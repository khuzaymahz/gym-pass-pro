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

  // Audience-gender badge colours. Drives the "Women only" / "Men
  // only" chip on gym cards + detail pages. These are intentionally
  // off the tier palette — they're informational badges, not brand
  // surfaces. Pink + blue is the conventional pairing globally;
  // the chroma is muted (`-400` family from Tailwind) so the chip
  // reads as "tag" not "alert".
  static const Color audienceFemale = Color(0xFFEC4899);
  static const Color audienceMale = Color(0xFF60A5FA);

  // Maps "you are here" marker — Google Maps' canonical user-pin
  // blue. Off-palette on purpose; members read the GPS-dot pattern
  // by colour, not by brand.
  static const Color userPositionBlue = Color(0xFF1A73E8);

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

extension GpColorsTheme on GpColors {
  /// True when the active palette is the light variant. Used by
  /// tier-color resolvers (e.g. `GPTier.readableOn`) to pick the
  /// surface-adapted brand colour instead of the dark-mode hex —
  /// brand hexes designed for dark backgrounds (silver mid-grey,
  /// platinum icy white-blue, diamond electric cyan) wash out on
  /// near-white surfaces.
  bool get isLight => bg.computeLuminance() > 0.5;
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

  /// Brand colour optimised for **dark** surfaces. Used as-is for
  /// the radial glow / shadow stops (transparency mutes them so
  /// they survive on either theme), and used as the readable
  /// foreground on dark mode. Light-mode foreground rendering
  /// goes through [colorOnLight] instead — see [readableOn].
  final Color color;

  /// Brand colour optimised for **light** surfaces. The dark-mode
  /// hexes (silver mid-grey, platinum icy white-blue, diamond
  /// electric cyan) drop below 3:1 contrast on near-white
  /// backgrounds; this variant is the same chroma family pushed
  /// toward darker / more saturated to stay legible.
  final Color colorOnLight;

  final int price;
  final int visits;
  final int rank;
  final List<String> features;

  const GPTier({
    required this.key,
    required this.name,
    required this.glyph,
    required this.color,
    required this.colorOnLight,
    required this.price,
    required this.visits,
    required this.rank,
    required this.features,
  });

  Color get color14 => color.withValues(alpha: 0.14);
  Color get color22 => color.withValues(alpha: 0.22);
  Color get color44 => color.withValues(alpha: 0.44);

  /// Tier colour for text/icon/border rendering on the active
  /// surface. Returns [colorOnLight] in light mode, [color] in
  /// dark — keeps the brand hue family while restoring contrast.
  Color readableOn(GpColors gp) => gp.isLight ? colorOnLight : color;

  // Every tier shares the same 30-visit monthly cap. The only differentiator
  // is the gym network each tier unlocks (entry / mid / premium / full).
  static const silver = GPTier(
    key: 'silver',
    name: 'Silver',
    glyph: '◇',
    color: Color(0xFF9E9E9E),
    // Slate grey — same neutral family, dark enough to read on
    // off-white. ~6:1 contrast.
    colorOnLight: Color(0xFF5A5F66),
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
    // Amber already reads on white; slight darken to lift contrast
    // for body-text uses without losing the warm hue.
    colorOnLight: Color(0xFFC77B00),
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
    // Deeper steel-blue for light mode. Still in the "polished
    // metal" register, ~5:1 contrast on the off-white surface.
    colorOnLight: Color(0xFF2E5BA8),
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
    // Deeper teal for light mode — keeps the cyan family but
    // drops the lightness so text + sparkles stay legible on the
    // off-white card surface. ~5:1 contrast.
    colorOnLight: Color(0xFF007A8C),
    price: 110,
    visits: 30,
    rank: 4,
    features: ['All 80 partner gyms', '30 visits/mo'],
  );

  static const all = [silver, gold, platinum, diamond];

  /// Lookup that **always** returns a tier — used for contexts that
  /// have already validated the key (catalog rows, settled
  /// subscriptions). Falls back to [silver] on a miss because Silver
  /// is the entry tier; the previous fallback was [gold] (brand
  /// amber), which made every malformed/unknown tier value render
  /// dressed as Gold and lie about a partner's tier.
  static GPTier byKey(String k) {
    final norm = k.trim().toLowerCase();
    return all.firstWhere((t) => t.key == norm, orElse: () => silver);
  }

  /// Strict lookup used at presentation surfaces where rendering an
  /// "unknown tier" with a default colour would be a load-bearing
  /// lie about the gym (the map pin colour, the floating gym card's
  /// border, the list-sheet hero logo). Returns `null` when the
  /// input doesn't match a known tier — callers swap in a neutral
  /// grey rather than impersonate Silver/Gold/etc.
  static GPTier? tryByKey(String? k) {
    if (k == null) return null;
    final norm = k.trim().toLowerCase();
    if (norm.isEmpty) return null;
    for (final t in all) {
      if (t.key == norm) return t;
    }
    return null;
  }
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
