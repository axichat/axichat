import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _glyphStartScale = 0.2;
const double _glyphEndScale = 1.0;
const double _glyphStartOpacity = 0.0;
const double _glyphEndOpacity = 1.0;
const double _hiddenTextAlpha = 0.0;
const String typingGlyphMorphShaderAsset =
    'assets/shaders/typing_glyph_morph.frag';
const double _typingSdfScale = 4.0;
const double _typingSdfPadding = 8.0;
const double _typingSdfSpread = 8.0;
const double _typingSdfAlphaThreshold = 0.5;
const double _typingSdfEdgePixel = 1.0;
const double _typingSdfMidpoint = 0.5;
const double _typingSdfNormalizationDivisor = 2.0;
const int _typingSdfColorChannelCount = 4;
const int _typingSdfAlphaChannelOffset = 3;
const int _typingSdfChannelMax = 255;
const int _typingSdfDistanceMax = 1 << 20;
const int _typingSdfChamferOrth = 3;
const int _typingSdfChamferDiag = 4;
const int _typingSdfMaxDimension = 256;

Future<ui.FragmentProgram>? _typingGlyphMorphProgram;

Future<ui.FragmentProgram> loadTypingGlyphMorphProgram() {
  return _typingGlyphMorphProgram ??=
      ui.FragmentProgram.fromAsset(typingGlyphMorphShaderAsset);
}

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

@immutable
class TypingGlyphSdf {
  const TypingGlyphSdf({
    required this.image,
    required this.spread,
    required this.edge,
  });

  final ui.Image image;
  final double spread;
  final double edge;
}

@immutable
class TypingGlyphSdfKey {
  const TypingGlyphSdfKey({
    required this.text,
    required this.style,
    required this.textDirection,
    required this.textScaleFactor,
  });

  final String text;
  final TextStyle style;
  final TextDirection textDirection;
  final double textScaleFactor;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is TypingGlyphSdfKey &&
        other.text == text &&
        other.style == style &&
        other.textDirection == textDirection &&
        other.textScaleFactor == textScaleFactor;
  }

  @override
  int get hashCode => Object.hash(text, style, textDirection, textScaleFactor);
}

class TypingGlyphSdfCache {
  final Map<TypingGlyphSdfKey, TypingGlyphSdf> _cache =
      <TypingGlyphSdfKey, TypingGlyphSdf>{};
  final Map<TypingGlyphSdfKey, Future<TypingGlyphSdf?>> _inflight =
      <TypingGlyphSdfKey, Future<TypingGlyphSdf?>>{};

  Future<TypingGlyphSdf?> resolve({
    required String text,
    required TextStyle style,
    required TextDirection textDirection,
    required double textScaleFactor,
  }) {
    final TypingGlyphSdfKey key = TypingGlyphSdfKey(
      text: text,
      style: style,
      textDirection: textDirection,
      textScaleFactor: textScaleFactor,
    );
    final TypingGlyphSdf? cached = _cache[key];
    if (cached != null) {
      return Future<TypingGlyphSdf?>.value(cached);
    }
    final Future<TypingGlyphSdf?>? inflight = _inflight[key];
    if (inflight != null) {
      return inflight;
    }
    final Future<TypingGlyphSdf?> build = _buildGlyphSdf(key);
    _inflight[key] = build;
    build.then((TypingGlyphSdf? sdf) {
      if (sdf != null) {
        _cache[key] = sdf;
      }
      _inflight.remove(key);
    });
    return build;
  }

  void dispose() {
    for (final TypingGlyphSdf sdf in _cache.values) {
      sdf.image.dispose();
    }
    _cache.clear();
    _inflight.clear();
  }

  Future<TypingGlyphSdf?> _buildGlyphSdf(TypingGlyphSdfKey key) async {
    final double baseScale = key.textScaleFactor * _typingSdfScale;
    TypingGlyphSdfRender render = _buildSdfRender(key, baseScale);
    if (render.isEmpty) {
      return null;
    }
    final double maxDimension = _typingSdfMaxDimension.toDouble();
    final double largestSide =
        math.max(render.pixelSize.width, render.pixelSize.height);
    if (largestSide > maxDimension) {
      final double scaleClamp = maxDimension / largestSide;
      final double clampedScale = baseScale * scaleClamp;
      render = _buildSdfRender(key, clampedScale);
      if (render.isEmpty) {
        return null;
      }
    }

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder)
      ..translate(render.pixelPadding, render.pixelPadding);
    render.painter!.paint(canvas, Offset.zero);
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(
      render.pixelSize.width.round(),
      render.pixelSize.height.round(),
    );
    final ByteData? data =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (data == null) {
      return null;
    }

    final Uint8List rgba = data.buffer.asUint8List();
    final int width = render.pixelSize.width.round();
    final int height = render.pixelSize.height.round();
    final Uint8List inside = _buildInsideMask(rgba, width, height);
    final List<int> insideDistances =
        _computeChamferDistances(inside, width, height, true);
    final List<int> outsideDistances =
        _computeChamferDistances(inside, width, height, false);
    const double spread = _typingSdfSpread;
    final double spreadPixels = spread * render.pixelScale;
    final double edge = _typingSdfEdgePixel / spreadPixels;
    final Uint8List sdfBytes = _encodeSdfImage(
      inside,
      insideDistances,
      outsideDistances,
      width,
      height,
      spreadPixels,
    );
    final ui.Image sdfImage = await _decodeSdfImage(sdfBytes, width, height);
    return TypingGlyphSdf(image: sdfImage, spread: spread, edge: edge);
  }

  TypingGlyphSdfRender _buildSdfRender(
    TypingGlyphSdfKey key,
    double scale,
  ) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: key.text, style: key.style),
      textDirection: key.textDirection,
      textScaler: TextScaler.linear(scale),
    )..layout();
    final Size textSize = painter.size;
    if (textSize.isEmpty) {
      return const TypingGlyphSdfRender.empty();
    }
    final double pixelPadding = _typingSdfPadding * scale;
    final Size pixelSize = Size(
      textSize.width + pixelPadding * 2,
      textSize.height + pixelPadding * 2,
    );
    return TypingGlyphSdfRender(
      painter: painter,
      pixelSize: pixelSize,
      pixelPadding: pixelPadding,
      pixelScale: scale,
    );
  }
}

@immutable
class TypingGlyphSdfRender {
  const TypingGlyphSdfRender({
    required this.painter,
    required this.pixelSize,
    required this.pixelPadding,
    required this.pixelScale,
  });

  const TypingGlyphSdfRender.empty()
      : painter = null,
        pixelSize = Size.zero,
        pixelPadding = 0.0,
        pixelScale = 0.0;

  final TextPainter? painter;
  final Size pixelSize;
  final double pixelPadding;
  final double pixelScale;

  bool get isEmpty => painter == null || pixelSize.isEmpty;
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
  TypingGlyphSdf? _glyphSdf;
  double _glyphProgress = _glyphStartOpacity;
  ui.FragmentProgram? _morphProgram;

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

  TypingGlyphSdf? get glyphSdf => _glyphSdf;
  set glyphSdf(TypingGlyphSdf? value) {
    if (_glyphSdf == value) {
      return;
    }
    _glyphSdf = value;
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

  ui.FragmentProgram? get morphProgram => _morphProgram;
  set morphProgram(ui.FragmentProgram? value) {
    if (_morphProgram == value) {
      return;
    }
    _morphProgram = value;
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
    final TypingGlyphSdf? glyphSdf = _glyphSdf;
    final ui.FragmentProgram? morphProgram = _morphProgram;
    if (glyphSdf != null && morphProgram != null) {
      _paintGlyphSdfMorph(
        canvas,
        renderEditable,
        glyphAnimation,
        glyphSdf,
        morphProgram,
      );
      return;
    }

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

  void _paintGlyphSdfMorph(
    Canvas canvas,
    RenderEditable renderEditable,
    TypingGlyphAnimation glyphAnimation,
    TypingGlyphSdf glyphSdf,
    ui.FragmentProgram program,
  ) {
    final double progress = _glyphProgress.clamp(0.0, 1.0);
    final Rect glyphRect = glyphAnimation.targetRect;
    final Rect dotRect =
        Rect.fromCircle(center: glyphAnimation.startOffset, radius: _dotRadius);
    final Rect morphRect = glyphRect.expandToInclude(dotRect);
    final Offset rectOrigin = morphRect.topLeft;
    final Rect glyphLocalRect = glyphRect.shift(-rectOrigin);
    final Offset dotCenter = glyphAnimation.startOffset - rectOrigin;
    final Color baseColor = glyphAnimation.style.color ?? _dotColor;
    final double colorRed = baseColor.r;
    final double colorGreen = baseColor.g;
    final double colorBlue = baseColor.b;
    final double colorAlpha = baseColor.a;

    final ui.FragmentShader shader = program.fragmentShader()
      ..setFloat(0, rectOrigin.dx)
      ..setFloat(1, rectOrigin.dy)
      ..setFloat(2, morphRect.width)
      ..setFloat(3, morphRect.height)
      ..setFloat(4, glyphLocalRect.left)
      ..setFloat(5, glyphLocalRect.top)
      ..setFloat(6, glyphLocalRect.width)
      ..setFloat(7, glyphLocalRect.height)
      ..setFloat(8, dotCenter.dx)
      ..setFloat(9, dotCenter.dy)
      ..setFloat(10, _dotRadius)
      ..setFloat(11, progress)
      ..setFloat(12, glyphSdf.edge)
      ..setFloat(13, glyphSdf.spread)
      ..setFloat(14, colorRed)
      ..setFloat(15, colorGreen)
      ..setFloat(16, colorBlue)
      ..setFloat(17, colorAlpha)
      ..setImageSampler(0, glyphSdf.image);

    final Paint paint = Paint()..shader = shader;
    canvas.drawRect(morphRect, paint);
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

Uint8List _buildInsideMask(Uint8List rgba, int width, int height) {
  final int pixelCount = width * height;
  final Uint8List inside = Uint8List(pixelCount);
  final int alphaThreshold = (_typingSdfAlphaThreshold * _typingSdfChannelMax)
      .round()
      .clamp(0, _typingSdfChannelMax);
  for (int i = 0; i < pixelCount; i++) {
    final int alphaIndex =
        i * _typingSdfColorChannelCount + _typingSdfAlphaChannelOffset;
    inside[i] = rgba[alphaIndex] > alphaThreshold ? 1 : 0;
  }
  return inside;
}

List<int> _computeChamferDistances(
  Uint8List inside,
  int width,
  int height,
  bool targetInside,
) {
  final int pixelCount = width * height;
  final List<int> distances =
      List<int>.filled(pixelCount, _typingSdfDistanceMax);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int index = y * width + x;
      final bool isInside = inside[index] == 1;
      if (isInside != targetInside) {
        continue;
      }
      if (_isBoundaryPixel(inside, width, height, x, y)) {
        distances[index] = 0;
      }
    }
  }

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int index = y * width + x;
      final bool isInside = inside[index] == 1;
      if (isInside != targetInside) {
        continue;
      }
      int current = distances[index];
      if (x > 0) {
        current = math.min(
          current,
          distances[index - 1] + _typingSdfChamferOrth,
        );
      }
      if (y > 0) {
        current = math.min(
          current,
          distances[index - width] + _typingSdfChamferOrth,
        );
      }
      if (x > 0 && y > 0) {
        current = math.min(
          current,
          distances[index - width - 1] + _typingSdfChamferDiag,
        );
      }
      if (x < width - 1 && y > 0) {
        current = math.min(
          current,
          distances[index - width + 1] + _typingSdfChamferDiag,
        );
      }
      distances[index] = current;
    }
  }

  for (int y = height - 1; y >= 0; y--) {
    for (int x = width - 1; x >= 0; x--) {
      final int index = y * width + x;
      final bool isInside = inside[index] == 1;
      if (isInside != targetInside) {
        continue;
      }
      int current = distances[index];
      if (x < width - 1) {
        current = math.min(
          current,
          distances[index + 1] + _typingSdfChamferOrth,
        );
      }
      if (y < height - 1) {
        current = math.min(
          current,
          distances[index + width] + _typingSdfChamferOrth,
        );
      }
      if (x < width - 1 && y < height - 1) {
        current = math.min(
          current,
          distances[index + width + 1] + _typingSdfChamferDiag,
        );
      }
      if (x > 0 && y < height - 1) {
        current = math.min(
          current,
          distances[index + width - 1] + _typingSdfChamferDiag,
        );
      }
      distances[index] = current;
    }
  }

  return distances;
}

bool _isBoundaryPixel(
  Uint8List inside,
  int width,
  int height,
  int x,
  int y,
) {
  final int index = y * width + x;
  final int value = inside[index];
  for (int dy = -1; dy <= 1; dy++) {
    for (int dx = -1; dx <= 1; dx++) {
      if (dx == 0 && dy == 0) {
        continue;
      }
      final int nx = x + dx;
      final int ny = y + dy;
      if (nx < 0 || nx >= width || ny < 0 || ny >= height) {
        continue;
      }
      final int neighborIndex = ny * width + nx;
      if (inside[neighborIndex] != value) {
        return true;
      }
    }
  }
  return false;
}

Uint8List _encodeSdfImage(
  Uint8List inside,
  List<int> insideDistances,
  List<int> outsideDistances,
  int width,
  int height,
  double spreadPixels,
) {
  final int pixelCount = width * height;
  final Uint8List rgba = Uint8List(pixelCount * _typingSdfColorChannelCount);
  const double distanceScale = 1.0 / _typingSdfChamferOrth;
  final double normalizationScale =
      1.0 / (_typingSdfNormalizationDivisor * spreadPixels);

  for (int i = 0; i < pixelCount; i++) {
    final bool isInside = inside[i] == 1;
    final double distance = isInside
        ? -insideDistances[i] * distanceScale
        : outsideDistances[i] * distanceScale;
    final double normalized =
        (_typingSdfMidpoint + distance * normalizationScale).clamp(0.0, 1.0);
    final int value = (normalized * _typingSdfChannelMax)
        .round()
        .clamp(0, _typingSdfChannelMax);
    final int baseIndex = i * _typingSdfColorChannelCount;
    rgba
      ..[baseIndex] = value
      ..[baseIndex + 1] = value
      ..[baseIndex + 2] = value
      ..[baseIndex + 3] = _typingSdfChannelMax;
  }
  return rgba;
}

Future<ui.Image> _decodeSdfImage(
  Uint8List rgba,
  int width,
  int height,
) {
  final Completer<ui.Image> completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    (ui.Image image) {
      completer.complete(image);
    },
  );
  return completer.future;
}
