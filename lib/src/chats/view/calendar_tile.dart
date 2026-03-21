// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class CalendarTile extends StatefulWidget {
  const CalendarTile({
    super.key,
    required this.onTap,
    this.nextTask,
    this.currentTask,
    this.dueReminderCount = 0,
  });

  final VoidCallback onTap;
  final CalendarTask? nextTask;
  final CalendarTask? currentTask;
  final int dueReminderCount;

  @override
  State<CalendarTile> createState() => _CalendarTileState();
}

class _CalendarTileState extends State<CalendarTile> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final showBadge = widget.dueReminderCount > 0;
    final badgeDiameter = _resolveBadgeDiameter(context);
    final cutouts = <CutoutSpec>[
      if (showBadge)
        CutoutSpec(
          edge: CutoutEdge.top,
          alignment: const Alignment(0.86, -1),
          depth: (badgeDiameter / 2) + spacing.s,
          thickness: badgeDiameter + (spacing.xs * 2),
          cornerRadius: context.radii.squircle,
          child: _ReminderBadge(
            count: widget.dueReminderCount,
            diameter: badgeDiameter,
          ),
        ),
    ];

    final CalendarTask? displayTask = widget.currentTask ?? widget.nextTask;
    final String subtitleText = widget.currentTask != null
        ? l10n.calendarTileNow(widget.currentTask!.title)
        : widget.nextTask != null
        ? l10n.calendarTileNext(widget.nextTask!.title)
        : l10n.calendarTileNone;

    final scheduledTime = displayTask?.scheduledTime;
    final List<Widget>? trailingActions = scheduledTime == null
        ? null
        : <Widget>[_TaskTimestamp(dateTime: scheduledTime)];

    final tile = AxiListTile(
      onTap: widget.onTap,
      paintSurface: false,
      leadingConstraints: BoxConstraints(
        maxHeight: context.snap(sizing.iconButtonTapTarget),
        maxWidth: context.snap(sizing.iconButtonTapTarget),
      ),
      leading: _CalendarAvatar(highlight: showBadge),
      title: l10n.homeRailCalendar,
      subtitle: subtitleText,
      subtitlePlaceholder: l10n.calendarTileNone,
      contentPadding: context.snapInsets(
        EdgeInsets.symmetric(horizontal: spacing.m, vertical: spacing.xs),
      ),
      minTileHeight: context.snap(sizing.listButtonHeight + spacing.s),
      actions: trailingActions,
    );

    return CutoutSurface(
      backgroundColor: colors.card,
      borderColor: colors.border,
      shape: SquircleBorder(cornerRadius: context.radii.squircle),
      cutouts: cutouts,
      child: tile,
    ).withTapBounce();
  }

  double _resolveBadgeDiameter(BuildContext context) {
    final textScaler = MediaQuery.of(context).textScaler;
    final baseDiameter = context.sizing.iconButtonIconSize;
    final scaledDiameter = textScaler.scale(baseDiameter);
    if (!scaledDiameter.isFinite || scaledDiameter <= 0) {
      return baseDiameter;
    }
    return scaledDiameter;
  }
}

class _CalendarAvatar extends StatelessWidget {
  const _CalendarAvatar({required this.highlight});

  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final motion = context.motion;
    final sizing = context.sizing;
    final background = highlight
        ? colors.primary.withValues(alpha: motion.tapSplashAlpha)
        : colors.secondary.withValues(alpha: motion.tapHoverAlpha);
    final borderColor = highlight ? colors.primary : colors.secondary;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: background,
        shape: SquircleBorder(
          cornerRadius: context.snap(context.radii.squircle),
          side: context.snapBorderSide(
            BorderSide(color: borderColor, width: context.borderSide.width),
          ),
        ),
      ),
      child: SizedBox(
        width: context.snap(sizing.iconButtonTapTarget),
        height: context.snap(sizing.iconButtonTapTarget),
        child: Center(
          child: Icon(
            LucideIcons.calendarClock,
            color: highlight ? colors.primary : colors.secondaryForeground,
            size: context.snap(sizing.iconButtonIconSize),
          ),
        ),
      ),
    );
  }
}

class _ReminderBadge extends StatelessWidget {
  const _ReminderBadge({required this.count, required this.diameter});

  final int count;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return AxiCountBadge(
      count: count,
      diameter: diameter,
      borderColor: colors.card,
    );
  }
}

class _TaskTimestamp extends StatelessWidget {
  const _TaskTimestamp({required this.dateTime});

  final DateTime dateTime;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final label = TimeOfDay.fromDateTime(dateTime).format(context);

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.secondary.withValues(
          alpha: context.motion.tapSplashAlpha,
        ),
        shape: SquircleBorder(
          cornerRadius: context.snap(context.radii.container),
        ),
      ),
      child: Padding(
        padding: context.snapInsets(
          EdgeInsets.symmetric(horizontal: spacing.s, vertical: spacing.xs),
        ),
        child: Text(
          label,
          style: context.textTheme.small.copyWith(
            color: colors.secondaryForeground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
