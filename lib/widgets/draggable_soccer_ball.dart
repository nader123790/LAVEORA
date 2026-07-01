import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Interactive football users can drag with mouse or touch.
class DraggableSoccerBall extends StatefulWidget {
  const DraggableSoccerBall({super.key});

  @override
  State<DraggableSoccerBall> createState() => _DraggableSoccerBallState();
}

class _DraggableSoccerBallState extends State<DraggableSoccerBall>
    with SingleTickerProviderStateMixin {
  Offset _position = const Offset(0.72, 0.78);
  bool _isDragging = false;
  late AnimationController _spinController;
  double _spinAngle = 0;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _spinController.addListener(() {
      setState(() => _spinAngle = _spinController.value * math.pi * 2);
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _onDragStart() {
    setState(() => _isDragging = true);
    _spinController.repeat();
  }

  void _onDragEnd() {
    setState(() => _isDragging = false);
    _spinController.stop();
    _spinController.reset();
  }

  @override
  Widget build(BuildContext context) {
    // BUG FIX: this widget is added directly as a child of an outer Stack
    // (in main.dart) with no Positioned wrapper around IT — this widget is
    // expected to position itself internally. It used to return
    // `LayoutBuilder(builder: (_, __) => Positioned(...))` directly.
    // `Positioned` only works when its *nearest* ancestor RenderObjectWidget
    // is a `Stack` — and `LayoutBuilder` is itself a RenderObjectWidget, so
    // sitting between the outer Stack and this Positioned broke that
    // relationship. That's exactly the
    // "Incorrect use of ParentDataWidget" / "the offending Positioned is
    // currently placed inside a LayoutBuilder widget" error seen in
    // DevTools. Wrapping the Positioned in its own inner Stack (filling the
    // available space via Positioned.fill) gives it a real Stack ancestor
    // again, fixing the error without changing any positioning behavior.
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ballSize = constraints.maxWidth > 600 ? 72.0 : 58.0;
          final maxX = constraints.maxWidth - ballSize - 8;
          final maxY = constraints.maxHeight - ballSize - 120;

          final left = (_position.dx * maxX).clamp(8.0, maxX);
          final top = (_position.dy * maxY).clamp(80.0, maxY);

          return Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                child: GestureDetector(
                  onPanStart: (_) => _onDragStart(),
                  onPanUpdate: (details) {
                    setState(() {
                      final newLeft =
                          (left + details.delta.dx).clamp(8.0, maxX);
                      final newTop = (top + details.delta.dy).clamp(80.0, maxY);
                      _position = Offset(
                        maxX > 0 ? newLeft / maxX : 0.5,
                        maxY > 0 ? newTop / maxY : 0.5,
                      );
                    });
                  },
                  onPanEnd: (_) => _onDragEnd(),
                  child: AnimatedScale(
                    scale: _isDragging ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Transform.rotate(
                      angle: _spinAngle,
                      child: Container(
                        width: ballSize,
                        height: ballSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white,
                              Colors.white.withOpacity(0.85),
                              const Color(0xFFE8E8E8),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00843D).withOpacity(0.45),
                              blurRadius: _isDragging ? 28 : 14,
                              spreadRadius: _isDragging ? 4 : 1,
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFFFFD700).withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Text('⚽', style: TextStyle(fontSize: 36)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
