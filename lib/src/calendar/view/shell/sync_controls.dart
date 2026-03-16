// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/interop/calendar_share.dart';
import 'package:axichat/src/calendar/interop/calendar_transfer_service.dart';
import 'package:axichat/src/calendar/task/time_formatter.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_transfer_sheet.dart';
import 'package:axichat/src/calendar/view/shell/feedback_system.dart';
import 'package:uuid/uuid.dart';

const bool _defaultShowTransferMenu = true;
const bool _defaultTransferMenuGhost = false;

class SyncControls extends StatelessWidget {
  const SyncControls({
    super.key,
    required this.state,
    this.compact = false,
    this.showTransferMenu = _defaultShowTransferMenu,
    this.transferMenuGhost = _defaultTransferMenuGhost,
    this.transferMenuSelected = false,
  });

  final CalendarState state;
  final bool compact;
  final bool showTransferMenu;
  final bool transferMenuGhost;
  final bool transferMenuSelected;

  @override
  Widget build(BuildContext context) {
    final CalendarTransferMenu? transferMenu = showTransferMenu
        ? CalendarTransferMenu(
            state: state,
            ghost: transferMenuGhost,
            selected: transferMenuSelected,
          )
        : null;
    if (compact) {
      return _CompactSyncControls(state: state, transferMenu: transferMenu);
    }
    return _InlineSyncControls(state: state, transferMenu: transferMenu);
  }
}

class CalendarTransferMenu extends StatefulWidget {
  const CalendarTransferMenu({
    super.key,
    required this.state,
    this.additionalActions,
    this.ghost = _defaultTransferMenuGhost,
    this.selected = false,
  });

  final CalendarState state;
  final List<AxiMenuAction>? additionalActions;
  final bool ghost;
  final bool selected;

  @override
  State<CalendarTransferMenu> createState() => _CalendarTransferMenuState();
}

class _CalendarTransferMenuState extends State<CalendarTransferMenu> {
  final CalendarTransferService _transferService =
      const CalendarTransferService();
  bool _exporting = false;
  final Map<String, ({int? taskCount, bool isFullModel})> _pendingImports =
      <String, ({int? taskCount, bool isFullModel})>{};
  int _handledImportOutcomeToken = 0;

  CalendarState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    final bool disabled = state.isSyncing || state.isLoading || _exporting;
    final bool hasCalendarData = state.model.hasCalendarData;
    return BlocListener<CalendarBloc, CalendarState>(
      listener: _handleCalendarStateChanged,
      child: CalendarTransferMenuButton(
        hasCalendarData: hasCalendarData,
        onExport: _handleExportAll,
        onImport: _handleImportCalendar,
        additionalActions: widget.additionalActions,
        busy: disabled,
        ghost: widget.ghost,
        selected: widget.selected,
      ),
    );
  }

  void _handleCalendarStateChanged(BuildContext _, CalendarState state) {
    if (state.importOutcomeToken == _handledImportOutcomeToken) {
      return;
    }
    _handledImportOutcomeToken = state.importOutcomeToken;
    final String? requestId = state.importRequestId;
    if (requestId == null) {
      return;
    }
    final pendingImport = _pendingImports.remove(requestId);
    if (pendingImport == null) {
      return;
    }
    final int? taskCount = pendingImport.taskCount;
    final bool importedFullModel = pendingImport.isFullModel;
    if (state.importError != null) {
      FeedbackSystem.showError(
        context,
        context.l10n.calendarTransferImportFailed,
      );
      return;
    }
    if (importedFullModel) {
      FeedbackSystem.showSuccess(
        context,
        context.l10n.calendarTransferImportSuccess,
      );
      return;
    }
    if (taskCount != null) {
      FeedbackSystem.showSuccess(
        context,
        context.l10n.calendarTransferImportTasksSuccess(taskCount),
      );
    }
  }

  Future<void> _handleExportAll() async {
    await _exportAll();
  }

  Future<void> _handleImportCalendar() async {
    await _importCalendar();
  }

  Future<void> _exportAll() async {
    final l10n = context.l10n;
    final model = state.model;
    if (!model.hasCalendarData) {
      FeedbackSystem.showInfo(context, l10n.calendarTransferNoDataExport);
      return;
    }
    setState(() => _exporting = true);
    final format = await showCalendarExportFormatSheet(context);
    if (!mounted || format == null) {
      if (mounted) {
        setState(() => _exporting = false);
      }
      return;
    }
    try {
      final file = format == CalendarExportFormat.json
          ? await _transferService.exportModel(model: model)
          : await _transferService.exportIcs(model: model);
      final CalendarShareOutcome shareOutcome = await shareCalendarExport(
        file: file,
        subject: l10n.calendarTransferExportSubject,
        text: l10n.calendarTransferExportText(format.label),
      );
      if (!mounted) return;
      FeedbackSystem.showSuccess(
        context,
        calendarShareSuccessMessage(
          outcome: shareOutcome,
          filePath: file.path,
          sharedText: l10n.calendarTransferExportReady,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      FeedbackSystem.showError(
        context,
        l10n.calendarTransferExportFailed(error.toString()),
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _importCalendar() async {
    final l10n = context.l10n;
    final shouldImport = await confirm(
      context,
      title: l10n.calendarImportCalendar,
      message: l10n.calendarTransferImportWarning,
      confirmLabel: l10n.calendarTransferImportConfirm,
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
      FeedbackSystem.showError(context, l10n.calendarTransferFileAccessFailed);
      return;
    }
    final file = File(path);
    try {
      final result = await _transferService.importFromFile(file);
      if (result.isFullModel && result.model != null) {
        final importedModel = result.model!;
        if (!importedModel.hasCalendarData) {
          if (!mounted) return;
          FeedbackSystem.showInfo(context, l10n.calendarTransferNoDataImport);
          return;
        }
        if (!mounted) return;
        final String requestId = const Uuid().v4();
        _pendingImports[requestId] = (taskCount: null, isFullModel: true);
        context.read<CalendarBloc>().add(
          CalendarEvent.modelImported(
            requestId: requestId,
            model: importedModel,
          ),
        );
        return;
      }
      final tasks = result.tasks;
      if (tasks.isEmpty) {
        if (!mounted) return;
        FeedbackSystem.showInfo(context, l10n.calendarTransferNoTasksDetected);
        return;
      }
      if (!mounted) return;
      final String requestId = const Uuid().v4();
      _pendingImports[requestId] = (
        taskCount: tasks.length,
        isFullModel: false,
      );
      context.read<CalendarBloc>().add(
        CalendarEvent.tasksImported(requestId: requestId, tasks: tasks),
      );
    } catch (error) {
      if (!mounted) return;
      FeedbackSystem.showError(
        context,
        l10n.calendarTransferImportFailedWithError(error.toString()),
      );
    }
  }
}

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key, required this.state});

  final CalendarState state;

  @override
  Widget build(BuildContext context) {
    final (String label, Widget indicator) = _resolveVisual(context);
    return AxiTooltip(
      builder: (_) => Text(label),
      child: Semantics(label: label, child: indicator),
    );
  }

  (String, Widget) _resolveVisual(BuildContext context) {
    final l10n = context.l10n;
    final sizing = context.sizing;
    if (state.isSyncing) {
      return (l10n.calendarSyncStatusSyncing, const AxiProgressIndicator());
    }
    if (state.syncError != null) {
      return (
        l10n.calendarSyncStatusFailed,
        Icon(
          LucideIcons.cloudAlert,
          size: sizing.menuItemIconSize,
          color: calendarDangerColor,
        ),
      );
    }
    if (state.lastSyncTime != null) {
      return (
        l10n.calendarSyncStatusSynced,
        Icon(
          LucideIcons.cloudCheck,
          size: sizing.menuItemIconSize,
          color: calendarSuccessColor,
        ),
      );
    }
    final Color fallbackColor = context.colorScheme.mutedForeground;
    return (
      l10n.calendarSyncStatusIdle,
      Icon(
        LucideIcons.cloud,
        size: sizing.menuItemIconSize,
        color: fallbackColor,
      ),
    );
  }
}

class _InlineSyncControls extends StatelessWidget {
  const _InlineSyncControls({required this.state, this.transferMenu});

  final CalendarState state;
  final Widget? transferMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final TextStyle statusStyle = context.textTheme.small.strong;
    final TextStyle secondaryStyle = context.textTheme.small.copyWith(
      color: context.colorScheme.mutedForeground,
    );
    final statusText = _statusTextFor(state, l10n);
    final lastSyncTime = state.lastSyncTime;
    final statusColor = _statusColorFor(context, state);
    final List<Widget> children = [
      ?transferMenu,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(statusText, style: statusStyle.copyWith(color: statusColor)),
          if (lastSyncTime != null && !state.isSyncing) ...[
            SizedBox(width: spacing.xs),
            Text(
              TimeFormatter.formatSyncTime(l10n, lastSyncTime),
              style: secondaryStyle,
            ),
          ],
          SizedBox(width: spacing.xs),
          SyncStatusIndicator(state: state),
        ],
      ),
    ];

    return Wrap(
      spacing: context.spacing.s,
      runSpacing: context.spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

class _CompactSyncControls extends StatelessWidget {
  const _CompactSyncControls({required this.state, this.transferMenu});

  final CalendarState state;
  final Widget? transferMenu;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [
      ?transferMenu,
      SyncStatusIndicator(state: state),
    ];

    return Wrap(
      spacing: context.spacing.s,
      runSpacing: context.spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

String _statusTextFor(CalendarState state, AppLocalizations l10n) {
  if (state.isSyncing) return l10n.calendarSyncStatusSyncing;
  if (state.syncError != null) return l10n.calendarSyncStatusFailed;
  if (state.lastSyncTime != null) return l10n.calendarSyncStatusSynced;
  return l10n.calendarSyncStatusIdle;
}

Color _statusColorFor(BuildContext context, CalendarState state) {
  if (state.isSyncing) return calendarWarningColor;
  if (state.syncError != null) return calendarDangerColor;
  if (state.lastSyncTime != null) return calendarSuccessColor;
  return context.colorScheme.mutedForeground;
}

class CalendarTransferMenuButton extends StatelessWidget {
  const CalendarTransferMenuButton({
    super.key,
    required this.hasCalendarData,
    required this.onExport,
    required this.onImport,
    this.additionalActions,
    this.busy = false,
    this.ghost = _defaultTransferMenuGhost,
    this.selected = false,
  });

  final bool hasCalendarData;
  final VoidCallback onExport;
  final VoidCallback onImport;
  final List<AxiMenuAction>? additionalActions;
  final bool busy;
  final bool ghost;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bool canExport = hasCalendarData && !busy;
    final bool canImport = !busy;
    return AxiMore(
      actions: [
        AxiMenuAction(
          icon: LucideIcons.upload,
          label: l10n.calendarExportCalendar,
          enabled: canExport,
          onPressed: canExport ? onExport : null,
        ),
        AxiMenuAction(
          icon: LucideIcons.download,
          label: l10n.calendarImportCalendar,
          enabled: canImport,
          onPressed: canImport ? onImport : null,
        ),
        ...?additionalActions,
      ],
      ghost: ghost,
      selected: selected,
    );
  }
}
