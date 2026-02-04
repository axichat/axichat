// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/common/ui/squircle_border.dart';
import 'package:flutter/rendering.dart';
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
    final borderWidth = shape.side.width;

    return _CutoutRender(
      cutouts: resolvedCutouts,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      borderWidth: borderWidth,
      shape: shape,
      shadows: shadows,
      shadowOpacity: resolvedShadowOpacity,
      child: child,
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

class _CutoutRender extends MultiChildRenderObjectWidget {
  _CutoutRender({
    required this.cutouts,
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
    required this.shape,
    required this.shadows,
    required this.shadowOpacity,
    required Widget child,
  }) : super(
          children: [
            child,
            for (final spec in cutouts) spec.child,
          ],
        );

  final List<CutoutSpec> cutouts;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final OutlinedBorder shape;
  final List<BoxShadow> shadows;
  final double shadowOpacity;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderCutoutSurface(
      cutouts: cutouts,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      borderWidth: borderWidth,
      shape: shape,
      shadows: shadows,
      shadowOpacity: shadowOpacity,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderCutoutSurface)
      ..cutouts = cutouts
      ..backgroundColor = backgroundColor
      ..borderColor = borderColor
      ..borderWidth = borderWidth
      ..shape = shape
      ..shadows = shadows
      ..shadowOpacity = shadowOpacity;
  }
}

class _RenderCutoutSurface extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CutoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CutoutParentData> {
  _RenderCutoutSurface({
    required List<CutoutSpec> cutouts,
    required Color backgroundColor,
    required Color borderColor,
    required double borderWidth,
    required OutlinedBorder shape,
    required List<BoxShadow> shadows,
    required double shadowOpacity,
  })  : _cutouts = cutouts,
        _backgroundColor = backgroundColor,
        _borderColor = borderColor,
        _borderWidth = borderWidth,
        _shape = shape,
        _shadows = shadows,
        _shadowOpacity = shadowOpacity;

  List<CutoutSpec> get cutouts => _cutouts;
  List<CutoutSpec> _cutouts;
  set cutouts(List<CutoutSpec> value) {
    if (value == _cutouts) return;
    _cutouts = value;
    markNeedsLayout();
  }

  Color get backgroundColor => _backgroundColor;
  Color _backgroundColor;
  set backgroundColor(Color value) {
    if (value == _backgroundColor) return;
    _backgroundColor = value;
    markNeedsPaint();
  }

  Color get borderColor => _borderColor;
  Color _borderColor;
  set borderColor(Color value) {
    if (value == _borderColor) return;
    _borderColor = value;
    markNeedsPaint();
  }

  double get borderWidth => _borderWidth;
  double _borderWidth;
  set borderWidth(double value) {
    if (value == _borderWidth) return;
    _borderWidth = value;
    markNeedsPaint();
  }

  OutlinedBorder get shape => _shape;
  OutlinedBorder _shape;
  set shape(OutlinedBorder value) {
    if (value == _shape) return;
    _shape = value;
    markNeedsLayout();
  }

  List<BoxShadow> get shadows => _shadows;
  List<BoxShadow> _shadows;
  set shadows(List<BoxShadow> value) {
    if (value == _shadows) return;
    _shadows = value;
    markNeedsPaint();
  }

  double get shadowOpacity => _shadowOpacity;
  double _shadowOpacity;
  set shadowOpacity(double value) {
    if (value == _shadowOpacity) return;
    _shadowOpacity = value;
    markNeedsPaint();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CutoutParentData) {
      child.parentData = _CutoutParentData();
    }
  }

  @override
  void performLayout() {
    if (firstChild == null) {
      size = constraints.smallest;
      return;
    }

    final bodyChild = firstChild!;
    final cutoutChildren = <RenderBox>[];
    final cutoutConstraints = BoxConstraints.loose(
      Size(constraints.maxWidth, constraints.maxHeight),
    );
    var child = childAfter(bodyChild);
    while (child != null) {
      child.layout(cutoutConstraints, parentUsesSize: true);
      cutoutChildren.add(child);
      child = childAfter(child);
    }

    final cutoutCount = math.min(cutoutChildren.length, _cutouts.length);
    var maxRightHalfWidth = 0.0;
    for (var i = 0; i < cutoutCount; i++) {
      final childBox = cutoutChildren[i];
      final spec = _cutouts[i];
      if (spec.edge == CutoutEdge.right) {
        maxRightHalfWidth =
            math.max(maxRightHalfWidth, childBox.size.width / 2);
      }
    }

    final bodyConstraints = constraints.deflate(
      EdgeInsetsDirectional.only(end: maxRightHalfWidth),
    );
    bodyChild.layout(bodyConstraints, parentUsesSize: true);
    final bodySize = bodyChild.size;
    size = constraints.constrain(
      Size(bodySize.width + maxRightHalfWidth, bodySize.height),
    );
    const bodyOffset = Offset.zero;

    bodyChildParentData(bodyChild).offset = bodyOffset;

    for (var i = 0; i < cutoutCount; i++) {
      final childBox = cutoutChildren[i];
      final spec = _cutouts[i];
      final rect = _cutoutRect(bodySize, spec);
      final topLeft = _cutoutChildOffset(rect, spec, childBox.size);
      bodyChildParentData(childBox).offset = bodyOffset + topLeft;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (firstChild == null) return;

    final bodyChild = firstChild!;
    final bodyParentData = bodyChildParentData(bodyChild);
    final bodyOffset = bodyParentData.offset;
    final bodySize = bodyChild.size;
    final fillPath = _cutoutPath(bodySize, shape, cutouts);
    final paintOffset = offset + bodyOffset;

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
        context.canvas.save();
        context.canvas.translate(
          paintOffset.dx + shadow.offset.dx,
          paintOffset.dy + shadow.offset.dy,
        );
        context.canvas.drawPath(fillPath, paint);
        context.canvas.restore();
      }
    }

    final fillPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    context.canvas.save();
    context.canvas.translate(paintOffset.dx, paintOffset.dy);
    context.canvas.drawPath(fillPath, fillPaint);
    if (borderColor.a > 0 && borderWidth > 0) {
      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth * 2
        ..strokeJoin = StrokeJoin.round;
      context.canvas.save();
      context.canvas.clipPath(fillPath);
      context.canvas.drawPath(fillPath, borderPaint);
      context.canvas.restore();
    }
    context.canvas.restore();

    final clipRect = paintOffset & bodySize;
    context.pushClipPath(
      needsCompositing,
      paintOffset,
      clipRect,
      fillPath,
      (context, offset) {
        context.paintChild(bodyChild, offset);
      },
    );

    var child = childAfter(bodyChild);
    while (child != null) {
      final childParentData = bodyChildParentData(child);
      context.paintChild(child, offset + childParentData.offset);
      child = childAfter(child);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  bool hitTestSelf(Offset position) => false;

  _CutoutParentData bodyChildParentData(RenderBox child) {
    return child.parentData! as _CutoutParentData;
  }
}

class _CutoutParentData extends ContainerBoxParentData<RenderBox> {}

Path _cutoutPath(Size size, OutlinedBorder shape, List<CutoutSpec> cutouts) {
  final rect = Offset.zero & size;
  final outerPath = shape.getOuterPath(rect);
  var fillPath = Path()..addPath(outerPath, Offset.zero);
  for (final spec in cutouts) {
    final cutoutRect = _cutoutRect(size, spec);
    final cutoutPath = SquircleBorder(
      cornerRadius: spec.cornerRadius,
    ).getOuterPath(cutoutRect);
    fillPath = Path.combine(PathOperation.difference, fillPath, cutoutPath);
  }
  return fillPath;
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

Offset _cutoutChildOffset(Rect rect, CutoutSpec spec, Size childSize) {
  final direction = _insideNormal(spec.edge);
  final inset = _resolvedInset(spec, childSize);
  final target = rect.center + direction * inset;
  return target - Offset(childSize.width / 2, childSize.height / 2);
}

double _resolvedInset(CutoutSpec spec, Size childSize) {
  final inset = _autoInset(spec, childSize);
  return inset.clamp(-spec.depth, spec.depth);
}

double _autoInset(CutoutSpec spec, Size childSize) {
  final normalExtent = _extentAlongNormal(spec, childSize);
  final perpendicularExtent = _extentPerpendicular(spec, childSize);
  final targetClearance = math.max(
    0.0,
    (spec.thickness - perpendicularExtent) / 2,
  );
  final inset = spec.depth - normalExtent / 2 - targetClearance;
  if (inset <= 0) {
    return 0;
  }
  return math.min(inset, spec.depth);
}

double _extentAlongNormal(CutoutSpec spec, Size childSize) {
  switch (spec.edge) {
    case CutoutEdge.right:
    case CutoutEdge.left:
      return childSize.width;
    case CutoutEdge.top:
    case CutoutEdge.bottom:
      return childSize.height;
  }
}

double _extentPerpendicular(CutoutSpec spec, Size childSize) {
  switch (spec.edge) {
    case CutoutEdge.right:
    case CutoutEdge.left:
      return childSize.height;
    case CutoutEdge.top:
    case CutoutEdge.bottom:
      return childSize.width;
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
  return (radius / 2) + (1 / 2);
}
