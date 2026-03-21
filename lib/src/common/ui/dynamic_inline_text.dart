// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:math';

import 'package:axichat/src/common/ui/squircle_border.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, mapEquals;
import 'package:flutter/gestures.dart'
    show TapGestureRecognizer, kLongPressTimeout, kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pixel_snap/pixel_snap.dart';

typedef LinkTapCallback = void Function(String url);

const double _detailStartGap = 8.0;
const double _detailSpacing = 6.0;

bool _usesPixelSnap(TargetPlatform platform) =>
    platform == TargetPlatform.linux || platform == TargetPlatform.windows;

double _identityPixelSnap(
  double value,
  double devicePixelRatio,
  PixelSnapMode mode,
) => value;

class DynamicInlineDetailAction {
  const DynamicInlineDetailAction({
    required this.onTap,
    required this.backgroundColor,
    required this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.minimumHeight = 0.0,
  });

  final VoidCallback onTap;
  final Color backgroundColor;
  final double borderRadius;
  final EdgeInsets padding;
  final double minimumHeight;
}

class DynamicTextLink {
  const DynamicTextLink({required this.range, required this.url});

  final TextRange range;
  final String url;
}

class DynamicInlineText extends LeafRenderObjectWidget {
  const DynamicInlineText({
    super.key,
    required this.text,
    required this.details,
    this.detailActions = const <int, DynamicInlineDetailAction>{},
    this.detailOpticalOffsetFactors = const <int, double>{},
    this.links = const [],
    this.onLinkTap,
    this.onLinkLongPress,
  });

  final TextSpan text;
  final List<InlineSpan> details;
  final Map<int, DynamicInlineDetailAction> detailActions;
  final Map<int, double> detailOpticalOffsetFactors;
  final List<DynamicTextLink> links;
  final LinkTapCallback? onLinkTap;
  final LinkTapCallback? onLinkLongPress;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      DynamicInlineTextRenderObject(
        text: text,
        details: details,
        detailActions: detailActions,
        detailOpticalOffsetFactors: detailOpticalOffsetFactors,
        textDirection: Directionality.of(context),
        textScaler:
            MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
        devicePixelRatio:
            MediaQuery.maybeDevicePixelRatioOf(context) ??
            View.of(context).devicePixelRatio,
        pixelSnapEnabled: _usesPixelSnap(Theme.of(context).platform),
        links: links,
        onLinkTap: onLinkTap,
        onLinkLongPress: onLinkLongPress,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    DynamicInlineTextRenderObject renderObject,
  ) {
    renderObject
      ..text = text
      ..details = details
      ..detailActions = detailActions
      ..detailOpticalOffsetFactors = detailOpticalOffsetFactors
      ..textDirection = Directionality.of(context)
      ..textScaler =
          MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling
      ..devicePixelRatio =
          MediaQuery.maybeDevicePixelRatioOf(context) ??
          View.of(context).devicePixelRatio
      ..pixelSnapEnabled = _usesPixelSnap(Theme.of(context).platform)
      ..links = links
      ..onLinkTap = onLinkTap
      ..onLinkLongPress = onLinkLongPress;
  }
}

class DynamicInlineTextRenderObject extends RenderBox {
  DynamicInlineTextRenderObject({
    required TextSpan text,
    required List<InlineSpan> details,
    required Map<int, DynamicInlineDetailAction> detailActions,
    required Map<int, double> detailOpticalOffsetFactors,
    required TextDirection textDirection,
    required TextScaler textScaler,
    required double devicePixelRatio,
    required bool pixelSnapEnabled,
    List<DynamicTextLink> links = const [],
    LinkTapCallback? onLinkTap,
    LinkTapCallback? onLinkLongPress,
  }) : _text = text,
       _details = details,
       _detailActions = Map.unmodifiable(detailActions),
       _detailOpticalOffsetFactors = Map.unmodifiable(
         detailOpticalOffsetFactors,
       ),
       _textDirection = textDirection,
       _textScaler = textScaler,
       _devicePixelRatio = devicePixelRatio,
       _pixelSnapEnabled = pixelSnapEnabled,
       _links = List.unmodifiable(links),
       _onLinkTap = onLinkTap,
       _onLinkLongPress = onLinkLongPress;

  TextSpan get text => _text;
  TextSpan _text;

  set text(TextSpan value) {
    if (value == _text) return;
    _text = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  List<InlineSpan> _details;
  Map<int, DynamicInlineDetailAction> _detailActions;

  set details(List<InlineSpan> value) {
    if (value == _details) return;
    _details = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  set detailActions(Map<int, DynamicInlineDetailAction> value) {
    if (mapEquals(_detailActions, value)) return;
    _detailActions = Map.unmodifiable(value);
    _cancelDetailTap();
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  Map<int, double> _detailOpticalOffsetFactors;

  set detailOpticalOffsetFactors(Map<int, double> value) {
    if (mapEquals(_detailOpticalOffsetFactors, value)) return;
    _detailOpticalOffsetFactors = Map.unmodifiable(value);
    markNeedsPaint();
  }

  TextDirection _textDirection;

  set textDirection(TextDirection value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    markNeedsSemanticsUpdate();
    markNeedsLayout();
  }

  TextScaler get textScaler => _textScaler;
  TextScaler _textScaler;

  set textScaler(TextScaler value) {
    if (value == _textScaler) {
      return;
    }
    _textScaler = value;
    markNeedsLayout();
  }

  double _devicePixelRatio;

  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) {
      return;
    }
    _devicePixelRatio = value;
    markNeedsLayout();
    markNeedsPaint();
  }

  bool _pixelSnapEnabled;

  set pixelSnapEnabled(bool value) {
    if (_pixelSnapEnabled == value) {
      return;
    }
    _pixelSnapEnabled = value;
    markNeedsLayout();
    markNeedsPaint();
  }

  List<DynamicTextLink> _links;

  set links(List<DynamicTextLink> value) {
    _cancelLinkLongPress();
    _linkLongPressTriggered = false;
    _links = List.unmodifiable(value);
  }

  LinkTapCallback? _onLinkTap;

  set onLinkTap(LinkTapCallback? value) {
    _onLinkTap = value;
  }

  LinkTapCallback? _onLinkLongPress;

  double get _detailRowVerticalOffset => 1.0;

  set onLinkLongPress(LinkTapCallback? value) {
    _onLinkLongPress = value;
    if (value == null) {
      _cancelLinkLongPress();
    }
  }

  late final TapGestureRecognizer _detailTapGestureRecognizer =
      TapGestureRecognizer(debugOwner: this)
        ..onTap = _handleDetailTap
        ..onTapCancel = _cancelDetailTap;

  @override
  bool hitTestSelf(Offset position) =>
      (_links.isNotEmpty && (_onLinkTap != null || _onLinkLongPress != null)) ||
      _detailActions.isNotEmpty;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (_detailActions.isNotEmpty) {
      if (event is PointerDownEvent) {
        final detailIndex = _detailActionIndexAtOffset(entry.localPosition);
        if (detailIndex != null) {
          _pressedDetailActionIndex = detailIndex;
          _detailTapPointer = event.pointer;
          _detailTapGestureRecognizer.addPointer(event);
          return;
        }
      }
      if (_detailTapPointer == event.pointer) {
        if (event is PointerCancelEvent) {
          _cancelDetailTap();
        }
        return;
      }
      if (event is PointerCancelEvent) {
        _cancelDetailTap();
      }
    }
    if (_links.isEmpty || _textPainter.text == null) return;
    if (event is PointerDownEvent) {
      _startLinkLongPress(entry.localPosition, event.pointer);
      return;
    }
    if (event is PointerMoveEvent) {
      _trackLinkLongPress(entry.localPosition, event.pointer);
      return;
    }
    if (event is PointerCancelEvent) {
      _linkLongPressTriggered = false;
      _cancelLinkLongPress();
      return;
    }
    if (event is! PointerUpEvent) return;
    final resolvedLink = _linkAtOffset(entry.localPosition);
    _cancelLinkLongPress();
    if (_linkLongPressTriggered) {
      _linkLongPressTriggered = false;
      return;
    }
    if (_onLinkTap == null || resolvedLink == null) return;
    _onLinkTap?.call(resolvedLink.url);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    _layout(double.infinity);
    return _maxLineWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) {
    final computedSize = _layout(width);
    return computedSize.height;
  }

  @override
  void performLayout() {
    final unconstrainedSize = _layout(constraints.maxWidth);
    size = constraints.constrain(
      Size(
        _snap(unconstrainedSize.width, PixelSnapMode.ceil),
        _snap(unconstrainedSize.height, PixelSnapMode.ceil),
      ),
    );
  }

  double _maxLineWidth = 0;
  double _finalLineWidth = 0;
  double _detailsWidth = 0;
  double _detailsHeight = 0;
  double _detailBaselineOffset = 0;
  double _detailBelowBaseline = 0;
  bool _canInlineDetails = false;
  List<LineMetrics> _textLineMetrics = const [];
  List<LineMetrics> _detailLineMetrics = const [];

  late TextPainter _textPainter;
  late List<TextPainter> _detailPainters;
  late List<double> _detailWidths;
  late List<double> _detailHeights;

  Timer? _linkLongPressTimer;
  Offset? _linkLongPressOrigin;
  int? _linkLongPressPointer;
  bool _linkLongPressTriggered = false;
  int? _detailTapPointer;
  int? _pressedDetailActionIndex;

  PixelSnap get _pixelSnap => _pixelSnapEnabled
      ? PixelSnap.custom(devicePixelRatio: _devicePixelRatio)
      : PixelSnap.custom(
          devicePixelRatio: _devicePixelRatio,
          pixelSnapFunction: _identityPixelSnap,
        );

  double _snap(double value, [PixelSnapMode mode = PixelSnapMode.snap]) =>
      value.pixelSnap(_pixelSnap, mode);

  Offset _snapOffset(Offset value, [PixelSnapMode mode = PixelSnapMode.snap]) =>
      value.pixelSnap(_pixelSnap, mode);

  bool _hasWidgetSpan(InlineSpan span) {
    var found = false;
    span.visitChildren((child) {
      if (child is WidgetSpan) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  void _debugAssertNoWidgetSpans() {
    assert(
      !_hasWidgetSpan(text) && _details.every((span) => !_hasWidgetSpan(span)),
      'DynamicInlineText does not support WidgetSpans. Use glyph-based spans instead.',
    );
  }

  DynamicTextLink? _linkAtOffset(Offset position) {
    if (position.dy < 0 || position.dy > _textPainter.height) {
      return null;
    }
    final textPosition = _textPainter.getPositionForOffset(position);
    final offset = textPosition.offset;
    for (final link in _links) {
      if (offset >= link.range.start && offset < link.range.end) {
        return link;
      }
    }
    return null;
  }

  void _startLinkLongPress(Offset position, int pointer) {
    if (_onLinkLongPress == null) return;
    final target = _linkAtOffset(position);
    if (target == null) return;
    _cancelLinkLongPress();
    _linkLongPressOrigin = position;
    _linkLongPressPointer = pointer;
    _linkLongPressTriggered = false;
    _linkLongPressTimer = Timer(kLongPressTimeout, () {
      _linkLongPressTriggered = true;
      _onLinkLongPress?.call(target.url);
    });
  }

  void _trackLinkLongPress(Offset position, int pointer) {
    if (_linkLongPressPointer != pointer || _linkLongPressOrigin == null) {
      return;
    }
    final origin = _linkLongPressOrigin!;
    if ((position - origin).distance > kTouchSlop) {
      _cancelLinkLongPress();
    }
  }

  void _cancelLinkLongPress() {
    _linkLongPressTimer?.cancel();
    _linkLongPressTimer = null;
    _linkLongPressOrigin = null;
    _linkLongPressPointer = null;
  }

  void _cancelDetailTap() {
    _detailTapPointer = null;
    _pressedDetailActionIndex = null;
  }

  void _handleDetailTap() {
    final pressedDetailActionIndex = _pressedDetailActionIndex;
    final callback = pressedDetailActionIndex == null
        ? null
        : _detailActions[pressedDetailActionIndex]?.onTap;
    _cancelDetailTap();
    callback?.call();
  }

  @override
  void detach() {
    _cancelLinkLongPress();
    _cancelDetailTap();
    super.detach();
  }

  @override
  void dispose() {
    _detailTapGestureRecognizer.dispose();
    super.dispose();
  }

  Size _layout(double maxWidth) {
    _debugAssertNoWidgetSpans();
    final plainText = text.toPlainText();
    final hasBodyText = plainText.isNotEmpty;
    assert(maxWidth > 0);

    _maxLineWidth = 0;
    _finalLineWidth = 0;
    _detailsWidth = 0;
    _detailsHeight = 0;
    _detailBaselineOffset = 0;
    _detailBelowBaseline = 0;
    _canInlineDetails = false;
    _textLineMetrics = const [];
    _detailLineMetrics = const [];
    _detailWidths = const [];
    _detailHeights = const [];

    _textPainter = TextPainter(
      text: text,
      textDirection: _textDirection,
      textScaler: _textScaler,
    );

    _textPainter.layout(maxWidth: maxWidth);
    final textLines = _textPainter.computeLineMetrics();
    _textLineMetrics = textLines;

    _detailPainters = [];
    _detailLineMetrics = [];
    _detailWidths = [];
    _detailHeights = [];
    if (_details.isNotEmpty) {
      _detailsWidth = hasBodyText ? _snap(_detailStartGap) : 0.0;
    }

    for (var index = 0; index < _details.length; index++) {
      final painter = TextPainter(
        text: _details[index],
        textDirection: _textDirection,
        textScaler: _textScaler,
      );
      painter.layout(maxWidth: maxWidth);
      final lineMetrics = painter.computeLineMetrics();
      if (lineMetrics.isNotEmpty) {
        final metrics = lineMetrics.first;
        final action = _detailActions[index];
        final detailWidth = _snap(
          metrics.width + (action?.padding.horizontal ?? 0),
          PixelSnapMode.ceil,
        );
        final detailHeight = _snap(
          max(
            metrics.height + (action?.padding.vertical ?? 0),
            action?.minimumHeight ?? 0,
          ),
          PixelSnapMode.ceil,
        );
        final verticalInset = _snap((detailHeight - metrics.height) / 2);
        final detailBaselineOffset = _snap(verticalInset + metrics.baseline);
        final detailBelowBaseline = _snap(
          verticalInset + (metrics.height - metrics.baseline),
        );
        _detailsWidth += detailWidth;
        _detailBaselineOffset = max(
          _detailBaselineOffset,
          detailBaselineOffset,
        );
        _detailBelowBaseline = max(_detailBelowBaseline, detailBelowBaseline);
        _detailLineMetrics.add(metrics);
        _detailWidths.add(detailWidth);
        _detailHeights.add(detailHeight);
      } else {
        _detailWidths.add(0);
        _detailHeights.add(0);
      }
      _detailPainters.add(painter);
      final hasTrailingDetail = index < _details.length - 1;
      if (hasTrailingDetail) {
        _detailsWidth += _snap(_detailSpacing);
      }
    }
    _detailsHeight = _snap(
      _detailBaselineOffset + _detailBelowBaseline,
      PixelSnapMode.ceil,
    );

    _maxLineWidth = _snap(
      max(textLines.fold(0, (prev, e) => max(prev, e.width)), _detailsWidth),
      PixelSnapMode.ceil,
    );

    final messageSize = Size(
      _maxLineWidth,
      hasBodyText ? _textPainter.height : 0.0,
    );

    _finalLineWidth = textLines.isEmpty
        ? 0.0
        : _snap(textLines.last.width, PixelSnapMode.ceil);

    final combinedWidth = _detailsWidth == 0
        ? _finalLineWidth
        : _finalLineWidth + _detailsWidth;
    _canInlineDetails =
        hasBodyText &&
        _detailsWidth > 0 &&
        combinedWidth <
            (textLines.length <= 1 ? maxWidth : min(_maxLineWidth, maxWidth));

    if (!hasBodyText && _detailPainters.isEmpty) {
      return Size.zero;
    }

    return _canInlineDetails
        ? Size(
            _snap(
              textLines.length <= 1
                  ? combinedWidth
                  : max(_maxLineWidth, combinedWidth),
              PixelSnapMode.ceil,
            ),
            _snap(messageSize.height, PixelSnapMode.ceil),
          )
        : Size(
            _snap(messageSize.width, PixelSnapMode.ceil),
            _snap(messageSize.height + _detailsHeight, PixelSnapMode.ceil),
          );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final hasBodyText = _textPainter.text?.toPlainText().isNotEmpty == true;
    final double baseTextHeight = hasBodyText ? _textPainter.height : 0.0;
    if (hasBodyText) {
      _textPainter.paint(context.canvas, offset);
    }

    if (_detailPainters.isEmpty) return;

    final lastLine = _textLineMetrics.isNotEmpty ? _textLineMetrics.last : null;
    final detailStartGap = hasBodyText ? _snap(_detailStartGap) : 0.0;
    final detailBaselineY = _canInlineDetails && lastLine != null
        ? _snap(offset.dy + lastLine.baseline)
        : _snap(offset.dy + baseTextHeight + _detailBaselineOffset);
    var dx = _canInlineDetails
        ? _snap(offset.dx + _finalLineWidth + detailStartGap)
        : _snap(offset.dx + size.width - _detailsWidth);
    for (var i = 0; i < _detailPainters.length; i++) {
      final painter = _detailPainters[i];
      final metrics = _detailLineMetrics.length > i
          ? _detailLineMetrics[i]
          : null;
      final detailBaseline =
          metrics?.baseline ?? painter.computeLineMetrics().first.baseline;
      final action = _detailActions[i];
      final horizontalPadding = action?.padding.horizontal ?? 0.0;
      final detailWidth = _detailWidths.length > i
          ? _detailWidths[i]
          : painter.width;
      final detailHeight = _detailHeights.length > i
          ? _detailHeights[i]
          : metrics?.height ?? painter.height;
      final textHeight = metrics?.height ?? painter.height;
      final verticalInset = (detailHeight - textHeight) / 2;
      final opticalOffset =
          textHeight * (_detailOpticalOffsetFactors[i] ?? 0.0);
      final textTop = _snap(
        detailBaselineY -
            detailBaseline +
            opticalOffset +
            _detailRowVerticalOffset,
      );
      final backgroundTop = _snap(textTop - verticalInset);
      if (action != null) {
        final backgroundRect = Rect.fromLTWH(
          dx,
          backgroundTop,
          detailWidth,
          detailHeight,
        ).pixelSnap(_pixelSnap);
        context.canvas.drawPath(
          SquircleBorder(
            cornerRadius: action.borderRadius,
          ).getOuterPath(backgroundRect),
          Paint()
            ..color = action.backgroundColor
            ..isAntiAlias = true,
        );
      }
      painter.paint(
        context.canvas,
        _snapOffset(Offset(dx + (horizontalPadding / 2), textTop)),
      );
      dx += detailWidth;
      final hasTrailingDetail = i < _detailPainters.length - 1;
      if (hasTrailingDetail) {
        dx += _snap(_detailSpacing);
      }
    }
  }

  int? _detailActionIndexAtOffset(Offset position) {
    if (_detailActions.isEmpty || _detailPainters.isEmpty) {
      return null;
    }
    final hasBodyText = _textPainter.text?.toPlainText().isNotEmpty == true;
    final baseTextHeight = hasBodyText ? _textPainter.height : 0.0;
    final lastLine = _textLineMetrics.isNotEmpty ? _textLineMetrics.last : null;
    final detailStartGap = hasBodyText ? _snap(_detailStartGap) : 0.0;
    final detailBaselineY = _canInlineDetails && lastLine != null
        ? _snap(lastLine.baseline)
        : _snap(baseTextHeight + _detailBaselineOffset);
    var dx = _canInlineDetails
        ? _snap(_finalLineWidth + detailStartGap)
        : _snap(size.width - _detailsWidth);
    for (var i = 0; i < _detailPainters.length; i++) {
      final action = _detailActions[i];
      final painter = _detailPainters[i];
      final metrics = _detailLineMetrics.length > i
          ? _detailLineMetrics[i]
          : null;
      final detailWidth = _detailWidths.length > i
          ? _detailWidths[i]
          : painter.width;
      final detailHeight = _detailHeights.length > i
          ? _detailHeights[i]
          : metrics?.height ?? painter.height;
      if (action != null) {
        final detailBaseline =
            metrics?.baseline ?? painter.computeLineMetrics().first.baseline;
        final textHeight = metrics?.height ?? painter.height;
        final verticalInset = (detailHeight - textHeight) / 2;
        final opticalOffset =
            textHeight * (_detailOpticalOffsetFactors[i] ?? 0.0);
        final textTop = _snap(
          detailBaselineY -
              detailBaseline +
              opticalOffset +
              _detailRowVerticalOffset,
        );
        final backgroundTop = _snap(textTop - verticalInset);
        final rect = Rect.fromLTWH(
          dx,
          backgroundTop,
          detailWidth,
          detailHeight,
        ).pixelSnap(_pixelSnap);
        if (rect.contains(position)) {
          return i;
        }
      }
      dx += detailWidth;
      if (i < _detailPainters.length - 1) {
        dx += _snap(_detailSpacing);
      }
    }
    return null;
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);

    config
      ..label = '${_text.text}'
      ..textDirection = _textDirection
      ..isButton = true;
  }
}
