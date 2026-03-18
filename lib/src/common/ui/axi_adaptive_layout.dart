// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:animations/animations.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AxiAdaptiveLayout extends StatelessWidget {
  static const Curve _paneResizeCurve = Curves.easeInOutCubic;
  static const Curve _compactSlideCurve = Curves.easeIn;
  static const Offset _compactSlideBeginOffset = Offset(1.0, 0);

  const AxiAdaptiveLayout({
    super.key,
    required this.primaryChild,
    required this.secondaryChild,
    this.invertPriority = false,
    this.showPrimary = true,
    this.showSecondary = true,
    this.animatePaneChanges = false,
    this.panePadding = EdgeInsets.zero,
    this.centerPrimary = true,
    this.centerSecondary = true,
    this.primaryAlignment,
    this.secondaryAlignment,
    this.primaryFlex = 4,
    this.secondaryFlex = 6,
    EdgeInsets? primaryPadding,
    EdgeInsets? secondaryPadding,
  }) : primaryPadding = primaryPadding ?? panePadding,
       secondaryPadding = secondaryPadding ?? panePadding;

  final Widget primaryChild;
  final Widget secondaryChild;
  final bool invertPriority;
  final bool showPrimary;
  final bool showSecondary;
  final bool animatePaneChanges;
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
        final bool allowSplitView = constraints.maxWidth >= smallScreen;

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
                transitionBuilder:
                    (child, primaryAnimation, secondaryAnimation) {
                      final bool showCompactDivider =
                          showPrimary && showSecondary;
                      final Widget transition = SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: _compactSlideBeginOffset,
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: primaryAnimation,
                                curve: _compactSlideCurve,
                              ),
                            ),
                        child: child,
                      );
                      if (!showCompactDivider) return transition;
                      return transition;
                    },
                child: compactChild,
              ),
            ),
          );
        }

        final bool showSecondaryDivider = showPrimary && showSecondary;
        final BoxDecoration secondaryDividerDecoration = BoxDecoration(
          border: Border(left: context.borderSide),
        );
        final primaryAlign =
            primaryAlignment ??
            (centerPrimary ? Alignment.center : Alignment.topLeft);
        final secondaryAlign =
            secondaryAlignment ??
            (centerSecondary ? Alignment.center : Alignment.topLeft);
        final animationDuration = context
            .watch<SettingsCubit>()
            .animationDuration;
        if (!animatePaneChanges) {
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
                    child: DecoratedBox(
                      decoration: showSecondaryDivider
                          ? secondaryDividerDecoration
                          : const BoxDecoration(),
                      child: AxiAdaptivePane(
                        alignment: secondaryAlign,
                        padding: secondaryPadding,
                        child: secondaryChild,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }
        final int resolvedPrimaryFlex = showPrimary ? primaryFlex : 0;
        final int resolvedSecondaryFlex = showSecondary ? secondaryFlex : 0;
        final int totalFlex = resolvedPrimaryFlex + resolvedSecondaryFlex;
        final double availableWidth = constraints.maxWidth;
        double widthForFlex(int flexValue) {
          if (totalFlex == 0) return 0.0;
          return availableWidth * (flexValue / totalFlex);
        }

        final double primaryWidth = widthForFlex(resolvedPrimaryFlex);
        final double secondaryWidth = showSecondary
            ? (availableWidth - primaryWidth).clamp(0.0, availableWidth)
            : 0.0;
        return ConstrainedBox(
          constraints: constraints,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedContainer(
                duration: animationDuration,
                curve: _paneResizeCurve,
                width: primaryWidth,
                child: ClipRect(
                  child: AxiAdaptivePane(
                    alignment: primaryAlign,
                    padding: primaryPadding,
                    child: primaryChild,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: animationDuration,
                curve: _paneResizeCurve,
                width: secondaryWidth,
                child: DecoratedBox(
                  decoration: showSecondaryDivider
                      ? secondaryDividerDecoration
                      : const BoxDecoration(),
                  child: ClipRect(
                    child: AxiAdaptivePane(
                      alignment: secondaryAlign,
                      padding: secondaryPadding,
                      child: secondaryChild,
                    ),
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
      child: Align(alignment: alignment, child: child),
    );
  }
}
