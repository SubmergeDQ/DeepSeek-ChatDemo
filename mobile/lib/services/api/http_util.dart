import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../models/models.dart';
import 'api_types.dart';

String joinUrl(String base, String path) {
  final normalized = base.replaceAll(RegExp(r'/+$'), '');
  return '$normalized$path';
}

Map<String, String> jsonHeaders([Map<String, String>? extra]) => {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?extra,
    };

/// 从错误响应中尽量提取可读信息，兼容 OpenAI / Anthropic / DeepSeek / Gemini。
String errorMessageFromBody(String body, String? fallback) {
  if (body.trim().isEmpty) return fallback ?? 'HTTP error';
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final error = decoded['error'];
      if (error is String) return error;
      if (error is Map) {
        final message = error['message'];
        if (message is String && message.trim().isNotEmpty) return message;
      }
      final message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) return message;
    }
  } catch (_) {
    // 非 JSON 响应直接返回原文。
  }
  final trimmed = body.trim();
  return trimmed.length > 500 ? '${trimmed.substring(0, 500)}…' : trimmed;
}

Future<http.StreamedResponse> sendJsonStream(
  http.Client client,
  Uri uri, {
  required Map<String, String> headers,
  required Object body,
  required CancelToken token,
  Duration connectTimeout = const Duration(seconds: 90),
}) async {
  final request = http.Request('POST', uri)
    ..headers.addAll(headers)
    ..bodyBytes = utf8.encode(jsonEncode(body));
  token.attach(client);
  http.StreamedResponse response;
  try {
    response = await client.send(request).timeout(connectTimeout);
  } on TimeoutException {
    throw ApiException('连接超时，请检查网络或接口地址', kind: ApiErrorKind.network);
  } catch (error) {
    if (token.cancelled) throw ApiException('已停止', kind: ApiErrorKind.cancelled);
    throw ApiException(
      '网络请求失败：$error',
      kind: ApiErrorKind.network,
    );
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    final text = await response.stream.bytesToString();
    throw ApiException(
      errorMessageFromBody(text, response.reasonPhrase),
      statusCode: response.statusCode,
      kind: ApiErrorKind.http,
    );
  }
  final contentType = response.headers['content-type'] ?? '';
  if (!contentType.contains('text/event-stream') &&
      !contentType.contains('application/json') &&
      contentType.isNotEmpty) {
    // 少数兼容服务不返回正确 Content-Type，仍尝试按 SSE 读取。
  }
  return response;
}

Future<http.Response> sendJson(
  http.Client client,
  Uri uri, {
  required Map<String, String> headers,
  Object? body,
  String method = 'POST',
  Duration timeout = const Duration(seconds: 60),
}) async {
  final request = http.Request(method, uri)..headers.addAll(headers);
  if (body != null) {
    request.bodyBytes = utf8.encode(jsonEncode(body));
  }
  final streamed = await client.send(request).timeout(timeout);
  final response = await http.Response.fromStream(streamed);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw ApiException(
      errorMessageFromBody(response.body, response.reasonPhrase),
      statusCode: response.statusCode,
      kind: ApiErrorKind.http,
    );
  }
  return response;
}

Map<String, dynamic> decodeJsonObjectSafe(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {
    // ignore
  }
  return <String, dynamic>{};
}

Future<Uint8List> readAttachmentBytes(Attachment attachment) async {
  final path = attachment.localPath;
  if (path == null || path.isEmpty) {
    throw ApiException('附件原件不可用：${attachment.name}');
  }
  final file = File(path);
  if (!await file.exists()) {
    throw ApiException('附件原件不可用：${attachment.name}');
  }
  return file.readAsBytes();
}

String base64ForAttachment(Uint8List bytes) => base64Encode(bytes);

String dataUrlFor(Attachment attachment, Uint8List bytes) =>
    'data:${attachment.mimeType};base64,${base64Encode(bytes)}';

/// 判断接口地址是否已经包含版本段，避免重复拼接。
bool hasApiVersion(String base) => RegExp(r'/v\d+[a-z0-9]*$', caseSensitive: false).hasMatch(base);
