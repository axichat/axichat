import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
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

class _SyncControlsState extends State<SyncControls> {
  final CalendarTransferService _transferService =
      const CalendarTransferService();
  bool _awaitingManualSync = false;

  CalendarState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    return BlocListener<CalendarBloc, CalendarState>(
      listenWhen: (previous, current) =>
          previous.isSyncing != current.isSyncing ||
          previous.syncError != current.syncError ||
          previous.lastSyncTime != current.lastSyncTime,
      listener: _handleSyncState,
      child: _InlineSyncControls(
        state: state,
        onRequestSync: () => _requestSync(context),
        onPushSync: () => _pushSync(context),
        onExportCalendar: _handleExportAll,
        onImportCalendar: _handleImportCalendar,
        onRetrySync: () => _retrySync(context),
      ),
    );
  }

  void _handleSyncState(BuildContext context, CalendarState nextState) {
    if (nextState.isSyncing) return;
    if (nextState.syncError != null) {
      _awaitingManualSync = false;
      FeedbackSystem.showError(
        context,
        'Sync failed: ${nextState.syncError}',
      );
      return;
    }
    if (_awaitingManualSync && nextState.lastSyncTime != null) {
      _awaitingManualSync = false;
      FeedbackSystem.showSuccess(context, 'Calendar synced successfully');
    }
  }

  void _requestSync(BuildContext context) {
    context.read<CalendarBloc>().add(const CalendarEvent.syncRequested());
    _awaitingManualSync = true;
  }

  void _pushSync(BuildContext context) {
    context.read<CalendarBloc>().add(const CalendarEvent.syncPushed());
    _awaitingManualSync = true;
  }

  void _retrySync(BuildContext context) {
    if (state.syncError?.contains('request') == true) {
      context.read<CalendarBloc>().add(const CalendarEvent.syncRequested());
    } else {
      context.read<CalendarBloc>().add(const CalendarEvent.syncPushed());
    }
    _awaitingManualSync = true;
  }

  void _handleExportAll() {
    unawaited(_exportAll());
  }

  void _handleImportCalendar() {
    unawaited(_importCalendar());
  }

  Future<void> _exportAll() async {
    await _exportTasks(
      context.read<CalendarBloc>().state.model.tasks.values,
    );
  }

  Future<void> _exportTasks(Iterable<CalendarTask> tasks) async {
    if (tasks.isEmpty) {
      FeedbackSystem.showInfo(context, 'No tasks available to export.');
      return;
    }
    final format = await showCalendarExportFormatSheet(context);
    if (!mounted || format == null) return;
    try {
      final file = await _transferService.exportTasks(
        tasks: tasks,
        format: format,
      );
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Axichat calendar export',
        text: 'Axichat calendar export (${format.label})',
      );
      if (!mounted) return;
      FeedbackSystem.showSuccess(context, 'Export ready to share.');
    } catch (error) {
      if (!mounted) return;
      FeedbackSystem.showError(
        context,
        'Failed to export calendar: $error',
      );
    }
  }

  Future<void> _importCalendar() async {
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
      final tasks = await _transferService.importFromFile(file);
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
    required this.onRequestSync,
    required this.onPushSync,
    required this.onExportCalendar,
    required this.onImportCalendar,
    required this.onRetrySync,
  });

  final CalendarState state;
  final VoidCallback onRequestSync;
  final VoidCallback onPushSync;
  final VoidCallback onExportCalendar;
  final VoidCallback onImportCalendar;
  final VoidCallback onRetrySync;

  @override
  Widget build(BuildContext context) {
    final disabled = state.isSyncing;
    final hasTasks = state.model.tasks.isNotEmpty;
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
        _CompactSyncButton(
          label: 'Request',
          icon: LucideIcons.cloudDownload,
          onPressed: disabled ? null : onRequestSync,
        ),
        _CompactSyncButton(
          label: 'Push',
          icon: LucideIcons.cloudUpload,
          onPressed: disabled ? null : onPushSync,
        ),
        _TransferMenuButton(
          hasTasks: hasTasks,
          onExport: onExportCalendar,
          onImport: onImportCalendar,
        ),
        if (state.syncError != null)
          _CompactSyncButton(
            label: 'Retry',
            icon: LucideIcons.refreshCcw,
            onPressed: onRetrySync,
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

class _TransferMenuButton extends StatelessWidget {
  const _TransferMenuButton({
    required this.hasTasks,
    required this.onExport,
    required this.onImport,
  });

  final bool hasTasks;
  final VoidCallback onExport;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return AxiMore(
      actions: [
        AxiMenuAction(
          icon: LucideIcons.upload,
          label: 'Export calendar',
          enabled: hasTasks,
          onPressed: hasTasks ? onExport : null,
        ),
        AxiMenuAction(
          icon: LucideIcons.download,
          label: 'Import calendar',
          onPressed: onImport,
        ),
      ],
    );
  }
}

class _CompactSyncButton extends StatelessWidget {
  const _CompactSyncButton({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final button = ShadButton.outline(
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
    return button.withTapBounce(enabled: onPressed != null);
  }
}
