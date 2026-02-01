// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

import 'calendar_hover_title_scope.dart';

class CalendarHoverTitleBubble extends StatelessWidget {
  const CalendarHoverTitleBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = CalendarHoverTitleScope.maybeOf(context);
    if (controller == null) {
      return const SizedBox.shrink();
    }

    final colors = context.colorScheme;
    final double height = context.sizing.menuItemHeight;
    final double maxWidth = context.sizing.dialogMaxWidth;

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
            constraints: BoxConstraints(maxWidth: maxWidth),
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
                  constraints: BoxConstraints.tightFor(height: height),
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
                        style: context.textTheme.label
                            .copyWith(color: colors.mutedForeground),
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
