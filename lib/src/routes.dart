import 'dart:collection';

import 'package:axichat/src/compose_screen.dart';
import 'package:axichat/src/home_screen.dart';
import 'package:axichat/src/login_screen.dart';
import 'package:axichat/src/profile_screen.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

part 'routes.g.dart';

mixin AuthenticationRouteData on GoRouteData {
  bool get authenticationRequired;
}

final routeLocations = UnmodifiableMapView(<String, AuthenticationRouteData>{
  const HomeRoute().location: const HomeRoute(),
  const ProfileRoute().location: const ProfileRoute(),
  const ComposeRoute().location: const ComposeRoute(),
  const LoginRoute().location: const LoginRoute(),
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
    TypedGoRoute<ProfileRoute>(path: ProfileRoute.path),
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

class ComposeRoute extends TransitionGoRouteData with AuthenticationRouteData {
  const ComposeRoute();

  static const path = 'compose';

  @override
  bool get authenticationRequired => true;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final extra = state.extra! as Map<String, dynamic>;
    return ComposeScreen(
      locate: extra['locate'] as T Function<T>(),
      id: extra['id'],
      jids: extra['jids'] ?? [''],
      body: extra['body'] ?? '',
    );
  }
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
