import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/ext.dart';
import '../core/theme.dart';
import '../data/settings_store.dart';
import '../models/models.dart';
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
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                children: [
                  _TopBar(
                    modelName: model?.name ?? l10n.selectModel,
                    providerName: provider?.name ?? '',
                    onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                    onModel: () => showModelPicker(context, onManage: _openSettings),
                    onNewChat: _newChat,
                    onMore: () => _showMoreMenu(context),
                    hasConversation: hasMessages,
                  ),
                  Expanded(
                    child: hasMessages && conversation != null
                        ? MessageList(
                            controller: controller,
                            conversation: conversation,
                          )
                        : WelcomeView(
                            modelName: model?.name ?? l10n.selectModel,
                            onSuggestion: _sendSuggestion,
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

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
    );
  }

  Future<void> _sendSuggestion(String text) async {
    final controller = context.read<ChatController>();
    try {
      await controller.send(text);
    } on ChatException catch (error) {
      if (!mounted) return;
      showToast(context, error.message);
    } catch (error) {
      if (!mounted) return;
      showToast(context, error.toString());
    }
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
    required this.modelName,
    required this.providerName,
    required this.onMenu,
    required this.onModel,
    required this.onNewChat,
    required this.onMore,
    required this.hasConversation,
  });

  final String modelName;
  final String providerName;
  final VoidCallback onMenu;
  final VoidCallback onModel;
  final VoidCallback onNewChat;
  final VoidCallback onMore;
  final bool hasConversation;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: onMenu,
            icon: const Icon(Icons.menu_rounded, size: 23),
            color: scheme.onSurface.withValues(alpha: 0.65),
            tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onModel,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.sizeOf(context).width * 0.5,
                              ),
                              child: Text(
                                modelName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                            if (providerName.isNotEmpty)
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.sizeOf(context).width * 0.5,
                                ),
                                child: Text(
                                  providerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: scheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: scheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: hasConversation ? onMore : null,
            icon: const Icon(Icons.more_horiz_rounded, size: 22),
            color: scheme.onSurface.withValues(alpha: hasConversation ? 0.55 : 0.2),
          ),
          IconButton(
            onPressed: onNewChat,
            icon: const Icon(Icons.edit_square, size: 21),
            color: scheme.onSurface.withValues(alpha: 0.55),
            tooltip: context.l10n.newChat,
          ),
        ],
      ),
    );
  }
}
