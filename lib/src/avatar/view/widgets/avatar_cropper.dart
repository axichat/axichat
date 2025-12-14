import 'dart:math';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AvatarCropper extends StatefulWidget {
  const AvatarCropper({
    super.key,
    required this.bytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.cropRect,
    required this.onCropChanged,
    required this.onCropReset,
    required this.colors,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.minCropSide = 48.0,
  });

  final Uint8List bytes;
  final double imageWidth;
  final double imageHeight;
  final Rect cropRect;
  final ValueChanged<Rect> onCropChanged;
  final VoidCallback onCropReset;
  final ShadColorScheme colors;
  final BorderRadius borderRadius;
  final double minCropSide;

  static Rect fallbackCropRect({
    required double imageWidth,
    required double imageHeight,
    double minCropSide = 48.0,
  }) {
    if (!imageWidth.isFinite ||
        !imageHeight.isFinite ||
        imageWidth <= 0 ||
        imageHeight <= 0) {
      return Rect.zero;
    }
    final minSide = min(imageWidth, imageHeight);
    final effectiveMinSide = min(minCropSide, minSide);
    final targetSide = minSide * 0.72;
    final safeSide = targetSide.clamp(effectiveMinSide, minSide);
    final left = (imageWidth - safeSide) / 2;
    final top = (imageHeight - safeSide) / 2;
    return Rect.fromLTWH(left, top, safeSide, safeSide);
  }

  @override
  State<AvatarCropper> createState() => _AvatarCropperState();
}

class _AvatarCropperState extends State<AvatarCropper> {
  static const double _maxDimension = 256.0;
  static const double _snapDistance = 12.0;

  late final CropController _controller = CropController();
  Rect? _lastArea;
  Rect? _pendingArea;
  bool _ready = false;

  @override
  void didUpdateWidget(covariant AvatarCropper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) {
      _controller.image = widget.bytes;
      _ready = false;
      _pendingArea = null;
      _lastArea = null;
    }
    if (widget.cropRect != oldWidget.cropRect) {
      final clamped = _clampToImage(widget.cropRect);
      _lastArea = clamped;
      _pendingArea = clamped;
      if (_ready) {
        _controller.area = clamped;
        _pendingArea = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasValidImage) {
      final colors = widget.colors;
      return SizedBox.square(
        dimension: _maxDimension,
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary,
              backgroundColor: colors.primary.withValues(alpha: 0.2),
            ),
          ),
        ),
      );
    }

    final requestedArea = widget.cropRect.isEmpty
        ? AvatarCropper.fallbackCropRect(
            imageWidth: widget.imageWidth,
            imageHeight: widget.imageHeight,
            minCropSide: widget.minCropSide,
          )
        : widget.cropRect;
    Rect initialArea = _clampToImage(requestedArea);
    if (!_isValidRect(initialArea)) {
      initialArea = AvatarCropper.fallbackCropRect(
        imageWidth: widget.imageWidth,
        imageHeight: widget.imageHeight,
        minCropSide: widget.minCropSide,
      );
    }
    _lastArea ??= initialArea;
    _pendingArea ??= initialArea;
    final colors = widget.colors;

    return SizedBox.square(
      dimension: _maxDimension,
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: widget.borderRadius,
            border: Border.all(color: colors.border),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Crop(
                      controller: _controller,
                      image: widget.bytes,
                      onCropped: (_) {},
                      aspectRatio: 1,
                      withCircleUi: true,
                      baseColor: colors.card,
                      maskColor: colors.background.withValues(alpha: 0.55),
                      radius: widget.borderRadius.topLeft.x,
                      initialRectBuilder:
                          InitialRectBuilder.withArea(initialArea),
                      willUpdateScale: (_) => false,
                      scrollZoomSensitivity: 0,
                      overlayBuilder: (context, rect) {
                        if (!_isValidRect(rect)) {
                          return const SizedBox.shrink();
                        }
                        return IgnorePointer(
                          ignoring: true,
                          child: CustomPaint(
                            size: rect.size,
                            painter: _CropGridPainter(
                              borderColor: colors.primary,
                              gridColor: colors.border,
                              radius: widget.borderRadius,
                            ),
                          ),
                        );
                      },
                      onMoved: (_, imageRect) {
                        if (!_isValidRect(imageRect)) return;
                        final clamped = _clampToImage(imageRect);
                        final snapped = _snapToCenter(clamped);
                        final previous = _lastArea;
                        if (previous != null &&
                            previous.left == snapped.left &&
                            previous.top == snapped.top &&
                            previous.width == snapped.width &&
                            previous.height == snapped.height) {
                          return;
                        }
                        if (_ready && snapped != imageRect) {
                          _controller.area = snapped;
                        }
                        _lastArea = snapped;
                        widget.onCropChanged(snapped);
                      },
                      onStatusChanged: (status) {
                        if (status == CropStatus.ready) {
                          _ready = true;
                          final targetArea =
                              _pendingArea ?? _lastArea ?? initialArea;
                          final safeTarget = _isValidRect(targetArea)
                              ? targetArea
                              : AvatarCropper.fallbackCropRect(
                                  imageWidth: widget.imageWidth,
                                  imageHeight: widget.imageHeight,
                                  minCropSide: widget.minCropSide,
                                );
                          _pendingArea = null;
                          _controller
                            ..withCircleUi = true
                            ..aspectRatio = 1
                            ..area = safeTarget;
                          _lastArea = safeTarget;
                        }
                      },
                      cornerDotBuilder: (size, alignment) => DotControl(
                        color: colors.primary,
                        padding: 7,
                      ),
                      progressIndicator: Center(
                        child: SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.primary,
                            backgroundColor:
                                colors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ),
                    const _CropScrollSignalForwarder(),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: () {
                    widget.onCropReset();
                    _lastArea = initialArea;
                    if (_ready) {
                      _controller.area = initialArea;
                      _pendingArea = null;
                    } else {
                      _pendingArea = initialArea;
                    }
                  },
                  child: const Icon(LucideIcons.refreshCcw, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasValidImage =>
      widget.imageWidth.isFinite &&
      widget.imageHeight.isFinite &&
      widget.imageWidth > 0 &&
      widget.imageHeight > 0;

  Rect _clampToImage(Rect rect) {
    if (!_hasValidImage) {
      return Rect.zero;
    }

    final maxSide = min(widget.imageWidth, widget.imageHeight);
    final minSide = min(widget.minCropSide, maxSide);
    final fallback = AvatarCropper.fallbackCropRect(
      imageWidth: widget.imageWidth,
      imageHeight: widget.imageHeight,
      minCropSide: widget.minCropSide,
    );
    if (!_isValidRect(rect)) return fallback;

    final targetWidth =
        rect.width.isFinite && rect.width > 0 ? rect.width : fallback.width;
    final targetHeight =
        rect.height.isFinite && rect.height > 0 ? rect.height : fallback.height;
    final width = targetWidth.clamp(minSide, maxSide);
    final height = targetHeight.clamp(minSide, maxSide);
    final maxLeft = widget.imageWidth - width;
    final maxTop = widget.imageHeight - height;
    final left = rect.left.isFinite
        ? rect.left.clamp(0.0, maxLeft)
        : (widget.imageWidth - width) / 2;
    final top = rect.top.isFinite
        ? rect.top.clamp(0.0, maxTop)
        : (widget.imageHeight - height) / 2;
    return Rect.fromLTWH(left, top, width, height);
  }

  Rect _snapToCenter(Rect rect) {
    if (!_isValidRect(rect)) return rect;
    final imageCenter = Offset(
      widget.imageWidth / 2,
      widget.imageHeight / 2,
    );
    if ((rect.center - imageCenter).distance <= _snapDistance) {
      return Rect.fromCenter(
        center: imageCenter,
        width: rect.width,
        height: rect.height,
      );
    }
    return rect;
  }
}

bool _isValidRect(Rect rect) =>
    rect.isFinite && rect.width > 0 && rect.height > 0;

class _CropScrollSignalForwarder extends StatelessWidget {
  const _CropScrollSignalForwarder();

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        final scrollable = Scrollable.maybeOf(context);
        final position = scrollable?.position;
        if (position == null) return;
        final target = (position.pixels + event.scrollDelta.dy)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
        if (target == position.pixels) return;
        position.jumpTo(target);
      },
      child: const SizedBox.expand(),
    );
  }
}

class _CropGridPainter extends CustomPainter {
  _CropGridPainter({
    required this.borderColor,
    required this.gridColor,
    required this.radius,
  });

  final Color borderColor;
  final Color gridColor;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: radius.topLeft,
      topRight: radius.topRight,
      bottomLeft: radius.bottomLeft,
      bottomRight: radius.bottomRight,
    );
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(rrect, borderPaint);

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    const thirds = [1 / 3, 2 / 3];
    for (final t in thirds) {
      final dx = rect.left + rect.width * t;
      final dy = rect.top + rect.height * t;
      canvas.drawLine(Offset(dx, rect.top), Offset(dx, rect.bottom), gridPaint);
      canvas.drawLine(Offset(rect.left, dy), Offset(rect.right, dy), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CropGridPainter oldDelegate) =>
      oldDelegate.borderColor != borderColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.radius != radius;
}
