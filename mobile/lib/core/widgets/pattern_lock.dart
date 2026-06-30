import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/gp_tokens.dart';

const _kMinNodes = 4;
const _kGridSize = 3;

/// A 3×3 unlock-pattern grid.
///
/// Calls [onPatternComplete] when the user lifts their finger with at least
/// 4 nodes connected. The pattern is a row-major list of node indices:
///   0 1 2
///   3 4 5
///   6 7 8
///
/// The widget renders itself into whatever space the parent gives it; callers
/// typically wrap it in a fixed-size SizedBox to ensure a square aspect ratio.
class PatternLock extends StatefulWidget {
  const PatternLock({
    super.key,
    required this.onPatternComplete,
    this.error = false,
    this.locked = false,
  });

  /// Called when the user lifts their finger after connecting ≥ 4 nodes.
  final ValueChanged<List<int>> onPatternComplete;

  /// When true, draws the active pattern in [GP.danger] red — use after a
  /// wrong-pattern attempt to give immediate visual feedback.
  final bool error;

  /// Disables gesture input when true — set while a network call is in flight
  /// so the user can't submit twice.
  final bool locked;

  @override
  State<PatternLock> createState() => PatternLockState();
}

class PatternLockState extends State<PatternLock> {
  final List<int> _path = [];
  Offset? _finger;
  List<Offset> _centers = [];

  /// Immediately clears the drawn path. Call from outside (e.g. the parent
  /// sheet) if you want to reset the grid without waiting for the post-lift
  /// auto-clear.
  void reset() {
    if (mounted) setState(() { _path.clear(); _finger = null; });
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final activeColor = widget.error ? GP.danger : gp.accentInk;
    return LayoutBuilder(
      builder: (ctx, constraints) {
        _computeCenters(constraints.biggest);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: widget.locked ? null : _onPanStart,
          onPanUpdate: widget.locked ? null : _onPanUpdate,
          onPanEnd: widget.locked ? null : _onPanEnd,
          child: CustomPaint(
            size: constraints.biggest,
            painter: _PatternPainter(
              path: List.unmodifiable(_path),
              centers: _centers,
              finger: _finger,
              activeColor: activeColor,
              inactiveNodeFill: gp.bg3,
              inactiveNodeBorder: gp.line2,
            ),
          ),
        );
      },
    );
  }

  void _computeCenters(Size size) {
    _centers = [];
    final cw = size.width / _kGridSize;
    final ch = size.height / _kGridSize;
    for (int r = 0; r < _kGridSize; r++) {
      for (int c = 0; c < _kGridSize; c++) {
        _centers.add(Offset(cw * (c + 0.5), ch * (r + 0.5)));
      }
    }
  }

  int? _hitTest(Offset pos) {
    const hitRadius = 28.0;
    for (int i = 0; i < _centers.length; i++) {
      if (!_path.contains(i) && (_centers[i] - pos).distance < hitRadius) {
        return i;
      }
    }
    return null;
  }

  void _onPanStart(DragStartDetails d) {
    setState(() { _path.clear(); _finger = d.localPosition; });
    final hit = _hitTest(d.localPosition);
    if (hit != null) {
      HapticFeedback.selectionClick();
      setState(() => _path.add(hit));
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() => _finger = d.localPosition);
    final hit = _hitTest(d.localPosition);
    if (hit != null) {
      HapticFeedback.selectionClick();
      setState(() => _path.add(hit));
    }
  }

  void _onPanEnd(DragEndDetails _) {
    setState(() => _finger = null);
    if (_path.length >= _kMinNodes) {
      widget.onPatternComplete(List.from(_path));
    }
    // Brief visual hold so the user can see the completed path, then clear.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _path.clear());
    });
  }
}

class _PatternPainter extends CustomPainter {
  const _PatternPainter({
    required this.path,
    required this.centers,
    required this.finger,
    required this.activeColor,
    required this.inactiveNodeFill,
    required this.inactiveNodeBorder,
  });

  final List<int> path;
  final List<Offset> centers;
  final Offset? finger;
  final Color activeColor;
  final Color inactiveNodeFill;
  final Color inactiveNodeBorder;

  @override
  void paint(Canvas canvas, Size size) {
    if (centers.isEmpty) return;

    // Inactive dots
    final fillPaint = Paint()
      ..color = inactiveNodeFill
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = inactiveNodeBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final centerDotPaint = Paint()
      ..color = inactiveNodeBorder
      ..style = PaintingStyle.fill;
    for (int i = 0; i < centers.length; i++) {
      if (path.contains(i)) continue;
      canvas.drawCircle(centers[i], 12, fillPaint);
      canvas.drawCircle(centers[i], 12, borderPaint);
      canvas.drawCircle(centers[i], 3, centerDotPaint);
    }

    // Lines between connected nodes
    if (path.length >= 2) {
      final linePaint = Paint()
        ..color = activeColor.withValues(alpha: 0.55)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < path.length - 1; i++) {
        canvas.drawLine(centers[path[i]], centers[path[i + 1]], linePaint);
      }
    }

    // Trailing line from last node to finger position
    if (path.isNotEmpty && finger != null) {
      final trailPaint = Paint()
        ..color = activeColor.withValues(alpha: 0.4)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(centers[path.last], finger!, trailPaint);
    }

    // Active dots (rendered on top of lines)
    final activeFillPaint = Paint()
      ..color = activeColor.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    final activeCenterPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;
    for (final i in path) {
      canvas.drawCircle(centers[i], 16, activeFillPaint);
      canvas.drawCircle(centers[i], 7, activeCenterPaint);
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.path != path ||
      old.finger != finger ||
      old.activeColor != activeColor;
}
