// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:flutter/material.dart';

class AxiHoverBand extends StatelessWidget {
  const AxiHoverBand({
    super.key,
    required this.shape,
    required this.color,
    required this.heightFactor,
  });

  final ShapeBorder shape;
  final Color color;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    return CustomPaint(
      painter: _AxiHoverBandPainter(
        shape: shape,
        color: color,
        heightFactor: heightFactor,
        textDirection: textDirection,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _AxiHoverBandPainter extends CustomPainter {
  const _AxiHoverBandPainter({
    required this.shape,
    required this.color,
    required this.heightFactor,
    required this.textDirection,
  });

  final ShapeBorder shape;
  final Color color;
  final double heightFactor;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final double clampedFactor = heightFactor.clamp(0.0, 1.0).toDouble();
    final double bandHeight = rect.height * clampedFactor;
    final double innerHeight = math.max(0.0, rect.height - bandHeight);
    final Rect innerRect = Rect.fromLTWH(
      rect.left,
      rect.top,
      rect.width,
      innerHeight,
    );
    final Path outer = shape.getOuterPath(rect, textDirection: textDirection);
    final Path inner =
        shape.getOuterPath(innerRect, textDirection: textDirection);
    final Path band = Path.combine(PathOperation.difference, outer, inner);
    final Color transparent = color.withValues(alpha: 0.0);
    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: <Color>[color, transparent],
      ).createShader(rect);
    canvas.drawPath(band, paint);
  }

  @override
  bool shouldRepaint(covariant _AxiHoverBandPainter oldDelegate) {
    return oldDelegate.shape != shape ||
        oldDelegate.color != color ||
        oldDelegate.heightFactor != heightFactor ||
        oldDelegate.textDirection != textDirection;
  }
}
