// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/common/ui/status_colors.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PresenceIndicator extends StatelessWidget {
  const PresenceIndicator({super.key, required this.presence, this.status});

  final Presence presence;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return PresenceCircle(presence: presence);
  }
}

class PresenceCircle extends StatelessWidget {
  const PresenceCircle({super.key, required this.presence});

  final Presence presence;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final sizing = context.sizing;
    final spacing = context.spacing;
    final indicatorSize = sizing.progressIndicatorSize;
    final double iconSize = (indicatorSize - spacing.xs)
        .clamp(0.0, indicatorSize)
        .toDouble();
    final presenceColor = _presenceColor(colors);
    return Container(
      height: indicatorSize,
      width: indicatorSize,
      decoration: ShapeDecoration(
        shape: CircleBorder(
          side: BorderSide(
            color: context.borderSide.color,
            width: context.borderSide.width,
          ),
        ),
        color: presenceColor,
      ),
      child: presence.isDnd
          ? Icon(LucideIcons.minus, color: colors.background, size: iconSize)
          : presence.isUnknown
          ? Icon(
              Icons.question_mark,
              color: colors.mutedForeground,
              size: iconSize,
            )
          : null,
    );
  }

  Color _presenceColor(ShadColorScheme colors) => switch (presence) {
    Presence.unavailable => colors.muted,
    Presence.xa => colors.warning,
    Presence.away => colors.warning,
    Presence.dnd => colors.destructive,
    Presence.chat => colors.green,
    Presence.unknown => colors.muted,
  };
}
