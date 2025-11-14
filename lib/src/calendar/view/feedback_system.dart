import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../common/ui/ui.dart';

class FeedbackMessage {
  final String? title;
  final String message;
  final FeedbackType type;
  final Duration? duration;
  final VoidCallback? onTap;
  final String? actionLabel;
  final VoidCallback? onAction;

  const FeedbackMessage({
    this.title,
    required this.message,
    required this.type,
    this.duration,
    this.onTap,
    this.actionLabel,
    this.onAction,
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
    String? title,
    Duration? duration,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _showFeedback(
        context,
        FeedbackMessage(
          title: title,
          message: message,
          type: FeedbackType.success,
          duration: duration ?? const Duration(seconds: 3),
          onTap: onTap,
          actionLabel: actionLabel,
          onAction: onAction,
        ));
  }

  static void showInfo(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _showFeedback(
        context,
        FeedbackMessage(
          title: title,
          message: message,
          type: FeedbackType.info,
          duration: duration ?? const Duration(seconds: 3),
          onTap: onTap,
          actionLabel: actionLabel,
          onAction: onAction,
        ));
  }

  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _showFeedback(
        context,
        FeedbackMessage(
          title: title,
          message: message,
          type: FeedbackType.warning,
          duration: duration ?? const Duration(seconds: 4),
          onTap: onTap,
          actionLabel: actionLabel,
          onAction: onAction,
        ));
  }

  static void showError(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _showFeedback(
        context,
        FeedbackMessage(
          title: title,
          message: message,
          type: FeedbackType.error,
          duration: duration ?? const Duration(seconds: 5),
          onTap: onTap,
          actionLabel: actionLabel,
          onAction: onAction,
        ));
  }

  static void _showFeedback(BuildContext context, FeedbackMessage feedback) {
    final toaster = ShadToaster.maybeOf(context);
    if (toaster != null) {
      toaster.show(_buildToast(context, feedback));
      return;
    }
    _showSnackBar(context, feedback);
  }

  static ShadToast _buildToast(
    BuildContext context,
    FeedbackMessage feedback,
  ) {
    final toastTitle = feedback.title ?? _toastTitleFor(feedback.type);
    final duration = feedback.duration ?? _defaultDurationFor(feedback.type);
    final hasAction = feedback.actionLabel != null && feedback.onAction != null;
    final action = hasAction
        ? Builder(
            builder: (actionContext) => ShadButton.link(
              size: ShadButtonSize.sm,
              child: Text(feedback.actionLabel!),
              onPressed: () {
                ShadToaster.of(actionContext).hide();
                feedback.onAction?.call();
              },
            ),
          )
        : null;
    final description = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: feedback.onTap,
      child: Text(feedback.message),
    );
    final commonProps = (
      title: toastTitle == null ? null : Text(toastTitle),
      description: description,
      action: action,
      alignment: Alignment.topRight,
      duration: duration,
      showCloseIconOnlyWhenHovered: false,
    );
    return switch (_toastVariantForType(feedback.type)) {
      ShadToastVariant.destructive => ShadToast.destructive(
          title: commonProps.title,
          description: commonProps.description,
          action: commonProps.action,
          alignment: commonProps.alignment,
          duration: commonProps.duration,
          showCloseIconOnlyWhenHovered:
              commonProps.showCloseIconOnlyWhenHovered,
        ),
      ShadToastVariant.primary => ShadToast(
          title: commonProps.title,
          description: commonProps.description,
          action: commonProps.action,
          alignment: commonProps.alignment,
          duration: commonProps.duration,
          showCloseIconOnlyWhenHovered:
              commonProps.showCloseIconOnlyWhenHovered,
        ),
    };
  }

  static void _showSnackBar(
    BuildContext context,
    FeedbackMessage feedback,
  ) {
    final colors = _getColorsForType(context, feedback.type);

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      // Fallback: try to find ScaffoldMessenger in the root context
      debugPrint(
          'Warning: ScaffoldMessenger not found for feedback: ${feedback.message}');
      return;
    }

    messenger.showSnackBar(
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
              const SizedBox(width: calendarGutterSm),
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
        action: feedback.actionLabel != null && feedback.onAction != null
            ? SnackBarAction(
                label: feedback.actionLabel!,
                onPressed: feedback.onAction!,
                textColor: colors.foreground,
              )
            : null,
        margin: calendarPaddingXl,
      ),
    );
  }

  static ShadToastVariant _toastVariantForType(FeedbackType type) {
    switch (type) {
      case FeedbackType.warning:
      case FeedbackType.error:
        return ShadToastVariant.destructive;
      case FeedbackType.success:
      case FeedbackType.info:
        return ShadToastVariant.primary;
    }
  }

  static String? _toastTitleFor(FeedbackType type) {
    switch (type) {
      case FeedbackType.success:
        return 'Success!';
      case FeedbackType.info:
        return 'Heads up';
      case FeedbackType.warning:
      case FeedbackType.error:
        return 'Whoops!';
    }
  }

  static Duration _defaultDurationFor(FeedbackType type) {
    switch (type) {
      case FeedbackType.success:
      case FeedbackType.info:
        return const Duration(seconds: 3);
      case FeedbackType.warning:
        return const Duration(seconds: 4);
      case FeedbackType.error:
        return const Duration(seconds: 5);
    }
  }

  static ({Color background, Color foreground}) _getColorsForType(
    BuildContext context,
    FeedbackType type,
  ) {
    final scheme = ShadTheme.of(context).colorScheme;
    switch (type) {
      case FeedbackType.success:
        return (background: const Color(0xFF22C55E), foreground: Colors.white);
      case FeedbackType.info:
        return (
          background: calendarPrimaryColor,
          foreground: scheme.primaryForeground,
        );
      case FeedbackType.warning:
        return (background: const Color(0xFFF97316), foreground: Colors.white);
      case FeedbackType.error:
        return (
          background: scheme.destructive,
          foreground: scheme.destructiveForeground,
        );
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
      padding: calendarPaddingLg,
      margin: const EdgeInsets.symmetric(vertical: calendarGutterSm),
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
          const SizedBox(width: calendarGutterSm),
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
            const SizedBox(width: calendarGutterSm),
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
        const SizedBox(height: calendarGutterSm),
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
