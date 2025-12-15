import 'dart:math' as math;

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:axichat/src/calendar/utils/responsive_helper.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    this.message,
    this.size = 24.0,
    this.showMessage = true,
  });

  final String? message;
  final double size;
  final bool showMessage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: _CalendarSpinner(
              size: size,
              semanticsLabel: message,
            ),
          ),
          if (showMessage && message != null) ...[
            const SizedBox(height: calendarGutterLg),
            Text(
              message!,
              style: calendarSubtitleTextStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class CalendarLoadingIndicator extends StatelessWidget {
  const CalendarLoadingIndicator({
    super.key,
    this.message = 'Loading calendar...',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Container(
      padding: calendarPaddingXl,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.9),
        ),
        boxShadow: calendarMediumShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: _CalendarSpinner(
              size: 42,
              strokeWidth: 4,
              semanticsLabel: message,
            ),
          ),
          const SizedBox(height: calendarGutterLg),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.foreground,
                      fontWeight: FontWeight.w600,
                    ) ??
                TextStyle(
                  fontSize: 16,
                  color: calendarTitleColor,
                  fontWeight: FontWeight.w600,
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
      duration: const Duration(milliseconds: 1100),
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
    final palette = <Color>[
      colors.primary,
      axiGreen,
      colors.secondary,
    ];
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
      colors: [
        colors[0],
        colors[1],
        colors[2],
        colors[0].withValues(alpha: 0),
      ],
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
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 1.65,
      false,
      paint,
    );
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
    this.height = 16,
    this.borderRadius = 4,
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
      duration: const Duration(milliseconds: 1500),
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

        return Container(
          padding: calendarPaddingXl,
          margin: calendarMarginSmall,
          decoration: BoxDecoration(
            color: calendarContainerColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: calendarBorderColor,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const SkeletonLoader(width: 20, height: 20, borderRadius: 10),
              const SizedBox(width: calendarGutterMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonLoader(width: double.infinity, height: 16),
                    const SizedBox(height: calendarGutterSm),
                    SkeletonLoader(
                      width: primaryLineWidth,
                      height: 12,
                    ),
                    const SizedBox(height: calendarInsetMd),
                    SkeletonLoader(
                      width: secondaryLineWidth,
                      height: 12,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: calendarGutterMd),
              const SkeletonLoader(width: 24, height: 24, borderRadius: 4),
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
    this.size = 24.0,
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
      duration: const Duration(milliseconds: 1000),
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
          child: Icon(
            widget.icon,
            color: widget.color,
            size: widget.size,
          ),
        );
      },
    );
  }
}
