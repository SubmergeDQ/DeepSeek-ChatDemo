import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/l10n.dart';
import '../models/models.dart';

/// 本机设置：服务商与 Key、默认模型、外观、语言与生成开关。
/// 仅保存在 SharedPreferences，不会上传。
class SettingsStore extends ChangeNotifier {
  static const _key = 'deepchat.settings.v1';
  static const _deepseekSystemPrompt = '该助手为DeepSeek，由深度求索公司创造。';

  SharedPreferences? _prefs;
  bool _loaded = false;

  String localePref = 'system';
  String themePref = 'system';
  List<ProviderConfig> providers = defaultProviders();
  String? activeProviderId;
  String? activeModelId;
  bool thinking = false;
  bool search = false;
  String systemPrompt = '';
  double ttsRate = 0.5;

  bool get loaded => _loaded;

  bool get zh {
    switch (localePref) {
      case 'zh':
        return true;
      case 'en':
        return false;
      default:
        return ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase() == 'zh';
    }
  }

  L10n get l10n => L10n(zh);

  ThemeMode get themeMode {
    switch (themePref) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_key);
    if (raw != null) {
      try {
        final data = jsonDecode(raw);
        if (data is Map<String, dynamic>) {
          localePref = data['localePref'] as String? ?? localePref;
          themePref = data['themePref'] as String? ?? themePref;
          thinking = data['thinking'] as bool? ?? thinking;
          search = data['search'] as bool? ?? search;
          systemPrompt = data['systemPrompt'] as String? ?? systemPrompt;
          ttsRate = (data['ttsRate'] as num?)?.toDouble() ?? ttsRate;
          activeProviderId = data['activeProviderId'] as String?;
          activeModelId = data['activeModelId'] as String?;
          final list = data['providers'];
          if (list is List && list.isNotEmpty) {
            final loadedProviders = list
                .whereType<Map>()
                .map((item) => ProviderConfig.fromJson(Map<String, dynamic>.from(item)))
                .where((item) => item.models.isNotEmpty)
                .toList();
            if (loadedProviders.isNotEmpty) {
              providers = _mergeBuiltins(loadedProviders);
            }
          }
        }
      } catch (_) {
        // 损坏的设置直接使用默认值。
      }
    }
    _ensureActiveModel();
    _loaded = true;
    notifyListeners();
  }

  /// 合并新增的内置服务商，保留用户已填写的 Key 与模型。
  List<ProviderConfig> _mergeBuiltins(List<ProviderConfig> saved) {
    final result = <ProviderConfig>[];
    for (final preset in defaultProviders()) {
      final existing = saved.where((item) => item.id == preset.id).firstOrNull;
      if (existing != null) {
        result.add(existing);
      } else {
        result.add(preset);
      }
    }
    for (final item in saved) {
      if (result.every((preset) => preset.id != item.id)) {
        result.add(item);
      }
    }
    return result;
  }

  void _ensureActiveModel() {
    ProviderConfig? provider;
    for (final item in providers) {
      if (item.id == activeProviderId) {
        provider = item;
        break;
      }
    }
    provider ??= providers.firstOrNull;
    activeProviderId = provider?.id;
    if (provider == null || provider.models.isEmpty) {
      activeModelId = null;
      return;
    }
    final exists = provider.models.any((model) => model.id == activeModelId);
    if (!exists) {
      activeModelId = provider.models.first.id;
    }
  }

  ProviderConfig? get activeProvider {
    for (final item in providers) {
      if (item.id == activeProviderId) return item;
    }
    return providers.firstOrNull;
  }

  ModelInfo? get activeModel {
    final provider = activeProvider;
    if (provider == null) return null;
    for (final item in provider.models) {
      if (item.id == activeModelId) return item;
    }
    return provider.models.firstOrNull;
  }

  String get effectiveSystemPrompt {
    if (systemPrompt.trim().isNotEmpty) return systemPrompt.trim();
    if (activeProvider?.type == ProviderType.deepseek) {
      return _deepseekSystemPrompt;
    }
    return '';
  }

  bool get canUseThinking => activeModel?.thinking ?? false;
  bool get canUseSearch => (activeModel?.search ?? false) && (activeProvider?.type.supportsSearch ?? false);

  Future<void> _save() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'localePref': localePref,
        'themePref': themePref,
        'thinking': thinking,
        'search': search,
        'systemPrompt': systemPrompt,
        'ttsRate': ttsRate,
        'activeProviderId': activeProviderId,
        'activeModelId': activeModelId,
        'providers': providers.map((item) => item.toJson()).toList(),
      }),
    );
  }

  void _commit() {
    _ensureActiveModel();
    notifyListeners();
    _save();
  }

  void setLocale(String value) {
    localePref = value;
    _commit();
  }

  void setTheme(String value) {
    themePref = value;
    _commit();
  }

  void setThinking(bool value) {
    thinking = value;
    _commit();
  }

  void setSearch(bool value) {
    search = value;
    _commit();
  }

  void setSystemPrompt(String value) {
    systemPrompt = value;
    _commit();
  }

  void setTtsRate(double value) {
    ttsRate = value;
    _commit();
  }

  void selectModel(String providerId, String modelId) {
    activeProviderId = providerId;
    activeModelId = modelId;
    _commit();
  }

  void upsertProvider(ProviderConfig provider) {
    final index = providers.indexWhere((item) => item.id == provider.id);
    if (index >= 0) {
      providers[index] = provider;
    } else {
      providers.add(provider);
    }
    activeProviderId ??= provider.id;
    _commit();
  }

  void removeProvider(String id) {
    final target = providers.where((item) => item.id == id).firstOrNull;
    if (target == null || target.builtin) return;
    providers.removeWhere((item) => item.id == id);
    if (activeProviderId == id) {
      activeProviderId = providers.firstOrNull?.id;
      activeModelId = providers.firstOrNull?.models.firstOrNull?.id;
    }
    _commit();
  }

  /// 清空全部对话时保留设置；这里只用于数据管理页的刷新。
  void refresh() => notifyListeners();
}
