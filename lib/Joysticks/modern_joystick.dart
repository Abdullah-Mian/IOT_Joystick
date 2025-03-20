import 'package:flutter/material.dart';
import 'base_joystick.dart';

class ModernJoystick extends BaseJoystick {
  const ModernJoystick({
    super.key,
    required super.callbacks,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha((0.1 * 255).toInt()),
        shape: BoxShape.circle,
      ),
      child: GridPattern(callbacks: callbacks),
    );
  }
}

class GridPattern extends StatelessWidget {
  final Map<String, Function> callbacks;

  const GridPattern({super.key, required this.callbacks});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        final dx = details.localPosition.dx - 90;
        final dy = details.localPosition.dy - 90;

        if (dx.abs() > dy.abs()) {
          if (dx > 0) {
            callbacks['onRight']?.call();
          } else {
            callbacks['onLeft']?.call();
          }
        } else {
          if (dy > 0) {
            callbacks['onBackward']?.call();
          } else {
            callbacks['onForward']?.call();
          }
        }
      },
      onPanEnd: (_) => callbacks['onRelease']?.call(),
      onPanCancel: () => callbacks['onRelease']?.call(),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue.withAlpha((0.3 * 255).toInt())),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
