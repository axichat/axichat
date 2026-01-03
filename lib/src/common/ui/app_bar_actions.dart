// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

const double _defaultAppBarActionSpacing = 8.0;
const double _inlineActionWidthMultiplier = 2.4;
const double _inlineActionEstimatedWidth =
    AxiIconButton.kTapTargetSize * _inlineActionWidthMultiplier;

class AppBarActionItem {
  const AppBarActionItem({
    required this.label,
    required this.iconData,
    this.icon,
    this.inline,
    this.estimatedWidth,
    this.onPressed,
    this.enabled = true,
    this.destructive = false,
    this.usePrimary = true,
    this.tooltip,
  });

  final String label;
  final IconData iconData;
  final Widget? icon;
  final Widget? inline;
  final double? estimatedWidth;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool destructive;
  final bool usePrimary;
  final String? tooltip;

  AxiMenuAction toMenuAction() {
    final bool isEnabled = enabled && onPressed != null;
    return AxiMenuAction(
      label: label,
      icon: iconData,
      destructive: destructive,
      enabled: isEnabled,
      onPressed: isEnabled ? onPressed : null,
    );
  }
}

class AppBarActions extends StatelessWidget {
  const AppBarActions({
    super.key,
    required this.actions,
    this.spacing = _defaultAppBarActionSpacing,
    this.overflowBreakpoint = appBarActionOverflowBreakpoint,
    this.moreTooltip,
    this.forceCollapsed,
    this.availableWidth,
  });

  final List<AppBarActionItem> actions;
  final double spacing;
  final double overflowBreakpoint;
  final String? moreTooltip;
  final bool? forceCollapsed;
  final double? availableWidth;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = MediaQuery.sizeOf(context).width;
        final double resolvedAvailableWidth = availableWidth ??
            (constraints.hasBoundedWidth ? constraints.maxWidth : screenWidth);
        final int spacingCount = actions.length > 1 ? actions.length - 1 : 0;
        final double spacingWidth = spacing * spacingCount;
        final double estimatedActionsWidth = actions.fold<double>(
          spacingWidth,
          (total, action) {
            final double actionWidth = action.estimatedWidth ??
                (action.inline != null
                    ? _inlineActionEstimatedWidth
                    : AxiIconButton.kTapTargetSize);
            return total + actionWidth;
          },
        );
        final bool autoCollapse =
            (overflowBreakpoint > 0 && screenWidth < overflowBreakpoint) ||
                resolvedAvailableWidth < estimatedActionsWidth;
        final bool shouldCollapse = forceCollapsed ?? autoCollapse;
        if (shouldCollapse) {
          final List<AxiMenuAction> menuActions = actions
              .map((action) => action.toMenuAction())
              .toList(growable: false);
          final bool hasEnabledAction = actions
              .any((action) => action.enabled && action.onPressed != null);
          if (moreTooltip == null) {
            return AxiMore(
              actions: menuActions,
              enabled: hasEnabledAction,
              ghost: true,
              usePrimary: true,
            );
          }
          return AxiMore(
            actions: menuActions,
            tooltip: moreTooltip!,
            enabled: hasEnabledAction,
            ghost: true,
            usePrimary: true,
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < actions.length; index++) ...[
              actions[index].inline ??
                  AxiIconButton.ghost(
                    iconData: actions[index].iconData,
                    icon: actions[index].icon,
                    tooltip: actions[index].tooltip ?? actions[index].label,
                    onPressed: actions[index].enabled
                        ? actions[index].onPressed
                        : null,
                    usePrimary: actions[index].usePrimary,
                  ),
              if (index < actions.length - 1) SizedBox(width: spacing),
            ],
          ],
        );
      },
    );
  }
}
