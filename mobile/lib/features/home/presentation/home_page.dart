import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../../core/widgets/gp_scaffold.dart';
import '../../../core/widgets/help_button.dart';
import '../../../core/widgets/top_bounce_physics.dart';
import '../../../core/widgets/wordmark_refresh.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/user_profile.dart';
import '../../../core/di/providers.dart';
import '../../gyms/data/gym_repository.dart';
import '../../gyms/data/gym_summary.dart';
import '../../gyms/data/home_region_store.dart';
import '../../gyms/data/location_service.dart';
import '../../gyms/data/media_url.dart';
import '../../gyms/presentation/gyms_filter_state.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../subscription/data/subscription_state.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _locationBootstrapped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureUserLocation();
    });
  }

  Future<void> _ensureUserLocation() async {
    if (_locationBootstrapped) return;
    _locationBootstrapped = true;

    if (ref.read(userPositionProvider) != null) return;

    final regionStore = ref.read(homeRegionStoreProvider);
    final stored = await regionStore.read();
    if (!mounted) return;
    if (stored != null && ref.read(userPositionProvider) == null) {
      ref.read(userPositionProvider.notifier).state = stored;
    }

    final result = await ref.read(locationServiceProvider).currentPosition();
    if (!mounted || !result.hasPosition) return;
    final pos = result.position!;
    final fresh = HomeLocation(lat: pos.latitude, lng: pos.longitude);
    ref.read(userPositionProvider.notifier).state = fresh;
    await regionStore.write(pos.latitude, pos.longitude);
  }

  Future<void> _handleRefresh() async {
    await Future.wait<void>([
      ref
          .read(subscriptionProvider.notifier)
          .refreshFromBackend(throwOnError: true),
      ref
          .read(profileProvider.notifier)
          .refreshFromBackend(throwOnError: true),
      ref.read(gymsListStateProvider.notifier).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final sub = ref.watch(subscriptionProvider);
    final profile = ref.watch(profileProvider);
    final gymsAsync = ref.watch(gymsListProvider);
    final allGyms = gymsAsync.valueOrNull ?? const <GymSummary>[];
    final isLoadingGyms = gymsAsync.isLoading && allGyms.isEmpty;
    final userPos = ref.watch(userPositionProvider);
    final nearYou = userPos == null
        ? allGyms
        : _sortByDistance(allGyms, userPos.lat, userPos.lng);
    final mq = MediaQuery.of(context);
    final topInset = mq.viewPadding.top;
    final firstName = profile.firstName?.trim();
    final greeting = (firstName != null && firstName.isNotEmpty)
        ? l.homeGreetingName(firstName)
        : l.homeGreetingFallback;

    // Proportional scale so the full home layout fits without scrolling on
    // any device. Content is designed for 780 dp; on shorter screens we
    // compress everything proportionally via Transform.scale so nothing
    // has to be individually resized.
    const kDesignH = 780.0;
    final screenH = mq.size.height;
    final s = (screenH / kDesignH).clamp(0.72, 1.0);
    final logicalH = screenH / s;

    Widget scrollSection = Stack(
      fit: StackFit.expand,
      children: [
        const RadialGlow(
          opacity: 0.12,
          size: 520,
          alignment: Alignment(0, -0.95),
        ),
        WordmarkRefresh(
          onRefresh: _handleRefresh,
          topOffset: topInset + 56,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: TopBouncePhysics(),
            ),
            padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 24),
            children: [
              const Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: [Wordmark(size: 22)],
                ),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 22),
              Builder(
                builder: (innerCtx) {
                  if (RefreshScope.of(innerCtx)) {
                    return const SkeletonPlanCard();
                  }
                  return _PlanCard(sub: sub);
                },
              ),
              const SizedBox(height: 22),
              _sectionHeader(
                context,
                l.homeNearYou,
                gp,
                trailing: l.seeAll,
                onTrailing: () {
                  ref.read(gymsCategoryFilterProvider.notifier).state = 'all';
                  ref
                      .read(exploreSheetOpenOnArrivalProvider.notifier)
                      .state = true;
                  context.go('/explore');
                },
              ),
              const SizedBox(height: 14),
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
                    final listState = ref.watch(gymsListStateProvider);
                    final isOffline = listState.source ==
                            GymsListSource.cached &&
                        listState.items.isEmpty;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: gp.bg2,
                        borderRadius: BorderRadius.circular(GPRadius.lg),
                        border: Border.all(color: gp.line),
                      ),
                      child: Text(
                        isOffline
                            ? l.homeOfflineNoCache
                            : l.homeNoGymsYet,
                        style: GPText.body(size: 13, color: gp.mutedSoft),
                      ),
                    );
                  }
                  final firstThree = nearYou.take(3).toList();
                  final apiBaseUrl = ref.watch(envProvider).apiBaseUrl;
                  return Column(
                    children: firstThree
                        .map(
                          (g) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GymRow(
                              gym: _gymSummaryToGPGym(g),
                              logoUrl: g.logoUrl == null
                                  ? null
                                  : resolveMediaUrl(apiBaseUrl, g.logoUrl!),
                              onTap: () => innerCtx.push('/gyms/${g.slug}'),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
              const _PromoSlider(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );

    // Apply proportional scale when the screen is shorter than the design
    // baseline. The OverflowBox lets the inner content be logically taller
    // than the screen, and Transform.scale compresses it to fit exactly.
    if (s < 0.999) {
      scrollSection = ClipRect(
        child: OverflowBox(
          maxWidth: mq.size.width,
          maxHeight: logicalH,
          alignment: Alignment.topLeft,
          child: Transform.scale(
            scale: s,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: mq.size.width,
              height: logicalH,
              child: scrollSection,
            ),
          ),
        ),
      );
    }

    return GpScaffold(
      tips: [
        HelpTip(icon: Icons.credit_card_outlined, text: l.helpHome3),
        HelpTip(icon: Icons.refresh_rounded, text: l.helpHome2),
        HelpTip(icon: Icons.swap_horiz_rounded, text: l.helpHome1),
      ],
      body: Stack(
        fit: StackFit.expand,
        children: [
          scrollSection,
          Positioned(
            top: topInset + 12,
            right: 20,
            child: Consumer(
              builder: (context, ref, _) {
                final hasUnread = ref
                        .watch(unreadNotificationsCountProvider)
                        .valueOrNull !=
                    null
                    ? ref.watch(unreadNotificationsCountProvider).valueOrNull! >
                        0
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
      ),
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

// ---------------------------------------------------------------------------
// Plan card
// ---------------------------------------------------------------------------

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
    final shownUsed = total == 0 ? used : used.clamp(0, total);
    final percent = total == 0 ? 0.0 : (shownUsed / total).clamp(0.0, 1.0);
    final remaining = total == 0 ? 0 : (total - shownUsed).clamp(0, total);
    final card = Material(
      color: gp.bg2,
      borderRadius: BorderRadius.circular(GPRadius.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(GPRadius.xl),
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/subscription');
        },
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GPRadius.xl),
            border: Border.all(color: gp.line),
            boxShadow: gp.cardShadows,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
              ),
              const SizedBox(height: 18),
              Row(
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
              ),
              const SizedBox(height: 18),
              Stack(
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
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (sub.renewIso != null) ...[
                    Expanded(
                      child: _CycleProgressText(
                        renewIso: sub.renewIso!,
                        durationMonths: sub.durationMonths ?? 1,
                      ),
                    ),
                  ] else
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
              ),
            ],
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
}


/// Renders "MONTH X OF X · CYCLE RESETS IN XD" (multi-month plans) or
/// "TERM RENEWS IN XD" (1-month plans) from live renewal data.
class _CycleProgressText extends StatelessWidget {
  const _CycleProgressText({
    required this.renewIso,
    required this.durationMonths,
  });

  final String renewIso;
  final int durationMonths;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final renewDate = DateTime.parse(renewIso).toLocal();
    final now = DateTime.now();
    final daysLeft = renewDate.difference(now).inDays.clamp(0, 9999);

    String label;
    if (durationMonths > 1) {
      // Compute cycle start by stepping back durationMonths months.
      int startMonth = renewDate.month - durationMonths;
      int startYear = renewDate.year;
      while (startMonth <= 0) {
        startMonth += 12;
        startYear -= 1;
      }
      final cycleStart = DateTime(startYear, startMonth, renewDate.day);
      final monthsElapsed =
          (now.year - cycleStart.year) * 12 + (now.month - cycleStart.month);
      final currentMonth = (monthsElapsed + 1).clamp(1, durationMonths);
      label = l.homeCycleProgress(currentMonth, durationMonths, daysLeft);
    } else {
      label = l.homeTermEndsIn(daysLeft);
    }

    return Text(
      label,
      style: GPText.mono(size: 9, letterSpacing: 1.4, color: gp.muted),
      overflow: TextOverflow.ellipsis,
    );
  }
}

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
          const SizedBox(height: 8),
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
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: () => context.go('/explore'),
              child: Text(
                l.homeNoPlanDayPassLink,
                style: GPText.mono(
                  size: 10,
                  letterSpacing: 1.2,
                  color: gp.muted,
                ).copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: gp.muted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Promo slider
// ---------------------------------------------------------------------------

class _PromoSlider extends ConsumerStatefulWidget {
  const _PromoSlider();

  @override
  ConsumerState<_PromoSlider> createState() => _PromoSliderState();
}

class _PromoSliderState extends ConsumerState<_PromoSlider> {
  final _ctrl = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _advance());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _advance() {
    if (!mounted) return;
    final sub = ref.read(subscriptionProvider);
    final gymCount = ref.read(gymsListProvider).valueOrNull?.length ?? 0;
    final count = _slideCount(sub, gymCount);
    _ctrl.animateToPage(
      (_page + 1) % count,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOut,
    );
  }

  static int _slideCount(SubscriptionState sub, int gymCount) => 3;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final sub = ref.watch(subscriptionProvider);
    final gymCount = ref.watch(gymsListProvider).valueOrNull?.length ?? 0;
    final slides = _buildSlides(context, l, gp, sub, gymCount);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 118,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => slides[i],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(slides.length, (i) {
            final active = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 5,
              height: 5,
              decoration: BoxDecoration(
                color: active ? gp.accentInk : gp.line2,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  List<Widget> _buildSlides(
    BuildContext context,
    AppLocalizations l,
    GpColors gp,
    SubscriptionState sub,
    int gymCount,
  ) {
    return [
      if (sub.tier == null)
        _PromoSlide(
          title: l.homeBannerActivateTitle,
          subtitle: l.homeBannerActivateSub,
          accentColor: gp.accentInk,
          icon: Icons.rocket_launch_outlined,
          onTap: () => context.push('/plans'),
        )
      else if (sub.tier!.rank < GPTier.diamond.rank)
        _PromoSlide(
          title: l.homeBannerUpgradeTitle,
          subtitle: l.homeBannerUpgradeSub,
          accentColor: GP.warn,
          icon: Icons.trending_up_rounded,
          onTap: () => context.push('/subscription'),
        )
      else
        _PromoSlide(
          title: l.homeBannerEliteTitle,
          subtitle: l.homeBannerEliteSub,
          accentColor: GPCategory.yoga,
          icon: Icons.workspace_premium_outlined,
          onTap: () {},
        ),
      _PromoSlide(
        title: l.homeBannerExploreTitle,
        subtitle: l.homeBannerExploreSub(gymCount),
        accentColor: GP.audienceMale,
        icon: Icons.explore_outlined,
        onTap: () => context.go('/explore'),
      ),
      _PromoSlide(
        title: l.homeBannerCheckinTitle,
        subtitle: l.homeBannerCheckinSub,
        accentColor: GP.success,
        icon: Icons.qr_code_scanner,
        onTap: () => StatefulNavigationShell.maybeOf(context)?.goBranch(2),
      ),
    ];
  }
}

class _PromoSlide extends StatelessWidget {
  const _PromoSlide({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color accentColor;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(GPRadius.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GPRadius.xl),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GPRadius.xl),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                accentColor.withValues(alpha: 0.18),
                gp.bg2,
              ],
            ),
            border: Border.all(color: accentColor.withValues(alpha: 0.28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: GPText.display(22, color: gp.fg, height: 1.0),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      subtitle,
                      style: GPText.body(
                        size: 12,
                        color: gp.mutedSoft,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Adapt a backend `GymSummary` into the local `GPGym` shape that
/// `GymRow` consumes. The two diverge for historical reasons (seed
/// data was the only source when GymRow was first written); folding
/// them into a single type is a separate cleanup. This adapter is
/// the only place that bridge lives — every backend-driven render
/// goes through it so we can't accidentally show a hardcoded `seed`
/// row in a list that's supposed to be live.
GPGym _gymSummaryToGPGym(GymSummary s) {
  return gymSummaryToGPGym(s);
}

/// Public adapter — every surface that renders backend gyms through
/// `GymRow` imports this so the field mapping stays in one place.
GPGym gymSummaryToGPGym(GymSummary s) {
  return GPGym(
    slug: s.slug,
    name: s.nameEn,
    area: s.area ?? '',
    category: s.category ?? 'gym',
    tier: s.tier ?? 'silver',
    lat: s.lat ?? 0,
    lng: s.lng ?? 0,
  );
}

List<GymSummary> _sortByDistance(
  List<GymSummary> gyms,
  double userLat,
  double userLng,
) {
  final copy = List<GymSummary>.from(gyms);
  copy.sort((a, b) {
    final da = _distance(a, userLat, userLng);
    final db = _distance(b, userLat, userLng);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  });
  return copy;
}

double? _distance(GymSummary g, double userLat, double userLng) {
  final lat = g.lat;
  final lng = g.lng;
  if (lat == null || lng == null) return null;
  if (lat == 0 && lng == 0) return null;
  return haversineKm(userLat, userLng, lat, lng);
}
