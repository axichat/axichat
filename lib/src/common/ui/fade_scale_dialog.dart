// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:animations/animations.dart';
import 'package:axichat/src/common/ui/settings_cubit_lookup.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';

const Color _defaultDialogBarrierColor = Color(0xcc000000);
const Duration _fallbackDialogAnimationDuration = Duration(milliseconds: 300);

Future<T?> showFadeScaleDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  bool useSafeArea = true,
  Duration? transitionDuration,
}) {
  final Color? themeBarrierColor = Theme.of(context).dialogTheme.barrierColor;
  final Color resolvedBarrierColor =
      barrierColor ?? themeBarrierColor ?? _defaultDialogBarrierColor;
  final String resolvedBarrierLabel = barrierLabel ??
      MaterialLocalizations.of(context).modalBarrierDismissLabel;
  final SettingsCubit? settingsCubit = maybeSettingsCubit(context);
  final Duration resolvedDuration = transitionDuration ??
      settingsCubit?.animationDuration ??
      _fallbackDialogAnimationDuration;

  return showGeneralDialog<T>(
    context: context,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final Widget child = builder(dialogContext);
      if (!useSafeArea) return child;
      return SafeArea(child: child);
    },
    barrierColor: resolvedBarrierColor,
    barrierDismissible: barrierDismissible,
    barrierLabel: resolvedBarrierLabel,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    transitionDuration: resolvedDuration,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      if (resolvedDuration == Duration.zero) {
        return child;
      }
      return FadeScaleTransition(
        animation: animation,
        child: child,
      );
    },
  );
}
