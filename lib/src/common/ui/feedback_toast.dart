// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum FeedbackTone { success, info, warning, error }

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

  @override
  State<FeedbackToast> createState() => _FeedbackToastState();

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

  factory FeedbackToast.error({
    Key? key,
    String? title,
    String? message,
    Duration? duration,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
    Alignment alignment = Alignment.topRight,
    bool showCloseIconOnlyWhenHovered = false,
  }) {
    if (kEnableDemoChats) {
      return FeedbackToast.success(
        key: key,
        title: null,
        message: null,
        duration: duration,
        onTap: onTap,
        actionLabel: actionLabel,
        onAction: onAction,
        alignment: alignment,
        showCloseIconOnlyWhenHovered: showCloseIconOnlyWhenHovered,
      );
    }
    return FeedbackToast(
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
  }

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
      builder: (context) => AxiButton.link(
        size: AxiButtonSize.sm,
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

class _FeedbackToastState extends State<FeedbackToast> {
  final hovered = ValueNotifier(false);

  @override
  void dispose() {
    hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final effectiveToastTheme = switch (widget.variant) {
      ShadToastVariant.primary => theme.primaryToastTheme,
      ShadToastVariant.destructive => theme.destructiveToastTheme,
    };
    final effectiveForegroundColor = switch (widget.variant) {
      ShadToastVariant.primary => theme.colorScheme.foreground,
      ShadToastVariant.destructive => theme.colorScheme.destructiveForeground,
    };
    final effectiveCloseIcon = widget.closeIcon ??
        effectiveToastTheme.closeIcon ??
        ShadIconButton.ghost(
          icon: Icon(
            size: 16,
            widget.closeIconData ??
                effectiveToastTheme.closeIconData ??
                LucideIcons.x,
          ),
          width: 20,
          height: 20,
          padding: EdgeInsets.zero,
          foregroundColor: effectiveForegroundColor.withValues(alpha: .5),
          hoverBackgroundColor: Colors.transparent,
          hoverForegroundColor: effectiveForegroundColor,
          pressedForegroundColor: effectiveForegroundColor,
          onPressed: () => ShadToaster.of(context).hide(),
        );
    final effectiveTitleStyle = widget.titleStyle ??
        effectiveToastTheme.titleStyle ??
        theme.textTheme.muted.copyWith(
          fontWeight: FontWeight.w500,
          color: effectiveForegroundColor,
        );
    final effectiveDescriptionStyle = widget.descriptionStyle ??
        effectiveToastTheme.descriptionStyle ??
        theme.textTheme.muted.copyWith(
          color: effectiveForegroundColor.withValues(alpha: .9),
        );
    final effectiveActionPadding = widget.actionPadding ??
        effectiveToastTheme.actionPadding ??
        const EdgeInsets.only(left: 16);
    final effectiveBorder = widget.border ??
        effectiveToastTheme.border ??
        Border.all(color: theme.colorScheme.border);
    final effectiveBorderRadius =
        widget.radius ?? effectiveToastTheme.radius ?? theme.radius;
    final effectiveShadows =
        widget.shadows ?? effectiveToastTheme.shadows ?? ShadShadows.lg;
    final effectiveBackgroundColor = widget.backgroundColor ??
        effectiveToastTheme.backgroundColor ??
        theme.colorScheme.background;
    final effectivePadding = widget.padding ??
        effectiveToastTheme.padding ??
        const EdgeInsets.fromLTRB(24, 24, 32, 24);
    final effectiveCrossAxisAlignment = widget.crossAxisAlignment ??
        effectiveToastTheme.crossAxisAlignment ??
        CrossAxisAlignment.center;
    final effectiveCloseIconPosition = widget.closeIconPosition ??
        effectiveToastTheme.closeIconPosition ??
        const ShadPosition(top: 8, right: 8);
    final effectiveShowCloseIconOnlyWhenHovered =
        widget.showCloseIconOnlyWhenHovered ??
            effectiveToastTheme.showCloseIconOnlyWhenHovered ??
            true;

    return MouseRegion(
      onEnter: (_) => hovered.value = true,
      onExit: (_) => hovered.value = false,
      child: ShadResponsiveBuilder(
        builder: (context, breakpoint) {
          return UnconstrainedBox(
            constrainedAxis: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth:
                    breakpoint >= theme.breakpoints.md ? 0 : double.infinity,
                maxWidth:
                    breakpoint >= theme.breakpoints.md ? 420 : double.infinity,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: effectiveBorder,
                  borderRadius: effectiveBorderRadius,
                  boxShadow: effectiveShadows,
                  color: effectiveBackgroundColor,
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: effectivePadding,
                      child: Row(
                        textDirection: widget.textDirection,
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: effectiveCrossAxisAlignment,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.title != null)
                                  DefaultTextStyle(
                                    style: effectiveTitleStyle,
                                    child: widget.title!,
                                  ),
                                if (widget.description != null)
                                  DefaultTextStyle(
                                    style: effectiveDescriptionStyle,
                                    child: widget.description!,
                                  ),
                              ],
                            ),
                          ),
                          if (widget.action != null)
                            Padding(
                              padding: effectiveActionPadding,
                              child: widget.action,
                            ),
                        ],
                      ),
                    ),
                    ValueListenableBuilder(
                      valueListenable: hovered,
                      builder: (context, hovered, child) {
                        if (!effectiveShowCloseIconOnlyWhenHovered) {
                          return child!;
                        }
                        return Visibility.maintain(
                          visible: hovered,
                          child: child!,
                        );
                      },
                      child: effectiveCloseIcon,
                    ).positionedWith(effectiveCloseIconPosition),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
