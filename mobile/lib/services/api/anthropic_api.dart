import 'package:http/http.dart' as http;

import '../../models/models.dart';
import 'api_types.dart';
import 'chat_api.dart';
import 'http_util.dart';
import 'sse.dart';

/// Anthropic Messages API。
class AnthropicApi extends ChatApi {
  static const _version = '2023-06-01';

  Map<String, String> _headers(ProviderConfig provider) => {
        'x-api-key': provider.apiKey,
        'anthropic-version': _version,
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      };

  @override
  Stream<ChatEvent> stream(ChatRequest request, CancelToken token) async* {
    final client = http.Client();
    token.attach(client);
    try {
      final response = await sendJsonStream(
        client,
        Uri.parse(joinUrl(request.provider.baseUrl, '/messages')),
        headers: _headers(request.provider),
        body: {
          'model': request.model.id,
          'max_tokens': request.thinking ? 8192 : 4096,
          if (request.systemPrompt.trim().isNotEmpty)
            'system': request.systemPrompt.trim(),
          'messages': await _messages(request),
          'stream': true,
          if (request.thinking)
            'thinking': {'type': 'enabled', 'budget_tokens': 4096},
        },
        token: token,
      );
      String? stopReason;
      await for (final event in parseSse(response.stream)) {
        final payload = decodeJsonObjectSafe(event.data);
        if (payload.isEmpty) continue;
        final type = (payload['type'] as String?) ?? event.event;
        switch (type) {
          case 'message_start':
            final message = payload['message'];
            if (message is Map) {
              final usage = _usage(message['usage']);
              if (usage != null) yield UsageEvent(usage);
            }
            break;
          case 'content_block_start':
            final block = payload['content_block'];
            if (block is Map && block['type'] == 'thinking') {
              final thinking = block['thinking'];
              if (thinking is String && thinking.isNotEmpty) {
                yield ReasoningDelta(thinking);
              }
            } else if (block is Map && block['type'] == 'text') {
              final text = block['text'];
              if (text is String && text.isNotEmpty) yield TextDelta(text);
            }
            break;
          case 'content_block_delta':
            final delta = payload['delta'];
            if (delta is! Map) break;
            if (delta['type'] == 'text_delta' && delta['text'] is String) {
              yield TextDelta(delta['text'] as String);
            } else if (delta['type'] == 'thinking_delta' &&
                delta['thinking'] is String) {
              yield ReasoningDelta(delta['thinking'] as String);
            }
            break;
          case 'message_delta':
            final delta = payload['delta'];
            if (delta is Map && delta['stop_reason'] is String) {
              stopReason = delta['stop_reason'] as String;
            }
            final usage = _usage(payload['usage']);
            if (usage != null) yield UsageEvent(usage);
            break;
          case 'message_stop':
            yield DoneEvent(stopReason);
            return;
          case 'error':
            final error = payload['error'];
            final message =
                error is Map && error['message'] is String ? error['message'] as String : '流式返回错误';
            throw ApiException(message);
          default:
            break;
        }
      }
      yield DoneEvent(stopReason);
    } on ApiException {
      rethrow;
    } catch (error) {
      if (token.cancelled) return;
      throw ApiException('请求中断：$error', kind: ApiErrorKind.interrupted);
    } finally {
      client.close();
    }
  }

  TokenUsage? _usage(Object? raw) {
    if (raw is! Map) return null;
    final input = raw['input_tokens'];
    final output = raw['output_tokens'];
    if (input is! num && output is! num) return null;
    return TokenUsage(
      inputTokens: (input as num?)?.toInt() ?? 0,
      outputTokens: (output as num?)?.toInt() ?? 0,
    );
  }

  Future<List<Map<String, dynamic>>> _messages(ChatRequest request) async {
    final result = <Map<String, dynamic>>[];
    for (final turn in request.history) {
      final text = appendTextAttachments(turn.text, turn.attachments).trim();
      if (text.isEmpty) continue;
      result.add({
        'role': turn.role == MessageRole.user ? 'user' : 'assistant',
        'content': text,
      });
    }
    final text = appendTextAttachments(request.userText, request.attachments).trim();
    final images = request.attachments.where((item) => item.isImage).toList();
    if (images.isEmpty) {
      result.add({'role': 'user', 'content': text});
    } else {
      if (!request.model.vision) {
        throw ApiException('当前模型不支持图片输入，请切换支持视觉的模型');
      }
      final blocks = <Map<String, dynamic>>[];
      for (final image in images) {
        final bytes = await readAttachmentBytes(image);
        blocks.add({
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': image.mimeType,
            'data': base64ForAttachment(bytes),
          },
        });
      }
      if (text.isNotEmpty) {
        blocks.add({'type': 'text', 'text': text});
      }
      result.add({'role': 'user', 'content': blocks});
    }
    final prefill = request.prefill?.trimRight();
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
        Uri.parse(joinUrl(provider.baseUrl, '/models?limit=100')),
        headers: {
          'x-api-key': provider.apiKey,
          'anthropic-version': _version,
        },
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
              name: (item['display_name'] as String?) ?? id,
              vision: true,
              thinking: !id.contains('claude-2') && !id.contains('claude-instant'),
            ),
          );
        }
      }
      return list;
    } finally {
      client.close();
    }
  }
}
