// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

class TaskTileSurface extends StatelessWidget {
  const TaskTileSurface({
    super.key,
    required this.margin,
    required this.decoration,
    required this.child,
    this.onTap,
    this.hoverColor,
    this.splashColor,
    this.highlightColor,
    this.focusColor,
    this.mouseCursor,
    this.leadingStripeColor,
    this.leadingStripeWidth,
  });

  final EdgeInsets margin;
  final BoxDecoration decoration;
  final Widget child;
  final VoidCallback? onTap;
  final Color? hoverColor;
  final Color? splashColor;
  final Color? highlightColor;
  final Color? focusColor;
  final MouseCursor? mouseCursor;
  final Color? leadingStripeColor;
  final double? leadingStripeWidth;

  @override
  Widget build(BuildContext context) {
    final RoundedSuperellipseBorder shape =
        RoundedSuperellipseBorder(borderRadius: context.radius);
    final MouseCursor effectiveCursor = mouseCursor ??
        (onTap != null ? SystemMouseCursors.click : MouseCursor.defer);
    final Border? border =
        decoration.border is Border ? decoration.border as Border : null;
    final BorderSide? uniformSide =
        border == null || !border.isUniform ? null : border.top;
    final RoundedSuperellipseBorder decoratedShape = uniformSide == null
        ? shape
        : RoundedSuperellipseBorder(
            borderRadius: context.radius,
            side: uniformSide,
          );
    final ShapeDecoration shapedDecoration = ShapeDecoration(
      color: decoration.color,
      shape: decoratedShape,
      shadows: decoration.boxShadow,
    );
    final double? stripeWidth = leadingStripeWidth;
    final Color? stripeColor = leadingStripeColor;
    final Widget content =
        stripeColor != null && stripeWidth != null && stripeWidth > 0
            ? CustomPaint(
                painter: _TaskTileStripePainter(
                  shape: decoratedShape,
                  color: stripeColor,
                  width: stripeWidth,
                ),
                child: child,
              )
            : child;

    return Container(
      margin: margin,
      child: AxiTapBounce(
        enabled: onTap != null,
        child: DecoratedBox(
          decoration: shapedDecoration,
          child: Material(
            type: MaterialType.transparency,
            shape: decoratedShape,
            child: InkWell(
              onTap: onTap,
              customBorder: decoratedShape,
              mouseCursor: effectiveCursor,
              hoverColor: hoverColor ?? Colors.transparent,
              splashColor: splashColor ?? Colors.transparent,
              highlightColor: highlightColor ?? Colors.transparent,
              focusColor: focusColor ?? Colors.transparent,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskTileStripePainter extends CustomPainter {
  _TaskTileStripePainter({
    required this.shape,
    required this.color,
    required this.width,
  });

  final ShapeBorder shape;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final Path shapePath = shape.getOuterPath(bounds);
    final Rect stripeRect = Rect.fromLTWH(0, 0, width, size.height);
    final Path stripePath = Path.combine(
      PathOperation.intersect,
      shapePath,
      Path()..addRect(stripeRect),
    );
    final Paint paint = Paint()..color = color;
    canvas.drawPath(stripePath, paint);
  }

  @override
  bool shouldRepaint(covariant _TaskTileStripePainter oldDelegate) {
    return oldDelegate.shape != shape ||
        oldDelegate.color != color ||
        oldDelegate.width != width;
  }
}
