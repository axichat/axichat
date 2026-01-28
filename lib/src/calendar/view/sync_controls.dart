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
import 'package:axichat/src/calendar/utils/calendar_state_waiter.dart';
import 'package:axichat/src/calendar/utils/calendar_share.dart';
import 'package:axichat/src/calendar/utils/calendar_transfer_service.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'calendar_transfer_sheet.dart';
import 'feedback_system.dart';

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

  CalendarState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    final bool disabled = state.isSyncing;
    final bool hasCalendarData = state.model.hasCalendarData;
    return CalendarTransferMenuButton(
      hasCalendarData: hasCalendarData,
      onExport: _handleExportAll,
      onImport: _handleImportCalendar,
      additionalActions: widget.additionalActions,
      busy: disabled,
      ghost: widget.ghost,
      selected: widget.selected,
    );
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
    final format = await showCalendarExportFormatSheet(context);
    if (!mounted || format == null) return;
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
        final CalendarBloc calendarBloc = context.read<CalendarBloc>();
        final CalendarModel mergedModel =
            calendarBloc.state.model.mergeWith(importedModel);
        calendarBloc.add(CalendarEvent.modelImported(model: importedModel));
        final bool imported = await waitForCalendarChecksum(
          bloc: calendarBloc,
          checksum: mergedModel.checksum,
        );
        if (!mounted) {
          return;
        }
        if (!imported) {
          FeedbackSystem.showError(context, l10n.calendarTransferImportFailed);
          return;
        }
        FeedbackSystem.showSuccess(context, l10n.calendarTransferImportSuccess);
        return;
      }
      final tasks = result.tasks;
      if (tasks.isEmpty) {
        if (!mounted) return;
        FeedbackSystem.showInfo(context, l10n.calendarTransferNoTasksDetected);
        return;
      }
      if (!mounted) return;
      final CalendarBloc calendarBloc = context.read<CalendarBloc>();
      final Set<String> taskIds = <String>{}
        ..addAll(tasks.map((task) => task.id));
      calendarBloc.add(CalendarEvent.tasksImported(tasks: tasks));
      final bool imported = await waitForTasksInCalendar(
        bloc: calendarBloc,
        taskIds: taskIds,
      );
      if (!mounted) {
        return;
      }
      if (!imported) {
        FeedbackSystem.showError(context, l10n.calendarTransferImportFailed);
        return;
      }
      FeedbackSystem.showSuccess(
        context,
        l10n.calendarTransferImportTasksSuccess(tasks.length),
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
      return (
        l10n.calendarSyncStatusSyncing,
        const AxiProgressIndicator(),
      );
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
      Icon(LucideIcons.cloud,
          size: sizing.menuItemIconSize, color: fallbackColor),
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
    final TextStyle statusStyle = context.textTheme.small.copyWith(
      fontWeight: FontWeight.w600,
    );
    final TextStyle secondaryStyle = context.textTheme.small.copyWith(
      color: context.colorScheme.mutedForeground,
    );
    final statusText = _statusTextFor(state, l10n);
    final lastSyncTime = state.lastSyncTime;
    final statusColor = _statusColorFor(context, state);
    final List<Widget> children = [
      if (transferMenu != null) transferMenu!,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            statusText,
            style: statusStyle.copyWith(color: statusColor),
          ),
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
      spacing: calendarGutterSm,
      runSpacing: calendarInsetMd,
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
      if (transferMenu != null) transferMenu!,
      SyncStatusIndicator(state: state),
    ];

    return Wrap(
      spacing: calendarGutterSm,
      runSpacing: calendarInsetMd,
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
