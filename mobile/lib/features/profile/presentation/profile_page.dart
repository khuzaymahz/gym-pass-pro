import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/glow.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/tier_chip.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/top_bounce_physics.dart';
import '../../../core/widgets/wordmark_refresh.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/user_profile.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../day_pass/data/day_pass.dart';
import '../../day_pass/data/day_pass_repository.dart';
import '../../subscription/data/subscription_state.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final sub = ref.watch(subscriptionProvider);
    final profile = ref.watch(profileProvider);
    final tier = sub.tier;
    final visits = sub.visitsUsed;
    final totalVisits = tier?.visits ?? 0;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final composed = profile.displayName;
    final displayName = composed.isNotEmpty ? composed : l.demoUserName;
    final initials = _initials(displayName);
    return Stack(
      fit: StackFit.expand,
      children: [
        const RadialGlow(
          opacity: 0.12,
          size: 520,
          alignment: Alignment(0, -0.95),
        ),
        // Pull-to-refresh — same physics + behaviour as the home
        // page so the gesture feels identical across the app:
        // bouncing overscroll, dumbbell only during the pull
        // gesture, skeletons swap in via RefreshScope while the
        // fetch is in flight.
        WordmarkRefresh(
          onRefresh: () async {
            // Real refresh — re-fetches from `/me` and
            // `/subscriptions/me` instead of re-awaiting the
            // cached `.ready` future (which after first hydrate
            // is a no-op). Stats column + tier chip update with
            // whatever the backend currently has.
            await Future.wait([
              ref
                  .read(subscriptionProvider.notifier)
                  .refreshFromBackend(throwOnError: true),
              ref
                  .read(profileProvider.notifier)
                  .refreshFromBackend(throwOnError: true),
            ]);
          },
          child: ListView(
            // Top bounces (so pull-to-refresh feels native), bottom
            // clamps (no rebound that members read as a fake refresh
            // when they swipe up past the last row on this short page).
            physics: const AlwaysScrollableScrollPhysics(
              parent: TopBouncePhysics(),
            ),
            padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 24),
            children: [
            Row(children: [Overline(l.profileOverline)]),
            const SizedBox(height: 28),
            Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [GP.limeHi, GP.lime],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: GP.lime.withValues(alpha: 0.45),
                        blurRadius: 24,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  // Avatar initials. `DisplayText` is locale-aware:
                  // EN renders the italic-condensed Archivo, AR uses
                  // upright Tajawal so letterforms stay joined. The
                  // old raw `Text + GPText.display(...)` always
                  // shipped the EN style, mangling Arabic initials
                  // like "مع" with an italic Latin face fallback.
                  child: DisplayText(
                    initials,
                    size: 24,
                    color: GP.ink,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User's display name. Same locale-awareness
                      // story as the avatar above: AR names (the
                      // "Guest Member" fallback "عضو ضيف" included)
                      // need the AR display face so the letterforms
                      // join at the baseline. `DisplayText` also
                      // skips `.toUpperCase()` on AR (no case in
                      // Arabic), so we no longer call it ourselves.
                      DisplayText(displayName, size: 22, color: gp.fg, height: 1.0),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (tier != null) ...[
                            TierChip(tier: tier),
                            const SizedBox(width: 8),
                            Text(l.profileMemberSince,
                                style: GPText.mono(size: 9, letterSpacing: 1.4, color: gp.muted),),
                          ] else
                            _NoPlanChip(l: l, gp: gp),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            // Builder so RefreshScope.of resolves inside the
            // WordmarkRefresh subtree (the outer ProfilePage build
            // context is above WordmarkRefresh and would miss).
            // Ring + stats column carry numbers that change on
            // refresh (visit count, streak); morphing them to
            // skeleton blocks is the clearest signal that the
            // refetch is in flight. The menu list below stays as-is
            // — its rows are static labels, not fetched data.
            Builder(
              builder: (innerCtx) {
                if (RefreshScope.of(innerCtx)) {
                  return _ProfileStatsSkeleton(includeRing: tier != null);
                }
                // Ring gauge only renders when there's an active
                // plan — without a tier the donut would be a
                // placeholder for nothing. The stats card below
                // already covers the empty state's "0 days /
                // No plan" lines.
                return Column(
                  children: [
                    if (tier != null) ...[
                      _ringGauge(
                        context, l, gp,
                        used: visits,
                        total: totalVisits,
                      ),
                      const SizedBox(height: 24),
                    ],
                    _statsColumn(context, l, gp, sub),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            // Active day passes — only renders the card when the
            // member actually has one (or more) bought-but-not-used
            // passes. Empty list = no card at all, no "you have no
            // passes" prompt — the surface is purely informational
            // when there's something to show.
            _DayPassesCard(),
            _menuList(context, l, gp),
            const SizedBox(height: 18),
            _signOutBtn(context, ref, l, gp),
            ],
          ),
        ),
        PositionedDirectional(
          top: topInset + 12,
          end: 20,
          child: IconBtn(
            icon: Icons.settings_outlined,
            onPressed: () => context.push('/settings'),
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final chars = parts.take(2).map((p) => p.characters.first).join();
    return chars.toUpperCase();
  }

  Widget _ringGauge(BuildContext context, AppLocalizations l, GpColors gp,
      {required int used, required int total,}) {
    // Defend against `total == 0` — happens when a member opens
    // Profile before their subscription has hydrated, or when the
    // backend returned a zero-visit plan. Without this guard the
    // ring divides by zero and CustomPaint emits a layout error.
    final percent = total == 0 ? 0.0 : used / total;
    return SizedBox(
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(130, 130),
            // Track colour is `line2` (white at 24% alpha) instead of
            // `bg3` (#17181A — near-black). The dark track was nearly
            // invisible against the page background and made the
            // empty portion of the ring read as "missing" rather than
            // "remaining". A faint white tone lets the ring read as a
            // gauge: filled progress on top, soft track underneath.
            painter:
                _RingPainter(percent, gp.line2, gp.accentHi, gp.accentInk),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$used',
                      style: GPText.display(40, color: gp.fg, height: 0.9),),
                  const SizedBox(width: 4),
                  Text('/$total',
                      style: GPText.display(18, color: gp.muted, height: 0.9),),
                ],
              ),
              const SizedBox(height: 6),
              Text(l.profileVisitsThisMo,
                  style: GPText.mono(
                    size: 9,
                    letterSpacing: 1.6,
                    color: gp.muted,
                  ),),
            ],
          ),
        ],
      ),
    );
  }

  String _localizedTierName(AppLocalizations l, String key) {
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

  Widget _statsColumn(
    BuildContext context,
    AppLocalizations l,
    GpColors gp,
    SubscriptionState sub,
  ) {
    final currentTier = sub.tier;
    final next = sub.nextTier;
    final String nextLabel;
    final Color nextColor;
    if (currentTier == null) {
      // No plan yet: the "next tier" row doubles as the signup nudge.
      nextLabel = l.profileNextTierEmpty;
      nextColor = gp.accentInk;
    } else if (next == null) {
      nextLabel = l.profileNextTierMaxed;
      nextColor = currentTier.readableOn(gp);
    } else {
      nextLabel = _localizedTierName(l, next.key).toUpperCase();
      nextColor = next.readableOn(gp);
    }
    final stats = [
      (l.profileStreak, l.profileStreakDays(sub.streakDays), gp.accentInk),
      (l.profileThisMonth, l.profileVisitsCount(sub.visitsUsed).toUpperCase(), gp.fg),
      (l.profileNextTier, nextLabel, nextColor),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
        boxShadow: gp.cardShadows,
      ),
      child: Column(
        children: stats
            .asMap()
            .entries
            .map(
              (e) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Text(e.value.$1,
                            style: GPText.mono(size: 10, letterSpacing: 1.6, color: gp.mutedSoft),),
                        const Spacer(),
                        Text(e.value.$2,
                            style: GPText.mono(size: 12, letterSpacing: 1, color: e.value.$3, weight: FontWeight.w600),),
                      ],
                    ),
                  ),
                  if (e.key < stats.length - 1) Container(height: 1, color: gp.line),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _menuList(BuildContext context, AppLocalizations l, GpColors gp) {
    final rows = [
      (Icons.workspace_premium_outlined, l.profileMenuSubscription,
          () => context.push('/subscription')),
      // Favorites lives in the You menu (rather than its own tab) so
      // members reach it the same way they reach Notifications and
      // Billing — via "manage my account stuff" rather than a top-
      // level surface. The same set powers the Explore filter.
      (Icons.favorite_border, l.profileMenuFavorites,
          () => context.push('/favorites')),
      (Icons.notifications_none, l.profileMenuNotifications,
          () => context.push('/notifications')),
      (Icons.receipt_long, l.profileMenuBilling,
          () => context.push('/billing')),
      (Icons.card_giftcard_outlined, l.profileMenuInvite,
          () => context.push('/invite')),
      (Icons.help_outline, l.profileMenuHelp,
          () => context.push('/help')),
      (Icons.settings_outlined, l.profileMenuSettings,
          () => context.push('/settings')),
    ];
    return Container(
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
        boxShadow: gp.cardShadows,
      ),
      child: Column(
        children: rows
            .asMap()
            .entries
            .map(
              (e) => Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: e.value.$3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: e.key < rows.length - 1
                            ? BorderSide(color: gp.line)
                            : BorderSide.none,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(e.value.$1, size: 18, color: gp.fg),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(e.value.$2,
                              style: GPText.body(size: 14, color: gp.fg, weight: FontWeight.w500),),
                        ),
                        Icon(Icons.arrow_forward_ios, size: 12, color: gp.muted),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _confirmLogout(
      BuildContext context, WidgetRef ref, AppLocalizations l,) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.logoutConfirmTitle),
        content: Text(l.logoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: GP.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.logoutConfirmYes),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await ref.read(authControllerProvider.notifier).logout();
      if (context.mounted) context.go('/sign-in');
    }
  }

  Widget _signOutBtn(BuildContext context, WidgetRef ref,
      AppLocalizations l, GpColors gp,) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
        boxShadow: gp.cardShadows,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(GPRadius.lg),
          onTap: () => _confirmLogout(context, ref, l),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.logout, size: 18, color: GP.danger),
                const SizedBox(width: 14),
                Text(l.profileLogout,
                    style: GPText.body(size: 14, color: GP.danger, weight: FontWeight.w600),),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Header chip shown to members who haven't subscribed yet. Mirrors the
/// shape of [TierChip] so the profile header never looks empty, but uses
/// the accent lime instead of a tier color — there is no tier to render.
class _NoPlanChip extends StatelessWidget {
  const _NoPlanChip({required this.l, required this.gp});
  final AppLocalizations l;
  final GpColors gp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: gp.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(GPRadius.sm),
        border: Border.all(color: gp.accent.withValues(alpha: 0.55)),
      ),
      child: Text(
        l.profileNoPlanChip.toUpperCase(),
        style: GPText.mono(
          size: 9,
          letterSpacing: 1.4,
          color: gp.accentInk,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percent;
  final Color trackColor;
  final Color sweepStart;
  final Color sweepEnd;
  _RingPainter(this.percent, this.trackColor, this.sweepStart, this.sweepEnd);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = trackColor;
    canvas.drawCircle(center, radius, bg);

    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [sweepStart, sweepEnd],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    const start = -math.pi / 2;
    final sweep = 2 * math.pi * percent;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.percent != percent ||
      old.trackColor != trackColor ||
      old.sweepStart != sweepStart ||
      old.sweepEnd != sweepEnd;
}


/// Skeleton stand-in for the ring gauge + stats rows during pull-to-
/// refresh. Same outer dimensions as the real block so the menu
/// list below doesn't shift when the real numbers come back.
class _ProfileStatsSkeleton extends StatelessWidget {
  const _ProfileStatsSkeleton({required this.includeRing});

  /// True when the live screen is rendering the ring (i.e. member
  /// has an active plan). Skeleton layout has to mirror the live
  /// layout exactly — including a ring placeholder when there isn't
  /// one in the real view would make the page jump down ~200 px
  /// when the refresh resolves and the placeholder is replaced by
  /// the (shorter) no-ring real content.
  final bool includeRing;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Column(
      children: [
        if (includeRing) ...[
          // Ring placeholder — must match the live `_ringGauge`'s
          // dimensions exactly so the layout doesn't shift when the
          // skeleton is replaced by the real ring on refresh
          // resolve. Earlier this circle was 180×180 (live is
          // 130×130), so the skeleton looked dramatically larger
          // than the actual figure it stood in for, reading as
          // "still loading" even after the data had arrived.
          //
          // Outer SizedBox height = 140 to mirror the live gauge's
          // own SizedBox; the circle itself is 130×130 painted
          // matching the live ring's CustomPaint size. Inner
          // SkeletonBox sizes match the live text block (a 40-pt
          // number row + 9-pt label) so the skeleton scans as the
          // same shape, not a same-coloured-but-wrong placeholder.
          SizedBox(
            height: 140,
            child: Center(
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gp.bg2,
                  border: Border.all(color: gp.line),
                ),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SkeletonBox(height: 28, width: 64),
                    SizedBox(height: 6),
                    SkeletonBox(height: 9, width: 54),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        // Stats card — three rows of label + value, matching the
        // live `_statsColumn` shape.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          decoration: BoxDecoration(
            color: gp.bg2,
            borderRadius: BorderRadius.circular(GPRadius.lg),
            border: Border.all(color: gp.line),
            boxShadow: gp.cardShadows,
          ),
          child: Column(
            children: [
              for (var i = 0; i < 3; i++) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      SkeletonBox(height: 11, width: 90),
                      Spacer(),
                      SkeletonBox(height: 11, width: 60),
                    ],
                  ),
                ),
                if (i < 2) Container(height: 1, color: gp.line),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "Active passes" card — renders the member's outstanding day
/// passes with a live countdown until expiry. Hidden entirely
/// when the member has none, so non-day-pass users aren't shown
/// an empty-state prompt to subscribe.
///
/// Reads `myDayPassesProvider`. The provider auto-disposes when
/// the screen leaves, so we don't keep a stale list cached after
/// the user navigates away.
class _DayPassesCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final async = ref.watch(myDayPassesProvider);
    final now = DateTime.now().toUtc();
    final passes = (async.valueOrNull ?? const <DayPass>[])
        .where((p) => p.isActive(now))
        .toList();

    if (passes.isEmpty) {
      // No card when there's nothing to show. Loading + error
      // states also collapse to nothing — the Profile screen
      // doesn't need to spin a skeleton for a card that may not
      // exist at all.
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: gp.bg2,
          borderRadius: BorderRadius.circular(GPRadius.md),
          border: Border.all(color: gp.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_activity_outlined,
                  size: 16,
                  color: gp.accentInk,
                ),
                const SizedBox(width: 8),
                Text(
                  l.profileDayPassesTitle.toUpperCase(),
                  style: GPText.mono(
                    size: 10,
                    letterSpacing: 1.8,
                    color: gp.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < passes.length; i++) ...[
              if (i > 0)
                Container(
                  height: 1,
                  color: gp.line,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                ),
              _DayPassRow(pass: passes[i], isAr: isAr, l: l, gp: gp),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayPassRow extends StatelessWidget {
  const _DayPassRow({
    required this.pass,
    required this.isAr,
    required this.l,
    required this.gp,
  });

  final DayPass pass;
  final bool isAr;
  final AppLocalizations l;
  final GpColors gp;

  /// Color-coded urgency for the countdown line. Lime (the brand
  /// accent) means "plenty of time left", amber means "use it
  /// soon", red means "minutes away from expiring". The thresholds
  /// (4h amber, 1h red) match what gym staff treat as the
  /// "imminent visit" window — if a member still hasn't shown up
  /// with <1h on the clock, the pass is at real risk of expiring
  /// unused.
  Color _countdownColor(Duration remaining) {
    if (remaining.isNegative) return GP.danger;
    if (remaining.inMinutes < 60) return GP.danger;
    if (remaining.inHours < 4) return GP.warn;
    return gp.accentInk;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final remaining = pass.expiresAt.difference(now);
    final urgent = !remaining.isNegative && remaining.inMinutes < 60;
    final countdownColor = _countdownColor(remaining);
    final countdownText = l.profileDayPassExpiresIn(
      _formatRemainingDuration(pass.expiresAt, l),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/gyms/${pass.gymSlug}'),
        borderRadius: BorderRadius.circular(GPRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Pulse-dot when urgent so the row visually flags
              // itself in a card that may carry multiple passes.
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsetsDirectional.only(end: 10),
                decoration: BoxDecoration(
                  color: urgent ? GP.danger : gp.accentInk,
                  shape: BoxShape.circle,
                  boxShadow: urgent
                      ? [
                          BoxShadow(
                            color: GP.danger.withValues(alpha: 0.7),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pass.name(isAr: isAr),
                      style: GPText.body(
                        size: 14,
                        color: gp.fg,
                        weight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      countdownText,
                      style: GPText.body(
                        size: 12,
                        color: countdownColor,
                        weight: urgent ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              // Trailing chevron — affordance that the row is tappable
              // (jumps to the gym detail so the member can scan).
              Icon(
                Icons.chevron_right,
                size: 20,
                color: gp.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Human duration between now and `expiresAt`. Hours when ≥1h
  /// remaining, minutes when 1–59m, "Less than a minute" below
  /// that, "Expired" when in the past. Pluralization handed off
  /// to the ARB-backed `durationHours / durationMinutes` so
  /// Arabic dual/plural forms render correctly.
  static String _formatRemainingDuration(
    DateTime expiresAt,
    AppLocalizations l,
  ) {
    final now = DateTime.now().toUtc();
    final remaining = expiresAt.difference(now);
    if (!remaining.isNegative && remaining.inMinutes < 1) {
      return l.durationLessThanAMinute;
    }
    if (remaining.isNegative) return l.durationExpired;
    if (remaining.inHours >= 1) return l.durationHours(remaining.inHours);
    return l.durationMinutes(remaining.inMinutes);
  }
}
