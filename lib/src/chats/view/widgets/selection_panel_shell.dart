// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SelectionPanelShell extends StatelessWidget {
  const SelectionPanelShell({
    super.key,
    required this.padding,
    required this.child,
    this.includeHorizontalSafeArea = true,
    this.includeBottomSafeArea = true,
  });

  final EdgeInsetsGeometry padding;
  final Widget child;
  final bool includeHorizontalSafeArea;
  final bool includeBottomSafeArea;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return SafeArea(
      top: false,
      left: includeHorizontalSafeArea,
      right: includeHorizontalSafeArea,
      bottom: includeBottomSafeArea,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          border: Border(
            top: BorderSide(color: colors.border, width: 1),
          ),
        ),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class SelectionSummaryHeader extends StatelessWidget {
  const SelectionSummaryHeader({
    super.key,
    required this.count,
    required this.onClear,
    this.tooltip = 'Clear selection',
    this.textStyle,
  });

  final int count;
  final VoidCallback onClear;
  final String tooltip;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = textStyle ?? context.textTheme.muted;
    return Row(
      children: [
        Expanded(
          child: Text(
            '$count selected',
            style: resolvedStyle,
          ),
        ),
        AxiIconButton(
          iconData: LucideIcons.x,
          tooltip: tooltip,
          onPressed: onClear,
        ),
      ],
    );
  }
}
