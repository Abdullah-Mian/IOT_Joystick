import 'package:flutter/material.dart';
import 'base_joystick.dart';

class NeoJoystick extends BaseJoystick {
  const NeoJoystick({super.key, required super.callbacks});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            colorScheme.primary.withAlpha((0.2 * 255).toInt()),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha((0.2 * 255).toInt()),
            blurRadius: 15,
            spreadRadius: -2,
          ),
        ],
      ),
      child: GestureDetector(
        onPanUpdate: (details) {
          final dx = details.localPosition.dx - 100;
          final dy = details.localPosition.dy - 100;

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
            shape: BoxShape.circle,
            color: colorScheme.primary.withAlpha((0.1 * 255).toInt()),
          ),
        ),
      ),
    );
  }
}
