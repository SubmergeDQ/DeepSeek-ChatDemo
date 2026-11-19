import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/ext.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../data/settings_store.dart';
import '../models/models.dart';
import '../services/speech/speech_service.dart';
import '../state/chat_controller.dart';
import 'pages/settings_page.dart';
import 'widgets/chat_input.dart';
import 'widgets/common.dart';
import 'widgets/message_list.dart';
import 'widgets/model_picker.dart';
import 'widgets/session_drawer.dart';
import 'widgets/welcome_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final controller = context.watch<ChatController>();
    final l10n = settings.l10n;
    final conversation = controller.active;
    final messages = conversation?.messages ?? const <ChatMessage>[];
    final provider = settings.activeProvider;
    final model = settings.activeModel;
    final hasMessages = messages.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasKey = provider?.apiKey.trim().isNotEmpty ?? false;
    final speech = context.watch<SpeechService>();
    ChatMessage? lastReply;
    for (var i = messages.length - 1; i >= 0; i--) {
      final message = messages[i];
      if (!message.isUser && (message.variant?.content.trim().isNotEmpty ?? false)) {
        lastReply = message;
        break;
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        drawer: SessionDrawer(onOpenSettings: _openSettings),
        drawerEnableOpenDragGesture: true,
        drawerEdgeDragWidth: 48,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                children: [
                  _TopBar(
                    title: conversation?.displayTitle ?? l10n.newChatTitle,
                    canReadAloud: lastReply != null && !controller.isStreaming,
                    speaking: lastReply != null && speech.speakingId == lastReply.id,
                    onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                    onTitleTap: hasMessages ? () => _showMoreMenu(context) : null,
                    onReadAloud: lastReply == null || controller.isStreaming
                        ? null
                        : () => _toggleReadAloud(lastReply!),
                    onNewChat: _newChat,
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragEnd: (details) {
                        final velocity = details.primaryVelocity ?? 0;
                        if (velocity > 250) {
                          _scaffoldKey.currentState?.openDrawer();
                        }
                      },
                      child: hasMessages && conversation != null
                          ? MessageList(
                              controller: controller,
                              conversation: conversation,
                            )
                          : WelcomeView(
                              modelName: hasKey ? (model?.name ?? '') : '',
                              onModelTap: () => showModelPicker(
                                context,
                                onManage: _openSettings,
                              ),
                            ),
                    ),
                  ),
                  if (conversation != null)
                    ChatInput(
                      controller: controller,
                      conversationId: conversation.id,
                      draft: conversation.draft,
                      onOpenSettings: _openSettings,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _newChat() {
    final controller = context.read<ChatController>();
    if (controller.isStreaming) {
      controller.stop();
    }
    controller.newConversation();
  }

  Future<void> _toggleReadAloud(ChatMessage message) async {
    final speech = context.read<SpeechService>();
    final settings = context.read<SettingsStore>();
    if (speech.speakingId == message.id) {
      await speech.stopSpeaking();
      return;
    }
    final content = message.variant?.content ?? '';
    if (content.trim().isEmpty) return;
    await speech.speak(
      stripMarkdown(content),
      messageId: message.id,
      zh: settings.zh,
      rate: settings.ttsRate,
      onDone: () {},
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
    );
  }

  Future<void> _showMoreMenu(BuildContext context) async {
    final controller = context.read<ChatController>();
    final conversation = controller.active;
    final l10n = context.l10n;
    if (conversation == null || conversation.messages.isEmpty) {
      await _openSettings();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, size: 20),
              title: Text(l10n.rename),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _renameConversation(conversation);
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded, size: 20),
              title: Text(l10n.share),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _shareConversation(conversation);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, size: 20),
              title: Text(l10n.delete, style: TextStyle(color: context.scheme.error)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _deleteConversation(conversation);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined, size: 20),
              title: Text(l10n.settings),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openSettings();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _renameConversation(Conversation conversation) async {
    final text = TextEditingController(text: conversation.displayTitle);
    final l10n = context.l10n;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.rename),
        content: TextField(
          controller: text,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(text.text),
            child: Text(l10n.save, style: const TextStyle(color: AppTheme.brand)),
          ),
        ],
      ),
    );
    text.dispose();
    if (result == null || result.trim().isEmpty) return;
    if (!mounted) return;
    await context.read<ChatController>().renameConversation(conversation.id, result);
  }

  Future<void> _shareConversation(Conversation conversation) async {
    final buffer = StringBuffer();
    buffer.writeln('# ${conversation.displayTitle}');
    buffer.writeln();
    for (final message in conversation.messages) {
      final variant = message.variant;
      if (message.isUser) {
        if (message.content.trim().isEmpty) continue;
        buffer.writeln('**${context.l10n.chat}**：');
        buffer.writeln(message.content.trim());
      } else if (variant != null && variant.content.trim().isNotEmpty) {
        buffer.writeln('**DeepChat**：');
        buffer.writeln(variant.content.trim());
      }
      buffer.writeln();
    }
    try {
      await SharePlus.instance.share(
        ShareParams(text: buffer.toString().trim(), subject: conversation.displayTitle),
      );
    } catch (_) {
      if (!mounted) return;
      showToast(context, context.l10n.shareFailed);
    }
  }

  Future<void> _deleteConversation(Conversation conversation) async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.delete,
      message: context.l10n.deleteConversationConfirm,
      confirmText: context.l10n.delete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await context.read<ChatController>().deleteConversation(conversation.id);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.canReadAloud,
    required this.speaking,
    required this.onMenu,
    required this.onTitleTap,
    required this.onReadAloud,
    required this.onNewChat,
  });

  final String title;
  final bool canReadAloud;
  final bool speaking;
  final VoidCallback onMenu;
  final VoidCallback? onTitleTap;
  final VoidCallback? onReadAloud;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 6, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: onMenu,
            icon: const Icon(Icons.menu_rounded, size: 23),
            color: scheme.onSurface.withValues(alpha: 0.75),
            tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
          ),
          Expanded(
            child: InkWell(
              onTap: onTitleTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          if (canReadAloud)
            IconButton(
              onPressed: onReadAloud,
              icon: Icon(
                speaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                size: 22,
              ),
              color: speaking ? AppTheme.brand : scheme.onSurface.withValues(alpha: 0.7),
              tooltip: speaking ? context.l10n.stopReading : context.l10n.readAloud,
            ),
          IconButton(
            onPressed: onNewChat,
            icon: const Icon(Icons.add_comment_outlined, size: 22),
            color: scheme.onSurface.withValues(alpha: 0.7),
            tooltip: context.l10n.newChat,
          ),
        ],
      ),
    );
  }
}
