// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _glyphStartOpacity = 0.0;
const double _glyphEndOpacity = 1.0;
const double _hiddenTextAlpha = 0.0;
const double _typingGlyphVisualOpacityMin = 0.22;
const double _typingGlyphScaleMin = 0.6;
const double _typingGlyphScaleMax = 1.0;
const Color _typingGlyphBaseColor = Colors.white;

enum TypingTextChangeKind { none, selection, insert, delete, replace }

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
    required this.range,
    required this.style,
  });

  final String text;
  final TextRange range;
  final TextStyle style;
}

@immutable
class TypingGlyphFrame {
  const TypingGlyphFrame({
    required this.animation,
    required this.progress,
    required this.rect,
  });

  final TypingGlyphAnimation animation;
  final double progress;
  final Rect rect;
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
  List<TextRange> _hiddenRanges = const <TextRange>[];

  List<TextRange> get hiddenRanges =>
      List<TextRange>.unmodifiable(_hiddenRanges);

  void updateSource(
    TextEditingController? source,
    TextEditingValue? initialValue,
  ) {
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
    final List<TextRange> ranges = range == null
        ? const <TextRange>[]
        : <TextRange>[range];
    setHiddenRanges(ranges);
  }

  void setHiddenRanges(List<TextRange> ranges) {
    final List<TextRange> nextRanges = _normalizedHiddenRanges(ranges);
    if (_rangesEqual(_hiddenRanges, nextRanges)) {
      return;
    }
    _hiddenRanges = nextRanges;
    notifyListeners();
  }

  void clearHiddenRange() => setHiddenRanges(const <TextRange>[]);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final String fullText = text;
    final TextRange composingRange = value.composing;
    final bool hasValidComposing = withComposing && value.isComposingRangeValid;
    final List<TextRange> hiddenRanges = _validatedHiddenRanges(
      fullText,
      _hiddenRanges,
    );
    if (!hasValidComposing && hiddenRanges.isEmpty) {
      return TextSpan(style: style, text: fullText);
    }

    final TextStyle baseStyle = DefaultTextStyle.of(context).style.merge(style);
    final TextStyle composingStyle = baseStyle.merge(
      const TextStyle(decoration: TextDecoration.underline),
    );
    final Color baseColor =
        baseStyle.color ?? ShadTheme.of(context).colorScheme.foreground;
    final Color hiddenColor = baseColor.withValues(alpha: _hiddenTextAlpha);
    final TextStyle hiddenStyle = _hiddenTextStyle(baseStyle, hiddenColor);

    final List<int> boundaries = <int>[0, fullText.length];
    if (hasValidComposing) {
      boundaries
        ..add(composingRange.start)
        ..add(composingRange.end);
    }
    if (hiddenRanges.isNotEmpty) {
      for (final TextRange range in hiddenRanges) {
        boundaries
          ..add(range.start)
          ..add(range.end);
      }
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
      final bool isHidden = _isHiddenRange(hiddenRanges, start, end);
      final bool isComposing =
          hasValidComposing &&
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

  List<TextRange> _validatedHiddenRanges(
    String fullText,
    List<TextRange> ranges,
  ) {
    if (ranges.isEmpty) {
      return const <TextRange>[];
    }
    final List<TextRange> valid = <TextRange>[];
    for (final TextRange range in ranges) {
      if (!range.isValid || range.isCollapsed) {
        continue;
      }
      if (range.start < 0 || range.end > fullText.length) {
        continue;
      }
      valid.add(range);
    }
    if (valid.length < 2) {
      return valid;
    }
    valid.sort((TextRange a, TextRange b) => a.start.compareTo(b.start));
    return valid;
  }

  bool _isHiddenRange(List<TextRange> ranges, int start, int end) {
    for (final TextRange range in ranges) {
      if (start >= range.start && end <= range.end) {
        return true;
      }
    }
    return false;
  }

  List<TextRange> _normalizedHiddenRanges(List<TextRange> ranges) {
    if (ranges.isEmpty) {
      return const <TextRange>[];
    }
    final Set<TextRange> unique = <TextRange>{}..addAll(ranges);
    final List<TextRange> normalized = unique.toList()
      ..sort((TextRange a, TextRange b) => a.start.compareTo(b.start));
    return normalized;
  }

  bool _rangesEqual(List<TextRange> a, List<TextRange> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  TextStyle _hiddenTextStyle(TextStyle style, Color hiddenColor) {
    final Paint hiddenPaint = Paint()..color = hiddenColor;
    return TextStyle(
      inherit: style.inherit,
      color: null,
      backgroundColor: null,
      fontSize: style.fontSize,
      fontWeight: style.fontWeight,
      fontStyle: style.fontStyle,
      letterSpacing: style.letterSpacing,
      wordSpacing: style.wordSpacing,
      textBaseline: style.textBaseline,
      height: style.height,
      leadingDistribution: style.leadingDistribution,
      locale: style.locale,
      background: null,
      shadows: style.shadows,
      fontFeatures: style.fontFeatures,
      fontVariations: style.fontVariations,
      decoration: TextDecoration.none,
      decorationColor: hiddenColor,
      decorationStyle: style.decorationStyle,
      decorationThickness: style.decorationThickness,
      debugLabel: style.debugLabel,
      fontFamily: style.fontFamily,
      fontFamilyFallback: style.fontFamilyFallback,
      overflow: style.overflow,
      foreground: hiddenPaint,
    );
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
    required Color caretColor,
    required double cursorWidth,
    required Radius? cursorRadius,
  }) : _caretColor = caretColor,
       _cursorWidth = cursorWidth,
       _cursorRadius = cursorRadius;

  Color _caretColor;
  double _cursorWidth;
  Radius? _cursorRadius;
  double _caretHeight = 0.0;
  Offset _caretOffset = Offset.zero;
  bool _showCaret = true;
  List<TypingGlyphFrame> _glyphFrames = const <TypingGlyphFrame>[];
  final Map<TypingGlyphAnimation, _TypingGlyphPicture> _glyphPictures =
      <TypingGlyphAnimation, _TypingGlyphPicture>{};
  bool _disposed = false;

  Color get caretColor => _caretColor;
  set caretColor(Color value) {
    if (_caretColor == value) {
      return;
    }
    _caretColor = value;
    notifyListeners();
  }

  double get cursorWidth => _cursorWidth;
  set cursorWidth(double value) {
    if (_cursorWidth == value) {
      return;
    }
    _cursorWidth = value;
    notifyListeners();
  }

  Radius? get cursorRadius => _cursorRadius;
  set cursorRadius(Radius? value) {
    if (_cursorRadius == value) {
      return;
    }
    _cursorRadius = value;
    notifyListeners();
  }

  double get caretHeight => _caretHeight;
  set caretHeight(double value) {
    if (_caretHeight == value) {
      return;
    }
    _caretHeight = value;
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

  List<TypingGlyphFrame> get glyphFrames => _glyphFrames;
  set glyphFrames(List<TypingGlyphFrame> value) {
    if (identical(_glyphFrames, value)) {
      return;
    }
    _glyphFrames = value;
    _pruneGlyphPictures(value);
    notifyListeners();
  }

  @override
  void paint(Canvas canvas, Size size, RenderEditable renderEditable) {
    final List<TypingGlyphFrame> glyphFrames = _glyphFrames;
    for (final TypingGlyphFrame frame in glyphFrames) {
      _paintGlyphMorph(canvas, renderEditable, frame);
    }

    final TextSelection? selection = renderEditable.selection;
    final bool shouldPaintCaret =
        selection != null &&
        selection.isValid &&
        selection.isCollapsed &&
        renderEditable.hasFocus &&
        _showCaret;
    if (!shouldPaintCaret) {
      return;
    }
    _paintCaretBar(canvas, renderEditable, _caretOffset, _glyphEndOpacity);
  }

  void _paintGlyphMorph(
    Canvas canvas,
    RenderEditable renderEditable,
    TypingGlyphFrame frame,
  ) {
    final double progress = frame.progress
        .clamp(_glyphStartOpacity, _glyphEndOpacity)
        .toDouble();
    if (progress <= _glyphStartOpacity) {
      return;
    }
    final TypingGlyphAnimation glyphAnimation = frame.animation;
    final Rect glyphRect = frame.rect;
    final _TypingGlyphPicture? picture =
        _glyphPictures[glyphAnimation] ??
        _createGlyphPicture(renderEditable, glyphAnimation);
    if (picture == null) {
      return;
    }
    _glyphPictures[glyphAnimation] = picture;

    final Color baseColor = glyphAnimation.style.color ?? _caretColor;
    final double glyphOpacity = ui.lerpDouble(
      _typingGlyphVisualOpacityMin,
      _glyphEndOpacity,
      progress,
    )!;
    final double glyphAlpha = (baseColor.a * glyphOpacity).clamp(
      _glyphStartOpacity,
      _glyphEndOpacity,
    );
    final Color glyphColor = baseColor.withValues(alpha: glyphAlpha.toDouble());
    final double scale = ui.lerpDouble(
      _typingGlyphScaleMin,
      _typingGlyphScaleMax,
      progress,
    )!;
    final double scaleX = picture.size.width <= 0
        ? scale
        : (glyphRect.width / picture.size.width) * scale;
    final double scaleY = picture.size.height <= 0
        ? scale
        : (glyphRect.height / picture.size.height) * scale;
    final Paint paint = Paint()
      ..colorFilter = ColorFilter.mode(glyphColor, BlendMode.modulate);
    canvas
      ..save()
      ..translate(glyphRect.center.dx, glyphRect.center.dy)
      ..scale(scaleX, scaleY)
      ..translate(-picture.size.width / 2, -picture.size.height / 2)
      ..saveLayer(Offset.zero & picture.size, paint)
      ..drawPicture(picture.picture)
      ..restore()
      ..restore();
  }

  _TypingGlyphPicture? _createGlyphPicture(
    RenderEditable renderEditable,
    TypingGlyphAnimation glyphAnimation,
  ) {
    final TextStyle pictureStyle = _glyphTextStyle(
      glyphAnimation.style,
      _typingGlyphBaseColor,
    );
    final TextPainter painter = TextPainter(
      text: TextSpan(text: glyphAnimation.text, style: pictureStyle),
      textDirection: renderEditable.textDirection,
      textScaler: renderEditable.textScaler,
      locale: renderEditable.locale,
    )..layout();
    final Size size = painter.size;
    if (size.width <= 0 || size.height <= 0) {
      return null;
    }
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    painter.paint(canvas, Offset.zero);
    if (_disposed) {
      final ui.Picture picture = recorder.endRecording();
      picture.dispose();
      return null;
    }
    return _TypingGlyphPicture(picture: recorder.endRecording(), size: size);
  }

  void _pruneGlyphPictures(List<TypingGlyphFrame> frames) {
    if (_glyphPictures.isEmpty) {
      return;
    }
    final Set<TypingGlyphAnimation> activeAnimations = frames
        .map((TypingGlyphFrame frame) => frame.animation)
        .toSet();
    final List<TypingGlyphAnimation> toRemove = <TypingGlyphAnimation>[];
    _glyphPictures.forEach((
      TypingGlyphAnimation key,
      _TypingGlyphPicture picture,
    ) {
      if (!activeAnimations.contains(key)) {
        toRemove.add(key);
      }
    });
    for (final TypingGlyphAnimation key in toRemove) {
      _glyphPictures.remove(key)?.dispose();
    }
  }

  void _paintCaretBar(
    Canvas canvas,
    RenderEditable renderEditable,
    Offset center,
    double opacity,
  ) {
    if (opacity <= 0) {
      return;
    }
    final double cursorWidth = _resolvedCursorWidth(renderEditable);
    final double caretHeight = _resolvedCaretHeight(renderEditable);
    if (cursorWidth <= 0 || caretHeight <= 0) {
      return;
    }
    final Rect caretRect = Rect.fromCenter(
      center: center,
      width: cursorWidth,
      height: caretHeight,
    );
    final double alpha = (_caretColor.a * opacity)
        .clamp(_glyphStartOpacity, _glyphEndOpacity)
        .toDouble();
    final Color color = _caretColor.withValues(alpha: alpha);
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final Radius? radius = _resolvedCursorRadius(renderEditable);
    if (radius != null && radius != Radius.zero) {
      canvas.drawRRect(RRect.fromRectAndRadius(caretRect, radius), paint);
      return;
    }
    canvas.drawRect(caretRect, paint);
  }

  double _resolvedCursorWidth(RenderEditable renderEditable) =>
      _cursorWidth > 0 ? _cursorWidth : renderEditable.cursorWidth;

  Radius? _resolvedCursorRadius(RenderEditable renderEditable) =>
      _cursorRadius ?? renderEditable.cursorRadius;

  double _resolvedCaretHeight(RenderEditable renderEditable) {
    if (_caretHeight > 0) {
      return _caretHeight;
    }
    return renderEditable.cursorHeight;
  }

  TextStyle _glyphTextStyle(TextStyle style, Color color) {
    final Paint paint = Paint()..color = color;
    return TextStyle(
      inherit: style.inherit,
      color: null,
      backgroundColor: style.backgroundColor,
      fontSize: style.fontSize,
      fontWeight: style.fontWeight,
      fontStyle: style.fontStyle,
      letterSpacing: style.letterSpacing,
      wordSpacing: style.wordSpacing,
      textBaseline: style.textBaseline,
      height: style.height,
      leadingDistribution: style.leadingDistribution,
      locale: style.locale,
      background: style.background,
      shadows: style.shadows,
      fontFeatures: style.fontFeatures,
      fontVariations: style.fontVariations,
      decoration: style.decoration,
      decorationColor: style.decorationColor,
      decorationStyle: style.decorationStyle,
      decorationThickness: style.decorationThickness,
      debugLabel: style.debugLabel,
      fontFamily: style.fontFamily,
      fontFamilyFallback: style.fontFamilyFallback,
      overflow: style.overflow,
      foreground: paint,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    for (final _TypingGlyphPicture picture in _glyphPictures.values.toList(
      growable: false,
    )) {
      picture.dispose();
    }
    _glyphPictures.clear();
    super.dispose();
  }

  @override
  bool shouldRepaint(RenderEditablePainter? oldDelegate) {
    if (identical(oldDelegate, this)) {
      return false;
    }
    return true;
  }
}

class _TypingGlyphPicture {
  const _TypingGlyphPicture({required this.picture, required this.size});

  final ui.Picture picture;
  final Size size;

  void dispose() {
    picture.dispose();
  }
}
