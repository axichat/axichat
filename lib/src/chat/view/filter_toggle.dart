// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models/message_models.dart';
import 'package:flutter/widgets.dart';

class FilterToggle extends StatelessWidget {
  const FilterToggle({
    super.key,
    required this.selected,
    required this.onChanged,
    this.padding,
  });

  final MessageTimelineFilter selected;
  final ValueChanged<MessageTimelineFilter> onChanged;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final textTheme = context.textTheme;
    final colors = context.colorScheme;
    final labels = [
      (MessageTimelineFilter.directOnly, l10n.chatFilterDirectOnlyLabel),
      (MessageTimelineFilter.allWithContact, l10n.chatFilterAllLabel),
    ];
    return Padding(
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: spacing.m,
            vertical: spacing.s,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.chatFilterTitle,
            style: textTheme.small.copyWith(
              color: colors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: spacing.s),
          Wrap(
            spacing: spacing.s,
            runSpacing: spacing.xs,
            children: [
              for (final entry in labels)
                AxiButton(
                  variant: entry.$1 == selected
                      ? AxiButtonVariant.secondary
                      : AxiButtonVariant.outline,
                  onPressed: () => onChanged(entry.$1),
                  child: Text(entry.$2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
