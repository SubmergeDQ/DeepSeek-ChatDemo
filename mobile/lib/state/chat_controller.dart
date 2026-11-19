import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils.dart';
import '../data/conversation_repository.dart';
import '../data/settings_store.dart';
import '../models/models.dart';
import '../services/api/api_types.dart';
import '../services/api/chat_api.dart';
import '../services/files/attachment_service.dart';
import '../services/speech/speech_service.dart';

class ChatException implements Exception {
  ChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 会话、流式回复与分支状态。
class ChatController extends ChangeNotifier {
  ChatController({
    required this.settings,
    required this.repository,
    required this.attachmentService,
    required this.speech,
  });

  final SettingsStore settings;
  final ConversationRepository repository;
  final AttachmentService attachmentService;
  final SpeechService speech;

  List<ConversationSummary> summaries = [];
  Conversation? active;
  bool loading = true;
  String? searchPhase;
  String? streamingConversationId;

  final Map<String, Conversation> _cache = {};
  final Set<String> _deletedIds = {};
  CancelToken? _token;
  Timer? _saveTimer;
  Timer? _draftTimer;
  int _dataEpoch = 0;

  bool get isStreaming => streamingConversationId != null;

  bool get isActiveStreaming =>
      streamingConversationId != null && streamingConversationId == active?.id;

  bool get canSend =>
      !isStreaming && settings.activeProvider != null && settings.activeModel != null;

  Future<void> init() async {
    summaries = await repository.listConversations();
    loading = false;
    notifyListeners();
  }

  Future<void> reloadSummaries() async {
    summaries = await repository.listConversations();
    notifyListeners();
  }

  /// 导出时需要完整的会话内容。
  Future<List<Conversation>> loadAllForExport() async {
    final list = await repository.listConversations();
    final result = <Conversation>[];
    for (final summary in list) {
      final cached = _cache[summary.id];
      if (cached != null) {
        result.add(cached);
        continue;
      }
      final loaded = await repository.loadConversation(summary.id);
      if (loaded != null) result.add(loaded);
    }
    return result;
  }

  void newConversation() {
    final now = DateTime.now().millisecondsSinceEpoch;
    active = Conversation(id: newId(), createdAt: now, updatedAt: now);
    searchPhase = null;
    notifyListeners();
  }

  Future<void> openConversation(String id) async {
    if (active?.id == id) return;
    final cached = _cache[id];
    if (cached != null) {
      active = cached;
      notifyListeners();
      return;
    }
    final loaded = await repository.loadConversation(id);
    if (loaded == null) return;
    // 上次进程在生成中被终止时，残留的 streaming 状态按已停止处理。
    var changed = false;
    for (final message in loaded.messages) {
      for (final variant in message.variants) {
        if (variant.status == MessageStatus.streaming) {
          variant.status = MessageStatus.stopped;
          changed = true;
        }
      }
    }
    if (changed) {
      await repository.replaceMessages(loaded.id, loaded.messages);
    }
    _cache[id] = loaded;
    _trimCache();
    active = loaded;
    notifyListeners();
  }

  void _trimCache() {
    if (_cache.length <= 8) return;
    final removable = _cache.keys
        .where((id) => id != active?.id && id != streamingConversationId)
        .toList();
    while (_cache.length > 8 && removable.isNotEmpty) {
      _cache.remove(removable.removeAt(0));
    }
  }

  void setDraft(String text) {
    final conversation = active;
    if (conversation == null) return;
    if (conversation.draft == text) return;
    conversation.draft = text;
    _cache[conversation.id] = conversation;
    if (conversation.messages.isEmpty) return;
    final epoch = _dataEpoch;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 600), () {
      if (epoch != _dataEpoch) return;
      if (_deletedIds.contains(conversation.id)) return;
      repository.saveConversation(conversation);
    });
  }

  Future<void> renameConversation(String id, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    var conversation = _cache[id] ?? (active?.id == id ? active : null);
    if (conversation == null) {
      conversation = await repository.loadConversation(id);
      if (conversation == null) return;
      _cache[id] = conversation;
    }
    conversation.title = trimmed;
    conversation.titleAuto = false;
    await repository.saveConversation(conversation);
    await reloadSummaries();
  }

  Future<void> deleteConversation(String id) async {
    if (streamingConversationId == id) {
      _token?.cancel();
      streamingConversationId = null;
      _token = null;
    }
    Conversation? cleanup = _cache[id];
    if (cleanup == null && active?.id == id) {
      cleanup = active;
    }
    cleanup ??= await repository.loadConversation(id);
    _deletedIds.add(id);
    await repository.deleteConversation(id);
    if (cleanup != null) {
      await attachmentService.deleteForConversations([cleanup]);
    }
    _cache.remove(id);
    summaries = summaries.where((item) => item.id != id).toList();
    if (active?.id == id) {
      active = null;
      newConversation();
    } else {
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
    _dataEpoch += 1;
    _markAllKnownDeleted();
    _token?.cancel();
    _token = null;
    streamingConversationId = null;
    _saveTimer?.cancel();
    await repository.clearAll();
    await attachmentService.clearAll();
    _deletedIds.clear();
    _cache.clear();
    summaries = [];
    active = null;
    newConversation();
  }

  Future<void> replaceAll(List<Conversation> conversations) async {
    _dataEpoch += 1;
    _markAllKnownDeleted();
    _token?.cancel();
    _token = null;
    streamingConversationId = null;
    _saveTimer?.cancel();
    await repository.replaceAll(conversations);
    await attachmentService.clearAll();
    _deletedIds.clear();
    _cache.clear();
    active = null;
    summaries = await repository.listConversations();
    if (summaries.isNotEmpty) {
      await openConversation(summaries.first.id);
    } else {
      newConversation();
    }
  }

  /// 清空/导入时防止仍在收尾的流把旧会话重新写回数据库。
  void _markAllKnownDeleted() {
    for (final summary in summaries) {
      _deletedIds.add(summary.id);
    }
    for (final conversation in _cache.values) {
      _deletedIds.add(conversation.id);
    }
    final current = active;
    if (current != null) {
      _deletedIds.add(current.id);
    }
  }

  void stop() {
    _token?.cancel();
  }

  Future<void> send(String text, {List<Attachment> attachments = const []}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && attachments.isEmpty) {
      throw ChatException(settings.l10n.emptyMessage);
    }
    if (isStreaming) {
      throw ChatException(
        settings.zh ? '请先等待当前回复完成或停止生成' : 'Wait for the current reply or stop it first',
      );
    }
    final provider = settings.activeProvider;
    final model = settings.activeModel;
    if (provider == null) {
      throw ChatException(settings.l10n.provider);
    }
    if (provider.apiKey.trim().isEmpty) {
      throw ChatException(settings.l10n.noApiKeyForProvider);
    }
    if (model == null) {
      throw ChatException(settings.l10n.modelListEmpty);
    }
    _validateAttachments(provider, model, attachments);

    final conversation = active ?? Conversation(
      id: newId(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    active = conversation;
    _cache[conversation.id] = conversation;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (conversation.title.trim().isEmpty) {
      conversation.title = conversationTitleFrom(trimmed);
      conversation.titleAuto = true;
    }
    final thinking = settings.thinking && model.thinking;
    final search = settings.search && model.search;
    final user = ChatMessage(
      id: newId(),
      role: MessageRole.user,
      content: trimmed,
      attachments: attachments,
      thinking: thinking,
      search: search,
      createdAt: now,
    );
    conversation.messages.add(user);
    conversation.updatedAt = now;
    conversation.draft = '';
    await repository.saveConversation(conversation);
    await repository.saveMessage(conversation.id, conversation.messages.length - 1, user);

    final basic = await _startAssistant(
      conversation: conversation,
      thinking: thinking,
      search: search,
    );
    if (basic != null) {
      notifyListeners();
      await _runStream(
        conversation: conversation,
        assistant: basic,
        user: user,
        thinking: thinking,
        search: search,
        wantTitle: conversation.messages.where((item) => item.isUser).length == 1 &&
            provider.type == ProviderType.deepseek,
        prefill: null,
      );
    }
  }

  Future<ChatMessage?> _startAssistant({
    required Conversation conversation,
    required bool thinking,
    required bool search,
  }) async {
    final provider = settings.activeProvider;
    final model = settings.activeModel;
    if (provider == null || model == null) return null;
    final assistant = ChatMessage(
      id: newId(),
      role: MessageRole.assistant,
      thinking: thinking,
      search: search,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      variants: [
        MessageVariant(
          model: model.id,
          providerId: provider.id,
          status: MessageStatus.streaming,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      ],
    );
    conversation.messages.add(assistant);
    await repository.saveMessage(
      conversation.id,
      conversation.messages.length - 1,
      assistant,
    );
    return assistant;
  }

  void _validateAttachments(
    ProviderConfig provider,
    ModelInfo model,
    List<Attachment> attachments,
  ) {
    for (final attachment in attachments) {
      if (attachment.isImage) {
        if (!model.vision) {
          throw ChatException(
            settings.zh ? '当前模型不支持图片输入，请切换支持视觉的模型' : 'This model does not support images',
          );
        }
      } else if (provider.type != ProviderType.deepseek &&
          (attachment.textContent == null || attachment.textContent!.isEmpty)) {
        throw ChatException(settings.l10n.unsupportedFile);
      }
    }
  }

  Future<void> regenerate(int messageIndex) async {
    if (isStreaming) {
      throw ChatException(settings.zh ? '请先停止当前生成' : 'Stop the current generation first');
    }
    final conversation = active;
    if (conversation == null || messageIndex < 0 || messageIndex >= conversation.messages.length) {
      return;
    }
    final assistant = conversation.messages[messageIndex];
    if (assistant.isUser) return;
    if (messageIndex != conversation.messages.length - 1) {
      throw ChatException(
        settings.zh ? '只能重新生成最后一条回复' : 'Only the latest reply can be regenerated',
      );
    }
    ChatMessage? user;
    for (var i = messageIndex - 1; i >= 0; i--) {
      if (conversation.messages[i].isUser) {
        user = conversation.messages[i];
        break;
      }
    }
    if (user == null) return;
    final provider = settings.activeProvider;
    final model = settings.activeModel;
    if (provider == null || model == null) return;
    if (provider.apiKey.trim().isEmpty) {
      throw ChatException(settings.l10n.noApiKeyForProvider);
    }
    final thinking = assistant.thinking && model.thinking;
    final search = assistant.search && model.search;
    assistant.variants.add(MessageVariant(
      model: model.id,
      providerId: provider.id,
      status: MessageStatus.streaming,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    assistant.activeVariant = assistant.variants.length - 1;
    notifyListeners();
    await repository.saveMessage(conversation.id, messageIndex, assistant);
    await _runStream(
      conversation: conversation,
      assistant: assistant,
      user: user,
      thinking: thinking,
      search: search,
      wantTitle: false,
      prefill: null,
    );
  }

  Future<void> editAndResend(int messageIndex, String newText, {List<Attachment>? attachments}) async {
    if (isStreaming) {
      throw ChatException(settings.zh ? '请先停止当前生成' : 'Stop the current generation first');
    }
    final conversation = active;
    if (conversation == null) return;
    if (messageIndex < 0 || messageIndex >= conversation.messages.length) return;
    final original = conversation.messages[messageIndex];
    if (!original.isUser) return;
    final content = newText.trim();
    final files = attachments ?? original.attachments;
    if (content.isEmpty && files.isEmpty) {
      throw ChatException(settings.l10n.emptyMessage);
    }
    final provider = settings.activeProvider;
    final model = settings.activeModel;
    if (provider == null || model == null) return;
    _validateAttachments(provider, model, files);
    final truncated = conversation.messages.sublist(0, messageIndex);
    final now = DateTime.now().millisecondsSinceEpoch;
    final user = ChatMessage(
      id: newId(),
      role: MessageRole.user,
      content: content,
      attachments: files,
      thinking: settings.thinking && model.thinking,
      search: settings.search && model.search,
      createdAt: now,
    );
    truncated.add(user);
    conversation.messages
      ..clear()
      ..addAll(truncated);
    conversation.updatedAt = now;
    await repository.replaceMessages(conversation.id, conversation.messages);
    await repository.saveConversation(conversation);
    final assistant = await _startAssistant(
      conversation: conversation,
      thinking: user.thinking,
      search: user.search,
    );
    notifyListeners();
    if (assistant != null) {
      await _runStream(
        conversation: conversation,
        assistant: assistant,
        user: user,
        thinking: user.thinking,
        search: user.search,
        wantTitle: false,
        prefill: null,
      );
    }
  }

  Future<void> continueGeneration(int messageIndex) async {
    if (isStreaming) return;
    final conversation = active;
    if (conversation == null) return;
    if (messageIndex < 0 || messageIndex >= conversation.messages.length) return;
    final assistant = conversation.messages[messageIndex];
    final variant = assistant.variant;
    if (variant == null || variant.content.isEmpty) return;
    final provider = settings.activeProvider;
    final model = settings.activeModel;
    if (provider == null || model == null) return;
    if (!provider.type.supportsPrefill) return;
    ChatMessage? user;
    for (var i = messageIndex - 1; i >= 0; i--) {
      if (conversation.messages[i].isUser) {
        user = conversation.messages[i];
        break;
      }
    }
    if (user == null) return;
    variant.status = MessageStatus.streaming;
    variant.error = null;
    notifyListeners();
    await _runStream(
      conversation: conversation,
      assistant: assistant,
      user: user,
      thinking: assistant.thinking && model.thinking,
      search: assistant.search && model.search,
      wantTitle: false,
      prefill: variant.content,
    );
  }

  Future<void> selectVariant(int messageIndex, int delta) async {
    final conversation = active;
    if (conversation == null) return;
    if (messageIndex < 0 || messageIndex >= conversation.messages.length) return;
    final message = conversation.messages[messageIndex];
    if (message.variants.length < 2) return;
    message.activeVariant =
        (message.activeVariant + delta) % message.variants.length;
    if (message.activeVariant < 0) {
      message.activeVariant += message.variants.length;
    }
    notifyListeners();
    await repository.saveMessage(conversation.id, messageIndex, message);
  }

  Future<void> setFeedback(int messageIndex, int value) async {
    final conversation = active;
    if (conversation == null) return;
    if (messageIndex < 0 || messageIndex >= conversation.messages.length) return;
    final message = conversation.messages[messageIndex];
    final variant = message.variant;
    if (variant == null) return;
    variant.feedback = variant.feedback == value ? 0 : value;
    notifyListeners();
    await repository.saveMessage(conversation.id, messageIndex, message);
  }

  List<ChatTurn> _historyBefore(Conversation conversation, int userIndex) {
    final result = <ChatTurn>[];
    for (var i = 0; i < userIndex; i++) {
      final message = conversation.messages[i];
      if (message.isUser) {
        // 只保留「提问 + 有效回答」成对的轮次。
        if (i + 1 >= userIndex) continue;
        final reply = conversation.messages[i + 1];
        if (reply.isUser) continue;
        final variant = reply.variant;
        if (variant == null ||
            (variant.status != MessageStatus.done && variant.status != MessageStatus.stopped) ||
            variant.content.trim().isEmpty) {
          continue;
        }
        result.add(ChatTurn(
          role: MessageRole.user,
          text: message.content,
          attachments: message.attachments,
        ));
        result.add(ChatTurn(role: MessageRole.assistant, text: variant.content));
        i++;
      }
    }
    return result;
  }

  Future<void> _runStream({
    required Conversation conversation,
    required ChatMessage assistant,
    required ChatMessage user,
    required bool thinking,
    required bool search,
    required bool wantTitle,
    required String? prefill,
  }) async {
    final provider = settings.activeProvider;
    final model = settings.activeModel;
    final variant = assistant.variant;
    if (provider == null || model == null || variant == null) return;
    final api = apiFor(provider.type);
    final token = CancelToken();
    final epoch = _dataEpoch;
    _token = token;
    streamingConversationId = conversation.id;
    searchPhase = null;
    variant.status = MessageStatus.streaming;
    variant.error = null;
    final startedAt = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();

    try {
      var prepared = List<Attachment>.from(user.attachments);
      if (provider.type == ProviderType.deepseek) {
        for (var i = 0; i < prepared.length; i++) {
          final attachment = prepared[i];
          if (attachment.serverId != null || attachment.localPath == null) continue;
          final uploaded = await api.uploadAttachment(provider, attachment, token);
          prepared[i] = uploaded;
          final attachmentIndex = user.attachments.indexWhere((item) => item.id == attachment.id);
          if (attachmentIndex >= 0) {
            user.attachments[attachmentIndex] = uploaded;
          }
        }
        if (!token.cancelled && prepared.isNotEmpty) {
          await repository.saveMessage(
            conversation.id,
            conversation.messages.indexOf(user),
            user,
          );
        }
      }
      if (token.cancelled) {
        variant.status = MessageStatus.stopped;
        return;
      }
      final userIndex = conversation.messages.indexOf(user);
      final request = ChatRequest(
        provider: provider,
        model: model,
        systemPrompt: settings.effectiveSystemPrompt,
        history: _historyBefore(conversation, userIndex),
        userText: user.content,
        attachments: prepared,
        thinking: thinking,
        search: search,
        wantTitle: wantTitle,
        prefill: prefill,
      );
      var firstTextAt = 0;
      await for (final event in api.stream(request, token)) {
        switch (event) {
          case TextDelta():
            if (firstTextAt == 0) {
              firstTextAt = DateTime.now().millisecondsSinceEpoch;
              if (variant.reasoning.isNotEmpty && variant.reasoningSeconds == null) {
                variant.reasoningSeconds =
                    ((firstTextAt - startedAt) / 1000).round().clamp(1, 9999).toInt();
              }
            }
            variant.content += event.text;
            searchPhase = null;
            break;
          case ReasoningDelta():
            variant.reasoning += event.text;
            break;
          case CitationEvent():
            final exists = variant.citations.any((item) => item.url == event.citation.url);
            if (!exists) {
              variant.citations.add(event.citation);
            }
            break;
          case SearchStatusEvent():
            searchPhase = event.phase.name;
            if (event.phase == SearchPhase.reading) {
              variant.didBrowsePage = true;
            }
            break;
          case TitleEvent():
            if (conversation.titleAuto) {
              conversation.title = event.title;
              conversation.titleAuto = false;
            }
            break;
          case UsageEvent():
            variant.usage = event.usage;
            break;
          case DoneEvent():
            variant.stopReason = event.stopReason;
            break;
        }
        conversation.updatedAt = DateTime.now().millisecondsSinceEpoch;
        _scheduleSave(conversation, assistant);
        notifyListeners();
        if (event is DoneEvent) break;
      }
      if (variant.status == MessageStatus.streaming) {
        variant.status = token.cancelled ? MessageStatus.stopped : MessageStatus.done;
      }
      if (variant.reasoning.isNotEmpty && variant.reasoningSeconds == null) {
        variant.reasoningSeconds = ((((firstTextAt == 0
                            ? DateTime.now().millisecondsSinceEpoch
                            : firstTextAt) -
                        startedAt) /
                    1000)
                .round()
                .clamp(1, 9999))
            .toInt();
      }
    } on ApiException catch (error) {
      if (token.cancelled || error.kind == ApiErrorKind.cancelled) {
        variant.status = MessageStatus.stopped;
      } else if (error.kind == ApiErrorKind.interrupted && variant.status == MessageStatus.done) {
        // 已正常结束。
      } else {
        variant.status = MessageStatus.error;
        variant.error = error.message;
      }
    } catch (error) {
      if (token.cancelled) {
        variant.status = MessageStatus.stopped;
      } else {
        variant.status = MessageStatus.error;
        variant.error = error.toString();
      }
    } finally {
      searchPhase = null;
      if (variant.status == MessageStatus.streaming) {
        variant.status = token.cancelled ? MessageStatus.stopped : MessageStatus.done;
      }
      streamingConversationId = null;
      _token = null;
      _saveTimer?.cancel();
      _saveTimer = null;
      final stale = epoch != _dataEpoch || _deletedIds.contains(conversation.id);
      if (!stale) {
        conversation.updatedAt = DateTime.now().millisecondsSinceEpoch;
        final index = conversation.messages.indexOf(assistant);
        if (index >= 0) {
          await repository.saveMessage(conversation.id, index, assistant);
        }
        await repository.saveConversation(conversation);
      }
      summaries = await repository.listConversations();
      notifyListeners();
    }
  }

  void _scheduleSave(Conversation conversation, ChatMessage message) {
    final epoch = _dataEpoch;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), () {
      if (epoch != _dataEpoch) return;
      if (_deletedIds.contains(conversation.id)) return;
      final index = conversation.messages.indexOf(message);
      if (index >= 0) {
        repository.saveMessage(conversation.id, index, message);
      }
      repository.saveConversation(conversation);
    });
  }

  Future<String?> transcribe(String filePath) async {
    final provider = settings.activeProvider;
    if (provider == null) throw ChatException(settings.l10n.provider);
    final api = apiFor(provider.type);
    final token = CancelToken();
    try {
      return await api.transcribe(provider, filePath, token);
    } finally {
      token.cancel();
    }
  }

  @override
  void dispose() {
    _token?.cancel();
    _saveTimer?.cancel();
    _draftTimer?.cancel();
    super.dispose();
  }
}
