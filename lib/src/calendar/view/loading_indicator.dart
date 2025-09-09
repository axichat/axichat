import 'package:flutter/material.dart';
import 'package:axichat/src/common/ui/ui.dart';

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
            const SizedBox(height: 16),
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
    return Container(
      padding: calendarPadding16,
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLoader(width: double.infinity, height: 16),
                const SizedBox(height: 8),
                SkeletonLoader(
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: 12,
                ),
                const SizedBox(height: 4),
                SkeletonLoader(
                  width: MediaQuery.of(context).size.width * 0.3,
                  height: 12,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const SkeletonLoader(width: 24, height: 24, borderRadius: 4),
        ],
      ),
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
