import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/chat/view/widgets/calendar_fragment_card.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _taskViewSheetSpacing = 16.0;
const double _taskViewSheetGap = 8.0;
const double _taskViewLabelLetterSpacing = 0.4;
const double _taskViewActionIconSize = 18.0;

const String _taskViewTitle = 'Task details';
const String _taskViewSubtitle = 'Read-only task.';
const String _taskViewPreviewLabel = 'Preview';
const String _taskViewActionsLabel = 'Task actions';
const String _taskViewCopyLabel = 'Copy to calendar';

const IconData _taskViewCopyIcon = LucideIcons.copy;

class CalendarTaskViewSheet extends StatelessWidget {
  const CalendarTaskViewSheet({
    super.key,
    required this.task,
    required this.onCopyPressed,
  });

  final CalendarTask task;
  final VoidCallback onCopyPressed;

  @override
  Widget build(BuildContext context) {
    final header = AxiSheetHeader(
      title: const Text(_taskViewTitle),
      subtitle: const Text(_taskViewSubtitle),
      onClose: () => Navigator.of(context).maybePop(),
    );
    return AxiSheetScaffold.scroll(
      header: header,
      children: [
        const _TaskViewSectionLabel(text: _taskViewPreviewLabel),
        CalendarFragmentCard(
          fragment: CalendarFragment.task(task: task),
        ),
        const SizedBox(height: _taskViewSheetSpacing),
        const _TaskViewSectionLabel(text: _taskViewActionsLabel),
        _TaskViewActionTile(
          icon: _taskViewCopyIcon,
          label: _taskViewCopyLabel,
          onTap: onCopyPressed,
        ),
      ],
    );
  }
}

class _TaskViewSectionLabel extends StatelessWidget {
  const _TaskViewSectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _taskViewSheetGap),
      child: Text(
        text,
        style: context.textTheme.small.copyWith(
          fontWeight: FontWeight.w700,
          color: context.colorScheme.mutedForeground,
          letterSpacing: _taskViewLabelLetterSpacing,
        ),
      ),
    );
  }
}

class _TaskViewActionTile extends StatelessWidget {
  const _TaskViewActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AxiListTile(
      leading: Icon(
        icon,
        size: _taskViewActionIconSize,
        color: context.colorScheme.primary,
      ),
      title: label,
      onTap: onTap,
    );
  }
}
