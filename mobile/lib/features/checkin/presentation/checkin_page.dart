import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/router/app_router.dart' show checkinBranchKey;

import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/gym_loader.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/presentation/home_shell.dart';
import '../../subscription/data/subscription_state.dart';
import 'checkin_controller.dart';

class CheckinPage extends ConsumerStatefulWidget {
  const CheckinPage({super.key});

  @override
  ConsumerState<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends ConsumerState<CheckinPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  /// True when our branch is the active one in the bottom-nav
  /// `IndexedStack`. Updated each build via `RouteAware` and via
  /// post-frame inspection of the shell's current index — used to
  /// gate `_controller.start()`/`stop()` so the camera only runs
  /// when this tab is actually visible. With the State alive across
  /// tab switches (StatefulShellRoute.indexedStack) this is what
  /// keeps battery + MLKit cost down: the State stays mounted, but
  /// the camera goes idle when the user is on Home / Explore /
  /// Profile.
  bool _branchVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _scan.dispose();
    super.dispose();
  }

  /// Apply the desired camera state given (a) app lifecycle state,
  /// (b) whether our branch is the visible tab, (c) whether a pending
  /// confirmation is on screen (camera widget swapped out for the
  /// validation card). Stop is idempotent on `mobile_scanner`, so
  /// calling it from multiple lifecycle paths is safe.
  void _syncCamera() {
    final pending =
        ref.read(checkinControllerProvider).pendingGym != null;
    final shouldRun = _branchVisible && !pending;
    if (shouldRun) {
      if (!_scan.isAnimating) _scan.repeat();
      _controller.start();
    } else {
      _scan.stop();
      _controller.stop();
    }
  }

  // App backgrounded → release the camera + ML pipeline so we don't
  // hold the device's only camera while invisible. Coming back to
  // foreground re-syncs based on the active tab.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncCamera();
    } else {
      _scan.stop();
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final state = ref.watch(checkinControllerProvider);
    final hasSubscription =
        ref.watch(subscriptionProvider.select((s) => s.hasSubscription));

    // Visibility within the bottom-nav IndexedStack + within our own
    // branch's navigator stack. Two ways the page can be invisible
    // even though State stays mounted:
    //   1. Another tab is selected → branch != currentIndex.
    //   2. The unsubscribed-scan flow pushed /gyms/<slug> on top of
    //      /checkin in the same branch → CheckinPage is in the route
    //      stack but not the topmost route, so not painted.
    // `ModalRoute.isCurrent` covers (2); the shell index check
    // covers (1).
    final shell = StatefulNavigationShell.maybeOf(context);
    final onActiveBranch = shell == null ||
        shell.currentIndex ==
            shell.route.branches.indexWhere(
              (b) => b.navigatorKey == checkinBranchKey,
            );
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    final visibleNow = onActiveBranch && isCurrentRoute;
    if (visibleNow != _branchVisible) {
      _branchVisible = visibleNow;
      // Defer the camera flip until after the build completes —
      // `MobileScannerController.start()` calls into platform code
      // and shouldn't run during widget build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncCamera();
      });
    }

    ref.listen(checkinControllerProvider, (prev, next) {
      // Pending confirmation toggles the camera widget out for a
      // confirmation card. Re-sync so the camera stops while the card
      // is visible and starts again on cancel.
      if (prev?.pendingGym != next.pendingGym) {
        _syncCamera();
      }
      if (next.result?.status == 'success') {
        context.go('/checkin/success');
      }
      // Unsubscribed member — or a subscriber whose tier doesn't cover the
      // scanned gym — lands on the gym's profile where the unlock/upgrade
      // CTA routes into /plans. `push` (not `go`) so the back button
      // returns to the scanner with the camera still alive.
      if (prev?.redirectGymSlug != next.redirectGymSlug &&
          next.redirectGymSlug != null) {
        ref.read(checkinControllerProvider.notifier).reset();
        // The push leaves CheckinPage's State alive but covered by
        // /gyms/<slug>; mark ourselves invisible and stop the camera
        // *before* the push so the platform view tears down its
        // capture session immediately rather than running invisibly
        // until a subsequent rebuild notices `isCurrent == false`.
        _branchVisible = false;
        _syncCamera();
        context.push('/gyms/${next.redirectGymSlug}');
      }
      // Pause-resume nudge previously fired here. Pause is now a planned
      // backend feature (follow-up); the controller no longer exposes a
      // pauseResumePending state, so a scan during a (server-side) pause
      // would just be rejected at scan time.
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              // Locale-natural order: BackBtn anchors visual-left in
              // EN and visual-right in AR; the centered "STEP 1 OF 2"
              // overline stays balanced because of the symmetric
              // Spacers + SizedBox padding.
              child: Row(
                children: [
                  const BackBtn(),
                  const Spacer(),
                  Overline(l.checkinStepLabel),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  DisplayText(l.checkinAlignTitle, size: 38),
                  const SizedBox(width: 10),
                  SerifAccent(l.checkinAlignAccent, size: 38),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: LayoutBuilder(
                builder: (_, box) {
                  final frameSize = box.maxWidth - 40;
                  return Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(GPRadius.xl2),
                      child: SizedBox(
                        width: frameSize,
                        height: frameSize,
                        child: state.pendingGym != null
                            ? _confirmFrame(l, gp, state.pendingGym!)
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  Container(color: gp.bg2),
                                  MobileScanner(
                                    controller: _controller,
                                    onDetect: (capture) {
                                      final raw = capture.barcodes
                                          .map((b) => b.rawValue)
                                          .firstWhere(
                                              (v) => v != null && v.isNotEmpty,
                                              orElse: () => null,);
                                      if (raw == null) return;
                                      ref
                                          .read(checkinControllerProvider.notifier)
                                          .onQrDetected(raw);
                                    },
                                  ),
                                  _cornerBrackets(),
                                  _scanLine(frameSize),
                                  // Swipe overlay. On Android, MobileScanner's
                                  // AndroidView consumes touches natively before
                                  // Flutter sees them — so a Listener wrapping
                                  // the frame never fires over the camera area.
                                  // Putting an opaque GestureDetector ABOVE the
                                  // scanner in the Stack means hit-testing finds
                                  // this Flutter widget first; it claims any
                                  // horizontal flick via the gesture arena (no
                                  // native competitor at this layer) and falls
                                  // through for vertical drags + taps so the
                                  // scanner still auto-focuses and pinch-zooms.
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onHorizontalDragEnd: (details) {
                                        HomeShell
                                            .handleHorizontalDragEndVelocity(
                                          context,
                                          ref,
                                          details.primaryVelocity ?? 0,
                                        );
                                      },
                                    ),
                                  ),
                                  if (state.processing) _processing(gp),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                state.pendingGym != null
                    ? l.checkinConfirmHintCaps
                    : l.checkinAlignHintCaps,
                style: GPText.mono(size: 11, letterSpacing: 1.8, color: gp.mutedSoft),
              ),
            ),
            const SizedBox(height: 18),
            if (state.errorCode != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _errorBanner(l, gp, state),
              ),
            if (!hasSubscription && state.pendingGym == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: _lockedPreviewBanner(l, gp),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: _bottomCta(l, state, hasSubscription),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cornerBrackets() {
    const s = 42.0;
    const t = 3.0;
    const c = GP.lime;
    Widget corner({
      required double? top,
      required double? left,
      required double? right,
      required double? bottom,
      required BorderRadiusGeometry radius,
      required BorderSide topSide,
      required BorderSide leftSide,
      required BorderSide rightSide,
      required BorderSide bottomSide,
    }) {
      return Positioned(
        top: top,
        left: left,
        right: right,
        bottom: bottom,
        child: Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border(
              top: topSide,
              left: leftSide,
              right: rightSide,
              bottom: bottomSide,
            ),
          ),
        ),
      );
    }

    const active = BorderSide(color: c, width: t);
    // BorderSide.none (BorderStyle.none) — a width:0 BorderStyle.solid side
    // is a "hairline" and Flutter rejects hairlines combined with a non-zero
    // BorderRadius, which the corner brackets all have.
    const none = BorderSide.none;
    return Stack(
      children: [
        corner(
          top: 14, left: 14, right: null, bottom: null,
          radius: const BorderRadius.only(topLeft: Radius.circular(14)),
          topSide: active, leftSide: active, rightSide: none, bottomSide: none,
        ),
        corner(
          top: 14, left: null, right: 14, bottom: null,
          radius: const BorderRadius.only(topRight: Radius.circular(14)),
          topSide: active, leftSide: none, rightSide: active, bottomSide: none,
        ),
        corner(
          top: null, left: 14, right: null, bottom: 14,
          radius: const BorderRadius.only(bottomLeft: Radius.circular(14)),
          topSide: none, leftSide: active, rightSide: none, bottomSide: active,
        ),
        corner(
          top: null, left: null, right: 14, bottom: 14,
          radius: const BorderRadius.only(bottomRight: Radius.circular(14)),
          topSide: none, leftSide: none, rightSide: active, bottomSide: active,
        ),
      ],
    );
  }

  Widget _scanLine(double frameSize) {
    return AnimatedBuilder(
      animation: _scan,
      builder: (_, __) {
        final t = _scan.value;
        final y = 24 + (frameSize - 48) * t;
        return Positioned(
          left: 24,
          right: 24,
          top: y,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  GP.lime.withValues(alpha: 0),
                  GP.lime,
                  GP.lime.withValues(alpha: 0),
                ],
              ),
              boxShadow: [BoxShadow(color: GP.lime.withValues(alpha: 0.5), blurRadius: 10)],
            ),
          ),
        );
      },
    );
  }

  Widget _processing(GpColors gp) {
    return Container(
      color: gp.bg.withValues(alpha: 0.8),
      alignment: Alignment.center,
      child: const GymLoader(size: GymLoaderSize.large),
    );
  }

  Widget _lockedPreviewBanner(AppLocalizations l, GpColors gp) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: gp.accentInk.withValues(alpha: 0.08),
        border: Border.all(color: gp.accentInk.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(GPRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: gp.accentInk, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.checkinLockedBannerTitle.toUpperCase(),
                  style: GPText.mono(
                    size: 10,
                    letterSpacing: 1.6,
                    color: gp.accentInk,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.checkinLockedBannerBody,
                  style: GPText.body(size: 12.5, color: gp.fg, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Confirmation card that replaces the live camera preview once a QR has
  // been decoded and tier-gated. The member sees exactly which gym they're
  // about to check into before a visit is burned — scanning a misaimed code
  // never auto-commits.
  Widget _confirmFrame(AppLocalizations l, GpColors gp, GPGym gym) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [gp.bg2, gp.bg],
            ),
          ),
        ),
        _cornerBrackets(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Overline(l.checkinConfirmEyebrow, bulletColor: GP.lime),
              const SizedBox(height: 24),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: GP.lime.withValues(alpha: 0.16),
                  border: Border.all(color: GP.lime.withValues(alpha: 0.6)),
                ),
                child: const Icon(Icons.qr_code_2, color: GP.lime, size: 30),
              ),
              const SizedBox(height: 22),
              Text(
                l.checkinConfirmPrompt.toUpperCase(),
                textAlign: TextAlign.center,
                style: GPText.mono(
                  size: 10,
                  letterSpacing: 1.8,
                  color: gp.muted,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                gym.name,
                textAlign: TextAlign.center,
                style: GPText.display(30, color: gp.fg, height: 1.0),
              ),
              const SizedBox(height: 8),
              Text(
                '${gym.area.toUpperCase()} · ${GPCategory.label(gym.category)}',
                style: GPText.mono(
                  size: 11,
                  letterSpacing: 1.6,
                  color: gym.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bottomCta(
    AppLocalizations l,
    CheckinUiState state,
    bool hasSubscription,
  ) {
    if (state.pendingGym != null) {
      return Column(
        children: [
          PillButton(
            label: l.checkinConfirmCta(state.pendingGym!.name),
            trailingIcon: Icons.check_rounded,
            onPressed: state.processing
                ? null
                : () => ref
                    .read(checkinControllerProvider.notifier)
                    .confirmCheckin(),
          ),
          const SizedBox(height: 10),
          PillButton(
            label: l.checkinCancelScan,
            variant: PillVariant.ghost,
            onPressed: state.processing
                ? null
                : () => ref
                    .read(checkinControllerProvider.notifier)
                    .cancelPending(),
          ),
        ],
      );
    }
    if (hasSubscription) {
      if (kDebugMode) {
        return _devTestingPanel();
      }
      return PillButton(
        label: l.checkinDemoButton,
        trailingIcon: Icons.flash_on,
        onPressed: () {
          ref.read(checkinControllerProvider.notifier).onQrDetected('iron-forge');
        },
      );
    }
    return PillButton(
      label: l.checkinSeePlansCta,
      trailingIcon: Icons.lock_outline,
      onPressed: () => context.push('/plans'),
    );
  }

  // Debug-only affordances. Visible only in `kDebugMode` so release builds
  // never ship these shortcuts. Lets testers:
  //   1) Simulate a scan against a representative gym for each tier, without
  //      printing a QR — exercises the tier-gate redirect (scanning above
  //      your tier) and the happy-path confirmation flow.
  //   2) Drain the term visit pool in one tap so the
  //      `CHECKIN_VISITS_EXHAUSTED` banner + early-renewal dialog can be
  //      reached without actually burning 30+ visits.
  Widget _devTestingPanel() {
    final gp = context.gp;
    final tierSlugs = <({String tier, String slug, Color color})>[
      (tier: 'Silver', slug: 'iron-forge', color: GPTier.silver.color),
      (tier: 'Gold', slug: 'apex-crossfit', color: GPTier.gold.color),
      (tier: 'platinum', slug: 'fortis-boxing', color: GPTier.platinum.color),
      (tier: 'Diamond', slug: 'core-athletic', color: GPTier.diamond.color),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: gp.bg2,
        border: Border.all(color: GP.lime.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(GPRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report_outlined, color: GP.lime, size: 14),
              const SizedBox(width: 6),
              Text(
                'DEV · TESTING ONLY',
                style: GPText.mono(
                  size: 10,
                  letterSpacing: 1.6,
                  color: GP.lime,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in tierSlugs)
                _DevChip(
                  label: 'Scan ${t.tier}',
                  color: t.color,
                  onTap: () => ref
                      .read(checkinControllerProvider.notifier)
                      .onQrDetected(t.slug),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _DevChip(
            label: 'Complete all visits (max out term pool)',
            color: GP.danger,
            fullWidth: true,
            onTap: () async {
              await ref
                  .read(subscriptionProvider.notifier)
                  .devMaxOutVisits();
              if (!mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Term visits maxed out'),
                    duration: Duration(seconds: 2),
                  ),
                );
            },
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(AppLocalizations l, GpColors gp, CheckinUiState state) {
    final isExhausted = state.errorCode == 'CHECKIN_VISITS_EXHAUSTED';
    final message = isExhausted
        ? l.checkinVisitsExhaustedBody
        : (state.errorMessage ?? l.checkinFailedGeneric);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GP.danger.withValues(alpha: 0.12),
        border: Border.all(color: GP.danger.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(GPRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: GP.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GPText.body(size: 13, color: gp.fg),
            ),
          ),
          TextButton(
            onPressed: isExhausted
                ? () => _confirmRenewNow(l)
                : () => ref.read(checkinControllerProvider.notifier).reset(),
            child: Text(
              (isExhausted ? l.subscriptionRenewNowCta : l.retry).toUpperCase(),
              style: GPText.mono(
                size: 10,
                letterSpacing: 1.4,
                color: gp.fg,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // The pause-resume dialog has been removed — pause is a planned
  // backend feature, not yet supported. Once it lands the controller
  // will surface a `pauseResumePending` state again and this dialog
  // can be reinstated.

  Future<void> _confirmRenewNow(AppLocalizations l) async {
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
    if (!mounted || confirmed != true) return;
    await ref.read(subscriptionProvider.notifier).renewNow();
    if (!mounted) return;
    ref.read(checkinControllerProvider.notifier).reset();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.subscriptionRenewedSnack)));
  }
}

class _DevChip extends StatelessWidget {
  const _DevChip({
    required this.label,
    required this.color,
    required this.onTap,
    this.fullWidth = false,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final chip = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(GPRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(GPRadius.sm),
        ),
        child: Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: GPText.mono(
            size: 10,
            letterSpacing: 1.4,
            color: gp.fg,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
    if (fullWidth) {
      return SizedBox(width: double.infinity, child: chip);
    }
    return chip;
  }
}
