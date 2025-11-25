import 'dart:math';

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
  });

  final TextSpan text;
  final List<InlineSpan> details;
  final List<DynamicTextLink> links;
  final LinkTapCallback? onLinkTap;

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
      ..onLinkTap = onLinkTap;
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
  })  : _text = text,
        _details = details,
        _textDirection = textDirection,
        _textScaler = textScaler,
        _links = List.unmodifiable(links),
        _onLinkTap = onLinkTap;

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
    _links = List.unmodifiable(value);
  }

  LinkTapCallback? _onLinkTap;

  set onLinkTap(LinkTapCallback? value) {
    _onLinkTap = value;
  }

  @override
  bool hitTestSelf(Offset position) => _links.isNotEmpty && _onLinkTap != null;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (_links.isEmpty || _onLinkTap == null) return;
    if (event is! PointerUpEvent) return;
    if (_textPainter.text == null) return;
    if (entry.localPosition.dy < 0 ||
        entry.localPosition.dy > _textPainter.height) {
      return;
    }
    final textPosition = _textPainter.getPositionForOffset(
      entry.localPosition,
    );
    final offset = textPosition.offset;
    for (final link in _links) {
      if (offset >= link.range.start && offset < link.range.end) {
        _onLinkTap?.call(link.url);
        break;
      }
    }
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

  Size _layout(double maxWidth) {
    _debugAssertNoWidgetSpans();
    final plainText = text.toPlainText();
    if (plainText.isEmpty) return Size.zero;
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
      _detailsWidth = _detailStartGap;
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

    final messageSize = Size(_maxLineWidth, _textPainter.height);

    _finalLineWidth = textLines.last.width;

    final combinedWidth =
        _detailsWidth == 0 ? _finalLineWidth : _finalLineWidth + _detailsWidth;
    _canInlineDetails = _detailsWidth > 0 &&
        combinedWidth <
            (textLines.length == 1 ? maxWidth : min(_maxLineWidth, maxWidth));

    return _canInlineDetails
        ? Size(
            textLines.length == 1
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
    if (_textPainter.text?.toPlainText() == '') return;

    _textPainter.paint(context.canvas, offset);

    if (_detailPainters.isEmpty) return;

    final lastLine = _textLineMetrics.isNotEmpty ? _textLineMetrics.last : null;
    var dx = _canInlineDetails
        ? offset.dx + _finalLineWidth + _detailStartGap
        : offset.dx + size.width - _detailsWidth;
    for (var i = 0; i < _detailPainters.length; i++) {
      final painter = _detailPainters[i];
      final metrics =
          _detailLineMetrics.length > i ? _detailLineMetrics[i] : null;
      final detailBaseline =
          metrics?.baseline ?? painter.computeLineMetrics().first.baseline;
      final dy = _canInlineDetails && lastLine != null
          ? offset.dy + lastLine.baseline - detailBaseline
          : offset.dy + _textPainter.height;
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
