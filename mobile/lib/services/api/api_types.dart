import 'package:http/http.dart' as http;

import '../../models/models.dart';

enum ApiErrorKind { http, network, protocol, interrupted, cancelled }

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.kind = ApiErrorKind.protocol});

  final String message;
  final int? statusCode;
  final ApiErrorKind kind;

  @override
  String toString() => message;
}

class CancelToken {
  bool cancelled = false;
  void Function()? _onCancel;
  http.Client? _client;

  void attach(http.Client client) {
    _client = client;
    if (cancelled) {
      client.close();
    }
  }

  void onCancel(void Function() callback) {
    _onCancel = callback;
  }

  void cancel() {
    if (cancelled) return;
    cancelled = true;
    _onCancel?.call();
    _client?.close();
  }
}

class ChatTurn {
  ChatTurn({required this.role, required this.text, List<Attachment>? attachments})
      : attachments = attachments ?? [];

  final MessageRole role;
  final String text;
  final List<Attachment> attachments;
}

class ChatRequest {
  ChatRequest({
    required this.provider,
    required this.model,
    this.systemPrompt = '',
    List<ChatTurn>? history,
    required this.userText,
    List<Attachment>? attachments,
    this.thinking = false,
    this.search = false,
    this.wantTitle = false,
    this.prefill,
  })  : history = history ?? [],
        attachments = attachments ?? [];

  final ProviderConfig provider;
  final ModelInfo model;
  final String systemPrompt;
  final List<ChatTurn> history;
  final String userText;
  final List<Attachment> attachments;
  final bool thinking;
  final bool search;
  final bool wantTitle;

  /// 继续生成时，把已有回答作为 assistant 前缀回传。
  final String? prefill;
}

sealed class ChatEvent {
  const ChatEvent();
}

class TextDelta extends ChatEvent {
  const TextDelta(this.text);

  final String text;
}

class ReasoningDelta extends ChatEvent {
  const ReasoningDelta(this.text);

  final String text;
}

class CitationEvent extends ChatEvent {
  const CitationEvent(this.citation);

  final Citation citation;
}

enum SearchPhase { searching, reading }

class SearchStatusEvent extends ChatEvent {
  const SearchStatusEvent(this.phase);

  final SearchPhase phase;
}

class TitleEvent extends ChatEvent {
  const TitleEvent(this.title);

  final String title;
}

class UsageEvent extends ChatEvent {
  const UsageEvent(this.usage);

  final TokenUsage usage;
}

class DoneEvent extends ChatEvent {
  const DoneEvent(this.stopReason);

  final String? stopReason;
}
