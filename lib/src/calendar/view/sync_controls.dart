import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/utils/calendar_share.dart';
import 'package:axichat/src/calendar/utils/calendar_transfer_service.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'calendar_transfer_sheet.dart';
import 'feedback_system.dart';

class SyncControls extends StatefulWidget {
  const SyncControls({
    super.key,
    required this.state,
  });

  final CalendarState state;

  @override
  State<SyncControls> createState() => _SyncControlsState();
}

const String _noCalendarDataImportMessage =
    'No calendar data detected in the selected file.';
const String _calendarImportSuccessMessage = 'Imported calendar data.';
const String _calendarImportWarningTitle = 'Import calendar';
const String _calendarImportWarningMessage =
    'Importing will merge data and override matching items in your current '
    'calendar. Continue?';
const String _calendarImportConfirmLabel = 'Import';

class _SyncControlsState extends State<SyncControls> {
  final CalendarTransferService _transferService =
      const CalendarTransferService();

  CalendarState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    return _InlineSyncControls(
      state: state,
      onExportCalendar: _handleExportAll,
      onImportCalendar: _handleImportCalendar,
    );
  }

  void _handleExportAll() {
    unawaited(_exportAll());
  }

  void _handleImportCalendar() {
    unawaited(_importCalendar());
  }

  Future<void> _exportAll() async {
    final model = context.read<CalendarBloc>().state.model;
    if (!model.hasCalendarData) {
      FeedbackSystem.showInfo(context, 'No tasks available to export.');
      return;
    }
    final format = await showCalendarExportFormatSheet(context);
    if (!mounted || format == null) return;
    try {
      if (format == CalendarExportFormat.ics && model.tasks.isEmpty) {
        FeedbackSystem.showInfo(context, 'No tasks available to export.');
        return;
      }
      final file = format == CalendarExportFormat.json
          ? await _transferService.exportModel(model: model)
          : await _transferService.exportTasks(
              tasks: model.tasks.values,
              format: format,
            );
      final CalendarShareOutcome shareOutcome = await shareCalendarExport(
        file: file,
        subject: 'Axichat calendar export',
        text: 'Axichat calendar export (${format.label})',
      );
      if (!mounted) return;
      FeedbackSystem.showSuccess(
        context,
        calendarShareSuccessMessage(
          outcome: shareOutcome,
          filePath: file.path,
          sharedText: 'Export ready to share.',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      FeedbackSystem.showError(
        context,
        'Failed to export calendar: $error',
      );
    }
  }

  Future<void> _importCalendar() async {
    final shouldImport = await confirm(
      context,
      title: _calendarImportWarningTitle,
      message: _calendarImportWarningMessage,
      confirmLabel: _calendarImportConfirmLabel,
    );
    if (shouldImport != true) {
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['ics', 'json'],
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final path = result.files.single.path;
    if (path == null) {
      if (!mounted) return;
      FeedbackSystem.showError(
        context,
        'Unable to access the selected file.',
      );
      return;
    }
    final file = File(path);
    try {
      final result = await _transferService.importFromFile(file);
      if (result.isFullModel && result.model != null) {
        final importedModel = result.model!;
        if (!importedModel.hasCalendarData) {
          if (!mounted) return;
          FeedbackSystem.showInfo(
            context,
            _noCalendarDataImportMessage,
          );
          return;
        }
        if (!mounted) return;
        context
            .read<CalendarBloc>()
            .add(CalendarEvent.modelImported(model: importedModel));
        FeedbackSystem.showSuccess(
          context,
          _calendarImportSuccessMessage,
        );
        return;
      }
      final tasks = result.tasks;
      if (tasks.isEmpty) {
        if (!mounted) return;
        FeedbackSystem.showInfo(
          context,
          'No tasks detected in the selected file.',
        );
        return;
      }
      if (!mounted) return;
      context
          .read<CalendarBloc>()
          .add(CalendarEvent.tasksImported(tasks: tasks));
      FeedbackSystem.showSuccess(
        context,
        'Imported ${tasks.length} task${tasks.length == 1 ? '' : 's'}.',
      );
    } catch (error) {
      if (!mounted) return;
      FeedbackSystem.showError(
        context,
        'Import failed: $error',
      );
    }
  }
}

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({
    super.key,
    required this.state,
  });

  final CalendarState state;

  @override
  Widget build(BuildContext context) {
    final (String label, Widget indicator) = _resolveVisual(context);
    return AxiTooltip(
      builder: (_) => Text(label),
      child: Semantics(
        label: label,
        child: indicator,
      ),
    );
  }

  (String, Widget) _resolveVisual(BuildContext context) {
    if (state.isSyncing) {
      return (
        'Syncing…',
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (state.syncError != null) {
      return (
        'Sync failed',
        const Icon(
          LucideIcons.cloudAlert,
          size: 16,
          color: Colors.red,
        ),
      );
    }
    if (state.lastSyncTime != null) {
      return (
        'Synced',
        const Icon(
          LucideIcons.cloudCheck,
          size: 16,
          color: Colors.green,
        ),
      );
    }
    final Color fallbackColor =
        Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
    return (
      'Not synced yet',
      Icon(
        LucideIcons.cloud,
        size: 16,
        color: fallbackColor,
      ),
    );
  }
}

class _InlineSyncControls extends StatelessWidget {
  const _InlineSyncControls({
    required this.state,
    required this.onExportCalendar,
    required this.onImportCalendar,
  });

  final CalendarState state;
  final VoidCallback onExportCalendar;
  final VoidCallback onImportCalendar;

  @override
  Widget build(BuildContext context) {
    final disabled = state.isSyncing;
    final hasCalendarData = state.model.hasCalendarData;
    final statusText = _statusTextFor(state);
    final lastSyncTime = state.lastSyncTime;
    final statusColor = _statusColorFor(context, state);

    return Wrap(
      spacing: calendarGutterSm,
      runSpacing: calendarInsetMd,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SyncStatusIndicator(state: state),
            const SizedBox(width: 6),
            Text(
              statusText,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
            if (lastSyncTime != null && !state.isSyncing) ...[
              const SizedBox(width: 6),
              Text(
                TimeFormatter.formatSyncTime(lastSyncTime),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).hintColor),
              ),
            ],
          ],
        ),
        CalendarTransferMenuButton(
          hasCalendarData: hasCalendarData,
          onExport: onExportCalendar,
          onImport: onImportCalendar,
          busy: disabled,
        ),
      ],
    );
  }
}

String _statusTextFor(CalendarState state) {
  if (state.isSyncing) return 'Syncing...';
  if (state.syncError != null) return 'Sync failed';
  if (state.lastSyncTime != null) return 'Synced';
  return 'Idle';
}

Color _statusColorFor(BuildContext context, CalendarState state) {
  if (state.isSyncing) return Colors.orange;
  if (state.syncError != null) return Colors.red;
  if (state.lastSyncTime != null) return Colors.green;
  return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
}

class CalendarTransferMenuButton extends StatelessWidget {
  const CalendarTransferMenuButton({
    super.key,
    required this.hasCalendarData,
    required this.onExport,
    required this.onImport,
    this.busy = false,
  });

  final bool hasCalendarData;
  final VoidCallback onExport;
  final VoidCallback onImport;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final bool canExport = hasCalendarData && !busy;
    final bool canImport = !busy;
    return AxiMore(
      actions: [
        AxiMenuAction(
          icon: LucideIcons.upload,
          label: 'Export calendar',
          enabled: canExport,
          onPressed: canExport ? onExport : null,
        ),
        AxiMenuAction(
          icon: LucideIcons.download,
          label: 'Import calendar',
          enabled: canImport,
          onPressed: canImport ? onImport : null,
        ),
      ],
    );
  }
}
