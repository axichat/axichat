import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
