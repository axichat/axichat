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
  });

  final Widget primaryChild;
  final Widget secondaryChild;
  final bool invertPriority;
  final EdgeInsets panePadding;

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

        final primaryFlex = switch (constraints.maxWidth) {
          < smallScreen => 10,
          < mediumScreen => 5,
          < largeScreen => 4,
          _ => 3,
        };
        final secondaryFlex = 10 - primaryFlex;
        Widget wrap(Widget child) => Padding(
              padding: panePadding,
              child: Center(child: child),
            );
        return ConstrainedBox(
          constraints: constraints,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                flex: primaryFlex,
                child: wrap(primaryChild),
              ),
              Flexible(
                flex: secondaryFlex,
                child: wrap(secondaryChild),
              ),
            ],
          ),
        );
      },
    );
  }
}
