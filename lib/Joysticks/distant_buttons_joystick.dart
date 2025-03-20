import 'package:flutter/material.dart';
import 'base_joystick.dart';

class DistantButtonsJoystick extends BaseJoystick {
  const DistantButtonsJoystick({super.key, required super.callbacks});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildButton(
              Alignment.topCenter, Icons.arrow_upward, callbacks['onForward'],
              offset: -10),
          _buildButton(Alignment.bottomCenter, Icons.arrow_downward,
              callbacks['onBackward'],
              offset: 10),
          _buildButton(
              Alignment.centerLeft, Icons.arrow_back, callbacks['onLeft'],
              offset: -10),
          _buildButton(
              Alignment.centerRight, Icons.arrow_forward, callbacks['onRight'],
              offset: 10),
        ],
      ),
    );
  }

  Widget _buildButton(Alignment alignment, IconData icon, Function? onPressed,
      {double offset = 0}) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: EdgeInsets.all(offset.abs()),
        child: GestureDetector(
          onTapDown: (_) => onPressed?.call(),
          onTapUp: (_) => callbacks['onRelease']?.call(),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha((0.3 * 255).toInt()),
              shape: BoxShape.circle,
            ),
            child: Icon(icon),
          ),
        ),
      ),
    );
  }
}
