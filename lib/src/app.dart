import 'dart:convert';

import 'package:chat/src/authentication/bloc/authentication_cubit.dart';
import 'package:chat/src/common/capability.dart';
import 'package:chat/src/common/policy.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/routes.dart';
import 'package:chat/src/settings/bloc/settings_cubit.dart';
import 'package:chat/src/storage/credential_store.dart';
import 'package:chat/src/storage/database.dart';
import 'package:chat/src/storage/models.dart';
import 'package:chat/src/storage/state_store.dart';
import 'package:chat/src/xmpp/foreground_socket.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class Axichat extends StatelessWidget {
  const Axichat({
    super.key,
    XmppService? xmppService,
    Capability? capability,
    Policy? policy,
  })  : _xmppService = xmppService,
        _capability = capability ?? const Capability(),
        _policy = policy ?? const Policy();

  final XmppService? _xmppService;
  final Capability _capability;
  final Policy _policy;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        if (_xmppService == null)
          RepositoryProvider(
            create: (context) => XmppService(
              buildConnection: () => !_capability.canForegroundService
                  ? XmppConnection()
                  : XmppConnection(
                      socketWrapper: ForegroundSocketWrapper(),
                    ),
              buildStateStore: (prefix, passphrase) async {
                await Hive.initFlutter(prefix);
                if (!Hive.isAdapterRegistered(1)) {
                  Hive.registerAdapter(PresenceAdapter());
                }
                await Hive.openBox(
                  XmppStateStore.boxName,
                  encryptionCipher: HiveAesCipher(utf8.encode(passphrase)),
                );
                return XmppStateStore();
              },
              buildDatabase: (prefix, passphrase) async {
                return XmppDrift(
                  file: await dbFileFor(prefix),
                  passphrase: passphrase,
                );
              },
              capability: _capability,
              policy: _policy,
            ),
          )
        else
          RepositoryProvider.value(value: _xmppService),
        RepositoryProvider.value(value: _capability),
        RepositoryProvider.value(value: _policy),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => SettingsCubit(),
          ),
          BlocProvider(
            create: (context) => AuthenticationCubit(
              credentialStore: CredentialStore(
                capability: context.read<Capability>(),
                policy: context.read<Policy>(),
              ),
              xmppService: context.read<XmppService>(),
              capability: context.read<Capability>(),
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
      if (context.read<AuthenticationCubit>().state
          is! AuthenticationComplete) {
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
        final lightTheme = ShadThemeData(
          colorScheme: ShadColorScheme.fromName(state.shadColor.name),
          brightness: Brightness.light,
          decoration: const ShadDecoration(
            errorPadding: inputSubtextInsets,
          ),
        );
        final darkTheme = ShadThemeData(
          colorScheme: ShadColorScheme.fromName(
            state.shadColor.name,
            brightness: Brightness.dark,
          ),
          brightness: Brightness.dark,
          decoration: const ShadDecoration(
            errorPadding: inputSubtextInsets,
          ),
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
