import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/squircle_border.dart';
import 'package:flutter/material.dart';

/// Wraps [child] with a squircle surface that appears to "cut into"
/// another surface by drawing a thick border using the surrounding
/// background color.
class AxiCutout extends StatelessWidget {
  const AxiCutout({
    super.key,
    required this.child,
    this.padding,
    this.background,
    this.borderColor,
    this.borderWidth = 4.0,
    this.cornerRadius = 14.0,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? background;
  final Color? borderColor;
  final double borderWidth;
  final double cornerRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: background ?? colors.card,
        shape: SquircleBorder(
          cornerRadius: cornerRadius,
          side: BorderSide(
            color: borderColor ?? colors.background,
            width: borderWidth,
          ),
        ),
      ),
      child: Padding(
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: child,
      ),
    );
  }
}
