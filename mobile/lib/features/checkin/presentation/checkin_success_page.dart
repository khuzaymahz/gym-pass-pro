import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/glow.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../subscription/data/subscription_state.dart';
import 'checkin_controller.dart';

/// Threshold under which we nudge the member to renew. Five is low enough to
/// feel urgent without false alarms — at three visits/week it's a week and
/// change of runway, which matches how far ahead the user can plan.
const _lowVisitsThreshold = 5;

class CheckinSuccessPage extends ConsumerWidget {
  const CheckinSuccessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkinControllerProvider);
    final sub = ref.watch(subscriptionProvider);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    // Defensive fallbacks. A successful result always carries name/area/slug
    // from the repository; these stubs only surface if the widget is hit
    // mid-flight (e.g. hot-reload) or a partial payload reaches us.
    final gymName = isAr
        ? (state.result?.gymNameAr ?? state.result?.gymNameEn ?? '—')
        : (state.result?.gymNameEn ?? '—');
    final gymArea = state.result?.gymArea ?? '';
    final gymSlug = state.result?.gymSlug;
    final tier = sub.tier!;
    // Prefer the term-cumulative pool so a 6-month Gold sees `174/180` — the
    // monthly count is an implementation detail of billing, not of what the
    // member actually has to spend. Fall back to the tier's monthly cap when
    // `durationMonths` hasn't been hydrated from storage yet.
    final termTotal =
        sub.termTotalVisits > 0 ? sub.termTotalVisits : tier.visits;
    final remaining = state.result?.remainingVisits ??
        (termTotal - sub.visitsUsed).clamp(0, termTotal);
    final daysToRenewal = _daysUntilIso(sub.renewIso);
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final now = DateTime.now();
    final timeLabel = _formatTime12h(now);
    final dateLabel = _formatShortDate(now);

    return Scaffold(
      backgroundColor: gp.bg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: RadialGlow(opacity: 0.22, alignment: Alignment(0, -0.3), size: 620),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Overline('${l.checkinSuccess} · $dateLabel · $timeLabel'),
                  const SizedBox(height: 20),
                  _passBadge(gp, l),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      DisplayText(l.checkinSuccessTitle, size: 36, height: 0.9),
                      const SizedBox(width: 10),
                      SerifAccent(l.checkinSuccessTitleAccent, size: 36),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    gymName.toUpperCase(),
                    style: GPText.display(20, color: gp.fg, height: 1.0),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    gymArea.isEmpty
                        ? '$dateLabel · $timeLabel'
                        : '$dateLabel · $timeLabel · ${gymArea.toUpperCase()}',
                    style: GPText.mono(size: 11, letterSpacing: 1.5, color: gp.muted),
                  ),
                  const SizedBox(height: 18),
                  if (remaining <= _lowVisitsThreshold) ...[
                    _lowVisitsBanner(context, l, gp, remaining),
                    const SizedBox(height: 12),
                  ],
                  _entryDetails(
                    context,
                    l,
                    tier,
                    remaining,
                    termTotal,
                    daysToRenewal,
                    sub,
                  ),
                  const Spacer(),
                  PillButton(
                    label: l.checkinBackHome,
                    trailingIcon: Icons.arrow_forward,
                    onPressed: () {
                      ref.read(checkinControllerProvider.notifier).reset();
                      context.go('/home');
                    },
                  ),
                  const SizedBox(height: 10),
                  if (gymSlug != null)
                    PillButton(
                      label: l.checkinVisitGym,
                      variant: PillVariant.ghost,
                      onPressed: () => context.push('/gyms/$gymSlug'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 12-hour clock with an `AM`/`PM` suffix. Hour 0 (midnight) and hour 12
  /// (noon) both read as `12`, which matches how English speakers write the
  /// boundary without forcing the reader to think about a 24-hour offset.
  String _formatTime12h(DateTime dt) {
    final h24 = dt.hour;
    final h12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24);
    final mm = dt.minute.toString().padLeft(2, '0');
    final suffix = h24 < 12 ? 'AM' : 'PM';
    return '$h12:$mm $suffix';
  }

  /// `DD / MM` in mono digits so the label reads identically on AR and EN.
  /// Avoiding month abbreviations sidesteps a localization rabbit hole for a
  /// field that mostly just needs to answer "today, right?" at a glance.
  String _formatShortDate(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    return '$dd / $mm';
  }

  /// Whole days from *today* to the ISO-coded renewal date. Negative values
  /// clamp to zero so a stale renewal doesn't show a cosmetic "minus seven"
  /// while the backend catches up.
  int? _daysUntilIso(String? iso) {
    if (iso == null) return null;
    final parts = iso.split('-');
    if (parts.length != 3) return null;
    final dt = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = dt.difference(today).inDays;
    return diff < 0 ? 0 : diff;
  }

  // Oversize "PASS" slab — the single visual signal a gym's front-desk
  // staff can read from across a counter. Lime wash + heavy italic display
  // type matches the CTA/accent system without needing a custom asset.
  Widget _passBadge(GpColors gp, AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GPRadius.xl2),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [GP.limeHi, GP.lime],
        ),
        boxShadow: [
          BoxShadow(
            color: GP.lime.withValues(alpha: 0.45),
            blurRadius: 44,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_rounded, color: gp.onLime, size: 20),
              const SizedBox(width: 8),
              Text(
                l.checkinPassEyebrow.toUpperCase(),
                style: GPText.mono(
                  size: 10,
                  letterSpacing: 2.2,
                  color: gp.onLime,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            l.checkinPassLabel,
            style: GPText.display(92, color: gp.onLime, height: 0.88),
          ),
        ],
      ),
    );
  }

  /// Member-facing entry details: visits left on the term pool, days until the
  /// plan renews, and total sessions on this term. The per-visit payment field
  /// was deliberately removed — it told the member what the *gym* is being
  /// paid, which is an operations concern, not a member one.
  Widget _entryDetails(
    BuildContext context,
    AppLocalizations l,
    GPTier tier,
    int remaining,
    int termTotal,
    int? daysToRenewal,
    SubscriptionState sub,
  ) {
    final gp = context.gp;
    final remainingColor =
        remaining <= _lowVisitsThreshold ? GP.danger : gp.accentInk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.xl),
        border: Border.all(color: gp.line),
        boxShadow: gp.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l.checkinEntryDetailsLabel.toUpperCase(),
                style: GPText.mono(
                  size: 10,
                  letterSpacing: 1.8,
                  color: gp.muted,
                  weight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tier.color14,
                  borderRadius: BorderRadius.circular(GPRadius.pill),
                  border: Border.all(color: tier.color44),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tier.glyph,
                      style: TextStyle(
                        color: tier.readableOn(gp),
                        fontSize: 12,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tier.name.toUpperCase(),
                      style: GPText.mono(
                        size: 10,
                        letterSpacing: 1.4,
                        color: tier.readableOn(gp),
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _statCell(
                  gp,
                  value: '$remaining',
                  unit: '/$termTotal',
                  label: l.checkinStatVisitsLeft,
                  valueColor: remainingColor,
                ),
              ),
              Container(width: 1, height: 38, color: gp.line),
              Expanded(
                child: _statCell(
                  gp,
                  value: daysToRenewal != null ? '$daysToRenewal' : '—',
                  unit: '',
                  label: l.checkinStatDaysToRenewal,
                ),
              ),
              Container(width: 1, height: 38, color: gp.line),
              Expanded(
                child: _statCell(
                  gp,
                  value: '#${sub.visitsUsed}',
                  unit: '',
                  label: l.checkinStatThisTerm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Amber-toned nudge shown when the term pool is nearly spent. Leads the
  /// member directly to /plans so they can extend or renew before the next
  /// scan refuses them at the door.
  Widget _lowVisitsBanner(
    BuildContext context,
    AppLocalizations l,
    GpColors gp,
    int remaining,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(GPRadius.lg),
      onTap: () => context.push('/plans'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: GP.danger.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(GPRadius.lg),
          border: Border.all(color: GP.danger.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: GP.danger, size: 18,),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l.checkinLowVisitsWarning(remaining),
                style: GPText.body(
                  size: 12,
                  color: gp.fg,
                  weight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l.checkinViewPlans.toUpperCase(),
              style: GPText.mono(
                size: 10,
                letterSpacing: 1.4,
                color: GP.danger,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: GP.danger, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _statCell(
    GpColors gp, {
    required String value,
    required String unit,
    required String label,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style: GPText.display(22, color: valueColor ?? gp.fg, height: 1.0),),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 3),
              Text(unit,
                  style: GPText.mono(
                    size: 10,
                    letterSpacing: 1.2,
                    color: gp.muted,
                  ),),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: GPText.mono(size: 9, letterSpacing: 1.4, color: gp.muted),
        ),
      ],
    );
  }
}
