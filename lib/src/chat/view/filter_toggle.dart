// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/storage/models/message_models.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';

class FilterToggle extends StatelessWidget {
  const FilterToggle({
    super.key,
    required this.selected,
    required this.contactName,
    required this.onChanged,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 8),
  });

  final MessageTimelineFilter selected;
  final String contactName;
  final ValueChanged<MessageTimelineFilter> onChanged;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = [
      (MessageTimelineFilter.directOnly, l10n.chatFilterDirectOnlyLabel),
      (MessageTimelineFilter.allWithContact, l10n.chatFilterAllLabel),
    ];
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.chatFilterTitle,
            style: textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in labels)
                _FilterChip(
                  label: entry.$2,
                  selected: entry.$1 == selected,
                  onSelected: () => onChanged(entry.$1),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final background = selected
        ? colors.primary.withValues(alpha: 0.16)
        : colors.surfaceContainerHighest.withValues(alpha: 0.6);
    final foreground = selected
        ? colors.primary
        : colors.onSurfaceVariant.withValues(alpha: 0.9);
    return ChoiceChip(
      showCheckmark: false,
      selected: selected,
      onSelected: (_) => onSelected(),
      label: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      selectedColor: background,
      backgroundColor: background.withValues(alpha: selected ? 1 : 0.8),
      side: BorderSide.none,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
