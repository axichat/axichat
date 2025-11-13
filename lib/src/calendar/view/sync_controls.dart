import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../common/ui/ui.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_task.dart';
import '../utils/calendar_transfer_service.dart';
import '../utils/responsive_helper.dart';
import '../utils/time_formatter.dart';
import 'calendar_transfer_sheet.dart';
import 'feedback_system.dart';
import 'widgets/task_form_section.dart';

class SyncControls extends StatefulWidget {
  const SyncControls({
    super.key,
    required this.state,
    this.compact = false,
  });

  final CalendarState state;
  final bool compact;

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
      child: ResponsiveHelper.layoutBuilder(
        context,
        mobile: _buildMobileControls(context, state),
        tablet: _buildTabletControls(context, state),
        desktop: _buildDesktopControls(context, state),
      ),
    );
  }

  Widget _buildMobileControls(BuildContext context, CalendarState state) {
    final disabled = state.isSyncing;
    final hasTasks = state.model.tasks.isNotEmpty;
    return Wrap(
      spacing: calendarGutterSm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildSyncStatusIcon(context, state),
        _CompactSyncButton(
          label: 'Request',
          icon: LucideIcons.cloudDownload,
          onPressed: disabled ? null : () => _requestSync(context),
        ),
        _CompactSyncButton(
          label: 'Push',
          icon: LucideIcons.cloudUpload,
          onPressed: disabled ? null : () => _pushSync(context),
        ),
        _buildTransferMenuButton(hasTasks),
      ],
    );
  }

  Widget _buildTabletControls(BuildContext context, CalendarState state) {
    final spec = ResponsiveHelper.spec(context);
    final hasTasks = state.model.tasks.isNotEmpty;
    return Container(
      padding: spec.contentPadding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSyncStatus(context, state),
          const SizedBox(height: calendarGutterMd),
          Row(
            children: [
              Expanded(
                child: TaskSecondaryButton(
                  label: 'Request',
                  icon: LucideIcons.cloudDownload,
                  onPressed:
                      state.isSyncing ? null : () => _requestSync(context),
                ),
              ),
              const SizedBox(width: calendarGutterSm),
              Expanded(
                child: TaskSecondaryButton(
                  label: 'Push',
                  icon: LucideIcons.cloudUpload,
                  onPressed: state.isSyncing ? null : () => _pushSync(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: calendarGutterSm),
          Align(
            alignment: Alignment.centerRight,
            child: _buildTransferMenuButton(hasTasks),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopControls(BuildContext context, CalendarState state) {
    final spec = ResponsiveHelper.spec(context);
    final hasTasks = state.model.tasks.isNotEmpty;
    return Container(
      padding: spec.contentPadding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sync & Transfer',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: calendarGutterMd),
          _buildSyncStatus(context, state),
          const SizedBox(height: calendarGutterLg),
          TaskPrimaryButton(
            label: 'Request Update',
            icon: LucideIcons.cloudDownload,
            onPressed: state.isSyncing ? null : () => _requestSync(context),
            isBusy: state.isSyncing,
          ),
          const SizedBox(height: calendarGutterSm),
          TaskSecondaryButton(
            label: 'Push Update',
            icon: LucideIcons.cloudUpload,
            onPressed: state.isSyncing ? null : () => _pushSync(context),
          ),
          const SizedBox(height: calendarGutterSm),
          Align(
            alignment: Alignment.centerRight,
            child: _buildTransferMenuButton(hasTasks),
          ),
          if (state.syncError != null) ...[
            const SizedBox(height: calendarGutterMd),
            _buildErrorDisplay(context, state),
            const SizedBox(height: calendarGutterSm),
            TaskSecondaryButton(
              label: 'Retry',
              icon: LucideIcons.refreshCcw,
              onPressed: () => _retrySync(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncStatusIcon(BuildContext context, CalendarState state) {
    return SyncStatusIndicator(state: state);
  }

  Widget _buildSyncStatus(BuildContext context, CalendarState state) {
    return Row(
      children: [
        _buildSyncStatusIcon(context, state),
        const SizedBox(width: calendarGutterSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getSyncStatusText(state),
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: _getSyncStatusColor(context, state),
                ),
              ),
              if (state.lastSyncTime != null && !state.isSyncing)
                Text(
                  'Last synced: ${_formatSyncTime(state.lastSyncTime!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorDisplay(BuildContext context, CalendarState state) {
    return Container(
      padding: calendarPaddingMd,
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: calendarGutterSm),
          Expanded(
            child: Text(
              state.syncError ?? 'Unknown error',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferMenuButton(bool hasTasks) {
    return AxiMore(
      options: [
        (toggle) => _TransferMenuItem(
              icon: LucideIcons.upload,
              label: 'Export calendar',
              enabled: hasTasks,
              onTap: () {
                toggle();
                if (hasTasks) _exportAll();
              },
            ),
        (toggle) => _TransferMenuItem(
              icon: LucideIcons.download,
              label: 'Import calendar',
              onTap: () {
                toggle();
                _importCalendar();
              },
            ),
      ],
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
    final bloc = context.read<CalendarBloc>();
    if (state.syncError?.contains('request') == true) {
      bloc.add(const CalendarEvent.syncRequested());
    } else {
      bloc.add(const CalendarEvent.syncPushed());
    }
    _awaitingManualSync = true;
  }

  Future<void> _exportAll() async {
    final tasks = context.read<CalendarBloc>().state.model.tasks.values;
    await _exportTasks(tasks);
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

  String _getSyncStatusText(CalendarState state) {
    if (state.isSyncing) return 'Syncing...';
    if (state.syncError != null) return 'Sync failed';
    if (state.lastSyncTime != null) return 'Synced';
    return 'Idle';
  }

  Color _getSyncStatusColor(BuildContext context, CalendarState state) {
    if (state.isSyncing) return Colors.orange;
    if (state.syncError != null) return Colors.red;
    if (state.lastSyncTime != null) return Colors.green;
    return Theme.of(context).textTheme.bodyMedium?.color ??
        Theme.of(context).colorScheme.onSurface;
  }

  String _formatSyncTime(DateTime time) => TimeFormatter.formatSyncTime(time);
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
    return Tooltip(
      message: label,
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

class _TransferMenuItem extends StatelessWidget {
  const _TransferMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ShadButton.ghost(
      onPressed: enabled ? onTap : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: enabled
                ? colors.onSurface
                : colors.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: enabled
                  ? colors.onSurface
                  : colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
