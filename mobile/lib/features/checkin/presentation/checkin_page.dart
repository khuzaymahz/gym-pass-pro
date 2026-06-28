import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

import '../../../core/router/app_router.dart' show checkinBranchKey;

import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/gym_loader.dart';
import '../../../core/widgets/help_button.dart';
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

  /// Last camera-start error. Surfaced via the inline error card below
  /// the camera frame so a black preview is never silent — the member
  /// always sees the reason ("permission denied" / generic) and a
  /// retry CTA. `null` means the camera is either running or hasn't
  /// been started yet.
  MobileScannerException? _cameraError;

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
  ///
  /// **Defaults to false.** The shell mounts ALL four branches at
  /// app boot — including this one — so without a false default
  /// the `MobileScanner` widget would render in the tree from
  /// frame zero, the controller would attach to its preview
  /// surface, the Camera2 lifecycle + MLKit barcode dynamite
  /// module + TFLite XNNPACK delegate would all initialise on a
  /// member who hasn't even tapped SCAN yet. False at boot, flipped
  /// true the first time the build computes the shell's current
  /// branch and finds we're it.
  bool _branchVisible = false;

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
  ///
  /// `start()` returns a `Future` that completes with the resolved
  /// camera state — or rejects with `MobileScannerException` if the
  /// permission was denied, the camera is in use by another app, etc.
  /// Previously the future was fire-and-forgotten, so a denied
  /// permission produced a black preview with zero feedback. Now we
  /// `await` it, surface the error into `_cameraError`, and the
  /// build path swaps the camera tile out for an inline error card
  /// with Retry / Open settings.
  Future<void> _syncCamera() async {
    final pending =
        ref.read(checkinControllerProvider).pendingGym != null;
    final shouldRun = _branchVisible && !pending;
    if (shouldRun) {
      if (!_scan.isAnimating) _scan.repeat();
      try {
        await _controller.start();
        if (!mounted) return;
        if (_cameraError != null) {
          setState(() => _cameraError = null);
        }
      } on MobileScannerException catch (err) {
        if (!mounted) return;
        setState(() => _cameraError = err);
        _scan.stop();
      }
    } else {
      _scan.stop();
      await _controller.stop();
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

    final returnRoute = ref.watch(checkinReturnRouteProvider);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              // Back button only appears when the user arrived here from
              // a specific screen (gym profile, day-pass checkout, etc.),
              // not when they tapped the scan tab directly. The SizedBox
              // preserves the header layout width in both cases.
              child: Row(
                children: [
                  if (returnRoute != null)
                    BackBtn(
                      onPressed: () {
                        ref
                            .read(checkinReturnRouteProvider.notifier)
                            .state = null;
                        context.go(returnRoute);
                      },
                    )
                  else
                    const SizedBox(width: 40),
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
                                  // `MobileScanner` only enters the tree
                                  // when our branch is actually visible.
                                  // The shell's IndexedStack mounts every
                                  // branch at boot, so without this gate
                                  // the camera + Camera2 surface + MLKit
                                  // barcode dynamite + TFLite XNNPACK
                                  // delegate would all initialise on a
                                  // member who hasn't tapped SCAN yet —
                                  // visible in the device logs as a flood
                                  // of camera/tflite/MLKit init lines at
                                  // app launch. Replacing it with a
                                  // matching `gp.bg2` placeholder when
                                  // hidden keeps the layout slot identical
                                  // (no shift when the user lands on the
                                  // tab) while letting the native handler
                                  // stay torn down.
                                  if (_branchVisible && _cameraError == null)
                                    MobileScanner(
                                      controller: _controller,
                                      // Without an errorBuilder, a
                                      // permission denial / camera-busy
                                      // failure produces a silent black
                                      // surface. We capture the error
                                      // into `_cameraError` so the
                                      // next build swaps the scanner
                                      // tile out for the error card,
                                      // and we render a plain
                                      // placeholder in the meantime
                                      // so there is never a black hole.
                                      errorBuilder:
                                          (context, error, _) {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          if (!mounted) return;
                                          if (_cameraError == error) {
                                            return;
                                          }
                                          setState(
                                            () => _cameraError = error,
                                          );
                                          _scan.stop();
                                        });
                                        return Container(color: gp.bg2);
                                      },
                                      onDetect: (capture) {
                                        final raw = capture.barcodes
                                            .map((b) => b.rawValue)
                                            .firstWhere(
                                                (v) =>
                                                    v != null && v.isNotEmpty,
                                                orElse: () => null,);
                                        if (raw == null) return;
                                        ref
                                            .read(checkinControllerProvider
                                                .notifier,)
                                            .onQrDetected(raw);
                                      },
                                    )
                                  else
                                    Container(color: gp.bg2),
                                  if (_cameraError != null)
                                    _cameraErrorOverlay(l, gp),
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
            Positioned(
              bottom: 24,
              left: 20,
              child: HelpButton(tips: [
                HelpTip(icon: Icons.qr_code_2, text: l.helpScan1),
                HelpTip(
                  icon: Icons.center_focus_strong_outlined,
                  text: l.helpScan2,
                ),
                HelpTip(
                  icon: Icons.check_circle_outline,
                  text: l.helpScan3,
                ),
              ],),
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

  /// Overlay shown inside the scanner frame when `MobileScanner` fails
  /// to start (permission denied, camera in use, missing hardware).
  /// Surfaces a Retry that re-attempts `_controller.start()` and an
  /// Open-Settings deep link for the permission-denied case so the
  /// member can grant camera access without leaving the app.
  Widget _cameraErrorOverlay(AppLocalizations l, GpColors gp) {
    final isPermission =
        _cameraError?.errorCode == MobileScannerErrorCode.permissionDenied;
    final title = isPermission
        ? l.checkinCameraPermissionTitle
        : l.checkinCameraGenericError;
    final body = isPermission ? l.checkinCameraPermissionBody : '';
    return Positioned.fill(
      child: Container(
        color: gp.bg2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPermission
                  ? Icons.no_photography_outlined
                  : Icons.videocam_off_outlined,
              color: gp.mutedSoft,
              size: 36,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GPText.body(size: 14, color: gp.fg, height: 1.35),
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: GPText.body(
                    size: 12.5, color: gp.mutedSoft, height: 1.4,),
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                PillButton(
                  label: l.checkinCameraRetry,
                  variant: PillVariant.ghost,
                  onPressed: () async {
                    setState(() => _cameraError = null);
                    if (!_scan.isAnimating) _scan.repeat();
                    await _syncCamera();
                  },
                ),
                if (isPermission)
                  PillButton(
                    label: l.checkinCameraOpenSettings,
                    onPressed: _openAppSettings,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAppSettings() async {
    // iOS exposes the per-app settings page via the `app-settings:`
    // URL scheme; Android has no equivalent URL scheme, so we fall
    // back to the system Settings app and the user navigates to
    // Apps → GymPass → Permissions. A future iteration can swap in
    // `permission_handler.openAppSettings()` for a one-tap path on
    // Android.
    final Uri uri = Platform.isIOS
        ? Uri.parse('app-settings:')
        : Uri.parse('package:net.gympass.gympass');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // best-effort: nothing to fall back to
    }
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
      return const SizedBox.shrink();
    }
    return PillButton(
      label: l.checkinSeePlansCta,
      trailingIcon: Icons.lock_outline,
      onPressed: () => context.push('/plans'),
    );
  }

  Widget _errorBanner(AppLocalizations l, GpColors gp, CheckinUiState state) {
    final isExhausted = state.errorCode == 'CHECKIN_VISITS_EXHAUSTED';
    final isRecentScan = state.errorCode == 'CHECKIN_ALREADY_SCANNED';

    // Warn (amber) for soft limits, danger (red) for hard errors.
    final accentColor = isRecentScan ? GP.warn : GP.danger;
    final icon = isRecentScan
        ? Icons.schedule_outlined
        : isExhausted
            ? Icons.bar_chart_outlined
            : Icons.error_outline;
    final title = isRecentScan
        ? l.checkinErrorTitleAlreadyScanned
        : isExhausted
            ? l.checkinErrorTitleVisitsExhausted
            : l.checkinErrorTitleGeneric;
    final message = isExhausted
        ? l.checkinVisitsExhaustedBody
        : isRecentScan
            ? l.checkinAlreadyScannedBody
            : (state.errorMessage ?? l.checkinFailedGeneric);

    void dismiss() =>
        ref.read(checkinControllerProvider.notifier).reset();

    // Shown behind the card while the user swipes in either direction.
    final swipeBg = Container(
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(GPRadius.md),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.close_rounded, color: accentColor, size: 22),
    );

    return Dismissible(
      key: ValueKey(state.errorCode),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => dismiss(),
      background: swipeBg,
      secondaryBackground: swipeBg,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(GPRadius.md),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar — avoids the non-uniform Border +
              // borderRadius conflict in BoxDecoration.
              Container(width: 3, color: accentColor),
              Expanded(
                child: Container(
                  color: accentColor.withValues(alpha: 0.08),
                  padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(icon, color: accentColor, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GPText.mono(
                                size: 10,
                                letterSpacing: 1.5,
                                color: accentColor,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message,
                              style: GPText.body(
                                size: 13,
                                color: gp.fg,
                                height: 1.4,
                              ),
                            ),
                            if (isExhausted) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => _confirmRenewNow(l),
                                child: Text(
                                  l.subscriptionRenewNowCta.toUpperCase(),
                                  style: GPText.mono(
                                    size: 10,
                                    letterSpacing: 1.4,
                                    color: gp.fg,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Tap-to-dismiss — explicit affordance alongside swipe.
                      GestureDetector(
                        onTap: dismiss,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6, top: 1),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: gp.mutedSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
