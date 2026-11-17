import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/settings_store.dart';
import 'l10n.dart';

extension BuildContextX on BuildContext {
  L10n get l10n => Provider.of<SettingsStore>(this, listen: false).l10n;

  bool get zh => Provider.of<SettingsStore>(this, listen: false).zh;

  ColorScheme get scheme => Theme.of(this).colorScheme;
}
