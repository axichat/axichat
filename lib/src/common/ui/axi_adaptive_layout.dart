import 'package:animations/animations.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AxiAdaptiveLayout extends StatelessWidget {
  const AxiAdaptiveLayout({
    super.key,
    required this.primaryChild,
    required this.secondaryChild,
    this.invertPriority = false,
    this.showPrimary = true,
    this.showSecondary = true,
    this.panePadding = EdgeInsets.zero,
    this.centerPrimary = true,
    this.centerSecondary = true,
    this.primaryAlignment,
    this.secondaryAlignment,
    this.primaryFlex = 4,
    this.secondaryFlex = 6,
    EdgeInsets? primaryPadding,
    EdgeInsets? secondaryPadding,
  })  : primaryPadding = primaryPadding ?? panePadding,
        secondaryPadding = secondaryPadding ?? panePadding;

  final Widget primaryChild;
  final Widget secondaryChild;
  final bool invertPriority;
  final bool showPrimary;
  final bool showSecondary;
  final EdgeInsets panePadding;
  final EdgeInsets primaryPadding;
  final EdgeInsets secondaryPadding;
  final bool centerPrimary;
  final bool centerSecondary;
  final Alignment? primaryAlignment;
  final Alignment? secondaryAlignment;
  final int primaryFlex;
  final int secondaryFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.maybeOf(context);
        final shortestSide = mediaQuery?.size.shortestSide;
        final bool isCompactDevice =
            shortestSide != null && shortestSide < compactDeviceBreakpoint;
        final bool allowSplitView =
            !isCompactDevice && constraints.maxWidth >= smallScreen;

        if (!showPrimary && !showSecondary) {
          return const SizedBox.shrink();
        }

        if (!allowSplitView) {
          final compactChild = showPrimary && showSecondary
              ? (invertPriority ? secondaryChild : primaryChild)
              : (showPrimary ? primaryChild : secondaryChild);
          return ConstrainedBox(
            constraints: constraints,
            child: Center(
              child: PageTransitionSwitcher(
                reverse: !invertPriority,
                duration: context.watch<SettingsCubit>().animationDuration,
                transitionBuilder: (
                  child,
                  primaryAnimation,
                  secondaryAnimation,
                ) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1.0, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: primaryAnimation,
                      curve: Curves.easeIn,
                    )),
                    child: child,
                  );
                },
                child: compactChild,
              ),
            ),
          );
        }

        final primaryAlign = primaryAlignment ??
            (centerPrimary ? Alignment.center : Alignment.topLeft);
        final secondaryAlign = secondaryAlignment ??
            (centerSecondary ? Alignment.center : Alignment.topLeft);
        return ConstrainedBox(
          constraints: constraints,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showPrimary)
                Expanded(
                  flex: primaryFlex,
                  child: AxiAdaptivePane(
                    alignment: primaryAlign,
                    padding: primaryPadding,
                    child: primaryChild,
                  ),
                ),
              if (showSecondary)
                Expanded(
                  flex: secondaryFlex,
                  child: AxiAdaptivePane(
                    alignment: secondaryAlign,
                    padding: secondaryPadding,
                    child: secondaryChild,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class AxiAdaptivePane extends StatelessWidget {
  const AxiAdaptivePane({
    super.key,
    required this.alignment,
    required this.padding,
    required this.child,
  });

  final Alignment alignment;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Align(
        alignment: alignment,
        child: child,
      ),
    );
  }
}
