import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const Duration _caretSlideDuration = Duration(milliseconds: 120);
const Duration _glyphMorphDuration = Duration(milliseconds: 180);
const Curve _caretSlideCurve = Curves.easeOutCubic;
const Curve _glyphMorphCurve = Curves.easeOutCubic;
const double _cursorDotDiameter = 6;
const double _cursorDotRadius = _cursorDotDiameter / 2;
const double _glyphStartScale = 0.2;
const double _glyphEndScale = 1.0;
const double _glyphStartOpacity = 0.0;
const double _glyphEndOpacity = 1.0;
const double _hiddenTextAlpha = 0.0;

enum TypingTextChangeKind {
  none,
  selection,
  insert,
  delete,
  replace,
}

extension TypingTextChangeKindX on TypingTextChangeKind {
  bool get isInsertion => this == TypingTextChangeKind.insert;
  bool get isDeletion => this == TypingTextChangeKind.delete;
  bool get isSelection => this == TypingTextChangeKind.selection;
}

@immutable
class TypingTextChange {
  const TypingTextChange({
    required this.kind,
    required this.previousValue,
    required this.currentValue,
    this.insertedRange,
    this.insertedText,
  });

  final TypingTextChangeKind kind;
  final TextEditingValue previousValue;
  final TextEditingValue currentValue;
  final TextRange? insertedRange;
  final String? insertedText;

  bool get isSingleCharacterInsertion =>
      kind.isInsertion && insertedRange != null && insertedText != null;
}

@immutable
class TypingGlyphAnimation {
  const TypingGlyphAnimation({
    required this.text,
    required this.targetRect,
    required this.startOffset,
    required this.style,
  });

  final String text;
  final Rect targetRect;
  final Offset startOffset;
  final TextStyle style;
}

class TypingTextEditingController extends TextEditingController {
  TypingTextEditingController({
    TextEditingController? source,
    TextEditingValue? initialValue,
  }) : _source = source {
    if (_source != null) {
      _syncFromSource(_source!.value);
      _source!.addListener(_handleSourceChanged);
    } else if (initialValue != null) {
      _syncFromSource(initialValue);
    }
    addListener(_handleLocalChanged);
  }

  TextEditingController? _source;
  bool _syncing = false;
  TextRange? _hiddenRange;

  TextRange? get hiddenRange => _hiddenRange;

  void updateSource(
      TextEditingController? source, TextEditingValue? initialValue) {
    if (_source == source) {
      if (_source == null && initialValue != null) {
        _syncFromSource(initialValue);
      }
      return;
    }
    _source?.removeListener(_handleSourceChanged);
    _source = source;
    if (_source != null) {
      _syncFromSource(_source!.value);
      _source!.addListener(_handleSourceChanged);
    } else if (initialValue != null) {
      _syncFromSource(initialValue);
    }
  }

  void setHiddenRange(TextRange? range) {
    if (_hiddenRange == range) {
      return;
    }
    _hiddenRange = range;
    notifyListeners();
  }

  void clearHiddenRange() => setHiddenRange(null);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final String fullText = text;
    final TextRange composingRange = value.composing;
    final bool hasValidComposing = withComposing && value.isComposingRangeValid;
    final TextRange? hiddenRange = _validatedHiddenRange(fullText);
    if (!hasValidComposing && hiddenRange == null) {
      return TextSpan(style: style, text: fullText);
    }

    final TextStyle baseStyle = DefaultTextStyle.of(context).style.merge(style);
    final TextStyle composingStyle = baseStyle.merge(
      const TextStyle(decoration: TextDecoration.underline),
    );
    final Color baseColor =
        baseStyle.color ?? ShadTheme.of(context).colorScheme.foreground;
    final Color hiddenColor = baseColor.withValues(alpha: _hiddenTextAlpha);
    final TextStyle hiddenStyle = baseStyle.copyWith(
      color: hiddenColor,
      decorationColor: hiddenColor,
      decoration: TextDecoration.none,
    );

    final List<int> boundaries = <int>[0, fullText.length];
    if (hasValidComposing) {
      boundaries
        ..add(composingRange.start)
        ..add(composingRange.end);
    }
    if (hiddenRange != null) {
      boundaries
        ..add(hiddenRange.start)
        ..add(hiddenRange.end);
    }
    boundaries.sort();

    final List<TextSpan> children = <TextSpan>[];
    for (int i = 0; i < boundaries.length - 1; i++) {
      final int start = boundaries[i];
      final int end = boundaries[i + 1];
      if (start == end) {
        continue;
      }
      final String segment = fullText.substring(start, end);
      final bool isHidden = hiddenRange != null &&
          start >= hiddenRange.start &&
          end <= hiddenRange.end;
      final bool isComposing = hasValidComposing &&
          start >= composingRange.start &&
          end <= composingRange.end;
      final TextStyle? segmentStyle = isHidden
          ? hiddenStyle
          : isComposing
              ? composingStyle
              : null;
      children.add(TextSpan(text: segment, style: segmentStyle));
    }

    return TextSpan(style: style, children: children);
  }

  TextRange? _validatedHiddenRange(String fullText) {
    final TextRange? hiddenRange = _hiddenRange;
    if (hiddenRange == null || !hiddenRange.isValid) {
      return null;
    }
    if (hiddenRange.isCollapsed) {
      return null;
    }
    if (hiddenRange.start < 0 || hiddenRange.end > fullText.length) {
      return null;
    }
    return hiddenRange;
  }

  void _handleSourceChanged() {
    if (_source == null || _syncing) {
      return;
    }
    _syncFromSource(_source!.value);
  }

  void _handleLocalChanged() {
    if (_syncing || _source == null) {
      return;
    }
    if (_source!.value == value) {
      return;
    }
    _syncing = true;
    _source!.value = value;
    _syncing = false;
  }

  void _syncFromSource(TextEditingValue value) {
    _syncing = true;
    this.value = value;
    _syncing = false;
  }

  @override
  void dispose() {
    _source?.removeListener(_handleSourceChanged);
    removeListener(_handleLocalChanged);
    super.dispose();
  }
}

class TypingTextAnimator extends StatefulWidget {
  const TypingTextAnimator({
    super.key,
    required this.controller,
    required this.child,
  });

  final TypingTextEditingController controller;
  final Widget child;

  @override
  State<TypingTextAnimator> createState() => _TypingTextAnimatorState();
}

class _TypingTextAnimatorState extends State<TypingTextAnimator>
    with TickerProviderStateMixin {
  late final AnimationController _caretController = AnimationController(
    vsync: this,
    duration: _caretSlideDuration,
  )..addListener(_handleCaretTick);
  late final Animation<double> _caretCurve = CurvedAnimation(
    parent: _caretController,
    curve: _caretSlideCurve,
  );

  late final AnimationController _glyphController = AnimationController(
    vsync: this,
    duration: _glyphMorphDuration,
  )
    ..addListener(_handleGlyphTick)
    ..addStatusListener(_handleGlyphStatus);
  late final Animation<double> _glyphCurve = CurvedAnimation(
    parent: _glyphController,
    curve: _glyphMorphCurve,
  );

  TypingCaretPainter? _caretPainter;
  RenderEditablePainter? _originalForegroundPainter;
  _CompositeEditablePainter? _compositeForegroundPainter;
  RenderEditable? _renderEditable;
  EditableTextState? _editableTextState;
  ValueNotifier<bool>? _cursorVisibility;
  TypingTextChange? _pendingChange;
  TextEditingValue _previousValue = const TextEditingValue();
  Animation<Offset> _caretAnimation = const AlwaysStoppedAnimation<Offset>(
    Offset.zero,
  );
  Offset _currentCaretOffset = Offset.zero;
  TypingGlyphAnimation? _glyphAnimation;
  bool _updateScheduled = false;
  bool _lookupScheduled = false;
  bool _suppressControllerChanges = false;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.controller.value;
    widget.controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleLookup());
  }

  @override
  void didUpdateWidget(covariant TypingTextAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _previousValue = widget.controller.value;
      _stopGlyphMorph();
      _scheduleUpdate();
    }
    _scheduleLookup();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Color dotColor = ShadTheme.of(context).colorScheme.foreground;
    _caretPainter ??= TypingCaretPainter(
      dotColor: dotColor,
      dotRadius: _cursorDotRadius,
    );
    _caretPainter
      ?..dotColor = dotColor
      ..dotRadius = _cursorDotRadius;
    _installForegroundPainter();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _detachEditableText();
    _caretController.dispose();
    _glyphController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _scheduleLookup() {
    if (_lookupScheduled) {
      return;
    }
    _lookupScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lookupScheduled = false;
      if (!mounted) {
        return;
      }
      _attachEditableText(_findEditableText(context));
    });
  }

  void _attachEditableText(EditableTextState? state) {
    if (state == _editableTextState) {
      return;
    }
    _detachEditableText();
    if (state == null) {
      return;
    }
    _editableTextState = state;
    _renderEditable = state.renderEditable;
    _cursorVisibility = _renderEditable?.showCursor
      ?..addListener(_handleCursorVisibilityChanged);
    _handleCursorVisibilityChanged();
    _installForegroundPainter();
    _scheduleUpdate();
  }

  void _detachEditableText() {
    _cursorVisibility?.removeListener(_handleCursorVisibilityChanged);
    _cursorVisibility = null;
    if (_renderEditable != null) {
      _renderEditable!.foregroundPainter = _originalForegroundPainter;
    }
    _originalForegroundPainter = null;
    _compositeForegroundPainter = null;
    _renderEditable = null;
    _editableTextState = null;
  }

  void _installForegroundPainter() {
    final RenderEditable? renderEditable = _renderEditable;
    final TypingCaretPainter? caretPainter = _caretPainter;
    if (renderEditable == null || caretPainter == null) {
      return;
    }
    final RenderEditablePainter? existingPainter =
        renderEditable.foregroundPainter;
    if (existingPainter == caretPainter ||
        existingPainter == _compositeForegroundPainter) {
      return;
    }
    _originalForegroundPainter = existingPainter;
    if (existingPainter == null) {
      renderEditable.foregroundPainter = caretPainter;
      return;
    }
    final _CompositeEditablePainter composite = _CompositeEditablePainter(
      <RenderEditablePainter>[existingPainter, caretPainter],
    );
    _compositeForegroundPainter = composite;
    renderEditable.foregroundPainter = composite;
  }

  void _handleCursorVisibilityChanged() {
    _caretPainter?.showCaret = _cursorVisibility?.value ?? false;
  }

  void _handleControllerChanged() {
    if (_suppressControllerChanges) {
      return;
    }
    final TextEditingValue nextValue = widget.controller.value;
    final TypingTextChange change = _describeChange(_previousValue, nextValue);
    _previousValue = nextValue;
    _pendingChange = change;
    _scheduleUpdate();
  }

  void _scheduleUpdate() {
    if (_updateScheduled) {
      return;
    }
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (!mounted) {
        return;
      }
      _applyPendingChange();
    });
  }

  void _applyPendingChange() {
    final TypingTextChange? change = _pendingChange;
    final RenderEditable? renderEditable = _renderEditable;
    if (change == null || renderEditable == null) {
      return;
    }
    if (!renderEditable.hasSize) {
      _pendingChange = change;
      _scheduleUpdate();
      return;
    }
    _pendingChange = null;

    final bool hasFocus = renderEditable.hasFocus;
    final Offset? endOffset =
        _caretOffsetForSelection(change.currentValue.selection, renderEditable);
    final Offset? startOffset = _caretOffsetForSelection(
        change.previousValue.selection, renderEditable);
    if (endOffset == null) {
      return;
    }
    if (!hasFocus) {
      _stopGlyphMorph();
      _jumpCaretTo(endOffset);
      return;
    }

    if (change.kind.isInsertion || change.kind.isDeletion) {
      _animateCaret(startOffset ?? endOffset, endOffset);
    } else {
      _jumpCaretTo(endOffset);
    }

    if (change.isSingleCharacterInsertion) {
      _startGlyphMorph(change, renderEditable);
    } else {
      _stopGlyphMorph();
    }
  }

  TypingTextChange _describeChange(
    TextEditingValue previousValue,
    TextEditingValue currentValue,
  ) {
    if (previousValue == currentValue) {
      return TypingTextChange(
        kind: TypingTextChangeKind.none,
        previousValue: previousValue,
        currentValue: currentValue,
      );
    }
    final int delta = currentValue.text.length - previousValue.text.length;
    if (delta == 0) {
      return TypingTextChange(
        kind: TypingTextChangeKind.selection,
        previousValue: previousValue,
        currentValue: currentValue,
      );
    }
    if (delta == 1 &&
        previousValue.selection.isCollapsed &&
        currentValue.selection.isCollapsed) {
      final int insertionOffset = currentValue.selection.baseOffset - 1;
      final bool offsetValid =
          insertionOffset >= 0 && insertionOffset < currentValue.text.length;
      final bool matchesCaret =
          previousValue.selection.baseOffset == insertionOffset;
      if (offsetValid && matchesCaret) {
        final TextRange range = TextRange(
          start: insertionOffset,
          end: insertionOffset + 1,
        );
        final String text = currentValue.text.substring(range.start, range.end);
        return TypingTextChange(
          kind: TypingTextChangeKind.insert,
          previousValue: previousValue,
          currentValue: currentValue,
          insertedRange: range,
          insertedText: text,
        );
      }
    }
    if (delta < 0) {
      return TypingTextChange(
        kind: TypingTextChangeKind.delete,
        previousValue: previousValue,
        currentValue: currentValue,
      );
    }
    return TypingTextChange(
      kind: TypingTextChangeKind.replace,
      previousValue: previousValue,
      currentValue: currentValue,
    );
  }

  Offset? _caretOffsetForSelection(
    TextSelection selection,
    RenderEditable renderEditable,
  ) {
    if (!selection.isValid) {
      return null;
    }
    final TextPosition position = TextPosition(offset: selection.extentOffset);
    final Rect caretRect = renderEditable.getLocalRectForCaret(position);
    final Offset centered = caretRect.center;
    return _snapOffset(centered, renderEditable.devicePixelRatio);
  }

  Offset _snapOffset(Offset offset, double devicePixelRatio) {
    if (devicePixelRatio == 0) {
      return offset;
    }
    final double snappedDx =
        (offset.dx * devicePixelRatio).roundToDouble() / devicePixelRatio;
    final double snappedDy =
        (offset.dy * devicePixelRatio).roundToDouble() / devicePixelRatio;
    return Offset(snappedDx, snappedDy);
  }

  void _animateCaret(Offset start, Offset end) {
    final Offset effectiveStart =
        _caretController.isAnimating ? _caretAnimation.value : start;
    if (effectiveStart == end) {
      _jumpCaretTo(end);
      return;
    }
    _caretAnimation =
        Tween<Offset>(begin: effectiveStart, end: end).animate(_caretCurve);
    _caretController
      ..reset()
      ..forward();
  }

  void _jumpCaretTo(Offset target) {
    _caretController.stop();
    _caretAnimation = AlwaysStoppedAnimation<Offset>(target);
    _updateCaretOffset(target);
  }

  void _handleCaretTick() {
    _updateCaretOffset(_caretAnimation.value);
  }

  void _updateCaretOffset(Offset offset) {
    _currentCaretOffset = offset;
    _caretPainter?.caretOffset = offset;
  }

  void _startGlyphMorph(
    TypingTextChange change,
    RenderEditable renderEditable,
  ) {
    final TextRange? range = change.insertedRange;
    final String? text = change.insertedText;
    if (range == null || text == null) {
      return;
    }
    final Rect? glyphRect = _glyphRectForRange(renderEditable, range);
    if (glyphRect == null) {
      return;
    }
    final TextStyle style = _textStyleForOffset(
      renderEditable,
      range.start,
    );
    final Offset startOffset = _caretOffsetForSelection(
          change.previousValue.selection,
          renderEditable,
        ) ??
        _currentCaretOffset;
    final TypingGlyphAnimation animation = TypingGlyphAnimation(
      text: text,
      targetRect: glyphRect,
      startOffset: startOffset,
      style: style,
    );
    _applyHiddenRange(range);
    _glyphAnimation = animation;
    _caretPainter
      ?..glyphAnimation = animation
      ..glyphProgress = _glyphStartOpacity;
    _glyphController
      ..reset()
      ..forward();
  }

  void _handleGlyphTick() {
    _caretPainter?.glyphProgress = _glyphCurve.value;
  }

  void _handleGlyphStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _stopGlyphMorph();
    }
  }

  void _stopGlyphMorph() {
    if (_glyphAnimation == null) {
      _applyHiddenRange(null);
      return;
    }
    _glyphController.stop();
    _glyphAnimation = null;
    _caretPainter
      ?..glyphAnimation = null
      ..glyphProgress = _glyphEndOpacity;
    _applyHiddenRange(null);
  }

  void _applyHiddenRange(TextRange? range) {
    if (widget.controller.hiddenRange == range) {
      return;
    }
    _suppressControllerChanges = true;
    widget.controller.setHiddenRange(range);
    _suppressControllerChanges = false;
  }

  Rect? _glyphRectForRange(
    RenderEditable renderEditable,
    TextRange range,
  ) {
    final List<ui.TextBox> boxes = renderEditable.getBoxesForSelection(
      TextSelection(baseOffset: range.start, extentOffset: range.end),
    );
    if (boxes.isEmpty) {
      return null;
    }
    return boxes.first.toRect();
  }

  TextStyle _textStyleForOffset(
    RenderEditable renderEditable,
    int offset,
  ) {
    final InlineSpan? span = renderEditable.text;
    if (span == null) {
      return DefaultTextStyle.of(context).style;
    }
    final InlineSpan? resolvedSpan =
        span.getSpanForPosition(TextPosition(offset: offset));
    final TextStyle? resolvedStyle = resolvedSpan is TextSpan
        ? resolvedSpan.style
        : span is TextSpan
            ? span.style
            : null;
    return DefaultTextStyle.of(context).style.merge(resolvedStyle);
  }
}

class TypingCaretPainter extends RenderEditablePainter {
  TypingCaretPainter({
    required Color dotColor,
    required double dotRadius,
  })  : _dotColor = dotColor,
        _dotRadius = dotRadius;

  Color _dotColor;
  double _dotRadius;
  Offset _caretOffset = Offset.zero;
  bool _showCaret = true;
  TypingGlyphAnimation? _glyphAnimation;
  double _glyphProgress = _glyphStartOpacity;

  Color get dotColor => _dotColor;
  set dotColor(Color value) {
    if (_dotColor == value) {
      return;
    }
    _dotColor = value;
    notifyListeners();
  }

  double get dotRadius => _dotRadius;
  set dotRadius(double value) {
    if (_dotRadius == value) {
      return;
    }
    _dotRadius = value;
    notifyListeners();
  }

  Offset get caretOffset => _caretOffset;
  set caretOffset(Offset value) {
    if (_caretOffset == value) {
      return;
    }
    _caretOffset = value;
    notifyListeners();
  }

  bool get showCaret => _showCaret;
  set showCaret(bool value) {
    if (_showCaret == value) {
      return;
    }
    _showCaret = value;
    notifyListeners();
  }

  TypingGlyphAnimation? get glyphAnimation => _glyphAnimation;
  set glyphAnimation(TypingGlyphAnimation? value) {
    if (_glyphAnimation == value) {
      return;
    }
    _glyphAnimation = value;
    notifyListeners();
  }

  double get glyphProgress => _glyphProgress;
  set glyphProgress(double value) {
    if (_glyphProgress == value) {
      return;
    }
    _glyphProgress = value;
    notifyListeners();
  }

  @override
  void paint(Canvas canvas, Size size, RenderEditable renderEditable) {
    final TypingGlyphAnimation? glyphAnimation = _glyphAnimation;
    if (glyphAnimation != null) {
      _paintGlyphMorph(canvas, renderEditable, glyphAnimation);
    }

    final TextSelection? selection = renderEditable.selection;
    final bool shouldPaintCaret = selection != null &&
        selection.isValid &&
        selection.isCollapsed &&
        renderEditable.hasFocus &&
        _showCaret;
    if (!shouldPaintCaret) {
      return;
    }
    final Paint dotPaint = Paint()
      ..color = _dotColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(_caretOffset, _dotRadius, dotPaint);
  }

  void _paintGlyphMorph(
    Canvas canvas,
    RenderEditable renderEditable,
    TypingGlyphAnimation glyphAnimation,
  ) {
    final double progress = _glyphProgress.clamp(0.0, 1.0);
    final double dotOpacity = _lerpDouble(
      _glyphEndOpacity,
      _glyphStartOpacity,
      progress,
    );
    final double glyphOpacity = _lerpDouble(
      _glyphStartOpacity,
      _glyphEndOpacity,
      progress,
    );
    final double glyphScale = _lerpDouble(
      _glyphStartScale,
      _glyphEndScale,
      progress,
    );

    final Paint dotPaint = Paint()
      ..color = _dotColor.withValues(alpha: dotOpacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(glyphAnimation.startOffset, _dotRadius, dotPaint);

    final Color baseColor = glyphAnimation.style.color ?? _dotColor;
    final TextStyle glyphStyle = glyphAnimation.style.copyWith(
      color: baseColor.withValues(alpha: glyphOpacity),
    );
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: glyphAnimation.text, style: glyphStyle),
      textDirection: renderEditable.textDirection,
      textScaler: renderEditable.textScaler,
    )..layout();

    final Offset center = glyphAnimation.targetRect.center;
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(glyphScale, glyphScale)
      ..translate(-center.dx, -center.dy);
    textPainter.paint(canvas, glyphAnimation.targetRect.topLeft);
    canvas.restore();
  }

  double _lerpDouble(double start, double end, double t) {
    return start + (end - start) * t;
  }

  @override
  bool shouldRepaint(RenderEditablePainter? oldDelegate) {
    if (identical(oldDelegate, this)) {
      return false;
    }
    return true;
  }
}

class _CompositeEditablePainter extends RenderEditablePainter {
  _CompositeEditablePainter(this.painters);

  final List<RenderEditablePainter> painters;

  @override
  void addListener(VoidCallback listener) {
    for (final RenderEditablePainter painter in painters) {
      painter.addListener(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    for (final RenderEditablePainter painter in painters) {
      painter.removeListener(listener);
    }
  }

  @override
  void paint(Canvas canvas, Size size, RenderEditable renderEditable) {
    for (final RenderEditablePainter painter in painters) {
      painter.paint(canvas, size, renderEditable);
    }
  }

  @override
  bool shouldRepaint(RenderEditablePainter? oldDelegate) {
    return true;
  }
}

EditableTextState? _findEditableText(BuildContext context) {
  EditableTextState? result;
  void visitor(Element element) {
    if (result != null) {
      return;
    }
    if (element is StatefulElement && element.state is EditableTextState) {
      result = element.state as EditableTextState;
      return;
    }
    element.visitChildElements(visitor);
  }

  final Element root = context as Element;
  root.visitChildElements(visitor);
  return result;
}
