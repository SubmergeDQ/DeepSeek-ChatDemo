import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ext.dart';
import '../../core/theme.dart';
import '../../data/settings_store.dart';
import '../../models/models.dart';

Future<void> showModelPicker(
  BuildContext context, {
  VoidCallback? onManage,
}) async {
  final settings = context.read<SettingsStore>();
  final l10n = settings.l10n;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      var query = '';
      return StatefulBuilder(
        builder: (context, setState) {
          final filtered = <(ProviderConfig, List<ModelInfo>)>[];
          for (final provider in settings.providers) {
            // 未填写 API Key 的服务商不进入模型列表，避免误选后无法使用。
            if (provider.apiKey.trim().isEmpty) continue;
            final models = provider.models.where((model) {
              if (query.isEmpty) return true;
              final q = query.toLowerCase();
              return model.name.toLowerCase().contains(q) ||
                  model.id.toLowerCase().contains(q) ||
                  provider.name.toLowerCase().contains(q);
            }).toList();
            if (models.isNotEmpty) {
              filtered.add((provider, models));
            }
          }
          return SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Row(
                    children: [
                      Text(
                        l10n.selectModel,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      if (onManage != null)
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onManage();
                          },
                          child: Text(l10n.providers),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: TextField(
                    onChanged: (value) => setState(() => query = value.trim()),
                    decoration: InputDecoration(
                      hintText: l10n.searchModelsPlaceholder,
                      prefixIcon: const Icon(Icons.search_rounded, size: 19),
                      isDense: true,
                    ),
                  ),
                ),
                Divider(height: 0.6, color: context.scheme.outlineVariant),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.key_off_rounded,
                                  size: 42,
                                  color: context.scheme.onSurface.withValues(alpha: 0.22),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.noApiKeyForProvider,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    color: context.scheme.onSurface.withValues(alpha: 0.65),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (onManage != null)
                                  FilledButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      onManage();
                                    },
                                    icon: const Icon(Icons.settings_outlined, size: 17),
                                    label: Text(l10n.goSettings),
                                  ),
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                          children: [
                            for (final entry in filtered) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      entry.$1.type.icon,
                                      size: 15,
                                      color: context.scheme.onSurface.withValues(alpha: 0.45),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      entry.$1.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: context.scheme.onSurface.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              for (final model in entry.$2)
                                _ModelTile(
                                  provider: entry.$1,
                                  model: model,
                                  selected: settings.activeProvider?.id == entry.$1.id &&
                                      settings.activeModelId == model.id,
                                  onTap: () {
                                    settings.selectModel(entry.$1.id, model.id);
                                    Navigator.of(context).pop();
                                  },
                                ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.provider,
    required this.model,
    required this.selected,
    required this.onTap,
  });

  final ProviderConfig provider;
  final ModelInfo model;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.brand.withValues(alpha: 0.12)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          provider.type.icon,
          size: 17,
          color: selected ? AppTheme.brand : scheme.onSurface.withValues(alpha: 0.45),
        ),
      ),
      title: Text(
        model.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: scheme.onSurface,
        ),
      ),
      subtitle: Text(
        model.id,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11.5, color: scheme.onSurface.withValues(alpha: 0.4)),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, size: 20, color: AppTheme.brand)
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      visualDensity: VisualDensity.compact,
    );
  }
}
