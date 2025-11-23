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
    this.panePadding = EdgeInsets.zero,
    this.centerPrimary = true,
    this.centerSecondary = true,
    this.primaryAlignment,
    this.secondaryAlignment,
    int primaryFlex = 4,
    int secondaryFlex = 6,
    EdgeInsets? primaryPadding,
    EdgeInsets? secondaryPadding,
  })  : primaryFlex = primaryFlex,
        secondaryFlex = secondaryFlex,
        primaryPadding = primaryPadding ?? panePadding,
        secondaryPadding = secondaryPadding ?? panePadding;

  final Widget primaryChild;
  final Widget secondaryChild;
  final bool invertPriority;
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

        if (!allowSplitView) {
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
                child: invertPriority ? secondaryChild : primaryChild,
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
              Expanded(
                flex: primaryFlex,
                child: Padding(
                  padding: primaryPadding,
                  child: Align(
                    alignment: primaryAlign,
                    child: primaryChild,
                  ),
                ),
              ),
              Expanded(
                flex: secondaryFlex,
                child: Padding(
                  padding: secondaryPadding,
                  child: Align(
                    alignment: secondaryAlign,
                    child: secondaryChild,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
