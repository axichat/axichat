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

enum AxiSheetBottomSafeAreaBehavior { none, insideSurface, outsideSurface }

/// Shows a bottom sheet on mobile form factors and a dialog on desktop/tablet.
///
/// Keeps the builder API identical to `showModalBottomSheet` so existing sheet
/// content can be reused without branching at call sites.
Future<T?> showAdaptiveBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = true,
  bool useBottomSafeArea = true,
  bool preferDialogOnMobile = false,
  bool showDragHandle = false,
  bool enableDrag = true,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool showCloseButton = false,
  bool? requestFocus,
  Color? backgroundColor,
  Color? barrierColor,
  EdgeInsets? dialogInsetPadding,
  double? dialogMaxWidth,
  double? dialogMaxHeightFraction,
  EdgeInsetsGeometry? surfacePadding,
  AxiSheetBottomSafeAreaBehavior? bottomSafeAreaBehavior,
}) {
  final commandSurface = preferDialogOnMobile
      ? CommandSurface.menu
      : resolveCommandSurface(context);
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
      requestFocus: requestFocus,
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
        final EdgeInsets baseSurfacePadding = resolvedSurfacePadding.resolve(
          Directionality.of(sheetContext),
        );
        final AxiSheetBottomSafeAreaBehavior resolvedBottomSafeAreaBehavior =
            bottomSafeAreaBehavior ??
            (useBottomSafeArea
                ? AxiSheetBottomSafeAreaBehavior.insideSurface
                : AxiSheetBottomSafeAreaBehavior.none);
        final double bottomSafeInset =
            useSafeArea &&
                resolvedBottomSafeAreaBehavior !=
                    AxiSheetBottomSafeAreaBehavior.none
            ? math.max(
                viewMediaQuery.viewPadding.bottom -
                    mediaQuery.viewInsets.bottom,
                zeroInset,
              )
            : zeroInset;
        final double surfaceBottomSafeInset =
            resolvedBottomSafeAreaBehavior ==
                AxiSheetBottomSafeAreaBehavior.insideSurface
            ? bottomSafeInset
            : zeroInset;
        final double externalBottomSafeInset =
            resolvedBottomSafeAreaBehavior ==
                AxiSheetBottomSafeAreaBehavior.outsideSurface
            ? bottomSafeInset
            : zeroInset;
        final EdgeInsets resolvedSheetSurfacePadding = transparentSurface
            ? EdgeInsets.zero
            : baseSurfacePadding.copyWith(
                bottom: baseSurfacePadding.bottom + surfaceBottomSafeInset,
              );
        final Widget child = _AxiSheetChrome(
          showDragHandle: showDragHandle,
          showCloseButton: showCloseButton,
          onClose: () => Navigator.of(sheetContext).pop(),
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
          padding: EdgeInsets.only(
            top: topInset,
            bottom: externalBottomSafeInset,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  mediaQuery.size.height - topInset - externalBottomSafeInset,
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
    requestFocus: requestFocus,
    builder: (dialogContext) {
      final mediaQuery = MediaQuery.of(dialogContext);
      final Size size = mediaQuery.size;
      final Widget child = _AxiSheetChrome(
        showCloseButton: showCloseButton,
        showDragHandle: false,
        onClose: () => Navigator.of(dialogContext).pop(),
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
    final BorderRadiusGeometry resolvedRadius =
        borderRadius ??
        (cornerRadius == null
            ? context.radius
            : BorderRadius.circular(cornerRadius!));
    final Color resolvedBackground =
        backgroundColor ?? ShadTheme.of(context).colorScheme.card;
    final BorderSide resolvedBorderSide = switch (borderColor) {
      final Color color when color.a == 0 => BorderSide.none,
      final Color color => context.borderSide.copyWith(color: color),
      null => context.borderSide,
    };
    final RoundedRectangleBorder shape = RoundedRectangleBorder(
      borderRadius: resolvedRadius,
      side: resolvedBorderSide,
    );
    final Widget surface = Material(
      color: resolvedBackground,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );

    final List<BoxShadow> resolvedShadows = shadows ?? const <BoxShadow>[];
    if (resolvedShadows.isEmpty) {
      return surface;
    }
    return DecoratedBox(
      decoration: ShapeDecoration(
        shadows: resolvedShadows,
        shape: RoundedRectangleBorder(borderRadius: resolvedRadius),
      ),
      child: surface,
    );
  }
}
