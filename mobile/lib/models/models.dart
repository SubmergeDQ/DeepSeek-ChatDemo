import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/utils.dart';

/// 接口协议类型。
enum ProviderType { deepseek, openai, anthropic, gemini }

extension ProviderTypeX on ProviderType {
  String get label {
    switch (this) {
      case ProviderType.deepseek:
        return 'DeepSeek';
      case ProviderType.openai:
        return 'OpenAI';
      case ProviderType.anthropic:
        return 'Anthropic';
      case ProviderType.gemini:
        return 'Gemini';
    }
  }

  bool get supportsFileUpload => this == ProviderType.deepseek;

  bool get supportsSearch => this == ProviderType.deepseek;

  /// 是否支持把本轮回答作为 assistant 前缀继续生成。
  bool get supportsPrefill =>
      this == ProviderType.deepseek || this == ProviderType.anthropic;

  bool get supportsAsr =>
      this == ProviderType.deepseek || this == ProviderType.openai;

  IconData get icon {
    switch (this) {
      case ProviderType.deepseek:
        return Icons.auto_awesome;
      case ProviderType.openai:
        return Icons.blur_on;
      case ProviderType.anthropic:
        return Icons.spa_outlined;
      case ProviderType.gemini:
        return Icons.diamond_outlined;
    }
  }
}

class ModelInfo {
  ModelInfo({
    required this.id,
    required this.name,
    this.vision = false,
    this.thinking = false,
    this.search = false,
  });

  final String id;
  final String name;
  final bool vision;
  final bool thinking;
  final bool search;

  ModelInfo copyWith({
    String? id,
    String? name,
    bool? vision,
    bool? thinking,
    bool? search,
  }) {
    return ModelInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      vision: vision ?? this.vision,
      thinking: thinking ?? this.thinking,
      search: search ?? this.search,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'vision': vision,
        'thinking': thinking,
        'search': search,
      };

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['id'] as String? ?? '',
      vision: json['vision'] as bool? ?? false,
      thinking: json['thinking'] as bool? ?? false,
      search: json['search'] as bool? ?? false,
    );
  }
}

class ProviderConfig {
  ProviderConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.baseUrl,
    this.apiKey = '',
    List<ModelInfo>? models,
    this.builtin = false,
  }) : models = models ?? [];

  final String id;
  final String name;
  final ProviderType type;
  final String baseUrl;
  final String apiKey;
  final List<ModelInfo> models;
  final bool builtin;

  bool get isConfigured => apiKey.trim().isNotEmpty && models.isNotEmpty;

  ModelInfo? modelById(String? id) {
    if (id == null) return null;
    for (final model in models) {
      if (model.id == id) return model;
    }
    return null;
  }

  ProviderConfig copyWith({
    String? name,
    ProviderType? type,
    String? baseUrl,
    String? apiKey,
    List<ModelInfo>? models,
    bool? builtin,
  }) {
    return ProviderConfig(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      models: models ?? this.models,
      builtin: builtin ?? this.builtin,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'builtin': builtin,
        'models': models.map((model) => model.toJson()).toList(),
      };

  factory ProviderConfig.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'openai';
    final type = ProviderType.values.firstWhere(
      (item) => item.name == typeName,
      orElse: () => ProviderType.openai,
    );
    return ProviderConfig(
      id: json['id'] as String? ?? newId(),
      name: json['name'] as String? ?? type.label,
      type: type,
      baseUrl: json['baseUrl'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      builtin: json['builtin'] as bool? ?? false,
      models: ((json['models'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => ModelInfo.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  ProviderConfig copyWithModels(List<ModelInfo> models) => copyWith(models: models);
}

/// 内置预设。内置项可以编辑 Key 与模型，但不能删除。
List<ProviderConfig> defaultProviders() => [
      ProviderConfig(
        id: 'deepseek',
        name: 'DeepSeek',
        type: ProviderType.deepseek,
        baseUrl: 'https://api.deepseek.com',
        builtin: true,
        models: [
          ModelInfo(
            id: 'deepseek-flash',
            name: 'DeepSeek Flash',
            vision: true,
            thinking: true,
            search: true,
          ),
          ModelInfo(
            id: 'deepseek-v4-pro',
            name: 'DeepSeek V4 Pro',
            thinking: true,
            search: true,
          ),
        ],
      ),
      ProviderConfig(
        id: 'deepseek-openai',
        name: 'DeepSeek (OpenAI)',
        type: ProviderType.openai,
        baseUrl: 'https://api.deepseek.com/v1',
        builtin: true,
        models: [
          ModelInfo(id: 'deepseek-chat', name: 'DeepSeek Chat'),
          ModelInfo(
            id: 'deepseek-reasoner',
            name: 'DeepSeek Reasoner',
            thinking: true,
          ),
        ],
      ),
      ProviderConfig(
        id: 'openai',
        name: 'OpenAI',
        type: ProviderType.openai,
        baseUrl: 'https://api.openai.com/v1',
        builtin: true,
        models: [
          ModelInfo(id: 'gpt-4o', name: 'GPT-4o', vision: true),
          ModelInfo(id: 'gpt-4o-mini', name: 'GPT-4o mini', vision: true),
          ModelInfo(id: 'o3-mini', name: 'o3-mini'),
        ],
      ),
      ProviderConfig(
        id: 'anthropic',
        name: 'Anthropic',
        type: ProviderType.anthropic,
        baseUrl: 'https://api.anthropic.com/v1',
        builtin: true,
        models: [
          ModelInfo(
            id: 'claude-sonnet-4-5',
            name: 'Claude Sonnet 4.5',
            vision: true,
            thinking: true,
          ),
          ModelInfo(
            id: 'claude-haiku-4-5',
            name: 'Claude Haiku 4.5',
            vision: true,
            thinking: true,
          ),
          ModelInfo(
            id: 'claude-opus-4-1',
            name: 'Claude Opus 4.1',
            vision: true,
            thinking: true,
          ),
        ],
      ),
      ProviderConfig(
        id: 'gemini',
        name: 'Google Gemini',
        type: ProviderType.gemini,
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
        builtin: true,
        models: [
          ModelInfo(
            id: 'gemini-2.5-pro',
            name: 'Gemini 2.5 Pro',
            vision: true,
            thinking: true,
          ),
          ModelInfo(
            id: 'gemini-2.5-flash',
            name: 'Gemini 2.5 Flash',
            vision: true,
            thinking: true,
          ),
        ],
      ),
      ProviderConfig(
        id: 'openrouter',
        name: 'OpenRouter',
        type: ProviderType.openai,
        baseUrl: 'https://openrouter.ai/api/v1',
        builtin: true,
        models: [
          ModelInfo(id: 'openrouter/auto', name: 'OpenRouter Auto', vision: true),
        ],
      ),
    ];

class Attachment {
  Attachment({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.size,
    this.localPath,
    this.serverId,
    this.isImage = false,
    this.textContent,
  });

  final String id;
  final String name;
  final String mimeType;
  final int size;
  final String? localPath;
  final String? serverId;
  final bool isImage;

  /// 文本类附件在本地读取的内容（仅用于非 Files API 服务商）。
  final String? textContent;

  Attachment copyWith({String? serverId, String? localPath, String? textContent}) {
    return Attachment(
      id: id,
      name: name,
      mimeType: mimeType,
      size: size,
      localPath: localPath ?? this.localPath,
      serverId: serverId ?? this.serverId,
      isImage: isImage,
      textContent: textContent ?? this.textContent,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mimeType': mimeType,
        'size': size,
        'localPath': localPath,
        'serverId': serverId,
        'isImage': isImage,
        'textContent': textContent,
      };

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] as String? ?? newId(),
      name: json['name'] as String? ?? 'file',
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      size: (json['size'] as num?)?.toInt() ?? 0,
      localPath: json['localPath'] as String?,
      serverId: json['serverId'] as String?,
      isImage: json['isImage'] as bool? ?? false,
      textContent: json['textContent'] as String?,
    );
  }
}

class Citation {
  Citation({
    required this.url,
    this.title,
    this.siteName,
    this.snippet,
    this.publishedAt,
    this.siteIcon,
  });

  final String url;
  final String? title;
  final String? siteName;
  final String? snippet;
  final String? publishedAt;
  final String? siteIcon;

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'siteName': siteName,
        'snippet': snippet,
        'publishedAt': publishedAt,
        'siteIcon': siteIcon,
      };

  factory Citation.fromJson(Map<String, dynamic> json) => Citation(
        url: json['url'] as String? ?? '',
        title: json['title'] as String?,
        siteName: json['siteName'] as String?,
        snippet: json['snippet'] as String?,
        publishedAt: json['publishedAt'] as String?,
        siteIcon: json['siteIcon'] as String?,
      );
}

class TokenUsage {
  TokenUsage({this.inputTokens = 0, this.outputTokens = 0});

  final int inputTokens;
  final int outputTokens;

  Map<String, dynamic> toJson() => {
        'inputTokens': inputTokens,
        'outputTokens': outputTokens,
      };

  factory TokenUsage.fromJson(Map<String, dynamic> json) => TokenUsage(
        inputTokens: (json['inputTokens'] as num?)?.toInt() ?? 0,
        outputTokens: (json['outputTokens'] as num?)?.toInt() ?? 0,
      );
}

enum MessageStatus { streaming, done, stopped, error }

class MessageVariant {
  MessageVariant({
    this.content = '',
    this.reasoning = '',
    List<Citation>? citations,
    this.model,
    this.providerId,
    this.status = MessageStatus.streaming,
    this.error,
    this.stopReason,
    this.usage,
    this.reasoningSeconds,
    this.createdAt,
    this.feedback = 0,
    this.didBrowsePage = false,
  }) : citations = citations ?? [];

  String content;
  String reasoning;
  final List<Citation> citations;
  final String? model;
  final String? providerId;
  MessageStatus status;
  String? error;
  String? stopReason;
  TokenUsage? usage;
  int? reasoningSeconds;
  final int? createdAt;

  /// 0 无反馈，1 有帮助，-1 没帮助。
  int feedback;

  /// 本轮是否执行过网页阅读。
  bool didBrowsePage;

  Map<String, dynamic> toJson() => {
        'content': content,
        'reasoning': reasoning,
        'citations': citations.map((item) => item.toJson()).toList(),
        'model': model,
        'providerId': providerId,
        'status': status.name,
        'error': error,
        'stopReason': stopReason,
        'usage': usage?.toJson(),
        'reasoningSeconds': reasoningSeconds,
        'createdAt': createdAt,
        'feedback': feedback,
        'didBrowsePage': didBrowsePage,
      };

  factory MessageVariant.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String? ?? 'done';
    return MessageVariant(
      content: json['content'] as String? ?? '',
      reasoning: json['reasoning'] as String? ?? '',
      citations: ((json['citations'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Citation.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      model: json['model'] as String?,
      providerId: json['providerId'] as String?,
      status: MessageStatus.values.firstWhere(
        (item) => item.name == statusName,
        orElse: () => MessageStatus.done,
      ),
      error: json['error'] as String?,
      stopReason: json['stopReason'] as String?,
      usage: json['usage'] is Map
          ? TokenUsage.fromJson(Map<String, dynamic>.from(json['usage'] as Map))
          : null,
      reasoningSeconds: (json['reasoningSeconds'] as num?)?.toInt(),
      createdAt: (json['createdAt'] as num?)?.toInt(),
      feedback: (json['feedback'] as num?)?.toInt() ?? 0,
      didBrowsePage: json['didBrowsePage'] as bool? ?? false,
    );
  }
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    this.content = '',
    List<Attachment>? attachments,
    List<MessageVariant>? variants,
    this.activeVariant = 0,
    this.thinking = false,
    this.search = false,
    required this.createdAt,
  })  : attachments = attachments ?? [],
        variants = variants ?? [];

  final String id;
  final MessageRole role;
  String content;
  final List<Attachment> attachments;
  final List<MessageVariant> variants;
  int activeVariant;
  final bool thinking;
  final bool search;
  final int createdAt;

  bool get isUser => role == MessageRole.user;

  MessageVariant? get variant {
    if (variants.isEmpty) return null;
    final index = activeVariant.clamp(0, variants.length - 1);
    return variants[index];
  }

  bool get isStreaming => variant?.status == MessageStatus.streaming;

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'attachments': attachments.map((item) => item.toJson()).toList(),
        'variants': variants.map((item) => item.toJson()).toList(),
        'activeVariant': activeVariant,
        'thinking': thinking,
        'search': search,
        'createdAt': createdAt,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final roleName = json['role'] as String? ?? 'user';
    return ChatMessage(
      id: json['id'] as String? ?? newId(),
      role: MessageRole.values.firstWhere(
        (item) => item.name == roleName,
        orElse: () => MessageRole.user,
      ),
      content: json['content'] as String? ?? '',
      attachments: ((json['attachments'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Attachment.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      variants: ((json['variants'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => MessageVariant.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      activeVariant: (json['activeVariant'] as num?)?.toInt() ?? 0,
      thinking: json['thinking'] as bool? ?? false,
      search: json['search'] as bool? ?? false,
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
    );
  }

  String get displayText => isUser ? content : (variant?.content ?? '');
}

enum MessageRole { user, assistant }

class Conversation {
  Conversation({
    required this.id,
    this.title = '',
    required this.createdAt,
    required this.updatedAt,
    List<ChatMessage>? messages,
    this.draft = '',
    this.titleAuto = true,
  }) : messages = messages ?? [];

  final String id;
  String title;
  final int createdAt;
  int updatedAt;
  final List<ChatMessage> messages;
  String draft;
  bool titleAuto;

  String get displayTitle => title.trim().isEmpty ? '新对话' : title;

  DateTime get updatedAtTime => DateTime.fromMillisecondsSinceEpoch(updatedAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'draft': draft,
        'titleAuto': titleAuto,
        'messages': messages.map((item) => item.toJson()).toList(),
      };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String? ?? newId(),
        title: json['title'] as String? ?? '',
        createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
        updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
        draft: json['draft'] as String? ?? '',
        titleAuto: json['titleAuto'] as bool? ?? true,
        messages: ((json['messages'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
}

class ConversationSummary {
  ConversationSummary({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.preview = '',
  });

  final String id;
  final String title;
  final int createdAt;
  final int updatedAt;
  final String preview;

  String get displayTitle => title.trim().isEmpty ? '新对话' : title;

  DateTime get updatedAtTime => DateTime.fromMillisecondsSinceEpoch(updatedAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'preview': preview,
      };

  factory ConversationSummary.fromJson(Map<String, dynamic> json) => ConversationSummary(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
        updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
        preview: json['preview'] as String? ?? '',
      );
}

String encodeJson(Object value) => jsonEncode(value);

Map<String, dynamic> decodeJsonObject(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) return decoded;
  return <String, dynamic>{};
}
