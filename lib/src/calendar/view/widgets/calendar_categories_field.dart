import 'package:flutter/material.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/view/widgets/task_form_section.dart';
import 'package:axichat/src/calendar/view/widgets/task_text_field.dart';
import 'package:axichat/src/common/ui/ui.dart';

const String _categoriesSectionTitle = 'Categories';
const String _categoriesHintText = 'Add category';
const String _categoriesAddTooltip = 'Add category';
const String _categoriesSplitPattern = r'[,\n]';

class CalendarCategoriesField extends StatefulWidget {
  const CalendarCategoriesField({
    super.key,
    required this.categories,
    required this.onChanged,
    this.title = _categoriesSectionTitle,
    this.hintText = _categoriesHintText,
  });

  final List<String> categories;
  final ValueChanged<List<String>> onChanged;
  final String title;
  final String hintText;

  @override
  State<CalendarCategoriesField> createState() =>
      _CalendarCategoriesFieldState();
}

class _CalendarCategoriesFieldState extends State<CalendarCategoriesField> {
  static final RegExp _splitter = RegExp(_categoriesSplitPattern);
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitInput() {
    final String raw = _controller.text.trim();
    if (raw.isEmpty) {
      return;
    }
    final List<String> additions = _splitCategories(raw);
    if (additions.isEmpty) {
      return;
    }
    final List<String> next = _mergeCategories(
      existing: widget.categories,
      additions: additions,
    );
    if (next.length == widget.categories.length) {
      _controller.clear();
      _focusNode.requestFocus();
      return;
    }
    widget.onChanged(next);
    _controller.clear();
    _focusNode.requestFocus();
  }

  List<String> _splitCategories(String input) {
    return input
        .split(_splitter)
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList();
  }

  List<String> _mergeCategories({
    required List<String> existing,
    required List<String> additions,
  }) {
    final List<String> merged = <String>[];
    final Set<String> seen = <String>{};
    for (final String category in existing) {
      final String trimmed = category.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final String key = trimmed.toLowerCase();
      if (!seen.add(key)) {
        continue;
      }
      merged.add(trimmed);
    }
    for (final String category in additions) {
      final String trimmed = category.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final String key = trimmed.toLowerCase();
      if (!seen.add(key)) {
        continue;
      }
      merged.add(trimmed);
    }
    return merged;
  }

  void _removeCategory(String category) {
    final List<String> next = List<String>.from(widget.categories)
      ..remove(category);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final Widget chips = widget.categories.isEmpty
        ? const SizedBox.shrink()
        : Wrap(
            spacing: calendarGutterSm,
            runSpacing: calendarInsetLg,
            children: widget.categories
                .map(
                  (category) => _CategoryChip(
                    label: category,
                    onRemove: () => _removeCategory(category),
                  ),
                )
                .toList(),
          );

    final Widget inputRow = ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) {
        final bool canSubmit = value.text.trim().isNotEmpty;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TaskTextField(
                controller: _controller,
                focusNode: _focusNode,
                hintText: widget.hintText,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitInput(),
                textCapitalization: TextCapitalization.words,
              ),
            ),
            const SizedBox(width: calendarGutterSm),
            _CategoryAddButton(
              enabled: canSubmit,
              onPressed: _submitInput,
            ),
          ],
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskSectionHeader(title: widget.title),
        const SizedBox(height: calendarGutterSm),
        inputRow,
        if (widget.categories.isNotEmpty) ...[
          const SizedBox(height: calendarGutterSm),
          chips,
        ],
      ],
    );
  }
}

class _CategoryAddButton extends StatelessWidget {
  const _CategoryAddButton({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? handler = enabled ? onPressed : null;
    final Color foreground =
        enabled ? calendarPrimaryColor : calendarSubtitleColor;
    return AxiIconButton(
      iconData: Icons.add,
      tooltip: _categoriesAddTooltip,
      onPressed: handler,
      color: foreground,
      backgroundColor: calendarContainerColor,
      borderColor: calendarBorderColor,
      iconSize: calendarGutterLg,
      buttonSize: AxiIconButton.kDefaultSize,
      tapTargetSize: AxiIconButton.kTapTargetSize,
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = context.textTheme.small.copyWith(
      color: calendarTitleColor,
      fontWeight: FontWeight.w600,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterSm,
        vertical: calendarInsetMd,
      ),
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        border: Border.all(color: calendarBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: labelStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: calendarInsetMd),
          _CategoryRemoveButton(onPressed: onRemove),
        ],
      ),
    );
  }
}

class _CategoryRemoveButton extends StatelessWidget {
  const _CategoryRemoveButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color foreground = calendarSubtitleColor;
    final BorderRadius radius = BorderRadius.circular(calendarBorderRadius);
    return Material(
      type: MaterialType.transparency,
      child: InkResponse(
        onTap: onPressed,
        containedInkWell: true,
        radius: calendarGutterLg,
        borderRadius: radius,
        hoverColor: calendarPrimaryColor.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(calendarInsetSm),
          child: Icon(
            Icons.close,
            size: calendarGutterMd,
            color: foreground,
          ),
        ),
      ),
    );
  }
}
