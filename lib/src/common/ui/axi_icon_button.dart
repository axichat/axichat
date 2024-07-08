import 'package:flutter/material.dart';

class AxiIconButton extends IconButton {
  AxiIconButton({
    super.key,
    required IconData iconData,
    required super.onPressed,
    super.style,
    super.tooltip,
  }) : super(icon: Icon(iconData));
}
