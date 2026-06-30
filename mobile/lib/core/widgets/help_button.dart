import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/gp_text.dart';
import '../theme/gp_tokens.dart';
import '../../l10n/app_localizations.dart';

// ─── Shared provider ──────────────────────────────────────────────────────────

@immutable
class HelpPillState {
  const HelpPillState({this.onRight = true, this.y});
  final bool onRight;
  final double? y; // pill top in logical px; null = centred
  HelpPillState copyWith({bool? onRight, double? y}) =>
      HelpPillState(onRight: onRight ?? this.onRight, y: y ?? this.y);
}

final helpPillProvider =
    StateProvider<HelpPillState>((ref) => const HelpPillState());

// ─── Constants ────────────────────────────────────────────────────────────────

const _kTabBarH = 78.0;
const _kPillW = 26.0;
const _kPillH = 48.0;
const _kMargin = 8.0;
const _kDragThreshold = 6.0;
const _kSideFlipFraction = 0.30;

// Spring physics tuning.
// Higher stiffness = less sticky lag; higher damping = faster settle.
const _kSpringStiffness = 210.0;
const _kSpringDamping = 19.0;

// ─── DraggableHelpButton ──────────────────────────────────────────────────────

/// Side-docked pill with spring-physics drag and squash-and-stretch.
///
/// **Feel:**
/// - Drag starts sticky — pill has inertia and lags behind the finger.
/// - Fast movement stretches the pill in the direction of travel and
///   squashes it perpendicular (classic squash-and-stretch).
/// - On release the spring overshoots slightly and settles with a soft bounce.
/// - Dragging ≥ 30 % of screen width across flips the pill to the other edge
///   with an elastic spring animation.
///
/// Position is shared via [helpPillProvider] across all screens.
class DraggableHelpButton extends ConsumerStatefulWidget {
  const DraggableHelpButton({super.key, required this.tips});
  final List<HelpTip> tips;

  @override
  ConsumerState<DraggableHelpButton> createState() =>
      _DraggableHelpButtonState();
}

class _DraggableHelpButtonState extends ConsumerState<DraggableHelpButton>
    with TickerProviderStateMixin {
  // ── 2-D spring state ────────────────────────────────────────────────────────
  double _displayY = 0, _targetY = 0, _springVelY = 0;
  double _displayX = 0, _targetX = 0, _springVelX = 0;
  late final Ticker _springTicker;
  bool _springing = false;

  // ── Drag state ──────────────────────────────────────────────────────────────
  bool _dragging = false;
  Offset _dragStartGlobal = Offset.zero;
  Offset _lastGlobal = Offset.zero;
  double _dragStartY = 0;
  double _dragStartX = 0;

  // ── Lift scale animation ─────────────────────────────────────────────────
  late final AnimationController _liftCtrl;
  late final Animation<double> _liftAnim;

  @override
  void initState() {
    super.initState();
    _springTicker = createTicker(_onSpringTick);
    _liftCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _liftAnim = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _liftCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _springTicker.dispose();
    _liftCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  double _defaultY(Size size, EdgeInsets vp) => vp.top + 90.0;

  double _clampY(double y, Size size, EdgeInsets vp) => y.clamp(
        vp.top + _kMargin,
        size.height - vp.bottom - _kTabBarH - _kPillH - _kMargin,
      );

  // Returns the resting X for the pill on the given side, shifted inward by
  // the system gesture inset so the pill never sits inside Android's back-
  // gesture zone (≈16-20 dp from each edge in gesture-navigation mode).
  double _edgeX(bool onRight, MediaQueryData mq) {
    final rawInset = onRight
        ? mq.systemGestureInsets.right
        : mq.systemGestureInsets.left;
    final inset = rawInset.clamp(0.0, 4.0);
    return onRight ? mq.size.width - _kPillW - inset : inset;
  }

  void _setTargets({double? x, double? y}) {
    if (x != null) _targetX = x;
    if (y != null) _targetY = y;
    if (!_springing) {
      _springing = true;
      _springTicker.start();
    }
  }

  // ── 2-D spring ticker ─────────────────────────────────────────────────────

  void _onSpringTick(Duration _) {
    const dt = 1 / 60.0;

    // Y axis
    _springVelY += _kSpringStiffness * (_targetY - _displayY) * dt;
    _springVelY *= (1 - _kSpringDamping * dt).clamp(0.0, 1.0);
    _displayY += _springVelY * dt;

    // X axis
    _springVelX += _kSpringStiffness * (_targetX - _displayX) * dt;
    _springVelX *= (1 - _kSpringDamping * dt).clamp(0.0, 1.0);
    _displayX += _springVelX * dt;

    final yOk = (_targetY - _displayY).abs() < 0.25 && _springVelY.abs() < 0.4;
    final xOk = (_targetX - _displayX).abs() < 0.25 && _springVelX.abs() < 0.4;
    if (yOk && xOk) {
      _displayY = _targetY;
      _displayX = _targetX;
      _springVelY = _springVelX = 0;
      _springTicker.stop();
      _springing = false;
    }

    if (mounted) setState(() {});
  }

  // ── Gesture handlers ─────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails d) {
    _dragging = false;
    _dragStartGlobal = d.globalPosition;
    _lastGlobal = d.globalPosition;

    final mq = MediaQuery.of(context);
    final pos = ref.read(helpPillProvider);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final effectiveOnRight = pos.y == null ? !isRtl : pos.onRight;

    // Sync X spring to the current edge so drag starts seamlessly.
    final edgeX = _edgeX(effectiveOnRight, mq);
    _dragStartX = edgeX;
    _displayX = edgeX;
    _targetX = edgeX;
    _springVelX = 0;

    final savedY = pos.y ?? _defaultY(mq.size, mq.viewPadding);
    _dragStartY = savedY;
    _displayY = savedY;
    _targetY = savedY;
    _springVelY = 0;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    _lastGlobal = d.globalPosition;
    final delta = d.globalPosition - _dragStartGlobal;

    if (!_dragging && delta.distance > _kDragThreshold) {
      _dragging = true;
      HapticFeedback.selectionClick();
      _liftCtrl.forward();
    }
    if (!_dragging) return;

    final mq = MediaQuery.of(context);

    // Y: spring follows finger vertically.
    final newY = _clampY(_dragStartY + delta.dy, mq.size, mq.viewPadding);

    // X: spring follows finger horizontally across the full screen width.
    final newX = (_dragStartX + delta.dx).clamp(0.0, mq.size.width - _kPillW);

    _setTargets(x: newX, y: newY);
  }

  void _onPanEnd(DragEndDetails details) {
    final wasDragging = _dragging;
    _dragging = false;
    _liftCtrl.reverse();

    if (!wasDragging) return;

    final mq = MediaQuery.of(context);
    final current = ref.read(helpPillProvider);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final effectiveOnRight = current.y == null ? !isRtl : current.onRight;

    // Determine new side from how far the pill was dragged horizontally.
    final totalDx = _lastGlobal.dx - _dragStartGlobal.dx;
    bool newOnRight = effectiveOnRight;

    if (effectiveOnRight && totalDx < -mq.size.width * _kSideFlipFraction) {
      newOnRight = false;
      HapticFeedback.mediumImpact();
    } else if (!effectiveOnRight &&
        totalDx > mq.size.width * _kSideFlipFraction) {
      newOnRight = true;
      HapticFeedback.mediumImpact();
    }

    // Spring-snap X to the target edge — organic elastic rebound.
    final edgeX = _edgeX(newOnRight, mq);
    _setTargets(x: edgeX);

    // Persist side + final Y.
    ref.read(helpPillProvider.notifier).state =
        HelpPillState(onRight: newOnRight, y: _targetY);
  }

  void _showSheet(BuildContext ctx, GpColors gp) {
    final l = AppLocalizations.of(ctx);
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _HelpSheet(tips: widget.tips, l: l, gp: gp),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final mq = MediaQuery.of(context);
    final pos = ref.watch(helpPillProvider);

    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final effectiveOnRight = pos.y == null ? !isRtl : pos.onRight;

    final pillY = (_dragging || _springing)
        ? _displayY
        : _clampY(
            pos.y ?? _defaultY(mq.size, mq.viewPadding),
            mq.size,
            mq.viewPadding,
          );
    final pillX = (_dragging || _springing)
        ? _displayX
        : _edgeX(effectiveOnRight, mq);

    final speedY = _springVelY.abs();
    final speedX = _springVelX.abs();
    final scaleY = (1.0 + (speedY / 320).clamp(0.0, 0.32)) *
        (1.0 - (speedX / 480).clamp(0.0, 0.22));
    final scaleX = (1.0 + (speedX / 320).clamp(0.0, 0.32)) *
        (1.0 - (speedY / 480).clamp(0.0, 0.22));

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            left: pillX,
            top: pillY,
            child: AnimatedBuilder(
              animation: _liftAnim,
              builder: (_, child) => Transform(
                transform: Matrix4.diagonal3Values(_liftAnim.value, _liftAnim.value, 1.0),
                alignment: effectiveOnRight
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Transform(
                  transform: Matrix4.diagonal3Values(scaleX, scaleY, 1.0),
                  alignment: Alignment.center,
                  child: child!,
                ),
              ),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showSheet(context, context.gp);
                },
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Container(
                  width: _kPillW,
                  height: _kPillH,
                  decoration: BoxDecoration(
                    color: gp.bg2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: gp.line2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: Offset(effectiveOnRight ? -3 : 3, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '?',
                      style: GPText.mono(
                        size: 12,
                        color: gp.accentInk,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── HelpButton (non-draggable) ───────────────────────────────────────────────

class HelpButton extends StatelessWidget {
  const HelpButton({super.key, required this.tips});
  final List<HelpTip> tips;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showSheet(context, gp);
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: gp.bg2,
          shape: BoxShape.circle,
          border: Border.all(color: gp.line2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '?',
            style: GPText.mono(
              size: 14,
              color: gp.accentInk,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  void _showSheet(BuildContext context, GpColors gp) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _HelpSheet(tips: tips, l: l, gp: gp),
    );
  }
}

// ─── HelpTip ──────────────────────────────────────────────────────────────────

class HelpTip {
  const HelpTip({required this.icon, required this.text});
  final IconData icon;
  final String text;
}

// ─── _HelpSheet ───────────────────────────────────────────────────────────────

class _HelpSheet extends StatelessWidget {
  const _HelpSheet({required this.tips, required this.l, required this.gp});
  final List<HelpTip> tips;
  final AppLocalizations l;
  final GpColors gp;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        12, 0, 12, 12 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.xl2),
        border: Border.all(color: gp.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: gp.line2,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  l.helpSheetTitle.toUpperCase(),
                  style: GPText.mono(
                    size: 11,
                    letterSpacing: 1.8,
                    color: gp.accentInk,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.42,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: tips
                    .map(
                      (tip) => Padding(
                        padding:
                            const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: gp.accentInk
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                tip.icon,
                                size: 16,
                                color: gp.accentInk,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  tip.text,
                                  style: GPText.body(
                                    size: 13,
                                    color: gp.mutedSoft,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: gp.accentInk.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(GPRadius.xl),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  l.helpDismiss,
                  style: GPText.mono(
                    size: 12,
                    letterSpacing: 1.4,
                    color: gp.accentInk,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
