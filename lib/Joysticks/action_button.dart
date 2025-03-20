import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const ActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onPressed(),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 0.95),
        duration: const Duration(milliseconds: 100),
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: color.withAlpha((0.2 * 255).toInt()),
                shape: BoxShape.circle,
                border: Border.all(
                    color: color.withAlpha((0.5 * 255).toInt()), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withAlpha((0.3 * 255).toInt()),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color.withAlpha((0.9 * 255).toInt()),
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
