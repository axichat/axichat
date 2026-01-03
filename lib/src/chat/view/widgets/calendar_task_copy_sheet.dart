// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/chat/view/widgets/calendar_fragment_card.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _taskCopySheetSpacing = 16.0;
const double _taskCopySheetGap = 8.0;
const double _taskCopySectionGap = 12.0;
const double _taskCopyHeaderIconSize = 18.0;
const double _taskCopyLabelLetterSpacing = 0.4;

const String _taskCopyTitle = 'Copy task';
const String _taskCopySubtitle = 'Choose which calendars should receive it.';
const String _taskCopyPreviewLabel = 'Preview';
const String _taskCopyCalendarsLabel = 'Calendars';
const String _taskCopyPersonalLabel = 'Add to personal calendar';
const String _taskCopyChatLabel = 'Add to chat calendar';
const String _taskCopyConfirmLabel = 'Copy';
const String _taskCopyMissingSelectionMessage = 'Select at least one calendar.';

const IconData _taskCopyConfirmIcon = LucideIcons.copy;

class CalendarTaskCopyDecision {
  const CalendarTaskCopyDecision({
    required this.addToPersonal,
    required this.addToChat,
  });

  final bool addToPersonal;
  final bool addToChat;
}

Future<CalendarTaskCopyDecision?> showCalendarTaskCopySheet({
  required BuildContext context,
  required CalendarTask task,
  required bool canAddToPersonal,
  required bool canAddToChat,
}) {
  return showAdaptiveBottomSheet<CalendarTaskCopyDecision>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => CalendarTaskCopyDecisionSheet(
      task: task,
      canAddToPersonal: canAddToPersonal,
      canAddToChat: canAddToChat,
    ),
  );
}

class CalendarTaskCopyDecisionSheet extends StatefulWidget {
  const CalendarTaskCopyDecisionSheet({
    super.key,
    required this.task,
    required this.canAddToPersonal,
    required this.canAddToChat,
  });

  final CalendarTask task;
  final bool canAddToPersonal;
  final bool canAddToChat;

  @override
  State<CalendarTaskCopyDecisionSheet> createState() =>
      _CalendarTaskCopyDecisionSheetState();
}

class _CalendarTaskCopyDecisionSheetState
    extends State<CalendarTaskCopyDecisionSheet> {
  late bool _addToPersonal;
  late bool _addToChat;

  @override
  void initState() {
    super.initState();
    _addToPersonal = widget.canAddToPersonal;
    _addToChat = widget.canAddToChat && !widget.canAddToPersonal;
  }

  @override
  Widget build(BuildContext context) {
    final header = AxiSheetHeader(
      title: const Text(_taskCopyTitle),
      subtitle: const Text(_taskCopySubtitle),
      onClose: () => Navigator.of(context).maybePop(),
    );
    final body = AxiSheetScaffold.scroll(
      header: header,
      children: [
        const _TaskCopySectionLabel(text: _taskCopyPreviewLabel),
        CalendarFragmentCard(
          fragment: CalendarFragment.task(task: widget.task),
        ),
        const SizedBox(height: _taskCopySheetSpacing),
        const _TaskCopySectionLabel(text: _taskCopyCalendarsLabel),
        if (widget.canAddToPersonal)
          _TaskCopyToggle(
            label: _taskCopyPersonalLabel,
            value: _addToPersonal,
            onChanged: (value) => setState(() {
              _addToPersonal = value;
            }),
          ),
        if (widget.canAddToChat) ...[
          const SizedBox(height: _taskCopySectionGap),
          _TaskCopyToggle(
            label: _taskCopyChatLabel,
            value: _addToChat,
            onChanged: (value) => setState(() {
              _addToChat = value;
            }),
          ),
        ],
        const SizedBox(height: _taskCopySheetSpacing),
        _TaskCopyActionRow(
          onPressed: _handleConfirmPressed,
          label: _taskCopyConfirmLabel,
          iconData: _taskCopyConfirmIcon,
        ),
      ],
    );
    return body;
  }

  void _handleConfirmPressed() {
    if (!_addToPersonal && !_addToChat) {
      FeedbackSystem.showError(
        context,
        _taskCopyMissingSelectionMessage,
      );
      return;
    }
    Navigator.of(context).pop(
      CalendarTaskCopyDecision(
        addToPersonal: _addToPersonal,
        addToChat: _addToChat,
      ),
    );
  }
}

class _TaskCopySectionLabel extends StatelessWidget {
  const _TaskCopySectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _taskCopySheetGap),
      child: Text(
        text,
        style: context.textTheme.small.copyWith(
          fontWeight: FontWeight.w700,
          color: context.colorScheme.mutedForeground,
          letterSpacing: _taskCopyLabelLetterSpacing,
        ),
      ),
    );
  }
}

class _TaskCopyToggle extends StatelessWidget {
  const _TaskCopyToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ShadSwitch(
      label: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _TaskCopyActionRow extends StatelessWidget {
  const _TaskCopyActionRow({
    required this.onPressed,
    required this.label,
    required this.iconData,
  });

  final VoidCallback onPressed;
  final String label;
  final IconData iconData;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ShadButton(
        size: ShadButtonSize.sm,
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: _taskCopyHeaderIconSize),
            const SizedBox(width: _taskCopySheetGap),
            Text(label),
          ],
        ),
      ),
    );
  }
}
