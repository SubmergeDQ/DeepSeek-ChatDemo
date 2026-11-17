import 'package:http/http.dart' as http;

import '../../models/models.dart';
import 'api_types.dart';
import 'chat_api.dart';
import 'http_util.dart';
import 'sse.dart';

/// Google Gemini generateContent 协议。
class GeminiApi extends ChatApi {
  @override
  Stream<ChatEvent> stream(ChatRequest request, CancelToken token) async* {
    final client = http.Client();
    token.attach(client);
    try {
      final base = request.provider.baseUrl.replaceAll(RegExp(r'/+$'), '');
      final modelId = _stripModelPrefix(request.model.id);
      final uri = Uri.parse('$base/models/${Uri.encodeComponent(modelId)}:streamGenerateContent')
          .replace(queryParameters: {'alt': 'sse', 'key': request.provider.apiKey});
      final response = await sendJsonStream(
        client,
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        },
        body: await _body(request),
        token: token,
      );
      String? finishReason;
      await for (final event in parseSse(response.stream)) {
        final payload = decodeJsonObjectSafe(event.data);
        if (payload.isEmpty) continue;
        final error = payload['error'];
        if (error is Map && error['message'] is String) {
          throw ApiException(error['message'] as String);
        }
        final candidates = payload['candidates'];
        if (candidates is List && candidates.isNotEmpty && candidates.first is Map) {
          final candidate = candidates.first as Map;
          final content = candidate['content'];
          if (content is Map && content['parts'] is List) {
            for (final part in content['parts'] as List) {
              if (part is! Map) continue;
              final text = part['text'];
              if (text is! String || text.isEmpty) continue;
              if (part['thought'] == true) {
                yield ReasoningDelta(text);
              } else {
                yield TextDelta(text);
              }
            }
          }
          final reason = candidate['finishReason'];
          if (reason is String) finishReason = _mapFinishReason(reason);
        }
        final usage = _usage(payload['usageMetadata']);
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

  String _mapFinishReason(String reason) {
    switch (reason) {
      case 'MAX_TOKENS':
        return 'max_tokens';
      case 'SAFETY':
      case 'PROHIBITED_CONTENT':
      case 'BLOCKLIST':
        return 'refusal';
      default:
        return 'end_turn';
    }
  }

  String _stripModelPrefix(String id) =>
      id.startsWith('models/') ? id.substring('models/'.length) : id;

  TokenUsage? _usage(Object? raw) {
    if (raw is! Map) return null;
    final input = raw['promptTokenCount'];
    final output = raw['candidatesTokenCount'];
    if (input is! num && output is! num) return null;
    return TokenUsage(
      inputTokens: (input as num?)?.toInt() ?? 0,
      outputTokens: (output as num?)?.toInt() ?? 0,
    );
  }

  Future<Map<String, dynamic>> _body(ChatRequest request) async {
    final contents = <Map<String, dynamic>>[];
    for (final turn in request.history) {
      final text = appendTextAttachments(turn.text, turn.attachments).trim();
      if (text.isEmpty) continue;
      contents.add({
        'role': turn.role == MessageRole.user ? 'user' : 'model',
        'parts': [
          {'text': text},
        ],
      });
    }
    final text = appendTextAttachments(request.userText, request.attachments).trim();
    final parts = <Map<String, dynamic>>[];
    if (text.isNotEmpty) parts.add({'text': text});
    final images = request.attachments.where((item) => item.isImage).toList();
    if (images.isNotEmpty) {
      if (!request.model.vision) {
        throw ApiException('当前模型不支持图片输入，请切换支持视觉的模型');
      }
      for (final image in images) {
        final bytes = await readAttachmentBytes(image);
        parts.add({
          'inline_data': {
            'mime_type': image.mimeType,
            'data': base64ForAttachment(bytes),
          },
        });
      }
    }
    contents.add({'role': 'user', 'parts': parts});
    return {
      if (request.systemPrompt.trim().isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': request.systemPrompt.trim()},
          ],
        },
      'contents': contents,
      if (request.thinking)
        'generationConfig': {
          'thinkingConfig': {'includeThoughts': true},
        },
    };
  }

  @override
  Future<List<ModelInfo>> fetchModels(ProviderConfig provider) async {
    final client = http.Client();
    try {
      final base = provider.baseUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base/models')
          .replace(queryParameters: {'key': provider.apiKey});
      final response = await sendJson(
        client,
        uri,
        headers: const {'Accept': 'application/json'},
        method: 'GET',
      );
      final payload = decodeJsonObjectSafe(response.body);
      final models = payload['models'];
      final list = <ModelInfo>[];
      if (models is List) {
        for (final item in models) {
          if (item is! Map || item['name'] is! String) continue;
          final methods = item['supportedGenerationMethods'];
          if (methods is List && !methods.contains('generateContent')) continue;
          final id = (item['name'] as String).replaceFirst('models/', '');
          list.add(
            ModelInfo(
              id: id,
              name: (item['displayName'] as String?) ?? id,
              vision: id.contains('gemini'),
              thinking: id.contains('2.5') || id.contains('3'),
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
