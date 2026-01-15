// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _calendarSheetHeaderCloseIconSize = 16;
const double _calendarSheetHeaderCloseButtonSize = 34;
const double _calendarSheetHeaderCloseTapTargetSize = 40;
const double _calendarSheetHeaderTitleFontSize = 16;
const FontWeight _calendarSheetHeaderTitleFontWeight = FontWeight.w700;

class CalendarSheetCloseButton extends StatelessWidget {
  const CalendarSheetCloseButton({
    super.key,
    required this.onPressed,
    this.tooltip,
    this.iconData = LucideIcons.x,
    this.color,
  });

  final VoidCallback onPressed;
  final String? tooltip;
  final IconData iconData;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AxiIconButton(
      iconData: iconData,
      tooltip: tooltip ?? MaterialLocalizations.of(context).closeButtonTooltip,
      iconSize: _calendarSheetHeaderCloseIconSize,
      buttonSize: _calendarSheetHeaderCloseButtonSize,
      tapTargetSize: _calendarSheetHeaderCloseTapTargetSize,
      backgroundColor: Colors.transparent,
      borderColor: Colors.transparent,
      color: color ?? context.colorScheme.mutedForeground,
      onPressed: onPressed,
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
    final TextStyle resolvedTitleStyle = titleStyle ??
        textTheme.h3.copyWith(
          fontSize: _calendarSheetHeaderTitleFontSize,
          fontWeight: _calendarSheetHeaderTitleFontWeight,
        );
    final TextStyle resolvedSubtitleStyle = subtitleStyle ?? textTheme.muted;

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
                if (actions.isNotEmpty) const SizedBox(width: calendarGutterSm),
                CalendarSheetCloseButton(
                  iconData: closeIcon,
                  tooltip: closeTooltip,
                  color: closeButtonColor,
                  onPressed: onClose!,
                ),
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: calendarInsetSm),
            Text(subtitle!, style: resolvedSubtitleStyle),
          ],
        ],
      ),
    );
  }
}
