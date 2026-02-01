// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:axichat/src/calendar/utils/responsive_helper.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    this.message,
    this.size,
    this.showMessage = true,
  });

  final String? message;
  final double? size;
  final bool showMessage;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final textTheme = context.textTheme;
    final double resolvedSize = size ?? sizing.progressIndicatorSize;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: resolvedSize,
            height: resolvedSize,
            child:
                _CalendarSpinner(size: resolvedSize, semanticsLabel: message),
          ),
          if (showMessage && message != null) ...[
            SizedBox(height: spacing.l),
            Text(
              message!,
              style: textTheme.small.copyWith(color: colors.foreground),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
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
            style: textTheme.p.copyWith(
              color: colors.foreground,
            ),
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
          authCompletionAnimationDuration + calendarTaskSplitPreviewAnimationDuration,
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

class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({
    super.key,
    this.width,
    this.height = axiSizing.menuItemIconSize,
    this.borderRadius = axiSizing.containerRadius,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration:
          authCompletionAnimationDuration + calendarScrollAnimationDuration,
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: calendarSelectedDayColor,
          ),
        );
      },
    );
  }
}

class TaskSkeletonTile extends StatelessWidget {
  const TaskSkeletonTile({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = ResponsiveHelper.spec(context);
        final double availableWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : spec.quickAddMaxWidth ??
                    ResponsiveHelper.sidebarDimensions(context).defaultWidth;
        final double primaryLineWidth = availableWidth * 0.6;
        final double secondaryLineWidth = availableWidth * 0.3;

        final double iconSize = context.sizing.iconButtonIconSize;
        final double menuIconSize = context.sizing.menuItemIconSize;
        final double labelHeight =
            context.textTheme.label.fontSize ?? menuIconSize;
        final double labelSmHeight =
            context.textTheme.labelSm.fontSize ?? menuIconSize;
        return Container(
          padding: calendarPaddingXl,
          margin: calendarMarginSmall,
          decoration: BoxDecoration(
            color: calendarContainerColor,
            borderRadius: BorderRadius.circular(context.sizing.containerRadius),
            border: Border.all(
              color: calendarBorderColor,
              width: context.borderSide.width,
            ),
          ),
          child: Row(
            children: [
              SkeletonLoader(
                width: iconSize,
                height: iconSize,
                borderRadius: context.sizing.containerRadius,
              ),
              const SizedBox(width: calendarGutterMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader(
                      width: double.infinity,
                      height: labelHeight,
                    ),
                    const SizedBox(height: calendarGutterSm),
                    SkeletonLoader(width: primaryLineWidth, height: labelSmHeight),
                    const SizedBox(height: calendarInsetMd),
                    SkeletonLoader(width: secondaryLineWidth, height: labelSmHeight),
                  ],
                ),
              ),
              const SizedBox(width: calendarGutterMd),
              SkeletonLoader(
                width: context.sizing.inputSuffixButtonSize,
                height: context.sizing.inputSuffixButtonSize,
                borderRadius: context.sizing.containerRadius,
              ),
            ],
          ),
        );
      },
    );
  }
}

class PulsatingIcon extends StatefulWidget {
  const PulsatingIcon({
    super.key,
    required this.icon,
    this.color,
    this.size = axiSizing.inputSuffixButtonSize,
  });

  final IconData icon;
  final Color? color;
  final double size;

  @override
  State<PulsatingIcon> createState() => _PulsatingIconState();
}

class _PulsatingIconState extends State<PulsatingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: authCompletionAnimationDuration,
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Icon(widget.icon, color: widget.color, size: widget.size),
        );
      },
    );
  }
}
