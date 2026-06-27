// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:convert';
import 'dart:ui' show AppExitResponse;

import 'package:axichat/main.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/guest/guest_calendar_bloc.dart';
import 'package:axichat/src/calendar/reminders/calendar_reminder_controller.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/calendar/view/shell/calendar_task_off_grid_drag_controller.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/fire_and_forget.dart';
import 'package:axichat/src/common/foreground_runtime_controller.dart';
import 'package:axichat/src/common/foreground_task_messages.dart';
import 'package:axichat/src/common/network_availability.dart';
import 'package:axichat/src/common/policy.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:axichat/src/draft/bloc/compose_window_cubit.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/view/compose_launcher.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/notifications/bloc/notification_request_cubit.dart';
import 'package:axichat/src/notifications/notification_payload.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:axichat/src/omemo_activity/bloc/omemo_activity_cubit.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/routes.dart';
import 'package:axichat/src/settings/app_language.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/share/bloc/share_intent_cubit.dart';
import 'package:axichat/src/share/share_handoff.dart';
import 'package:axichat/src/share/system_share_target_service.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/app_storage.dart';
import 'package:axichat/src/storage/hive_extensions.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/state_store.dart';
import 'package:axichat/src/update/bloc/update_cubit.dart';
import 'package:axichat/src/update/update_service.dart';
import 'package:axichat/src/update/view/update_prompt.dart';
import 'package:axichat/src/xmpp/connection/foreground_socket.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:axichat/src/xmpp_activity/bloc/xmpp_activity_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'localization/app_localizations.dart';

class Axichat extends StatefulWidget {
  Axichat({
    super.key,
    XmppService? xmppService,
    NotificationService? notificationService,
    Capability? capability,
    Policy? policy,
    required CalendarStorageManager storageManager,
  }) : _xmppService = xmppService,
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
  String? _pendingAuthCalendarAccountJid;

  @override
  void initState() {
    super.initState();
    _xmppService =
        widget._xmppService ??
        XmppService(
          buildConnection: () => withForeground
              ? XmppConnection(socketWrapper: ForegroundSocketWrapper())
              : XmppConnection(),
          buildStateStore: (prefix, passphrase) async {
            final Logger logger = Logger('XmppStateStore');
            final hiveDirectory = await prepareAppStorageSubdirectory(prefix);
            final storageRootDirectory = await prepareAppStorageDirectory();
            Hive.init(hiveDirectory.path);
            if (!Hive.isAdapterRegistered(1)) {
              Hive.registerAdapter(PresenceAdapter());
            }
            await Hive.openBoxWithRetry(
              XmppStateStore.boxName,
              encryptionCipher: HiveAesCipher(utf8.encode(passphrase)),
              logger: logger,
            );
            final accountJid =
                _pendingAuthCalendarAccountJid ?? _xmppService.myJid;
            if (accountJid == null || accountJid.trim().isEmpty) {
              throw StateError(
                'Authenticated calendar storage requires an account address.',
              );
            }
            await widget._storageManager.ensureAuthStorage(
              accountAddress: accountJid,
              passphrase: passphrase,
              storageRootPath: storageRootDirectory.path,
            );
            if (accountJid == _pendingAuthCalendarAccountJid) {
              _pendingAuthCalendarAccountJid = null;
            }
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
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        ChangeNotifierProvider<CalendarStorageManager>(
          create: (context) => widget._storageManager,
        ),
        ChangeNotifierProvider<CalendarTaskOffGridDragController>(
          create: (context) => CalendarTaskOffGridDragController(),
        ),
        RepositoryProvider<XmppService>.value(value: _xmppService),
        RepositoryProvider<MessageService>(
          create: (context) => context.read<XmppService>(),
        ),
        RepositoryProvider.value(value: widget._notificationService),
        RepositoryProvider.value(value: widget._capability),
        RepositoryProvider.value(value: widget._policy),
        RepositoryProvider.value(value: _reminderController),
        RepositoryProvider<SystemShareTargetService>(
          create: (context) => SystemShareTargetService(),
        ),
        RepositoryProvider<ShareComposerSeedQueue>(
          create: (context) => ShareComposerSeedQueue(),
          dispose: (queue) => queue.dispose(),
        ),
        RepositoryProvider<CredentialStore>(
          create: (context) => CredentialStore(
            capability: context.read<Capability>(),
            policy: context.read<Policy>(),
          ),
        ),
        RepositoryProvider<http.Client>(
          create: (context) => http.Client(),
          dispose: (client) => client.close(),
        ),
      ],
      child: BlocProvider(
        create: (context) {
          final settingsCubit = SettingsCubit(
            xmppService: _xmppService,
            capability: widget._capability,
            credentialStore: context.read<CredentialStore>(),
          )..primeAttachmentAutoDownloadSettings();
          final settings = settingsCubit.state;
          context.read<NotificationService>().updateRuntimeSettings(
            chatNotificationsMuted: settings.chatNotificationsMuted,
            emailNotificationsMuted: settings.emailNotificationsMuted,
            notificationPreviewsEnabled: settings.notificationPreviewsEnabled,
          );
          _xmppService.updateForegroundNotificationSettings(
            chatNotificationsMuted: settings.chatNotificationsMuted,
            emailNotificationsMuted: settings.emailNotificationsMuted,
            notificationPreviewsEnabled: settings.notificationPreviewsEnabled,
          );
          return settingsCubit;
        },
        child: Builder(
          builder: (context) {
            return RepositoryProvider<EmailService>(
              create: (context) {
                final settingsState = context.read<SettingsCubit>().state;
                return EmailService(
                  credentialStore: context.read<CredentialStore>(),
                  databaseBuilder: () => context.read<XmppService>().database,
                  notificationService: context.read<NotificationService>(),
                  endpointConfig: settingsState.endpointConfig,
                  emailReadReceiptsEnabled: settingsState.emailReadReceipts,
                  emailEncryptionBetaEnabledByAddress:
                      settingsState.emailEncryptionBetaEnabledByAddress,
                  xmppSelfJidProvider: () => _xmppService.myJid,
                  mailPushHints: _xmppService.mailPushHintStream,
                );
              },
              child: RepositoryProvider<ForegroundRuntimeController>(
                create: (context) => ForegroundRuntimeController(
                  capability: context.read<Capability>(),
                  notificationService: context.read<NotificationService>(),
                  xmppService: context.read<XmppService>(),
                  emailService: context.read<EmailService>(),
                ),
                child: MultiBlocProvider(
                  providers: [
                    BlocProvider(
                      create: (context) => UpdateCubit(
                        updateService: UpdateService(
                          httpClient: context.read<http.Client>(),
                        ),
                      )..initialize(),
                    ),
                    BlocProvider(
                      create: (context) => NotificationRequestCubit(
                        notificationService: context
                            .read<NotificationService>(),
                        foregroundRuntimeController: context
                            .read<ForegroundRuntimeController>(),
                      )..refreshPermissions(),
                    ),
                    BlocProvider(
                      create: (context) => AuthenticationCubit(
                        credentialStore: context.read<CredentialStore>(),
                        xmppService: context.read<XmppService>(),
                        emailService: context.read<EmailService>(),
                        foregroundRuntimeController: context
                            .read<ForegroundRuntimeController>(),
                        initialEndpointConfig: context
                            .read<SettingsCubit>()
                            .state
                            .endpointConfig,
                        beforeStickyReconnect: () async {
                          await context
                              .read<ForegroundRuntimeController>()
                              .restoreIfPreferred(
                                desired: context
                                    .read<SettingsCubit>()
                                    .state
                                    .backgroundMessagingEnabled,
                              );
                        },
                        beforeXmppConnect: (accountJid) async {
                          _pendingAuthCalendarAccountJid = accountJid;
                          final settingsCubit = context.read<SettingsCubit>();
                          await context
                              .read<ForegroundRuntimeController>()
                              .prepareForNextXmppConnection(
                                desired: await settingsCubit
                                    .backgroundMessagingEnabledForAccount(
                                      accountJid,
                                    ),
                              );
                        },
                      ),
                    ),
                    BlocProvider(
                      create: (context) => OmemoActivityCubit(
                        xmppBase: context.read<XmppService>(),
                      ),
                    ),
                    BlocProvider(
                      create: (context) => XmppActivityCubit(
                        xmppBase: context.read<XmppService>(),
                      ),
                    ),
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
                        emailService:
                            context
                                .read<SettingsCubit>()
                                .state
                                .endpointConfig
                                .smtpEnabled
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
                        emailService:
                            context
                                .read<SettingsCubit>()
                                .state
                                .endpointConfig
                                .smtpEnabled
                            ? context.read<EmailService>()
                            : null,
                      ),
                    ),
                    BlocProvider(
                      create: (context) {
                        final endpointConfig = context
                            .read<SettingsCubit>()
                            .state
                            .endpointConfig;
                        final emailEnabled = endpointConfig.smtpEnabled;
                        return ConnectivityCubit(
                          xmppBase: context.read<XmppService>(),
                          emailEnabled: emailEnabled,
                          emailService: emailEnabled
                              ? context.read<EmailService>()
                              : null,
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
                          final authenticationCubit = context
                              .read<AuthenticationCubit>();
                          final chatsCubit = context.read<ChatsCubit>();
                          final draftCubit = context.read<DraftCubit>();
                          final connectivityCubit = context
                              .read<ConnectivityCubit>();
                          final emailService = context.read<EmailService>();
                          final foregroundRuntimeController = context
                              .read<ForegroundRuntimeController>();
                          final EmailService? activeEmailService =
                              config.smtpEnabled ? emailService : null;
                          authenticationCubit.updateEndpointConfig(config);
                          await authenticationCubit.updateEmailService(
                            activeEmailService,
                          );
                          if (!context.mounted) return;
                          chatsCubit.updateEmailService(activeEmailService);
                          draftCubit.updateEmailService(activeEmailService);
                          emailService.updateEndpointConfig(config);
                          connectivityCubit.updateEmailContext(
                            emailEnabled: config.smtpEnabled,
                            emailService: activeEmailService,
                          );
                          if (!config.smtpEnabled) {
                            await emailService.shutdown(
                              clearCredentials: false,
                            );
                            await emailService.handleNetworkLost();
                          } else {
                            await emailService.handleNetworkAvailable();
                          }
                          if (authenticationCubit.state
                              is AuthenticationComplete) {
                            await foregroundRuntimeController
                                .restoreIfPreferred(
                                  desired: settings.backgroundMessagingEnabled,
                                );
                          } else {
                            await foregroundRuntimeController
                                .prepareForNextXmppConnection(
                                  desired: settings.backgroundMessagingEnabled,
                                );
                          }
                        },
                      ),
                      BlocListener<SettingsCubit, SettingsState>(
                        listenWhen: (previous, current) =>
                            previous.emailEncryptionBetaEnabledByAddress !=
                            current.emailEncryptionBetaEnabledByAddress,
                        listener: (context, settings) {
                          context
                              .read<EmailService>()
                              .updateEmailEncryptionBetaSettings(
                                settings.emailEncryptionBetaEnabledByAddress,
                              );
                        },
                      ),
                      BlocListener<SettingsCubit, SettingsState>(
                        listenWhen: (previous, current) =>
                            previous.emailReadReceipts !=
                            current.emailReadReceipts,
                        listener: (context, settings) async {
                          await context
                              .read<EmailService>()
                              .updateEmailReadReceiptsEnabled(
                                settings.emailReadReceipts,
                              );
                        },
                      ),
                    ],
                    child: const MaterialAxichat(),
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
  static final Logger _exitLogger = Logger('AppExit');
  static const Duration _exitCleanupTimeout = Duration(seconds: 8);

  bool _shareIntentAwaitingRoute = false;
  bool _notificationIntentHandling = false;
  bool _notificationIntentAwaitingRoute = false;
  Timer? _pendingAuthNavigation;
  StreamSubscription<String?>? _notificationTapSubscription;
  Future<void>? _exitCleanupFuture;
  AuthenticationState? _lastAuthState;
  ({String? payload})? _pendingNotificationIntent;
  String? _pendingNotificationChatJid;
  bool _checkedInitialNotificationLaunchDetails = false;
  late final AppLifecycleListener _lifecycleListener = AppLifecycleListener(
    onResume: _handleLifecycleResume,
    onShow: _handleLifecycleResume,
    onRestart: _handleLifecycleResume,
    onExitRequested: _handleExitRequested,
  );

  late final GoRouter _router = GoRouter(
    restorationScopeId: 'app',
    redirect: (context, routerState) {
      if (context.read<AuthenticationCubit>().state
          is! AuthenticationComplete) {
        // Check if the current route allows guest access
        final location = resolveRouteLocation(routerState.matchedLocation);
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
    _lifecycleListener;
    _router.routerDelegate.addListener(_handleRouteChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notificationTapSubscription ??= context
        .read<NotificationService>()
        .notificationTapPayloads
        .listen(_handleNotificationTapPayload);
    final profileState = context.read<ProfileCubit>().state;
    context.read<SettingsCubit>().trackDonationPromptMessageCount(
      accountJid: profileState.jid,
      storedConversationMessageCount:
          profileState.storedConversationMessageCount,
    );
    _syncSystemShareTargets(context, null);
  }

  @override
  void dispose() {
    _pendingAuthNavigation?.cancel();
    _pendingAuthNavigation = null;
    final notificationTapSubscription = _notificationTapSubscription;
    _notificationTapSubscription = null;
    if (notificationTapSubscription != null) {
      unawaited(notificationTapSubscription.cancel());
    }
    _lifecycleListener.dispose();
    _router.routerDelegate.removeListener(_handleRouteChange);
    _router.dispose();
    super.dispose();
  }

  Future<void> _restoreForegroundRuntimeIfPreferredForContext(
    BuildContext context,
  ) async {
    final locate = context.read;
    await locate<ForegroundRuntimeController>().restoreIfPreferred(
      desired: locate<SettingsCubit>().state.backgroundMessagingEnabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsState>(
      listener: (context, state) {
        context.read<NotificationService>().updateRuntimeSettings(
          chatNotificationsMuted: state.chatNotificationsMuted,
          emailNotificationsMuted: state.emailNotificationsMuted,
          notificationPreviewsEnabled: state.notificationPreviewsEnabled,
        );
        context.read<XmppService>().updateForegroundNotificationSettings(
          chatNotificationsMuted: state.chatNotificationsMuted,
          emailNotificationsMuted: state.emailNotificationsMuted,
          notificationPreviewsEnabled: state.notificationPreviewsEnabled,
        );
      },
      builder: (context, state) {
        final localeOverride = state.language.locale;
        const chatNeutrals = ChatNeutrals();
        final lightTheme = AppTheme.build(
          shadColor: state.shadColor,
          brightness: Brightness.light,
          platform: defaultTargetPlatform,
          neutrals: chatNeutrals,
        );
        final darkTheme = AppTheme.build(
          shadColor: state.shadColor,
          brightness: Brightness.dark,
          platform: defaultTargetPlatform,
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
            final bool useAppleSystemTypography = theme.platform.isApple;
            final shadTheme = theme.brightness == Brightness.light
                ? lightTheme
                : darkTheme;
            final chatTokens = AppTheme.tokens(
              brightness: theme.brightness,
              neutrals: chatNeutrals,
            );
            final materialColors = shadTheme.colorScheme;
            final globalRadius = shadTheme.radius;
            final buttonShape = SquircleBorder(cornerRadius: axiSquircleRadius);
            final listTileShape = buttonShape;
            final outlineInputBorder = OutlineInputBorder(
              borderRadius: globalRadius,
              borderSide: BorderSide(
                color: materialColors.border,
                width: axiBorders.width,
              ),
            );
            final focusedInputBorder = outlineInputBorder.copyWith(
              borderSide: BorderSide(
                color: materialColors.primary,
                width: axiBorders.width,
              ),
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
            final TextTheme baseTextTheme = TextTheme(
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
            );
            final textThemeWithEmojiFallback = useAppleSystemTypography
                ? baseTextTheme
                : baseTextTheme.apply(
                    fontFamily: interFontFamily,
                    fontFamilyFallback: interFontFallback,
                  );
            final appBarTitleStyle = useAppleSystemTypography
                ? shadTheme.textTheme.h3.copyWith(
                    color: materialColors.foreground,
                    fontWeight: appBarTitleFontWeight,
                  )
                : shadTheme.textTheme.h3.copyWith(
                    fontFamily: interFontFamily,
                    fontFamilyFallback: interFontFallback,
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
                    width: axiBorders.width,
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
                  side: BorderSide(
                    color: materialColors.border,
                    width: axiBorders.width,
                  ),
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
                  color: materialColors.border,
                  width: axiSpaceXxs,
                ),
              ),
              scrollbarTheme: ScrollbarThemeData(
                thickness: const WidgetStatePropertyAll<double>(axiSpaceXs),
                radius: const Radius.circular(999),
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  final hovered =
                      states.contains(WidgetState.hovered) ||
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
                axiBorders,
                axiRadii,
                axiSpacing,
                axiSizing,
                axiMotion,
              ],
            );
          },
          routerConfig: _router,
          builder: (context, child) {
            final notificationStrings = AppLocalizations.of(
              context,
            )!.toNotificationStrings();
            context.read<NotificationService>().updateLocalizations(
              notificationStrings,
            );
            context.read<XmppService>().updateLocalizations(
              AppLocalizations.of(context)!,
            );
            context.read<XmppService>().updateForegroundNotificationStrings(
              notificationStrings.toForegroundNotificationStrings(),
            );
            context.read<CalendarReminderController>().updateLocalizations(
              AppLocalizations.of(context)!,
            );
            final endpointConfig = context
                .read<SettingsCubit>()
                .state
                .endpointConfig;
            if (endpointConfig.smtpEnabled) {
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
                BlocListener<ProfileCubit, ProfileState>(
                  listenWhen: (previous, current) =>
                      previous.jid != current.jid ||
                      previous.storedConversationMessageCount !=
                          current.storedConversationMessageCount,
                  listener: (context, state) {
                    context
                        .read<SettingsCubit>()
                        .trackDonationPromptMessageCount(
                          accountJid: state.jid,
                          storedConversationMessageCount:
                              state.storedConversationMessageCount,
                        );
                  },
                ),
                BlocListener<ConnectivityCubit, ConnectivityState>(
                  listenWhen: (previous, current) =>
                      previous is! ConnectivityConnected &&
                      current is ConnectivityConnected,
                  listener: (context, _) {
                    context.read<UpdateCubit>().refresh();
                  },
                ),
                BlocListener<ConnectivityCubit, ConnectivityState>(
                  listenWhen: (previous, current) =>
                      previous.networkAvailability !=
                      current.networkAvailability,
                  listener: (context, state) {
                    if (!state.demoOffline &&
                        state.networkAvailability.isAvailable) {
                      final xmppService = context.read<XmppService>();
                      fireAndForget(
                        () => xmppService.requestReconnect(
                          ReconnectTrigger.networkAvailable,
                        ),
                        operationName: 'App.xmppNetworkAvailable',
                      );
                    }
                    if (!state.emailEnabled) return;
                    final emailService = context.read<EmailService>();
                    if (state.networkAvailability.isAvailable) {
                      fireAndForget(
                        emailService.handleNetworkAvailable,
                        operationName: 'App.emailNetworkAvailable',
                      );
                    }
                  },
                ),
                BlocListener<ChatsCubit, ChatsState>(
                  listenWhen: (previous, current) =>
                      !listEquals(previous.items, current.items),
                  listener: _syncSystemShareTargets,
                ),
                BlocListener<SettingsCubit, SettingsState>(
                  listenWhen: (previous, current) =>
                      previous.endpointConfig.smtpEnabled !=
                      current.endpointConfig.smtpEnabled,
                  listener: _syncSystemShareTargets,
                ),
                BlocListener<AuthenticationCubit, AuthenticationState>(
                  listener: (context, state) async {
                    final locate = context.read;
                    final profileCubit = locate<ProfileCubit>();
                    final settingsCubit = locate<SettingsCubit>();
                    final previousAuthState = _lastAuthState;
                    _lastAuthState = state;
                    final currentLocation =
                        _router.routeInformationProvider.value.uri.path;
                    final matchList =
                        _router.routerDelegate.currentConfiguration;
                    final matchedLocation = matchList.matches.isEmpty
                        ? null
                        : matchList.uri.path;
                    final currentRoute = resolveRouteLocation(currentLocation);
                    final matchedRoute = matchedLocation == null
                        ? null
                        : resolveRouteLocation(matchedLocation);
                    final effectiveRoute = currentRoute ?? matchedRoute;
                    final authRequired =
                        effectiveRoute?.authenticationRequired ?? true;
                    final onLoginRoute =
                        currentLocation == const LoginRoute().location ||
                        matchedLocation == const LoginRoute().location;
                    final onGuestRoute = onLoginRoute || !authRequired;
                    final authCompletionDuration =
                        settingsCubit.authCompletionDuration;
                    _syncSystemShareTargets(context, state);
                    if (state is AuthenticationNone) {
                      _pendingAuthNavigation?.cancel();
                      _pendingAuthNavigation = null;
                      profileCubit.clearSessionIdentity();
                      await settingsCubit.activateAccountSettings(null);
                      if (!context.mounted) {
                        return;
                      }
                      if (!onLoginRoute && authRequired) {
                        _router.go(const LoginRoute().location);
                      }
                    } else {
                      if (state is AuthenticationComplete &&
                          previousAuthState is! AuthenticationComplete) {
                        profileCubit.syncSessionIdentity();
                        if (onGuestRoute) {
                          _pendingAuthNavigation?.cancel();
                          _pendingAuthNavigation = null;
                          void navigateHome() {
                            final latestAuthState = _lastAuthState;
                            if (latestAuthState is! AuthenticationComplete) {
                              return;
                            }
                            final currentMatchList =
                                _router.routerDelegate.currentConfiguration;
                            final currentMatchedLocation =
                                currentMatchList.matches.isEmpty
                                ? null
                                : currentMatchList.uri.path;
                            if (currentMatchedLocation ==
                                const HomeRoute().location) {
                              _pendingAuthNavigation = null;
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
                        await settingsCubit.activateAccountSettings(
                          locate<XmppService>().myJid,
                        );
                        if (!context.mounted) {
                          return;
                        }
                        await _restoreForegroundRuntimeIfPreferredForContext(
                          context,
                        );
                        if (!context.mounted) {
                          return;
                        }
                      }
                    }
                    await _handleNotificationIntent();
                    _handleShareIntent();
                  },
                ),
                BlocListener<ShareIntentCubit, ShareIntentState>(
                  listener: (context, _) {
                    _handleShareIntent();
                  },
                ),
              ],
              child: child ?? const SizedBox.shrink(),
            );
            final authComplete = context.select<AuthenticationCubit, bool>(
              (cubit) => cubit.state is AuthenticationComplete,
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
            content = UpdatePromptOverlay(
              canPresentPrompt: _canPresentUpdatePrompt(
                authComplete: authComplete,
              ),
              child: content,
            );
            return content;
          },
        );

        return ScaffoldMessenger(child: app);
      },
    );
  }

  void _handleLifecycleResume() {
    context.read<UpdateCubit>().refresh();
    fireAndForget(
      () => context.read<NotificationRequestCubit>().handleLifecycleResume(),
      operationName: 'NotificationRequestCubit.handleLifecycleResume',
    );
    _syncSystemShareTargets(context, null);
    _handleNotificationIntent();
    _handleShareIntent();
  }

  // Desktop exit requests do not wait for normal widget disposal. Use the
  // platform exit hook to shut down network and storage services explicitly.
  Future<AppExitResponse> _handleExitRequested() async {
    _exitCleanupFuture ??= _runExitCleanup();
    try {
      await _exitCleanupFuture!.timeout(_exitCleanupTimeout);
    } on TimeoutException catch (error, stackTrace) {
      _exitLogger.warning(
        'Timed out while preparing app exit; allowing termination.',
        error,
        stackTrace,
      );
    }
    return AppExitResponse.exit;
  }

  Future<void> _runExitCleanup() async {
    if (!mounted) return;

    await _runExitStep('prepare authentication for exit', () {
      return context.read<AuthenticationCubit>().prepareForAppExit();
    });
    await _runExitStep('stop email runtime', () {
      return context.read<EmailService>().close();
    });
    await _runExitStep('close XMPP runtime', () {
      return context.read<XmppService>().close();
    });
    await _runExitStep('close credential store', () {
      return context.read<CredentialStore>().close();
    });
    await _runExitStep('stop network availability listener', () {
      return NetworkAvailabilityService.instance.stop();
    });
  }

  Future<void> _runExitStep(
    String label,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on Object catch (error, stackTrace) {
      _exitLogger.warning('Failed to $label.', error, stackTrace);
    }
  }

  Future<void> _handleNotificationIntent() async {
    if (!mounted || _notificationIntentHandling) return;
    _notificationIntentHandling = true;
    try {
      final launchIntent = _pendingNotificationIntent == null
          ? await _takePendingNotificationIntent()
          : null;
      _pendingNotificationIntent ??= launchIntent;
      if (!mounted) {
        return;
      }
      if (context.read<AuthenticationCubit>().state
          is! AuthenticationComplete) {
        return;
      }
      final xmppService = context.read<XmppService>();
      final chatsCubit = context.read<ChatsCubit>();
      final intent = _pendingNotificationIntent;
      if (intent != null) {
        final payload = intent.payload;
        _pendingNotificationIntent = null;
        if (payload == null) {
          _pendingNotificationChatJid = null;
          _refreshEmailForNotificationWake();
          await _routeHomeForNotificationIntent();
          return;
        }
        if (const NotificationPayloadCodec().isEmailInboxPayload(payload)) {
          _pendingNotificationChatJid = null;
          _refreshEmailForNotificationWake();
          await _routeHomeForNotificationIntent();
          return;
        }
        final String? chatJid = await xmppService.resolveNotificationPayload(
          payload,
        );
        if (chatJid != null) {
          _pendingNotificationChatJid = chatJid;
        } else {
          _pendingNotificationChatJid = null;
          _refreshEmailForNotificationWake();
          await _routeHomeForNotificationIntent();
          return;
        }
      }
      final pendingJid = _pendingNotificationChatJid;
      if (pendingJid == null) {
        _notificationIntentAwaitingRoute = false;
        return;
      }
      if (!_isOnHomeRoute()) {
        _notificationIntentAwaitingRoute = true;
        _router.go(const HomeRoute().location);
        await Future<void>.delayed(Duration.zero);
        if (!mounted || !_isOnHomeRoute()) {
          return;
        }
      }
      _notificationIntentAwaitingRoute = false;
      await chatsCubit.openChat(jid: pendingJid);
      if (_pendingNotificationChatJid == pendingJid) {
        _pendingNotificationChatJid = null;
      }
    } finally {
      _notificationIntentHandling = false;
      if (mounted &&
          _pendingNotificationIntent != null &&
          context.read<AuthenticationCubit>().state is AuthenticationComplete) {
        scheduleMicrotask(_handleNotificationIntent);
      }
    }
  }

  Future<bool> _routeHomeForNotificationIntent() async {
    if (_isOnHomeRoute()) {
      _notificationIntentAwaitingRoute = false;
      return true;
    }
    _notificationIntentAwaitingRoute = true;
    _router.go(const HomeRoute().location);
    await Future<void>.delayed(Duration.zero);
    if (!mounted || !_isOnHomeRoute()) {
      return false;
    }
    _notificationIntentAwaitingRoute = false;
    return true;
  }

  void _refreshEmailForNotificationWake() {
    fireAndForget(
      context.read<EmailService>().handleForegroundResumeNetworkAvailable,
      operationName: 'MaterialAxichat.notificationWakeEmailRefresh',
    );
  }

  void _handleNotificationTapPayload(String? payload) {
    if (!mounted) return;
    clearLaunchedNotification();
    _pendingNotificationIntent = (
      payload: _normalizedNotificationPayload(payload),
    );
    _pendingNotificationChatJid = null;
    _handleNotificationIntent();
  }

  String? _normalizedNotificationPayload(String? payload) {
    final normalized = payload?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  Future<({String? payload})?> _takePendingNotificationIntent() async {
    if (launchedFromNotification) {
      return (
        payload: _normalizedNotificationPayload(
          takeLaunchedNotificationPayload(),
        ),
      );
    }
    if (_checkedInitialNotificationLaunchDetails) {
      return null;
    }
    _checkedInitialNotificationLaunchDetails = true;
    final launchDetails = await context
        .read<NotificationService>()
        .getAppNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp != true) {
      return null;
    }
    final payload = launchDetails?.notificationResponse?.payload;
    return (payload: _normalizedNotificationPayload(payload));
  }

  void _handleShareIntent() {
    if (!mounted) return;
    if (context.read<ShareIntentCubit>().state.hasPayload != true) {
      _shareIntentAwaitingRoute = false;
      return;
    }
    if (context.read<AuthenticationCubit>().state is! AuthenticationComplete) {
      _shareIntentAwaitingRoute = false;
      return;
    }
    if (_isOnHomeRoute()) {
      _shareIntentAwaitingRoute = false;
      return;
    }
    if (_shareIntentAwaitingRoute) {
      return;
    }
    _shareIntentAwaitingRoute = true;
    _router.go(const HomeRoute().location);
  }

  void _syncSystemShareTargets(BuildContext context, Object? _) {
    final locate = context.read;
    final shareTargetService = locate<SystemShareTargetService>();
    if (locate<AuthenticationCubit>().state is! AuthenticationComplete) {
      fireAndForget(
        shareTargetService.clearShareTargets,
        operationName: 'MaterialAxichat.clearSystemShareTargets',
        loggerName: 'MaterialAxichat',
      );
      return;
    }
    final chats = locate<ChatsCubit>().state.items;
    if (chats == null) {
      return;
    }
    final smtpEnabled =
        locate<SettingsCubit>().state.endpointConfig.smtpEnabled;
    final xmppService = locate<XmppService>();
    fireAndForget(
      () => shareTargetService.publishTargets(
        chats: List<Chat>.unmodifiable(chats),
        smtpEnabled: smtpEnabled,
        loadAvatarBytes: (path) =>
            xmppService.resolveSafeAvatarBytes(avatarPath: path),
      ),
      operationName: 'MaterialAxichat.publishSystemShareTargets',
      loggerName: 'MaterialAxichat',
    );
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

  bool _canPresentUpdatePrompt({required bool authComplete}) {
    if (!authComplete) {
      return false;
    }
    final currentLocation = _router.routeInformationProvider.value.uri.path;
    final matchedLocation = _router.state.matchedLocation;
    final currentRoute = resolveRouteLocation(currentLocation);
    final matchedRoute = matchedLocation.isEmpty
        ? null
        : resolveRouteLocation(matchedLocation);
    final effectiveRoute = currentRoute ?? matchedRoute;
    return effectiveRoute?.authenticationRequired ?? true;
  }

  void _handleRouteChange() {
    if (!mounted) return;
    if (_notificationIntentAwaitingRoute && _isOnHomeRoute()) {
      if (_notificationIntentHandling) {
        return;
      }
      _handleNotificationIntent();
    }
    if (!_shareIntentAwaitingRoute || !_isOnHomeRoute()) {
      return;
    }
    _shareIntentAwaitingRoute = false;
  }
}

extension ThemeExtension on BuildContext {
  ShadColorScheme get colorScheme => ShadTheme.of(this).colorScheme;

  ShadTextTheme get textTheme => ShadTheme.of(this).textTheme;

  Brightness get brightness => ShadTheme.of(this).brightness;

  IconThemeData get iconTheme => IconTheme.of(this);

  BorderRadius get radius => BorderRadius.circular(radii.container);

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

  BorderSide get borderSide =>
      BorderSide(color: colorScheme.border, width: borders.width);
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
    final calendarShortcut = env.supportsDesktopShortcuts
        ? _calendarActivator(env.platform)
        : null;

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

  @override
  Set<PointerDeviceKind> get dragDevices => defaultTargetPlatform.isMobile
      ? <PointerDeviceKind>{...super.dragDevices, PointerDeviceKind.mouse}
      : super.dragDevices;
}

SystemUiOverlayStyle _systemUiOverlayStyleFor(ThemeData theme) {
  final isDark = theme.brightness == Brightness.dark;
  final baseStyle = isDark
      ? SystemUiOverlayStyle.light
      : SystemUiOverlayStyle.dark;
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
