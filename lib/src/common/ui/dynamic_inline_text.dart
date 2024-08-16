import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class DynamicInlineText extends LeafRenderObjectWidget {
  const DynamicInlineText({
    super.key,
    required this.text,
    required this.details,
  });

  final TextSpan text;
  final List<TextSpan> details;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      DynamicInlineTextRenderObject(
        text: text,
        details: details,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    DynamicInlineTextRenderObject renderObject,
  ) {
    renderObject
      ..text = text
      ..details = details
      ..textDirection = Directionality.of(context);
  }
}

class DynamicInlineTextRenderObject extends RenderBox {
  DynamicInlineTextRenderObject({
    required TextSpan text,
    required List<TextSpan> details,
    required TextDirection textDirection,
  })  : _text = text,
        _details = details,
        _textDirection = textDirection;

  TextSpan get text => _text;
  TextSpan _text;
  set text(TextSpan val) {
    if (val == _text) return;
    _text = val;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  List<TextSpan> _details;
  set details(List<TextSpan> val) {
    if (val == _details) return;
    _details = val;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection val) {
    if (_textDirection == val) {
      return;
    }
    _textDirection = val;
    markNeedsSemanticsUpdate();
    markNeedsLayout();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) => true;

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

  double _lineHeight = 0;
  int _lineCount = 0;
  double _maxLineWidth = 0;
  double _finalLineWidth = 0;
  double _detailsWidth = 0;
  double _detailsHeight = 0;
  bool _canInlineDetails = false;

  late TextPainter _textPainter;
  late List<TextPainter> _detailPainters;

  final int detailSpacing = 2;

  Size _layout(double maxWidth) {
    if (text.text == null || text.text!.isEmpty) return Size.zero;
    assert(maxWidth > 0);

    _textPainter = TextPainter(
      text: text,
      textDirection: _textDirection,
    );

    _textPainter.layout(maxWidth: maxWidth);
    final textLines = _textPainter.computeLineMetrics();

    _detailPainters = _details.map((e) {
      final painter = TextPainter(
        text: e,
        textDirection: _textDirection,
      );
      painter.layout(maxWidth: maxWidth);
      _detailsWidth += painter.computeLineMetrics().first.width + detailSpacing;
      _detailsHeight = max(_detailsHeight, painter.height);
      return painter;
    }).toList();

    _maxLineWidth = max(
      textLines.fold(0, (prev, e) => max(prev, e.width)),
      _detailsWidth,
    );

    final messageSize = Size(_maxLineWidth, _textPainter.height);

    _finalLineWidth = textLines.last.width;
    _lineHeight = textLines.last.height;
    _lineCount = textLines.length;

    final combinedWidth = _finalLineWidth + _detailsWidth * 1.08;
    _canInlineDetails = combinedWidth <
        (textLines.length == 1 ? maxWidth : min(_maxLineWidth, maxWidth));

    return _canInlineDetails
        ? Size(
            textLines.length == 1 ? combinedWidth : _maxLineWidth,
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

    var dx = offset.dx + size.width - _detailsWidth;
    var dy =
        offset.dy + _lineHeight * (_lineCount - (_canInlineDetails ? 1 : 0));

    for (final painter in _detailPainters) {
      painter.paint(context.canvas, Offset(dx, dy));
      dx += painter.width + detailSpacing;
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
