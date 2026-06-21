// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math';
import 'dart:ui' as ui;

import 'package:axichat/src/common/ui/squircle_border.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier, mapEquals;
import 'package:flutter/gestures.dart'
    show LongPressGestureRecognizer, TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show ParagraphBoundary;

typedef LinkTapCallback = void Function(String url);

const double _detailStartGap = 8.0;
const double _detailSpacing = 6.0;

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
        selectionRegistrar: SelectionContainer.maybeOf(context),
        selectionColor: DefaultSelectionStyle.of(context).selectionColor,
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
      ..registrar = SelectionContainer.maybeOf(context)
      ..selectionColor = DefaultSelectionStyle.of(context).selectionColor
      ..links = links
      ..onLinkTap = onLinkTap
      ..onLinkLongPress = onLinkLongPress;
  }
}

class DynamicInlineTextRenderObject extends RenderBox
    with ChangeNotifier, Selectable, SelectionRegistrant {
  DynamicInlineTextRenderObject({
    required TextSpan text,
    required List<InlineSpan> details,
    required Map<int, DynamicInlineDetailAction> detailActions,
    required Map<int, double> detailOpticalOffsetFactors,
    required TextDirection textDirection,
    required TextScaler textScaler,
    required SelectionRegistrar? selectionRegistrar,
    required Color? selectionColor,
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
       _selectionColor = selectionColor,
       _links = List.unmodifiable(links),
       _onLinkTap = onLinkTap,
       _onLinkLongPress = onLinkLongPress {
    registrar = selectionRegistrar;
  }

  TextSpan get text => _text;
  TextSpan _text;

  set text(TextSpan value) {
    if (value == _text) return;
    _text = value;
    _textLayoutReady = false;
    _clearSelection();
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
    _textLayoutReady = false;
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
    _textLayoutReady = false;
    markNeedsLayout();
  }

  Color? _selectionColor;

  set selectionColor(Color? value) {
    if (value == _selectionColor) {
      return;
    }
    _selectionColor = value;
    markNeedsPaint();
  }

  TextPosition? _selectionStart;
  TextPosition? _selectionEnd;
  LayerLink? _startHandleLayerLink;
  LayerLink? _endHandleLayerLink;
  SelectionGeometry _selectionGeometry = const SelectionGeometry(
    status: SelectionStatus.none,
    hasContent: false,
  );

  @override
  SelectionGeometry get value => _selectionGeometry;

  bool get _hasHandleLayers =>
      _startHandleLayerLink != null || _endHandleLayerLink != null;

  @override
  bool get alwaysNeedsCompositing => _hasHandleLayers;

  List<DynamicTextLink> _links;

  set links(List<DynamicTextLink> value) {
    _cancelLinkLongPress();
    _cancelLinkTap();
    _links = List.unmodifiable(value);
  }

  LinkTapCallback? _onLinkTap;

  set onLinkTap(LinkTapCallback? value) {
    _onLinkTap = value;
    if (value == null) {
      _cancelLinkTap();
    }
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
  late final TapGestureRecognizer _linkTapGestureRecognizer =
      TapGestureRecognizer(debugOwner: this)
        ..onTap = _handleLinkTap
        ..onTapCancel = _cancelLinkTap;
  late final LongPressGestureRecognizer _linkLongPressGestureRecognizer =
      LongPressGestureRecognizer(debugOwner: this)
        ..onLongPress = _handleLinkLongPress
        ..onLongPressCancel = _cancelLinkLongPress;

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
      _startLinkGestures(entry.localPosition, event);
      return;
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
    size = constraints.constrain(unconstrainedSize);
    _updateSelectionGeometry();
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
  var _textLayoutReady = false;

  DynamicTextLink? _linkTapTarget;
  DynamicTextLink? _linkLongPressTarget;
  int? _detailTapPointer;
  int? _pressedDetailActionIndex;

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

  void _startLinkGestures(Offset position, PointerDownEvent event) {
    if (_onLinkTap == null && _onLinkLongPress == null) return;
    final target = _linkAtOffset(position);
    if (target == null) return;
    if (_onLinkTap != null) {
      _linkTapTarget = target;
      _linkTapGestureRecognizer.addPointer(event);
    }
    if (_onLinkLongPress != null) {
      _linkLongPressTarget = target;
      _linkLongPressGestureRecognizer.addPointer(event);
    }
  }

  void _cancelLinkTap() {
    _linkTapTarget = null;
  }

  void _cancelLinkLongPress() {
    _linkLongPressTarget = null;
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

  void _handleLinkTap() {
    final target = _linkTapTarget;
    _cancelLinkTap();
    if (target == null) {
      return;
    }
    _onLinkTap?.call(target.url);
  }

  void _handleLinkLongPress() {
    final target = _linkLongPressTarget;
    _cancelLinkLongPress();
    if (target == null) {
      return;
    }
    _onLinkLongPress?.call(target.url);
  }

  String get _plainText => _textLayoutReady
      ? _textPainter.text?.toPlainText(includeSemanticsLabels: false) ?? ''
      : _text.toPlainText(includeSemanticsLabels: false);

  Rect get _bodyTextRect {
    if (!_textLayoutReady || _plainText.isEmpty || _textPainter.height <= 0) {
      return Rect.zero;
    }
    return Rect.fromLTWH(0, 0, _maxLineWidth, _textPainter.height);
  }

  TextPosition _textPositionForGlobalOffset(Offset globalPosition) {
    final transform = getTransformTo(null)..invert();
    final localPosition = MatrixUtils.transformPoint(transform, globalPosition);
    final adjustedOffset = SelectionUtils.adjustDragOffset(
      _bodyTextRect,
      localPosition,
      direction: _textDirection,
    );
    final position = _textPainter.getPositionForOffset(adjustedOffset);
    return TextPosition(offset: position.offset.clamp(0, contentLength));
  }

  void _setSelectionPosition(TextPosition? position, {required bool isEnd}) {
    if (isEnd) {
      _selectionEnd = position;
    } else {
      _selectionStart = position;
    }
  }

  void _clearSelection() {
    if (_selectionStart == null && _selectionEnd == null) {
      _updateSelectionGeometry();
      return;
    }
    _selectionStart = null;
    _selectionEnd = null;
    markNeedsPaint();
    _updateSelectionGeometry();
  }

  SelectionResult _setSelectionOffset(int offset, {required bool isEnd}) {
    if (contentLength == 0) {
      _setSelectionPosition(null, isEnd: isEnd);
      _updateSelectionGeometry();
      return SelectionResult.none;
    }
    final position = TextPosition(offset: offset.clamp(0, contentLength));
    _setSelectionPosition(position, isEnd: isEnd);
    markNeedsPaint();
    _updateSelectionGeometry();
    if (position.offset == contentLength) {
      return SelectionResult.next;
    }
    if (position.offset == 0) {
      return SelectionResult.previous;
    }
    return SelectionResult.end;
  }

  TextRange _wordBoundaryNear(int offset, {required bool forward}) {
    final position = TextPosition(offset: offset.clamp(0, contentLength));
    final boundary = _textPainter.getWordBoundary(position);
    if (boundary.start != boundary.end) {
      return boundary;
    }
    final nextOffset = (offset + (forward ? 1 : -1)).clamp(0, contentLength);
    return _textPainter.getWordBoundary(TextPosition(offset: nextOffset));
  }

  int _paragraphBoundaryOffset(int offset, {required bool forward}) {
    final boundary = ParagraphBoundary(_plainText);
    final nextOffset = forward
        ? boundary.getTrailingTextBoundaryAt(offset)
        : boundary.getLeadingTextBoundaryAt(offset - 1);
    return (nextOffset ?? (forward ? contentLength : 0)).clamp(
      0,
      contentLength,
    );
  }

  SelectionResult _handleSelectionEdgeUpdate(
    SelectionEdgeUpdateEvent event, {
    required bool isEnd,
  }) {
    if (contentLength == 0) {
      _setSelectionPosition(null, isEnd: isEnd);
      _updateSelectionGeometry();
      return SelectionResult.none;
    }
    final position = _textPositionForGlobalOffset(event.globalPosition);
    switch (event.granularity) {
      case TextGranularity.character:
        _setSelectionPosition(position, isEnd: isEnd);
      case TextGranularity.word:
        final boundary = _wordBoundaryNear(position.offset, forward: isEnd);
        _setSelectionPosition(
          TextPosition(offset: isEnd ? boundary.end : boundary.start),
          isEnd: isEnd,
        );
      case TextGranularity.paragraph:
      case TextGranularity.line:
      case TextGranularity.document:
        return SelectionResult.none;
    }
    markNeedsPaint();
    _updateSelectionGeometry();
    if (position.offset == contentLength) {
      return SelectionResult.next;
    }
    if (position.offset == 0) {
      return SelectionResult.previous;
    }
    return SelectionUtils.getResultBasedOnRect(
      _bodyTextRect,
      MatrixUtils.transformPoint(
        getTransformTo(null)..invert(),
        event.globalPosition,
      ),
    );
  }

  SelectionResult _selectWordAt(Offset globalPosition) {
    if (contentLength == 0) {
      return SelectionResult.none;
    }
    final position = _textPositionForGlobalOffset(globalPosition);
    final boundary = _textPainter.getWordBoundary(position);
    final start = boundary.start.clamp(0, contentLength);
    final end = boundary.end.clamp(0, contentLength);
    _selectionStart = TextPosition(offset: start);
    _selectionEnd = TextPosition(offset: end);
    markNeedsPaint();
    _updateSelectionGeometry();
    return SelectionResult.end;
  }

  SelectionResult _selectParagraphAt(Offset globalPosition) {
    if (contentLength == 0) {
      return SelectionResult.none;
    }
    final transform = getTransformTo(null)..invert();
    final localPosition = MatrixUtils.transformPoint(transform, globalPosition);
    final result = SelectionUtils.getResultBasedOnRect(
      _bodyTextRect,
      localPosition,
    );
    if (result != SelectionResult.end) {
      return result;
    }
    _selectionStart = const TextPosition(offset: 0);
    _selectionEnd = TextPosition(offset: contentLength);
    markNeedsPaint();
    _updateSelectionGeometry();
    return SelectionResult.end;
  }

  SelectionResult _selectAll() {
    if (contentLength == 0) {
      return SelectionResult.none;
    }
    _selectionStart = const TextPosition(offset: 0);
    _selectionEnd = TextPosition(offset: contentLength);
    markNeedsPaint();
    _updateSelectionGeometry();
    return SelectionResult.none;
  }

  int _selectionEdgeOffset({required bool isEnd, required bool forward}) {
    final current = isEnd ? _selectionEnd : _selectionStart;
    return current?.offset ?? (forward ? 0 : contentLength);
  }

  SelectionResult _extendSelection(
    bool forward, {
    required bool isEnd,
    required TextGranularity granularity,
  }) {
    final offset = _selectionEdgeOffset(isEnd: isEnd, forward: forward);
    switch (granularity) {
      case TextGranularity.character:
        return _setSelectionOffset(offset + (forward ? 1 : -1), isEnd: isEnd);
      case TextGranularity.word:
        final boundary = _wordBoundaryNear(offset, forward: forward);
        return _setSelectionOffset(
          forward ? boundary.end : boundary.start,
          isEnd: isEnd,
        );
      case TextGranularity.paragraph:
        return _setSelectionOffset(
          _paragraphBoundaryOffset(offset, forward: forward),
          isEnd: isEnd,
        );
      case TextGranularity.document:
        return _setSelectionOffset(forward ? contentLength : 0, isEnd: isEnd);
      case TextGranularity.line:
        return SelectionResult.none;
    }
  }

  SelectionResult _extendSelectionByLine({
    required bool forward,
    required bool isEnd,
    required double globalDx,
  }) {
    if (contentLength == 0 || !_textLayoutReady) {
      return SelectionResult.none;
    }
    final offset = _selectionEdgeOffset(isEnd: isEnd, forward: forward);
    final caretOffset = _textPainter.getOffsetForCaret(
      TextPosition(offset: offset.clamp(0, contentLength)),
      Rect.zero,
    );
    final targetY =
        caretOffset.dy + (forward ? 1 : -1) * _textPainter.preferredLineHeight;
    if (targetY < 0) {
      return _setSelectionOffset(0, isEnd: isEnd);
    }
    if (targetY > _textPainter.height) {
      return _setSelectionOffset(contentLength, isEnd: isEnd);
    }
    final localOrigin = localToGlobal(Offset.zero);
    final localDx = globalToLocal(Offset(globalDx, localOrigin.dy)).dx;
    final position = _textPainter.getPositionForOffset(
      Offset(localDx.clamp(0, _maxLineWidth), targetY),
    );
    return _setSelectionOffset(position.offset, isEnd: isEnd);
  }

  SelectionResult _extendSelectionDirectionally(
    DirectionallyExtendSelectionEvent event,
  ) {
    switch (event.direction) {
      case SelectionExtendDirection.forward:
        return _extendSelection(
          true,
          isEnd: event.isEnd,
          granularity: TextGranularity.character,
        );
      case SelectionExtendDirection.backward:
        return _extendSelection(
          false,
          isEnd: event.isEnd,
          granularity: TextGranularity.character,
        );
      case SelectionExtendDirection.previousLine:
        return _extendSelectionByLine(
          forward: false,
          isEnd: event.isEnd,
          globalDx: event.dx,
        );
      case SelectionExtendDirection.nextLine:
        return _extendSelectionByLine(
          forward: true,
          isEnd: event.isEnd,
          globalDx: event.dx,
        );
    }
  }

  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    switch (event.type) {
      case SelectionEventType.startEdgeUpdate:
        return _handleSelectionEdgeUpdate(
          event as SelectionEdgeUpdateEvent,
          isEnd: false,
        );
      case SelectionEventType.endEdgeUpdate:
        return _handleSelectionEdgeUpdate(
          event as SelectionEdgeUpdateEvent,
          isEnd: true,
        );
      case SelectionEventType.clear:
        _clearSelection();
        return SelectionResult.none;
      case SelectionEventType.selectAll:
        return _selectAll();
      case SelectionEventType.selectWord:
        return _selectWordAt(
          (event as SelectWordSelectionEvent).globalPosition,
        );
      case SelectionEventType.selectParagraph:
        return _selectParagraphAt(
          (event as SelectParagraphSelectionEvent).globalPosition,
        );
      case SelectionEventType.granularlyExtendSelection:
        final granularEvent = event as GranularlyExtendSelectionEvent;
        return _extendSelection(
          granularEvent.forward,
          isEnd: granularEvent.isEnd,
          granularity: granularEvent.granularity,
        );
      case SelectionEventType.directionallyExtendSelection:
        return _extendSelectionDirectionally(
          event as DirectionallyExtendSelectionEvent,
        );
    }
  }

  @override
  SelectedContent? getSelectedContent() {
    if (_selectionStart == null || _selectionEnd == null) {
      return null;
    }
    final start = min(_selectionStart!.offset, _selectionEnd!.offset);
    final end = max(_selectionStart!.offset, _selectionEnd!.offset);
    if (start == end) {
      return null;
    }
    return SelectedContent(plainText: _plainText.substring(start, end));
  }

  @override
  SelectedContentRange? getSelection() {
    if (_selectionStart == null || _selectionEnd == null) {
      return null;
    }
    return SelectedContentRange(
      startOffset: _selectionStart!.offset,
      endOffset: _selectionEnd!.offset,
    );
  }

  @override
  int get contentLength => _plainText.length;

  @override
  List<Rect> get boundingBoxes {
    if (!_textLayoutReady || contentLength == 0) {
      return const <Rect>[];
    }
    final boxes = _textPainter.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: contentLength),
      boxHeightStyle: ui.BoxHeightStyle.max,
    );
    if (boxes.isEmpty) {
      return <Rect>[_bodyTextRect];
    }
    return <Rect>[for (final box in boxes) box.toRect()];
  }

  @override
  void pushHandleLayers(LayerLink? startHandle, LayerLink? endHandle) {
    if (_startHandleLayerLink == startHandle &&
        _endHandleLayerLink == endHandle) {
      return;
    }
    final hadHandleLayers = _hasHandleLayers;
    _startHandleLayerLink = startHandle;
    _endHandleLayerLink = endHandle;
    if (hadHandleLayers != _hasHandleLayers) {
      markNeedsCompositingBitsUpdate();
    }
    markNeedsPaint();
  }

  void _updateSelectionGeometry() {
    final newGeometry = _selectionGeometryForCurrentSelection();
    if (newGeometry == _selectionGeometry) {
      return;
    }
    _selectionGeometry = newGeometry;
    notifyListeners();
  }

  SelectionGeometry _selectionGeometryForCurrentSelection() {
    if (contentLength == 0) {
      return const SelectionGeometry(
        status: SelectionStatus.none,
        hasContent: false,
      );
    }
    if (!_textLayoutReady) {
      return const SelectionGeometry(
        status: SelectionStatus.none,
        hasContent: false,
      );
    }
    if (_selectionStart == null || _selectionEnd == null) {
      return const SelectionGeometry(
        status: SelectionStatus.none,
        hasContent: true,
      );
    }
    final selectionStart = _selectionStart!.offset;
    final selectionEnd = _selectionEnd!.offset;
    final selection = TextSelection(
      baseOffset: selectionStart,
      extentOffset: selectionEnd,
    );
    final selectionRects = <Rect>[
      for (final box in _textPainter.getBoxesForSelection(selection))
        box.toRect(),
    ];
    final selectionCollapsed = selectionStart == selectionEnd;
    final selectionReversed = selectionStart > selectionEnd;
    final flipHandles =
        selectionReversed != (_textDirection == TextDirection.rtl);
    final startHandleType = selectionCollapsed
        ? TextSelectionHandleType.collapsed
        : flipHandles
        ? TextSelectionHandleType.right
        : TextSelectionHandleType.left;
    final endHandleType = selectionCollapsed
        ? TextSelectionHandleType.collapsed
        : flipHandles
        ? TextSelectionHandleType.left
        : TextSelectionHandleType.right;
    return SelectionGeometry(
      startSelectionPoint: SelectionPoint(
        localPosition: _textPainter.getOffsetForCaret(
          TextPosition(offset: selectionStart),
          Rect.zero,
        ),
        lineHeight: _textPainter.preferredLineHeight,
        handleType: startHandleType,
      ),
      endSelectionPoint: SelectionPoint(
        localPosition: _textPainter.getOffsetForCaret(
          TextPosition(offset: selectionEnd),
          Rect.zero,
        ),
        lineHeight: _textPainter.preferredLineHeight,
        handleType: endHandleType,
      ),
      selectionRects: selectionRects,
      status: selectionCollapsed
          ? SelectionStatus.collapsed
          : SelectionStatus.uncollapsed,
      hasContent: true,
    );
  }

  void _paintSelection(PaintingContext context, Offset offset) {
    final selectionColor = _selectionColor;
    if (selectionColor == null ||
        _selectionStart == null ||
        _selectionEnd == null) {
      return;
    }
    final selection = TextSelection(
      baseOffset: _selectionStart!.offset,
      extentOffset: _selectionEnd!.offset,
    );
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = selectionColor;
    for (final box in _textPainter.getBoxesForSelection(selection)) {
      context.canvas.drawRect(box.toRect().shift(offset), paint);
    }
  }

  void _paintSelectionHandles(PaintingContext context, Offset offset) {
    if (_startHandleLayerLink != null && value.startSelectionPoint != null) {
      context.pushLayer(
        LeaderLayer(
          link: _startHandleLayerLink!,
          offset: offset + value.startSelectionPoint!.localPosition,
        ),
        (context, offset) {},
        Offset.zero,
      );
    }
    if (_endHandleLayerLink != null && value.endSelectionPoint != null) {
      context.pushLayer(
        LeaderLayer(
          link: _endHandleLayerLink!,
          offset: offset + value.endSelectionPoint!.localPosition,
        ),
        (context, offset) {},
        Offset.zero,
      );
    }
  }

  @override
  void detach() {
    _cancelLinkLongPress();
    _cancelLinkTap();
    _cancelDetailTap();
    super.detach();
  }

  @override
  void dispose() {
    _detailTapGestureRecognizer.dispose();
    _linkTapGestureRecognizer.dispose();
    _linkLongPressGestureRecognizer.dispose();
    super.dispose();
  }

  Size _layout(double maxWidth) {
    _debugAssertNoWidgetSpans();
    _textLayoutReady = false;
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
    _textLayoutReady = true;
    final textLines = _textPainter.computeLineMetrics();
    _textLineMetrics = textLines;

    _detailPainters = [];
    _detailLineMetrics = [];
    _detailWidths = [];
    _detailHeights = [];
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
        final action = _detailActions[index];
        final detailWidth = metrics.width + (action?.padding.horizontal ?? 0);
        final detailHeight = max(
          metrics.height + (action?.padding.vertical ?? 0),
          action?.minimumHeight ?? 0,
        );
        final verticalInset = (detailHeight - metrics.height) / 2;
        final detailBaselineOffset = verticalInset + metrics.baseline;
        final detailBelowBaseline =
            verticalInset + (metrics.height - metrics.baseline);
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
        _detailsWidth += _detailSpacing;
      }
    }
    _detailsHeight = _detailBaselineOffset + _detailBelowBaseline;

    _maxLineWidth = max(
      textLines.fold(0, (prev, e) => max(prev, e.width)),
      _detailsWidth,
    );

    final messageSize = Size(
      _maxLineWidth,
      hasBodyText ? _textPainter.height : 0.0,
    );

    _finalLineWidth = textLines.isEmpty ? 0.0 : textLines.last.width;

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
            textLines.length <= 1
                ? combinedWidth
                : max(_maxLineWidth, combinedWidth),
            messageSize.height,
          )
        : Size(messageSize.width, messageSize.height + _detailsHeight);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final hasBodyText = _textPainter.text?.toPlainText().isNotEmpty == true;
    final double baseTextHeight = hasBodyText ? _textPainter.height : 0.0;
    if (hasBodyText) {
      _paintSelection(context, offset);
      _textPainter.paint(context.canvas, offset);
    }

    if (_detailPainters.isEmpty) {
      _paintSelectionHandles(context, offset);
      return;
    }

    final lastLine = _textLineMetrics.isNotEmpty ? _textLineMetrics.last : null;
    final detailStartGap = hasBodyText ? _detailStartGap : 0.0;
    final detailBaselineY = _canInlineDetails && lastLine != null
        ? offset.dy + lastLine.baseline
        : offset.dy + baseTextHeight + _detailBaselineOffset;
    var dx = _canInlineDetails
        ? offset.dx + _finalLineWidth + detailStartGap
        : offset.dx + size.width - _detailsWidth;
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
      final textTop =
          detailBaselineY -
          detailBaseline +
          opticalOffset +
          _detailRowVerticalOffset;
      final backgroundTop = textTop - verticalInset;
      if (action != null) {
        final backgroundRect = Rect.fromLTWH(
          dx,
          backgroundTop,
          detailWidth,
          detailHeight,
        );
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
        Offset(dx + (horizontalPadding / 2), textTop),
      );
      dx += detailWidth;
      final hasTrailingDetail = i < _detailPainters.length - 1;
      if (hasTrailingDetail) {
        dx += _detailSpacing;
      }
    }
    _paintSelectionHandles(context, offset);
  }

  int? _detailActionIndexAtOffset(Offset position) {
    if (_detailActions.isEmpty || _detailPainters.isEmpty) {
      return null;
    }
    final hasBodyText = _textPainter.text?.toPlainText().isNotEmpty == true;
    final baseTextHeight = hasBodyText ? _textPainter.height : 0.0;
    final lastLine = _textLineMetrics.isNotEmpty ? _textLineMetrics.last : null;
    final detailStartGap = hasBodyText ? _detailStartGap : 0.0;
    final detailBaselineY = _canInlineDetails && lastLine != null
        ? lastLine.baseline
        : baseTextHeight + _detailBaselineOffset;
    var dx = _canInlineDetails
        ? _finalLineWidth + detailStartGap
        : size.width - _detailsWidth;
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
        final textTop =
            detailBaselineY -
            detailBaseline +
            opticalOffset +
            _detailRowVerticalOffset;
        final backgroundTop = textTop - verticalInset;
        final rect = Rect.fromLTWH(
          dx,
          backgroundTop,
          detailWidth,
          detailHeight,
        );
        if (rect.contains(position)) {
          return i;
        }
      }
      dx += detailWidth;
      if (i < _detailPainters.length - 1) {
        dx += _detailSpacing;
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
