import 'dart:ui';

import 'package:chat/src/authentication/bloc/authentication_cubit.dart';
import 'package:chat/src/common/capability.dart';
import 'package:chat/src/common/policy.dart';
import 'package:chat/src/routes.dart';
import 'package:chat/src/settings/bloc/settings_cubit.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class Axichat extends StatelessWidget {
  const Axichat({
    super.key,
    required XmppService xmppService,
  }) : _xmppService = xmppService;

  final XmppService _xmppService;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: _xmppService),
        RepositoryProvider(create: (context) => Capability()),
        RepositoryProvider(create: (context) => Policy()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => SettingsCubit(),
          ),
          BlocProvider(
            create: (context) => AuthenticationCubit(
              xmppService: context.read<XmppService>(),
            ),
          ),
        ],
        child: const MaterialAxichat(),
      ),
    );
  }
}

class MaterialAxichat extends StatefulWidget {
  const MaterialAxichat({super.key});

  @override
  State<MaterialAxichat> createState() => _MaterialAxichatState();
}

class _MaterialAxichatState extends State<MaterialAxichat> {
  final _log = Logger('MaterialAxichat');

  final _router = GoRouter(
    restorationScopeId: 'app',
    redirect: (context, routerState) {
      if (context.read<AuthenticationCubit>().state
          is! AuthenticationComplete) {
        return const LoginRoute().location;
      }
      return null;
    },
    routes: $appRoutes,
  );

  AppLifecycleListener? _lifecycleListener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lifecycleListener = _lifecycleListener ??
        AppLifecycleListener(
          onStateChange: (state) async {
            if (state == AppLifecycleState.resumed) {
              if (context.read<XmppService>().user != null) return;
              try {
                await context.read<AuthenticationCubit>().login();
              } on XmppException catch (_) {
                _log.info('Redirecting to login screen...');
              }
            } else if (state == AppLifecycleState.detached) {
              await context.read<AuthenticationCubit>().logout();
            }
          },
          onExitRequested: () async {
            await context.read<AuthenticationCubit>().logout();
            return AppExitResponse.exit;
          },
        );
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final lightTheme = ShadThemeData(
          colorScheme: ShadColorScheme.fromName(state.shadColor.name),
          brightness: Brightness.light,
        );
        final darkTheme = ShadThemeData(
          colorScheme: ShadColorScheme.fromName(
            state.shadColor.name,
            brightness: Brightness.dark,
          ),
          brightness: Brightness.dark,
        );
        return ShadApp.router(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''),
          ],
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: state.themeMode,
          materialThemeBuilder: (context, theme) {
            final shadTheme =
                theme.brightness == Brightness.light ? lightTheme : darkTheme;
            return theme.copyWith(
              textTheme: TextTheme(
                displayLarge: shadTheme.textTheme.h1Large,
                displayMedium: shadTheme.textTheme.h1,
                displaySmall: shadTheme.textTheme.h2,
                titleLarge: shadTheme.textTheme.h3,
                titleMedium: shadTheme.textTheme.large,
                titleSmall: shadTheme.textTheme.small,
                bodyLarge: shadTheme.textTheme.p,
                bodyMedium: shadTheme.textTheme.small,
                bodySmall: shadTheme.textTheme.muted,
                labelLarge: shadTheme.textTheme.muted,
                labelMedium: shadTheme.textTheme.muted,
                labelSmall: shadTheme.textTheme.muted,
              ),
            );
          },
          routerConfig: _router,
          builder: (context, child) {
            return BlocListener<AuthenticationCubit, AuthenticationState>(
              listener: (context, state) {
                if (state is AuthenticationNone) {
                  _router.go(const LoginRoute().location);
                } else if (state is AuthenticationComplete) {
                  _router.go(const HomeRoute().location);
                }
              },
              child: child,
            );
          },
        );
      },
    );
  }
}

extension ThemeExtension on BuildContext {
  ShadColorScheme get colorScheme => ShadTheme.of(this).colorScheme;
  ShadTextTheme get textTheme => ShadTheme.of(this).textTheme;
  ShadDecoration get decoration => ShadTheme.of(this).decoration;
  BorderRadius get radius => ShadTheme.of(this).radius;
}
