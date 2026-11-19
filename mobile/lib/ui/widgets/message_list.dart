import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/ext.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/settings_store.dart';
import '../../models/models.dart';
import '../../services/speech/speech_service.dart';
import '../../state/chat_controller.dart';
import 'common.dart';
import 'message_item.dart';

class MessageList extends StatefulWidget {
  const MessageList({
    super.key,
    required this.controller,
    required this.conversation,
  });

  final ChatController controller;
  final Conversation conversation;

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final ScrollController _scroll = ScrollController();
  bool _atBottom = true;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _lastCount = widget.conversation.messages.length;
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void didUpdateWidget(covariant MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final count = widget.conversation.messages.length;
    final conversationChanged = oldWidget.conversation.id != widget.conversation.id;
    if (conversationChanged) {
      _lastCount = count;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
      return;
    }
    if (count != _lastCount) {
      _lastCount = count;
      if (_atBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
      }
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final atBottom = _scroll.position.extentAfter < 80;
    if (atBottom != _atBottom) {
      setState(() => _atBottom = atBottom);
    }
  }

  void _jumpToBottom() {
    if (!mounted || !_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  void _animateToBottom() {
    if (!mounted || !_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final conversation = widget.conversation;
    final settings = context.watch<SettingsStore>();
    final speech = context.watch<SpeechService>();
    final messages = conversation.messages;
    final streaming = controller.isActiveStreaming;
    if (streaming && _atBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_scroll.hasClients) {
          final max = _scroll.position.maxScrollExtent;
          if ((max - _scroll.offset).abs() > 4) {
            _scroll.jumpTo(max);
          }
        }
      });
    }
    return Stack(
      children: [
        ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isLast = index == messages.length - 1;
            final messageStreaming = isLast && streaming && !message.isUser;
            final variant = message.variant;
            final canContinue = !message.isUser &&
                isLast &&
                !streaming &&
                (variant?.status == MessageStatus.stopped ||
                    variant?.stopReason == 'max_tokens') &&
                !message.thinking &&
                (variant?.content.trim().isNotEmpty ?? false) &&
                (settings.activeProvider?.type.supportsPrefill ?? false);
            return MessageItem(
              key: ValueKey(message.id),
              message: message,
              index: index,
              isLast: isLast,
              streaming: messageStreaming,
              searchPhase: messageStreaming ? controller.searchPhase : null,
              speaking: speech.speakingId == message.id,
              canContinue: canContinue,
              onCopy: () => _copy(context, message),
              onEdit: () => _edit(context, index, message),
              onRegenerate: () => _regenerate(context, index),
              onReadAloud: () => _readAloud(context, message, variant),
              onShare: () => _share(context, message, variant),
              onContinue: () => _continue(context, index),
              onVariant: (delta) => controller.selectVariant(index, delta),
              onFeedback: (value) => controller.setFeedback(index, value),
            );
          },
        ),
        if (!_atBottom)
          Positioned(
            right: 14,
            bottom: 10,
            child: Material(
              color: context.scheme.surface,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _animateToBottom,
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: context.scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _copy(BuildContext context, ChatMessage message) async {
    final text = message.isUser ? message.content : (message.variant?.content ?? '');
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    showToast(context, context.l10n.copied);
  }

  Future<void> _share(BuildContext context, ChatMessage message, MessageVariant? variant) async {
    final content = message.isUser ? message.content : (variant?.content ?? '');
    if (content.trim().isEmpty) return;
    try {
      await SharePlus.instance.share(ShareParams(text: content));
    } catch (_) {
      if (!context.mounted) return;
      showToast(context, context.l10n.shareFailed);
    }
  }

  Future<void> _readAloud(
    BuildContext context,
    ChatMessage message,
    MessageVariant? variant,
  ) async {
    final speech = context.read<SpeechService>();
    final settings = context.read<SettingsStore>();
    if (speech.speakingId == message.id) {
      await speech.stopSpeaking();
      return;
    }
    final content = variant?.content ?? '';
    if (content.trim().isEmpty) return;
    await speech.speak(
      stripMarkdown(content),
      messageId: message.id,
      zh: settings.zh,
      rate: settings.ttsRate,
      onDone: () {},
    );
  }

  Future<void> _regenerate(BuildContext context, int index) async {
    try {
      await widget.controller.regenerate(index);
    } on ChatException catch (error) {
      if (!context.mounted) return;
      showToast(context, error.message);
    }
  }

  Future<void> _continue(BuildContext context, int index) async {
    await widget.controller.continueGeneration(index);
  }

  Future<void> _edit(BuildContext context, int index, ChatMessage message) async {
    final textController = TextEditingController(text: message.content);
    final l10n = context.l10n;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.edit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: textController,
              autofocus: true,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.editMessageHint,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(dialogContext).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(textController.text),
            child: Text(l10n.save, style: const TextStyle(color: AppTheme.brand)),
          ),
        ],
      ),
    );
    textController.dispose();
    if (result == null) return;
    try {
      await widget.controller.editAndResend(index, result);
    } on ChatException catch (error) {
      if (!context.mounted) return;
      showToast(context, error.message);
    }
  }
}
