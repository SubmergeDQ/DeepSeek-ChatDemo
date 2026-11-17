import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/models.dart';
import 'api_types.dart';
import 'chat_api.dart';
import 'http_util.dart';
import 'sse.dart';

/// OpenAI Chat Completions 协议，同时兼容 DeepSeek / Moonshot / 智谱 /
/// 硅基流动 / Groq / Ollama / OpenRouter 等 OpenAI 兼容服务。
class OpenAiApi extends ChatApi {
  @override
  Stream<ChatEvent> stream(ChatRequest request, CancelToken token) async* {
    final client = http.Client();
    token.attach(client);
    try {
      final uri = Uri.parse(joinUrl(request.provider.baseUrl, '/chat/completions'));
      final response = await sendJsonStream(
        client,
        uri,
        headers: {
          'Authorization': 'Bearer ${request.provider.apiKey}',
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        },
        body: {
          'model': request.model.id,
          'messages': await _messages(request),
          'stream': true,
        },
        token: token,
      );
      String? finishReason;
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('application/json')) {
        // 部分兼容服务忽略 stream 参数，直接返回完整 JSON。
        final body = await response.stream.bytesToString();
        final payload = decodeJsonObjectSafe(body);
        final result = _readCompletion(payload);
        if (result.reasoning.isNotEmpty) yield ReasoningDelta(result.reasoning);
        if (result.content.isNotEmpty) yield TextDelta(result.content);
        if (result.usage != null) yield UsageEvent(result.usage!);
        yield DoneEvent(result.finishReason);
        return;
      }
      await for (final event in parseSse(response.stream)) {
        final data = event.data.trim();
        if (data.isEmpty) continue;
        if (data == '[DONE]') break;
        final payload = decodeJsonObjectSafe(data);
        if (payload.isEmpty) continue;
        _throwIfError(payload);
        final choices = payload['choices'];
        if (choices is List && choices.isNotEmpty && choices.first is Map) {
          final choice = choices.first as Map;
          final delta = choice['delta'];
          if (delta is Map) {
            final reasoning = delta['reasoning_content'] ?? delta['reasoning'];
            if (reasoning is String && reasoning.isNotEmpty) {
              yield ReasoningDelta(reasoning);
            }
            final content = delta['content'];
            if (content is String && content.isNotEmpty) {
              yield TextDelta(content);
            } else if (content is List) {
              for (final part in content) {
                if (part is Map && part['text'] is String) {
                  yield TextDelta(part['text'] as String);
                }
              }
            }
          }
          final reason = choice['finish_reason'];
          if (reason is String) finishReason = reason;
        }
        final usage = _readUsage(payload['usage']);
        if (usage != null) yield UsageEvent(usage);
      }
      yield DoneEvent(finishReason);
    } on ApiException {
      rethrow;
    } catch (error) {
      if (token.cancelled) return;
      throw ApiException('请求中断：$error', kind: ApiErrorKind.interrupted);
    } finally {
      client.close();
    }
  }

  void _throwIfError(Map<String, dynamic> payload) {
    final error = payload['error'];
    if (error == null) return;
    if (error is String && error.isNotEmpty) {
      throw ApiException(error);
    }
    if (error is Map && error['message'] is String) {
      throw ApiException(error['message'] as String);
    }
  }

  TokenUsage? _readUsage(Object? raw) {
    if (raw is! Map) return null;
    final input = (raw['prompt_tokens'] ?? raw['input_tokens']);
    final output = (raw['completion_tokens'] ?? raw['output_tokens']);
    if (input is! num && output is! num) return null;
    return TokenUsage(
      inputTokens: (input as num?)?.toInt() ?? 0,
      outputTokens: (output as num?)?.toInt() ?? 0,
    );
  }

  _CompletionResult _readCompletion(Map<String, dynamic> payload) {
    _throwIfError(payload);
    var content = '';
    var reasoning = '';
    String? finishReason;
    final choices = payload['choices'];
    if (choices is List && choices.isNotEmpty && choices.first is Map) {
      final choice = choices.first as Map;
      final message = choice['message'];
      if (message is Map) {
        if (message['content'] is String) content = message['content'] as String;
        final rawReasoning = message['reasoning_content'] ?? message['reasoning'];
        if (rawReasoning is String) reasoning = rawReasoning;
      }
      if (choice['finish_reason'] is String) {
        finishReason = choice['finish_reason'] as String;
      }
    }
    return _CompletionResult(
      content: content,
      reasoning: reasoning,
      finishReason: finishReason,
      usage: _readUsage(payload['usage']),
    );
  }

  Future<List<Map<String, dynamic>>> _messages(ChatRequest request) async {
    final result = <Map<String, dynamic>>[];
    if (request.systemPrompt.trim().isNotEmpty) {
      result.add({'role': 'system', 'content': request.systemPrompt.trim()});
    }
    for (final turn in request.history) {
      final text = appendTextAttachments(turn.text, turn.attachments);
      if (text.trim().isEmpty) continue;
      result.add({
        'role': turn.role == MessageRole.user ? 'user' : 'assistant',
        'content': text,
      });
    }
    final text = appendTextAttachments(request.userText, request.attachments);
    final images = request.attachments.where((item) => item.isImage).toList();
    if (images.isEmpty) {
      result.add({'role': 'user', 'content': text});
    } else {
      if (!request.model.vision) {
        throw ApiException('当前模型不支持图片输入，请切换支持视觉的模型');
      }
      final parts = <Map<String, dynamic>>[
        if (text.trim().isNotEmpty) {'type': 'text', 'text': text},
      ];
      for (final image in images) {
        final bytes = await readAttachmentBytes(image);
        parts.add({
          'type': 'image_url',
          'image_url': {'url': dataUrlFor(image, bytes)},
        });
      }
      result.add({'role': 'user', 'content': parts});
    }
    final prefill = request.prefill;
    if (prefill != null && prefill.isNotEmpty) {
      result.add({'role': 'assistant', 'content': prefill});
    }
    return result;
  }

  @override
  Future<List<ModelInfo>> fetchModels(ProviderConfig provider) async {
    final client = http.Client();
    try {
      final response = await sendJson(
        client,
        Uri.parse(joinUrl(provider.baseUrl, '/models')),
        headers: {'Authorization': 'Bearer ${provider.apiKey}'},
        method: 'GET',
      );
      final payload = decodeJsonObjectSafe(response.body);
      final data = payload['data'];
      final list = <ModelInfo>[];
      if (data is List) {
        for (final item in data) {
          if (item is! Map || item['id'] is! String) continue;
          final id = item['id'] as String;
          list.add(
            ModelInfo(
              id: id,
              name: (item['name'] as String?) ?? id,
              vision: _looksVision(id),
              thinking: _looksThinking(id),
            ),
          );
        }
      }
      list.sort((a, b) => a.id.compareTo(b.id));
      return list;
    } finally {
      client.close();
    }
  }

  bool _looksVision(String id) {
    final lower = id.toLowerCase();
    return lower.contains('gpt-4o') ||
        lower.contains('gpt-4.1') ||
        lower.contains('gpt-5') ||
        lower.contains('omni') ||
        lower.contains('vision') ||
        lower.contains('claude') ||
        lower.contains('gemini') ||
        lower.contains('vl') ||
        lower.contains('llava') ||
        lower.contains('pixtral');
  }

  bool _looksThinking(String id) {
    final lower = id.toLowerCase();
    return lower.contains('o1') ||
        lower.contains('o3') ||
        lower.contains('o4') ||
        lower.contains('reason') ||
        lower.contains('thinking') ||
        lower.contains('r1');
  }

  @override
  Future<String> transcribe(
    ProviderConfig provider,
    String filePath,
    CancelToken token,
  ) async {
    final client = http.Client();
    token.attach(client);
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(joinUrl(provider.baseUrl, '/audio/transcriptions')),
      )
        ..headers['Authorization'] = 'Bearer ${provider.apiKey}'
        ..fields['model'] = 'whisper-1'
        ..files.add(await http.MultipartFile.fromPath('file', filePath));
      final streamed = await client.send(request).timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          errorMessageFromBody(response.body, response.reasonPhrase),
          statusCode: response.statusCode,
          kind: ApiErrorKind.http,
        );
      }
      final payload = decodeJsonObjectSafe(response.body);
      final text = payload['text'];
      if (text is String) return text;
      return utf8.decode(response.bodyBytes);
    } finally {
      client.close();
    }
  }
}

class _CompletionResult {
  _CompletionResult({
    required this.content,
    required this.reasoning,
    required this.finishReason,
    required this.usage,
  });

  final String content;
  final String reasoning;
  final String? finishReason;
  final TokenUsage? usage;
}
