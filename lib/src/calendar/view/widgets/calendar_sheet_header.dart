// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class CalendarSheetCloseButton extends StatelessWidget {
  const CalendarSheetCloseButton({
    super.key,
    required this.onClose,
    this.tooltip,
    this.color,
    this.iconData = LucideIcons.x,
  });

  final VoidCallback onClose;
  final String? tooltip;
  final Color? color;
  final IconData iconData;

  @override
  Widget build(BuildContext context) {
    return ModalCloseButton(
      onPressed: onClose,
      tooltip: tooltip ?? MaterialLocalizations.of(context).closeButtonTooltip,
      iconData: iconData,
      backgroundColor: Colors.transparent,
      borderColor: Colors.transparent,
      color: color ?? context.colorScheme.mutedForeground,
    );
  }
}

class CalendarSheetHeader extends StatelessWidget {
  const CalendarSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onClose,
    this.actions = const <Widget>[],
    this.padding = EdgeInsets.zero,
    this.titleStyle,
    this.subtitleStyle,
    this.closeButtonColor,
    this.closeTooltip,
    this.closeIcon = LucideIcons.x,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onClose;
  final List<Widget> actions;
  final EdgeInsets padding;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final Color? closeButtonColor;
  final String? closeTooltip;
  final IconData closeIcon;

  @override
  Widget build(BuildContext context) {
    final ShadTextTheme textTheme = context.textTheme;
    final TextStyle resolvedTitleStyle = titleStyle ?? textTheme.h4.strong;
    final TextStyle resolvedSubtitleStyle = subtitleStyle ?? textTheme.muted;
    final spacing = context.spacing;

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: resolvedTitleStyle)),
              ...actions,
              if (onClose != null) ...[
                if (actions.isNotEmpty) SizedBox(width: spacing.s),
                CalendarSheetCloseButton(
                  iconData: closeIcon,
                  tooltip: closeTooltip,
                  color: closeButtonColor,
                  onClose: onClose!,
                ),
              ],
            ],
          ),
          if (subtitle != null) ...[
            SizedBox(height: spacing.xxs),
            Text(subtitle!, style: resolvedSubtitleStyle),
          ],
        ],
      ),
    );
  }
}
