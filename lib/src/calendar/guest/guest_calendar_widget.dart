// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_sync_warning.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/calendar_state_waiter.dart';
import 'package:axichat/src/calendar/utils/calendar_share.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'package:axichat/src/calendar/view/calendar_experience_state.dart';
import 'package:axichat/src/calendar/view/calendar_widget.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/calendar/view/calendar_transfer_sheet.dart';
import 'package:axichat/src/calendar/view/sync_controls.dart';
import 'package:axichat/src/calendar/view/calendar_task_search.dart';
import 'package:axichat/src/calendar/view/task_sidebar.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_loading_overlay.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_mobile_tab_shell.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_hover_title_scope.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_task_feedback_observer.dart';
import 'package:axichat/src/calendar/view/widgets/task_form_section.dart';
import 'package:axichat/src/calendar/utils/calendar_transfer_service.dart';
import 'guest_calendar_bloc.dart';

class GuestCalendarWidget extends StatefulWidget {
  const GuestCalendarWidget({super.key});

  @override
  State<GuestCalendarWidget> createState() => _GuestCalendarWidgetState();
}

class _GuestCalendarWidgetState
    extends CalendarExperienceState<GuestCalendarWidget, GuestCalendarBloc> {
  late final CalendarHoverTitleController _hoverTitleController =
      CalendarHoverTitleController();

  @override
  void dispose() {
    _hoverTitleController.dispose();
    super.dispose();
  }

  @override
  String get dragLogTag => 'guest-calendar';

  @override
  EdgeInsets? navigationPadding(
    CalendarResponsiveSpec spec,
    bool usesDesktopLayout,
  ) =>
      null;

  @override
  EdgeInsets? errorBannerMargin(
    CalendarResponsiveSpec spec,
    bool usesDesktopLayout,
  ) =>
      spec.modalMargin;

  @override
  Widget buildTasksTabLabel(
    BuildContext context,
    bool highlight,
    Animation<double> animation,
  ) {
    return TasksTabLabel(
      highlight: highlight,
      animation: animation,
      baseColor: calendarPrimaryColor,
    );
  }

  @override
  CalendarMobileTabShell buildMobileTabShell(
    BuildContext context,
    Widget tabSwitcher,
    Widget cancelBucket,
  ) {
    final colors = context.colorScheme;
    return CalendarMobileTabShell(
      tabBar: tabSwitcher,
      cancelBucket: cancelBucket,
      backgroundColor: colors.background,
      borderColor: context.borderSide.color,
    );
  }

  @override
  Widget? buildDesktopTopHeader(Widget navigation, Widget? errorBanner) {
    return CalendarNavSurface(child: navigation);
  }

  @override
  Widget? buildDesktopBodyHeader(Widget navigation, Widget? errorBanner) {
    return errorBanner;
  }

  @override
  Widget buildMobileHeader(
    BuildContext context,
    bool showingPrimary,
    Widget navigation,
    Widget? errorBanner,
  ) {
    final children = <Widget>[];
    if (showingPrimary) {
      final Widget navContent = CalendarNavSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [navigation, if (errorBanner != null) errorBanner],
        ),
      );
      children.add(navContent);
    } else if (errorBanner != null) {
      children.add(errorBanner);
    }
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  @override
  Widget buildScaffoldBody(
    BuildContext context,
    CalendarState state,
    bool usesDesktopLayout,
    Widget layout,
  ) {
    return CalendarHoverTitleScope(
      controller: _hoverTitleController,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            _GuestBanner(
              onNavigateBack: _handleBannerBackNavigation,
              onSignUp: () => context.go('/login'),
              transferMenu: _GuestTransferMenu(state: state),
            ),
            Expanded(child: layout),
          ],
        ),
      ),
    );
  }

  @override
  Widget wrapWithTaskFeedback(BuildContext context, Widget child) {
    return CalendarTaskFeedbackObserver<GuestCalendarBloc>(child: child);
  }

  @override
  VoidCallback? buildNavigationSearchAction(
    BuildContext context,
    CalendarState state,
    bool usesDesktopLayout,
  ) {
    final locate = context.read;
    return () => _openTaskSearch(calendarBloc, locate: locate);
  }

  Future<void> _openTaskSearch(
    GuestCalendarBloc bloc, {
    T Function<T>()? locate,
  }) async {
    final TaskSidebarState<GuestCalendarBloc>? sidebarState =
        sidebarKey.currentState;
    await showCalendarTaskSearch(
      context: context,
      bloc: bloc,
      locate: locate,
      requiresLongPressForDrag: sidebarState?.requiresLongPressForDrag ?? false,
      taskTileBuilder: sidebarState == null
          ? null
          : (
              CalendarTask task, {
              Widget? trailing,
              bool requiresLongPress = false,
              VoidCallback? onTap,
              VoidCallback? onDragStart,
              bool allowContextMenu = false,
            }) =>
              sidebarState.buildSearchTaskTile(
                task,
                trailing: trailing,
                requiresLongPress: requiresLongPress,
                onTap: onTap,
                onDragStart: onDragStart,
                allowContextMenu: allowContextMenu,
              ),
    );
  }

  @override
  Widget buildLoadingOverlay(BuildContext context) {
    const double guestLoadingScrimAlpha = 0.3;
    return CalendarLoadingOverlay(
      color: context.colorScheme.foreground.withValues(
        alpha: guestLoadingScrimAlpha,
      ),
    );
  }

  @override
  Color resolveSurfaceColor(BuildContext context) =>
      _calendarSurfaceColor(context);

  @override
  bool shouldUseDesktopLayout(
    CalendarSizeClass sizeClass,
    MediaQueryData mediaQuery,
  ) {
    return sizeClass == CalendarSizeClass.expanded;
  }

  @override
  void handleStateChanges(BuildContext context, CalendarState state) {
    if (state.error != null && mounted) {
      FeedbackSystem.showError(context, state.error!);
    }
    final warning = state.syncWarning;
    if (warning != null && mounted) {
      final l10n = context.l10n;
      final (String title, String message) = switch (warning.type) {
        CalendarSyncWarningType.snapshotUnavailable => (
            l10n.calendarSyncWarningSnapshotTitle,
            l10n.calendarSyncWarningSnapshotMessage,
          ),
      };
      FeedbackSystem.showWarning(
        context,
        message,
        title: title,
      );
      calendarBloc.add(const CalendarEvent.syncWarningCleared());
    }
  }

  Future<void> _handleBannerBackNavigation() async {
    final navigator = GoRouter.of(
      context,
    ).routerDelegate.navigatorKey.currentState;
    if (navigator != null && await navigator.maybePop()) {
      return;
    }
    if (!mounted) {
      return;
    }
    context.go('/login');
  }

  Color _calendarSurfaceColor(BuildContext context) {
    return context.brightness == Brightness.dark
        ? context.colorScheme.card
        : calendarSidebarBackgroundColor;
  }
}

class _GuestBanner extends StatelessWidget {
  const _GuestBanner({
    required this.onNavigateBack,
    required this.onSignUp,
    required this.transferMenu,
  });

  final Future<void> Function() onNavigateBack;
  final VoidCallback onSignUp;
  final Widget transferMenu;

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper.spec(context);
    final EdgeInsets basePadding = responsive.contentPadding;
    final EdgeInsets bannerPadding = EdgeInsets.fromLTRB(
      basePadding.left,
      calendarGutterMd,
      basePadding.right,
      calendarGutterMd,
    );
    final accent = calendarPrimaryColor;
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      padding: bannerPadding,
      child: Row(
        children: [
          AxiIconButton(
            iconData: Icons.arrow_back,
            tooltip: context.l10n.calendarBackToLogin,
            onPressed: () {
              onNavigateBack();
            },
          ),
          const SizedBox(width: calendarGutterMd),
          Icon(Icons.info_outline_rounded, size: 18, color: accent),
          const SizedBox(width: calendarGutterMd),
          Expanded(
            child: Text(
              context.l10n.calendarGuestModeNotice,
              style: calendarBodyTextStyle.copyWith(
                color: calendarSubtitleColor,
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 2,
            ),
          ),
          const SizedBox(width: calendarGutterMd),
          transferMenu,
          const SizedBox(width: calendarGutterMd),
          TaskPrimaryButton(
            label: context.l10n.calendarGuestSignUpToSync,
            onPressed: onSignUp,
            icon: Icons.login,
          ),
        ],
      ),
    );
  }
}

class _GuestTransferMenu extends StatefulWidget {
  const _GuestTransferMenu({required this.state});

  final CalendarState state;

  @override
  State<_GuestTransferMenu> createState() => _GuestTransferMenuState();
}

const String _guestCalendarExportFilePrefix = 'axichat_guest_calendar';

class _GuestTransferMenuState extends State<_GuestTransferMenu> {
  final CalendarTransferService _transferService =
      const CalendarTransferService();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final bool hasCalendarData = widget.state.model.hasCalendarData;
    return CalendarTransferMenuButton(
      hasCalendarData: hasCalendarData,
      onExport: _handleExportAll,
      onImport: _handleImportCalendar,
      busy: _busy,
    );
  }

  Future<void> _handleExportAll() async {
    if (_busy) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final model = widget.state.model;
      if (!model.hasCalendarData) {
        FeedbackSystem.showInfo(
          context,
          l10n.calendarGuestExportNoData,
        );
        return;
      }
      final format = await showCalendarExportFormatSheet(
        context,
        title: l10n.calendarGuestExportTitle,
      );
      if (!mounted || format == null) return;
      final File file = format == CalendarExportFormat.json
          ? await _transferService.exportModel(
              model: model,
              fileNamePrefix: _guestCalendarExportFilePrefix,
            )
          : await _transferService.exportIcs(
              model: model,
              fileNamePrefix: _guestCalendarExportFilePrefix,
            );
      final CalendarShareOutcome shareOutcome = await shareCalendarExport(
        file: file,
        subject: l10n.calendarGuestExportShareSubject,
        text: l10n.calendarGuestExportShareText(format.label),
      );
      if (!mounted) return;
      FeedbackSystem.showSuccess(
        context,
        calendarShareSuccessMessage(
          outcome: shareOutcome,
          filePath: file.path,
          sharedText: l10n.calendarExportReady,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      FeedbackSystem.showError(
        context,
        l10n.calendarGuestExportFailed(error.toString()),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleImportCalendar() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final shouldImport = await confirm(
        context,
        title: context.l10n.calendarGuestImportTitle,
        message: context.l10n.calendarGuestImportWarningMessage,
        confirmLabel: context.l10n.calendarGuestImportConfirmLabel,
      );
      if (shouldImport != true) {
        return;
      }
      final pickerResult = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const ['ics', 'json'],
      );
      if (pickerResult == null || pickerResult.files.isEmpty) {
        return;
      }
      final path = pickerResult.files.single.path;
      if (path == null) {
        if (!mounted) return;
        FeedbackSystem.showError(
          context,
          context.l10n.calendarGuestImportFileAccessError,
        );
        return;
      }
      final file = File(path);
      final importResult = await _transferService.importFromFile(file);
      if (importResult.isFullModel && importResult.model != null) {
        final importedModel = importResult.model!;
        if (!importedModel.hasCalendarData) {
          if (!mounted) return;
          FeedbackSystem.showInfo(
            context,
            context.l10n.calendarGuestImportNoData,
          );
          return;
        }
        if (!mounted) return;
        final GuestCalendarBloc calendarBloc =
            context.read<GuestCalendarBloc>();
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
          FeedbackSystem.showError(
            context,
            context.l10n.calendarGuestImportFailed,
          );
          return;
        }
        FeedbackSystem.showSuccess(
          context,
          context.l10n.calendarGuestImportSuccess,
        );
        return;
      }
      final tasks = importResult.tasks;
      if (tasks.isEmpty) {
        if (!mounted) return;
        FeedbackSystem.showInfo(
          context,
          context.l10n.calendarGuestImportNoTasks,
        );
        return;
      }
      if (!mounted) return;
      final GuestCalendarBloc calendarBloc = context.read<GuestCalendarBloc>();
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
        FeedbackSystem.showError(
          context,
          context.l10n.calendarGuestImportFailed,
        );
        return;
      }
      FeedbackSystem.showSuccess(
        context,
        context.l10n.calendarGuestImportTasksSuccess(tasks.length),
      );
    } catch (error) {
      if (!mounted) return;
      FeedbackSystem.showError(
        context,
        context.l10n.calendarGuestImportError(error.toString()),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
