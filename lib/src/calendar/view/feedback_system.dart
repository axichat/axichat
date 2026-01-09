// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';

const double _feedbackProgressCornerRadius = 999.0;

class FeedbackMessage {
  final String? title;
  final String message;
  final FeedbackTone tone;
  final Duration? duration;
  final VoidCallback? onTap;
  final String? actionLabel;
  final VoidCallback? onAction;

  const FeedbackMessage({
    this.title,
    required this.message,
    required this.tone,
    this.duration,
    this.onTap,
    this.actionLabel,
    this.onAction,
  });
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
          tone: FeedbackTone.success,
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
          tone: FeedbackTone.info,
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
          tone: FeedbackTone.warning,
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
          tone: FeedbackTone.error,
          duration: duration ?? const Duration(seconds: 5),
          onTap: onTap,
          actionLabel: actionLabel,
          onAction: onAction,
        ));
  }

  static void _showFeedback(BuildContext context, FeedbackMessage feedback) {
    final toaster = ShadToaster.maybeOf(context);
    if (toaster != null) {
      toaster.show(
        FeedbackToast(
          tone: feedback.tone,
          title: feedback.title,
          message: feedback.message,
          duration: feedback.duration,
          onTap: feedback.onTap,
          actionLabel: feedback.actionLabel,
          onAction: feedback.onAction,
        ),
      );
      return;
    }
    _showSnackBar(context, feedback);
  }

  static void _showSnackBar(
    BuildContext context,
    FeedbackMessage feedback,
  ) {
    final colorsForTone = _getColorsForTone(context, feedback.tone);

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: GestureDetector(
          onTap: feedback.onTap,
          child: Row(
            children: [
              Icon(
                _getIconForTone(feedback.tone),
                color: colorsForTone.foreground,
                size: 18,
              ),
              const SizedBox(width: calendarGutterSm),
              Expanded(
                child: Text(
                  feedback.message,
                  style: TextStyle(color: colorsForTone.foreground),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: colorsForTone.background,
        duration: feedback.duration ?? const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: feedback.actionLabel != null && feedback.onAction != null
            ? SnackBarAction(
                label: feedback.actionLabel!,
                onPressed: feedback.onAction!,
                textColor: colorsForTone.foreground,
              )
            : null,
        margin: calendarPaddingXl,
      ),
    );
  }

  static ({Color background, Color foreground}) _getColorsForTone(
    BuildContext context,
    FeedbackTone tone,
  ) {
    final scheme = ShadTheme.of(context).colorScheme;
    switch (tone) {
      case FeedbackTone.success:
        return (background: const Color(0xFF22C55E), foreground: Colors.white);
      case FeedbackTone.info:
        return (
          background: calendarPrimaryColor,
          foreground: scheme.primaryForeground,
        );
      case FeedbackTone.warning:
        return (background: const Color(0xFFF97316), foreground: Colors.white);
      case FeedbackTone.error:
        return (
          background: scheme.destructive,
          foreground: scheme.destructiveForeground,
        );
    }
  }

  static IconData _getIconForTone(FeedbackTone tone) {
    switch (tone) {
      case FeedbackTone.success:
        return Icons.check_circle_outline;
      case FeedbackTone.info:
        return Icons.info_outline;
      case FeedbackTone.warning:
        return Icons.warning_amber_outlined;
      case FeedbackTone.error:
        return Icons.error_outline;
    }
  }
}

class InlineFeedback extends StatelessWidget {
  const InlineFeedback({
    super.key,
    required this.message,
    required this.tone,
    this.onDismiss,
  });

  final String message;
  final FeedbackTone tone;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = FeedbackSystem._getColorsForTone(context, tone);

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
            FeedbackSystem._getIconForTone(tone),
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
          borderRadius: BorderRadius.circular(_feedbackProgressCornerRadius),
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
