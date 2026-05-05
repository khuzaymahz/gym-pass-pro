import 'package:flutter/material.dart';

import 'gp_tokens.dart';

class GPText {
  // Archivo / Inter / InstrumentSerif are Latin-only. Cairo is bundled as the
  // Arabic-script fallback so AR text renders in a designed face instead of
  // whatever the platform sans happens to be (was Roboto on Android, blurry
  // on some devices). Roboto / sans-serif remain at the tail for any glyph
  // Cairo doesn't cover.
  static const List<String> _fallback = ['Cairo', 'Roboto', 'sans-serif'];

  // Archivo is a variable font with wght (100-900) + wdth (62-125) axes.
  // Pushing wght to 900 and wdth to narrower 88 produces a more editorial,
  // compressed display — closer to a dedicated display face like Anton
  // without shipping an extra font.
  static const List<FontVariation> _displayAxes = [
    FontVariation('wght', 900),
    FontVariation('wdth', 88),
  ];

  static TextStyle display(double size, {Color color = GP.paper, double height = 0.92}) {
    return TextStyle(
      fontFamily: 'Archivo',
      fontFamilyFallback: _fallback,
      fontWeight: FontWeight.w900,
      fontVariations: _displayAxes,
      fontStyle: FontStyle.italic,
      fontSize: size,
      height: height,
      letterSpacing: -size * 0.045,
      color: color,
    );
  }

  static TextStyle display1({Color color = GP.paper}) => display(54, color: color, height: 0.88);
  static TextStyle display2({Color color = GP.paper}) => display(42, color: color, height: 0.9);
  static TextStyle h1({Color color = GP.paper}) => display(26, color: color, height: 1.05);
  static TextStyle h2({Color color = GP.paper}) => display(20, color: color, height: 1.1);

  static TextStyle serifAccent(double size, {Color color = GP.lime}) {
    return TextStyle(
      fontFamily: 'InstrumentSerif',
      fontFamilyFallback: _fallback,
      fontStyle: FontStyle.italic,
      fontSize: size * 0.82,
      height: 0.92,
      letterSpacing: -size * 0.012,
      color: color,
    );
  }

  // Overline / mono labels used to use JetBrainsMono, which has no Arabic
  // glyphs — the result was unreadable step indicators in AR. Inter renders
  // both scripts cleanly; the uppercase + tracked-out treatment still reads
  // as a "label" without the monospaced look.
  static const TextStyle overline = TextStyle(
    fontFamily: 'Inter',
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
      fontFamily: 'Inter',
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
      fontFamily: 'Inter',
      fontFamilyFallback: _fallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
    );
  }

  static TextStyle bodyLg({Color color = GP.mutedSoft}) => body(size: 16, color: color);
  static TextStyle bodySm({Color color = GP.muted}) => body(size: 12, color: color, height: 1.4);

  static TextStyle ctaLabel = const TextStyle(
    fontFamily: 'Archivo',
    fontFamilyFallback: _fallback,
    fontWeight: FontWeight.w900,
    fontVariations: _displayAxes,
    fontStyle: FontStyle.italic,
    fontSize: 15,
    letterSpacing: 0.6,
    height: 1.0,
    color: GP.ink,
  );
}
