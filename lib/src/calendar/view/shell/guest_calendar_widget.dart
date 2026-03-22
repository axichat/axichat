// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
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
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/interop/calendar_share.dart';
import 'package:axichat/src/calendar/view/shell/responsive_helper.dart';
import 'package:axichat/src/calendar/view/shell/calendar_experience_state.dart';
import 'package:axichat/src/calendar/view/shell/calendar_widget.dart';
import 'package:axichat/src/calendar/view/shell/feedback_system.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_transfer_sheet.dart';
import 'package:axichat/src/calendar/view/shell/sync_controls.dart';
import 'package:axichat/src/calendar/view/shell/calendar_task_search.dart';
import 'package:axichat/src/calendar/view/sidebar/task_sidebar.dart';
import 'package:axichat/src/calendar/view/shell/calendar_loading_overlay.dart';
import 'package:axichat/src/calendar/view/shell/calendar_mobile_tab_shell.dart';
import 'package:axichat/src/calendar/view/grid/calendar_hover_title_scope.dart';
import 'package:axichat/src/calendar/view/shell/calendar_task_feedback_observer.dart';
import 'package:axichat/src/calendar/interop/calendar_transfer_service.dart';
import 'package:axichat/src/calendar/bloc/guest/guest_calendar_bloc.dart';

class GuestCalendarWidget extends StatefulWidget {
  const GuestCalendarWidget({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<GuestCalendarWidget> createState() => _GuestCalendarWidgetState();
}

class _GuestCalendarWidgetState
    extends CalendarExperienceState<GuestCalendarWidget, GuestCalendarBloc> {
  late final CalendarHoverTitleController _hoverTitleController =
      CalendarHoverTitleController();
  late final GlobalKey _calendarModalAnchorKey = GlobalKey(
    debugLabel: 'guest-calendar-modal-anchor',
  );
  late final GlobalKey<NavigatorState> _calendarNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  BuildContext get calendarModalContext {
    return _calendarModalAnchorKey.currentContext ??
        _calendarNavigatorKey.currentState?.overlay?.context ??
        _calendarNavigatorKey.currentContext ??
        context;
  }

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
  ) => null;

  @override
  EdgeInsets? errorBannerMargin(
    CalendarResponsiveSpec spec,
    bool usesDesktopLayout,
  ) => spec.modalMargin;

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
          children: [navigation, ?errorBanner],
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
    return CalendarSurfaceNavigator(
      navigatorKey: _calendarNavigatorKey,
      modalAnchorKey: _calendarModalAnchorKey,
      child: CalendarHoverTitleScope(
        controller: _hoverTitleController,
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              _GuestBanner(
                onNavigateBack: _handleBannerBackNavigation,
                showBackButton: widget.showBackButton,
                transferMenu: _GuestTransferMenu(state: state),
              ),
              Expanded(child: layout),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget wrapWithTaskFeedback(BuildContext context, Widget child) {
    return Builder(
      builder: (context) {
        final locate = context.read;
        final initialTasks = context
            .select<GuestCalendarBloc, Map<String, CalendarTask>>(
              (bloc) => bloc.state.model.tasks,
            );
        return CalendarTaskFeedbackObserver<GuestCalendarBloc>(
          initialTasks: initialTasks,
          onEvent: (event) => locate<GuestCalendarBloc>().add(event),
          child: child,
        );
      },
    );
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
            }) => sidebarState.buildSearchTaskTile(
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
      FeedbackSystem.showWarning(context, message, title: title);
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
    required this.showBackButton,
    required this.transferMenu,
  });

  final Future<void> Function() onNavigateBack;
  final bool showBackButton;
  final Widget transferMenu;

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper.spec(context);
    final EdgeInsets basePadding = responsive.contentPadding;
    final spacing = context.spacing;
    final EdgeInsets bannerPadding = EdgeInsets.fromLTRB(
      basePadding.left,
      spacing.s,
      basePadding.right,
      spacing.s,
    );
    final accent = calendarPrimaryColor;
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(
            color: calendarBorderColor,
            width: context.borderSide.width,
          ),
        ),
      ),
      padding: bannerPadding,
      child: Row(
        children: [
          if (showBackButton) ...[
            AxiIconButton(
              iconData: Icons.arrow_back,
              tooltip: context.l10n.calendarBackToLogin,
              onPressed: () {
                onNavigateBack();
              },
            ),
            SizedBox(width: spacing.s),
          ],
          Icon(
            Icons.info_outline_rounded,
            size: context.sizing.menuItemIconSize,
            color: accent,
          ),
          SizedBox(width: spacing.s),
          Expanded(
            child: Text(
              context.l10n.calendarGuestModeNotice,
              style: calendarBodyTextStyle.copyWith(
                color: calendarSubtitleColor,
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 1,
            ),
          ),
          SizedBox(width: spacing.s),
          transferMenu,
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
  bool _exporting = false;
  ({int? taskCount, bool isFullModel})? _pendingImport;

  @override
  Widget build(BuildContext context) {
    final bool hasCalendarData = widget.state.model.hasCalendarData;
    final bool busy = _exporting || widget.state.isLoading;
    return BlocListener<GuestCalendarBloc, CalendarState>(
      listenWhen: (previous, current) =>
          previous.isLoading != current.isLoading,
      listener: _handleCalendarStateChanged,
      child: CalendarTransferMenuButton(
        hasCalendarData: hasCalendarData,
        onExport: _handleExportAll,
        onImport: _handleImportCalendar,
        busy: busy,
      ),
    );
  }

  void _handleCalendarStateChanged(BuildContext _, CalendarState state) {
    final pendingImport = _pendingImport;
    if (pendingImport == null || state.isLoading) {
      return;
    }
    if (state.importError == null &&
        state.lastImportedTaskIds.isEmpty &&
        state.lastImportedModelChecksum == null) {
      return;
    }
    _pendingImport = null;
    final int? taskCount = pendingImport.taskCount;
    final bool importedFullModel = pendingImport.isFullModel;
    if (state.importError != null) {
      FeedbackSystem.showError(context, context.l10n.calendarGuestImportFailed);
      return;
    }
    if (importedFullModel) {
      FeedbackSystem.showSuccess(
        context,
        context.l10n.calendarGuestImportSuccess,
      );
      return;
    }
    if (taskCount != null) {
      FeedbackSystem.showSuccess(
        context,
        context.l10n.calendarGuestImportTasksSuccess(taskCount),
      );
    }
  }

  Future<void> _handleExportAll() async {
    if (_exporting || widget.state.isLoading) return;
    final l10n = context.l10n;
    setState(() => _exporting = true);
    try {
      final model = widget.state.model;
      if (!model.hasCalendarData) {
        FeedbackSystem.showInfo(context, l10n.calendarGuestExportNoData);
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
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _handleImportCalendar() async {
    if (_exporting || widget.state.isLoading) return;
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
        _pendingImport = (taskCount: null, isFullModel: true);
        context.read<GuestCalendarBloc>().add(
          CalendarEvent.modelImported(model: importedModel),
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
      _pendingImport = (taskCount: tasks.length, isFullModel: false);
      context.read<GuestCalendarBloc>().add(
        CalendarEvent.tasksImported(tasks: tasks),
      );
    } catch (error) {
      if (!mounted) return;
      FeedbackSystem.showError(
        context,
        context.l10n.calendarGuestImportError(error.toString()),
      );
    }
  }
}
