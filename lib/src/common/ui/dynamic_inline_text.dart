// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart' show kLongPressTimeout, kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

typedef LinkTapCallback = void Function(String url);

const double _detailStartGap = 8.0;
const double _detailSpacing = 6.0;

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
    this.links = const [],
    this.onLinkTap,
    this.onLinkLongPress,
  });

  final TextSpan text;
  final List<InlineSpan> details;
  final List<DynamicTextLink> links;
  final LinkTapCallback? onLinkTap;
  final LinkTapCallback? onLinkLongPress;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      DynamicInlineTextRenderObject(
        text: text,
        details: details,
        textDirection: Directionality.of(context),
        textScaler:
            MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
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
      ..textDirection = Directionality.of(context)
      ..textScaler =
          MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling
      ..links = links
      ..onLinkTap = onLinkTap
      ..onLinkLongPress = onLinkLongPress;
  }
}

class DynamicInlineTextRenderObject extends RenderBox {
  DynamicInlineTextRenderObject({
    required TextSpan text,
    required List<InlineSpan> details,
    required TextDirection textDirection,
    required TextScaler textScaler,
    List<DynamicTextLink> links = const [],
    LinkTapCallback? onLinkTap,
    LinkTapCallback? onLinkLongPress,
  })  : _text = text,
        _details = details,
        _textDirection = textDirection,
        _textScaler = textScaler,
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

  set details(List<InlineSpan> value) {
    if (value == _details) return;
    _details = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
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

  set onLinkLongPress(LinkTapCallback? value) {
    _onLinkLongPress = value;
    if (value == null) {
      _cancelLinkLongPress();
    }
  }

  @override
  bool hitTestSelf(Offset position) =>
      _links.isNotEmpty && (_onLinkTap != null || _onLinkLongPress != null);

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
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
      Size(unconstrainedSize.width, unconstrainedSize.height),
    );
  }

  double _maxLineWidth = 0;
  double _finalLineWidth = 0;
  double _detailsWidth = 0;
  double _detailsHeight = 0;
  bool _canInlineDetails = false;
  List<LineMetrics> _textLineMetrics = const [];
  List<LineMetrics> _detailLineMetrics = const [];

  late TextPainter _textPainter;
  late List<TextPainter> _detailPainters;

  Timer? _linkLongPressTimer;
  Offset? _linkLongPressOrigin;
  int? _linkLongPressPointer;
  bool _linkLongPressTriggered = false;

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

  @override
  void detach() {
    _cancelLinkLongPress();
    super.detach();
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
    _canInlineDetails = false;
    _textLineMetrics = const [];
    _detailLineMetrics = const [];

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
    if (_details.isNotEmpty) {
      _detailsWidth = hasBodyText ? _detailStartGap : 0.0;
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
        _detailsWidth += metrics.width;
        _detailsHeight = max(_detailsHeight, metrics.height);
        _detailLineMetrics.add(metrics);
      }
      _detailPainters.add(painter);
      final hasTrailingDetail = index < _details.length - 1;
      if (hasTrailingDetail) {
        _detailsWidth += _detailSpacing;
      }
    }

    _maxLineWidth = max(
      textLines.fold(0, (prev, e) => max(prev, e.width)),
      _detailsWidth,
    );

    final messageSize =
        Size(_maxLineWidth, hasBodyText ? _textPainter.height : 0.0);

    _finalLineWidth = textLines.isEmpty ? 0.0 : textLines.last.width;

    final combinedWidth =
        _detailsWidth == 0 ? _finalLineWidth : _finalLineWidth + _detailsWidth;
    _canInlineDetails = hasBodyText &&
        _detailsWidth > 0 &&
        combinedWidth <
            (textLines.length <= 1 ? maxWidth : min(_maxLineWidth, maxWidth));

    if (!hasBodyText && _detailPainters.isEmpty) {
      return Size.zero;
    }

    return _canInlineDetails
        ? Size(
            textLines.length <= 1
                ? combinedWidth
                : max(_maxLineWidth, combinedWidth),
            messageSize.height,
          )
        : Size(
            messageSize.width,
            messageSize.height + _detailsHeight,
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
    final detailStartGap = hasBodyText ? _detailStartGap : 0.0;
    var dx = _canInlineDetails
        ? offset.dx + _finalLineWidth + detailStartGap
        : offset.dx + size.width - _detailsWidth;
    for (var i = 0; i < _detailPainters.length; i++) {
      final painter = _detailPainters[i];
      final metrics =
          _detailLineMetrics.length > i ? _detailLineMetrics[i] : null;
      final detailBaseline =
          metrics?.baseline ?? painter.computeLineMetrics().first.baseline;
      final dy = _canInlineDetails && lastLine != null
          ? offset.dy + lastLine.baseline - detailBaseline
          : offset.dy + baseTextHeight;
      painter.paint(context.canvas, Offset(dx, dy));
      dx += painter.width;
      final hasTrailingDetail = i < _detailPainters.length - 1;
      if (hasTrailingDetail) {
        dx += _detailSpacing;
      }
    }
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
