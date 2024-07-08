import 'package:chat/src/authentication/bloc/authentication_bloc.dart';
import 'package:chat/src/routes.dart';
import 'package:chat/src/settings/bloc/settings_cubit.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

class Axichat extends StatelessWidget {
  const Axichat({
    super.key,
    required XmppService xmppService,
  }) : _xmppService = xmppService;

  final XmppService _xmppService;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: _xmppService,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => SettingsCubit(),
          ),
          BlocProvider(
            create: (context) => AuthenticationBloc(
              xmppService: context.read<XmppService>(),
            ),
          ),
        ],
        child: MaterialAxichat(),
      ),
    );
  }
}

class MaterialAxichat extends StatelessWidget {
  MaterialAxichat({super.key});

  final _router = GoRouter(
    restorationScopeId: 'app',
    redirect: (context, routerState) {
      if (context.read<AuthenticationBloc>().state is! AuthenticationComplete) {
        return const LoginRoute().location;
      }
      return null;
    },
    routes: $appRoutes,
  );

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        return MaterialApp.router(
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
          theme: ThemeData(colorSchemeSeed: Colors.indigoAccent),
          darkTheme: ThemeData.dark(),
          themeMode: state.themeMode,
          routerConfig: _router,
          builder: (context, child) {
            return BlocListener<AuthenticationBloc, AuthenticationState>(
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
