import 'dart:collection';

import 'package:axichat/src/calendar/guest/guest_calendar_widget.dart';
import 'package:axichat/src/chats/view/archived_chat_screen.dart';
import 'package:axichat/src/chats/view/archives_screen.dart';
import 'package:axichat/src/compose_screen.dart';
import 'package:axichat/src/email/demo/email_demo_screen.dart';
import 'package:axichat/src/home_screen.dart';
import 'package:axichat/src/login_screen.dart';
import 'package:axichat/src/profile_screen.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

part 'routes.g.dart';

typedef ServiceLocator = T Function<T>();

mixin AuthenticationRouteData on GoRouteData {
  bool get authenticationRequired;
}

final routeLocations = UnmodifiableMapView(<String, AuthenticationRouteData>{
  const HomeRoute().location: const HomeRoute(),
  const ProfileRoute().location: const ProfileRoute(),
  const ArchivesRoute().location: const ArchivesRoute(),
  const ComposeRoute().location: const ComposeRoute(),
  const GuestCalendarRoute().location: const GuestCalendarRoute(),
  const LoginRoute().location: const LoginRoute(),
  const EmailDemoRoute().location: const EmailDemoRoute(),
});

class TransitionGoRouteData extends GoRouteData {
  const TransitionGoRouteData();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) {
    if (context.read<SettingsCubit>().state.lowMotion) {
      return NoTransitionPage(child: build(context, state));
    }
    return MaterialPage(child: build(context, state));
  }
}

@TypedGoRoute<HomeRoute>(
  path: '/',
  routes: [
    TypedGoRoute<ProfileRoute>(
      path: ProfileRoute.path,
      routes: [
        TypedGoRoute<ArchivesRoute>(
          path: ArchivesRoute.path,
          routes: [
            TypedGoRoute<ArchivedChatRoute>(path: ArchivedChatRoute.path),
          ],
        ),
      ],
    ),
    TypedGoRoute<ComposeRoute>(path: ComposeRoute.path),
  ],
)
class HomeRoute extends TransitionGoRouteData with AuthenticationRouteData {
  const HomeRoute();

  static const String path = '/';

  @override
  bool get authenticationRequired => true;

  @override
  Widget build(BuildContext context, GoRouterState state) => const HomeScreen();
}

class ProfileRoute extends TransitionGoRouteData with AuthenticationRouteData {
  const ProfileRoute();

  static const path = 'profile';

  @override
  bool get authenticationRequired => true;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ProfileScreen(locate: state.extra! as T Function<T>());
}

class ArchivesRoute extends TransitionGoRouteData with AuthenticationRouteData {
  const ArchivesRoute();

  static const path = 'archives';

  @override
  bool get authenticationRequired => true;

  @override
  Widget build(BuildContext context, GoRouterState state) => ArchivesScreen(
        locate: state.extra! as T Function<T>(),
      );
}

class ArchivedChatRoute extends TransitionGoRouteData
    with AuthenticationRouteData {
  const ArchivedChatRoute({required this.jid});

  static const path = 'chat/:jid';

  final String jid;

  @override
  bool get authenticationRequired => true;

  @override
  Widget build(BuildContext context, GoRouterState state) => ArchivedChatScreen(
        locate: state.extra! as T Function<T>(),
        jid: jid,
      );
}

class ComposeRoute extends TransitionGoRouteData with AuthenticationRouteData {
  const ComposeRoute();

  static const path = 'compose';

  @override
  bool get authenticationRequired => true;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final extra = state.extra as Map<String, dynamic>?;
    final locator = _resolveLocator(context, extra);
    return ComposeScreen(
      locate: locator,
      id: extra?['id'],
      jids: extra?['jids'] ?? [''],
      body: extra?['body'] ?? '',
      attachmentMetadataIds: extra?['attachments'] ?? const <String>[],
    );
  }

  ServiceLocator _resolveLocator(
    BuildContext context,
    Map<String, dynamic>? extra,
  ) {
    final locator = extra?['locate'] as ServiceLocator?;
    if (locator != null) {
      return locator;
    }
    final fallbackContext =
        GoRouter.of(context).routerDelegate.navigatorKey.currentContext ??
            context;
    return <T>() => fallbackContext.read<T>();
  }
}

@TypedGoRoute<GuestCalendarRoute>(path: '/guest-calendar')
class GuestCalendarRoute extends TransitionGoRouteData
    with AuthenticationRouteData {
  const GuestCalendarRoute();

  @override
  bool get authenticationRequired => false;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const GuestCalendarWidget();
}

@TypedGoRoute<EmailDemoRoute>(path: '/email-demo')
class EmailDemoRoute extends TransitionGoRouteData
    with AuthenticationRouteData {
  const EmailDemoRoute();

  @override
  bool get authenticationRequired => true;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const EmailDemoScreen();
}

@TypedGoRoute<LoginRoute>(path: '/login')
class LoginRoute extends GoRouteData with AuthenticationRouteData {
  const LoginRoute();

  @override
  bool get authenticationRequired => false;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const LoginScreen();
}
