import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'gp_text.dart';
import 'gp_tokens.dart';

class AppTheme {
  static ThemeData dark({String languageCode = 'ar'}) =>
      _build(GpColors.dark, Brightness.dark, languageCode: languageCode);

  static ThemeData light({String languageCode = 'ar'}) =>
      _build(GpColors.light, Brightness.light, languageCode: languageCode);

  static ThemeData _build(
    GpColors c,
    Brightness brightness, {
    required String languageCode,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: GP.lime,
      onPrimary: c.onLime,
      secondary: c.fg,
      onSecondary: c.bg,
      surface: c.bg2,
      onSurface: c.fg,
      error: GP.danger,
      onError: Colors.white,
    );

    final textTheme = TextTheme(
      displayLarge: GPText.display1(color: c.fg),
      displayMedium: GPText.display2(color: c.fg),
      displaySmall: GPText.display(34, color: c.fg),
      headlineLarge: GPText.h1(color: c.fg),
      headlineMedium: GPText.h2(color: c.fg),
      titleLarge: GPText.h2(color: c.fg),
      bodyLarge: GPText.body(size: 16, color: c.fg),
      bodyMedium: GPText.body(size: 14, color: c.mutedSoft),
      bodySmall: GPText.bodySm(color: c.muted),
      labelLarge: GPText.ctaLabel.copyWith(color: c.onLime),
      labelMedium: GPText.mono(size: 11, color: c.muted),
      labelSmall: GPText.mono(size: 10, letterSpacing: 2.0, color: c.muted),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.bg,
      colorScheme: scheme,
      textTheme: textTheme,
      fontFamily: 'Inter',
      fontFamilyFallback: const ['Cairo', 'Roboto', 'sans-serif'],
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.fg,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              brightness == Brightness.dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: brightness,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness:
              brightness == Brightness.dark ? Brightness.light : Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.bg2,
        hintStyle: GPText.body(color: c.muted),
        labelStyle: GPText.body(color: c.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GPRadius.lg),
          borderSide: BorderSide(color: c.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GPRadius.lg),
          borderSide: BorderSide(color: c.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GPRadius.lg),
          borderSide: BorderSide(color: c.accentInk, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GPRadius.lg),
          borderSide: const BorderSide(color: GP.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GPRadius.lg),
          borderSide: const BorderSide(color: GP.danger, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      dividerTheme: DividerThemeData(color: c.line, space: 1),
      iconTheme: IconThemeData(color: c.fg),
    );
  }
}
