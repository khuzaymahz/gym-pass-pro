import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/top_bounce_physics.dart';
import '../../../l10n/app_localizations.dart';
import '../../gyms/data/gym_repository.dart';
import '../../gyms/data/gym_summary.dart';
import '../../gyms/data/media_url.dart';
import '../data/plan_pricing.dart';
import '../data/subscription_state.dart';
import 'widgets/tier_name_label.dart';
import 'widgets/tier_network_sheet.dart';

/// Selection for the plans page. Nullable so checkout can fall back to the
/// current tier when the user never picked anything. Seeded on first build
/// to either the lowest upgrade above the current tier, the current tier,
/// or the lowest tier overall.
final selectedTierProvider = StateProvider<String?>((_) => null);

/// Commitment length the user picked for the selected tier. Drives the total
/// quoted on /checkout. Defaults to 1 month so first-time visitors see the
/// familiar monthly plan first.
final selectedDurationProvider = StateProvider<int>((_) => 1);

class PlansPage extends ConsumerStatefulWidget {
  const PlansPage({super.key});

  @override
  ConsumerState<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends ConsumerState<PlansPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _seedSelection());
  }

  /// Picks a default selection when the page opens:
  /// 1. first upgrade above current tier (growth path for existing members),
  /// 2. current tier (already on Diamond — nothing above to upgrade to),
  /// 3. lowest tier (first-time subscriber — entry point by default).
  /// Also seeds the commitment length from the member's current cycle so
  /// the CTA reads "This is your current plan" instead of landing on the
  /// default 1-month and showing a spurious "Switch to 1 month" nudge.
  /// Called again when subscription state resolves from the backend, so
  /// the page never lingers on a stale default seed.
  void _seedSelection() {
    if (!mounted) return;
    final sub = ref.read(subscriptionProvider);
    final tierNotifier = ref.read(selectedTierProvider.notifier);
    final durationNotifier = ref.read(selectedDurationProvider.notifier);
    durationNotifier.state = sub.durationMonths ?? 1;
    final current = sub.tier;
    if (current == null) {
      tierNotifier.state = GPTier.all.first.key;
      return;
    }
    final firstUpgrade = GPTier.all.firstWhere(
      (t) => t.rank > current.rank,
      orElse: () => current,
    );
    tierNotifier.state = firstUpgrade.key;
  }

  // Tap only toggles selection; we deliberately do not auto-scroll the tapped
  // card to the top — the page header "CHOOSE your tier" must stay visible as
  // the user browses. Expansion animates in place under the finger.
  void _onSelectTier(GPTier tier) {
    HapticFeedback.selectionClick();
    ref.read(selectedTierProvider.notifier).state = tier.key;
  }

  void _onSelectDuration(int months) {
    if (ref.read(selectedDurationProvider) == months) return;
    HapticFeedback.selectionClick();
    ref.read(selectedDurationProvider.notifier).state = months;
  }

  Future<void> _confirmAndCheckout(
    String confirmTitle,
    String confirmBody,
    AppLocalizations l,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(confirmTitle),
        content: Text(confirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    HapticFeedback.mediumImpact();
    context.push('/checkout');
  }

  String _durationLabel(AppLocalizations l, int months) {
    switch (months) {
      case 3:
        return l.plansDuration3Months;
      case 6:
        return l.plansDuration6Months;
      case 12:
        return l.plansDuration12Months;
      default:
        return l.plansDuration1Month;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    ref.listen<SubscriptionState>(subscriptionProvider, (prev, next) {
      if (prev?.tierKey != next.tierKey ||
          prev?.durationMonths != next.durationMonths) {
        _seedSelection();
      }
    });
    final sub = ref.watch(subscriptionProvider);
    final currentTier = sub.tier;
    final selectedKey = ref.watch(selectedTierProvider);
    final selectedDuration = ref.watch(selectedDurationProvider);
    // Live network — same `/api/v1/gyms` payload the home and explore pages
    // read. While the future is in flight the list is empty, which collapses
    // the per-card avatar stack to "0 GYMS" cleanly rather than flashing
    // stale seed names. Re-fetched whenever Riverpod invalidates the provider
    // (e.g. when the home page pulls to refresh).
    final allGyms =
        ref.watch(gymsListProvider).valueOrNull ?? const <GymSummary>[];
    final apiBaseUrl = ref.watch(envProvider).apiBaseUrl;
    // When nothing is selected and the user has no current tier, fall back
    // to the first tier so the CTA still has something to operate on.
    final selectedTier = selectedKey != null
        ? GPTier.byKey(selectedKey)
        : (currentTier ?? GPTier.all.first);

    final cta = _buildCta(
      l,
      sub,
      currentTier,
      selectedTier,
      selectedDuration,
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Back button is conditional on member state:
            //   - First-time arrival (post-registration): no back
            //     button. The verified phone + captured profile
            //     have already committed; "back" would unwind
            //     nothing and strand the member on a stale auth
            //     screen. The "Skip for now" pill at the bottom
            //     covers the "I'll pick later" intent.
            //   - Returning member visiting /plans to upgrade or
            //     change tier: back button is the only way out
            //     (Skip is hidden for them — they already have a
            //     plan, there's nothing to skip).
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  if (currentTier != null) const BackBtn() else const SizedBox(width: 40),
                  const Spacer(),
                  Overline(l.plansOverline),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  DisplayText(l.plansTitle, size: 36),
                  const SizedBox(width: 10),
                  SerifAccent(l.plansTitleAccent, size: 36),
                ],
              ),
            ),
            Expanded(
              // No pull-to-refresh on the plans page — the tier
              // catalog is a near-static product surface (4 tiers
              // hard-coded into [GPTier.all] + plan rows that change
              // on the order of months when ops adjust pricing). A
              // refresh gesture promised the member fresh data they
              // would never see, and the dumbbell collided with the
              // headline above.
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: TopBouncePhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: GPTier.all.map((t) {
                  final isSel = t.key == selectedTier.key;
                  final isCurrent =
                      currentTier != null && t.key == currentTier.key;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TierCard(
                      tier: t,
                      selected: isSel,
                      isCurrent: isCurrent,
                      gp: gp,
                      l: l,
                      onTap: () => _onSelectTier(t),
                      selectedDuration: selectedDuration,
                      onDurationChanged: _onSelectDuration,
                      allGyms: allGyms,
                      apiBaseUrl: apiBaseUrl,
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PillButton(
                    label: cta.label,
                    trailingIcon: cta.onTap == null ? null : cta.icon,
                    onPressed: cta.onTap,
                  ),
                  // Skip is only offered to first-time visitors. Existing
                  // members navigated here to upgrade or downgrade, so they
                  // already have a plan — there's nothing to skip past.
                  if (currentTier == null) ...[
                    const SizedBox(height: 8),
                    PillButton(
                      label: l.plansSkipForNow,
                      variant: PillVariant.ghost,
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        context.go('/home');
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Three CTA shapes:
  ///  - No subscription → "Subscribe to <tier>" → checkout creates a fresh
  ///    backend subscription.
  ///  - Selection equals current (tier + duration) → disabled "current
  ///    plan" badge.
  ///  - Anything else → "Switch to <tier · duration>" → checkout cancels
  ///    the current sub server-side and buys the new one in the same call.
  ///    Backend doesn't yet support in-place tier swaps or in-place
  ///    duration extensions; cancel-then-buy is honest and audit-clean.
  _CtaSpec _buildCta(
    AppLocalizations l,
    SubscriptionState sub,
    GPTier? current,
    GPTier selected,
    int selectedDuration,
  ) {
    final selectedLabel = _tierLabel(l, selected.key);

    if (current == null) {
      return _CtaSpec(
        label: l.plansSubscribeTo(selectedLabel),
        icon: Icons.arrow_forward,
        onTap: () {
          HapticFeedback.mediumImpact();
          context.push('/checkout');
        },
      );
    }

    final matchesCurrentTier = selected.key == current.key;
    final matchesCurrentDuration = selectedDuration == sub.durationMonths;
    if (matchesCurrentTier && matchesCurrentDuration) {
      return _CtaSpec(label: l.plansCurrentPlanCta);
    }

    final durationLabel = _durationLabel(l, selectedDuration);
    return _CtaSpec(
      label: l.plansSwitchToCta(selectedLabel, durationLabel),
      icon: Icons.swap_horiz,
      onTap: () => _confirmAndCheckout(
        l.plansSwitchConfirmTitle,
        l.plansSwitchConfirmBody(selectedLabel, durationLabel),
        l,
      ),
    );
  }

  String _tierLabel(AppLocalizations l, String key) {
    switch (key) {
      case 'silver':
        return l.tierSilver;
      case 'platinum':
        return l.tierPlatinum;
      case 'diamond':
        return l.tierDiamond;
      case 'gold':
      default:
        return l.tierGold;
    }
  }
}

class _CtaSpec {
  const _CtaSpec({
    required this.label,
    this.icon,
    this.onTap,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
}

class _TierCard extends StatelessWidget {
  final GPTier tier;
  final bool selected;
  final bool isCurrent;
  final VoidCallback onTap;
  final GpColors gp;
  final AppLocalizations l;

  /// Commitment length currently chosen for the selected tier. The picker
  /// inside the card is only rendered when [selected] is true, but the value
  /// is passed to every card so an unselected tier can still show the
  /// prospective total if we ever expand the layout.
  final int selectedDuration;
  final ValueChanged<int> onDurationChanged;

  /// Authoritative network — live `/api/v1/gyms` payload, the same list the
  /// home and explore surfaces read. Each card filters this down to the
  /// gyms its tier rank unlocks; when the future is still loading the list
  /// is empty and the preview collapses to "0 GYMS" rather than flashing
  /// stale seed data.
  final List<GymSummary> allGyms;

  /// Base URL the live image proxy serves logos from. Forwarded into
  /// `_MiniAvatar` so it can resolve relative `logoUrl` paths the same
  /// way the gym detail header and the explore tile do.
  final String apiBaseUrl;

  const _TierCard({
    required this.tier,
    required this.selected,
    required this.isCurrent,
    required this.onTap,
    required this.gp,
    required this.l,
    required this.selectedDuration,
    required this.onDurationChanged,
    required this.allGyms,
    required this.apiBaseUrl,
  });

  String get _localizedTierName {
    switch (tier.key) {
      case 'silver':
        return l.tierSilver;
      case 'platinum':
        return l.tierPlatinum;
      case 'diamond':
        return l.tierDiamond;
      case 'gold':
      default:
        return l.tierGold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseFeatures = l.tierFeatures(tier.key);
    final total = totalPriceForDuration(tier.price, selectedDuration);
    final effectivePerMonth = (total / selectedDuration).round();
    final totalVisits = tier.visits * selectedDuration;
    final accent = tier.readableOn(gp);
    // Lowest monthly rate across all durations, used for the collapsed
    // "FROM X JOD/MO" teaser so the discount is visible before a user expands.
    final lowestPerMonth = _lowestEffectivePerMonth(tier.price);
    final networkGyms = filterGymsForTier(allGyms, tier);
    final features = baseFeatures;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GPRadius.xl),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.all(selected ? 20 : 16),
          // Clip the inner Stack to the rounded border so the
          // tier-coloured radial glow (positioned at right:-20,
          // top:-20 inside the Stack) doesn't bleed past the card's
          // top-right corner. Without antiAlias clipping the glow
          // showed as a hard rectangular ear poking out of the card,
          // which read as a broken / incomplete border.
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: gp.bg2,
            borderRadius: BorderRadius.circular(GPRadius.xl),
            // Border + selection ring use the readable variant so
            // platinum / diamond / silver don't wash out on the
            // off-white light-mode surface. Glow shadow below
            // keeps the dark-mode hex on purpose — alpha 0.22
            // mutes it enough that it survives on either theme
            // and preserves the same warm/cool aura the brand
            // colour evokes.
            border: Border.all(
              color: selected
                  ? tier.readableOn(gp)
                  : isCurrent
                      ? tier.readableOn(gp).withValues(alpha: 0.5)
                      : gp.line,
              width: selected ? 1.4 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: tier.color.withValues(alpha: 0.22),
                      blurRadius: 28,
                      spreadRadius: -8,
                      offset: const Offset(0, 10),
                    ),
                    ...gp.cardShadows,
                  ]
                : gp.cardShadows,
          ),
          child: Stack(
            children: [
              if (selected)
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          tier.color.withValues(alpha: 0.22),
                          tier.color.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 12),
                    _NetworkPreview(
                      gyms: networkGyms,
                      accent: accent,
                      gp: gp,
                      apiBaseUrl: apiBaseUrl,
                      countLabel: l.plansNetworkCount(networkGyms.length),
                      onTap: () => TierNetworkSheet.show(
                        context: context,
                        tier: tier,
                        localizedTierName: _localizedTierName,
                        gyms: networkGyms,
                      ),
                    ),
                    SizedBox(height: selected ? 14 : 10),
                    _summaryLine(
                      collapsed: !selected,
                      effectivePerMonth: effectivePerMonth,
                      lowestPerMonth: lowestPerMonth,
                    ),
                    if (selected) ...[
                      if (features.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        ...features.map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.check,
                                    color: accent,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    f,
                                    style: GPText.body(
                                      size: 13,
                                      color: gp.mutedSoft,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ] else
                        const SizedBox(height: 16),
                      Container(height: 1, color: gp.line),
                      const SizedBox(height: 14),
                      _DurationPicker(
                        tier: tier,
                        selected: selectedDuration,
                        tierColor: accent,
                        gp: gp,
                        l: l,
                        onChanged: onDurationChanged,
                      ),
                      if (selectedDuration > 1) ...[
                        const SizedBox(height: 10),
                        Text(
                          l.plansVisitsIncluded(totalVisits),
                          style: GPText.mono(
                            size: 10,
                            letterSpacing: 1.4,
                            color: gp.muted,
                          ),
                        ),
                      ],
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          l.plansTapToExpand,
                          style: GPText.mono(
                            size: 9,
                            letterSpacing: 1.6,
                            color: gp.muted,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Cheapest per-month rate available across all durations. Used to tease
  /// the longest-commitment discount on the collapsed card — the user sees
  /// "FROM 21 JOD/MO" before having to expand and compare durations.
  int _lowestEffectivePerMonth(int monthlyPrice) {
    var min = monthlyPrice;
    for (final m in availableDurations) {
      final perMonth = (totalPriceForDuration(monthlyPrice, m) / m).round();
      if (perMonth < min) min = perMonth;
    }
    return min;
  }

  Widget _header() {
    return Row(
      children: [
        Text(
          tier.glyph,
          style: TextStyle(
            color: tier.readableOn(gp),
            fontSize: 18,
            height: 1,
          ),
        ),
        const SizedBox(width: 8),
        // Per-tier styled wordmark — silver flat / gold warm bloom /
        // platinum shimmer / diamond sparkle. Card chrome (border,
        // glow, layout) stays uniform; only the name treatment
        // differs so the four tiers feel materially distinct without
        // rearranging the row.
        TierNameLabel(tier: tier, label: _localizedTierName),
        const SizedBox(width: 10),
        if (isCurrent)
          _statusBadge(
            label: l.plansCurrentPlan,
            tint: tier.readableOn(gp),
          ),
        const Spacer(),
        _selectionIndicator(),
      ],
    );
  }

  /// Compact two-number read for the card headline.
  /// - Collapsed: "30 VISITS/MO · FROM X JOD/MO" — teases the longest discount.
  /// - Expanded: "30 VISITS/MO · X JOD/MO"       — the current duration's rate.
  /// Numbers stay in display face for continuity with the price system; labels
  /// stay mono so metadata has a distinct typographic rank.
  Widget _summaryLine({
    required bool collapsed,
    required int effectivePerMonth,
    required int lowestPerMonth,
  }) {
    final visitsSize = collapsed ? 22.0 : 28.0;
    final priceSize = collapsed ? 22.0 : 28.0;
    final accent = tier.readableOn(gp);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 10,
      runSpacing: 6,
      children: [
        _monoNumber(
          number: '${tier.visits}',
          label: l.plansVisitsPerMonth,
          size: visitsSize,
          numberColor: gp.fg,
          labelColor: gp.muted,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: gp.line2,
              shape: BoxShape.circle,
            ),
          ),
        ),
        collapsed
            ? _fromPrice(lowestPerMonth: lowestPerMonth, accent: accent)
            : _monoNumber(
                number: '$effectivePerMonth',
                label: l.plansPerMonth,
                size: priceSize,
                numberColor: accent,
                labelColor: gp.muted,
              ),
      ],
    );
  }

  Widget _monoNumber({
    required String number,
    required String label,
    required double size,
    required Color numberColor,
    required Color labelColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          number,
          style: GPText.display(size, color: numberColor, height: 0.9),
        ),
        const SizedBox(width: 6),
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            label,
            style: GPText.mono(
              size: 10,
              letterSpacing: 1.4,
              color: labelColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _fromPrice({required int lowestPerMonth, required Color accent}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        l.plansStartsFrom(lowestPerMonth),
        style: GPText.mono(
          size: 11,
          letterSpacing: 1.4,
          color: accent,
          weight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _selectionIndicator() {
    final ringColor = tier.readableOn(gp);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? ringColor : gp.line2,
          width: 1.4,
        ),
        color: selected ? ringColor : Colors.transparent,
      ),
      // Check ink: always paper colour on the filled ring so it
      // pops in either theme. The ring itself carries the tier
      // chroma; the check carries the contrast.
      child: selected
          ? Icon(
              Icons.check,
              color: ThemeData.estimateBrightnessForColor(ringColor) ==
                      Brightness.dark
                  ? Colors.white
                  : GP.ink,
              size: 14,
            )
          : null,
    );
  }

  Widget _statusBadge({required String label, required Color tint}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(GPRadius.sm),
        border: Border.all(color: tint.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: GPText.mono(
          size: 9,
          letterSpacing: 1.4,
          color: tier.readableOn(gp),
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Horizontal row of commitment-length cards. Each card shows its own total
/// and per-month rate so the user can compare savings at a glance without
/// cross-referencing a separate total line. Scrolls horizontally when a
/// narrower device can't fit four cards side by side.
class _DurationPicker extends StatelessWidget {
  final GPTier tier;
  final int selected;
  final Color tierColor;
  final GpColors gp;
  final AppLocalizations l;
  final ValueChanged<int> onChanged;

  const _DurationPicker({
    required this.tier,
    required this.selected,
    required this.tierColor,
    required this.gp,
    required this.l,
    required this.onChanged,
  });

  String _durationLabel(int months) {
    switch (months) {
      case 3:
        return l.plansDuration3Months;
      case 6:
        return l.plansDuration6Months;
      case 12:
        return l.plansDuration12Months;
      default:
        return l.plansDuration1Month;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Four duration cards at 104px + 10px gaps overflow ~375px devices by one
    // card, so the 12-month option lives off-screen until the user swipes.
    // The heading-trailing "SWIPE FOR 1 YEAR" cue plus a fade + chevron on the
    // trailing edge of the list announces the hidden content without stealing
    // space from the cards themselves.
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l.plansDurationHeading,
              style: GPText.mono(
                size: 10,
                letterSpacing: 1.8,
                color: gp.muted,
                weight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(
              isRtl ? Icons.chevron_left : Icons.chevron_right,
              size: 14,
              color: tierColor.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 4),
            Text(
              l.plansDurationSwipeHint,
              style: GPText.mono(
                size: 9,
                letterSpacing: 1.4,
                color: tierColor.withValues(alpha: 0.9),
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 128,
          child: Stack(
            children: [
              ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 0,
                  right: isRtl ? 0 : 28,
                ),
                itemCount: availableDurations.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final months = availableDurations[i];
                  final discount = discountPercentForDuration(months);
                  final total = totalPriceForDuration(tier.price, months);
                  final perMonth = (total / months).round();
                  return _DurationCard(
                    label: _durationLabel(months),
                    total: total,
                    perMonth: perMonth,
                    discount: discount,
                    active: months == selected,
                    tierColor: tierColor,
                    gp: gp,
                    l: l,
                    onTap: () => onChanged(months),
                  );
                },
              ),
              Positioned(
                top: 0,
                bottom: 0,
                right: isRtl ? null : 0,
                left: isRtl ? 0 : null,
                width: 28,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: isRtl
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        end: isRtl
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        colors: [
                          gp.bg2.withValues(alpha: 0),
                          gp.bg2,
                        ],
                      ),
                    ),
                    child: Align(
                      alignment: isRtl
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          isRtl ? Icons.chevron_left : Icons.chevron_right,
                          size: 16,
                          color: tierColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Vertical card for one commitment length. The total price gets display face
/// weight to establish the primary comparison axis; the per-month rate and
/// savings badge provide secondary context. Only shows a per-month line when
/// the duration > 1 — the 1-month card's total IS its per-month rate.
class _DurationCard extends StatelessWidget {
  final String label;
  final int total;
  final int perMonth;
  final int discount;
  final bool active;
  final Color tierColor;
  final GpColors gp;
  final AppLocalizations l;
  final VoidCallback onTap;

  const _DurationCard({
    required this.label,
    required this.total,
    required this.perMonth,
    required this.discount,
    required this.active,
    required this.tierColor,
    required this.gp,
    required this.l,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final showsPerMonth = perMonth != total;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 104,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: active ? tierColor.withValues(alpha: 0.14) : gp.bg,
            borderRadius: BorderRadius.circular(GPRadius.lg),
            border: Border.all(
              color: active ? tierColor : gp.line,
              width: active ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GPText.mono(
                  size: 10,
                  letterSpacing: 1.4,
                  color: active ? tierColor : gp.mutedSoft,
                  weight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$total',
                    style: GPText.display(
                      24,
                      color: active ? tierColor : gp.fg,
                      height: 0.9,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      'JOD',
                      style: GPText.mono(
                        size: 9,
                        letterSpacing: 1.2,
                        color: gp.muted,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (showsPerMonth)
                Text(
                  l.plansDurationCardPerMonth(perMonth),
                  style: GPText.mono(
                    size: 10,
                    letterSpacing: 1.2,
                    color: gp.muted,
                  ),
                )
              else
                const SizedBox(height: 12),
              const SizedBox(height: 6),
              if (discount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: active ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(GPRadius.sm),
                  ),
                  child: Text(
                    l.plansDurationSave(discount),
                    style: GPText.mono(
                      size: 9,
                      letterSpacing: 1.2,
                      color: tierColor,
                      weight: FontWeight.w700,
                    ),
                  ),
                )
              else
                const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar stack + "+N GYMS" pill, the core visual signal that the tier's
/// differentiator is the *gym network*, not the visit count. Tapping opens
/// the full network list in a bottom sheet. Renders inline on every card
/// (selected or not) because network scale is the first thing a user
/// compares across tiers.
///
/// The avatars are real partner logos pulled from the backend — when a
/// partner uploads a wordmark in the gym-partner portal it shows up here
/// the next time `gymsListProvider` refreshes. Gyms without an uploaded
/// logo fall back to a tier-coloured initial disc (same monogram rule the
/// gym detail header and explore-map pin popup use), so the preview is
/// never blank.
class _NetworkPreview extends StatelessWidget {
  final List<GymSummary> gyms;
  final Color accent;
  final GpColors gp;
  final String apiBaseUrl;
  final String countLabel;
  final VoidCallback onTap;

  const _NetworkPreview({
    required this.gyms,
    required this.accent,
    required this.gp,
    required this.apiBaseUrl,
    required this.countLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Render up to 3 overlapping avatars; anything beyond rolls into the count.
    final preview = gyms.take(3).toList();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GPRadius.pill),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(GPRadius.pill),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (preview.isNotEmpty)
                SizedBox(
                  width: 22.0 + (preview.length - 1) * 14.0,
                  height: 24,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var i = 0; i < preview.length; i++)
                        Positioned(
                          left: i * 14.0,
                          child: _MiniAvatar(
                            gym: preview[i],
                            accent: accent,
                            bg: gp.bg2,
                            apiBaseUrl: apiBaseUrl,
                          ),
                        ),
                    ],
                  ),
                ),
              if (preview.isNotEmpty) const SizedBox(width: 10),
              Text(
                countLabel.toUpperCase(),
                style: GPText.mono(
                  size: 10,
                  letterSpacing: 1.4,
                  color: accent,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: accent, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// 22px overlapping disc that previews one gym in the tier-card pill.
/// When the backend record carries a `logoUrl` we render it through
/// `Image.network` (resolved against the live image proxy), otherwise
/// we fall back to the tier-coloured single-letter monogram. The outer
/// border uses the card surface so the stacked discs read as separated
/// even when they overlap by 14px.
class _MiniAvatar extends StatelessWidget {
  final GymSummary gym;
  final Color accent;
  final Color bg;
  final String apiBaseUrl;

  const _MiniAvatar({
    required this.gym,
    required this.accent,
    required this.bg,
    required this.apiBaseUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final displayName =
        isAr && gym.nameAr.isNotEmpty ? gym.nameAr : gym.nameEn;
    // `.characters.first` avoids slicing a multi-byte grapheme (matters for
    // AR gym names where one displayed letter spans multiple code units).
    final initial = displayName.isEmpty
        ? '·'
        : displayName.characters.first.toUpperCase();
    final logoUrl = gym.logoUrl;
    final hasLogo = logoUrl != null && logoUrl.isNotEmpty;
    final resolved = hasLogo ? resolveMediaUrl(apiBaseUrl, logoUrl) : null;
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
    // 22 logical px × DPR × 2 (Hero / scaling headroom), capped so we
    // never ask the decoder for more than 96 raw pixels for what is at
    // most a 22-px disc — keeps the avatar stack light enough to render
    // every tier card without a noticeable hitch on list scroll.
    final pixelSize = (22 * dpr * 2).round().clamp(48, 96);
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.22),
        border: Border.all(color: bg, width: 2),
      ),
      child: hasLogo
          ? CachedNetworkImage(
              imageUrl: resolved!,
              fit: BoxFit.cover,
              width: 22,
              height: 22,
              memCacheWidth: pixelSize,
              memCacheHeight: pixelSize,
              maxWidthDiskCache: pixelSize,
              maxHeightDiskCache: pixelSize,
              fadeInDuration: const Duration(milliseconds: 160),
              placeholder: (_, __) =>
                  _MonogramText(initial: initial, color: accent),
              errorWidget: (_, __, ___) =>
                  _MonogramText(initial: initial, color: accent),
            )
          : _MonogramText(initial: initial, color: accent),
    );
  }
}

class _MonogramText extends StatelessWidget {
  const _MonogramText({required this.initial, required this.color});

  final String initial;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      initial,
      style: GPText.display(11, color: color, height: 1.0),
    );
  }
}
