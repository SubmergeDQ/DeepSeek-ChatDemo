import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ext.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/settings_store.dart';
import '../../models/models.dart';
import '../../state/chat_controller.dart';
import 'common.dart';

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
    final groups = <String, List<ConversationSummary>>{};
    final now = DateTime.now();
    for (final summary in controller.summaries) {
      if (_query.isNotEmpty && !summary.displayTitle.toLowerCase().contains(_query.toLowerCase())) {
        continue;
      }
      final label = dateGroupLabel(summary.updatedAtTime, now, zh: settings.zh);
      groups.putIfAbsent(label, () => []).add(summary);
    }
    final scheme = context.scheme;
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.84,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(22)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
              child: Row(
                children: [
                  const Logo(size: 30, radius: 9),
                  const SizedBox(width: 9),
                  Text(
                    'DeepChat',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onOpenSettings();
                    },
                    icon: const Icon(Icons.settings_outlined, size: 21),
                    color: scheme.onSurface.withValues(alpha: 0.55),
                    tooltip: l10n.settings,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                width: double.infinity,
                height: 42,
                child: FilledButton.icon(
                  onPressed: () {
                    if (controller.isStreaming) {
                      controller.stop();
                    }
                    controller.newConversation();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: Text(l10n.newChat),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value.trim()),
                style: const TextStyle(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: l10n.searchSessions,
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: scheme.onSurface.withValues(alpha: 0.4)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
              ),
            ),
            Expanded(
              child: groups.isEmpty
                  ? EmptyState(icon: Icons.chat_bubble_outline_rounded, title: l10n.noSessions)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                      children: [
                        for (final entry in groups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 14, 10, 4),
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                          for (final summary in entry.value)
                            _SessionTile(
                              summary: summary,
                              active: controller.active?.id == summary.id,
                              onTap: () async {
                                final navigator = Navigator.of(context);
                                await controller.openConversation(summary.id);
                                navigator.pop();
                              },
                              onRename: () => _rename(context, controller, summary),
                              onDelete: () => _delete(context, controller, summary),
                            ),
                        ],
                      ],
                    ),
            ),
            Divider(height: 0.6, color: scheme.outlineVariant),
            ListTile(
              onTap: () {
                Navigator.of(context).pop();
                widget.onOpenSettings();
              },
              leading: Icon(Icons.settings_outlined, size: 20, color: scheme.onSurface.withValues(alpha: 0.55)),
              title: Text(l10n.settings, style: const TextStyle(fontSize: 14.5)),
              dense: true,
              trailing: Icon(Icons.chevron_right_rounded, size: 19, color: scheme.onSurface.withValues(alpha: 0.3)),
            ),
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

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.summary,
    required this.active,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final ConversationSummary summary;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Material(
      color: active ? AppTheme.brand.withValues(alpha: 0.09) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 2, 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  summary.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: active ? AppTheme.brand : scheme.onSurface.withValues(alpha: 0.82),
                    fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'rename') onRename();
                  if (value == 'delete') onDelete();
                },
                icon: Icon(
                  Icons.more_horiz_rounded,
                  size: 18,
                  color: scheme.onSurface.withValues(alpha: 0.35),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    height: 40,
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, size: 17),
                        const SizedBox(width: 8),
                        Text(context.l10n.rename, style: const TextStyle(fontSize: 13.5)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    height: 40,
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 17, color: scheme.error),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.delete,
                          style: TextStyle(fontSize: 13.5, color: scheme.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
