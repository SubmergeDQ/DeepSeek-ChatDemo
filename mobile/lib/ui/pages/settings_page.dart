import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../core/ext.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/settings_store.dart';
import '../../models/models.dart';
import '../../services/backup_service.dart';
import '../../services/update_service.dart';
import '../../state/chat_controller.dart';
import '../widgets/common.dart';
import '../widgets/model_picker.dart';
import 'provider_edit_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _checkingUpdate = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final controller = context.watch<ChatController>();
    final l10n = settings.l10n;
    final scheme = context.scheme;
    final activeProvider = settings.activeProvider;
    final activeModel = settings.activeModel;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBackground = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF5F6F8);

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: pageBackground,
        centerTitle: true,
        title: Text(l10n.settings),
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? scheme.surface : Colors.white,
              foregroundColor: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          SectionHeader(l10n.apiAndModels),
          SettingsCard(
            children: [
              for (final provider in settings.providers)
                _ProviderTile(
                  provider: provider,
                  onTap: () => _openProvider(context, provider),
                ),
              ListTile(
                onTap: () => _addProvider(context),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.brand.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_rounded, size: 20, color: AppTheme.brand),
                ),
                title: Text(
                  l10n.addProvider,
                  style: const TextStyle(fontSize: 14.5, color: AppTheme.brand),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              Divider(height: 0.6, indent: 56, endIndent: 16, color: scheme.outlineVariant),
              ListTile(
                onTap: () => showModelPicker(context),
                leading: Icon(
                  Icons.memory_rounded,
                  size: 21,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
                title: Text(
                  activeModel?.name ?? l10n.noModels,
                  style: const TextStyle(fontSize: 14.5),
                ),
                subtitle: Text(
                  activeProvider == null
                      ? ''
                      : '${activeProvider.name} · ${activeModel?.id ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: scheme.onSurface.withValues(alpha: 0.3),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ],
          ),
          SectionHeader(l10n.appSection),
          SettingsCard(
            children: [
              _ValueRow(
                icon: Icons.language_rounded,
                title: l10n.language,
                value: _localeLabel(settings),
                onTap: () => _chooseLanguage(settings),
              ),
              _ValueRow(
                icon: Icons.brightness_6_outlined,
                title: l10n.theme,
                value: _themeLabel(settings),
                onTap: () => _chooseTheme(settings),
              ),
              SwitchListTile(
                value: settings.thinking,
                onChanged: settings.canUseThinking ? settings.setThinking : null,
                title: Text(l10n.deepThink, style: const TextStyle(fontSize: 14.5)),
                subtitle: Text(
                  settings.canUseThinking
                      ? l10n.reasoningContent
                      : '${l10n.notSupported} · ${activeModel?.name ?? ''}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
                secondary: Icon(
                  Icons.psychology_outlined,
                  size: 21,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              SwitchListTile(
                value: settings.search,
                onChanged: settings.canUseSearch ? settings.setSearch : null,
                title: Text(l10n.webSearch, style: const TextStyle(fontSize: 14.5)),
                subtitle: Text(
                  settings.canUseSearch ? l10n.sources : l10n.notSupported,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
                secondary: Icon(
                  Icons.travel_explore_rounded,
                  size: 21,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              ListTile(
                onTap: () => _editSystemPrompt(settings),
                leading: Icon(
                  Icons.tune_rounded,
                  size: 21,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
                title: Text(l10n.systemPrompt, style: const TextStyle(fontSize: 14.5)),
                subtitle: Text(
                  settings.systemPrompt.isEmpty ? l10n.systemPromptHint : settings.systemPrompt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: scheme.onSurface.withValues(alpha: 0.3),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ],
          ),
          SectionHeader(l10n.voiceSection),
          SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.record_voice_over_outlined,
                          size: 19,
                          color: scheme.onSurface.withValues(alpha: 0.55),
                        ),
                        const SizedBox(width: 12),
                        Text(l10n.readAloud, style: const TextStyle(fontSize: 14.5)),
                        const Spacer(),
                        Text(
                          '${(settings.ttsRate * 100).round()}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: settings.ttsRate.clamp(0.2, 0.9),
                      min: 0.2,
                      max: 0.9,
                      divisions: 7,
                      label: '${(settings.ttsRate * 100).round()}%',
                      onChanged: settings.setTtsRate,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SectionHeader(l10n.dataSection),
          SettingsCard(
            children: [
              SettingsTile(
                leading: Icon(
                  Icons.ios_share_rounded,
                  size: 20,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
                title: l10n.exportData,
                subtitle: controller.summaries.isEmpty ? l10n.noSessions : 'JSON',
                onTap: () => _export(context, controller),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: scheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
              SettingsTile(
                leading: Icon(
                  Icons.download_outlined,
                  size: 20,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
                title: l10n.importData,
                subtitle: l10n.importConfirm,
                onTap: () => _import(context, controller),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: scheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
              SettingsTile(
                leading: Icon(Icons.delete_sweep_outlined, size: 20, color: scheme.error),
                title: l10n.clearAll,
                titleColor: scheme.error,
                subtitle: l10n.clearAllConfirm,
                onTap: () => _clearAll(context, controller),
                showDivider: false,
              ),
            ],
          ),
          SectionHeader(l10n.aboutSection),
          SettingsCard(
            children: [
              ListTile(
                onTap: _checkingUpdate ? null : _checkUpdate,
                leading: Icon(
                  Icons.system_update_outlined,
                  size: 21,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
                title: Text(l10n.checkForUpdates, style: const TextStyle(fontSize: 14.5)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_checkingUpdate)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.8),
                      )
                    else
                      Text(
                        AppInfo.version,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurface.withValues(alpha: 0.42),
                        ),
                      ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 19,
                      color: scheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ],
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              SettingsTile(
                leading: Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
                title: l10n.serviceAgreement,
                onTap: () => _openUrl(AppInfo.licenseUrl),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: scheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
              SettingsTile(
                leading: Icon(
                  Icons.help_outline_rounded,
                  size: 20,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
                title: l10n.helpFeedback,
                onTap: () => _openUrl(AppInfo.feedbackUrl),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: scheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
              SettingsTile(
                leading: Icon(
                  Icons.code_rounded,
                  size: 20,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
                title: l10n.openRepository,
                subtitle: AppInfo.repo,
                onTap: () => _openUrl(AppInfo.repoUrl),
                trailing: Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: scheme.onSurface.withValues(alpha: 0.3),
                ),
                showDivider: false,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Column(
              children: [
                Text(
                  'DeepChat ${AppInfo.version}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.38),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  l10n.disclaimer,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: scheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _localeLabel(SettingsStore settings) {
    switch (settings.localePref) {
      case 'zh':
        return '简体中文';
      case 'en':
        return 'English';
      default:
        return settings.l10n.languageSystem;
    }
  }

  String _themeLabel(SettingsStore settings) {
    switch (settings.themePref) {
      case 'light':
        return settings.l10n.themeLight;
      case 'dark':
        return settings.l10n.themeDark;
      default:
        return settings.l10n.themeSystem;
    }
  }

  Future<void> _chooseLanguage(SettingsStore settings) async {
    final l10n = settings.l10n;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.language, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            for (final option in [
              ('system', l10n.languageSystem),
              ('zh', '简体中文'),
              ('en', 'English'),
            ])
              ListTile(
                title: Text(option.$2, style: const TextStyle(fontSize: 14.5)),
                trailing: settings.localePref == option.$1
                    ? const Icon(Icons.check_rounded, size: 19, color: AppTheme.brand)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option.$1),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) settings.setLocale(selected);
  }

  Future<void> _chooseTheme(SettingsStore settings) async {
    final l10n = settings.l10n;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.theme, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            for (final option in [
              ('system', l10n.themeSystem),
              ('light', l10n.themeLight),
              ('dark', l10n.themeDark),
            ])
              ListTile(
                title: Text(option.$2, style: const TextStyle(fontSize: 14.5)),
                trailing: settings.themePref == option.$1
                    ? const Icon(Icons.check_rounded, size: 19, color: AppTheme.brand)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option.$1),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) settings.setTheme(selected);
  }

  Future<void> _checkUpdate() async {
    setState(() => _checkingUpdate = true);
    final l10n = context.l10n;
    try {
      final release = await UpdateService().fetchLatest();
      if (!mounted) return;
      if (release == null) {
        showToast(context, l10n.checkUpdateFailed);
        return;
      }
      if (!UpdateService.isNewer(release)) {
        showToast(context, '${l10n.alreadyLatest}（${AppInfo.version}）');
        return;
      }
      final action = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${l10n.newVersionFound} ${release.tagName}'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Text(
                release.body.trim().isEmpty ? release.htmlUrl : release.body,
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop('download'),
              child: Text(l10n.downloadUpdate),
            ),
          ],
        ),
      );
      if (action == 'download') {
        await _openUrl(release.apkUrl ?? release.htmlUrl);
      }
    } catch (error) {
      if (mounted) showToast(context, '${l10n.checkUpdateFailed}：$error');
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) showToast(context, context.l10n.openLinkFailed);
    }
  }

  Future<void> _openProvider(BuildContext context, ProviderConfig provider) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProviderEditPage(provider: provider, isNew: false),
      ),
    );
  }

  Future<void> _addProvider(BuildContext context) async {
    final l10n = context.l10n;
    final choice = await showModalBottomSheet<ProviderType>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                l10n.addProvider,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.blur_on_rounded),
              title: Text(l10n.openaiCompatible),
              subtitle: const Text(
                'OpenAI / Moonshot / 智谱 / 硅基流动 / Ollama …',
                style: TextStyle(fontSize: 11.5),
              ),
              onTap: () => Navigator.of(sheetContext).pop(ProviderType.openai),
            ),
            ListTile(
              leading: const Icon(Icons.spa_outlined),
              title: const Text('Anthropic'),
              subtitle: const Text('Claude Messages API', style: TextStyle(fontSize: 11.5)),
              onTap: () => Navigator.of(sheetContext).pop(ProviderType.anthropic),
            ),
            ListTile(
              leading: const Icon(Icons.diamond_outlined),
              title: const Text('Google Gemini'),
              subtitle: const Text('generateContent API', style: TextStyle(fontSize: 11.5)),
              onTap: () => Navigator.of(sheetContext).pop(ProviderType.gemini),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('DeepSeek'),
              subtitle: const Text('Anthropic 兼容协议', style: TextStyle(fontSize: 11.5)),
              onTap: () => Navigator.of(sheetContext).pop(ProviderType.deepseek),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final defaults = switch (choice) {
      ProviderType.deepseek => 'https://api.deepseek.com',
      ProviderType.openai => 'https://api.openai.com/v1',
      ProviderType.anthropic => 'https://api.anthropic.com/v1',
      ProviderType.gemini => 'https://generativelanguage.googleapis.com/v1beta',
    };
    final provider = ProviderConfig(
      id: newId(),
      name: context.l10n.customProvider,
      type: choice,
      baseUrl: defaults,
      models: [],
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProviderEditPage(provider: provider, isNew: true),
      ),
    );
  }

  Future<void> _editSystemPrompt(SettingsStore settings) async {
    final text = TextEditingController(text: settings.systemPrompt);
    final l10n = context.l10n;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.systemPrompt),
        content: TextField(
          controller: text,
          minLines: 4,
          maxLines: 8,
          decoration: InputDecoration(hintText: l10n.systemPromptHint),
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
    if (result != null) settings.setSystemPrompt(result.trim());
  }

  Future<void> _export(BuildContext context, ChatController controller) async {
    final l10n = context.l10n;
    try {
      final conversations = await controller.loadAllForExport();
      if (conversations.isEmpty) {
        if (context.mounted) showToast(context, l10n.noSessions);
        return;
      }
      if (!context.mounted) return;
      await context.read<BackupService>().export(conversations);
    } catch (error) {
      if (context.mounted) showToast(context, '${l10n.exportFailed}：$error');
    }
  }

  Future<void> _import(BuildContext context, ChatController controller) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.importData,
      message: l10n.importConfirm,
    );
    if (!confirmed || !context.mounted) return;
    try {
      final conversations = await context.read<BackupService>().pickAndRead();
      if (conversations.isEmpty) return;
      await controller.replaceAll(conversations);
      if (context.mounted) showToast(context, l10n.importSuccess);
    } catch (error) {
      if (context.mounted) showToast(context, '${l10n.importFailed}：$error');
    }
  }

  Future<void> _clearAll(BuildContext context, ChatController controller) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.clearAll,
      message: l10n.clearAllConfirm,
      confirmText: l10n.delete,
      destructive: true,
    );
    if (!confirmed) return;
    await controller.clearAll();
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Icon(icon, size: 21, color: scheme.onSurface.withValues(alpha: 0.55)),
          title: Text(title, style: const TextStyle(fontSize: 14.5)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurface.withValues(alpha: 0.42),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: scheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        Divider(
          height: 0.6,
          indent: 56,
          endIndent: 16,
          color: scheme.outlineVariant,
        ),
      ],
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.provider, required this.onTap});

  final ProviderConfig provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final configured = provider.apiKey.trim().isNotEmpty;
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              provider.type.icon,
              size: 18,
              color: scheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  provider.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5),
                ),
              ),
              if (provider.builtin)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    context.l10n.builtinProvider,
                    style: TextStyle(
                      fontSize: 9,
                      color: scheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: configured
                      ? const Color(0xFF34C759)
                      : scheme.onSurface.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  configured
                      ? '${provider.models.length} ${context.l10n.models}'
                      : context.l10n.noApiKeyForProvider,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            size: 19,
            color: scheme.onSurface.withValues(alpha: 0.3),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        Divider(
          height: 0.6,
          indent: 62,
          endIndent: 14,
          color: scheme.outlineVariant,
        ),
      ],
    );
  }
}
