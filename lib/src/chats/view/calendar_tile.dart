// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

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
  double _cachedBadgeWidth = 0;
  int? _cachedBadgeCount;
  double _textScaleFactor = 1;
  int _badgeStyleHash = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final showBadge = widget.dueReminderCount > 0;
    final badgeWidth = showBadge
        ? _resolveBadgeWidth(
            context,
            widget.dueReminderCount,
          )
        : 0.0;
    final cutouts = <CutoutSpec>[
      if (showBadge)
        CutoutSpec(
          edge: CutoutEdge.top,
          alignment: Alignment.topRight,
          depth: spacing.m,
          thickness: badgeWidth,
          cornerRadius: context.radii.container,
          child: _ReminderBadge(count: widget.dueReminderCount),
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
        maxHeight: sizing.iconButtonTapTarget,
        maxWidth: sizing.iconButtonTapTarget,
      ),
      leading: _CalendarAvatar(highlight: showBadge),
      title: l10n.homeRailCalendar,
      subtitle: subtitleText,
      subtitlePlaceholder: l10n.calendarTileNone,
      contentPadding: EdgeInsets.symmetric(
        horizontal: spacing.m,
        vertical: spacing.xs,
      ),
      minTileHeight: sizing.listButtonHeight + spacing.s,
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

  double _resolveBadgeWidth(BuildContext context, int count) {
    final textScaler = MediaQuery.of(context).textScaler;
    final scaleFactor = textScaler.scale(1);
    final spacing = context.spacing;
    final badgeStyle = context.textTheme.small.copyWith(
      fontWeight: FontWeight.w700,
    );
    final nextStyleHash = Object.hash(
      badgeStyle.fontSize,
      badgeStyle.fontFamily,
      badgeStyle.fontWeight,
      badgeStyle.letterSpacing,
      spacing.s,
      spacing.xs,
      spacing.l,
    );
    if (_cachedBadgeCount == count &&
        _cachedBadgeWidth > 0 &&
        _textScaleFactor == scaleFactor &&
        _badgeStyleHash == nextStyleHash) {
      return _cachedBadgeWidth;
    }
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$count',
        style: badgeStyle,
      ),
      textDirection: Directionality.of(context),
      textScaler: textScaler,
    )..layout();
    final horizontalPadding = spacing.m;
    final minWidth = spacing.l;
    _cachedBadgeCount = count;
    _textScaleFactor = scaleFactor;
    _badgeStyleHash = nextStyleHash;
    _cachedBadgeWidth =
        math.max(minWidth, textPainter.width + (horizontalPadding * 2));
    return _cachedBadgeWidth;
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
          cornerRadius: context.radii.squircle,
          side: BorderSide(
            color: borderColor,
            width: context.borderSide.width,
          ),
        ),
      ),
      child: SizedBox(
        width: sizing.iconButtonTapTarget,
        height: sizing.iconButtonTapTarget,
        child: Center(
          child: Icon(
            LucideIcons.calendarClock,
            color: highlight ? colors.primary : colors.secondaryForeground,
            size: sizing.iconButtonIconSize,
          ),
        ),
      ),
    );
  }
}

class _ReminderBadge extends StatelessWidget {
  const _ReminderBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.primary,
        shape: SquircleBorder(
          cornerRadius: context.radii.container,
          side: BorderSide(
            color: colors.card,
            width: context.borderSide.width,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.m,
          vertical: spacing.xs,
        ),
        child: Text(
          '$count',
          maxLines: 1,
          style: context.textTheme.small.copyWith(
            color: colors.primaryForeground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
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
        shape: SquircleBorder(cornerRadius: context.radii.container),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.s,
          vertical: spacing.xs,
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
