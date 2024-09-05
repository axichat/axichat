import 'package:chat/src/compose_screen.dart';
import 'package:chat/src/home_screen.dart';
import 'package:chat/src/login_screen.dart';
import 'package:chat/src/profile_screen.dart';
import 'package:chat/src/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

part 'routes.g.dart';

class TransitionGoRouteData extends GoRouteData {
  const TransitionGoRouteData();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      MaterialPage(child: build(context, state));
}

@TypedGoRoute<HomeRoute>(
  path: '/',
  routes: [
    TypedGoRoute<ProfileRoute>(path: ProfileRoute.path),
    TypedGoRoute<ComposeRoute>(path: ComposeRoute.path),
  ],
)
class HomeRoute extends TransitionGoRouteData {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HomeScreen();
}

class ProfileRoute extends TransitionGoRouteData {
  const ProfileRoute();

  static const path = 'profile';

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ProfileScreen(locate: state.extra as T Function<T>());
}

class ComposeRoute extends TransitionGoRouteData {
  const ComposeRoute();

  static const path = 'compose';

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final extra = state.extra as Map<String, dynamic>;
    return ComposeScreen(
      locate: extra['locate'] as T Function<T>(),
      id: extra['id'],
      jids: extra['jids'] ?? [''],
      body: extra['body'] ?? '',
    );
  }
}

@TypedGoRoute<LoginRoute>(path: '/login')
class LoginRoute extends GoRouteData {
  const LoginRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const LoginScreen();
}

@TypedGoRoute<SettingsRoute>(path: '/settings')
class SettingsRoute extends TransitionGoRouteData {
  const SettingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SettingsScreen();
}
