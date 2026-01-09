// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

import 'package:axichat/src/common/ui/ui.dart';
import 'task_form_section.dart';

const String _categoriesSectionTitle = 'Categories';
const String _categoriesHintText = 'Add category';
const String _categoriesSplitPattern = r'[,\n]';
const double _categoryInputMinWidth = 140.0;
const double _categoryInputMaxWidth = 260.0;
const double _categoryChipMaxWidth = 180.0;

class CalendarCategoriesField extends StatefulWidget {
  const CalendarCategoriesField({
    super.key,
    required this.categories,
    required this.onChanged,
    this.title = _categoriesSectionTitle,
    this.hintText = _categoriesHintText,
    this.enabled = true,
    this.surfaceColor,
  });

  final List<String> categories;
  final ValueChanged<List<String>> onChanged;
  final String title;
  final String hintText;
  final bool enabled;
  final Color? surfaceColor;

  @override
  State<CalendarCategoriesField> createState() =>
      _CalendarCategoriesFieldState();
}

class _CalendarCategoriesFieldState extends State<CalendarCategoriesField> {
  static final RegExp _splitter = RegExp(_categoriesSplitPattern);
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode.addListener(_handleFocusChanged);
    _expanded = _shouldStartExpanded(widget);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CalendarCategoriesField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_expanded && _shouldStartExpanded(widget)) {
      setState(() => _expanded = true);
    }
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus || !widget.enabled) {
      return;
    }
    _submitInput(requestFocus: false);
  }

  void _submitInput({bool requestFocus = true}) {
    if (!widget.enabled) {
      return;
    }
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
      _maybeRequestFocus(requestFocus);
      return;
    }
    widget.onChanged(next);
    _controller.clear();
    _maybeRequestFocus(requestFocus);
  }

  void _maybeRequestFocus(bool requestFocus) {
    if (!requestFocus) {
      return;
    }
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

  bool _shouldStartExpanded(CalendarCategoriesField widget) {
    return widget.categories.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color barBackground = widget.surfaceColor ?? calendarContainerColor;
    final List<Widget> chipWidgets = <Widget>[
      ...widget.categories.map(
        (category) => _CategoryChip(
          label: category,
          backgroundColor: barBackground,
          onRemove: widget.enabled ? () => _removeCategory(category) : null,
        ),
      ),
      _CategoryInputField(
        controller: _controller,
        focusNode: _focusNode,
        hintText: widget.hintText,
        onSubmitted: _submitInput,
        enabled: widget.enabled,
        backgroundColor: barBackground,
      ),
    ];
    final Widget content = ChipsBarSurface(
      backgroundColor: barBackground,
      borderSide: BorderSide(color: calendarBorderColor),
      includeTopBorder: false,
      padding: calendarPaddingLg,
      child: Wrap(
        spacing: calendarGutterSm,
        runSpacing: calendarGutterSm,
        children: chipWidgets,
      ),
    );
    final Widget? badge = widget.categories.isEmpty
        ? null
        : ChipsBarCountBadge(
            count: widget.categories.length,
            expanded: _expanded,
            colors: colors,
          );
    return TaskSectionExpander(
      title: widget.title,
      isExpanded: _expanded,
      onToggle: () => setState(() => _expanded = !_expanded),
      badge: badge,
      enabled: widget.enabled,
      child: content,
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.backgroundColor,
    this.onRemove,
  });

  final String label;
  final Color backgroundColor;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = Theme.of(context).textTheme.bodyMedium ??
        const TextStyle(fontWeight: FontWeight.w600);
    return InputChip(
      shape: const StadiumBorder(),
      showCheckmark: false,
      backgroundColor: backgroundColor,
      selectedColor: backgroundColor,
      side: BorderSide(color: calendarBorderColor),
      labelStyle: labelStyle.copyWith(color: calendarTitleColor),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _categoryChipMaxWidth),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      deleteIcon: onRemove == null
          ? null
          : Icon(
              Icons.close,
              size: calendarGutterMd,
              color: calendarSubtitleColor,
            ),
      onDeleted: onRemove,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterSm,
        vertical: calendarInsetSm,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: calendarInsetSm),
    );
  }
}

class _CategoryInputField extends StatelessWidget {
  const _CategoryInputField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onSubmitted,
    required this.enabled,
    required this.backgroundColor,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final VoidCallback onSubmitted;
  final bool enabled;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color hintColor = colors.onSurfaceVariant.withValues(alpha: 0.8);
    final TextStyle? textStyle = Theme.of(context).textTheme.bodyMedium;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _categoryInputMinWidth,
        maxWidth: _categoryInputMaxWidth,
      ),
      child: SizedBox(
        height: chipsBarHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(chipsBarHeight / 2),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: calendarGutterSm),
            child: Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: const InputDecorationTheme(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              child: AxiTextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: 1,
                enabled: enabled,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: textStyle?.copyWith(color: hintColor),
                ),
                style: textStyle,
                strutStyle: textStyle == null
                    ? null
                    : StrutStyle.fromTextStyle(textStyle),
                textAlignVertical: TextAlignVertical.center,
                onSubmitted: (_) => onSubmitted(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
