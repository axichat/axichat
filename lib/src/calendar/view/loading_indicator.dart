import 'package:flutter/material.dart';
import 'package:axichat/src/common/ui/ui.dart';

import '../utils/responsive_helper.dart';

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
            child: const CircularProgressIndicator(strokeWidth: 2),
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
    return Container(
      padding: calendarPaddingXl,
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        boxShadow: calendarMediumShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: calendarGutterLg),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: calendarTitleColor,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
