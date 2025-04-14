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
  });

  final Widget primaryChild;
  final Widget secondaryChild;
  final bool invertPriority;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final primaryFlex = switch (constraints.maxWidth) {
          < smallScreen => 10,
          < mediumScreen => 5,
          < largeScreen => 4,
          _ => 3,
        };
        final secondaryFlex = 10 - primaryFlex;
        final secondaryVisible = secondaryFlex > 0;
        return ConstrainedBox(
          constraints: constraints,
          child: !secondaryVisible
              ? Center(
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
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      flex: primaryFlex,
                      child: Center(
                        child: primaryChild,
                      ),
                    ),
                    Flexible(
                      flex: secondaryFlex,
                      child: Center(
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
