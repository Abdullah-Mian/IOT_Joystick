import 'package:flutter/material.dart';
import 'base_joystick.dart';

class CloseButtonsJoystick extends BaseJoystick {
  const CloseButtonsJoystick({super.key, required super.callbacks});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildButton(
              Alignment.topCenter, Icons.arrow_upward, callbacks['onForward']),
          _buildButton(Alignment.bottomCenter, Icons.arrow_downward,
              callbacks['onBackward']),
          _buildButton(
              Alignment.centerLeft, Icons.arrow_back, callbacks['onLeft']),
          _buildButton(
              Alignment.centerRight, Icons.arrow_forward, callbacks['onRight']),
        ],
      ),
    );
  }

  Widget _buildButton(Alignment alignment, IconData icon, Function? onPressed) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTapDown: (_) => onPressed?.call(),
        onTapUp: (_) => callbacks['onRelease']?.call(),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blue.withAlpha((0.3 * 255).toInt()),
            shape: BoxShape.circle,
          ),
          child: Icon(icon),
        ),
      ),
    );
  }
}
