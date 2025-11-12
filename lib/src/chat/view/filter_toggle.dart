import 'package:axichat/src/storage/models/message_models.dart';
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
    final labels = [
      (MessageTimelineFilter.directOnly, 'Direct only'),
      (MessageTimelineFilter.allWithContact, 'All'),
    ];
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Messages shown',
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
