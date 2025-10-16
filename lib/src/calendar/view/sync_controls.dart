import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../common/ui/ui.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../utils/responsive_helper.dart';
import '../utils/time_formatter.dart';
import 'feedback_system.dart';
import 'widgets/task_form_section.dart';

class SyncControls extends StatelessWidget {
  final CalendarState state;
  final bool compact;

  const SyncControls({
    super.key,
    required this.state,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<CalendarBloc, CalendarState>(
      listenWhen: (previous, current) =>
          previous.isSyncing != current.isSyncing ||
          previous.syncError != current.syncError,
      listener: (context, state) {
        if (!state.isSyncing &&
            state.syncError == null &&
            state.lastSyncTime != null) {
          // Sync completed successfully
          _showSyncSnackbar(context, 'Calendar synced successfully');
        } else if (!state.isSyncing && state.syncError != null) {
          // Sync failed
          _showSyncSnackbar(context, 'Sync failed: ${state.syncError}');
        }
      },
      child: ResponsiveHelper.layoutBuilder(
        context,
        mobile: _buildMobileControls(context),
        tablet: _buildTabletControls(context),
        desktop: _buildDesktopControls(context),
      ),
    );
  }

  Widget _buildMobileControls(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSyncStatusIcon(context),
        IconButton(
          onPressed: state.isSyncing ? null : () => _requestSync(context),
          icon: const Icon(Icons.cloud_download),
          tooltip: 'Request Update',
        ),
        IconButton(
          onPressed: state.isSyncing ? null : () => _pushSync(context),
          icon: const Icon(Icons.cloud_upload),
          tooltip: 'Push Update',
        ),
      ],
    );
  }

  Widget _buildTabletControls(BuildContext context) {
    final spec = ResponsiveHelper.spec(context);
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
          _buildSyncStatus(context),
          const SizedBox(height: calendarGutterMd),
          Row(
            children: [
              Expanded(
                child: TaskSecondaryButton(
                  label: 'Request',
                  icon: Icons.cloud_download,
                  onPressed:
                      state.isSyncing ? null : () => _requestSync(context),
                ),
              ),
              const SizedBox(width: calendarGutterSm),
              Expanded(
                child: TaskSecondaryButton(
                  label: 'Push',
                  icon: Icons.cloud_upload,
                  onPressed: state.isSyncing ? null : () => _pushSync(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopControls(BuildContext context) {
    final spec = ResponsiveHelper.spec(context);
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
            'Sync Status',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: calendarGutterMd),
          _buildSyncStatus(context),
          const SizedBox(height: calendarGutterLg),
          TaskPrimaryButton(
            label: 'Request Update',
            icon: Icons.cloud_download,
            onPressed: state.isSyncing ? null : () => _requestSync(context),
            isBusy: state.isSyncing,
          ),
          const SizedBox(height: calendarGutterSm),
          TaskSecondaryButton(
            label: 'Push Update',
            icon: Icons.cloud_upload,
            onPressed: state.isSyncing ? null : () => _pushSync(context),
          ),
          if (state.syncError != null) ...[
            const SizedBox(height: calendarGutterMd),
            _buildErrorDisplay(context),
            const SizedBox(height: calendarGutterSm),
            TaskSecondaryButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () => _retrySync(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncStatusIcon(BuildContext context) {
    if (state.isSyncing) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (state.syncError != null) {
      return const Icon(
        Icons.sync_problem,
        color: Colors.red,
        size: 20,
      );
    }

    if (state.lastSyncTime != null) {
      return const Icon(
        Icons.cloud_done,
        color: Colors.green,
        size: 20,
      );
    }

    return Icon(
      Icons.cloud_off,
      color: Theme.of(context).textTheme.bodySmall?.color,
      size: 20,
    );
  }

  Widget _buildSyncStatus(BuildContext context) {
    return Row(
      children: [
        _buildSyncStatusIcon(context),
        const SizedBox(width: calendarGutterSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getSyncStatusText(),
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: _getSyncStatusColor(context),
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

  Widget _buildErrorDisplay(BuildContext context) {
    return Container(
      padding: calendarPaddingMd,
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 16),
          const SizedBox(width: calendarGutterSm),
          Expanded(
            child: Text(
              state.syncError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _getSyncStatusText() {
    if (state.isSyncing) return 'Syncing...';
    if (state.syncError != null) return 'Sync failed';
    if (state.lastSyncTime != null) return 'Synced';
    return 'Not synced';
  }

  Color _getSyncStatusColor(BuildContext context) {
    if (state.isSyncing) return Theme.of(context).primaryColor;
    if (state.syncError != null) return Colors.red;
    if (state.lastSyncTime != null) return Colors.green;
    return Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
  }

  String _formatSyncTime(DateTime time) {
    return TimeFormatter.formatSyncTime(time);
  }

  void _requestSync(BuildContext context) {
    context.read<CalendarBloc>().add(const CalendarEvent.syncRequested());
    FeedbackSystem.showInfo(context, 'Requesting calendar update...');
  }

  void _pushSync(BuildContext context) {
    context.read<CalendarBloc>().add(const CalendarEvent.syncPushed());
    FeedbackSystem.showInfo(context, 'Pushing calendar update...');
  }

  void _retrySync(BuildContext context) {
    // Try the last sync operation again
    context.read<CalendarBloc>().add(const CalendarEvent.syncRequested());
    FeedbackSystem.showInfo(context, 'Retrying sync...');
  }

  void _showSyncSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// Helper widget for displaying sync status in compact form
class SyncStatusIndicator extends StatelessWidget {
  final CalendarState state;

  const SyncStatusIndicator({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isSyncing) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    IconData icon;
    Color? color;

    if (state.syncError != null) {
      icon = Icons.sync_problem;
      color = Colors.red;
    } else if (state.lastSyncTime != null) {
      icon = Icons.cloud_done;
      color = Colors.green;
    } else {
      icon = Icons.cloud_off;
      color = Colors.grey;
    }

    return Icon(icon, size: 16, color: color);
  }
}
