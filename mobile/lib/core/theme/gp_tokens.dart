import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Great-circle distance between two lat/lng points in kilometres.
/// Haversine on a 6371 km sphere — accurate to ~0.5% over Jordan-
/// scale distances. Returns 0 when the two points coincide; callers
/// that don't want to render "0 km" should guard against unresolved
/// coords (lat == 0 && lng == 0) at the call site.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthKm = 6371.0;
  double deg2rad(double d) => d * (math.pi / 180);
  final dLat = deg2rad(lat2 - lat1);
  final dLng = deg2rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(deg2rad(lat1)) *
          math.cos(deg2rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthKm * c;
}

class GP {
  // Brand / base (static across themes).
  //
  // **Brand accent**: amber `#EAB308` (rgb 234, 179, 8). Replaces the
  // previous chartreuse lime — amber sits closer to a "premium gold"
  // register, reads cleanly on both dark ink AND light cream
  // surfaces (the lime-on-cream contrast was the blocker for proper
  // light mode), and pairs with the gym-tier palette without
  // competing. The constant names `lime`/`limeHi`/`onLime` are
  // retained because they thread through ~50 widgets — renaming is
  // a noisy follow-up that doesn't change behaviour.
  static const Color lime = Color(0xFFEAB308);
  static const Color limeHi = Color(0xFFF4C842);
  static const Color ink = Color(0xFF0A0B0A);
  static const Color paper = Color(0xFFF5F3EC);

  // Default surfaces (dark — kept for backwards compatibility).
  // Widgets that need theme-aware tokens should read from context.gp.
  static const Color bg = ink;
  static const Color bg2 = Color(0xFF111311);
  static const Color bg3 = Color(0xFF17181A);
  static const Color line = Color(0x1FF5F3EC); // ~12%
  static const Color line2 = Color(0x3DF5F3EC); // ~24%
  static const Color muted = Color(0x73F5F3EC); // ~45%
  static const Color mutedSoft = Color(0xB3F5F3EC); // ~70%

  // Signals (static)
  static const Color danger = Color(0xFFFF5C3A);
  static const Color success = Color(0xFF52FFA0);
  static const Color warn = Color(0xFFFFC43D);

  // Brand-amber alphas (kept named "lime*" for backwards compatibility
  // with widgets that still reference these directly).
  static const Color lime14 = Color(0x24EAB308);
  static const Color lime22 = Color(0x38EAB308);
  static const Color lime44 = Color(0x70EAB308);
}

/// Theme-aware surface/text tokens. Brand colors (lime, danger, tier palette)
/// remain static. Use `context.gp` to read these anywhere a widget builds.
@immutable
class GpColors extends ThemeExtension<GpColors> {
  final Color bg;
  final Color bg2;
  final Color bg3;
  final Color line;
  final Color line2;
  final Color muted;
  final Color mutedSoft;
  final Color fg; // primary text
  final Color onLime; // ink on accent fills — same across themes
  // Primary accent — lime in both modes. Use for active states, progress
  // indicators, badges, selection, and interactive affordances. Never for
  // reading text on light mode: lime-on-cream fails contrast.
  final Color accent;
  final Color accentHi;
  // Readable brand ink — use for small accent text/icons that must remain
  // legible on the current surface. Stays lime on dark (pops on near-black),
  // goes dark on light so typography accents read cleanly.
  final Color accentInk;
  // Tinted soft card shadow applied to raised/hero surfaces.
  final Color cardShadow;

  const GpColors({
    required this.bg,
    required this.bg2,
    required this.bg3,
    required this.line,
    required this.line2,
    required this.muted,
    required this.mutedSoft,
    required this.fg,
    required this.onLime,
    required this.accent,
    required this.accentHi,
    required this.accentInk,
    required this.cardShadow,
  });

  static const dark = GpColors(
    bg: GP.ink,
    bg2: Color(0xFF111311),
    bg3: Color(0xFF17181A),
    line: Color(0x1FF5F3EC),
    line2: Color(0x3DF5F3EC),
    muted: Color(0x73F5F3EC),
    mutedSoft: Color(0xB3F5F3EC),
    fg: GP.paper,
    onLime: GP.ink,
    accent: GP.lime,
    accentHi: GP.limeHi,
    accentInk: GP.lime,
    cardShadow: Color(0x00000000),
  );

  // Light palette: soft off-white background with near-black text.
  // Brand amber is **the same hex in both modes** for `accent` and
  // `accentInk` — earlier the light variant had a darker `accentInk`
  // (`#9A6B00`) for body-text legibility, but mixing two ambers in
  // the same screen made the wordmark, brand badges, and inline
  // accents read as three different shades. Visual consistency wins;
  // small accent text falls back to the `fg` ink token where
  // contrast matters more than brand colour.
  static const light = GpColors(
    bg: Color(0xFFFAFAF9),
    bg2: Color(0xFFF5F5F4),
    bg3: Color(0xFFE7E5E4),
    line: Color(0x141A1A1A),
    line2: Color(0x2E1A1A1A),
    muted: Color(0xFF9CA3AF),
    mutedSoft: Color(0xFF6B7280),
    fg: Color(0xFF1A1A1A),
    onLime: GP.ink,
    accent: GP.lime,
    accentHi: GP.limeHi,
    accentInk: GP.lime,
    cardShadow: Color(0x141A1A1A),
  );

  @override
  GpColors copyWith({
    Color? bg,
    Color? bg2,
    Color? bg3,
    Color? line,
    Color? line2,
    Color? muted,
    Color? mutedSoft,
    Color? fg,
    Color? onLime,
    Color? accent,
    Color? accentHi,
    Color? accentInk,
    Color? cardShadow,
  }) {
    return GpColors(
      bg: bg ?? this.bg,
      bg2: bg2 ?? this.bg2,
      bg3: bg3 ?? this.bg3,
      line: line ?? this.line,
      line2: line2 ?? this.line2,
      muted: muted ?? this.muted,
      mutedSoft: mutedSoft ?? this.mutedSoft,
      fg: fg ?? this.fg,
      onLime: onLime ?? this.onLime,
      accent: accent ?? this.accent,
      accentHi: accentHi ?? this.accentHi,
      accentInk: accentInk ?? this.accentInk,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  GpColors lerp(ThemeExtension<GpColors>? other, double t) {
    if (other is! GpColors) return this;
    return GpColors(
      bg: Color.lerp(bg, other.bg, t)!,
      bg2: Color.lerp(bg2, other.bg2, t)!,
      bg3: Color.lerp(bg3, other.bg3, t)!,
      line: Color.lerp(line, other.line, t)!,
      line2: Color.lerp(line2, other.line2, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedSoft: Color.lerp(mutedSoft, other.mutedSoft, t)!,
      fg: Color.lerp(fg, other.fg, t)!,
      onLime: Color.lerp(onLime, other.onLime, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHi: Color.lerp(accentHi, other.accentHi, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
    );
  }
}

extension GpColorsContext on BuildContext {
  GpColors get gp =>
      Theme.of(this).extension<GpColors>() ?? GpColors.dark;
}

extension GpCardShadow on GpColors {
  /// Soft shadow stack for raised cards. Empty in dark mode (token is fully
  /// transparent); renders a layered editorial shadow in light mode.
  List<BoxShadow> get cardShadows {
    if (cardShadow.a == 0) return const [];
    return [
      BoxShadow(
        color: cardShadow,
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: cardShadow.withValues(alpha: cardShadow.a * 0.5),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ];
  }
}

class GPTier {
  final String key;
  final String name;
  final String glyph;
  final Color color;
  final int price;
  final int visits;
  final int rank;
  final List<String> features;

  const GPTier({
    required this.key,
    required this.name,
    required this.glyph,
    required this.color,
    required this.price,
    required this.visits,
    required this.rank,
    required this.features,
  });

  Color get color14 => color.withValues(alpha: 0.14);
  Color get color22 => color.withValues(alpha: 0.22);
  Color get color44 => color.withValues(alpha: 0.44);

  /// Tier color used as text/icon on page and card backgrounds. Kept as a
  /// method (not just `color`) so individual tiers can swap to a surface-
  /// adaptive variant if their brand hue fails contrast on the current theme.
  Color readableOn(GpColors gp) => color;

  // Every tier shares the same 30-visit monthly cap. The only differentiator
  // is the gym network each tier unlocks (entry / mid / premium / full).
  static const silver = GPTier(
    key: 'silver',
    name: 'Silver',
    glyph: '◇',
    color: Color(0xFF9E9E9E),
    price: 25,
    visits: 30,
    rank: 1,
    features: ['10 entry-level gyms', '30 visits/mo'],
  );
  static const gold = GPTier(
    key: 'gold',
    name: 'Gold',
    glyph: '◆',
    color: Color(0xFFF9A825),
    price: 45,
    visits: 30,
    rank: 2,
    features: ['25 gyms · Silver + Gold', '30 visits/mo'],
  );
  // Platinum sits between Gold's warm amber and Diamond's electric cyan
  // — an icy white-blue with just enough chroma to read as a metal,
  // not as plain white. Drives the card's subtle shimmer treatment in
  // the plans page (see [TierNameLabel.platinum]).
  static const platinum = GPTier(
    key: 'platinum',
    name: 'Platinum',
    glyph: '◈',
    color: Color(0xFFB8D4FF),
    price: 75,
    visits: 30,
    rank: 3,
    features: ['45 premium gyms', '30 visits/mo'],
  );
  static const diamond = GPTier(
    key: 'diamond',
    name: 'Diamond',
    glyph: '◉',
    color: Color(0xFF00E5FF),
    price: 110,
    visits: 30,
    rank: 4,
    features: ['All 80 partner gyms', '30 visits/mo'],
  );

  static const all = [silver, gold, platinum, diamond];

  static GPTier byKey(String k) =>
      all.firstWhere((t) => t.key == k, orElse: () => gold);
}

class GPCategory {
  // Gym category accent matches the brand amber. Other categories
  // keep their distinct hues so a member glancing at filters can
  // tell crossfit / martial / yoga apart at a tile.
  static const Color gym = GP.lime;
  static const Color crossfit = Color(0xFF52FFA0);
  static const Color martial = Color(0xFFFF5C3A);
  static const Color yoga = Color(0xFFB79BFF);

  static Color color(String c) {
    switch (c) {
      case 'gym':
        return gym;
      case 'crossfit':
        return crossfit;
      case 'martial':
        return martial;
      case 'yoga':
        return yoga;
      default:
        return gym;
    }
  }

  static String label(String c) {
    switch (c) {
      case 'crossfit':
        return 'CROSS';
      case 'martial':
        return 'MARTIAL';
      case 'yoga':
        return 'YOGA';
      default:
        return 'GYM';
    }
  }
}

class GPGym {
  final String slug;
  final String name;
  final String area;
  final String category;
  final String tier;

  /// Real-world coordinates for the seeded gyms. Live distance to the
  /// member is computed via [distanceKmFrom] using these — there is no
  /// pre-baked "distance" field anymore (it lied: the seed shipped the
  /// same number to every member regardless of where they actually
  /// were). Leave at 0,0 for placeholders that shouldn't render in
  /// distance UI.
  final double lat;
  final double lng;

  const GPGym({
    required this.slug,
    required this.name,
    required this.area,
    required this.category,
    required this.tier,
    required this.lat,
    required this.lng,
  });

  Color get color => GPCategory.color(category);
  GPTier get tierObj => GPTier.byKey(tier);

  /// Great-circle distance from ([userLat], [userLng]) to this gym
  /// in kilometres. Returns null when the gym has no coordinates so
  /// callers can hide the row rather than show "0 km" or "— km."
  double? distanceKmFrom(double userLat, double userLng) {
    if (lat == 0 && lng == 0) return null;
    return haversineKm(userLat, userLng, lat, lng);
  }

  /// Seed gyms with real Amman lat/lngs sourced from Maps. These are
  /// the fallback rendering set when the backend isn't reachable;
  /// the live `GymSummary` rows from `/gyms` carry the authoritative
  /// coordinates once the backend is up.
  static const seed = [
    GPGym(
      slug: 'iron-forge', name: 'Iron Forge', area: 'Abdoun',
      category: 'gym', tier: 'silver',
      lat: 31.9510, lng: 35.8745,
    ),
    GPGym(
      slug: 'bedford-yoga', name: 'Bedford Yoga', area: 'Sweifieh',
      category: 'yoga', tier: 'gold',
      lat: 31.9430, lng: 35.8590,
    ),
    GPGym(
      slug: 'fortis-boxing', name: 'Fortis Boxing', area: 'Jabal Amman',
      category: 'martial', tier: 'platinum',
      lat: 31.9540, lng: 35.9325,
    ),
    GPGym(
      slug: 'apex-crossfit', name: 'Apex CrossFit', area: 'Khalda',
      category: 'crossfit', tier: 'gold',
      lat: 31.9810, lng: 35.8330,
    ),
    GPGym(
      slug: 'halo-studio', name: 'Halo Studio', area: 'Abdoun',
      category: 'yoga', tier: 'silver',
      lat: 31.9485, lng: 35.8765,
    ),
    GPGym(
      slug: 'core-athletic', name: 'Core Athletic', area: 'Dabouq',
      category: 'gym', tier: 'diamond',
      lat: 32.0190, lng: 35.8175,
    ),
  ];
}

class GPSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xl2 = 24;
  static const double xl3 = 32;
  static const double xl4 = 48;
}

class GPRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xl2 = 24;
  static const double pill = 100;
}
