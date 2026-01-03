// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

const double _defaultAppBarActionSpacing = 8.0;

class AppBarActionItem {
  const AppBarActionItem({
    required this.label,
    required this.iconData,
    this.icon,
    this.onPressed,
    this.enabled = true,
    this.destructive = false,
    this.tooltip,
  });

  final String label;
  final IconData iconData;
  final Widget? icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool destructive;
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
  });

  final List<AppBarActionItem> actions;
  final double spacing;
  final double overflowBreakpoint;
  final String? moreTooltip;
  final bool? forceCollapsed;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }
    final double width = MediaQuery.sizeOf(context).width;
    final bool shouldCollapse =
        forceCollapsed ?? width < overflowBreakpoint;
    if (shouldCollapse) {
      final menuActions = actions
          .map((action) => action.toMenuAction())
          .toList(growable: false);
      final bool hasEnabledAction =
          actions.any((action) => action.enabled && action.onPressed != null);
      if (moreTooltip == null) {
        return AxiMore(
          actions: menuActions,
          enabled: hasEnabledAction,
          ghost: true,
        );
      }
      return AxiMore(
        actions: menuActions,
        tooltip: moreTooltip!,
        enabled: hasEnabledAction,
        ghost: true,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          AxiIconButton.ghost(
            iconData: actions[index].iconData,
            icon: actions[index].icon,
            tooltip: actions[index].tooltip ?? actions[index].label,
            onPressed: actions[index].enabled ? actions[index].onPressed : null,
          ),
          if (index < actions.length - 1) SizedBox(width: spacing),
        ],
      ],
    );
  }
}
