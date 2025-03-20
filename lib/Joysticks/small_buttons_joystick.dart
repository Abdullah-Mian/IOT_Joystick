import 'package:flutter/material.dart';
import 'base_joystick.dart';

class SmallButtonsJoystick extends BaseJoystick {
  const SmallButtonsJoystick({super.key, required super.callbacks});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildButton(Icons.arrow_upward, callbacks['onForward']),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildButton(Icons.arrow_back, callbacks['onLeft']),
            const SizedBox(width: 16),
            _buildButton(Icons.arrow_forward, callbacks['onRight']),
          ],
        ),
        _buildButton(Icons.arrow_downward, callbacks['onBackward']),
      ],
    );
  }

  Widget _buildButton(IconData icon, Function? onPressed) {
    return GestureDetector(
      onTapDown: (_) => onPressed?.call(),
      onTapUp: (_) => callbacks['onRelease']?.call(),
      child: Container(
        width: 40, // Smaller size
        height: 40,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.blue.withAlpha((0.3 * 255).toInt()),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}
