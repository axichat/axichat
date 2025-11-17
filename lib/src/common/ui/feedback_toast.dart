import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum FeedbackTone {
  success,
  info,
  warning,
  error,
}

class FeedbackToast extends ShadToast {
  FeedbackToast({
    super.key,
    required FeedbackTone tone,
    String? title,
    String? message,
    Duration? duration,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
    Alignment alignment = Alignment.topRight,
    bool showCloseIconOnlyWhenHovered = false,
  }) : super.raw(
          variant: _variantForTone(tone),
          title: _textOrNull(title ?? _defaultTitleForTone(tone)),
          description: message == null
              ? null
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: Text(message),
                ),
          action: _actionWidget(actionLabel, onAction),
          alignment: alignment,
          duration: duration ?? _defaultDurationForTone(tone),
          showCloseIconOnlyWhenHovered: showCloseIconOnlyWhenHovered,
        );

  FeedbackToast.success({
    Key? key,
    String? title,
    String? message,
    Duration? duration,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
    Alignment alignment = Alignment.topRight,
    bool showCloseIconOnlyWhenHovered = false,
  }) : this(
          key: key,
          tone: FeedbackTone.success,
          title: title,
          message: message,
          duration: duration,
          onTap: onTap,
          actionLabel: actionLabel,
          onAction: onAction,
          alignment: alignment,
          showCloseIconOnlyWhenHovered: showCloseIconOnlyWhenHovered,
        );

  FeedbackToast.info({
    Key? key,
    String? title,
    String? message,
    Duration? duration,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
    Alignment alignment = Alignment.topRight,
    bool showCloseIconOnlyWhenHovered = false,
  }) : this(
          key: key,
          tone: FeedbackTone.info,
          title: title,
          message: message,
          duration: duration,
          onTap: onTap,
          actionLabel: actionLabel,
          onAction: onAction,
          alignment: alignment,
          showCloseIconOnlyWhenHovered: showCloseIconOnlyWhenHovered,
        );

  FeedbackToast.warning({
    Key? key,
    String? title,
    String? message,
    Duration? duration,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
    Alignment alignment = Alignment.topRight,
    bool showCloseIconOnlyWhenHovered = false,
  }) : this(
          key: key,
          tone: FeedbackTone.warning,
          title: title,
          message: message,
          duration: duration,
          onTap: onTap,
          actionLabel: actionLabel,
          onAction: onAction,
          alignment: alignment,
          showCloseIconOnlyWhenHovered: showCloseIconOnlyWhenHovered,
        );

  FeedbackToast.error({
    Key? key,
    String? title,
    String? message,
    Duration? duration,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
    Alignment alignment = Alignment.topRight,
    bool showCloseIconOnlyWhenHovered = false,
  }) : this(
          key: key,
          tone: FeedbackTone.error,
          title: title,
          message: message,
          duration: duration,
          onTap: onTap,
          actionLabel: actionLabel,
          onAction: onAction,
          alignment: alignment,
          showCloseIconOnlyWhenHovered: showCloseIconOnlyWhenHovered,
        );

  static Text? _textOrNull(String? value) {
    if (value == null) {
      return null;
    }
    return Text(value);
  }

  static Widget? _actionWidget(String? label, VoidCallback? onAction) {
    if (label == null || onAction == null) {
      return null;
    }
    return Builder(
      builder: (context) => ShadButton.link(
        size: ShadButtonSize.sm,
        child: Text(label),
        onPressed: () {
          ShadToaster.of(context).hide();
          onAction();
        },
      ),
    );
  }

  static ShadToastVariant _variantForTone(FeedbackTone tone) {
    switch (tone) {
      case FeedbackTone.warning:
      case FeedbackTone.error:
        return ShadToastVariant.destructive;
      case FeedbackTone.success:
      case FeedbackTone.info:
        return ShadToastVariant.primary;
    }
  }

  static String? _defaultTitleForTone(FeedbackTone tone) {
    switch (tone) {
      case FeedbackTone.success:
        return 'Success!';
      case FeedbackTone.info:
        return 'Heads up';
      case FeedbackTone.warning:
      case FeedbackTone.error:
        return 'Whoops!';
    }
  }

  static Duration _defaultDurationForTone(FeedbackTone tone) {
    switch (tone) {
      case FeedbackTone.success:
      case FeedbackTone.info:
        return const Duration(seconds: 3);
      case FeedbackTone.warning:
        return const Duration(seconds: 4);
      case FeedbackTone.error:
        return const Duration(seconds: 5);
    }
  }
}
