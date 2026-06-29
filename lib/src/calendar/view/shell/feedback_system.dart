// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/app.dart';
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
  static final Map<Object, OverlayEntry> _persistentFeedbackEntries =
      <Object, OverlayEntry>{};

  static void showTaskCopiedForPaste(BuildContext context) {
    final String message = switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS =>
        context.l10n.calendarTaskCopiedPasteInstructionTouch,
      TargetPlatform.fuchsia ||
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows =>
        context.l10n.calendarTaskCopiedPasteInstructionPointer,
    };
    showSuccess(context, message);
  }

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

  static void showPersistentInfo(
    BuildContext context,
    String message, {
    required Object id,
    String? title,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _showPersistentFeedback(
      context,
      FeedbackMessage(
        title: title,
        message: message,
        tone: FeedbackTone.info,
        onTap: onTap,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
      id: id,
    );
  }

  static void showPersistentError(
    BuildContext context,
    String message, {
    required Object id,
    String? title,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _showPersistentFeedback(
      context,
      FeedbackMessage(
        title: title,
        message: message,
        tone: FeedbackTone.error,
        onTap: onTap,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
      id: id,
    );
  }

  static void dismissPersistent(Object id) {
    final OverlayEntry? entry = _persistentFeedbackEntries.remove(id);
    if (entry?.mounted == true) {
      entry!.remove();
    }
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

  static void _showPersistentFeedback(
    BuildContext context,
    FeedbackMessage feedback, {
    required Object id,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      _showSnackBar(
        context,
        FeedbackMessage(
          title: feedback.title,
          message: feedback.message,
          tone: feedback.tone,
          duration: const Duration(days: 1),
          onTap: feedback.onTap,
          actionLabel: feedback.actionLabel,
          onAction: feedback.onAction,
        ),
      );
      return;
    }

    _persistentFeedbackEntries.remove(id)?.remove();

    late final OverlayEntry entry;
    void dismiss() {
      final current = _persistentFeedbackEntries[id];
      if (identical(current, entry)) {
        _persistentFeedbackEntries.remove(id);
      }
      if (entry.mounted) {
        entry.remove();
      }
    }

    entry = OverlayEntry(
      builder: (context) =>
          _PersistentFeedbackEntry(feedback: feedback, onDismiss: dismiss),
    );
    _persistentFeedbackEntries[id] = entry;
    overlay.insert(entry);
  }

  static void _showSnackBar(BuildContext context, FeedbackMessage feedback) {
    final colorsForTone = _getColorsForTone(context, feedback.tone);
    final sizing = context.sizing;
    final textTheme = context.textTheme;
    final spacing = context.spacing;

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
              SizedBox(width: spacing.s),
              Expanded(
                child: Text(
                  feedback.message,
                  style: textTheme.p.copyWith(color: colorsForTone.foreground),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: colorsForTone.background,
        duration: feedback.duration ?? const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: context.radius),
        action: feedback.actionLabel != null && feedback.onAction != null
            ? SnackBarAction(
                label: feedback.actionLabel!,
                onPressed: feedback.onAction!,
                textColor: colorsForTone.foreground,
              )
            : null,
        margin: EdgeInsets.all(spacing.m),
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

class _PersistentFeedbackEntry extends StatelessWidget {
  const _PersistentFeedbackEntry({
    required this.feedback,
    required this.onDismiss,
  });

  final FeedbackMessage feedback;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final bool compactWidth = MediaQuery.sizeOf(context).width < smallScreen;
    final Alignment alignment = compactWidth
        ? Alignment.topCenter
        : Alignment.topRight;
    return Positioned.fill(
      child: SafeArea(
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: EdgeInsets.all(context.spacing.m),
            child: FeedbackToast(
              tone: feedback.tone,
              title: feedback.title,
              message: feedback.message,
              onTap: feedback.onTap,
              actionLabel: feedback.actionLabel,
              onAction: feedback.onAction,
              onDismiss: onDismiss,
              alignment: alignment,
              showCloseIconOnlyWhenHovered: false,
            ),
          ),
        ),
      ),
    );
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
    final spacing = context.spacing;
    final colors = FeedbackSystem._getColorsForTone(context, tone);

    return Container(
      padding: EdgeInsets.all(spacing.m),
      margin: EdgeInsets.symmetric(vertical: spacing.s),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.1),
        border: Border.all(
          color: colors.background.withValues(alpha: 0.3),
          width: context.borderSide.width,
        ),
        borderRadius: context.radius,
      ),
      child: Row(
        children: [
          Icon(
            FeedbackSystem._getIconForTone(tone),
            color: colors.background,
            size: sizing.iconButtonIconSize,
          ),
          SizedBox(width: spacing.s),
          Expanded(
            child: Text(
              message,
              style: textTheme.small.copyWith(color: colors.background),
            ),
          ),
          if (onDismiss != null) ...[
            SizedBox(width: spacing.s),
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
            Text(label, style: textTheme.small),
            if (showPercentage && progress != null)
              Text(
                context.l10n.commonPercentLabel((progress! * 100).toInt()),
                style: textTheme.small,
              ),
          ],
        ),
        SizedBox(height: context.spacing.s),
        ShadProgress(
          value: progress,
          minHeight: context.sizing.progressIndicatorBarHeight,
          backgroundColor: colors.border.withValues(alpha: 0.6),
          color: colors.primary,
          borderRadius: BorderRadius.circular(_feedbackProgressCornerRadius),
          innerBorderRadius: BorderRadius.circular(
            _feedbackProgressCornerRadius,
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
      duration: calendarTaskSplitPreviewAnimationDuration,
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
