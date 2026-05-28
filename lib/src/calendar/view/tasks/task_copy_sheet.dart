// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/shell/feedback_system.dart';
import 'package:axichat/src/calendar/view/shell/calendar_modal_scope.dart';
import 'package:axichat/src/calendar/view/tasks/fragment_card.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
    useBottomSafeArea: context.calendarUseSheetBottomSafeArea,
    preferDialogOnMobile: true,
    surfacePadding: EdgeInsets.zero,
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
    final l10n = context.l10n;
    final header = AxiSheetHeader(
      title: Text(l10n.chatTaskCopyTitle),
      subtitle: Text(l10n.chatTaskCopySubtitle),
      onClose: () => Navigator.of(context).maybePop(),
    );
    return AxiSheetScaffold.scroll(
      header: header,
      footer: AxiSheetActions(
        children: [
          AxiButton.primary(
            onPressed: _handleConfirmPressed,
            leading: Icon(
              _taskCopyConfirmIcon,
              size: context.sizing.menuItemIconSize,
            ),
            child: Text(l10n.chatTaskCopyConfirmLabel),
          ),
        ],
      ),
      children: [
        _TaskCopySectionLabel(text: l10n.chatTaskCopyPreviewLabel),
        CalendarFragmentCard(
          fragment: CalendarFragment.task(task: widget.task),
        ),
        SizedBox(height: context.spacing.m),
        _TaskCopySectionLabel(text: l10n.chatTaskCopyCalendarsLabel),
        if (widget.canAddToPersonal)
          _TaskCopyToggle(
            label: l10n.chatTaskCopyPersonalLabel,
            value: _addToPersonal,
            onChanged: (value) => setState(() {
              _addToPersonal = value;
            }),
          ),
        if (widget.canAddToChat) ...[
          SizedBox(height: context.spacing.s),
          _TaskCopyToggle(
            label: l10n.chatTaskCopyChatLabel,
            value: _addToChat,
            onChanged: (value) => setState(() {
              _addToChat = value;
            }),
          ),
        ],
      ],
    );
  }

  void _handleConfirmPressed() {
    if (!_addToPersonal && !_addToChat) {
      FeedbackSystem.showError(
        context,
        context.l10n.chatTaskCopyMissingSelectionMessage,
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
      padding: EdgeInsets.only(bottom: context.spacing.s),
      child: Text(text, style: context.textTheme.sectionLabelM),
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
    return ShadSwitch(label: Text(label), value: value, onChanged: onChanged);
  }
}
