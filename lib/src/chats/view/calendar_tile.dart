import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class CalendarTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final showBadge = dueReminderCount > 0;
    final badgeWidth =
        showBadge ? _measureBadgeWidth(context, dueReminderCount) : 0.0;
    final cutouts = <CutoutSpec>[
      if (showBadge)
        CutoutSpec(
          edge: CutoutEdge.top,
          alignment: const Alignment(0.86, -1),
          depth: 14,
          thickness: badgeWidth,
          cornerRadius: 18,
          child: _ReminderBadge(count: dueReminderCount),
        ),
    ];

    final CalendarTask? displayTask = currentTask ?? nextTask;
    final String subtitleText = currentTask != null
        ? 'Now: ${currentTask!.title}'
        : nextTask != null
            ? 'Next: ${nextTask!.title}'
            : 'No upcoming tasks';

    final scheduledTime = displayTask?.scheduledTime;
    final List<Widget>? trailingActions = scheduledTime == null
        ? null
        : <Widget>[
            _TaskTimestamp(dateTime: scheduledTime),
          ];

    final tile = AxiListTile(
      onTap: onTap,
      paintSurface: false,
      leadingConstraints: const BoxConstraints(
        maxHeight: 56,
        maxWidth: 56,
      ),
      leading: _CalendarAvatar(
        highlight: showBadge,
      ),
      title: 'Calendar',
      subtitle: subtitleText,
      subtitlePlaceholder: 'No upcoming tasks',
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      minTileHeight: 60,
      actions: trailingActions,
    );

    return CutoutSurface(
      backgroundColor: colors.card,
      borderColor: colors.border,
      shape: SquircleBorder(cornerRadius: 18),
      cutouts: cutouts,
      child: tile,
    ).withTapBounce();
  }
}

class _CalendarAvatar extends StatelessWidget {
  const _CalendarAvatar({required this.highlight});

  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final background = highlight
        ? colors.primary.withValues(alpha: 0.12)
        : colors.secondary.withValues(alpha: 0.18);
    final borderColor =
        highlight ? colors.primary : colors.secondary.withValues(alpha: 0.45);

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: background,
        shape: SquircleBorder(
          cornerRadius: 16,
          side: BorderSide(color: borderColor, width: 1.2),
        ),
      ),
      child: SizedBox(
        width: 46,
        height: 46,
        child: Center(
          child: Icon(
            LucideIcons.calendarClock,
            color: highlight ? colors.primary : colors.secondaryForeground,
            size: 22,
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
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.primary,
        shape: SquircleBorder(
          cornerRadius: 14,
          side: BorderSide(color: colors.card, width: 2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          '$count',
          maxLines: 1,
          style: context.textTheme.small.copyWith(
            color: colors.primaryForeground,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
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
    final label = TimeOfDay.fromDateTime(dateTime).format(context);

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.secondary.withValues(alpha: 0.2),
        shape: SquircleBorder(cornerRadius: 12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

double _measureBadgeWidth(BuildContext context, int count) {
  final painter = TextPainter(
    text: TextSpan(
      text: '$count',
      style: context.textTheme.small.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),
    textDirection: Directionality.of(context),
  )..layout();

  return math.max(44, painter.width + 24);
}
