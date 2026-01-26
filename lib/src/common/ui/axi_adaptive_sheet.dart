// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

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
  final EdgeInsetsGeometry resolvedSurfacePadding =
      surfacePadding ?? EdgeInsets.all(context.spacing.m);

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
        final MediaQueryData windowMediaQuery = MediaQueryData.fromView(
          View.of(sheetContext),
        );
        final Color resolvedBackground =
            backgroundColor ?? ShadTheme.of(context).colorScheme.card;
        final bool transparentSurface = resolvedBackground.a == 0;
        final BorderRadiusGeometry sheetRadius = BorderRadius.vertical(
          top: Radius.circular(context.sizing.containerRadius),
        );
        const double zeroInset = 0;
        final double topInset =
            useSafeArea ? windowMediaQuery.viewPadding.top : zeroInset;
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
            padding:
                transparentSurface ? EdgeInsets.zero : resolvedSurfacePadding,
            borderRadius: sheetRadius,
            shadows: transparentSurface ? const <BoxShadow>[] : null,
            child: child,
          ),
        );
        final Widget scopedSurface = KeyboardPopScope(child: surface);
        return MediaQuery(
          data: windowMediaQuery,
          child: Padding(
            padding: EdgeInsets.only(top: topInset),
            child: SafeArea(
              top: false,
              bottom: useSafeArea,
              left: false,
              right: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: windowMediaQuery.size.height - topInset,
                ),
                child: scopedSurface,
              ),
            ),
          ),
        );
      },
    );
  }

  final Color resolvedBackground =
      backgroundColor ?? ShadTheme.of(context).colorScheme.card;
  final EdgeInsets resolvedInsets = dialogInsetPadding ??
      EdgeInsets.symmetric(
        horizontal: context.spacing.l,
        vertical: context.spacing.l,
      );

  return showFadeScaleDialog<T>(
    context: context,
    barrierColor: barrierColor,
    useRootNavigator: useRootNavigator,
    barrierDismissible: isDismissible,
    useSafeArea: false,
    builder: (dialogContext) {
      final mediaQuery = MediaQuery.of(dialogContext);
      final Size size = mediaQuery.size;
      final EdgeInsets viewInsets = mediaQuery.viewInsets;
      final Widget child = _AxiSheetChrome(
        showCloseButton: showCloseButton,
        showDragHandle: false,
        onClose: () => Navigator.of(dialogContext).maybePop(),
        child: builder(dialogContext),
      );
      final EdgeInsets dialogInsets = EdgeInsets.fromLTRB(
        resolvedInsets.left,
        resolvedInsets.top,
        resolvedInsets.right,
        resolvedInsets.bottom + viewInsets.bottom,
      );
      final Widget constrainedChild = ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogMaxWidth ?? context.sizing.dialogMaxWidth,
          maxHeight: size.height *
              (dialogMaxHeightFraction ??
                  context.sizing.dialogMaxHeightFraction),
        ),
        child: child,
      );
      final Widget wrappedChild =
          useSafeArea ? SafeArea(child: constrainedChild) : constrainedChild;
      return Dialog(
        insetPadding: dialogInsets,
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        child: AxiModalSurface(
          backgroundColor: resolvedBackground,
          borderColor: ShadTheme.of(context).colorScheme.border,
          padding: resolvedSurfacePadding,
          child: wrappedChild,
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

    final EdgeInsets dragHandlePadding =
        EdgeInsets.only(top: context.spacing.s, bottom: context.spacing.xs);
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
        borderRadius ?? BorderRadius.circular(context.sizing.containerRadius);
    final Widget paddedChild = Padding(padding: padding, child: child);
    return ClipRRect(
      borderRadius: resolvedRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor ?? ShadTheme.of(context).colorScheme.card,
          border: Border.all(
            color: borderColor ??
                (ShadTheme.of(context).decoration.border?.top?.color ??
                    ShadTheme.of(context).colorScheme.border),
            width: ShadTheme.of(context).decoration.border?.top?.width ?? 0,
          ),
          borderRadius: resolvedRadius,
          boxShadow: shadows ??
              [
                BoxShadow(
                  color: Theme.of(context).shadowColor,
                  blurRadius: context.sizing.modalShadowBlur,
                  offset: Offset(0, context.sizing.modalShadowOffsetY),
                ),
              ],
        ),
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
