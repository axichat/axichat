// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

import 'calendar_hover_title_scope.dart';

class CalendarHoverTitleBubble extends StatelessWidget {
  const CalendarHoverTitleBubble({super.key});

  static const double _height = 30.0;
  static const double _maxWidth = 640.0;

  @override
  Widget build(BuildContext context) {
    final controller = CalendarHoverTitleScope.maybeOf(context);
    if (controller == null) {
      return const SizedBox.shrink();
    }

    final colors = context.colorScheme;

    return IgnorePointer(
      ignoring: true,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final String title = controller.title ?? '';
          if (title.isEmpty) {
            return const SizedBox.shrink();
          }

          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: IntrinsicWidth(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.card,
                  border: Border(
                    top: BorderSide(color: colors.border),
                    right: BorderSide(color: colors.border),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints.tightFor(height: _height),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: calendarInsetLg,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.small.copyWith(
                          fontSize: 13,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
