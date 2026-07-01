import 'package:flutter/material.dart';

import 'gp_tokens.dart';

class GPText {
  static const List<String> _fallback = ['Roboto', 'sans-serif'];

  // Cairo variable font axes: wght 200–1000, slnt −20–0 (0 = upright).
  // Slant replaces Archivo italic for display heads; Arabic text always
  // renders upright (slnt 0) so ligatures stay intact.
  static const List<FontVariation> _displayAxes = [
    FontVariation('wght', 900),
    FontVariation('slnt', -10),
  ];

  static const List<FontVariation> _displayAxesAr = [
    FontVariation('wght', 800),
    FontVariation('slnt', 0),
  ];

  static TextStyle display(double size, {Color color = GP.paper, double height = 0.92}) {
    return TextStyle(
      fontFamily: 'Cairo',
      fontFamilyFallback: _fallback,
      fontWeight: FontWeight.w900,
      fontVariations: _displayAxes,
      fontSize: size,
      height: height,
      letterSpacing: -size * 0.02,
      color: color,
    );
  }

  static TextStyle displayArabic(
    double size, {
    Color color = GP.paper,
    double height = 1.1,
  }) {
    return TextStyle(
      fontFamily: 'Cairo',
      fontFamilyFallback: _fallback,
      fontWeight: FontWeight.w800,
      fontVariations: _displayAxesAr,
      fontSize: size,
      height: height,
      letterSpacing: 0,
      color: color,
    );
  }

  static TextStyle displayFor(
    String languageCode,
    double size, {
    Color color = GP.paper,
    double height = 0.92,
  }) {
    if (languageCode == 'ar') {
      return displayArabic(size, color: color);
    }
    return display(size, color: color, height: height);
  }

  static TextStyle display1({Color color = GP.paper}) => display(54, color: color, height: 0.88);
  static TextStyle display2({Color color = GP.paper}) => display(42, color: color, height: 0.9);
  static TextStyle h1({Color color = GP.paper}) => display(26, color: color, height: 1.05);
  static TextStyle h2({Color color = GP.paper}) => display(20, color: color, height: 1.1);

  static TextStyle serifAccent(double size, {Color color = GP.lime}) {
    return TextStyle(
      fontFamily: 'Cairo',
      fontFamilyFallback: _fallback,
      fontWeight: FontWeight.w700,
      fontVariations: const [FontVariation('wght', 700)],
      fontSize: size * 0.82,
      height: 0.92,
      letterSpacing: -size * 0.008,
      color: color,
    );
  }

  static const TextStyle overline = TextStyle(
    fontFamily: 'Cairo',
    fontFamilyFallback: _fallback,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.0,
    height: 1.2,
    color: GP.muted,
  );

  static TextStyle mono({
    double size = 11,
    FontWeight weight = FontWeight.w600,
    double letterSpacing = 1.3,
    Color color = GP.muted,
  }) {
    return TextStyle(
      fontFamily: 'Cairo',
      fontFamilyFallback: _fallback,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: 1.2,
      color: color,
    );
  }

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = GP.mutedSoft,
    double height = 1.45,
  }) {
    return TextStyle(
      fontFamily: 'Cairo',
      fontFamilyFallback: _fallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
    );
  }

  static TextStyle bodyLg({Color color = GP.mutedSoft}) => body(size: 16, color: color);
  static TextStyle bodySm({Color color = GP.muted}) => body(size: 12, color: color, height: 1.4);

  static const TextStyle ctaLabel = TextStyle(
    fontFamily: 'Cairo',
    fontFamilyFallback: _fallback,
    fontWeight: FontWeight.w900,
    fontVariations: _displayAxes,
    fontSize: 15,
    letterSpacing: 0.6,
    height: 1.0,
    color: GP.ink,
  );
}
