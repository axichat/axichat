// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:typed_data';

import 'package:animations/animations.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/avatar/avatar_presentation.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';

const String fallbackSignupAvatarAssetPath =
    'assets/images/avatars/abstract/abstract1.png';

class SignupAvatarPreview extends StatefulWidget {
  const SignupAvatarPreview({
    super.key,
    required this.bytes,
    required this.displayLabel,
    required this.size,
    required this.animationDuration,
    required this.rotationDuration,
    required this.rotationStartedAt,
    required this.showRotationTimer,
    required this.transitionKey,
  });

  final Uint8List? bytes;
  final String displayLabel;
  final double size;
  final Duration animationDuration;
  final Duration rotationDuration;
  final DateTime? rotationStartedAt;
  final bool showRotationTimer;
  final Object transitionKey;

  @override
  State<SignupAvatarPreview> createState() => _SignupAvatarPreviewState();
}

class _SignupAvatarPreviewState extends State<SignupAvatarPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timerController = AnimationController(
    vsync: this,
    duration: widget.rotationDuration,
  );
  bool _fallbackAvatarPrecached = false;

  @override
  void initState() {
    super.initState();
    _syncTimer(restart: widget.showRotationTimer);
  }

  @override
  void didUpdateWidget(covariant SignupAvatarPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rotationDuration != widget.rotationDuration) {
      _timerController.duration = widget.rotationDuration;
    }
    final shouldRestartTimer =
        oldWidget.transitionKey != widget.transitionKey ||
        oldWidget.showRotationTimer != widget.showRotationTimer ||
        oldWidget.rotationDuration != widget.rotationDuration ||
        oldWidget.rotationStartedAt != widget.rotationStartedAt;
    _syncTimer(restart: shouldRestartTimer);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fallbackAvatarPrecached) return;
    _fallbackAvatarPrecached = true;
    precacheImage(const AssetImage(fallbackSignupAvatarAssetPath), context);
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final radii = context.radii;
    final sizing = context.sizing;
    final borderSide = context.borderSide;
    final frameStrokeWidth = borderSide.width * 4;
    final previewInset = frameStrokeWidth / 2;
    final previewSize = (widget.size - frameStrokeWidth)
        .clamp(0.0, widget.size)
        .toDouble();
    final sizeSpan = sizing.iconButtonSize - sizing.iconButtonIconSize;
    final previewProgress = sizeSpan <= 0
        ? 1.0
        : ((previewSize - sizing.iconButtonIconSize) / sizeSpan)
              .clamp(0.0, 1.0)
              .toDouble();
    final sharedCornerRadius =
        radii.squircleSm +
        ((radii.squircle - radii.squircleSm) * previewProgress);
    final previewShape = SquircleBorder(cornerRadius: sharedCornerRadius);
    final resolvedBytes = widget.bytes;
    final hasBytes = resolvedBytes != null && resolvedBytes.isNotEmpty;

    return SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(
        foregroundPainter: widget.showRotationTimer
            ? _AvatarCountdownBorderPainter(
                progress: _timerController,
                activeColor: colors.primary,
                trackColor: colors.border,
                strokeWidth: frameStrokeWidth,
                cornerRadius: sharedCornerRadius,
              )
            : null,
        child: Padding(
          padding: EdgeInsets.all(previewInset),
          child: PageTransitionSwitcher(
            duration: widget.animationDuration,
            transitionBuilder: (child, primaryAnimation, secondaryAnimation) =>
                FadeTransition(
                  opacity: primaryAnimation,
                  child: FadeTransition(
                    opacity: ReverseAnimation(secondaryAnimation),
                    child: child,
                  ),
                ),
            child: hasBytes
                ? AxiAvatar(
                    key: ValueKey(widget.transitionKey),
                    avatar: AvatarPresentation.avatar(
                      label: widget.displayLabel,
                      colorSeed: widget.displayLabel,
                      loading: false,
                    ),
                    size: previewSize,
                    shape: AxiAvatarShape.squircle,
                    subscription: Subscription.none,
                    presence: null,
                    avatarBytes: resolvedBytes,
                  )
                : SizedBox.square(
                    key: ValueKey(widget.transitionKey),
                    dimension: previewSize,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: colors.card,
                        shape: previewShape,
                      ),
                      child: ClipPath(
                        clipper: ShapeBorderClipper(shape: previewShape),
                        child: Image.asset(
                          fallbackSignupAvatarAssetPath,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _syncTimer({required bool restart}) {
    if (!widget.showRotationTimer) {
      _timerController
        ..stop()
        ..value = 0;
      return;
    }
    final startedAt = widget.rotationStartedAt ?? DateTime.timestamp();
    final elapsed = DateTime.timestamp().difference(startedAt);
    final progress = widget.rotationDuration.inMicroseconds <= 0
        ? 1.0
        : (elapsed.inMicroseconds / widget.rotationDuration.inMicroseconds)
              .clamp(0.0, 1.0)
              .toDouble();
    if (restart) {
      _timerController.value = progress;
      if (progress < 1) {
        _timerController.forward();
      }
      return;
    }
    if (!_timerController.isAnimating) {
      _timerController.forward();
    }
  }
}

class _AvatarCountdownBorderPainter extends CustomPainter {
  _AvatarCountdownBorderPainter({
    required Animation<double> progress,
    required this.activeColor,
    required this.trackColor,
    required this.strokeWidth,
    required this.cornerRadius,
  }) : _progress = progress,
       super(repaint: progress);

  final Animation<double> _progress;
  final Color activeColor;
  final Color trackColor;
  final double strokeWidth;
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (strokeWidth <= 0) {
      return;
    }
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final borderPath = SquircleBorder(
      cornerRadius: cornerRadius,
    ).getOuterPath(rect);
    final metrics = borderPath.computeMetrics().toList();
    if (metrics.isEmpty) {
      return;
    }
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    var totalLength = 0.0;
    for (final metric in metrics) {
      totalLength += metric.length;
    }
    final clampedRemaining = (1 - _progress.value).clamp(0.0, 1.0).toDouble();
    final remainingLength = totalLength * clampedRemaining;
    final startDistance = totalLength - remainingLength;
    var accumulatedLength = 0.0;
    for (final metric in metrics) {
      final metricStart = accumulatedLength;
      final metricEnd = accumulatedLength + metric.length;
      final drawStart = startDistance > metricStart
          ? startDistance - metricStart
          : 0.0;
      if (drawStart > 0) {
        canvas.drawPath(metric.extractPath(0, drawStart), trackPaint);
      }
      if (drawStart < metric.length && startDistance < metricEnd) {
        canvas.drawPath(
          metric.extractPath(drawStart, metric.length),
          activePaint,
        );
      }
      accumulatedLength = metricEnd;
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarCountdownBorderPainter oldDelegate) {
    return oldDelegate._progress != _progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.cornerRadius != cornerRadius;
  }
}
