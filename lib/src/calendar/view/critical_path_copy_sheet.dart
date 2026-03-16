// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/calendar/view/fragment_card.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _criticalPathCopySheetSpacing = 16.0;
const double _criticalPathCopySheetGap = 8.0;
const double _criticalPathCopySectionGap = 12.0;
const double _criticalPathCopyHeaderIconSize = 18.0;
const double _criticalPathCopyLabelLetterSpacing = 0.4;

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
        const SizedBox(height: _criticalPathCopySheetSpacing),
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
          const SizedBox(height: _criticalPathCopySectionGap),
          _CriticalPathCopyToggle(
            label: l10n.chatCriticalPathCopyChatLabel,
            value: _addToChat,
            onChanged: (value) => setState(() {
              _addToChat = value;
            }),
          ),
        ],
        const SizedBox(height: _criticalPathCopySheetSpacing),
        _CriticalPathCopyActionRow(
          onPressed: _handleConfirmPressed,
          label: l10n.chatCriticalPathCopyConfirmLabel,
          iconData: _criticalPathCopyConfirmIcon,
        ),
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
      padding: const EdgeInsets.only(bottom: _criticalPathCopySheetGap),
      child: Text(
        text,
        style: context.textTheme.small.copyWith(
          fontWeight: FontWeight.w700,
          color: context.colorScheme.mutedForeground,
          letterSpacing: _criticalPathCopyLabelLetterSpacing,
        ),
      ),
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

class _CriticalPathCopyActionRow extends StatelessWidget {
  const _CriticalPathCopyActionRow({
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
      child: AxiButton.primary(
        size: AxiButtonSize.sm,
        onPressed: onPressed,
        leading: Icon(iconData, size: _criticalPathCopyHeaderIconSize),
        child: Text(label),
      ),
    );
  }
}
