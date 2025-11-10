import 'dart:async';
import 'dart:convert';

import 'package:axichat/main.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/guest/guest_calendar_bloc.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/reminders/calendar_reminder_controller.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/calendar/storage/calendar_hive_adapters.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/policy.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/omemo_activity/bloc/omemo_activity_cubit.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/notifications/view/omemo_operation_overlay.dart';
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
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'localization/app_localizations.dart';

class Axichat extends StatefulWidget {
  Axichat({
    super.key,
    XmppService? xmppService,
    NotificationService? notificationService,
    Capability? capability,
    Policy? policy,
    Box<CalendarModel>? guestCalendarBox,
    required CalendarStorageManager storageManager,
  })  : _xmppService = xmppService,
        _notificationService = notificationService ?? NotificationService(),
        _capability = capability ?? const Capability(),
        _policy = policy ?? const Policy(),
        _guestCalendarBox = guestCalendarBox,
        _storageManager = storageManager;

  final XmppService? _xmppService;
  final NotificationService _notificationService;
  final Capability _capability;
  final Policy _policy;
  final Box<CalendarModel>? _guestCalendarBox;
  final CalendarStorageManager _storageManager;

  @override
  State<Axichat> createState() => _AxichatState();
}

class _AxichatState extends State<Axichat> {
  Storage? _authStorage;
  late final CalendarReminderController _reminderController =
      CalendarReminderController(
    notificationService: widget._notificationService,
  );

  @override
  void dispose() {
    unawaited(_reminderController.clearAll());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        if (widget._guestCalendarBox != null)
          RepositoryProvider<Box<CalendarModel>>(
            create: (_) => widget._guestCalendarBox!,
            key: const Key('guest_calendar_box'),
          ),
        RepositoryProvider<Storage?>.value(
          value: _authStorage,
          key: const Key('calendar_storage'),
        ),
        if (widget._xmppService == null)
          RepositoryProvider<XmppService>(
            create: (context) => XmppService(
              buildConnection: () =>
                  withForeground && foregroundServiceActive.value
                      ? XmppConnection(
                          socketWrapper: ForegroundSocketWrapper(),
                        )
                      : XmppConnection(),
              buildStateStore: (prefix, passphrase) async {
                await Hive.initFlutter(prefix);
                if (!Hive.isAdapterRegistered(1)) {
                  Hive.registerAdapter(PresenceAdapter());
                }
                registerCalendarHiveAdapters(Hive);
                await Hive.openBox(
                  XmppStateStore.boxName,
                  encryptionCipher: HiveAesCipher(utf8.encode(passphrase)),
                );
                final calendarBox = await Hive.openBox<CalendarModel>(
                  'calendar',
                  encryptionCipher: HiveAesCipher(utf8.encode(passphrase)),
                );
                final legacyModel = calendarBox.get('calendar');
                final storage = await widget._storageManager.ensureAuthStorage(
                  passphrase: passphrase,
                  legacyModel: legacyModel,
                );

                await calendarBox.close();

                setState(() {
                  _authStorage = storage;
                });
                return XmppStateStore();
              },
              buildDatabase: (prefix, passphrase) async {
                return XmppDrift(
                  file: await dbFileFor(prefix),
                  passphrase: passphrase,
                );
              },
              notificationService: widget._notificationService,
              capability: widget._capability,
            ),
          )
        else
          RepositoryProvider<XmppService>.value(
            value: widget._xmppService!,
          ),
        RepositoryProvider.value(value: widget._notificationService),
        RepositoryProvider.value(value: widget._capability),
        RepositoryProvider.value(value: widget._policy),
        RepositoryProvider.value(value: _reminderController),
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
          BlocProvider(
            create: (context) => OmemoActivityCubit(
              xmppBase: context.read<XmppService>(),
            ),
          ),
          if (widget._storageManager.guestStorage != null)
            BlocProvider(
              create: (context) => GuestCalendarBloc(
                storage: widget._storageManager.guestStorage!,
                reminderController: _reminderController,
              )..add(const CalendarStarted()),
              key: const Key('guest_calendar_bloc'),
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
        // Check if the current route allows guest access
        final location = routeLocations[routerState.matchedLocation];
        if (location?.authenticationRequired == false) {
          return null; // Allow access to guest routes
        }
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
                final location = routeLocations[_router.state.matchedLocation]!;
                if (state is AuthenticationNone &&
                    location.authenticationRequired) {
                  _router.go(const LoginRoute().location);
                } else if (state is AuthenticationComplete &&
                    !location.authenticationRequired) {
                  _router.go(const HomeRoute().location);
                }
              },
              child: Stack(
                children: [
                  if (child != null) child else const SizedBox.shrink(),
                  const OmemoOperationOverlay(),
                ],
              ),
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

  BorderRadius get radius => ShadTheme.of(this).radius;
}
