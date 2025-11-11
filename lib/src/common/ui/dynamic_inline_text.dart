import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

typedef LinkTapCallback = void Function(String url);

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
  final List<TextSpan> details;
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
    required List<TextSpan> details,
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

  List<TextSpan> _details;

  set details(List<TextSpan> value) {
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
    final plainText = text.toPlainText();
    if (plainText.isEmpty) return Size.zero;
    assert(maxWidth > 0);

    _lineHeight = 0;
    _lineCount = 0;
    _maxLineWidth = 0;
    _finalLineWidth = 0;
    _detailsWidth = 0;
    _detailsHeight = 0;
    _canInlineDetails = false;

    _textPainter = TextPainter(
      text: text,
      textDirection: _textDirection,
      textScaler: _textScaler,
    );

    _textPainter.layout(maxWidth: maxWidth);
    final textLines = _textPainter.computeLineMetrics();

    _detailPainters = _details.map((e) {
      final painter = TextPainter(
        text: e,
        textDirection: _textDirection,
        textScaler: _textScaler,
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
