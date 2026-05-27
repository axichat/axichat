// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum FeedbackTone { success, info, warning, error }

class FeedbackToast extends ShadToast {
  FeedbackToast({
    super.key,
    required this.tone,
    String? title,
    String? message,
    Duration? duration,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
    Alignment? alignment,
    bool showCloseIconOnlyWhenHovered = false,
  }) : super.raw(
         variant: _variantForTone(tone),
         title: _textOrNull(_titleForTone(tone, title, message)),
         description: message == null
             ? null
             : GestureDetector(
                 behavior: HitTestBehavior.opaque,
                 onTap: onTap,
                 child: Text(
                   message,
                   maxLines: _descriptionMaxLines,
                   overflow: TextOverflow.ellipsis,
                 ),
               ),
         action: _actionWidget(actionLabel, onAction),
         alignment: alignment ?? _defaultAlignment,
         duration: duration ?? _defaultDurationForTone(tone),
         showCloseIconOnlyWhenHovered: showCloseIconOnlyWhenHovered,
       );

  static const int _titleMaxLines = 1;
  static const int _descriptionMaxLines = 2;

  final FeedbackTone tone;

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
    Alignment? alignment,
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
    Alignment? alignment,
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
    Alignment? alignment,
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
    Alignment? alignment,
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

  static Text? _textOrNull(String? value, {int? maxLines}) {
    if (value == null) {
      return null;
    }
    final int resolvedMaxLines = maxLines ?? _titleMaxLines;
    return Text(
      value,
      maxLines: resolvedMaxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  static String? _titleForTone(
    FeedbackTone tone,
    String? title,
    String? message,
  ) {
    if (title != null || message != null) {
      return title;
    }
    return _defaultTitleForTone(tone);
  }

  static Alignment get _defaultAlignment {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      return Alignment.topRight;
    }
    final view = views.first;
    final double width = view.physicalSize.width / view.devicePixelRatio;
    return _isCompactToastWidth(width)
        ? Alignment.topCenter
        : Alignment.topRight;
  }

  static bool _isCompactToastWidth(double width) {
    return width < smallScreen;
  }

  static Widget? _actionWidget(String? label, VoidCallback? onAction) {
    if (label == null || onAction == null) {
      return null;
    }
    return Builder(
      builder: (context) => AxiButton.outline(
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
  final dismissibleKey = UniqueKey();

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
    final Color? toneColor = switch (widget.tone) {
      FeedbackTone.success => theme.colorScheme.green,
      FeedbackTone.info => null,
      FeedbackTone.warning => null,
      FeedbackTone.error => null,
    };
    final effectiveForegroundColor = switch (widget.variant) {
      ShadToastVariant.primary => theme.colorScheme.foreground,
      ShadToastVariant.destructive => theme.colorScheme.destructiveForeground,
    };
    final effectiveCloseIcon =
        widget.closeIcon ??
        effectiveToastTheme.closeIcon ??
        AxiIconButton.ghost(
          iconData:
              widget.closeIconData ??
              effectiveToastTheme.closeIconData ??
              LucideIcons.x,
          iconSize: context.sizing.inputSuffixIconSize,
          buttonSize: context.sizing.inputSuffixButtonSize,
          tapTargetSize: context.sizing.inputSuffixButtonSize,
          color: effectiveForegroundColor.withValues(alpha: .5),
          hoverColor: effectiveForegroundColor,
          pressedColor: effectiveForegroundColor,
          backgroundColor: Colors.transparent,
          hoverBackgroundColor: Colors.transparent,
          pressedBackgroundColor: Colors.transparent,
          borderColor: Colors.transparent,
          semanticLabel: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => ShadToaster.of(context).hide(),
        );
    final effectiveTitleStyle =
        widget.titleStyle ??
        theme.textTheme.small.strong.copyWith(color: effectiveForegroundColor);
    final effectiveDescriptionStyle =
        widget.descriptionStyle ??
        theme.textTheme.small.copyWith(
          color: effectiveForegroundColor.withValues(alpha: .9),
        );
    final effectiveActionPadding =
        widget.actionPadding ?? EdgeInsets.only(left: context.spacing.s);
    final effectiveBorder =
        widget.border ??
        (toneColor == null
            ? null
            : ShadBorder.fromBorderSide(
                ShadBorderSide(
                  color: toneColor,
                  width: context.borderSide.width,
                ),
              )) ??
        effectiveToastTheme.border ??
        ShadBorder.fromBorderSide(
          ShadBorderSide(
            color: theme.colorScheme.border,
            width: axiBorders.width,
          ),
        );
    final effectiveBorderRadius =
        widget.radius ?? effectiveToastTheme.radius ?? theme.radius;
    final effectiveShadows =
        widget.shadows ?? effectiveToastTheme.shadows ?? ShadShadows.lg;
    final effectiveBackgroundColor =
        widget.backgroundColor ??
        (toneColor == null
            ? null
            : Color.alphaBlend(
                toneColor.withValues(alpha: context.motion.tapHoverAlpha),
                theme.colorScheme.card,
              )) ??
        effectiveToastTheme.backgroundColor ??
        theme.colorScheme.background;
    final effectivePadding =
        widget.padding ??
        EdgeInsets.fromLTRB(
          context.spacing.m,
          context.spacing.xs,
          context.spacing.l,
          context.spacing.xs,
        );
    final effectiveCrossAxisAlignment =
        widget.crossAxisAlignment ??
        effectiveToastTheme.crossAxisAlignment ??
        CrossAxisAlignment.center;
    final effectiveCloseIconPosition =
        widget.closeIconPosition ??
        effectiveToastTheme.closeIconPosition ??
        ShadPosition(top: context.spacing.xs, right: context.spacing.xs);
    final effectiveShowCloseIconOnlyWhenHovered =
        widget.showCloseIconOnlyWhenHovered ??
        effectiveToastTheme.showCloseIconOnlyWhenHovered ??
        true;
    final bool compactWidth = FeedbackToast._isCompactToastWidth(
      MediaQuery.sizeOf(context).width,
    );

    return MouseRegion(
      onEnter: (_) => hovered.value = true,
      onExit: (_) => hovered.value = false,
      child: Dismissible(
        key: dismissibleKey,
        direction: compactWidth
            ? DismissDirection.up
            : DismissDirection.horizontal,
        resizeDuration: null,
        background: const SizedBox.expand(),
        secondaryBackground: const SizedBox.expand(),
        onDismissed: (_) => ShadToaster.of(context).hide(animate: false),
        child: UnconstrainedBox(
          constrainedAxis: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: compactWidth ? double.infinity : 0,
              maxWidth: compactWidth
                  ? double.infinity
                  : context.sizing.dialogMaxWidth,
              minHeight: context.sizing.menuItemHeight,
              maxHeight: compactWidth
                  ? context.sizing.attachmentPreviewExtent +
                        context.sizing.inputSuffixButtonSize
                  : context.sizing.attachmentPreviewExtent,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: effectiveBorder.toBorder(),
                borderRadius: effectiveBorderRadius,
                boxShadow: effectiveShadows,
                color: effectiveBackgroundColor,
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: effectivePadding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (compactWidth) ...[
                          Align(
                            alignment: Alignment.center,
                            child: _CompactToastDismissHint(
                              color: effectiveForegroundColor,
                            ),
                          ),
                          SizedBox(height: context.spacing.xxs),
                        ],
                        Row(
                          textDirection: widget.textDirection,
                          mainAxisSize: compactWidth
                              ? MainAxisSize.max
                              : MainAxisSize.min,
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
                        if (compactWidth) ...[
                          SizedBox(height: context.spacing.xxs),
                          SizedBox(height: context.sizing.inputSuffixIconSize),
                        ],
                      ],
                    ),
                  ),
                  if (!compactWidth)
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
        ),
      ),
    );
  }
}

class _CompactToastDismissHint extends StatelessWidget {
  const _CompactToastDismissHint({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Icon(
        LucideIcons.chevronUp,
        size: context.sizing.inputSuffixIconSize,
        color: color.withValues(alpha: context.motion.tapFocusAlpha),
      ),
    );
  }
}
