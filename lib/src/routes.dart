import 'package:axichat/src/compose_screen.dart';
import 'package:axichat/src/home_screen.dart';
import 'package:axichat/src/login_screen.dart';
import 'package:axichat/src/profile_screen.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/verification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

part 'routes.g.dart';

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
    TypedGoRoute<VerificationRoute>(path: VerificationRoute.path),
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
      ProfileScreen(locate: state.extra! as T Function<T>());
}

class VerificationRoute extends TransitionGoRouteData {
  const VerificationRoute();

  static const path = 'verification';

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final extra = state.extra! as Map<String, dynamic>;
    return VerificationScreen(
      locate: extra['locate'] as T Function<T>(),
      jid: extra['jid'],
    );
  }
}

class ComposeRoute extends TransitionGoRouteData {
  const ComposeRoute();

  static const path = 'compose';

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
class LoginRoute extends GoRouteData {
  const LoginRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const LoginScreen();
}
