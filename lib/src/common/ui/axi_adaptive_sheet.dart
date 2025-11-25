import 'package:axichat/src/common/env.dart';
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
  bool useSafeArea = false,
  bool showDragHandle = false,
  bool enableDrag = true,
  bool useRootNavigator = false,
  bool isDismissible = true,
  Color? backgroundColor,
  Color? barrierColor,
  EdgeInsets? dialogInsetPadding,
  double dialogMaxWidth = 640,
  double dialogMaxHeightFraction = 0.9,
}) {
  final commandSurface =
      EnvScope.maybeOf(context)?.commandSurface ?? CommandSurface.sheet;
  final scheme = ShadTheme.of(context).colorScheme;

  if (commandSurface == CommandSurface.sheet) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      showDragHandle: showDragHandle,
      enableDrag: enableDrag,
      isDismissible: isDismissible,
      backgroundColor: Colors.transparent,
      barrierColor: barrierColor,
      useRootNavigator: useRootNavigator,
      builder: (sheetContext) {
        final Widget child = builder(sheetContext);
        final double bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: AxiModalSurface(
            backgroundColor: backgroundColor ?? scheme.card,
            borderColor: scheme.border,
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        );
      },
    );
  }

  final Color resolvedBackground =
      backgroundColor ?? ShadTheme.of(context).colorScheme.card;
  final EdgeInsets resolvedInsets = dialogInsetPadding ??
      const EdgeInsets.symmetric(horizontal: 24, vertical: 24);

  return showDialog<T>(
    context: context,
    barrierColor: barrierColor,
    useRootNavigator: useRootNavigator,
    barrierDismissible: isDismissible,
    builder: (dialogContext) {
      final mediaQuery = MediaQuery.of(dialogContext);
      final Size size = mediaQuery.size;
      final EdgeInsets viewInsets = mediaQuery.viewInsets;
      final Widget child = builder(dialogContext);
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
          padding: const EdgeInsets.all(16),
          child: wrappedChild,
        ),
      );
    },
  );
}

class AxiModalSurface extends StatelessWidget {
  const AxiModalSurface({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.borderColor,
    this.cornerRadius = 18,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final double cornerRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final shape = SquircleBorder(
      cornerRadius: cornerRadius,
      side: BorderSide(color: borderColor ?? scheme.border),
    );
    return ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: backgroundColor ?? scheme.card,
          shape: shape,
          shadows: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
