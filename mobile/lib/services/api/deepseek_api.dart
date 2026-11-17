import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../models/models.dart';
import '../../core/utils.dart';
import 'api_types.dart';
import 'chat_api.dart';
import 'http_util.dart';
import 'sse.dart';

/// DeepSeek 官方接口：Anthropic 兼容的 Messages / Files API，
/// 支持深度思考、联网搜索、链接阅读与来源引用。
class DeepSeekApi extends ChatApi {
  static const _filesBeta = 'files-api-2025-04-14';

  @override
  Stream<ChatEvent> stream(ChatRequest request, CancelToken token) async* {
    final client = http.Client();
    token.attach(client);
    try {
      final attachments = <Attachment>[];
      for (final attachment in request.attachments) {
        if (attachment.serverId != null || attachment.localPath == null) {
          attachments.add(attachment);
        } else {
          attachments.add(await uploadAttachment(request.provider, attachment, token));
        }
      }
      final body = {
        'model': request.model.id,
        'system': request.systemPrompt,
        'messages': _messages(request, attachments),
        'thinking': {'type': request.thinking ? 'enabled' : 'disabled'},
        'tools': [
          {'type': 'deepseek_read_url', 'name': 'deepseek_read_url'},
          if (request.search)
            {'type': 'deepseek_web_search', 'name': 'deepseek_web_search'},
        ],
        'safety_check': {'level': 'high'},
        'stream': true,
        if (request.wantTitle) 'title': {'enabled': true},
      };
      final hasFile = attachments.any((item) => item.serverId != null) ||
          request.history.any(
            (turn) => turn.attachments.any((item) => item.serverId != null),
          );
      final response = await sendJsonStream(
        client,
        Uri.parse(joinUrl(request.provider.baseUrl, '/anthropic/v1/messages')),
        headers: {
          'x-api-key': request.provider.apiKey,
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
          if (hasFile) 'anthropic-beta': _filesBeta,
        },
        body: body,
        token: token,
      );
      String? stopReason;
      await for (final event in parseSse(response.stream)) {
        final data = event.data.trim();
        if (data.isEmpty) continue;
        Map<String, dynamic> payload;
        try {
          final decoded = jsonDecode(data);
          payload = decoded is Map<String, dynamic>
              ? decoded
              : decoded is Map
                  ? Map<String, dynamic>.from(decoded)
                  : <String, dynamic>{};
        } catch (_) {
          if (event.event == 'error') throw ApiException(data);
          continue;
        }
        if (payload.isEmpty) continue;
        final error = payload['error'];
        if (error is Map && error['message'] is String) {
          throw ApiException(error['message'] as String);
        }
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
            if (block is! Map) break;
            final blockType = block['type'];
            if (blockType == 'thinking' && block['thinking'] is String) {
              final thinking = block['thinking'] as String;
              if (thinking.isNotEmpty) yield ReasoningDelta(thinking);
            } else if (blockType == 'text' && block['text'] is String) {
              final text = block['text'] as String;
              if (text.isNotEmpty) yield TextDelta(text);
            } else if (blockType == 'server_tool_use') {
              final kind = block['kind'];
              yield SearchStatusEvent(
                kind == 'read_link' ? SearchPhase.reading : SearchPhase.searching,
              );
            } else if (blockType == 'web_search_tool_result') {
              final content = block['content'];
              if (content is List) {
                for (final item in content) {
                  if (item is! Map) continue;
                  if (item['type'] != 'web_search_result') continue;
                  final url = item['url'];
                  if (url is! String || url.isEmpty) continue;
                  yield CitationEvent(Citation(
                    url: url,
                    title: item['title'] as String?,
                    siteName: item['site_name'] as String?,
                    snippet: item['snippet'] as String?,
                  ));
                }
              }
            }
            break;
          case 'content_block_delta':
            final delta = payload['delta'];
            if (delta is! Map) break;
            final deltaType = delta['type'];
            if (deltaType == 'text_delta' && delta['text'] is String) {
              yield TextDelta(delta['text'] as String);
            } else if (deltaType == 'thinking_delta' && delta['thinking'] is String) {
              yield ReasoningDelta(delta['thinking'] as String);
            } else if (deltaType == 'citations_delta') {
              final citation = delta['citation'];
              if (citation is Map && citation['url'] is String) {
                yield CitationEvent(Citation(
                  url: citation['url'] as String,
                  title: citation['title'] as String?,
                ));
              }
            }
            break;
          case 'message_delta':
            final delta = payload['delta'];
            if (delta is Map) {
              if (delta['stop_reason'] is String) {
                stopReason = delta['stop_reason'] as String;
              }
              final title = delta['title'];
              if (title is String && title.trim().isNotEmpty) {
                yield TitleEvent(title.trim());
              }
            }
            final usage = _usage(payload['usage']);
            if (usage != null) yield UsageEvent(usage);
            break;
          case 'message_stop':
            yield DoneEvent(stopReason);
            return;
          case 'error':
            final message = payload['message'];
            throw ApiException(message is String ? message : data);
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

  List<Map<String, dynamic>> _messages(
    ChatRequest request,
    List<Attachment> currentAttachments,
  ) {
    final result = <Map<String, dynamic>>[];
    for (final turn in request.history) {
      if (turn.role == MessageRole.user) {
        final files = turn.attachments
            .where((item) => item.serverId != null)
            .map<Map<String, dynamic>>((item) => {
                  'type': item.isImage ? 'image' : 'document',
                  'source': {'type': 'file', 'file_id': item.serverId},
                })
            .toList();
        final text = turn.text;
        if (files.isEmpty) {
          if (text.trim().isEmpty) continue;
          result.add({'role': 'user', 'content': text});
        } else {
          result.add({
            'role': 'user',
            'content': [
              ...files,
              if (text.trim().isNotEmpty) {'type': 'text', 'text': text},
            ],
          });
        }
      } else {
        if (turn.text.trim().isEmpty) continue;
        result.add({
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': turn.text},
          ],
        });
      }
    }
    final files = currentAttachments
        .where((item) => item.serverId != null)
        .map<Map<String, dynamic>>((item) => {
              'type': item.isImage ? 'image' : 'document',
              'source': {'type': 'file', 'file_id': item.serverId},
            })
        .toList();
    if (files.isEmpty) {
      result.add({'role': 'user', 'content': request.userText});
    } else {
      result.add({
        'role': 'user',
        'content': [
          ...files,
          if (request.userText.trim().isNotEmpty)
            {'type': 'text', 'text': request.userText},
        ],
      });
    }
    final prefill = request.prefill;
    if (prefill != null && prefill.isNotEmpty) {
      result.add({
        'role': 'assistant',
        'content': [
          {'type': 'text', 'text': prefill},
        ],
      });
    }
    return result;
  }

  @override
  Future<Attachment> uploadAttachment(
    ProviderConfig provider,
    Attachment attachment,
    CancelToken token,
  ) async {
    final path = attachment.localPath;
    if (path == null) throw ApiException('附件原件不可用：${attachment.name}');
    final client = http.Client();
    token.attach(client);
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(joinUrl(provider.baseUrl, '/anthropic/v1/files')),
      )..headers.addAll({
          'x-api-key': provider.apiKey,
          'anthropic-beta': _filesBeta,
        });
      final purpose = _purposeFor(attachment);
      if (purpose != null) request.fields['purpose'] = purpose;
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        path,
        filename: attachment.name,
        contentType: MediaType.parse(attachment.mimeType),
      ));
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
      final id = payload['id'];
      if (id is! String || id.isEmpty) {
        throw ApiException('上传响应缺少文件 ID');
      }
      return attachment.copyWith(serverId: id);
    } finally {
      client.close();
    }
  }

  String? _purposeFor(Attachment attachment) {
    if (attachment.isImage) return null;
    final ext = fileExtension(attachment.name);
    if (const {'.pdf', '.doc', '.docx', '.ppt', '.pptx'}.contains(ext)) {
      return 'rich_layout_recognition';
    }
    return 'user_data';
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
        Uri.parse(joinUrl(provider.baseUrl, '/v1/tools/asr')),
      )..headers['Authorization'] = 'Bearer ${provider.apiKey}';
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: 'recording.wav',
        contentType: MediaType('audio', 'wav'),
      ));
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
      throw ApiException('语音识别响应格式不正确', kind: ApiErrorKind.protocol);
    } finally {
      client.close();
    }
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
          final lower = id.toLowerCase();
          list.add(ModelInfo(
            id: id,
            name: id,
            vision: lower.contains('flash') || lower.contains('vision'),
            thinking: lower.contains('flash') ||
                lower.contains('pro') ||
                lower.contains('reason'),
            search: lower.contains('flash') || lower.contains('pro'),
          ));
        }
      }
      return list;
    } finally {
      client.close();
    }
  }
}
