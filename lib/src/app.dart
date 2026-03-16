// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:convert';

import 'package:axichat/main.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/guest/guest_calendar_bloc.dart';
import 'package:axichat/src/calendar/reminders/calendar_reminder_controller.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/foreground_task_messages.dart';
import 'package:axichat/src/common/policy.dart';
import 'package:axichat/src/common/ui/app_theme.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:axichat/src/draft/bloc/compose_window_cubit.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/view/compose_launcher.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/home/service/home_refresh_sync_service.dart';
import 'package:axichat/src/notifications/notification_service.dart';
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

  @override
  void initState() {
    super.initState();
    _xmppService =
        widget._xmppService ??
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
  }

  @override
  void dispose() {
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
        RepositoryProvider<http.Client>(
          create: (context) => http.Client(),
          dispose: (client) => client.close(),
        ),
      ],
      child: BlocProvider(
        create: (context) => SettingsCubit(
          xmppService: _xmppService,
          capability: widget._capability,
        )..primeAttachmentAutoDownloadSettings(),
        child: Builder(
          builder: (context) {
            return MultiRepositoryProvider(
              providers: [
                RepositoryProvider<EmailService>(
                  create: (context) => EmailService(
                    credentialStore: context.read<CredentialStore>(),
                    databaseBuilder: () => context.read<XmppService>().database,
                    notificationService: context.read<NotificationService>(),
                    messageService: context.read<MessageService>(),
                    emailReadReceiptsEnabled: context
                        .read<SettingsCubit>()
                        .state
                        .emailReadReceipts,
                  ),
                ),
                RepositoryProvider<HomeRefreshSyncService>(
                  create: (context) => HomeRefreshSyncService(
                    xmppService: context.read<XmppService>(),
                    emailService:
                        context
                            .read<SettingsCubit>()
                            .state
                            .endpointConfig
                            .smtpEnabled
                        ? context.read<EmailService>()
                        : null,
                  )..start(),
                ),
              ],
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
                    create: (context) => AuthenticationCubit(
                      credentialStore: context.read<CredentialStore>(),
                      xmppService: context.read<XmppService>(),
                      emailService: context.read<EmailService>(),
                      homeRefreshSyncService: context
                          .read<HomeRefreshSyncService>(),
                      initialEndpointConfig: context
                          .read<SettingsCubit>()
                          .state
                          .endpointConfig,
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
                      homeRefreshSyncService: context
                          .read<HomeRefreshSyncService>(),
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
                        final emailService = context.read<EmailService>();
                        final EmailService? activeEmailService =
                            config.smtpEnabled ? emailService : null;
                        context
                            .read<AuthenticationCubit>()
                            .updateEndpointConfig(config);
                        await context
                            .read<AuthenticationCubit>()
                            .updateEmailService(activeEmailService);
                        if (!context.mounted) return;
                        context.read<ChatsCubit>().updateEmailService(
                          activeEmailService,
                        );
                        context.read<DraftCubit>().updateEmailService(
                          activeEmailService,
                        );
                        emailService.updateEndpointConfig(config);
                        await context
                            .read<HomeRefreshSyncService>()
                            .updateEmailService(activeEmailService);
                        if (!context.mounted) return;
                        context.read<ConnectivityCubit>().updateEmailContext(
                          emailEnabled: config.smtpEnabled,
                          emailService: activeEmailService,
                        );
                        if (!config.smtpEnabled) {
                          await emailService.shutdown(clearCredentials: false);
                          await emailService.handleNetworkLost();
                        } else {
                          await emailService.handleNetworkAvailable();
                        }
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
  bool _shareIntentAwaitingRoute = false;
  bool _notificationIntentHandling = false;
  bool _notificationIntentAwaitingRoute = false;
  Timer? _pendingAuthNavigation;
  AuthenticationState? _lastAuthState;
  String? _pendingNotificationChatJid;
  bool _checkedInitialNotificationLaunchDetails = false;
  late final AppLifecycleListener _lifecycleListener = AppLifecycleListener(
    onResume: _handleLifecycleResume,
    onShow: _handleLifecycleResume,
    onRestart: _handleLifecycleResume,
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
    final profileState = context.read<ProfileCubit>().state;
    context.read<SettingsCubit>().trackDonationPromptMessageCount(
      accountJid: profileState.jid,
      storedConversationMessageCount:
          profileState.storedConversationMessageCount,
    );
  }

  @override
  void dispose() {
    _pendingAuthNavigation?.cancel();
    _pendingAuthNavigation = null;
    _lifecycleListener.dispose();
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
        final EmailService? emailService = endpointConfig.smtpEnabled
            ? context.read<EmailService>()
            : null;
        notificationService
          ..chatNotificationsMuted = state.chatNotificationsMuted
          ..emailNotificationsMuted = state.emailNotificationsMuted
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
            context.read<NotificationService>().updateLocalizations(
              AppLocalizations.of(context)!.toNotificationStrings(),
            );
            context.read<XmppService>().updateLocalizations(
              AppLocalizations.of(context)!,
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
                    if (state is AuthenticationNone) {
                      _pendingAuthNavigation?.cancel();
                      _pendingAuthNavigation = null;
                      profileCubit.clearSessionIdentity();
                      if (!onLoginRoute && authRequired) {
                        _router.go(const LoginRoute().location);
                      }
                    } else {
                      if (state is AuthenticationComplete &&
                          previousAuthState is! AuthenticationComplete) {
                        profileCubit.syncSessionIdentity();
                      }
                      if (state is AuthenticationComplete &&
                          previousAuthState is! AuthenticationComplete &&
                          onGuestRoute) {
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
    _handleNotificationIntent();
    _handleShareIntent();
  }

  Future<void> _handleNotificationIntent() async {
    if (!mounted || _notificationIntentHandling) return;
    if (context.read<AuthenticationCubit>().state is! AuthenticationComplete) {
      return;
    }
    final xmppService = context.read<XmppService>();
    final chatsCubit = context.read<ChatsCubit>();
    _notificationIntentHandling = true;
    try {
      final payload = await _takePendingNotificationPayload();
      if (payload != null) {
        final String? chatJid = await xmppService.resolveNotificationPayload(
          payload,
        );
        if (chatJid != null) {
          _pendingNotificationChatJid = chatJid;
        }
      }
      final pendingJid = _pendingNotificationChatJid;
      if (pendingJid == null) {
        return;
      }
      if (!_isOnHomeRoute()) {
        _notificationIntentAwaitingRoute = true;
        _router.go(const HomeRoute().location);
        return;
      }
      _notificationIntentAwaitingRoute = false;
      await chatsCubit.openChat(jid: pendingJid);
      if (_pendingNotificationChatJid == pendingJid) {
        _pendingNotificationChatJid = null;
      }
    } finally {
      _notificationIntentHandling = false;
    }
  }

  Future<String?> _takePendingNotificationPayload() async {
    if (launchedFromNotification) {
      launchedFromNotification = false;
      final payload = takeLaunchedNotificationChatJid();
      if (payload != null && payload.isNotEmpty) {
        return payload;
      }
    }
    if (_checkedInitialNotificationLaunchDetails) {
      return null;
    }
    _checkedInitialNotificationLaunchDetails = true;
    final launchDetails = await context
        .read<NotificationService>()
        .getAppNotificationAppLaunchDetails();
    final payload = launchDetails?.notificationResponse?.payload;
    if (payload == null || payload.isEmpty) {
      return null;
    }
    return payload;
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
      _notificationIntentAwaitingRoute = false;
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
