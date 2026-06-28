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
import '../../../core/di/providers.dart';
import '../../gyms/data/gym_repository.dart';
import '../../gyms/data/gym_summary.dart';
import '../../gyms/data/home_region_store.dart';
import '../../gyms/data/location_service.dart';
import '../../gyms/data/media_url.dart';
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
  /// Tracks whether we've already kicked off a one-shot location
  /// fetch since the page mounted. Without this, every rebuild
  /// would re-fire the GPS read (and the OS permission prompt that
  /// goes with it). Set true the moment we fire — even if the
  /// fetch fails, we don't retry from here; Explore's locate-me
  /// button is the manual recovery path.
  bool _locationBootstrapped = false;

  @override
  void initState() {
    super.initState();
    // Defer the GPS read until after the first frame paints so the
    // home shell isn't blocked on the OS permission prompt cold-
    // starting. The result lands in `userPositionProvider`; GymRow
    // + the Near You sort below pick it up reactively.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureUserLocation();
    });
  }

  /// Hydrates `userPositionProvider` from the persisted region store
  /// (instant — used as the first-paint distance baseline), then
  /// fires a live GPS read in the background to refine it. Same
  /// pattern Explore's `_locateUser` uses, hoisted here so the
  /// Home tab works as the entry point too: a member who lands on
  /// Home and never opens Explore still gets real distances on the
  /// Near You list and on every gym row across the app.
  Future<void> _ensureUserLocation() async {
    if (_locationBootstrapped) return;
    _locationBootstrapped = true;

    // Already hydrated by another surface (e.g. user opened Explore
    // first). Nothing to do.
    if (ref.read(userPositionProvider) != null) return;

    final regionStore = ref.read(homeRegionStoreProvider);
    final stored = await regionStore.read();
    if (!mounted) return;
    if (stored != null && ref.read(userPositionProvider) == null) {
      // Use the last-known fix immediately so distances render on
      // the first paint instead of staying blank for the live-GPS
      // round trip. Live GPS below will overwrite this with a fresh
      // reading.
      ref.read(userPositionProvider.notifier).state = stored;
    }

    final result = await ref.read(locationServiceProvider).currentPosition();
    if (!mounted || !result.hasPosition) return;
    final pos = result.position!;
    final fresh = HomeLocation(lat: pos.latitude, lng: pos.longitude);
    ref.read(userPositionProvider.notifier).state = fresh;
    // Persist for the next cold start; also feeds Explore's
    // initial-region framing the next time the user opens it.
    await regionStore.write(pos.latitude, pos.longitude);
  }

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
    // The gymsListStateProvider notifier owns its own cache + fetch
    // lifecycle; calling refresh() here re-fires the backend call,
    // overwriting the cache on success and switching the source to
    // `cached` (preserving the existing items) on failure. We await
    // it so the pull-to-refresh indicator stops at the right moment.
    // `throwOnError: true` lets the WordmarkRefresh wrapper see a
    // failure and pop the "check your connection" snackbar.
    // Subscription / profile keep their cached snapshots regardless;
    // the gym list manages its own freshness signal via `source`.
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
    // Near You comes from `gymsListProvider` (backend `/api/v1/gyms`).
    // No seed fallback — backend is the single source of truth, and a
    // truly empty list renders the empty-state card rather than a
    // fake "here are some gyms" sample. The provider's `valueOrNull`
    // is non-null after the first hydrate; before that we render
    // skeletons.
    final gymsAsync = ref.watch(gymsListProvider);
    final allGyms = gymsAsync.valueOrNull ?? const <GymSummary>[];
    final isLoadingGyms = gymsAsync.isLoading && allGyms.isEmpty;
    // Near You is **distance-sorted** when the user's position is
    // available — backend returns gyms in unspecified order and
    // simply taking the first three was lying ("near you" with no
    // distance signal). Once `userPositionProvider` hydrates (see
    // `_ensureUserLocation` in initState) the list re-sorts by
    // great-circle distance ascending. Gyms without coordinates
    // sink to the end. When position is null (cold start before
    // GPS resolves, or permission denied) we keep backend order —
    // honest "we don't know yet" instead of a fake sort.
    final userPos = ref.watch(userPositionProvider);
    final nearYou = userPos == null
        ? allGyms
        : _sortByDistance(allGyms, userPos.lat, userPos.lng);
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
                    // Empty-state copy distinguishes:
                    //   - We've never had a successful fetch on this
                    //     device AND we're offline → "you're offline,
                    //     connect and pull to refresh"
                    //   - Backend genuinely returned zero rows →
                    //     "no partner gyms in the network yet"
                    // The freshness signal lives on
                    // `gymsListStateProvider.source`. Without this
                    // distinction the user sees the same "no gyms"
                    // copy whether the network is unreachable or
                    // the backend is empty — which reads as a bug
                    // either way.
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
                  // Distance-sorted ascending when GPS is available;
                  // raw backend order otherwise. See the `nearYou`
                  // assignment above for the rationale.
                  final firstThree = nearYou.take(3).toList();
                  // Backend stores `/media/...` as a relative path, so the
                  // app has to prefix the API base URL before handing the
                  // string to CachedNetworkImage. Without this the logo
                  // requests resolve against the device's filesystem and
                  // silently fail.
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
    // `total <= 0` covers two distinct cases:
    //   - 0  → cycle hasn't materialised yet (subscription mid-hydrate).
    //   - -1 → unlimited tier (Diamond) — no cap to clamp against.
    // The previous `total == 0` only handled the first case, so a Diamond
    // member tapping into Home hit `used.clamp(0, -1)` and crashed
    // ("Invalid argument(s): 0", because `lo > hi`).
    // Defend against the brief window before the subscription has
    // hydrated from the backend, where `total == 0` and clamp
    // would do the wrong thing. Every tier shares the same monthly
    // cap (tier gates the gym network, not the visit count) so we
    // don't need a separate "unlimited" path.
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
              ),
              // Multi-month plans need a "where am I in the term" hint —
              // the cycle counter alone can't tell a 3-month silver
              // member that they're on month 1 of 3 with 90 total
              // visits in the bank. For 1-month plans this row would
              // just say "MONTH 1 OF 1" so we skip it.
              if ((sub.durationMonths ?? 1) > 1) ...[
                const SizedBox(height: 6),
                _TermProgressLine(sub: sub),
              ],
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
GPGym _gymSummaryToGPGym(GymSummary s) {
  return gymSummaryToGPGym(s);
}

/// Sort `gyms` ascending by great-circle distance from
/// (`userLat`, `userLng`). Rows missing coords sink to the end (the
/// distance helper returns null for `lat == 0 && lng == 0` — we
/// treat null as "infinitely far" rather than "right at the user").
/// Pure function; the caller decides whether to take(N) afterwards.
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

/// Public version of the adapter so favourites / explore / any other
/// surface that renders backend gyms through the existing `GymRow`
/// widget can reuse the same field mapping. Kept in this file because
/// home was the first consumer; importing from here is fine since the
/// file is already on the hot path.
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
