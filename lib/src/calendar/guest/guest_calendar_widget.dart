import 'dart:io';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return CalendarMobileTabShell(
      tabBar: tabSwitcher,
      cancelBucket: cancelBucket,
      backgroundColor: colors.surface,
      borderColor: theme.dividerColor,
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
          children: [
            navigation,
            if (errorBanner != null) errorBanner,
          ],
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
    return SafeArea(
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
    return CalendarLoadingOverlay(
      color: Colors.black.withValues(alpha: 0.3),
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
  }

  Future<void> _handleBannerBackNavigation() async {
    final navigator =
        GoRouter.of(context).routerDelegate.navigatorKey.currentState;
    if (navigator != null && await navigator.maybePop()) {
      return;
    }
    if (!mounted) {
      return;
    }
    context.go('/login');
  }

  Color _calendarSurfaceColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? theme.colorScheme.surface
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
        border: const Border(
          bottom: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      padding: bannerPadding,
      child: Row(
        children: [
          AxiIconButton(
            iconData: Icons.arrow_back,
            tooltip: 'Back to login',
            onPressed: () {
              onNavigateBack();
            },
          ),
          const SizedBox(width: calendarGutterMd),
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: calendarGutterMd),
          Expanded(
            child: Text(
              'Guest Mode - Tasks saved locally on this device only',
              style: calendarBodyTextStyle.copyWith(
                color: calendarSubtitleColor,
                fontSize: 14,
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 2,
            ),
          ),
          const SizedBox(width: calendarGutterMd),
          transferMenu,
          const SizedBox(width: calendarGutterMd),
          TaskPrimaryButton(
            label: 'Sign Up to Sync',
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

class _GuestTransferMenuState extends State<_GuestTransferMenu> {
  final CalendarTransferService _transferService =
      const CalendarTransferService();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final bool hasTasks = widget.state.model.tasks.isNotEmpty;
    return CalendarTransferMenuButton(
      hasTasks: hasTasks,
      onExport: _handleExportAll,
      onImport: _handleImportCalendar,
      busy: _busy,
    );
  }

  Future<void> _handleExportAll() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final Iterable<CalendarTask> tasks =
          context.read<GuestCalendarBloc>().state.model.tasks.values;
      if (tasks.isEmpty) {
        FeedbackSystem.showInfo(context, 'No tasks available to export.');
        return;
      }
      final format = await showCalendarExportFormatSheet(
        context,
        title: 'Export guest calendar',
      );
      if (!mounted || format == null) return;
      final file = await _transferService.exportTasks(
        tasks: tasks,
        format: format,
        fileNamePrefix: 'axichat_guest_calendar',
      );
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Axichat guest calendar export',
        text: 'Axichat guest calendar export (${format.label})',
      );
      if (!mounted) return;
      FeedbackSystem.showSuccess(context, 'Export ready to share.');
    } catch (error) {
      if (!mounted) return;
      FeedbackSystem.showError(
        context,
        'Failed to export calendar: $error',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleImportCalendar() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
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
          .read<GuestCalendarBloc>()
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
