// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/fade_scale_dialog.dart';
import 'package:axichat/src/common/ui/keyboard_pop_scope.dart';
import 'package:axichat/src/common/ui/modal_close_button.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Shows a bottom sheet on mobile form factors and a dialog on desktop/tablet.
///
/// Keeps the builder API identical to `showModalBottomSheet` so existing sheet
/// content can be reused without branching at call sites.
Future<T?> showAdaptiveBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = true,
  bool showDragHandle = false,
  bool enableDrag = true,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool showCloseButton = false,
  Color? backgroundColor,
  Color? barrierColor,
  EdgeInsets? dialogInsetPadding,
  double? dialogMaxWidth,
  double? dialogMaxHeightFraction,
  EdgeInsetsGeometry? surfacePadding,
}) {
  final commandSurface = resolveCommandSurface(context);
  final colorScheme = ShadTheme.of(context).colorScheme;
  final spacing = context.spacing;
  final sizing = context.sizing;
  final containerRadius = context.radii.container;
  final EdgeInsetsGeometry resolvedSurfacePadding =
      surfacePadding ?? EdgeInsets.all(spacing.m);
  final Color resolvedBackground = backgroundColor ?? colorScheme.card;
  final BorderRadiusGeometry sheetRadius = BorderRadius.vertical(
    top: Radius.circular(containerRadius),
  );
  final EdgeInsets resolvedInsets =
      dialogInsetPadding ??
      EdgeInsets.symmetric(horizontal: spacing.l, vertical: spacing.l);
  final double resolvedDialogMaxWidth = dialogMaxWidth ?? sizing.dialogMaxWidth;
  final double resolvedDialogMaxHeightFraction =
      dialogMaxHeightFraction ?? sizing.dialogMaxHeightFraction;

  if (commandSurface == CommandSurface.sheet) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: false,
      showDragHandle: false,
      enableDrag: enableDrag,
      isDismissible: isDismissible,
      backgroundColor: Colors.transparent,
      barrierColor: barrierColor,
      useRootNavigator: useRootNavigator,
      builder: (sheetContext) {
        final MediaQueryData mediaQuery = MediaQuery.of(sheetContext);
        final MediaQueryData viewMediaQuery = MediaQueryData.fromView(
          View.of(sheetContext),
        );
        final bool transparentSurface = resolvedBackground.a == 0;
        const double zeroInset = 0;
        final double topInset = useSafeArea
            ? viewMediaQuery.viewPadding.top
            : zeroInset;
        final double bottomSafeInset = useSafeArea
            ? math.max(
                viewMediaQuery.viewPadding.bottom -
                    mediaQuery.viewInsets.bottom,
                zeroInset,
              )
            : zeroInset;
        final EdgeInsets baseSurfacePadding = resolvedSurfacePadding.resolve(
          Directionality.of(sheetContext),
        );
        final EdgeInsets resolvedSheetSurfacePadding = transparentSurface
            ? EdgeInsets.zero
            : baseSurfacePadding.copyWith(
                bottom: baseSurfacePadding.bottom + bottomSafeInset,
              );
        final Widget child = _AxiSheetChrome(
          showDragHandle: showDragHandle,
          showCloseButton: showCloseButton,
          onClose: () => Navigator.of(sheetContext).maybePop(),
          child: builder(sheetContext),
        );
        final Widget surface = SizedBox(
          width: double.infinity,
          child: AxiModalSurface(
            backgroundColor: resolvedBackground,
            borderColor: Colors.transparent,
            padding: resolvedSheetSurfacePadding,
            borderRadius: sheetRadius,
            shadows: transparentSurface ? const <BoxShadow>[] : null,
            child: child,
          ),
        );
        final Widget scopedSurface = KeyboardPopScope(child: surface);
        return Padding(
          padding: EdgeInsets.only(top: topInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: mediaQuery.size.height - topInset,
            ),
            child: scopedSurface,
          ),
        );
      },
    );
  }

  return showFadeScaleDialog<T>(
    context: context,
    barrierColor: barrierColor,
    useRootNavigator: useRootNavigator,
    barrierDismissible: isDismissible,
    useSafeArea: useSafeArea,
    builder: (dialogContext) {
      final mediaQuery = MediaQuery.of(dialogContext);
      final Size size = mediaQuery.size;
      final Widget child = _AxiSheetChrome(
        showCloseButton: showCloseButton,
        showDragHandle: false,
        onClose: () => Navigator.of(dialogContext).maybePop(),
        child: builder(dialogContext),
      );
      final Widget constrainedChild = ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: resolvedDialogMaxWidth,
          maxHeight: size.height * resolvedDialogMaxHeightFraction,
        ),
        child: child,
      );
      return Dialog(
        insetPadding: resolvedInsets,
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        child: AxiModalSurface(
          backgroundColor: resolvedBackground,
          borderColor: colorScheme.border,
          padding: resolvedSurfacePadding,
          child: constrainedChild,
        ),
      );
    },
  );
}

class _AxiSheetChrome extends StatelessWidget {
  const _AxiSheetChrome({
    required this.child,
    required this.onClose,
    required this.showCloseButton,
    required this.showDragHandle,
  });

  final Widget child;
  final VoidCallback onClose;
  final bool showCloseButton;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    if (!showCloseButton && !showDragHandle) {
      return child;
    }

    final EdgeInsets dragHandlePadding = EdgeInsets.only(
      top: context.spacing.s,
      bottom: context.spacing.xs,
    );
    final EdgeInsets closeButtonPadding = EdgeInsets.only(
      top: context.spacing.xs,
      right: context.spacing.xs,
      bottom: context.spacing.s,
    );
    final Widget closeButton = ModalCloseButton(
      onPressed: () => closeSheetWithKeyboardDismiss(context, onClose),
      color: ShadTheme.of(context).colorScheme.mutedForeground,
      backgroundColor: Colors.transparent,
      borderColor: Colors.transparent,
    );
    final dragHandle = Center(
      child: Container(
        width: context.sizing.sheetDragHandleWidth,
        height: context.sizing.sheetDragHandleHeight,
        decoration: BoxDecoration(
          color: ShadTheme.of(context).colorScheme.border,
          borderRadius: BorderRadius.circular(context.spacing.xxl),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDragHandle)
          Padding(padding: dragHandlePadding, child: dragHandle),
        if (showCloseButton)
          Padding(
            padding: closeButtonPadding,
            child: Align(alignment: Alignment.centerRight, child: closeButton),
          ),
        Flexible(fit: FlexFit.loose, child: child),
      ],
    );
  }
}

class AxiModalSurface extends StatelessWidget {
  const AxiModalSurface({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.borderColor,
    this.cornerRadius,
    this.borderRadius,
    this.shadows,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? cornerRadius;
  final BorderRadiusGeometry? borderRadius;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final BorderRadiusGeometry resolvedRadius = borderRadius ?? context.radius;
    final Widget paddedChild = Padding(padding: padding, child: child);
    final ShadDecoration decoration = ShadDecoration(
      color: backgroundColor ?? ShadTheme.of(context).colorScheme.card,
      border: ShadBorder.all(
        color: borderColor ?? context.borderSide.color,
        width: context.borderSide.width,
        radius: resolvedRadius,
      ),
      shadows: shadows ?? const <BoxShadow>[],
    );
    return ClipRRect(
      borderRadius: resolvedRadius,
      child: ShadDecorator(
        decoration: decoration,
        child: Material(
          type: MaterialType.transparency,
          shape: RoundedRectangleBorder(borderRadius: resolvedRadius),
          clipBehavior: Clip.antiAlias,
          child: paddedChild,
        ),
      ),
    );
  }
}
