import 'package:flutter/material.dart';
import 'base_joystick.dart';

class ClassicJoystick extends BaseJoystick {
  const ClassicJoystick({
    super.key,
    required super.callbacks,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDirectionButton(Icons.arrow_upward, callbacks['onForward']),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDirectionButton(Icons.arrow_back, callbacks['onLeft']),
            const SizedBox(width: 50),
            _buildDirectionButton(Icons.arrow_forward, callbacks['onRight']),
          ],
        ),
        _buildDirectionButton(Icons.arrow_downward, callbacks['onBackward']),
      ],
    );
  }

  Widget _buildDirectionButton(IconData icon, Function? onPressed) {
    return GestureDetector(
      onTapDown: (_) => onPressed?.call(),
      onTapUp: (_) => callbacks['onRelease']?.call(),
      onTapCancel: () => callbacks['onRelease']?.call(),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.blue.withAlpha((0.3 * 255).toInt()),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
