// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:collection';

import 'package:axichat/src/attachments/view/attachment_gallery_screen.dart';
import 'package:axichat/src/blocklist/view/blocklist_screen.dart';
import 'package:axichat/src/calendar/guest/guest_calendar_widget.dart';
import 'package:axichat/src/chats/view/archived_chat_screen.dart';
import 'package:axichat/src/chats/view/archives_screen.dart';
import 'package:axichat/src/email/demo/email_demo_screen.dart';
import 'package:axichat/src/home_screen.dart';
import 'package:axichat/src/login_screen.dart';
import 'package:axichat/src/avatar/view/avatar_editor_screen.dart';
import 'package:axichat/src/profile_screen.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

part 'routes.g.dart';

typedef ServiceLocator = T Function<T>();

const Curve _routeFadeCurve = Curves.easeInOutCubic;

mixin AuthenticationRouteData on GoRouteData {
  bool get authenticationRequired;
}

T Function<T>() _resolveLocate(BuildContext context, GoRouterState state) {
  final extra = state.extra;
  if (extra is T Function<T>()) {
    return extra;
  }
  return context.read;
}

final routeLocations = UnmodifiableMapView(<String, AuthenticationRouteData>{
  const HomeRoute().location: const HomeRoute(),
  const ProfileRoute().location: const ProfileRoute(),
  const AvatarEditorRoute().location: const AvatarEditorRoute(),
  const ArchivesRoute().location: const ArchivesRoute(),
  const AttachmentGalleryRoute().location: const AttachmentGalleryRoute(),
  const BlocklistRoute().location: const BlocklistRoute(),
  const GuestCalendarRoute().location: const GuestCalendarRoute(),
  const LoginRoute().location: const LoginRoute(),
  const EmailDemoRoute().location: const EmailDemoRoute(),
});

final List<_RouteLocationPattern> _routeLocationPatterns =
    <_RouteLocationPattern>[
      _RouteLocationPattern(
        template: ArchivedChatRoute.path,
        route: const ArchivedChatRoute(jid: ''),
      ),
    ];

AuthenticationRouteData? resolveRouteLocation(String location) {
  final direct = routeLocations[location];
  if (direct != null) {
    return direct;
  }
  final normalized = location.trim();
  if (normalized.isEmpty) {
    return null;
  }
  for (final pattern in _routeLocationPatterns) {
    if (pattern.matches(normalized)) {
      return pattern.route;
    }
  }
  return null;
}

class _RouteLocationPattern {
  _RouteLocationPattern({required this.template, required this.route})
    : _regexp = _compileTemplate(template);

  final String template;
  final AuthenticationRouteData route;
  final RegExp _regexp;

  bool matches(String location) => _regexp.hasMatch(location);

  static RegExp _compileTemplate(String template) {
    final segments = template.split('/');
    final encoded = segments
        .map((segment) {
          if (segment.isEmpty) {
            return '';
          }
          if (segment.startsWith(':')) {
            return '[^/]+';
          }
          return RegExp.escape(segment);
        })
        .join('/');
    return RegExp('^$encoded\$');
  }
}

class TransitionGoRouteData extends GoRouteData {
  const TransitionGoRouteData();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) {
    final pageKey = ValueKey<String>(state.uri.toString());
    if (context.watch<SettingsCubit>().state.lowMotion) {
      return NoTransitionPage(key: pageKey, child: build(context, state));
    }
    final animationDuration = context.watch<SettingsCubit>().animationDuration;
    return CustomTransitionPage(
      key: pageKey,
      transitionDuration: animationDuration,
      reverseTransitionDuration: animationDuration,
      child: build(context, state),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final CurvedAnimation curved = CurvedAnimation(
          parent: animation,
          curve: _routeFadeCurve,
          reverseCurve: _routeFadeCurve,
        );
        return FadeTransition(opacity: curved, child: child);
      },
    );
  }
}

@TypedStatefulShellRoute<HomeShellRoute>(
  branches: <TypedStatefulShellBranch<StatefulShellBranchData>>[
    TypedStatefulShellBranch<HomeShellBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<HomeRoute>(path: HomeRoute.path),
      ],
    ),
    TypedStatefulShellBranch<ProfileShellBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<ProfileRoute>(path: ProfileRoute.path),
        TypedGoRoute<ArchivesRoute>(path: ArchivesRoute.path),
        TypedGoRoute<BlocklistRoute>(path: BlocklistRoute.path),
        TypedGoRoute<ArchivedChatRoute>(path: ArchivedChatRoute.path),
      ],
    ),
  ],
)
class HomeShellRoute extends StatefulShellRouteData {
  const HomeShellRoute();

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell navigationShell,
  ) {
    return HomeShellCalendarScope(navigationShell: navigationShell);
  }
}

class HomeShellBranchData extends StatefulShellBranchData {
  const HomeShellBranchData();
}

class ProfileShellBranchData extends StatefulShellBranchData {
  const ProfileShellBranchData();
}

@TypedGoRoute<HomeRoute>(path: HomeRoute.path)
class HomeRoute extends TransitionGoRouteData
    with $HomeRoute, AuthenticationRouteData {
  const HomeRoute();

  static const String path = '/';

  @override
  bool get authenticationRequired => true;

  @override
  String get location => GoRouteData.$location(path);

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);

  @override
  Widget build(BuildContext context, GoRouterState state) => const HomeScreen();
}

class ProfileRoute extends TransitionGoRouteData
    with $ProfileRoute, AuthenticationRouteData {
  const ProfileRoute();

  static const path = '/profile';

  @override
  bool get authenticationRequired => true;

  @override
  String get location => GoRouteData.$location(path);

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ProfileScreen();
}

@TypedGoRoute<AvatarEditorRoute>(path: AvatarEditorRoute.path)
class AvatarEditorRoute extends TransitionGoRouteData
    with $AvatarEditorRoute, AuthenticationRouteData {
  const AvatarEditorRoute();

  static const path = '/profile/avatar';

  @override
  bool get authenticationRequired => true;

  @override
  String get location => GoRouteData.$location(path);

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      AvatarEditorScreen(locate: _resolveLocate(context, state));
}

class ArchivesRoute extends TransitionGoRouteData
    with $ArchivesRoute, AuthenticationRouteData {
  const ArchivesRoute();

  static const path = '/profile/archives';

  @override
  bool get authenticationRequired => true;

  @override
  String get location => GoRouteData.$location(path);

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ArchivesScreen(locate: _resolveLocate(context, state));
}

@TypedGoRoute<AttachmentGalleryRoute>(path: AttachmentGalleryRoute.path)
class AttachmentGalleryRoute extends TransitionGoRouteData
    with $AttachmentGalleryRoute, AuthenticationRouteData {
  const AttachmentGalleryRoute();

  static const path = '/profile/attachments';

  @override
  bool get authenticationRequired => true;

  @override
  String get location => GoRouteData.$location(path);

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      AttachmentGalleryScreen(locate: _resolveLocate(context, state));
}

class BlocklistRoute extends TransitionGoRouteData
    with $BlocklistRoute, AuthenticationRouteData {
  const BlocklistRoute();

  static const path = '/profile/blocklist';

  @override
  bool get authenticationRequired => true;

  @override
  String get location => GoRouteData.$location(path);

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const BlocklistScreen();
}

class ArchivedChatRoute extends TransitionGoRouteData
    with $ArchivedChatRoute, AuthenticationRouteData {
  const ArchivedChatRoute({required this.jid});

  static const path = '/profile/archives/chat/:jid';

  final String jid;

  @override
  bool get authenticationRequired => true;

  @override
  String get location => GoRouteData.$location(
    '/profile/archives/chat/${Uri.encodeComponent(jid)}',
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ArchivedChatScreen(locate: _resolveLocate(context, state), jid: jid);
}

@TypedGoRoute<GuestCalendarRoute>(path: '/guest-calendar')
class GuestCalendarRoute extends TransitionGoRouteData
    with $GuestCalendarRoute, AuthenticationRouteData {
  const GuestCalendarRoute();

  @override
  bool get authenticationRequired => false;

  @override
  String get location => GoRouteData.$location('/guest-calendar');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const GuestCalendarWidget();
}

@TypedGoRoute<EmailDemoRoute>(path: '/email-demo')
class EmailDemoRoute extends TransitionGoRouteData
    with $EmailDemoRoute, AuthenticationRouteData {
  const EmailDemoRoute();

  @override
  bool get authenticationRequired => true;

  @override
  String get location => GoRouteData.$location('/email-demo');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const EmailDemoScreen();
}

@TypedGoRoute<LoginRoute>(path: '/login')
class LoginRoute extends TransitionGoRouteData
    with $LoginRoute, AuthenticationRouteData {
  const LoginRoute();

  @override
  bool get authenticationRequired => false;

  @override
  String get location => GoRouteData.$location('/login');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const LoginScreen();
}
