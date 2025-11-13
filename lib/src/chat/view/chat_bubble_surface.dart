import 'dart:math' as math;

import 'package:axichat/src/common/ui/squircle_border.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Slots managed by [ChatBubbleSurface].
enum _ChatBubbleSlot {
  body,
  reaction,
  recipients,
}

class _ChatBubbleSlotWidget extends ParentDataWidget<_ChatBubbleParentData> {
  const _ChatBubbleSlotWidget({
    required this.slot,
    required super.child,
  });

  final _ChatBubbleSlot slot;

  @override
  void applyParentData(RenderObject renderObject) {
    final parentData = renderObject.parentData as _ChatBubbleParentData;
    if (parentData.slot == slot) return;
    parentData.slot = slot;
    final targetParent = renderObject.parent;
    if (targetParent is RenderObject) {
      targetParent.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => ChatBubbleSurface;
}

class _ChatBubbleParentData extends ContainerBoxParentData<RenderBox> {
  _ChatBubbleSlot slot = _ChatBubbleSlot.body;
}

class CutoutStyle {
  const CutoutStyle({
    required this.depth,
    required this.cornerRadius,
    required this.padding,
    required this.offset,
    required this.minThickness,
  });

  final double depth;
  final double cornerRadius;
  final EdgeInsets padding;
  final Offset offset;
  final double minThickness;
}

class ChatBubbleSurface extends MultiChildRenderObjectWidget {
  ChatBubbleSurface({
    super.key,
    required this.isSelf,
    required this.backgroundColor,
    required this.borderColor,
    required this.borderRadius,
    required this.shadowOpacity,
    required this.shadows,
    required this.bubbleWidthFraction,
    required this.cornerClearance,
    required Widget body,
    this.reactionOverlay,
    this.reactionStyle,
    this.recipientOverlay,
    this.recipientStyle,
  }) : super(
          children: [
            _ChatBubbleSlotWidget(
              slot: _ChatBubbleSlot.body,
              child: body,
            ),
            if (reactionOverlay != null)
              _ChatBubbleSlotWidget(
                slot: _ChatBubbleSlot.reaction,
                child: reactionOverlay,
              ),
            if (recipientOverlay != null)
              _ChatBubbleSlotWidget(
                slot: _ChatBubbleSlot.recipients,
                child: recipientOverlay,
              ),
          ],
        );

  final bool isSelf;
  final Color backgroundColor;
  final Color borderColor;
  final BorderRadius borderRadius;
  final double shadowOpacity;
  final List<BoxShadow> shadows;
  final double bubbleWidthFraction;
  final double cornerClearance;
  final Widget? reactionOverlay;
  final CutoutStyle? reactionStyle;
  final Widget? recipientOverlay;
  final CutoutStyle? recipientStyle;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderChatBubbleSurface(
        isSelf: isSelf,
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        borderRadius: borderRadius,
        shadowOpacity: shadowOpacity,
        shadows: shadows,
        bubbleWidthFraction: bubbleWidthFraction,
        cornerClearance: cornerClearance,
        reactionStyle: reactionStyle,
        recipientStyle: recipientStyle,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderChatBubbleSurface renderObject,
  ) {
    renderObject
      ..isSelf = isSelf
      ..backgroundColor = backgroundColor
      ..borderColor = borderColor
      ..borderRadius = borderRadius
      ..shadowOpacity = shadowOpacity
      ..shadows = shadows
      ..bubbleWidthFraction = bubbleWidthFraction
      ..cornerClearance = cornerClearance
      ..reactionStyle = reactionStyle
      ..recipientStyle = recipientStyle;
  }
}

class RenderChatBubbleSurface extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ChatBubbleParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ChatBubbleParentData> {
  RenderChatBubbleSurface({
    required bool isSelf,
    required Color backgroundColor,
    required Color borderColor,
    required BorderRadius borderRadius,
    required double shadowOpacity,
    required List<BoxShadow> shadows,
    required double bubbleWidthFraction,
    required double cornerClearance,
    CutoutStyle? reactionStyle,
    CutoutStyle? recipientStyle,
  })  : _isSelf = isSelf,
        _backgroundColor = backgroundColor,
        _borderColor = borderColor,
        _borderRadius = borderRadius,
        _shadowOpacity = shadowOpacity,
        _shadows = shadows,
        _bubbleWidthFraction = bubbleWidthFraction,
        _cornerClearance = cornerClearance,
        _reactionStyle = reactionStyle,
        _recipientStyle = recipientStyle;

  bool _isSelf;
  bool get isSelf => _isSelf;
  set isSelf(bool value) {
    if (value == _isSelf) return;
    _isSelf = value;
    markNeedsLayout();
    markNeedsPaint();
  }

  Color _backgroundColor;
  Color get backgroundColor => _backgroundColor;
  set backgroundColor(Color value) {
    if (value == _backgroundColor) return;
    _backgroundColor = value;
    markNeedsPaint();
  }

  Color _borderColor;
  Color get borderColor => _borderColor;
  set borderColor(Color value) {
    if (value == _borderColor) return;
    _borderColor = value;
    markNeedsPaint();
  }

  BorderRadius _borderRadius;
  BorderRadius get borderRadius => _borderRadius;
  set borderRadius(BorderRadius value) {
    if (value == _borderRadius) return;
    _borderRadius = value;
    markNeedsPaint();
  }

  double _shadowOpacity;
  double get shadowOpacity => _shadowOpacity;
  set shadowOpacity(double value) {
    final resolved = value.clamp(0.0, 1.0);
    if (resolved == _shadowOpacity) return;
    _shadowOpacity = resolved;
    markNeedsPaint();
  }

  List<BoxShadow> _shadows;
  List<BoxShadow> get shadows => _shadows;
  set shadows(List<BoxShadow> value) {
    if (_shadows == value) return;
    _shadows = value;
    markNeedsPaint();
  }

  double _bubbleWidthFraction;
  double get bubbleWidthFraction => _bubbleWidthFraction;
  set bubbleWidthFraction(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (clamped == _bubbleWidthFraction) return;
    _bubbleWidthFraction = clamped;
    markNeedsLayout();
  }

  double _cornerClearance;
  double get cornerClearance => _cornerClearance;
  set cornerClearance(double value) {
    if (value == _cornerClearance) return;
    _cornerClearance = value;
    markNeedsLayout();
  }

  CutoutStyle? _reactionStyle;
  CutoutStyle? get reactionStyle => _reactionStyle;
  set reactionStyle(CutoutStyle? value) {
    if (_reactionStyle == value) return;
    _reactionStyle = value;
    markNeedsLayout();
    markNeedsPaint();
  }

  CutoutStyle? _recipientStyle;
  CutoutStyle? get recipientStyle => _recipientStyle;
  set recipientStyle(CutoutStyle? value) {
    if (_recipientStyle == value) return;
    _recipientStyle = value;
    markNeedsLayout();
    markNeedsPaint();
  }

  RenderBox? get _bodyChild => _childForSlot(_ChatBubbleSlot.body);
  RenderBox? get _reactionChild => _childForSlot(_ChatBubbleSlot.reaction);
  RenderBox? get _recipientChild => _childForSlot(_ChatBubbleSlot.recipients);

  Rect? _reactionCutoutRect;
  Rect? _recipientCutoutRect;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _ChatBubbleParentData) {
      child.parentData = _ChatBubbleParentData();
    }
  }

  RenderBox? _childForSlot(_ChatBubbleSlot slot) {
    RenderBox? child = firstChild;
    while (child != null) {
      final parentData = child.parentData as _ChatBubbleParentData;
      if (parentData.slot == slot) {
        return child;
      }
      child = parentData.nextSibling;
    }
    return null;
  }

  @override
  void performLayout() {
    final body = _bodyChild;
    if (body == null) {
      size = constraints.smallest;
      return;
    }

    body.layout(constraints, parentUsesSize: true);
    (body.parentData as _ChatBubbleParentData).offset = Offset.zero;
    size = body.size;

    _reactionCutoutRect = null;
    _recipientCutoutRect = null;

    _layoutCutoutChild(
      child: _reactionChild,
      style: reactionStyle,
      isReaction: true,
    );
    _layoutCutoutChild(
      child: _recipientChild,
      style: recipientStyle,
      isReaction: false,
    );
  }

  void _layoutCutoutChild({
    required RenderBox? child,
    required CutoutStyle? style,
    required bool isReaction,
  }) {
    if (child == null || style == null) return;
    final maxThickness = _resolveCutoutLimit(
      bubbleWidth: size.width,
      minThickness: style.minThickness,
      cornerClearance: cornerClearance,
      fraction: bubbleWidthFraction,
    );
    if (maxThickness <= 0) return;
    final maxContentWidth =
        math.max(0.0, maxThickness - style.padding.horizontal);
    if (maxContentWidth <= 0) return;
    child.layout(
      BoxConstraints(
        minWidth: 0,
        maxWidth: maxContentWidth,
      ),
      parentUsesSize: true,
    );
    final childSize = child.size;
    if (childSize.width <= 0 || childSize.height <= 0) return;

    var resolvedThickness = math.max(
      style.minThickness,
      childSize.width + style.padding.horizontal,
    );
    resolvedThickness = math.min(resolvedThickness, maxThickness);

    final placement = _reactionCutoutPlacement(
      bubbleWidth: size.width,
      requestedThickness: resolvedThickness,
      isSelf: isSelf,
      cornerClearance: cornerClearance,
    );

    final rect = Rect.fromLTWH(
      placement.left,
      size.height - style.depth,
      placement.width,
      style.depth * 2,
    );

    final childParentData = child.parentData as _ChatBubbleParentData;
    childParentData.offset = Offset(
      rect.left + style.padding.left + style.offset.dx,
      rect.top + style.padding.top + style.offset.dy,
    );

    if (isReaction) {
      _reactionCutoutRect = rect;
    } else {
      _recipientCutoutRect = rect;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final localPath = _buildBubblePath(
      size,
      borderRadius,
      [
        if (_reactionCutoutRect != null)
          _CutoutDescriptor(
            rect: _reactionCutoutRect!,
            cornerRadius: reactionStyle?.cornerRadius ?? 16,
          ),
        if (_recipientCutoutRect != null)
          _CutoutDescriptor(
            rect: _recipientCutoutRect!,
            cornerRadius: recipientStyle?.cornerRadius ?? 16,
          ),
      ],
    );
    final path = localPath.shift(offset);

    final canvas = context.canvas;

    _paintShadows(canvas, path);

    final fillPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, fillPaint);
    if (borderColor.a > 0) {
      canvas.drawPath(path, strokePaint);
    }

    canvas.save();
    canvas.clipPath(path);
    final body = _bodyChild;
    if (body != null) {
      final bodyParentData = body.parentData as _ChatBubbleParentData;
      context.paintChild(body, offset + bodyParentData.offset);
    }
    canvas.restore();

    _paintAttachments(context, offset);
  }

  void _paintShadows(Canvas canvas, Path path) {
    if (shadowOpacity <= 0 || shadows.isEmpty) return;
    for (final shadow in shadows) {
      final color = shadow.color.withValues(
        alpha: shadow.color.a * shadowOpacity,
      );
      if (color.a <= 0) continue;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      if (shadow.blurRadius > 0) {
        paint.maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          _blurSigma(shadow.blurRadius),
        );
      }
      canvas.save();
      canvas.translate(shadow.offset.dx, shadow.offset.dy);
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  void _paintAttachments(PaintingContext context, Offset offset) {
    RenderBox? child = firstChild;
    while (child != null) {
      final parentData = child.parentData as _ChatBubbleParentData;
      if (parentData.slot != _ChatBubbleSlot.body) {
        context.paintChild(child, offset + parentData.offset);
      }
      child = parentData.nextSibling;
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final bool hitChild = _hitTestChildren(result, position: position);
    final hitSelf = size.contains(position) && hitTestSelf(position);
    return hitChild || hitSelf;
  }

  bool _hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    RenderBox? child = lastChild;
    while (child != null) {
      final parentData = child.parentData as _ChatBubbleParentData;
      final shouldTestBody =
          parentData.slot == _ChatBubbleSlot.body && size.contains(position);
      final shouldTestAttachment = parentData.slot != _ChatBubbleSlot.body;
      if (shouldTestBody || shouldTestAttachment) {
        if (child.hitTest(
          result,
          position: position - parentData.offset,
        )) {
          return true;
        }
      }
      child = parentData.previousSibling;
    }
    return false;
  }

  @override
  bool hitTestSelf(Offset position) => false;
}

class _CutoutDescriptor {
  const _CutoutDescriptor({
    required this.rect,
    required this.cornerRadius,
  });

  final Rect rect;
  final double cornerRadius;
}

Path _buildBubblePath(
  Size size,
  BorderRadius borderRadius,
  List<_CutoutDescriptor> cutouts,
) {
  final rect = Offset.zero & size;
  final shape = ContinuousRectangleBorder(borderRadius: borderRadius);
  var path = Path()..addPath(shape.getOuterPath(rect), Offset.zero);
  for (final cutout in cutouts) {
    final cutoutShape = SquircleBorder(cornerRadius: cutout.cornerRadius);
    path = Path.combine(
      PathOperation.difference,
      path,
      cutoutShape.getOuterPath(cutout.rect),
    );
  }
  return path;
}

double _resolveCutoutLimit({
  required double? bubbleWidth,
  required double minThickness,
  required double cornerClearance,
  required double fraction,
}) {
  const fallbackBoost = 80.0;
  final fallback = minThickness + fallbackBoost;
  if (bubbleWidth == null ||
      !bubbleWidth.isFinite ||
      bubbleWidth <= 0 ||
      bubbleWidth.isNaN) {
    return fallback;
  }
  final safeInset = (cornerClearance * 2);
  final safeWidth = bubbleWidth - safeInset;
  final fractionWidth = bubbleWidth * fraction;
  final limit = math.max(0.0, math.min(safeWidth, fractionWidth));
  if (limit <= 0) {
    return fallback;
  }
  return math.min(limit, bubbleWidth);
}

double _reactionAlignmentForBubble({
  required double? bubbleWidth,
  required double thickness,
  required bool isSelf,
  required double cornerClearance,
}) {
  const alignmentHint = 0.76;
  if (bubbleWidth == null ||
      !bubbleWidth.isFinite ||
      bubbleWidth <= 0 ||
      bubbleWidth.isNaN) {
    return isSelf ? -alignmentHint : alignmentHint;
  }
  final safeInset = cornerClearance;
  final halfThickness = thickness / 2;
  final minCenter = safeInset + halfThickness;
  final maxCenter = bubbleWidth - safeInset - halfThickness;
  if (maxCenter <= minCenter) {
    return 0;
  }
  final targetCenter = isSelf ? minCenter : maxCenter;
  final fraction = (targetCenter / bubbleWidth).clamp(0.0, 1.0);
  return (fraction * 2) - 1;
}

_CutoutPlacement _reactionCutoutPlacement({
  required double? bubbleWidth,
  required double requestedThickness,
  required bool isSelf,
  required double cornerClearance,
}) {
  if (bubbleWidth == null ||
      !bubbleWidth.isFinite ||
      bubbleWidth <= 0 ||
      bubbleWidth.isNaN) {
    final left = isSelf ? 0.0 : 0.0;
    return _CutoutPlacement(width: requestedThickness, left: left);
  }
  final alignment = _reactionAlignmentForBubble(
    bubbleWidth: bubbleWidth,
    thickness: requestedThickness,
    isSelf: isSelf,
    cornerClearance: cornerClearance,
  );
  final center = ((alignment + 1) / 2) * bubbleWidth;
  final maxLeft = math.max(0.0, bubbleWidth - requestedThickness);
  final left = (center - requestedThickness / 2).clamp(0.0, maxLeft);
  return _CutoutPlacement(width: requestedThickness, left: left);
}

double _blurSigma(double radius) => radius * 0.57735 + 0.5;

class _CutoutPlacement {
  const _CutoutPlacement({
    required this.width,
    required this.left,
  });

  final double width;
  final double left;
}
