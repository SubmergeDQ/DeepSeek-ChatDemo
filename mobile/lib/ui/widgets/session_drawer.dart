import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_info.dart';
import '../../core/ext.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/settings_store.dart';
import '../../models/models.dart';
import '../../state/chat_controller.dart';
import 'common.dart';
import 'model_picker.dart';

class SessionDrawer extends StatefulWidget {
  const SessionDrawer({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  State<SessionDrawer> createState() => _SessionDrawerState();
}

class _SessionDrawerState extends State<SessionDrawer> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    final settings = context.watch<SettingsStore>();
    final l10n = settings.l10n;
    final scheme = context.scheme;
    final groups = <String, List<ConversationSummary>>{};
    final now = DateTime.now();
    for (final summary in controller.summaries) {
      if (_query.isNotEmpty && !summary.displayTitle.toLowerCase().contains(_query.toLowerCase())) {
        continue;
      }
      final label = dateGroupLabel(summary.updatedAtTime, now, zh: settings.zh);
      groups.putIfAbsent(label, () => []).add(summary);
    }
    final provider = settings.activeProvider;
    final model = settings.activeModel;
    final configured = provider?.apiKey.trim().isNotEmpty ?? false;

    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.84,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value.trim()),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: l10n.searchSessions,
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 19,
                    color: scheme.onSurface.withValues(alpha: 0.38),
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => showModelPicker(
                    context,
                    onManage: () {
                      Navigator.of(context).pop();
                      widget.onOpenSettings();
                    },
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.memory_rounded,
                          size: 15,
                          color: scheme.onSurface.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.currentModel,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.42),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            configured ? (model?.name ?? l10n.selectModel) : l10n.selectModel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: configured
                                  ? AppTheme.brand
                                  : scheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 17,
                          color: scheme.onSurface.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: groups.isEmpty
                  ? EmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: _query.isEmpty ? l10n.noSessions : l10n.noSessions,
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 8),
                      children: [
                        for (final entry in groups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: scheme.onSurface.withValues(alpha: 0.42),
                              ),
                            ),
                          ),
                          for (final summary in entry.value)
                            _SessionRow(
                              summary: summary,
                              active: controller.active?.id == summary.id,
                              onTap: () async {
                                final navigator = Navigator.of(context);
                                await controller.openConversation(summary.id);
                                navigator.pop();
                              },
                              onLongPress: () => _showSessionActions(context, controller, summary),
                            ),
                        ],
                      ],
                    ),
            ),
            Divider(height: 0.6, color: scheme.outlineVariant),
            InkWell(
              onTap: widget.onOpenSettings,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 6, 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: scheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 18,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.localUser,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        size: 20,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                      onSelected: (value) {
                        if (value == 'settings') {
                          widget.onOpenSettings();
                        } else if (value == 'about') {
                          showAboutDialog(
                            context: context,
                            applicationName: 'DeepChat',
                            applicationVersion: AppInfo.version,
                            children: [
                              Text(l10n.disclaimer),
                            ],
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'settings',
                          child: Text(l10n.settings, style: const TextStyle(fontSize: 14)),
                        ),
                        PopupMenuItem(
                          value: 'about',
                          child: Text(l10n.about, style: const TextStyle(fontSize: 14)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSessionActions(
    BuildContext context,
    ChatController controller,
    ConversationSummary summary,
  ) async {
    final l10n = context.l10n;
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
                _rename(context, controller, summary);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, size: 20, color: context.scheme.error),
              title: Text(
                l10n.delete,
                style: TextStyle(color: context.scheme.error),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _delete(context, controller, summary);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    ChatController controller,
    ConversationSummary summary,
  ) async {
    final text = TextEditingController(text: summary.displayTitle);
    final l10n = context.l10n;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.rename),
        content: TextField(
          controller: text,
          autofocus: true,
          maxLength: 60,
          decoration: InputDecoration(hintText: l10n.providerName),
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
    if (result != null && result.trim().isNotEmpty) {
      await controller.renameConversation(summary.id, result);
    }
  }

  Future<void> _delete(
    BuildContext context,
    ChatController controller,
    ConversationSummary summary,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.delete,
      message: context.l10n.deleteConversationConfirm,
      confirmText: context.l10n.delete,
      destructive: true,
    );
    if (confirmed) {
      await controller.deleteConversation(summary.id);
    }
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.summary,
    required this.active,
    required this.onTap,
    required this.onLongPress,
  });

  final ConversationSummary summary;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: double.infinity,
        color: active ? AppTheme.brand.withValues(alpha: 0.07) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Text(
          summary.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15.5,
            color: active ? AppTheme.brand : scheme.onSurface,
            fontWeight: active ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
