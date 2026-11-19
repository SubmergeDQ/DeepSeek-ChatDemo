import 'package:flutter/material.dart';

/// DeepChat 品牌色与浅深两套主题，颜色取值对齐官方 chat-demo 的设计令牌。
class AppTheme {
  static const Color brand = Color(0xFF3964FE);
  static const Color brandDark = Color(0xFF5686FE);
  static const Color brandTextDark = Color(0xFF679EFE);
  static const Color bubbleLight = Color(0xFFEDF3FE);
  static const Color bubbleDark = Color(0xFF2C2C2E);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.light,
    ).copyWith(
      primary: brand,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: const Color(0xFF0F1115),
      surfaceContainerHighest: const Color(0xFFF1F3F5),
      outlineVariant: const Color(0xFFE1E5EE),
      error: const Color(0xFFEC1313),
    );
    return _base(scheme, Colors.white);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.dark,
    ).copyWith(
      primary: brandDark,
      onPrimary: Colors.white,
      surface: const Color(0xFF2C2C2E),
      onSurface: const Color(0xFFF9FAFB),
      surfaceContainerHighest: const Color(0xFF353638),
      outlineVariant: const Color(0xFF3A3A3C),
      error: const Color(0xFFF25A5A),
    );
    return _base(scheme, const Color(0xFF151517));
  }

  static ThemeData _base(ColorScheme scheme, Color scaffold) {
    final isDark = scheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 0.6,
        space: 0.6,
      ),
      textTheme: Typography.material2021(platform: TargetPlatform.android)
          .black
          .apply(
            bodyColor: scheme.onSurface,
            displayColor: scheme.onSurface,
          )
          .copyWith(
            bodyLarge: TextStyle(fontSize: 16, height: 1.75, color: scheme.onSurface),
            bodyMedium: TextStyle(fontSize: 15, height: 1.65, color: scheme.onSurface),
            titleMedium: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF353638) : const Color(0xFFF9FAFB),
        hintStyle: TextStyle(
          color: scheme.onSurface.withValues(alpha: 0.35),
          fontSize: 15,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF43454A) : const Color(0xFF353638),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? const Color(0xFF353638) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : null,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.25),
      ),
    );
  }

  static TextStyle codeStyle(Color color) => TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.7,
        color: color,
      );
}
