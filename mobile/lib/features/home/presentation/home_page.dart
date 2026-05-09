import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/glow.dart';
import '../../../core/widgets/gym_tile.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/tier_chip.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/wordmark.dart';
import '../../../core/widgets/top_bounce_physics.dart';
import '../../../core/widgets/wordmark_refresh.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/user_profile.dart';
import '../../gyms/data/gym_repository.dart';
import '../../gyms/data/gym_summary.dart';
import '../../gyms/presentation/gyms_filter_state.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../subscription/data/subscription_state.dart';

/// Map Eastern Arabic digits (٠-٩, U+0660–U+0669) back to Latin 0-9.
/// `DateFormat.jm('ar')` returns Eastern Arabic numerals by default, but
/// Jordanian mobile apps use Western digits in both locales per CLAUDE.md §10.
String _toLatinDigits(String s) {
  const arabicZero = 0x0660;
  return s.replaceAllMapped(RegExp(r'[٠-٩]'), (m) {
    return String.fromCharCode(m.group(0)!.codeUnitAt(0) - arabicZero + 0x30);
  });
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Future<void> _handleRefresh() async {
    // Real refresh — actually re-fetches from the backend instead
    // of re-awaiting the cached `.ready` future (which after the
    // first hydrate is a no-op). Three providers move on this
    // page: subscription (visit count, renew date), profile (name
    // / email / phone an admin may have corrected), and the gym
    // list (Near You).
    //
    // The gymsListProvider invalidate has to be awaited via
    // `.future` rather than just `ref.invalidate(...)` — otherwise
    // the refresh indicator stops the moment invalidate returns
    // (synchronously) and the new gym list lands silently a few
    // hundred ms later. Members read that as "swipe to refresh
    // didn't update anything." Reading `.future` after invalidate
    // triggers the new fetch and gives us a Future to await
    // alongside the other two refreshes.
    ref.invalidate(gymsListProvider);
    await Future.wait<void>([
      ref.read(subscriptionProvider.notifier).refreshFromBackend(),
      ref.read(profileProvider.notifier).refreshFromBackend(),
      ref.read(gymsListProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final sub = ref.watch(subscriptionProvider);
    final profile = ref.watch(profileProvider);
    // Near You comes from `gymsListProvider` (backend `/api/v1/gyms`).
    // No seed fallback — backend is the single source of truth, and a
    // truly empty list renders the empty-state card rather than a
    // fake "here are some gyms" sample. The provider's `valueOrNull`
    // is non-null after the first hydrate; before that we render
    // skeletons.
    final gymsAsync = ref.watch(gymsListProvider);
    final nearYou = gymsAsync.valueOrNull ?? const <GymSummary>[];
    final isLoadingGyms = gymsAsync.isLoading && nearYou.isEmpty;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final firstName = profile.firstName?.trim();
    final greeting = (firstName != null && firstName.isNotEmpty)
        ? l.homeGreetingName(firstName)
        : l.homeGreetingFallback;
    // Top overline = live weekday + current time in the user's locale, always
    // in 12-hour form. Weekday follows the locale ("Monday" / "الاثنين");
    // the clock uses Latin digits in both locales per Jordanian mobile
    // convention (digits come back as ٠-٩ on AR by default, so we strip back
    // to 0-9 after formatting).
    final now = DateTime.now();
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final weekday = DateFormat('EEEE', localeTag).format(now);
    final clock = _toLatinDigits(DateFormat.jm(localeTag).format(now));
    final topOverline = '$weekday · $clock';
    return Stack(
      fit: StackFit.expand,
      children: [
        const RadialGlow(
          opacity: 0.12,
          size: 520,
          alignment: Alignment(0, -0.95),
        ),
        WordmarkRefresh(
          onRefresh: _handleRefresh,
          // Push the pull badge below the floating IconBtn row (which sits
          // at topInset+12 with ~28px of icon height) so the Letter Stamp
          // never lands inside the iPhone Dynamic Island / notch.
          topOffset: topInset + 56,
          child: ListView(
            // TopBouncePhysics: top bounces (so pull-to-refresh feels
            // native), bottom clamps (no rebound that members read as a
            // fake refresh). AlwaysScrollable lets the refresh indicator
            // arm even when the list fits the viewport.
            physics: const AlwaysScrollableScrollPhysics(
              parent: TopBouncePhysics(),
            ),
            padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 24),
            children: [
              // Wordmark stays anchored to the visual-left in every
              // locale — the GYMPASS logo is brand identity, not
              // directional content (matches the sign-in page).
              const Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: [Wordmark(size: 22)],
                ),
              ),
              const SizedBox(height: 22),
              Overline(topOverline),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [DisplayText(greeting, size: 36)],
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  DisplayText(l.homeHeadlineLine1, size: 36),
                  const SizedBox(width: 10),
                  SerifAccent(l.homeHeadlineAccent, size: 36),
                ],
              ),
              const SizedBox(height: 26),
              // Builder gives a context positioned inside the
              // WordmarkRefresh's RefreshScope subtree (the outer
              // HomePage build context sits above WordmarkRefresh and
              // would silently miss the lookup). On pull-to-refresh
              // the plan card morphs to a SkeletonPlanCard so the
              // member sees "we're working" instead of stale numbers
              // sitting under a spinner. NOT used on cold start —
              // that path renders the real card directly so a returning
              // member never waits on a placeholder.
              Builder(
                builder: (innerCtx) {
                  if (RefreshScope.of(innerCtx)) {
                    return const SkeletonPlanCard();
                  }
                  return _PlanCard(sub: sub);
                },
              ),
              const SizedBox(height: 26),
              _sectionHeader(
                context,
                l.homeNearYou,
                gp,
                trailing: l.seeAll,
                onTrailing: () {
                  // SEE ALL drops the member onto Explore with no
                  // category filter and the sheet pre-opened to
                  // mid — they came here for the list, not the map.
                  ref.read(gymsCategoryFilterProvider.notifier).state = 'all';
                  ref
                      .read(exploreSheetOpenOnArrivalProvider.notifier)
                      .state = true;
                  context.go('/explore');
                },
              ),
              const SizedBox(height: 14),
              // Three states drive what we render here:
              //
              //   1. cold-start hydrate (provider loading, no cached
              //      rows yet) → skeletons
              //   2. pull-to-refresh in flight (RefreshScope true) →
              //      skeletons
              //   3. data resolved → real rows from the backend's
              //      `/api/v1/gyms` (no seed fallback)
              //
              // When the backend has zero rows, we render an empty-
              // state card. That's the truthful state.
              Builder(
                builder: (innerCtx) {
                  final showSkeleton =
                      isLoadingGyms || RefreshScope.of(innerCtx);
                  if (showSkeleton) {
                    return Column(
                      children: List.generate(
                        3,
                        (_) => const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: SkeletonGymRow(),
                        ),
                      ),
                    );
                  }
                  if (nearYou.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: gp.bg2,
                        borderRadius: BorderRadius.circular(GPRadius.lg),
                        border: Border.all(color: gp.line),
                      ),
                      child: Text(
                        l.homeNoGymsYet,
                        style: GPText.body(size: 13, color: gp.mutedSoft),
                      ),
                    );
                  }
                  // Pick the first three. Future iteration: sort by
                  // user GPS distance once we have the position
                  // ready before this point in the build (already
                  // tracked in `userPositionProvider`).
                  final firstThree = nearYou.take(3).toList();
                  final isAr = Localizations.localeOf(context)
                          .languageCode ==
                      'ar';
                  return Column(
                    children: firstThree
                        .map(
                          (g) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GymRow(
                              gym: _gymSummaryToGPGym(g, isAr: isAr),
                              logoUrl: g.logoUrl,
                              onTap: () => innerCtx.push('/gyms/${g.slug}'),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              _sectionHeader(context, l.homeCategories, gp),
              const SizedBox(height: 14),
              _CategoryGrid(
                onTapCategory: (key) {
                  // Category tile sets the filter, then opens
                  // Explore with the sheet pre-opened to mid so the
                  // narrowed list is immediately visible.
                  ref.read(gymsCategoryFilterProvider.notifier).state = key;
                  ref
                      .read(exploreSheetOpenOnArrivalProvider.notifier)
                      .state = true;
                  context.go('/explore');
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        Positioned(
          top: topInset + 12,
          // Pinned visual-right in every locale to match the
          // wordmark's visual-left anchoring — the home header is
          // a fixed brand layout, not directional content.
          right: 20,
          // Notifications-only — search lived here too but the
          // bottom-nav already gives one tap to Explore (which has
          // its own search pill), so duplicating the entry point
          // here was redundant. The badge dot only renders when
          // there's actually an unread notification — was hardcoded
          // to `true` before, which painted a phantom indicator
          // even on a clean inbox.
          child: Consumer(
            builder: (context, ref, _) {
              final hasUnread = ref
                      .watch(unreadNotificationsCountProvider)
                      .valueOrNull !=
                  null
                  ? ref.watch(unreadNotificationsCountProvider).valueOrNull! > 0
                  : false;
              return IconBtn(
                icon: Icons.notifications_none,
                badge: hasUnread,
                onPressed: () => context.push('/notifications'),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    String label,
    GpColors gp, {
    String? trailing,
    VoidCallback? onTrailing,
  }) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: GPText.mono(
            size: 11,
            letterSpacing: 1.8,
            color: gp.fg,
            weight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          InkWell(
            onTap: onTrailing,
            child: Text(
              trailing.toUpperCase(),
              style: GPText.mono(size: 10, letterSpacing: 1.5, color: gp.accentInk),
            ),
          ),
      ],
    );
  }
}

/// Plan card shown on Home when a member has an active subscription.
/// The card's chrome is **tier-aware** — Silver reads as the entry tier
/// (flat, low-chroma), Gold adds a warm corner bloom, Platinum picks up
/// a cool ice gradient + slightly stronger ring, and Diamond lights up
/// with a cyan halo + sparkle accents and swaps the visit fraction for
/// an UNLIMITED treatment. Same content footprint as before so the page
/// layout doesn't shift between tiers; only the decoration + visit
/// readout change.
///
/// All four variants are theme-aware: backgrounds blend the tier accent
/// into `gp.bg2` at a higher alpha on light mode (where pure brand
/// chroma washes out) and a lower alpha on dark mode (where the accent
/// already pops against the deep canvas).
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.sub});
  final SubscriptionState sub;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final tier = sub.tier;
    if (tier == null) {
      return const _EmptyPlanCard();
    }
    final used = sub.visitsUsed;
    final total = sub.termTotalVisits;
    // `total < 0` is the unlimited sentinel (Diamond). `total == 0` is
    // the not-yet-hydrated case. Neither admits a denominator — the
    // unlimited path swaps the fraction readout entirely, the
    // unhydrated path treats it as "0 of 0" for one frame.
    final isUnlimited = total < 0;
    final shownUsed = total <= 0 ? used : used.clamp(0, total);
    final percent = total <= 0 ? 0.0 : (shownUsed / total).clamp(0.0, 1.0);
    final remaining = total <= 0 ? 0 : (total - shownUsed).clamp(0, total);
    final accent = tier.readableOn(gp);

    final card = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(GPRadius.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(GPRadius.xl),
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/subscription');
        },
        child: Ink(
          decoration: _tierDecoration(tier, gp, accent),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(GPRadius.xl),
            child: Stack(
              children: [
                // Large faint glyph watermark in the back corner —
                // the tier's brand mark embedded into the card itself
                // so each tier reads as its own surface, not just its
                // own colour. Alpha is bumped on light mode where a
                // 0.06 wash disappears against the warm-paper canvas.
                Positioned(
                  top: -28,
                  right: -28,
                  child: Text(
                    tier.glyph,
                    style: TextStyle(
                      fontSize: 160,
                      height: 1,
                      color: accent.withValues(
                        alpha: gp.isLight ? 0.10 : 0.12,
                      ),
                    ),
                  ),
                ),
                // Tier-specific extra accents (e.g. Diamond's
                // sparkles). Empty list for tiers that don't need
                // anything beyond the base decoration.
                ..._tierAccents(tier, gp, accent),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(l, gp, tier),
                      const SizedBox(height: 18),
                      _visitsRow(
                        l: l,
                        gp: gp,
                        accent: accent,
                        shownUsed: shownUsed,
                        total: total,
                        isUnlimited: isUnlimited,
                      ),
                      const SizedBox(height: 18),
                      if (isUnlimited)
                        _unlimitedRow(l, gp, accent)
                      else
                        _progressBar(tier, gp, percent),
                      const SizedBox(height: 14),
                      _footerRow(
                        l: l,
                        gp: gp,
                        remaining: remaining,
                        isUnlimited: isUnlimited,
                      ),
                      // Multi-month plans need a "where am I in the
                      // term" hint — the cycle counter alone can't tell
                      // a 3-month member that they're on month 1 of 3.
                      // For 1-month plans this row would just say
                      // "MONTH 1 OF 1" so we skip it.
                      if ((sub.durationMonths ?? 1) > 1) ...[
                        const SizedBox(height: 6),
                        _TermProgressLine(sub: sub),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 8),
          child: child,
        ),
      ),
      child: card,
    );
  }

  /// Tier-specific card surface. Each tier picks a different recipe
  /// for background, border, and shadow so the cards read as four
  /// different *materials* without competing with each other for the
  /// same affordance:
  ///
  ///   - **Silver** — flat `gp.bg2`, neutral hairline border, default
  ///     card shadow. Reads as the entry tier — no glow, no chroma
  ///     wash, just clean chrome.
  ///   - **Gold** — diagonal gradient adding a warm wash, accent
  ///     border at 35% alpha, soft amber glow shadow. Feels warm
  ///     without being loud.
  ///   - **Platinum** — reverse-diagonal cool gradient with a
  ///     stronger blue-toned wash, accent border at 40%, blue glow.
  ///     Polished-metal register.
  ///   - **Diamond** — top-right radial gradient (most dramatic),
  ///     accent border at 50%, deepest cyan halo shadow. The most
  ///     visually-energetic tier; the eye lands here first.
  BoxDecoration _tierDecoration(GPTier tier, GpColors gp, Color accent) {
    final r = BorderRadius.circular(GPRadius.xl);
    switch (tier.key) {
      case 'gold':
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              gp.bg2,
              Color.alphaBlend(
                accent.withValues(alpha: gp.isLight ? 0.07 : 0.10),
                gp.bg2,
              ),
            ],
          ),
          borderRadius: r,
          border: Border.all(color: accent.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: tier.color.withValues(alpha: 0.18),
              blurRadius: 24,
              spreadRadius: -8,
              offset: const Offset(0, 8),
            ),
            ...gp.cardShadows,
          ],
        );
      case 'platinum':
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color.alphaBlend(
                accent.withValues(alpha: gp.isLight ? 0.10 : 0.13),
                gp.bg2,
              ),
              gp.bg2,
            ],
          ),
          borderRadius: r,
          border: Border.all(color: accent.withValues(alpha: 0.40)),
          boxShadow: [
            BoxShadow(
              color: tier.color.withValues(alpha: 0.22),
              blurRadius: 28,
              spreadRadius: -8,
              offset: const Offset(0, 10),
            ),
            ...gp.cardShadows,
          ],
        );
      case 'diamond':
        return BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.4,
            colors: [
              Color.alphaBlend(
                accent.withValues(alpha: gp.isLight ? 0.14 : 0.18),
                gp.bg2,
              ),
              gp.bg2,
            ],
          ),
          borderRadius: r,
          border: Border.all(color: accent.withValues(alpha: 0.50)),
          boxShadow: [
            BoxShadow(
              color: tier.color.withValues(alpha: 0.30),
              blurRadius: 36,
              spreadRadius: -10,
              offset: const Offset(0, 12),
            ),
            ...gp.cardShadows,
          ],
        );
      case 'silver':
      default:
        return BoxDecoration(
          color: gp.bg2,
          borderRadius: r,
          border: Border.all(color: gp.line),
          boxShadow: gp.cardShadows,
        );
    }
  }

  /// Layered accents that sit on top of the gradient but under the
  /// content column. Currently only Diamond gets sparkle stars; the
  /// other tiers carry their identity entirely in the gradient + glyph
  /// watermark.
  List<Widget> _tierAccents(GPTier tier, GpColors gp, Color accent) {
    if (tier.key != 'diamond') return const [];
    return [
      Positioned(
        top: 18,
        right: 70,
        child: _Sparkle(color: accent, size: 10),
      ),
      Positioned(
        top: 96,
        right: 26,
        child: _Sparkle(color: accent, size: 6),
      ),
      Positioned(
        top: 56,
        right: 130,
        child: _Sparkle(color: accent, size: 7),
      ),
    ];
  }

  Widget _header(AppLocalizations l, GpColors gp, GPTier tier) {
    return Row(
      children: [
        TierChip(tier: tier),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: gp.accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(GPRadius.sm),
            border: Border.all(color: gp.accent.withValues(alpha: 0.55)),
          ),
          child: Text(
            l.homeActive,
            style: GPText.mono(
              size: 9,
              letterSpacing: 1.6,
              color: gp.accentInk,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Visits readout. Finite tiers show `used / total visits`; the
  /// unlimited tier (Diamond) drops the fraction entirely and surfaces
  /// the consumption count + an `UNLIMITED` chip — `0 / -1` was the
  /// previous bug behaviour, where the sentinel value rendered
  /// literally and members saw a meaningless "-1" beside their count.
  Widget _visitsRow({
    required AppLocalizations l,
    required GpColors gp,
    required Color accent,
    required int shownUsed,
    required int total,
    required bool isUnlimited,
  }) {
    if (isUnlimited) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$shownUsed',
            style: GPText.display(44, color: gp.fg, height: 0.9),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: SerifAccent(l.homeVisits, size: 26),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(GPRadius.sm),
                border: Border.all(color: accent.withValues(alpha: 0.55)),
              ),
              child: Text(
                l.homeUnlimited,
                style: GPText.mono(
                  size: 9,
                  letterSpacing: 1.6,
                  color: accent,
                  weight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$shownUsed',
          style: GPText.display(44, color: gp.fg, height: 0.9),
        ),
        const SizedBox(width: 6),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '/$total',
            style: GPText.display(20, color: gp.muted, height: 0.9),
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: SerifAccent(l.homeVisits, size: 26),
        ),
      ],
    );
  }

  Widget _progressBar(GPTier tier, GpColors gp, double percent) {
    return Stack(
      children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: gp.bg3,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        FractionallySizedBox(
          widthFactor: percent,
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: tier.color,
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: tier.color.withValues(alpha: 0.55),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Replaces the progress bar for the unlimited tier. Drawing a
  /// "0 %" or "100 %" bar for Diamond would lie about the cap the
  /// member doesn't have; the infinity glyph + caption is the honest
  /// version. Sits in the same vertical slot as the bar so the layout
  /// height is identical across tiers.
  Widget _unlimitedRow(AppLocalizations l, GpColors gp, Color accent) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.50)),
          ),
          child: Icon(Icons.all_inclusive, size: 16, color: accent),
        ),
        const SizedBox(width: 10),
        Text(
          l.homeUnlimitedThisCycle,
          style: GPText.mono(
            size: 11,
            letterSpacing: 1.6,
            color: accent,
            weight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _footerRow({
    required AppLocalizations l,
    required GpColors gp,
    required int remaining,
    required bool isUnlimited,
  }) {
    return Row(
      children: [
        if (!isUnlimited)
          Text(
            l.homeLeftThisCycle(remaining),
            style: GPText.mono(
              size: 10,
              letterSpacing: 1.5,
              color: gp.mutedSoft,
            ),
          ),
        const Spacer(),
        Text(
          l.homeManage,
          style: GPText.mono(
            size: 10,
            letterSpacing: 1.5,
            color: gp.accentInk,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.arrow_forward, size: 12, color: gp.accentInk),
      ],
    );
  }
}

/// Decorative 4-pointed sparkle used as a Diamond-tier accent. Pure
/// paint, no asset dependency — scales cleanly down to 5 px without
/// the aliasing a small PNG would carry. Mirrors the sparkle in the
/// plan-page Diamond name treatment so the brand cue reads
/// consistently across surfaces.
class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SparklePainter(color: color),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final hw = size.width / 2;
    final hh = size.height / 2;
    // Pinch the side arms inward so the star reads as a 4-point
    // star rather than a square diamond — matches the diamond glyph
    // silhouette and gives a crisper "twinkle" shape.
    const pinch = 0.18;
    final path = Path()
      ..moveTo(cx, 0)
      ..lineTo(cx + hw * pinch, cy - hh * pinch)
      ..lineTo(size.width, cy)
      ..lineTo(cx + hw * pinch, cy + hh * pinch)
      ..lineTo(cx, size.height)
      ..lineTo(cx - hw * pinch, cy + hh * pinch)
      ..lineTo(0, cy)
      ..lineTo(cx - hw * pinch, cy - hh * pinch)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.color != color;
}

/// Sub-line under the per-cycle visit count: "MONTH 2 OF 3 · CYCLE
/// RESETS IN 12D" or, in the final cycle of the term, "TERM RENEWS IN
/// 9D". Lets a multi-month member see at a glance how far through the
/// commitment they are without opening the subscription page.
class _TermProgressLine extends StatelessWidget {
  const _TermProgressLine({required this.sub});
  final SubscriptionState sub;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final cycle = sub.currentCycleNumber();
    final months = sub.durationMonths;
    final cycleDaysLeft = sub.daysLeftInCycle();
    final termDaysLeft = sub.daysLeftInTerm();
    if (cycle == null || months == null) {
      return const SizedBox.shrink();
    }
    final inFinalCycle = cycle >= months;
    final text = inFinalCycle
        ? (termDaysLeft == null ? null : l.homeTermEndsIn(termDaysLeft))
        : (cycleDaysLeft == null
            ? null
            : l.homeCycleProgress(cycle, months, cycleDaysLeft));
    if (text == null) return const SizedBox.shrink();
    return Text(
      text,
      style: GPText.mono(
        size: 9,
        letterSpacing: 1.4,
        color: gp.muted,
      ),
    );
  }
}

/// Shown on /home for members who've signed up but haven't picked a plan yet.
///
/// This is the **default landing surface** post-signup — the router used to
/// gate non-subscribed members at /plans, but that broke browse-first
/// onboarding (no bottom nav, no way to look around the gym network before
/// paying). New signups now land here, see this card alongside a normal
/// home shell with /explore in the bottom nav, and tap into the gym they
/// care about. The upgrade pill on each gym card / detail page funnels
/// them into /plans with concrete context for what they're paying for.
///
/// The card stays honest: no fake tier, no fake visit count, just an
/// explicit "choose your plan" CTA.
class _EmptyPlanCard extends StatelessWidget {
  const _EmptyPlanCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.xl),
        border: Border.all(color: gp.accent.withValues(alpha: 0.45)),
        boxShadow: gp.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.homeNoPlanOverline.toUpperCase(),
            style: GPText.mono(
              size: 10,
              letterSpacing: 1.8,
              color: gp.accentInk,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.homeNoPlanTitle,
            style: GPText.display(28, color: gp.fg, height: 1.0),
          ),
          const SizedBox(height: 10),
          Text(
            l.homeNoPlanBlurb,
            style: GPText.body(size: 13, color: gp.mutedSoft, height: 1.45),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (ctx) => PillButton(
              label: l.homeNoPlanCta,
              trailingIcon: Icons.arrow_forward,
              onPressed: () => ctx.push('/plans'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends ConsumerWidget {
  const _CategoryGrid({required this.onTapCategory});
  final ValueChanged<String> onTapCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    // Backend is the single source of truth — no seed fallback.
    // Counts read off `gymsListProvider`, which fetches `/api/v1/gyms`
    // on first read and re-fetches on pull-to-refresh. Empty live
    // list → category tile shows "0 clubs", which is the truthful
    // state when the backend has no rows in that category.
    final live = ref.watch(gymsListProvider).valueOrNull ?? const [];
    int categoryCount(String cat) {
      return live.where((g) => g.category == cat).length;
    }
    final cats = <(String, String, Color)>[
      ('gym', l.categoryGym, GPCategory.gym),
      ('crossfit', l.categoryCross, GPCategory.crossfit),
      ('martial', l.categoryMartial, GPCategory.martial),
      ('yoga', l.categoryYoga, GPCategory.yoga),
    ];
    // Aspect ratio tightened from 1.8 → 2.4 so the tiles aren't
    // unnecessarily tall — at 1.8 the `spaceBetween` column left a
    // visible empty band between the eyebrow and the count, which
    // read as a layout bug. 2.4 lets the label sit just above the
    // count with the count anchored to the bottom for visual rhythm.
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: cats.map((c) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onTapCategory(c.$1),
            borderRadius: BorderRadius.circular(GPRadius.lg),
            child: Ink(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(GPRadius.lg),
                border: Border.all(color: c.$3.withValues(alpha: 0.35)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c.$3.withValues(alpha: 0.18), gp.bg2],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    c.$2,
                    style: GPText.mono(
                      size: 10,
                      letterSpacing: 1.8,
                      color: c.$3,
                      weight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    l.clubsCount(categoryCount(c.$1)),
                    style: GPText.display(24, color: gp.fg, height: 0.9),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Adapt a backend `GymSummary` into the local `GPGym` shape that
/// `GymRow` consumes. The two diverge for historical reasons (seed
/// data was the only source when GymRow was first written); folding
/// them into a single type is a separate cleanup. This adapter is
/// the only place that bridge lives — every backend-driven render
/// goes through it so we can't accidentally show a hardcoded `seed`
/// row in a list that's supposed to be live.
GPGym _gymSummaryToGPGym(GymSummary s, {required bool isAr}) {
  return GPGym(
    slug: s.slug,
    name: isAr && s.nameAr.isNotEmpty ? s.nameAr : s.nameEn,
    area: s.area ?? '',
    category: s.category ?? 'gym',
    tier: s.tier ?? 'silver',
    lat: s.lat ?? 0,
    lng: s.lng ?? 0,
  );
}
