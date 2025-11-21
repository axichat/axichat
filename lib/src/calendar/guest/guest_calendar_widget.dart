import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../bloc/calendar_state.dart';
import '../utils/responsive_helper.dart';
import '../view/calendar_experience_state.dart';
import '../view/feedback_system.dart';
import '../view/widgets/calendar_loading_overlay.dart';
import '../view/widgets/calendar_mobile_tab_shell.dart';
import '../view/widgets/calendar_task_feedback_observer.dart';
import '../view/widgets/task_form_section.dart';
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
      spec.contentPadding;

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
  Widget? buildDesktopTopHeader(Widget navigation, Widget? errorBanner) => null;

  @override
  Widget? buildDesktopBodyHeader(Widget navigation, Widget? errorBanner) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        navigation,
        if (errorBanner != null) errorBanner,
      ],
    );
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
      children.add(navigation);
    }
    if (errorBanner != null) {
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
  });

  final Future<void> Function() onNavigateBack;
  final VoidCallback onSignUp;

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
              ),
            ),
          ),
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
