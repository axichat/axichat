import 'dart:convert';

import 'package:axichat/main.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/policy.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/routes.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/state_store.dart';
import 'package:axichat/src/xmpp/foreground_socket.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'localization/app_localizations.dart';

class Axichat extends StatelessWidget {
  Axichat({
    super.key,
    XmppBase? xmppService,
    NotificationService? notificationService,
    Capability? capability,
    Policy? policy,
  })  : _xmppService = xmppService,
        _notificationService = notificationService ?? NotificationService(),
        _capability = capability ?? const Capability(),
        _policy = policy ?? const Policy();

  final XmppBase? _xmppService;
  final NotificationService _notificationService;
  final Capability _capability;
  final Policy _policy;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        if (_xmppService == null)
          RepositoryProvider(
            create: (context) => XmppService(
              buildConnection: () => withForeground
                  ? XmppConnection(socketWrapper: ForegroundSocketWrapper())
                  : XmppConnection(),
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
              notificationService: _notificationService,
              capability: _capability,
              policy: _policy,
            ),
          )
        else
          RepositoryProvider.value(value: _xmppService),
        RepositoryProvider.value(value: _notificationService),
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
              notificationService: context.read<NotificationService>(),
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
        context.read<NotificationService>().mute = state.mute;
        if (context.read<XmppService>() case final ChatsService service) {
          service.toggleAllChatsMarkerResponsive(
            responsive: state.readReceipts,
          );
        }
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
              iconTheme: const IconThemeData(size: 20),
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

  IconThemeData get iconTheme => IconTheme.of(this);

  ShadDecoration get decoration => ShadTheme.of(this).decoration;

  BorderRadius get radius => ShadTheme.of(this).radius;
}
