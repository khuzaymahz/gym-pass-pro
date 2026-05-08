import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/glow.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/tier_chip.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/top_bounce_physics.dart';
import '../../../core/widgets/wordmark_refresh.dart';
import '../../../l10n/app_localizations.dart';
import '../data/subscription_state.dart';

class MySubscriptionPage extends ConsumerWidget {
  const MySubscriptionPage({super.key});

  String _tierName(AppLocalizations l, String key) {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final sub = ref.watch(subscriptionProvider);
    final tier = sub.tier;
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: RadialGlow(opacity: 0.12, size: 520, alignment: Alignment(0, -0.95)),
          ),
          WordmarkRefresh(
            // Real refresh — re-fetches the live subscription so the
            // visit count, renewal date, and pause window all reflect
            // whatever the backend has right now. Was awaiting
            // `.ready`, which is a resolved future after first hydrate
            // and never re-fetched anything on subsequent pulls.
            onRefresh: () =>
                ref.read(subscriptionProvider.notifier).refreshFromBackend(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: TopBouncePhysics(),
              ),
              padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 20),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Overline(l.subscriptionOverline)],
                ),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    DisplayText(l.subscriptionTitle, size: 36),
                    const SizedBox(width: 10),
                    SerifAccent(l.subscriptionTitleAccent, size: 36),
                  ],
                ),
                const SizedBox(height: 22),
                // Builder so RefreshScope.of resolves inside the
                // WordmarkRefresh subtree (the outer page context
                // sits above and would silently miss).
                Builder(
                  builder: (innerCtx) {
                    final refreshing = RefreshScope.of(innerCtx);
                    // Skeleton in two situations:
                    //   1. Initial cold-start before subscriptionProvider
                    //      has hydrated (`!sub.loaded`) — first paint on
                    //      a slow network would otherwise flash the
                    //      empty-state CTA at a member who actually has
                    //      a plan.
                    //   2. Pull-to-refresh in flight — same rationale
                    //      as the home plan card.
                    if (!sub.loaded || refreshing) {
                      return const _SubscriptionSkeleton();
                    }
                    if (tier == null) {
                      return Column(
                        children:
                            _emptyStateSlivers(context, l, gp),
                      );
                    }
                    return Column(
                      children: _activeStateSlivers(
                        context, ref, l, gp, sub, tier,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          PositionedDirectional(
            top: topInset + 12,
            start: 20,
            child: const BackBtn(),
          ),
        ],
      ),
    );
  }

  List<Widget> _activeStateSlivers(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    GpColors gp,
    SubscriptionState sub,
    GPTier tier,
  ) {
    final used = sub.visitsUsed;
    // Renewal date is guaranteed present whenever [tier] is — they're written
    // together in [SubscriptionNotifier.activate].
    final renewIso = sub.renewIso!;
    final next = GPTier.all.firstWhere(
      (t) => t.rank == tier.rank + 1,
      orElse: () => tier,
    );
    final hasUpgrade = next.key != tier.key;
    final isPaused = sub.isOnPause();
    final isScheduledPause = !isPaused && sub.hasScheduledPause;
    final canPause = !isPaused &&
        !isScheduledPause &&
        !sub.isTermVisitsExhausted &&
        sub.pauseAllowanceDays > 0 &&
        sub.pauseDaysRemaining > 0 &&
        sub.pausesUsed < sub.maxPauses;

    return [
      _bigTierCard(l, gp, sub, tier, used, renewIso),
      const SizedBox(height: 16),
      if (sub.isTermVisitsExhausted) ...[
        _visitsExhaustedCard(context, ref, l, gp),
        const SizedBox(height: 16),
      ],
      if (isPaused || isScheduledPause) ...[
        _pauseStatusCard(context, ref, l, gp, sub, isPaused),
        const SizedBox(height: 16),
      ],
      _perks(l, gp, tier),
      const SizedBox(height: 16),
      if (canPause) ...[
        PillButton(
          label: l.subscriptionPauseCta,
          trailingIcon: Icons.ac_unit_rounded,
          variant: PillVariant.ghost,
          onPressed: () => _openPauseSheet(context, ref, l, gp, sub),
        ),
        const SizedBox(height: 10),
      ],
      if (hasUpgrade)
        PillButton(
          label: l.subscriptionUpgradeTo(_tierName(l, next.key)),
          trailingIcon: Icons.arrow_upward,
          onPressed: () => context.push('/plans'),
        ),
      // Recent-visits feed requires a backend visit-log endpoint. Hiding the
      // section rather than rendering hardcoded sample rows — matches the
      // no-demo-rows rule in CLAUDE.md §9.
    ];
  }

  List<Widget> _emptyStateSlivers(
    BuildContext context,
    AppLocalizations l,
    GpColors gp,
  ) {
    return [
      Container(
        padding: const EdgeInsets.all(22),
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
              l.subscriptionEmptyOverline.toUpperCase(),
              style: GPText.mono(
                size: 10,
                letterSpacing: 1.8,
                color: gp.accentInk,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l.subscriptionEmptyTitle,
              style: GPText.display(32, color: gp.fg, height: 1.0),
            ),
            const SizedBox(height: 12),
            Text(
              l.subscriptionEmptyBlurb,
              style: GPText.body(size: 14, color: gp.mutedSoft, height: 1.5),
            ),
            const SizedBox(height: 18),
            PillButton(
              label: l.subscriptionEmptyCta,
              trailingIcon: Icons.arrow_forward,
              onPressed: () => context.push('/plans'),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _bigTierCard(AppLocalizations l, GpColors gp, SubscriptionState sub,
      GPTier tier, int used, String renewIso,) {
    final total = sub.termTotalVisits;
    final shownUsed = total == 0 ? used : used.clamp(0, total);
    final percent = total == 0 ? 0.0 : (shownUsed / total).clamp(0.0, 1.0);
    final isPaused = sub.isOnPause();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.xl),
        border: Border.all(color: tier.color.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(color: tier.color.withValues(alpha: 0.2), blurRadius: 40, spreadRadius: -12),
          ...gp.cardShadows,
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [tier.color.withValues(alpha: 0.3), tier.color.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TierChip(tier: tier),
                  if (isPaused) ...[
                    const SizedBox(width: 8),
                    _pausedBadge(l, gp),
                  ],
                  const Spacer(),
                  Text(l.subscriptionRenewsOn(renewIso),
                      style: GPText.mono(size: 9, letterSpacing: 1.4, color: gp.mutedSoft),),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                _tierName(l, tier.key).toUpperCase(),
                style: GPText.display(64, color: tier.readableOn(gp), height: 0.88),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$shownUsed', style: GPText.display(32, color: gp.fg, height: 0.9)),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text('/$total ${l.subscriptionVisitLabelCaps}',
                        style: GPText.mono(size: 11, letterSpacing: 1.4, color: gp.mutedSoft),),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(color: gp.bg3, borderRadius: BorderRadius.circular(3)),
                  ),
                  FractionallySizedBox(
                    widthFactor: percent,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: tier.color,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [BoxShadow(color: tier.color.withValues(alpha: 0.5), blurRadius: 10)],
                      ),
                    ),
                  ),
                ],
              ),
              if ((sub.durationMonths ?? 1) > 1) ...[
                const SizedBox(height: 10),
                _termProgressLine(l, gp, sub),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _termProgressLine(
    AppLocalizations l,
    GpColors gp,
    SubscriptionState sub,
  ) {
    final cycle = sub.currentCycleNumber();
    final months = sub.durationMonths;
    final cycleDaysLeft = sub.daysLeftInCycle();
    final termDaysLeft = sub.daysLeftInTerm();
    if (cycle == null || months == null) return const SizedBox.shrink();
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
        size: 10,
        letterSpacing: 1.4,
        color: gp.mutedSoft,
      ),
    );
  }

  Widget _perks(AppLocalizations l, GpColors gp, GPTier tier) {
    final features = l.tierFeatures(tier.key);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
        boxShadow: gp.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.subscriptionPerks,
              style: GPText.mono(size: 10, letterSpacing: 1.8, color: gp.muted),),
          const SizedBox(height: 12),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check, color: tier.readableOn(gp), size: 14),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(f, style: GPText.body(size: 14, color: gp.fg)),
                    ),
                  ],
                ),
              ),),
        ],
      ),
    );
  }

  Widget _pausedBadge(AppLocalizations l, GpColors gp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: gp.accentInk.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(GPRadius.sm),
        border: Border.all(color: gp.accentInk.withValues(alpha: 0.55)),
      ),
      child: Text(
        l.subscriptionPausedBadge,
        style: GPText.mono(
          size: 9,
          letterSpacing: 1.4,
          color: gp.accentInk,
          weight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _pauseStatusCard(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    GpColors gp,
    SubscriptionState sub,
    bool active,
  ) {
    // Active pause: member is currently paused; "resume now" ends the pause
    // early and shifts renewal only by the days actually consumed. Scheduled
    // pause: window sits in the future; ending it here cancels it without
    // consuming days (see [SubscriptionNotifier.endPause]).
    final fromIso = sub.pauseFromIso ?? '';
    final untilIso = sub.pauseUntilIso ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.accentInk.withValues(alpha: 0.45)),
        boxShadow: gp.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.ac_unit_rounded, color: gp.accentInk, size: 18),
              const SizedBox(width: 10),
              Text(
                (active
                        ? l.subscriptionPausedOverline
                        : l.subscriptionPauseScheduledOverline)
                    .toUpperCase(),
                style: GPText.mono(
                  size: 10,
                  letterSpacing: 1.6,
                  color: gp.accentInk,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            active
                ? l.subscriptionPausedBody(untilIso)
                : l.subscriptionPauseScheduledBody(fromIso, untilIso),
            style: GPText.body(size: 13, color: gp.fg, height: 1.45),
          ),
          const SizedBox(height: 14),
          PillButton(
            label: active
                ? l.subscriptionResumeCta
                : l.subscriptionPauseCancelCta,
            trailingIcon: Icons.play_arrow_rounded,
            onPressed: () => _confirmResume(context, ref, l, active),
          ),
        ],
      ),
    );
  }

  Widget _visitsExhaustedCard(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    GpColors gp,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GP.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: GP.danger.withValues(alpha: 0.5)),
        boxShadow: gp.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: GP.danger, size: 18),
              const SizedBox(width: 10),
              Text(
                l.subscriptionVisitsExhaustedTitle.toUpperCase(),
                style: GPText.mono(
                  size: 10,
                  letterSpacing: 1.6,
                  color: GP.danger,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l.subscriptionVisitsExhaustedBody,
            style: GPText.body(size: 13, color: gp.fg, height: 1.45),
          ),
          const SizedBox(height: 14),
          PillButton(
            label: l.subscriptionRenewNowCta,
            trailingIcon: Icons.refresh,
            onPressed: () => _confirmRenewNow(context, ref, l),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmResume(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    bool active,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(active
            ? l.subscriptionResumeConfirmTitle
            : l.subscriptionPauseCancelTitle,),
        content: Text(active
            ? l.subscriptionResumeConfirmBody
            : l.subscriptionPauseCancelBody,),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(subscriptionProvider.notifier).endPause();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.subscriptionResumedSnack)));
  }

  Future<void> _confirmRenewNow(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.subscriptionRenewConfirmTitle),
        content: Text(l.subscriptionRenewConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    HapticFeedback.mediumImpact();
    // Route through /checkout (renewal=1) so the member actually pays for the
    // fresh term — renewing silently in-place bypassed the payment gate.
    context.push('/checkout?renewal=1');
  }

  Future<void> _openPauseSheet(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    GpColors gp,
    SubscriptionState sub,
  ) async {
    HapticFeedback.selectionClick();
    await _PauseSheet.show(context: context, ref: ref, l: l, gp: gp, sub: sub);
  }

}

/// Bottom sheet that lets a member start a pause. Holds its own local state
/// for the draft start date and day count so the member can adjust both
/// before committing — only the Pause button on the sheet calls into the
/// subscription notifier.
class _PauseSheet extends StatefulWidget {
  const _PauseSheet({
    required this.ref,
    required this.l,
    required this.gp,
    required this.sub,
  });

  final WidgetRef ref;
  final AppLocalizations l;
  final GpColors gp;
  final SubscriptionState sub;

  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    required AppLocalizations l,
    required GpColors gp,
    required SubscriptionState sub,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _PauseSheet(ref: ref, l: l, gp: gp, sub: sub),
    );
  }

  @override
  State<_PauseSheet> createState() => _PauseSheetState();
}

class _PauseSheetState extends State<_PauseSheet> {
  late DateTime _from;
  late int _days;

  @override
  void initState() {
    super.initState();
    _from = DateTime.now();
    _days = widget.sub.pauseDaysRemaining.clamp(1, 30);
  }

  int get _maxDays => widget.sub.pauseDaysRemaining;

  DateTime get _until => _from.add(Duration(days: _days));

  String _iso(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime.now(),
      // Don't let the pause start beyond the renewal window — a scheduled
      // pause with nowhere to land would never activate.
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _from = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _submit() async {
    HapticFeedback.mediumImpact();
    final fromIso = _iso(_from);
    final untilIso = _iso(_until);
    await widget.ref
        .read(subscriptionProvider.notifier)
        .startPause(fromIso: fromIso, untilIso: untilIso);
    if (!mounted) return;
    Navigator.of(context).pop();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final isNow = _from.difference(DateTime.now()).inDays <= 0;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            isNow
                ? widget.l.subscriptionPausedNowSnack(untilIso)
                : widget.l.subscriptionPauseScheduledSnack(fromIso),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final gp = widget.gp;
    final l = widget.l;
    final fromIso = _iso(_from);
    final untilIso = _iso(_until);
    final isToday = _from.difference(DateTime.now()).inDays <= 0;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, scroll) {
        return Container(
          decoration: BoxDecoration(
            color: gp.bg,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(GPRadius.xl),
            ),
            border: Border.all(color: gp.line),
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: gp.line2,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l.subscriptionPauseSheetTitle,
                style: GPText.display(24, color: gp.fg, height: 1.0),
              ),
              const SizedBox(height: 10),
              Text(
                l.subscriptionPauseSheetBlurb(widget.sub.pauseAllowanceDays),
                style: GPText.body(size: 13, color: gp.mutedSoft, height: 1.5),
              ),
              const SizedBox(height: 16),
              _row(
                gp,
                label: l.subscriptionPauseRemainingLabel,
                value: l.subscriptionPauseRemainingValue(_maxDays),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(GPRadius.md),
                onTap: _pickStart,
                child: _row(
                  gp,
                  label: l.subscriptionPauseStartDateLabel,
                  value: isToday ? l.subscriptionPauseStartNow : fromIso,
                  trailing: Icon(Icons.calendar_today,
                      size: 14, color: gp.accentInk,),
                ),
              ),
              const SizedBox(height: 12),
              _daysStepper(gp, l),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: gp.bg2,
                  borderRadius: BorderRadius.circular(GPRadius.md),
                  border: Border.all(color: gp.line),
                ),
                child: Text(
                  l.subscriptionPauseSummary(fromIso, untilIso),
                  style: GPText.body(size: 13, color: gp.fg, height: 1.4),
                ),
              ),
              const SizedBox(height: 20),
              PillButton(
                label: l.subscriptionPauseStartSubmit,
                trailingIcon: Icons.ac_unit_rounded,
                onPressed:
                    _maxDays == 0 || _days < 1 || _days > _maxDays ? null : _submit,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(
    GpColors gp, {
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.md),
        border: Border.all(color: gp.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: GPText.mono(
                size: 10,
                letterSpacing: 1.4,
                color: gp.muted,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: GPText.body(size: 14, color: gp.fg, weight: FontWeight.w600),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _daysStepper(GpColors gp, AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.md),
        border: Border.all(color: gp.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l.subscriptionPauseDaysLabel.toUpperCase(),
              style: GPText.mono(
                size: 10,
                letterSpacing: 1.4,
                color: gp.muted,
                weight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: _days > 1 ? () => setState(() => _days -= 1) : null,
            icon: Icon(Icons.remove, color: gp.fg),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$_days',
              textAlign: TextAlign.center,
              style: GPText.display(20, color: gp.fg, height: 1.0),
            ),
          ),
          IconButton(
            onPressed:
                _days < _maxDays ? () => setState(() => _days += 1) : null,
            icon: Icon(Icons.add, color: gp.fg),
          ),
        ],
      ),
    );
  }
}

/// Skeleton stand-in for the My Subscription content. Same outer
/// dimensions as the real big-tier card + perks card so the layout
/// doesn't shift when real data lands. Used both on cold-start
/// (before [SubscriptionState.loaded] flips true) and during a
/// pull-to-refresh.
class _SubscriptionSkeleton extends StatelessWidget {
  const _SubscriptionSkeleton();

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Big tier card placeholder.
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: gp.bg2,
            borderRadius: BorderRadius.circular(GPRadius.xl),
            border: Border.all(color: gp.line),
            boxShadow: gp.cardShadows,
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SkeletonBox(height: 22, width: 70, radius: 11),
                  Spacer(),
                  SkeletonBox(height: 12, width: 130),
                ],
              ),
              SizedBox(height: 18),
              SkeletonBox(height: 56, width: 200),
              SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SkeletonBox(height: 32, width: 40),
                  SizedBox(width: 8),
                  SkeletonBox(height: 14, width: 100),
                ],
              ),
              SizedBox(height: 12),
              SkeletonBox(height: 6, radius: 3),
              SizedBox(height: 10),
              SkeletonBox(height: 10, width: 220),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Perks card placeholder — three checkmark rows.
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: gp.bg2,
            borderRadius: BorderRadius.circular(GPRadius.lg),
            border: Border.all(color: gp.line),
            boxShadow: gp.cardShadows,
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(height: 10, width: 90),
              SizedBox(height: 14),
              SkeletonBox(height: 12, width: 220),
              SizedBox(height: 10),
              SkeletonBox(height: 12, width: 180),
              SizedBox(height: 10),
              SkeletonBox(height: 12, width: 240),
            ],
          ),
        ),
      ],
    );
  }
}
