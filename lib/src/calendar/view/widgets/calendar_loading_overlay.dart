// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Semi-transparent overlay with a centered [CalendarLoadingIndicator].
/// Used when the calendar or guest calendar blocks interactions during syncs.
class CalendarLoadingOverlay extends StatelessWidget {
  const CalendarLoadingOverlay({super.key, this.color, this.indicator});

  final Color? color;
  final Widget? indicator;

  @override
  Widget build(BuildContext context) {
    final overlayColor =
        color ?? context.colorScheme.background.withValues(alpha: 0.6);
    return Container(
      color: overlayColor,
      child: Center(child: indicator ?? const CalendarLoadingIndicator()),
    );
  }
}

class CalendarLoadingIndicator extends StatelessWidget {
  const CalendarLoadingIndicator({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final textTheme = context.textTheme;
    final String resolvedMessage =
        message ?? context.l10n.calendarLoadingMessage;
    final double indicatorSize = sizing.buttonHeightRegular;
    return AxiModalSurface(
      padding: EdgeInsets.all(spacing.m),
      backgroundColor: colors.card,
      borderColor: colors.border.withValues(alpha: 0.9),
      shadows: calendarMediumShadow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: indicatorSize,
            height: indicatorSize,
            child: _CalendarSpinner(
              size: indicatorSize,
              strokeWidth: sizing.progressIndicatorStrokeWidth,
              semanticsLabel: resolvedMessage,
            ),
          ),
          SizedBox(height: spacing.l),
          Text(
            resolvedMessage,
            style: textTheme.p.copyWith(color: colors.foreground),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CalendarSpinner extends StatefulWidget {
  const _CalendarSpinner({
    required this.size,
    this.strokeWidth,
    this.semanticsLabel,
  });

  final double size;
  final double? strokeWidth;
  final String? semanticsLabel;

  @override
  State<_CalendarSpinner> createState() => _CalendarSpinnerState();
}

class _CalendarSpinnerState extends State<_CalendarSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration:
          authCompletionAnimationDuration +
          calendarTaskSplitPreviewAnimationDuration,
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final palette = <Color>[colors.primary, axiGreen, colors.secondary];
    final double stroke =
        widget.strokeWidth ?? math.max(2.5, widget.size * 0.12);
    return Semantics(
      label: widget.semanticsLabel,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _CalendarSpinnerPainter(
                progress: _controller.value,
                colors: palette,
                strokeWidth: stroke,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CalendarSpinnerPainter extends CustomPainter {
  const _CalendarSpinnerPainter({
    required this.progress,
    required this.colors,
    required this.strokeWidth,
  });

  final double progress;
  final List<Color> colors;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: [colors[0], colors[1], colors[2], colors[0].withValues(alpha: 0)],
      stops: const [0, 0.5, 0.85, 1],
      transform: GradientRotation(progress * math.pi * 2),
    ).createShader(Offset.zero & size);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..shader = shader;
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    canvas.drawArc(rect, -math.pi / 2, math.pi * 1.65, false, paint);
  }

  @override
  bool shouldRepaint(covariant _CalendarSpinnerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        !listEquals(oldDelegate.colors, colors);
  }
}
