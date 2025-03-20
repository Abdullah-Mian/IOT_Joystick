import 'package:flutter/material.dart';

class MinimalJoystick extends StatelessWidget {
  final Map<String, Function> callbacks;

  const MinimalJoystick({super.key, required this.callbacks});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.primary.withAlpha((0.2 * 255).toInt()),
          width: 1.5,
        ),
        gradient: RadialGradient(
          colors: [
            colorScheme.primary.withAlpha((0.05 * 255).toInt()),
            Colors.transparent,
          ],
        ),
      ),
      child: Stack(
        children: [
          _buildDirectionButton(
              Alignment.topCenter, '↑', callbacks['onForward']!, colorScheme),
          _buildDirectionButton(Alignment.bottomCenter, '↓',
              callbacks['onBackward']!, colorScheme),
          _buildDirectionButton(
              Alignment.centerLeft, '←', callbacks['onLeft']!, colorScheme),
          _buildDirectionButton(
              Alignment.centerRight, '→', callbacks['onRight']!, colorScheme),
          Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surface.withAlpha((0.1 * 255).toInt()),
                border: Border.all(
                  color: colorScheme.primary.withAlpha((0.2 * 255).toInt()),
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionButton(Alignment alignment, String label,
      Function onPressed, ColorScheme colorScheme) {
    return Align(
      alignment: alignment,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 0.9),
        duration: const Duration(milliseconds: 100),
        builder: (context, scale, child) {
          return GestureDetector(
            onTapDown: (_) => onPressed(),
            onTapUp: (_) => callbacks['onRelease']!(),
            onTapCancel: () => callbacks['onRelease']!(),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: colorScheme.surface.withAlpha((0.1 * 255).toInt()),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.primary.withAlpha((0.3 * 255).toInt()),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 20,
                      color: colorScheme.primary.withAlpha((0.8 * 255).toInt()),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
