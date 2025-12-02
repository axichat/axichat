import 'dart:math' as math;

import 'package:axichat/src/common/ui/squircle_border.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Slots managed by [ChatBubbleSurface].
enum _ChatBubbleSlot {
  body,
  reaction,
  recipients,
  avatar,
  selection,
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
    this.cornerClearance,
    this.alignment,
  });

  final double depth;
  final double cornerRadius;
  final EdgeInsets padding;
  final Offset offset;
  final double minThickness;
  final double? cornerClearance;
  final double? alignment;
}

enum _CutoutAnchor { top, bottom, left, right }

enum _CutoutType { reaction, recipient, avatar, selection }

enum ChatBubbleCutoutAnchor { top, bottom, left, right }

_CutoutAnchor _toInternalAnchor(ChatBubbleCutoutAnchor anchor) =>
    switch (anchor) {
      ChatBubbleCutoutAnchor.top => _CutoutAnchor.top,
      ChatBubbleCutoutAnchor.bottom => _CutoutAnchor.bottom,
      ChatBubbleCutoutAnchor.left => _CutoutAnchor.left,
      ChatBubbleCutoutAnchor.right => _CutoutAnchor.right,
    };

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
    this.selectionOverlay,
    this.selectionStyle,
    this.selectionFollowsSelfEdge = true,
    this.recipientAnchor = ChatBubbleCutoutAnchor.bottom,
    this.avatarOverlay,
    this.avatarStyle,
    this.avatarAnchor = ChatBubbleCutoutAnchor.left,
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
            if (avatarOverlay != null)
              _ChatBubbleSlotWidget(
                slot: _ChatBubbleSlot.avatar,
                child: avatarOverlay,
              ),
            if (selectionOverlay != null)
              _ChatBubbleSlotWidget(
                slot: _ChatBubbleSlot.selection,
                child: selectionOverlay,
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
  final Widget? selectionOverlay;
  final CutoutStyle? selectionStyle;
  final bool selectionFollowsSelfEdge;
  final ChatBubbleCutoutAnchor recipientAnchor;
  final Widget? avatarOverlay;
  final CutoutStyle? avatarStyle;
  final ChatBubbleCutoutAnchor avatarAnchor;

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
        selectionStyle: selectionStyle,
        selectionFollowsSelfEdge: selectionFollowsSelfEdge,
        recipientAnchor: recipientAnchor,
        avatarStyle: avatarStyle,
        avatarAnchor: avatarAnchor,
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
      ..recipientStyle = recipientStyle
      ..selectionStyle = selectionStyle
      ..selectionFollowsSelfEdge = selectionFollowsSelfEdge
      ..recipientAnchor = recipientAnchor
      ..avatarStyle = avatarStyle
      ..avatarAnchor = avatarAnchor;
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
    CutoutStyle? selectionStyle,
    bool selectionFollowsSelfEdge = true,
    ChatBubbleCutoutAnchor recipientAnchor = ChatBubbleCutoutAnchor.bottom,
    CutoutStyle? avatarStyle,
    ChatBubbleCutoutAnchor avatarAnchor = ChatBubbleCutoutAnchor.left,
  })  : _isSelf = isSelf,
        _backgroundColor = backgroundColor,
        _borderColor = borderColor,
        _borderRadius = borderRadius,
        _shadowOpacity = shadowOpacity,
        _shadows = shadows,
        _bubbleWidthFraction = bubbleWidthFraction,
        _cornerClearance = cornerClearance,
        _reactionStyle = reactionStyle,
        _recipientStyle = recipientStyle,
        _selectionStyle = selectionStyle,
        _selectionFollowsSelfEdge = selectionFollowsSelfEdge,
        _recipientAnchor = _toInternalAnchor(recipientAnchor),
        _avatarStyle = avatarStyle,
        _avatarAnchor = _toInternalAnchor(avatarAnchor);

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

  CutoutStyle? _selectionStyle;
  CutoutStyle? get selectionStyle => _selectionStyle;
  set selectionStyle(CutoutStyle? value) {
    if (_selectionStyle == value) return;
    _selectionStyle = value;
    markNeedsLayout();
    markNeedsPaint();
  }

  CutoutStyle? _avatarStyle;
  CutoutStyle? get avatarStyle => _avatarStyle;
  set avatarStyle(CutoutStyle? value) {
    if (_avatarStyle == value) return;
    _avatarStyle = value;
    markNeedsLayout();
    markNeedsPaint();
  }

  bool _selectionFollowsSelfEdge;
  bool get selectionFollowsSelfEdge => _selectionFollowsSelfEdge;
  set selectionFollowsSelfEdge(bool value) {
    if (value == _selectionFollowsSelfEdge) return;
    _selectionFollowsSelfEdge = value;
    markNeedsLayout();
  }

  _CutoutAnchor _recipientAnchor;
  set recipientAnchor(ChatBubbleCutoutAnchor value) {
    final anchor = _toInternalAnchor(value);
    if (anchor == _recipientAnchor) return;
    _recipientAnchor = anchor;
    markNeedsLayout();
  }

  _CutoutAnchor _avatarAnchor;
  set avatarAnchor(ChatBubbleCutoutAnchor value) {
    final anchor = _toInternalAnchor(value);
    if (anchor == _avatarAnchor) return;
    _avatarAnchor = anchor;
    markNeedsLayout();
  }

  RenderBox? get _bodyChild => _childForSlot(_ChatBubbleSlot.body);
  RenderBox? get _reactionChild => _childForSlot(_ChatBubbleSlot.reaction);
  RenderBox? get _recipientChild => _childForSlot(_ChatBubbleSlot.recipients);
  RenderBox? get _avatarChild => _childForSlot(_ChatBubbleSlot.avatar);
  RenderBox? get _selectionChild => _childForSlot(_ChatBubbleSlot.selection);

  Rect? _reactionCutoutRect;
  Rect? _recipientCutoutRect;
  Rect? _avatarCutoutRect;
  Rect? _selectionCutoutRect;

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
    _avatarCutoutRect = null;
    _selectionCutoutRect = null;

    _layoutCutoutChild(
      child: _reactionChild,
      style: reactionStyle,
      type: _CutoutType.reaction,
      anchor: _CutoutAnchor.bottom,
    );
    _layoutCutoutChild(
      child: _recipientChild,
      style: recipientStyle,
      type: _CutoutType.recipient,
      anchor: _recipientAnchor,
    );
    _layoutCutoutChild(
      child: _avatarChild,
      style: avatarStyle,
      type: _CutoutType.avatar,
      anchor: _avatarAnchor,
    );
    final selectionAnchor = selectionFollowsSelfEdge
        ? (isSelf ? _CutoutAnchor.right : _CutoutAnchor.left)
        : (isSelf ? _CutoutAnchor.left : _CutoutAnchor.right);
    _layoutCutoutChild(
      child: _selectionChild,
      style: selectionStyle,
      type: _CutoutType.selection,
      anchor: selectionAnchor,
    );
  }

  void _layoutCutoutChild({
    required RenderBox? child,
    required CutoutStyle? style,
    required _CutoutType type,
    required _CutoutAnchor anchor,
  }) {
    if (child == null) return;
    if (style == null) {
      child.layout(BoxConstraints.tight(Size.zero), parentUsesSize: true);
      final childParentData = child.parentData as _ChatBubbleParentData;
      childParentData.offset = Offset.zero;
      return;
    }
    final styleCornerClearance = style.cornerClearance ?? cornerClearance;
    final horizontalAnchor =
        anchor == _CutoutAnchor.top || anchor == _CutoutAnchor.bottom;
    if (type == _CutoutType.avatar && anchor == _CutoutAnchor.left) {
      // Avatar: carve a quarter cutout at the top-left corner and center the
      // avatar over the bubble origin.
      final avatarSize = math.max(style.minThickness, style.depth * 2);
      child.layout(
        BoxConstraints.tight(Size.square(avatarSize)),
        parentUsesSize: true,
      );
      final cutoutRadius = math.max(style.depth, style.cornerRadius);
      final rect = Rect.fromCircle(
        center: Offset.zero,
        radius: cutoutRadius,
      );
      final childParentData = child.parentData as _ChatBubbleParentData;
      childParentData.offset = Offset(
        -child.size.width / 2 + style.offset.dx,
        -child.size.height / 2 + style.offset.dy,
      );
      _avatarCutoutRect = rect;
      return;
    }
    final bubbleExtent = horizontalAnchor ? size.width : size.height;
    var maxThickness = _resolveCutoutLimit(
      bubbleExtent: bubbleExtent,
      minThickness: style.minThickness,
      cornerClearance: styleCornerClearance,
      fraction: horizontalAnchor ? bubbleWidthFraction : 1.0,
    );
    maxThickness = math.max(maxThickness, style.minThickness);
    final paddingExtent =
        horizontalAnchor ? style.padding.horizontal : style.padding.vertical;
    final maxContentExtent = math.max(0.0, maxThickness - paddingExtent);
    final unboundedSelection =
        type == _CutoutType.selection && !horizontalAnchor;
    final childConstraints = horizontalAnchor
        ? BoxConstraints(
            minWidth: 0,
            maxWidth: unboundedSelection ? double.infinity : maxContentExtent,
          )
        : BoxConstraints(
            minHeight: 0,
            maxHeight: unboundedSelection ? double.infinity : maxContentExtent,
          );
    if (!unboundedSelection && maxContentExtent <= 0) {
      child.layout(BoxConstraints.tight(Size.zero), parentUsesSize: true);
      final childParentData = child.parentData as _ChatBubbleParentData;
      childParentData.offset = Offset.zero;
      return;
    }
    child.layout(childConstraints, parentUsesSize: true);
    final childSize = child.size;
    final childExtent = horizontalAnchor ? childSize.width : childSize.height;
    if (childExtent <= 0) {
      final childParentData = child.parentData as _ChatBubbleParentData;
      childParentData.offset = Offset.zero;
      return;
    }

    final desiredThickness = childExtent + paddingExtent;
    final resolvedThickness = math.min(
      math.max(style.minThickness, desiredThickness),
      maxThickness,
    );

    final depth = style.depth;
    final intrude = depth * 2;

    double rectLeft;
    double rectTop;
    double rectWidth;
    double rectHeight;

    if (horizontalAnchor) {
      rectLeft = _horizontalCutoutLeft(
        bubbleWidth: size.width,
        requestedThickness: resolvedThickness,
        isSelf: isSelf,
        cornerClearance: styleCornerClearance,
        alignment: style.alignment,
      );
      rectWidth = resolvedThickness;
      rectHeight = intrude;
      rectTop = anchor == _CutoutAnchor.top ? -depth : size.height - depth;
    } else {
      rectTop = _verticalCutoutTop(
        bubbleHeight: size.height,
        requestedThickness: resolvedThickness,
        cornerClearance: styleCornerClearance,
        alignment: style.alignment,
      );
      rectHeight = resolvedThickness;
      rectWidth = intrude;
      rectLeft = anchor == _CutoutAnchor.left ? -depth : size.width - depth;
    }

    final rect = Rect.fromLTWH(rectLeft, rectTop, rectWidth, rectHeight);

    final childParentData = child.parentData as _ChatBubbleParentData;
    childParentData.offset = Offset(
      rect.left + style.padding.left + style.offset.dx,
      rect.top + style.padding.top + style.offset.dy,
    );

    switch (type) {
      case _CutoutType.reaction:
        _reactionCutoutRect = rect;
        break;
      case _CutoutType.recipient:
        _recipientCutoutRect = rect;
        break;
      case _CutoutType.avatar:
        _avatarCutoutRect = rect;
        break;
      case _CutoutType.selection:
        _selectionCutoutRect = rect;
        break;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final localPath = _bubblePath(
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
        if (_avatarCutoutRect != null)
          _CutoutDescriptor(
            rect: _avatarCutoutRect!,
            cornerRadius: avatarStyle?.cornerRadius ?? 16,
            shape: _CutoutShape.oval,
          ),
        if (_selectionCutoutRect != null)
          _CutoutDescriptor(
            rect: _selectionCutoutRect!,
            cornerRadius: selectionStyle?.cornerRadius ?? 16,
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
    this.shape = _CutoutShape.squircle,
  });

  final Rect rect;
  final double cornerRadius;
  final _CutoutShape shape;
}

enum _CutoutShape { squircle, oval }

Path _bubblePath(
  Size size,
  BorderRadius borderRadius,
  List<_CutoutDescriptor> cutouts,
) {
  final rect = Offset.zero & size;
  final shape = ContinuousRectangleBorder(borderRadius: borderRadius);
  var path = Path()..addPath(shape.getOuterPath(rect), Offset.zero);
  for (final cutout in cutouts) {
    final cutoutPath = switch (cutout.shape) {
      _CutoutShape.squircle => SquircleBorder(
          cornerRadius: cutout.cornerRadius,
        ).getOuterPath(cutout.rect),
      _CutoutShape.oval => Path()..addOval(cutout.rect),
    };
    path = Path.combine(
      PathOperation.difference,
      path,
      cutoutPath,
    );
  }
  return path;
}

double _resolveCutoutLimit({
  required double? bubbleExtent,
  required double minThickness,
  required double cornerClearance,
  required double fraction,
}) {
  const fallbackBoost = 80.0;
  final fallback = minThickness + fallbackBoost;
  if (bubbleExtent == null ||
      !bubbleExtent.isFinite ||
      bubbleExtent <= 0 ||
      bubbleExtent.isNaN) {
    return fallback;
  }
  final safeInset = (cornerClearance * 2);
  final safeExtent = bubbleExtent - safeInset;
  final fractionExtent = bubbleExtent * fraction;
  final limit = math.max(0.0, math.min(safeExtent, fractionExtent));
  if (limit <= 0) {
    return fallback;
  }
  return math.min(limit, bubbleExtent);
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

double _horizontalCutoutLeft({
  required double? bubbleWidth,
  required double requestedThickness,
  required bool isSelf,
  required double cornerClearance,
  double? alignment,
}) {
  if (bubbleWidth == null ||
      !bubbleWidth.isFinite ||
      bubbleWidth <= 0 ||
      bubbleWidth.isNaN) {
    return 0.0;
  }
  final resolvedAlignment = (alignment ??
          _reactionAlignmentForBubble(
            bubbleWidth: bubbleWidth,
            thickness: requestedThickness,
            isSelf: isSelf,
            cornerClearance: cornerClearance,
          ))
      .clamp(-1.0, 1.0);
  final center = ((resolvedAlignment + 1) / 2) * bubbleWidth;
  final maxLeft = math.max(0.0, bubbleWidth - requestedThickness);
  return (center - requestedThickness / 2).clamp(0.0, maxLeft);
}

double _verticalCutoutTop({
  required double? bubbleHeight,
  required double requestedThickness,
  required double cornerClearance,
  double? alignment,
}) {
  if (bubbleHeight == null ||
      !bubbleHeight.isFinite ||
      bubbleHeight <= 0 ||
      bubbleHeight.isNaN) {
    return 0.0;
  }
  final safeInset = cornerClearance;
  final minTop = safeInset;
  final maxTop =
      math.max(minTop, bubbleHeight - safeInset - requestedThickness);
  final centerTop = (bubbleHeight - requestedThickness) / 2;
  if (maxTop <= minTop) {
    return centerTop.clamp(
        0.0, math.max(0.0, bubbleHeight - requestedThickness));
  }
  final resolvedAlignment = ((alignment ?? 0).clamp(-1.0, 1.0) + 1) / 2;
  final available = maxTop - minTop;
  return (minTop + available * resolvedAlignment)
      .clamp(minTop, maxTop)
      .clamp(0.0, math.max(0.0, bubbleHeight - requestedThickness));
}

double _blurSigma(double radius) => radius * 0.57735 + 0.5;
