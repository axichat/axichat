// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/shell/feedback_system.dart';
import 'package:axichat/src/calendar/view/shell/calendar_modal_scope.dart';
import 'package:axichat/src/calendar/view/tasks/fragment_card.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const IconData _criticalPathCopyConfirmIcon = LucideIcons.copy;

class CalendarCriticalPathCopyDecision {
  const CalendarCriticalPathCopyDecision({
    required this.addToPersonal,
    required this.addToChat,
  });

  final bool addToPersonal;
  final bool addToChat;
}

Future<CalendarCriticalPathCopyDecision?> showCalendarCriticalPathCopySheet({
  required BuildContext context,
  required CalendarCriticalPath path,
  required List<CalendarTask> tasks,
  required bool canAddToPersonal,
  required bool canAddToChat,
}) {
  return showAdaptiveBottomSheet<CalendarCriticalPathCopyDecision>(
    context: context,
    isScrollControlled: true,
    useBottomSafeArea: context.calendarUseSheetBottomSafeArea,
    preferDialogOnMobile: true,
    surfacePadding: EdgeInsets.zero,
    builder: (sheetContext) => CalendarCriticalPathCopyDecisionSheet(
      path: path,
      tasks: tasks,
      canAddToPersonal: canAddToPersonal,
      canAddToChat: canAddToChat,
    ),
  );
}

class CalendarCriticalPathCopyDecisionSheet extends StatefulWidget {
  const CalendarCriticalPathCopyDecisionSheet({
    super.key,
    required this.path,
    required this.tasks,
    required this.canAddToPersonal,
    required this.canAddToChat,
  });

  final CalendarCriticalPath path;
  final List<CalendarTask> tasks;
  final bool canAddToPersonal;
  final bool canAddToChat;

  @override
  State<CalendarCriticalPathCopyDecisionSheet> createState() =>
      _CalendarCriticalPathCopyDecisionSheetState();
}

class _CalendarCriticalPathCopyDecisionSheetState
    extends State<CalendarCriticalPathCopyDecisionSheet> {
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
      title: Text(l10n.chatCriticalPathCopyTitle),
      subtitle: Text(l10n.chatCriticalPathCopySubtitle),
      onClose: () => Navigator.of(context).maybePop(),
    );
    return AxiSheetScaffold.scroll(
      header: header,
      footer: AxiSheetActions(
        children: [
          AxiButton.primary(
            onPressed: _handleConfirmPressed,
            leading: Icon(
              _criticalPathCopyConfirmIcon,
              size: context.sizing.menuItemIconSize,
            ),
            child: Text(l10n.chatCriticalPathCopyConfirmLabel),
          ),
        ],
      ),
      children: [
        _CriticalPathCopySectionLabel(
          text: l10n.chatCriticalPathCopyPreviewLabel,
        ),
        CalendarFragmentCard(
          fragment: CalendarFragment.criticalPath(
            path: widget.path,
            tasks: widget.tasks,
          ),
        ),
        SizedBox(height: context.spacing.m),
        _CriticalPathCopySectionLabel(
          text: l10n.chatCriticalPathCopyCalendarsLabel,
        ),
        if (widget.canAddToPersonal)
          _CriticalPathCopyToggle(
            label: l10n.chatCriticalPathCopyPersonalLabel,
            value: _addToPersonal,
            onChanged: (value) => setState(() {
              _addToPersonal = value;
            }),
          ),
        if (widget.canAddToChat) ...[
          SizedBox(height: context.spacing.s),
          _CriticalPathCopyToggle(
            label: l10n.chatCriticalPathCopyChatLabel,
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
        context.l10n.chatCriticalPathCopyMissingSelectionMessage,
      );
      return;
    }
    Navigator.of(context).pop(
      CalendarCriticalPathCopyDecision(
        addToPersonal: _addToPersonal,
        addToChat: _addToChat,
      ),
    );
  }
}

class _CriticalPathCopySectionLabel extends StatelessWidget {
  const _CriticalPathCopySectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.s),
      child: Text(text, style: context.textTheme.sectionLabelM),
    );
  }
}

class _CriticalPathCopyToggle extends StatelessWidget {
  const _CriticalPathCopyToggle({
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
