import 'package:flutter/material.dart';

class FeedbackMessage {
  final String message;
  final FeedbackType type;
  final Duration? duration;
  final VoidCallback? onTap;

  const FeedbackMessage({
    required this.message,
    required this.type,
    this.duration,
    this.onTap,
  });
}

enum FeedbackType {
  success,
  info,
  warning,
  error,
}

class FeedbackSystem {
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration? duration,
    VoidCallback? onTap,
  }) {
    _showFeedback(
        context,
        FeedbackMessage(
          message: message,
          type: FeedbackType.success,
          duration: duration ?? const Duration(seconds: 3),
          onTap: onTap,
        ));
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration? duration,
    VoidCallback? onTap,
  }) {
    _showFeedback(
        context,
        FeedbackMessage(
          message: message,
          type: FeedbackType.info,
          duration: duration ?? const Duration(seconds: 3),
          onTap: onTap,
        ));
  }

  static void showWarning(
    BuildContext context,
    String message, {
    Duration? duration,
    VoidCallback? onTap,
  }) {
    _showFeedback(
        context,
        FeedbackMessage(
          message: message,
          type: FeedbackType.warning,
          duration: duration ?? const Duration(seconds: 4),
          onTap: onTap,
        ));
  }

  static void _showFeedback(BuildContext context, FeedbackMessage feedback) {
    final colors = _getColorsForType(context, feedback.type);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: GestureDetector(
          onTap: feedback.onTap,
          child: Row(
            children: [
              Icon(
                _getIconForType(feedback.type),
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  feedback.message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: colors.background,
        duration: feedback.duration ?? const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  static ({Color background, Color foreground}) _getColorsForType(
    BuildContext context,
    FeedbackType type,
  ) {
    switch (type) {
      case FeedbackType.success:
        return (background: Colors.green.shade600, foreground: Colors.white);
      case FeedbackType.info:
        return (background: Colors.blue.shade600, foreground: Colors.white);
      case FeedbackType.warning:
        return (background: Colors.orange.shade600, foreground: Colors.white);
      case FeedbackType.error:
        return (background: Colors.red.shade600, foreground: Colors.white);
    }
  }

  static IconData _getIconForType(FeedbackType type) {
    switch (type) {
      case FeedbackType.success:
        return Icons.check_circle_outline;
      case FeedbackType.info:
        return Icons.info_outline;
      case FeedbackType.warning:
        return Icons.warning_amber_outlined;
      case FeedbackType.error:
        return Icons.error_outline;
    }
  }
}

class InlineFeedback extends StatelessWidget {
  const InlineFeedback({
    super.key,
    required this.message,
    required this.type,
    this.onDismiss,
  });

  final String message;
  final FeedbackType type;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = FeedbackSystem._getColorsForType(context, type);

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.1),
        border: Border.all(
          color: colors.background.withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            FeedbackSystem._getIconForType(type),
            color: colors.background,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.background,
                fontSize: 14,
              ),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                Icons.close,
                color: colors.background,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ProgressIndicator extends StatelessWidget {
  const ProgressIndicator({
    super.key,
    required this.label,
    this.progress,
    this.showPercentage = false,
  });

  final String label;
  final double? progress;
  final bool showPercentage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (showPercentage && progress != null)
              Text(
                '${(progress! * 100).toInt()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class ActionFeedback extends StatefulWidget {
  const ActionFeedback({
    super.key,
    required this.child,
    this.onTap,
    this.feedbackMessage,
    this.hapticFeedback = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? feedbackMessage;
  final bool hapticFeedback;

  @override
  State<ActionFeedback> createState() => _ActionFeedbackState();
}

class _ActionFeedbackState extends State<ActionFeedback>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.hapticFeedback) {
      // HapticFeedback.lightImpact();
    }

    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    widget.onTap?.call();

    if (widget.feedbackMessage != null) {
      FeedbackSystem.showSuccess(context, widget.feedbackMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: widget.child,
          );
        },
      ),
    );
  }
}
