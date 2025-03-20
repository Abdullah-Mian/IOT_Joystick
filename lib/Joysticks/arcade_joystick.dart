import 'package:flutter/material.dart';
import 'dart:math';
import 'base_joystick.dart';

class ArcadeJoystick extends BaseJoystick {
  const ArcadeJoystick({super.key, required super.callbacks});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            colorScheme.tertiary.withAlpha((0.15 * 255).toInt()),
            Colors.transparent,
          ],
        ),
      ),
      child: GestureDetector(
        onPanUpdate: (details) {
          const center = Offset(110, 110);
          final position = details.localPosition;
          final angle =
              (atan2(position.dy - center.dy, position.dx - center.dx) *
                          180 /
                          pi +
                      360) %
                  360;

          if (angle >= 315 || angle < 45) {
            callbacks['onRight']!();
          } else if (angle >= 45 && angle < 135)
            callbacks['onBackward']!();
          else if (angle >= 135 && angle < 225)
            callbacks['onLeft']!();
          else if (angle >= 225 && angle < 315) callbacks['onForward']!();
        },
        onPanEnd: (_) => callbacks['onRelease']?.call(),
        onPanCancel: () => callbacks['onRelease']?.call(),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.surface.withAlpha((0.3 * 255).toInt()),
          ),
        ),
      ),
    );
  }
}
