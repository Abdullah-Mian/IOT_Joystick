import 'package:flutter/material.dart';

abstract class BaseJoystick extends StatelessWidget {
  final Map<String, Function> callbacks;

  const BaseJoystick({
    super.key,
    required this.callbacks,
  });
}
