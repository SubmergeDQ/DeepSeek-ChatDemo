import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ext.dart';
import '../../core/theme.dart';
import '../../data/settings_store.dart';
import '../../models/models.dart';
import '../../services/api/chat_api.dart';
import '../widgets/common.dart';

class ProviderEditPage extends StatefulWidget {
  const ProviderEditPage({
    super.key,
    required this.provider,
    required this.isNew,
  });

  final ProviderConfig provider;
  final bool isNew;

  @override
  State<ProviderEditPage> createState() => _ProviderEditPageState();
}

class _ProviderEditPageState extends State<ProviderEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  late ProviderType _type;
  late List<ModelInfo> _models;
  bool _obscure = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.provider.name);
    _baseUrl = TextEditingController(text: widget.provider.baseUrl);
    _apiKey = TextEditingController(text: widget.provider.apiKey);
    _type = widget.provider.type;
    _models = List<ModelInfo>.from(widget.provider.models);
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  ProviderConfig _draft() => ProviderConfig(
        id: widget.provider.id,
        name: _name.text.trim(),
        type: _type,
        baseUrl: _baseUrl.text.trim(),
        apiKey: _apiKey.text.trim(),
        models: _models,
        builtin: widget.provider.builtin,
      );

  Future<void> _save() async {
    final l10n = context.l10n;
    final name = _name.text.trim();
    final baseUrl = _baseUrl.text.trim();
    if (name.isEmpty) {
      showToast(context, l10n.providerName);
      return;
    }
    if (baseUrl.isEmpty || !baseUrl.startsWith('http')) {
      showToast(context, l10n.baseUrl);
      return;
    }
    if (_models.isEmpty) {
      showToast(context, l10n.noModels);
      return;
    }
    final provider = ProviderConfig(
      id: widget.provider.id,
      name: name,
      type: _type,
      baseUrl: baseUrl,
      apiKey: _apiKey.text.trim(),
      models: _models,
      builtin: widget.provider.builtin,
    );
    context.read<SettingsStore>().upsertProvider(provider);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _chooseType() async {
    final l10n = context.l10n;
    final selected = await showModalBottomSheet<ProviderType>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                l10n.selectProviderType,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            for (final type in ProviderType.values)
              ListTile(
                leading: Icon(type.icon),
                title: Text(type.label),
                trailing: _type == type
                    ? const Icon(Icons.check_rounded, size: 19, color: AppTheme.brand)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(type),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _type = selected);
    }
  }

  Future<void> _fetchModels({bool testOnly = false}) async {
    final l10n = context.l10n;
    if (_apiKey.text.trim().isEmpty) {
      showToast(context, l10n.apiKeyRequired);
      return;
    }
    setState(() => _busy = true);
    try {
      final models = await apiFor(_type).fetchModels(_draft());
      if (!mounted) return;
      if (models.isEmpty) {
        showToast(context, l10n.modelListEmpty);
        return;
      }
      if (testOnly) {
        showToast(context, '${l10n.connectionOk} · ${models.length} ${l10n.models}');
        return;
      }
      setState(() => _models = models);
      showToast(context, '${l10n.modelsFetched}（${models.length}）');
    } catch (error) {
      if (!mounted) return;
      showToast(
        context,
        '${testOnly ? l10n.connectionFailed : l10n.fetchModels}：$error',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editModel([ModelInfo? existing]) async {
    final idController = TextEditingController(text: existing?.id ?? '');
    final nameController = TextEditingController(text: existing?.name ?? '');
    var vision = existing?.vision ?? false;
    var thinking = existing?.thinking ?? false;
    var search = existing?.search ?? false;
    final l10n = context.l10n;
    final result = await showDialog<ModelInfo>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? l10n.addModel : l10n.modelId),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: idController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.modelId,
                    hintText: 'deepseek-chat',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: l10n.modelName,
                    hintText: 'DeepSeek Chat',
                  ),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  value: vision,
                  onChanged: (value) => setDialogState(() => vision = value),
                  title: Text(l10n.photo, style: const TextStyle(fontSize: 14)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                SwitchListTile(
                  value: thinking,
                  onChanged: (value) => setDialogState(() => thinking = value),
                  title: Text(l10n.deepThink, style: const TextStyle(fontSize: 14)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                if (_type == ProviderType.deepseek)
                  SwitchListTile(
                    value: search,
                    onChanged: (value) => setDialogState(() => search = value),
                    title: Text(l10n.webSearch, style: const TextStyle(fontSize: 14)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                final id = idController.text.trim();
                if (id.isEmpty) return;
                final name = nameController.text.trim().isEmpty
                    ? id
                    : nameController.text.trim();
                Navigator.of(dialogContext).pop(
                  ModelInfo(
                    id: id,
                    name: name,
                    vision: vision,
                    thinking: thinking,
                    search: search,
                  ),
                );
              },
              child: Text(l10n.save, style: const TextStyle(color: AppTheme.brand)),
            ),
          ],
        ),
      ),
    );
    idController.dispose();
    nameController.dispose();
    if (result == null) return;
    setState(() {
      final index = _models.indexWhere((model) => model.id == result.id);
      if (index >= 0) {
        _models[index] = result;
      } else {
        _models.add(result);
      }
    });
  }

  Future<void> _deleteProvider() async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteProvider,
      message: l10n.deleteProviderConfirm,
      confirmText: l10n.delete,
      destructive: true,
    );
    if (!confirmed) return;
    if (!mounted) return;
    context.read<SettingsStore>().removeProvider(widget.provider.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.scheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? l10n.addProvider : l10n.editProvider),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: 18),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(
                l10n.save,
                style: const TextStyle(color: AppTheme.brand, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: TextField(
                  controller: _name,
                  decoration: InputDecoration(labelText: l10n.providerName),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: TextField(
                  controller: _baseUrl,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.baseUrl,
                    hintText: _baseUrlHint(_type),
                    helperText: _baseUrlHint(_type),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: TextField(
                  controller: _apiKey,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: l10n.apiKey,
                    hintText: l10n.apiKeyHint,
                    helperText: l10n.apiKeyStoredLocally,
                    helperMaxLines: 2,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ListTile(
                onTap: _chooseType,
                leading: Icon(_type.icon, size: 20, color: scheme.onSurface.withValues(alpha: 0.55)),
                title: Text(l10n.providerType, style: const TextStyle(fontSize: 14.5)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _type.label,
                      style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.55)),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 19, color: scheme.onSurface.withValues(alpha: 0.3)),
                  ],
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _fetchModels(testOnly: true),
                      icon: const Icon(Icons.network_check_rounded, size: 16),
                      label: Text(l10n.testConnection),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(color: scheme.outlineVariant),
                        foregroundColor: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SectionHeader(
            l10n.models,
            trailing: TextButton.icon(
              onPressed: _busy ? null : () => _fetchModels(),
              icon: const Icon(Icons.cloud_download_outlined, size: 16),
              label: Text(l10n.fetchModels, style: const TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ),
          SettingsCard(
            children: [
              if (_models.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    l10n.noModels,
                    style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.45)),
                  ),
                )
              else
                for (var i = 0; i < _models.length; i++)
                  _ModelRow(
                    model: _models[i],
                    showSearch: _type == ProviderType.deepseek,
                    showDivider: i != _models.length - 1,
                    onTap: () => _editModel(_models[i]),
                    onDelete: () => setState(() => _models.removeAt(i)),
                  ),
              ListTile(
                onTap: () => _editModel(),
                leading: const Icon(Icons.add_rounded, size: 20, color: AppTheme.brand),
                title: Text(
                  l10n.addModel,
                  style: const TextStyle(fontSize: 14, color: AppTheme.brand),
                ),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _typeHelp(_type, l10n.zh),
            style: TextStyle(
              fontSize: 12,
              height: 1.55,
              color: scheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
          if (!widget.provider.builtin) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _deleteProvider,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(l10n.deleteProvider),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _baseUrlHint(ProviderType type) {
    switch (type) {
      case ProviderType.deepseek:
        return 'https://api.deepseek.com';
      case ProviderType.openai:
        return 'https://api.openai.com/v1';
      case ProviderType.anthropic:
        return 'https://api.anthropic.com/v1';
      case ProviderType.gemini:
        return 'https://generativelanguage.googleapis.com/v1beta';
    }
  }

  String _typeHelp(ProviderType type, bool zh) {
    switch (type) {
      case ProviderType.deepseek:
        return zh
            ? 'DeepSeek 官方 Anthropic 兼容接口，支持深度思考、联网搜索与文件上传。'
            : 'DeepSeek Anthropic-compatible API with thinking, web search and file upload.';
      case ProviderType.openai:
        return zh
            ? 'OpenAI Chat Completions 协议。接口地址需包含版本段（如 /v1）；适用于 OpenAI、Moonshot、智谱、硅基流动、Groq、Ollama、OpenRouter 等兼容服务。本地 Ollama 等无需鉴权的服务，API Key 填任意非空值即可。'
            : 'OpenAI Chat Completions protocol. Include the version segment (e.g. /v1). Works with OpenAI, Moonshot, SiliconFlow, Groq, Ollama, OpenRouter and more. For local services without auth, enter any non-empty API key.';
      case ProviderType.anthropic:
        return zh
            ? 'Anthropic Messages 协议，支持扩展思考。接口地址通常以 /v1 结尾。'
            : 'Anthropic Messages protocol with extended thinking. The base URL usually ends with /v1.';
      case ProviderType.gemini:
        return zh
            ? 'Google Gemini generateContent 协议，支持思考过程与图片输入。接口地址通常以 /v1beta 结尾。'
            : 'Google Gemini generateContent protocol with thinking and image input. The base URL usually ends with /v1beta.';
    }
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.showSearch,
    required this.showDivider,
    required this.onTap,
    required this.onDelete,
  });

  final ModelInfo model;
  final bool showSearch;
  final bool showDivider;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          title: Text(
            model.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
          subtitle: Row(
            children: [
              Flexible(
                child: Text(
                  model.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: scheme.onSurface.withValues(alpha: 0.4)),
                ),
              ),
              const SizedBox(width: 8),
              if (model.vision) _Tag('图片', color: const Color(0xFF34C759)),
              if (model.thinking) _Tag('思考', color: AppTheme.brand),
              if (showSearch && model.search) _Tag('搜索', color: const Color(0xFFFF9500)),
            ],
          ),
          trailing: IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.close_rounded, size: 16),
            color: scheme.onSurface.withValues(alpha: 0.35),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          dense: true,
        ),
        if (showDivider)
          Divider(height: 0.5, indent: 16, endIndent: 16, color: scheme.outlineVariant),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 9, color: color)),
    );
  }
}
