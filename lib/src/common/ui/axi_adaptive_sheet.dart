// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/fade_scale_dialog.dart';
import 'package:axichat/src/common/ui/keyboard_pop_scope.dart';
import 'package:axichat/src/common/ui/modal_close_button.dart';
import 'package:axichat/src/common/ui/squircle_border.dart';
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
  double dialogMaxWidth = 640,
  double dialogMaxHeightFraction = 0.9,
  EdgeInsetsGeometry surfacePadding = const EdgeInsets.all(16),
}) {
  final commandSurface = resolveCommandSurface(context);
  final scheme = ShadTheme.of(context).colorScheme;

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
        final Color resolvedBackground = backgroundColor ?? scheme.card;
        final bool transparentSurface = resolvedBackground.a == 0;
        const BorderRadiusGeometry sheetRadius = BorderRadius.vertical(
          top: Radius.circular(18),
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
            padding: transparentSurface ? EdgeInsets.zero : surfacePadding,
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
      const EdgeInsets.symmetric(horizontal: 24, vertical: 24);

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
          maxWidth: dialogMaxWidth,
          maxHeight: size.height * dialogMaxHeightFraction,
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
          borderColor: scheme.border,
          padding: surfacePadding,
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

  static const EdgeInsets _dragHandlePadding =
      EdgeInsets.only(top: 12, bottom: 8);
  static const double _dragHandleWidth = 34;
  static const double _dragHandleHeight = 4;
  static const EdgeInsets _closeButtonPadding = EdgeInsets.only(
    top: 4,
    right: 4,
    bottom: 8,
  );

  final Widget child;
  final VoidCallback onClose;
  final bool showCloseButton;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    if (!showCloseButton && !showDragHandle) {
      return child;
    }

    final colors = ShadTheme.of(context).colorScheme;
    final Widget closeButton = ModalCloseButton(
      onPressed: onClose,
      color: colors.mutedForeground,
      backgroundColor: Colors.transparent,
      borderColor: Colors.transparent,
    );
    final dragHandle = Center(
      child: Container(
        width: _dragHandleWidth,
        height: _dragHandleHeight,
        decoration: BoxDecoration(
          color: colors.border.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDragHandle)
          Padding(padding: _dragHandlePadding, child: dragHandle),
        if (showCloseButton)
          Padding(
            padding: _closeButtonPadding,
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
    this.cornerRadius = 18,
    this.borderRadius,
    this.shadows,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final double cornerRadius;
  final BorderRadiusGeometry? borderRadius;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final shape = SquircleBorder(
      cornerRadius: cornerRadius,
      borderRadius: borderRadius,
      side: BorderSide(color: borderColor ?? scheme.border),
    );
    final Widget paddedChild = Padding(padding: padding, child: child);
    return ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: backgroundColor ?? scheme.card,
          shape: shape,
          shadows: shadows ??
              const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: paddedChild,
        ),
      ),
    );
  }
}
