// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/common/ui/squircle_border.dart';
import 'package:flutter/widgets.dart';

class CutoutSurface extends StatelessWidget {
  const CutoutSurface({
    super.key,
    required this.child,
    required this.cutouts,
    required this.backgroundColor,
    required this.borderColor,
    required this.shape,
    this.shadows = const [],
    this.shadowOpacity = 0,
  });

  final Widget child;
  final List<CutoutSpec> cutouts;
  final Color backgroundColor;
  final Color borderColor;
  final OutlinedBorder shape;
  final List<BoxShadow> shadows;
  final double shadowOpacity;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final scaleFactor =
        mediaQuery == null ? 1.0 : mediaQuery.textScaler.scale(1);
    final resolvedCutouts = scaleFactor == 1
        ? cutouts
        : cutouts
            .map((spec) => spec.scaled(scaleFactor))
            .toList(growable: false);
    final resolvedShadowOpacity = shadowOpacity.clamp(0.0, 1.0);
    final clipper = _CutoutClipper(shape: shape, cutouts: resolvedCutouts);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          painter: _CutoutPainter(
            shape: shape,
            backgroundColor: backgroundColor,
            borderColor: borderColor,
            cutouts: resolvedCutouts,
            shadows: shadows,
            shadowOpacity: resolvedShadowOpacity,
          ),
          child: ClipPath(
            clipper: clipper,
            child: child,
          ),
        ),
        if (resolvedCutouts.isNotEmpty)
          for (final spec in resolvedCutouts) _CutoutAttachment(spec: spec),
      ],
    );
  }
}

class CutoutSpec {
  const CutoutSpec({
    required this.edge,
    required this.alignment,
    required this.depth,
    required this.thickness,
    required this.child,
    this.cornerRadius = 16,
  });

  final CutoutEdge edge;
  final Alignment alignment;
  final double depth;
  final double thickness;
  final Widget child;
  final double cornerRadius;

  CutoutSpec scaled(double factor) {
    if (factor == 1) return this;
    return CutoutSpec(
      edge: edge,
      alignment: alignment,
      depth: depth * factor,
      thickness: thickness * factor,
      child: child,
      cornerRadius: cornerRadius * factor,
    );
  }
}

enum CutoutEdge { top, right, bottom, left }

class _CutoutPainter extends CustomPainter {
  const _CutoutPainter({
    required this.shape,
    required this.backgroundColor,
    required this.borderColor,
    required this.cutouts,
    required this.shadows,
    required this.shadowOpacity,
  });

  final OutlinedBorder shape;
  final Color backgroundColor;
  final Color borderColor;
  final List<CutoutSpec> cutouts;
  final List<BoxShadow> shadows;
  final double shadowOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPath = _cutoutPath(size, shape, cutouts);

    if (shadowOpacity > 0 && shadows.isNotEmpty) {
      for (final shadow in shadows) {
        final baseAlpha = shadow.color.a;
        if (baseAlpha <= 0) continue;
        final shadowColor = shadow.color.withValues(
          alpha: baseAlpha * shadowOpacity,
        );
        if (shadowColor.a <= 0) continue;
        final paint = Paint()
          ..color = shadowColor
          ..style = PaintingStyle.fill
          ..maskFilter = shadow.blurRadius <= 0
              ? null
              : MaskFilter.blur(
                  BlurStyle.normal,
                  _blurSigma(shadow.blurRadius),
                );
        canvas.save();
        canvas.translate(shadow.offset.dx, shadow.offset.dy);
        canvas.drawPath(fillPath, paint);
        canvas.restore();
      }
    }

    final fillPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(fillPath, fillPaint);
    if (borderColor.a > 0) {
      canvas.drawPath(fillPath, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CutoutPainter oldDelegate) => true;
}

class _CutoutClipper extends CustomClipper<Path> {
  const _CutoutClipper({required this.shape, required this.cutouts});

  final OutlinedBorder shape;
  final List<CutoutSpec> cutouts;

  @override
  Path getClip(Size size) => _cutoutPath(size, shape, cutouts);

  @override
  bool shouldReclip(covariant _CutoutClipper oldClipper) {
    return oldClipper.shape != shape || oldClipper.cutouts != cutouts;
  }
}

Path _cutoutPath(
  Size size,
  OutlinedBorder shape,
  List<CutoutSpec> cutouts,
) {
  final rect = Offset.zero & size;
  final outerPath = shape.getOuterPath(rect);
  var fillPath = Path()..addPath(outerPath, Offset.zero);
  for (final spec in cutouts) {
    final cutoutRect = _cutoutRect(size, spec);
    final cutoutPath =
        SquircleBorder(cornerRadius: spec.cornerRadius).getOuterPath(
      cutoutRect,
    );
    fillPath = Path.combine(PathOperation.difference, fillPath, cutoutPath);
  }
  return fillPath;
}

class _CutoutAttachment extends StatelessWidget {
  const _CutoutAttachment({required this.spec});

  final CutoutSpec spec;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _CutoutAttachmentDelegate(spec),
        child: spec.child,
      ),
    );
  }
}

class _CutoutAttachmentDelegate extends SingleChildLayoutDelegate {
  const _CutoutAttachmentDelegate(this.spec);

  final CutoutSpec spec;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(Size(
      constraints.maxWidth,
      constraints.maxHeight,
    ));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final rect = _cutoutRect(size, spec);
    final direction = _insideNormal(spec.edge);
    final inset = _resolvedInset(childSize);
    final target = rect.center + direction * inset;
    final topLeft = target -
        Offset(
          childSize.width / 2,
          childSize.height / 2,
        );
    return topLeft;
  }

  double _resolvedInset(Size childSize) {
    final inset = _autoInset(childSize);
    return inset.clamp(-spec.depth, spec.depth);
  }

  double _autoInset(Size childSize) {
    final normalExtent = _extentAlongNormal(childSize);
    final perpendicularExtent = _extentPerpendicular(childSize);
    final targetClearance =
        math.max(0.0, (spec.thickness - perpendicularExtent) / 2);
    final inset = spec.depth - normalExtent / 2 - targetClearance;
    if (inset <= 0) {
      return 0;
    }
    return math.min(inset, spec.depth);
  }

  double _extentAlongNormal(Size childSize) {
    switch (spec.edge) {
      case CutoutEdge.right:
      case CutoutEdge.left:
        return childSize.width;
      case CutoutEdge.top:
      case CutoutEdge.bottom:
        return childSize.height;
    }
  }

  double _extentPerpendicular(Size childSize) {
    switch (spec.edge) {
      case CutoutEdge.right:
      case CutoutEdge.left:
        return childSize.height;
      case CutoutEdge.top:
      case CutoutEdge.bottom:
        return childSize.width;
    }
  }

  @override
  bool shouldRelayout(covariant _CutoutAttachmentDelegate oldDelegate) =>
      oldDelegate.spec != spec;
}

Rect _cutoutRect(Size size, CutoutSpec spec) {
  final anchor = _edgeAnchor(size, spec);
  final halfThickness = spec.thickness / 2;
  switch (spec.edge) {
    case CutoutEdge.right:
      return Rect.fromLTRB(
        size.width - spec.depth,
        anchor.dy - halfThickness,
        size.width + spec.depth,
        anchor.dy + halfThickness,
      );
    case CutoutEdge.left:
      return Rect.fromLTRB(
        -spec.depth,
        anchor.dy - halfThickness,
        spec.depth,
        anchor.dy + halfThickness,
      );
    case CutoutEdge.top:
      return Rect.fromLTRB(
        anchor.dx - halfThickness,
        -spec.depth,
        anchor.dx + halfThickness,
        spec.depth,
      );
    case CutoutEdge.bottom:
      return Rect.fromLTRB(
        anchor.dx - halfThickness,
        size.height - spec.depth,
        anchor.dx + halfThickness,
        size.height + spec.depth,
      );
  }
}

Offset _edgeAnchor(Size size, CutoutSpec spec) {
  final fx = ((spec.alignment.x + 1) / 2) * size.width;
  final fy = ((spec.alignment.y + 1) / 2) * size.height;
  switch (spec.edge) {
    case CutoutEdge.right:
      return Offset(size.width, fy);
    case CutoutEdge.left:
      return Offset(0, fy);
    case CutoutEdge.top:
      return Offset(fx, 0);
    case CutoutEdge.bottom:
      return Offset(fx, size.height);
  }
}

Offset _insideNormal(CutoutEdge edge) {
  switch (edge) {
    case CutoutEdge.right:
      return const Offset(-1, 0);
    case CutoutEdge.left:
      return const Offset(1, 0);
    case CutoutEdge.top:
      return const Offset(0, 1);
    case CutoutEdge.bottom:
      return const Offset(0, -1);
  }
}

double _blurSigma(double radius) {
  if (radius <= 0) return 0;
  return radius * 0.57735 + 0.5;
}
