// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:axichat/main.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/guest/guest_calendar_bloc.dart';
import 'package:axichat/src/calendar/reminders/calendar_reminder_controller.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_manager.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/file_type_detector.dart';
import 'package:axichat/src/common/policy.dart';
import 'package:axichat/src/common/shorebird_push.dart';
import 'package:axichat/src/common/ui/app_theme.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:axichat/src/demo/demo_calendar.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/draft/bloc/compose_window_cubit.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/view/compose_launcher.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/attachment_optimizer.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/home/service/home_refresh_sync_service.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/omemo_activity/bloc/omemo_activity_cubit.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/routes.dart';
import 'package:axichat/src/settings/app_language.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/share/bloc/share_intent_cubit.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/hive_extensions.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/state_store.dart';
import 'package:axichat/src/xmpp/foreground_socket.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:axichat/src/xmpp_activity/bloc/xmpp_activity_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'localization/app_localizations.dart';

Timer? _pendingAuthNavigation;
AuthenticationState? _lastAuthState;
const String _shareFileSchemePrefix = 'file://';
const String _emptyShareBody = '';
const List<String> _emptyShareJids = [''];
const int _shareAttachmentUnknownSizeBytes = 0;
const int _shareAttachmentMinSizeBytes = 1;

class Axichat extends StatefulWidget {
  Axichat({
    super.key,
    XmppService? xmppService,
    NotificationService? notificationService,
    Capability? capability,
    Policy? policy,
    required CalendarStorageManager storageManager,
  })  : _xmppService = xmppService,
        _notificationService = notificationService ?? NotificationService(),
        _capability = capability ?? const Capability(),
        _policy = policy ?? const Policy(),
        _storageManager = storageManager;

  final XmppService? _xmppService;
  final NotificationService _notificationService;
  final Capability _capability;
  final Policy _policy;
  final CalendarStorageManager _storageManager;

  @override
  State<Axichat> createState() => _AxichatState();
}

class _AxichatState extends State<Axichat> {
  late final CalendarReminderController _reminderController =
      CalendarReminderController(
    notificationService: widget._notificationService,
  );
  late final XmppService _xmppService;
  late final XmppActivityCubit _xmppActivityCubit;

  @override
  void initState() {
    super.initState();
    _xmppService = widget._xmppService ??
        XmppService(
          buildConnection: () => withForeground && foregroundServiceActive.value
              ? XmppConnection(socketWrapper: ForegroundSocketWrapper())
              : XmppConnection(),
          buildStateStore: (prefix, passphrase) async {
            final Logger logger = Logger('XmppStateStore');
            await Hive.initFlutter(prefix);
            if (!Hive.isAdapterRegistered(1)) {
              Hive.registerAdapter(PresenceAdapter());
            }
            await Hive.openBoxWithRetry(
              XmppStateStore.boxName,
              encryptionCipher: HiveAesCipher(utf8.encode(passphrase)),
              logger: logger,
            );
            await widget._storageManager.ensureAuthStorage(
              passphrase: passphrase,
            );
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
        );
    _xmppActivityCubit = XmppActivityCubit(xmppBase: _xmppService);
  }

  @override
  void dispose() {
    _pendingAuthNavigation?.cancel();
    _xmppActivityCubit.close();
    Future<void>(() async {
      await _reminderController.clearAll();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        ChangeNotifierProvider<CalendarStorageManager>(
          create: (context) => widget._storageManager,
        ),
        RepositoryProvider<XmppService>.value(value: _xmppService),
        RepositoryProvider<MessageService>(
          create: (context) => context.read<XmppService>(),
        ),
        RepositoryProvider.value(value: widget._notificationService),
        RepositoryProvider.value(value: widget._capability),
        RepositoryProvider.value(value: widget._policy),
        RepositoryProvider.value(value: _reminderController),
        RepositoryProvider<CredentialStore>(
          create: (context) => CredentialStore(
            capability: context.read<Capability>(),
            policy: context.read<Policy>(),
          ),
        ),
      ],
      child: BlocProvider(
        create: (context) => SettingsCubit(
          xmppService: context.read<XmppService>(),
          capability: context.read<Capability>(),
        ),
        child: Builder(
          builder: (context) {
            final storageManager = context.read<CalendarStorageManager>();
            return MultiRepositoryProvider(
              providers: [
                RepositoryProvider<EmailService>(
                  create: (context) => EmailService(
                    credentialStore: context.read<CredentialStore>(),
                    databaseBuilder: () => context.read<XmppService>().database,
                    notificationService: context.read<NotificationService>(),
                    xmppService: context.read<XmppService>(),
                    messageService: context.read<MessageService>(),
                  ),
                ),
                RepositoryProvider<HomeRefreshSyncService>(
                  create: (context) => HomeRefreshSyncService(
                    xmppService: context.read<XmppService>(),
                    emailService: context
                            .read<SettingsCubit>()
                            .state
                            .endpointConfig
                            .enableSmtp
                        ? context.read<EmailService>()
                        : null,
                  )..start(),
                ),
              ],
              child: MultiBlocProvider(
                providers: [
                  BlocProvider(
                    create: (context) => AuthenticationCubit(
                      credentialStore: context.read<CredentialStore>(),
                      xmppService: context.read<XmppService>(),
                      emailService: context
                              .read<SettingsCubit>()
                              .state
                              .endpointConfig
                              .enableSmtp
                          ? context.read<EmailService>()
                          : null,
                      homeRefreshSyncService:
                          context.read<HomeRefreshSyncService>(),
                      notificationService: context.read<NotificationService>(),
                      initialEndpointConfig:
                          context.read<SettingsCubit>().state.endpointConfig,
                    ),
                  ),
                  BlocProvider(
                    create: (context) => OmemoActivityCubit(
                        xmppBase: context.read<XmppService>()),
                  ),
                  BlocProvider.value(value: _xmppActivityCubit),
                  BlocProvider(
                    create: (context) => ShareIntentCubit()..initialize(),
                  ),
                  BlocProvider(
                    create: (context) {
                      final xmppService = context.read<XmppService>();
                      final OmemoService? omemoService =
                          xmppService is OmemoService
                              ? xmppService as OmemoService
                              : null;
                      return ProfileCubit(
                        xmppService: xmppService,
                        presenceService: xmppService as PresenceService,
                        omemoService: omemoService,
                      );
                    },
                  ),
                  BlocProvider(
                    create: (context) => BlocklistCubit(
                      xmppService: context.read<XmppService>(),
                    ),
                  ),
                  BlocProvider(
                    create: (context) => ChatsCubit(
                      xmppService: context.read<XmppService>(),
                      homeRefreshSyncService:
                          context.read<HomeRefreshSyncService>(),
                      emailService: context
                              .read<SettingsCubit>()
                              .state
                              .endpointConfig
                              .enableSmtp
                          ? context.read<EmailService>()
                          : null,
                    ),
                  ),
                  BlocProvider(
                    create: (context) => RosterCubit(
                      rosterService:
                          context.read<XmppService>() as RosterService,
                    ),
                  ),
                  BlocProvider(
                    create: (context) => DraftCubit(
                      messageService: context.read<MessageService>(),
                      emailService: context
                              .read<SettingsCubit>()
                              .state
                              .endpointConfig
                              .enableSmtp
                          ? context.read<EmailService>()
                          : null,
                    ),
                  ),
                  BlocProvider(
                    create: (context) {
                      final endpointConfig =
                          context.read<SettingsCubit>().state.endpointConfig;
                      final emailEnabled = endpointConfig.enableSmtp;
                      return ConnectivityCubit(
                        xmppBase: context.read<XmppService>(),
                        emailEnabled: emailEnabled,
                        emailService:
                            emailEnabled ? context.read<EmailService>() : null,
                      );
                    },
                  ),
                  BlocProvider(create: (context) => ComposeWindowCubit()),
                  if (widget._storageManager.guestStorage != null)
                    BlocProvider(
                      create: (context) => GuestCalendarBloc(
                        storage: widget._storageManager.guestStorage!,
                        reminderController: _reminderController,
                      )..add(const CalendarStarted()),
                      key: const Key('guest_calendar_bloc'),
                    ),
                ],
                child: MultiBlocListener(
                  listeners: [
                    BlocListener<SettingsCubit, SettingsState>(
                      listenWhen: (previous, current) =>
                          previous.endpointConfig != current.endpointConfig,
                      listener: (context, settings) async {
                        final config = settings.endpointConfig;
                        final emailService = context.read<EmailService>();
                        final EmailService? activeEmailService =
                            config.enableSmtp ? emailService : null;
                        context
                            .read<AuthenticationCubit>()
                            .updateEndpointConfig(config);
                        await context
                            .read<AuthenticationCubit>()
                            .updateEmailService(activeEmailService);
                        if (!context.mounted) return;
                        context
                            .read<ChatsCubit>()
                            .updateEmailService(activeEmailService);
                        context
                            .read<DraftCubit>()
                            .updateEmailService(activeEmailService);
                        emailService.updateEndpointConfig(config);
                        await context
                            .read<HomeRefreshSyncService>()
                            .updateEmailService(activeEmailService);
                        if (!context.mounted) return;
                        context.read<ConnectivityCubit>().updateEmailContext(
                              emailEnabled: config.enableSmtp,
                              emailService: activeEmailService,
                            );
                        if (!config.enableSmtp) {
                          await emailService.shutdown(
                            clearCredentials: false,
                          );
                          await emailService.handleNetworkLost();
                        } else {
                          await emailService.handleNetworkAvailable();
                        }
                      },
                    ),
                  ],
                  child: AnimatedBuilder(
                    animation: storageManager,
                    child: const MaterialAxichat(),
                    builder: (context, child) {
                      final calendarStorage = storageManager.authStorage;
                      final content = child ?? const SizedBox.shrink();
                      if (calendarStorage == null) {
                        return content;
                      }
                      return BlocProvider<CalendarBloc>(
                        create: (context) {
                          final reminderController =
                              context.read<CalendarReminderController>();
                          final xmppService = context.read<XmppService>();
                          const bool seedDemoCalendar = kEnableDemoChats;
                          final storage = calendarStorage;

                          if (seedDemoCalendar) {
                            return CalendarBloc(
                              xmppService: xmppService,
                              emailService: context
                                      .read<SettingsCubit>()
                                      .state
                                      .endpointConfig
                                      .enableSmtp
                                  ? context.read<EmailService>()
                                  : null,
                              reminderController: reminderController,
                              syncManagerBuilder: (bloc) {
                                final manager = CalendarSyncManager(
                                  readModel: () => bloc.currentModel,
                                  applyModel: (model) async {
                                    if (bloc.isClosed) return;
                                    bloc.add(
                                      CalendarEvent.remoteModelApplied(
                                        model: model,
                                      ),
                                    );
                                  },
                                  sendCalendarMessage: (outbound) async {
                                    if (bloc.isClosed) {
                                      return;
                                    }
                                    final jid = xmppService.myJid;
                                    if (jid != null) {
                                      await xmppService.sendCalendarSyncMessage(
                                        jid: jid,
                                        outbound: outbound,
                                      );
                                    }
                                  },
                                  sendSnapshotFile:
                                      xmppService.uploadCalendarSnapshot,
                                );
                                return manager;
                              },
                              storage: storage,
                            )
                              ..add(const CalendarEvent.started())
                              ..add(
                                CalendarEvent.remoteModelApplied(
                                  model:
                                      DemoCalendar.franklin(anchor: demoNow()),
                                ),
                              );
                          }
                          return CalendarBloc(
                            xmppService: xmppService,
                            emailService: context
                                    .read<SettingsCubit>()
                                    .state
                                    .endpointConfig
                                    .enableSmtp
                                ? context.read<EmailService>()
                                : null,
                            reminderController: reminderController,
                            syncManagerBuilder: (bloc) {
                              final manager = CalendarSyncManager(
                                readModel: () => bloc.currentModel,
                                applyModel: (model) async {
                                  if (bloc.isClosed) return;
                                  bloc.add(
                                    CalendarEvent.remoteModelApplied(
                                      model: model,
                                    ),
                                  );
                                },
                                sendCalendarMessage: (outbound) async {
                                  if (bloc.isClosed) {
                                    return;
                                  }
                                  final jid = xmppService.myJid;
                                  if (jid != null) {
                                    await xmppService.sendCalendarSyncMessage(
                                      jid: jid,
                                      outbound: outbound,
                                    );
                                  }
                                },
                                sendSnapshotFile:
                                    xmppService.uploadCalendarSnapshot,
                              );
                              return manager;
                            },
                            storage: storage,
                          )..add(const CalendarEvent.started());
                        },
                        child: BlocListener<SettingsCubit, SettingsState>(
                          listenWhen: (previous, current) =>
                              previous.endpointConfig != current.endpointConfig,
                          listener: (context, settings) {
                            final config = settings.endpointConfig;
                            final emailService = context.read<EmailService>();
                            final EmailService? activeEmailService =
                                config.enableSmtp ? emailService : null;
                            context
                                .read<CalendarBloc>()
                                .updateEmailService(activeEmailService);
                          },
                          child: content,
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
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
  bool _shareIntentHandling = false;
  bool _shareIntentAwaitingRoute = false;

  late final GoRouter _router = GoRouter(
    restorationScopeId: 'app',
    redirect: (context, routerState) {
      if (context.read<AuthenticationCubit>().state
          is! AuthenticationComplete) {
        // Check if the current route allows guest access
        final location = routeLocations[routerState.matchedLocation];
        if (location?.authenticationRequired == false) {
          return null; // Allow access to guest routes
        }
        final loginLocation = const LoginRoute().location;
        if (context.read<AuthenticationCubit>().state
                is AuthenticationLogInInProgress &&
            (context.read<AuthenticationCubit>().state
                    as AuthenticationLogInInProgress)
                .fromSignup &&
            routerState.matchedLocation == loginLocation) {
          return null;
        }
        return loginLocation;
      }
      return null;
    },
    routes: $appRoutes,
  );

  @override
  void initState() {
    super.initState();
    _router.routerDelegate.addListener(_handleRouteChange);
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_handleRouteChange);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsState>(
      listener: (context, state) async {
        final notificationService = context.read<NotificationService>();
        final endpointConfig = state.endpointConfig;
        final EmailService? emailService =
            endpointConfig.enableSmtp ? context.read<EmailService>() : null;
        notificationService
          ..mute = state.mute
          ..notificationPreviewsEnabled = state.notificationPreviewsEnabled;
        emailService?.updateDefaultChatAttachmentAutoDownload(
          state.defaultChatAttachmentAutoDownload,
        );
      },
      builder: (context, state) {
        final localeOverride = state.language.locale;
        const chatNeutrals = ChatNeutrals();
        final lightTheme = AppTheme.build(
          shadColor: state.shadColor,
          brightness: Brightness.light,
          neutrals: chatNeutrals,
        );
        final darkTheme = AppTheme.build(
          shadColor: state.shadColor,
          brightness: Brightness.dark,
          neutrals: chatNeutrals,
        );
        final app = ShadApp.router(
          locale: localeOverride,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: state.themeMode,
          materialThemeBuilder: (context, theme) {
            final shadTheme =
                theme.brightness == Brightness.light ? lightTheme : darkTheme;
            final chatTokens = AppTheme.tokens(
              brightness: theme.brightness,
              neutrals: chatNeutrals,
            );
            final materialColors = shadTheme.colorScheme;
            final globalRadius = shadTheme.radius;
            final buttonShape = SquircleBorder(
              cornerRadius: axiSquircleRadius,
            );
            final listTileShape = buttonShape;
            final outlineInputBorder = OutlineInputBorder(
              borderRadius: globalRadius,
              borderSide: BorderSide(color: materialColors.border),
            );
            final focusedInputBorder = outlineInputBorder.copyWith(
              borderSide: BorderSide(color: materialColors.primary, width: 1.5),
            );
            final errorBorder = outlineInputBorder.copyWith(
              borderSide: BorderSide(
                color: materialColors.destructive,
                width: 1,
              ),
            );
            final selectionOverlay = materialColors.primary.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.12 : 0.06,
            );
            final focusRingColor = materialColors.primary.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.25 : 0.15,
            );
            final textThemeWithEmojiFallback = TextTheme(
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
            ).apply(
              fontFamily: interFontFamily,
              fontFamilyFallback: interFontFallback,
            );
            final appBarTitleStyle = shadTheme.textTheme.h3.copyWith(
              fontFamily: gabaritoFontFamily,
              fontFamilyFallback: gabaritoFontFallback,
              color: materialColors.foreground,
              fontWeight: appBarTitleFontWeight,
            );
            return theme.copyWith(
              iconTheme: const IconThemeData(size: axiIconSize),
              textTheme: textThemeWithEmojiFallback,
              appBarTheme: theme.appBarTheme.copyWith(
                titleTextStyle: appBarTitleStyle,
                toolbarTextStyle: appBarTitleStyle,
                elevation: axiSizing.appBarElevation,
                scrolledUnderElevation: axiSizing.appBarScrolledUnderElevation,
              ),
              scaffoldBackgroundColor: materialColors.background,
              dividerColor: materialColors.border,
              cardColor: materialColors.card,
              listTileTheme: ListTileThemeData(
                shape: listTileShape,
                tileColor: materialColors.card,
                selectedTileColor: Color.alphaBlend(
                  selectionOverlay,
                  materialColors.card,
                ),
                textColor: materialColors.foreground,
                iconColor: materialColors.foreground,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: materialColors.card,
                focusColor: focusRingColor,
                hoverColor: materialColors.card,
                border: outlineInputBorder,
                enabledBorder: outlineInputBorder,
                disabledBorder: outlineInputBorder.copyWith(
                  borderSide: BorderSide(
                    color: materialColors.border.withValues(alpha: 0.6),
                  ),
                ),
                focusedBorder: focusedInputBorder,
                errorBorder: errorBorder,
                focusedErrorBorder: errorBorder,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: axiSpaceM,
                  vertical: axiSpaceS,
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  elevation: 0,
                  backgroundColor: materialColors.primary,
                  foregroundColor: materialColors.primaryForeground,
                  shape: buttonShape,
                  padding: const EdgeInsets.symmetric(
                    horizontal: axiSpaceM,
                    vertical: axiSpaceS,
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: materialColors.card,
                  foregroundColor: materialColors.foreground,
                  shape: buttonShape,
                  side: BorderSide(color: materialColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: axiSpaceM,
                    vertical: axiSpaceS,
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: materialColors.foreground,
                  shape: buttonShape,
                  padding: const EdgeInsets.symmetric(
                    horizontal: axiSpaceS,
                    vertical: axiSpaceXs,
                  ),
                ),
              ),
              checkboxTheme: CheckboxThemeData(
                shape: buttonShape,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                visualDensity: VisualDensity.standard,
                side: BorderSide(
                    color: materialColors.border, width: axiSpaceXxs),
              ),
              scrollbarTheme: ScrollbarThemeData(
                thickness: const WidgetStatePropertyAll<double>(axiSpaceXs),
                radius: const Radius.circular(999),
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  final hovered = states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused) ||
                      states.contains(WidgetState.dragged);
                  return hovered
                      ? chatTokens.scrollbarHover
                      : chatTokens.scrollbar;
                }),
              ),
              extensions: [
                ...theme.extensions.values.where(
                  (extension) => extension is! ChatThemeTokens,
                ),
                chatTokens,
                axiSpacing,
                axiSizing,
              ],
            );
          },
          routerConfig: _router,
          builder: (context, child) {
            context.read<NotificationService>().updateLocalizations(
                  AppLocalizations.of(context)!,
                );
            final endpointConfig =
                context.read<SettingsCubit>().state.endpointConfig;
            if (endpointConfig.enableSmtp) {
              context.read<EmailService>().updateLocalizations(
                    AppLocalizations.of(context)!,
                  );
            }
            final shadTheme = ShadTheme.of(context);
            final brightness = Theme.of(context).brightness;
            CalendarPalette.update(
              scheme: shadTheme.colorScheme,
              brightness: brightness,
            );
            final overlayStyle = _systemUiOverlayStyleFor(Theme.of(context));
            final routedContent = MultiBlocListener(
              listeners: [
                BlocListener<AuthenticationCubit, AuthenticationState>(
                  listener: (context, state) async {
                    final previousAuthState = _lastAuthState;
                    _lastAuthState = state;
                    final currentLocation =
                        _router.routeInformationProvider.value.uri.path;
                    final matchedLocation = _router.state.matchedLocation;
                    final currentRoute = routeLocations[currentLocation];
                    final matchedRoute = routeLocations[matchedLocation];
                    final effectiveRoute = currentRoute ?? matchedRoute;
                    final onLoginRoute =
                        currentLocation == const LoginRoute().location ||
                            matchedLocation == const LoginRoute().location;
                    final onGuestRoute = onLoginRoute ||
                        effectiveRoute == null ||
                        !effectiveRoute.authenticationRequired;
                    final authCompletionDuration =
                        context.read<SettingsCubit>().authCompletionDuration;
                    if (state is AuthenticationNone) {
                      _pendingAuthNavigation?.cancel();
                      _pendingAuthNavigation = null;
                      if (!onLoginRoute &&
                          (effectiveRoute?.authenticationRequired ?? true)) {
                        _router.go(const LoginRoute().location);
                      }
                    } else if (state is AuthenticationComplete &&
                        previousAuthState is! AuthenticationComplete &&
                        onGuestRoute) {
                      _pendingAuthNavigation?.cancel();
                      _pendingAuthNavigation = null;
                      void navigateHome() {
                        final latestAuthState = _lastAuthState;
                        if (latestAuthState is! AuthenticationComplete) return;
                        if (_router.state.matchedLocation ==
                            const HomeRoute().location) {
                          return;
                        }
                        _router.go(const HomeRoute().location);
                        _pendingAuthNavigation = null;
                      }

                      if (authCompletionDuration == Duration.zero) {
                        navigateHome();
                      } else {
                        _pendingAuthNavigation = Timer(
                          authCompletionDuration,
                          navigateHome,
                        );
                      }
                    }
                    await _handleShareIntent();
                  },
                ),
                BlocListener<ShareIntentCubit, ShareIntentState>(
                  listener: (context, _) async {
                    await _handleShareIntent();
                  },
                ),
              ],
              child: child ?? const SizedBox.shrink(),
            );
            Widget content = AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlayStyle,
              child: routedContent,
            );
            content = ScrollConfiguration(
              behavior: const AxiDragScrollBehavior(),
              child: content,
            );
            content = EnvScope(
              child: _ShortcutBindings(
                enabled: context.select<AuthenticationCubit, bool>(
                  (cubit) => cubit.state is AuthenticationComplete,
                ),
                child: _DesktopMenuShell(
                  actionsEnabled: context.select<AuthenticationCubit, bool>(
                    (cubit) => cubit.state is AuthenticationComplete,
                  ),
                  child: content,
                ),
              ),
            );
            content = ShorebirdUpdateGate(child: content);
            return content;
          },
        );

        return ScaffoldMessenger(child: app);
      },
    );
  }

  Future<void> _handleShareIntent() async {
    if (!mounted || _shareIntentHandling) return;
    if (context.read<ShareIntentCubit>().state.hasPayload != true) return;
    if (context.read<AuthenticationCubit>().state is! AuthenticationComplete) {
      return;
    }
    if (_shareIntentAwaitingRoute && !_isOnHomeRoute()) {
      return;
    }
    if (_shareIntentAwaitingRoute && _isOnHomeRoute()) {
      _shareIntentAwaitingRoute = false;
    }
    if (_shouldNavigateToHomeForShare()) {
      _shareIntentAwaitingRoute = true;
      _router.go(const HomeRoute().location);
      return;
    }
    _shareIntentHandling = true;
    try {
      final SharePayload? payload =
          context.read<ShareIntentCubit>().state.payload;
      if (payload == null) return;
      final String resolvedBody = payload.text?.trim() ?? _emptyShareBody;
      final bool hasBody = resolvedBody.isNotEmpty;
      if (!mounted) return;
      final MessageService messageService = context.read<MessageService>();
      final List<String> attachmentMetadataIds =
          await _persistSharedAttachments(
        messageService: messageService,
        attachments: payload.attachments,
      );
      if (!mounted) return;
      if (!hasBody && attachmentMetadataIds.isEmpty) {
        _consumeSharePayload(payload);
        return;
      }
      openComposeDraft(
        context,
        navigator: _router.routerDelegate.navigatorKey.currentState,
        body: resolvedBody,
        jids: _emptyShareJids,
        attachmentMetadataIds: attachmentMetadataIds,
      );
      _consumeSharePayload(payload);
    } finally {
      _shareIntentHandling = false;
    }
  }

  bool _isOnHomeRoute() {
    final String homeLocation = const HomeRoute().location;
    final String currentLocation =
        _router.routeInformationProvider.value.uri.path;
    final String matchedLocation = _router.state.matchedLocation;
    if (currentLocation == homeLocation || matchedLocation == homeLocation) {
      return true;
    }
    return false;
  }

  bool _shouldNavigateToHomeForShare() {
    if (_isOnHomeRoute()) {
      return false;
    }
    final String currentLocation =
        _router.routeInformationProvider.value.uri.path;
    final String matchedLocation = _router.state.matchedLocation;
    final AuthenticationRouteData? currentRoute =
        routeLocations[currentLocation] ?? routeLocations[matchedLocation];
    if (currentRoute == null) {
      return true;
    }
    return currentRoute.authenticationRequired == false;
  }

  void _consumeSharePayload(SharePayload payload) {
    if (!identical(context.read<ShareIntentCubit>().state.payload, payload)) {
      return;
    }
    context.read<ShareIntentCubit>().consume();
  }

  void _handleRouteChange() {
    if (!mounted || !_shareIntentAwaitingRoute) return;
    if (!_isOnHomeRoute()) {
      return;
    }
    _shareIntentAwaitingRoute = false;
    _handleShareIntent();
  }

  Future<List<String>> _persistSharedAttachments({
    required MessageService messageService,
    required List<ShareAttachmentPayload> attachments,
  }) async {
    final List<EmailAttachment> prepared = await _prepareSharedAttachments(
      attachments: attachments,
      optimize: true,
    );
    if (prepared.isEmpty) {
      return const <String>[];
    }
    return messageService.persistDraftAttachmentMetadata(prepared);
  }

  Future<List<EmailAttachment>> _prepareSharedAttachments({
    required List<ShareAttachmentPayload> attachments,
    required bool optimize,
  }) async {
    if (attachments.isEmpty) {
      return const <EmailAttachment>[];
    }
    final List<EmailAttachment> prepared = <EmailAttachment>[];
    for (final ShareAttachmentPayload attachment in attachments) {
      final String normalizedPath = _normalizeSharedAttachmentPath(
        attachment.path,
      );
      if (normalizedPath.isEmpty) {
        continue;
      }
      final File file = File(normalizedPath);
      if (!await file.exists()) {
        continue;
      }
      final String fileName = _resolveSharedAttachmentFileName(normalizedPath);
      final int sizeBytes = await _resolveSharedAttachmentSizeBytes(file);
      final int resolvedSizeBytes = sizeBytes >= _shareAttachmentMinSizeBytes
          ? sizeBytes
          : _shareAttachmentUnknownSizeBytes;
      final String mimeType = await _resolveSharedAttachmentMimeType(
        fileName: fileName,
        path: normalizedPath,
        attachment: attachment,
      );
      EmailAttachment emailAttachment = EmailAttachment(
        path: normalizedPath,
        fileName: fileName,
        sizeBytes: resolvedSizeBytes,
        mimeType: mimeType,
      );
      if (optimize) {
        emailAttachment = await EmailAttachmentOptimizer.optimize(
          emailAttachment,
        );
      }
      prepared.add(emailAttachment);
    }
    return List<EmailAttachment>.unmodifiable(prepared);
  }

  String _normalizeSharedAttachmentPath(String path) {
    final String trimmed = path.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    if (!trimmed.startsWith(_shareFileSchemePrefix)) {
      return trimmed;
    }
    final String? resolved = Uri.tryParse(trimmed)?.toFilePath();
    if (resolved == null || resolved.isEmpty) {
      return trimmed;
    }
    return resolved;
  }

  String _resolveSharedAttachmentFileName(String path) {
    final String baseName = p.basename(path);
    if (baseName.isNotEmpty) {
      return baseName;
    }
    return path;
  }

  Future<String> _resolveSharedAttachmentMimeType({
    required String fileName,
    required String path,
    required ShareAttachmentPayload attachment,
  }) async {
    final String? resolvedMimeType = await resolveMimeTypeFromPath(
      path: path,
      fileName: fileName,
      declaredMimeType: attachment.type.mimeTypeFallback,
    );
    return resolvedMimeType ?? attachment.type.mimeTypeFallback;
  }

  Future<int> _resolveSharedAttachmentSizeBytes(File file) async {
    try {
      return await file.length();
    } on Exception {
      return _shareAttachmentUnknownSizeBytes;
    }
  }
}

extension ThemeExtension on BuildContext {
  ShadColorScheme get colorScheme => ShadTheme.of(this).colorScheme;

  ShadTextTheme get textTheme => ShadTheme.of(this).textTheme;

  Brightness get brightness => ShadTheme.of(this).brightness;

  IconThemeData get iconTheme => IconTheme.of(this);

  BorderRadius get radius => ShadTheme.of(this).radius;

  ChatThemeTokens get chatTheme =>
      Theme.of(this).extension<ChatThemeTokens>() ??
      AppTheme.tokens(brightness: Theme.of(this).brightness);

  AxiSpacing get spacing =>
      Theme.of(this).extension<AxiSpacing>() ?? axiSpacing;

  AxiSizing get sizing => Theme.of(this).extension<AxiSizing>() ?? axiSizing;

  AxiMotion get motion => Theme.of(this).extension<AxiMotion>() ?? axiMotion;

  AxiBorders get borders =>
      Theme.of(this).extension<AxiBorders>() ?? axiBorders;

  AxiRadii get radii => Theme.of(this).extension<AxiRadii>() ?? axiRadii;

  BorderSide get borderSide => BorderSide(
        color: colorScheme.border,
        width: borders.width,
      );
}

extension TargetPlatformExtension on TargetPlatform {
  bool get isApple =>
      this == TargetPlatform.macOS || this == TargetPlatform.iOS;

  bool get isMobile =>
      this == TargetPlatform.android || this == TargetPlatform.iOS;
}

class ComposeIntent extends Intent {
  const ComposeIntent();
}

class ToggleSearchIntent extends Intent {
  const ToggleSearchIntent();
}

class ToggleCalendarIntent extends Intent {
  const ToggleCalendarIntent();
}

class OpenFindActionIntent extends Intent {
  const OpenFindActionIntent();
}

class _ShortcutBindings extends StatelessWidget {
  const _ShortcutBindings({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }
    final env = EnvScope.of(context);
    final routedChild = Actions(
      actions: {
        ComposeIntent: CallbackAction<ComposeIntent>(
          onInvoke: (_) {
            openComposeDraft(context, attachmentMetadataIds: const <String>[]);
            return null;
          },
        ),
      },
      child: child,
    );
    final shortcuts = <ShortcutActivator, Intent>{
      _composeActivator(env.platform): const ComposeIntent(),
    };
    return Shortcuts(shortcuts: shortcuts, child: routedChild);
  }
}

class _DesktopMenuShell extends StatelessWidget {
  const _DesktopMenuShell({required this.actionsEnabled, required this.child});

  final bool actionsEnabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final env = EnvScope.maybeOf(context);
    if (!actionsEnabled || env == null || !env.usesDesktopMenu) {
      return child;
    }
    final composeShortcut = _composeActivator(env.platform);
    final searchShortcut = _searchActivator(env.platform);
    final calendarShortcut =
        env.supportsDesktopShortcuts ? _calendarActivator(env.platform) : null;

    // Keep shortcuts wired but hide the overlay/platform menu chrome to avoid clutter.
    return _ShortcutHintProvider(
      composeShortcut: composeShortcut,
      searchShortcut: searchShortcut,
      calendarShortcut: calendarShortcut,
      child: child,
    );
  }
}

class _ShortcutHintProvider extends InheritedWidget {
  const _ShortcutHintProvider({
    required this.composeShortcut,
    required this.searchShortcut,
    required super.child,
    this.calendarShortcut,
  });

  final MenuSerializableShortcut composeShortcut;
  final MenuSerializableShortcut searchShortcut;
  final MenuSerializableShortcut? calendarShortcut;

  @override
  bool updateShouldNotify(covariant _ShortcutHintProvider oldWidget) {
    return composeShortcut != oldWidget.composeShortcut ||
        searchShortcut != oldWidget.searchShortcut ||
        calendarShortcut != oldWidget.calendarShortcut;
  }
}

SingleActivator _composeActivator(TargetPlatform platform) {
  return SingleActivator(
    LogicalKeyboardKey.keyN,
    meta: platform.isApple,
    control: !platform.isApple,
  );
}

SingleActivator _searchActivator(TargetPlatform platform) {
  return SingleActivator(
    LogicalKeyboardKey.keyF,
    meta: platform.isApple,
    control: !platform.isApple,
  );
}

SingleActivator _calendarActivator(TargetPlatform platform) {
  return SingleActivator(
    LogicalKeyboardKey.keyC,
    meta: platform.isApple,
    control: !platform.isApple,
    shift: true,
  );
}

class AxiDragScrollBehavior extends MaterialScrollBehavior {
  const AxiDragScrollBehavior();

  static const _touchDragDevices = <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };

  static const _mobileDragDevices = <PointerDeviceKind>{
    ..._touchDragDevices,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };

  @override
  Set<PointerDeviceKind> get dragDevices => defaultTargetPlatform.isMobile
      ? _mobileDragDevices
      : const <PointerDeviceKind>{};
}

SystemUiOverlayStyle _systemUiOverlayStyleFor(ThemeData theme) {
  final isDark = theme.brightness == Brightness.dark;
  final baseStyle =
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
  final iconBrightness = isDark ? Brightness.light : Brightness.dark;
  return baseStyle.copyWith(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: iconBrightness,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: iconBrightness,
    systemNavigationBarDividerColor: Colors.transparent,
  );
}
