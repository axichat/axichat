// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';

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
      ),
    );
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
      ),
    );
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
      ),
    );
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
      ),
    );
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

  static void _showSnackBar(BuildContext context, FeedbackMessage feedback) {
    final colorsForTone = _getColorsForTone(context, feedback.tone);
    final sizing = context.sizing;
    final textTheme = context.textTheme;

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
                size: sizing.iconButtonIconSize,
              ),
              const SizedBox(width: calendarGutterSm),
              Expanded(
                child: Text(
                  feedback.message,
                  style: textTheme.bodyMedium
                      .copyWith(color: colorsForTone.foreground),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: colorsForTone.background,
        duration: feedback.duration ?? const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(sizing.containerRadius),
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
    final scheme = context.colorScheme;
    switch (tone) {
      case FeedbackTone.success:
        return (background: scheme.green, foreground: scheme.primaryForeground);
      case FeedbackTone.info:
        return (
          background: calendarPrimaryColor,
          foreground: scheme.primaryForeground,
        );
      case FeedbackTone.warning:
        return (
          background: scheme.warning,
          foreground: scheme.primaryForeground,
        );
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
    final sizing = context.sizing;
    final textTheme = context.textTheme;
    final colors = FeedbackSystem._getColorsForTone(context, tone);

    return Container(
      padding: calendarPaddingLg,
      margin: const EdgeInsets.symmetric(vertical: calendarGutterSm),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.1),
        border: Border.all(
          color: colors.background.withValues(alpha: 0.3),
          width: context.borderSide.width,
        ),
        borderRadius: BorderRadius.circular(sizing.containerRadius),
      ),
      child: Row(
        children: [
          Icon(
            FeedbackSystem._getIconForTone(tone),
            color: colors.background,
            size: sizing.iconButtonIconSize,
          ),
          const SizedBox(width: calendarGutterSm),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodySmall.copyWith(color: colors.background),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: calendarGutterSm),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                Icons.close,
                color: colors.background,
                size: sizing.menuItemIconSize,
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
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: textTheme.bodySmall),
            if (showPercentage && progress != null)
              Text(
                context.l10n.commonPercentLabel(
                  (progress! * 100).toInt(),
                ),
                style: textTheme.bodySmall,
              ),
          ],
        ),
        const SizedBox(height: calendarGutterSm),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: colors.border.withValues(alpha: 0.6),
          valueColor: AlwaysStoppedAnimation<Color>(
            colors.primary,
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
    this.hapticFeedback = true,
  });

  final Widget child;
  final VoidCallback? onTap;
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
    if (widget.onTap == null) {
      return;
    }
    if (widget.hapticFeedback) {
      // HapticFeedback.lightImpact();
    }

    _runTapAnimation();

    widget.onTap?.call();
  }

  Future<void> _runTapAnimation() async {
    await _animationController.forward();
    if (!mounted) {
      return;
    }
    await _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap == null ? null : _handleTap,
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
