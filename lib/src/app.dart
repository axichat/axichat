import 'dart:async';
import 'dart:convert';

import 'package:axichat/main.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/guest/guest_calendar_bloc.dart';
import 'package:axichat/src/calendar/reminders/calendar_reminder_controller.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/policy.dart';
import 'package:axichat/src/common/startup/auth_bootstrap.dart';
import 'package:axichat/src/common/ui/app_theme.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/compose_window_cubit.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/view/compose_launcher.dart';
import 'package:axichat/src/draft/view/compose_window.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/home/service/home_refresh_sync_service.dart';
import 'package:axichat/src/omemo_activity/bloc/omemo_activity_cubit.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/notifications/view/omemo_operation_overlay.dart';
import 'package:axichat/src/routes.dart';
import 'package:axichat/src/share/share_intent_cubit.dart';
import 'package:axichat/src/settings/app_language.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/state_store.dart';
import 'package:axichat/src/xmpp/foreground_socket.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/storage/hive_extensions.dart';
import 'localization/app_localizations.dart';

Timer? _pendingAuthNavigation;
AuthenticationState? _lastAuthState;

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

  @override
  void dispose() {
    _pendingAuthNavigation?.cancel();
    unawaited(_reminderController.clearAll());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        ChangeNotifierProvider<CalendarStorageManager>(
          create: (context) => widget._storageManager,
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
            ),
          )
        else
          RepositoryProvider<XmppService>.value(
            value: widget._xmppService!,
          ),
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
        RepositoryProvider<EmailService>(
          create: (context) => EmailService(
            credentialStore: context.read<CredentialStore>(),
            databaseBuilder: () => context.read<XmppService>().database,
            notificationService: context.read<NotificationService>(),
          ),
        ),
        RepositoryProvider<HomeRefreshSyncService>(
          create: (context) => HomeRefreshSyncService(
            xmppService: context.read<XmppService>(),
            emailService: context.read<EmailService>(),
          )..start(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => SettingsCubit(),
          ),
          BlocProvider(
            create: (context) => AuthenticationCubit(
              credentialStore: context.read<CredentialStore>(),
              xmppService: context.read<XmppService>(),
              emailService: context.read<EmailService>(),
              homeRefreshSyncService: context.read<HomeRefreshSyncService>(),
              notificationService: context.read<NotificationService>(),
              autoLoginOnStart:
                  context.read<AuthBootstrap>().hasStoredLoginCredentials,
            ),
          ),
          BlocProvider(
            create: (context) => OmemoActivityCubit(
              xmppBase: context.read<XmppService>(),
            ),
          ),
          BlocProvider(
            create: (context) => ShareIntentCubit()..initialize(),
          ),
          BlocProvider(
            create: (context) => ChatsCubit(
              xmppService: context.read<XmppService>(),
              homeRefreshSyncService: context.read<HomeRefreshSyncService>(),
              emailService: context.read<EmailService>(),
            ),
          ),
          BlocProvider(
            create: (context) => DraftCubit(
              messageService: context.read<MessageService>(),
              emailService: context.read<EmailService>(),
              settingsCubit: context.read<SettingsCubit>(),
            ),
          ),
          BlocProvider(
            create: (context) => ComposeWindowCubit(),
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
  late final XmppService _xmppService;
  late final EmailService _emailService;

  late final GoRouter _router = GoRouter(
    restorationScopeId: 'app',
    redirect: (context, routerState) {
      final authState = context.read<AuthenticationCubit>().state;
      if (authState is! AuthenticationComplete) {
        // Check if the current route allows guest access
        final location = routeLocations[routerState.matchedLocation];
        if (location?.authenticationRequired == false) {
          return null; // Allow access to guest routes
        }
        final loginLocation = const LoginRoute().location;
        if (authState is AuthenticationLogInInProgress &&
            authState.fromSignup &&
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
    _xmppService = context.read<XmppService>();
    _emailService = context.read<EmailService>();
    _xmppService
      ..setEmailSpamSyncCallback(_emailService.applySpamSyncUpdate)
      ..setEmailBlocklistSyncCallback(
        _emailService.applyEmailBlocklistSyncUpdate,
      );
  }

  @override
  void dispose() {
    _xmppService
      ..clearEmailSpamSyncCallback()
      ..clearEmailBlocklistSyncCallback();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        context.read<NotificationService>()
          ..mute = state.mute
          ..notificationPreviewsEnabled = state.notificationPreviewsEnabled;
        final xmppService = context.read<XmppService>();
        xmppService.updateMessageStorageMode(state.messageStorageMode);
        context
            .read<EmailService>()
            .updateMessageStorageMode(xmppService.messageStorageMode);
        xmppService.toggleAllChatsMarkerResponsive(
          responsive: state.readReceipts,
        );
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
            final buttonShape =
                ContinuousRectangleBorder(borderRadius: globalRadius);
            final listTileShape = buttonShape;
            final outlineInputBorder = OutlineInputBorder(
              borderRadius: globalRadius,
              borderSide: BorderSide(color: materialColors.border),
            );
            final focusedInputBorder = outlineInputBorder.copyWith(
              borderSide: BorderSide(color: materialColors.primary, width: 1.5),
            );
            final errorBorder = outlineInputBorder.copyWith(
              borderSide:
                  BorderSide(color: materialColors.destructive, width: 1),
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
              fontWeight: FontWeight.w700,
            );
            return theme.copyWith(
              iconTheme: const IconThemeData(size: 20),
              textTheme: textThemeWithEmojiFallback,
              appBarTheme: theme.appBarTheme.copyWith(
                titleTextStyle: appBarTitleStyle,
                toolbarTextStyle: appBarTitleStyle,
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
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  elevation: 0,
                  backgroundColor: materialColors.primary,
                  foregroundColor: materialColors.primaryForeground,
                  shape: buttonShape,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
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
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: materialColors.foreground,
                  shape: buttonShape,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              checkboxTheme: CheckboxThemeData(
                shape: ContinuousRectangleBorder(borderRadius: globalRadius),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                visualDensity: VisualDensity.standard,
                side: BorderSide(color: materialColors.border, width: 1.2),
              ),
              scrollbarTheme: ScrollbarThemeData(
                thickness: const WidgetStatePropertyAll<double>(4),
                radius: const Radius.circular(999),
                thumbColor: WidgetStateProperty.resolveWith(
                  (states) {
                    final hovered = states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.focused) ||
                        states.contains(WidgetState.dragged);
                    return hovered
                        ? chatTokens.scrollbarHover
                        : chatTokens.scrollbar;
                  },
                ),
              ),
              extensions: [
                ...theme.extensions.values
                    .where((extension) => extension is! ChatThemeTokens),
                chatTokens,
              ],
            );
          },
          routerConfig: _router,
          builder: (context, child) {
            final shadTheme = ShadTheme.of(context);
            final brightness = Theme.of(context).brightness;
            CalendarPalette.update(
              scheme: shadTheme.colorScheme,
              brightness: brightness,
            );
            final overlayStyle = _systemUiOverlayStyleFor(Theme.of(context));
            final actionsEnabled = context.select<AuthenticationCubit, bool>(
              (cubit) => cubit.state is AuthenticationComplete,
            );
            final routedContent = MultiBlocListener(
              listeners: [
                BlocListener<AuthenticationCubit, AuthenticationState>(
                  listener: (context, state) {
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
                    final animationDuration =
                        context.read<SettingsCubit>().animationDuration;
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

                      if (animationDuration == Duration.zero) {
                        navigateHome();
                      } else {
                        _pendingAuthNavigation =
                            Timer(animationDuration, navigateHome);
                      }
                    }
                    _handleShareIntent(context);
                  },
                ),
                BlocListener<ShareIntentCubit, ShareIntentState>(
                  listener: (context, _) => _handleShareIntent(context),
                ),
              ],
              child: Stack(
                children: [
                  if (child != null) child else const SizedBox.shrink(),
                  Overlay(
                    initialEntries: [
                      OverlayEntry(
                        maintainState: true,
                        builder: (context) => const Material(
                          type: MaterialType.transparency,
                          child: ComposeWindowOverlay(),
                        ),
                      ),
                      OverlayEntry(
                        maintainState: true,
                        builder: (context) => const Material(
                          type: MaterialType.transparency,
                          child: OmemoOperationOverlay(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
                enabled: actionsEnabled,
                child: _DesktopMenuShell(
                  actionsEnabled: actionsEnabled,
                  child: content,
                ),
              ),
            );
            return content;
          },
        );

        return ScaffoldMessenger(child: app);
      },
    );
  }

  void _handleShareIntent(BuildContext context) {
    final shareState = context.read<ShareIntentCubit>().state;
    if (!shareState.hasPayload) return;
    final authState = context.read<AuthenticationCubit>().state;
    if (authState is! AuthenticationComplete) return;
    final payload = shareState.payload!;
    openComposeDraft(
      context,
      navigator: _router.routerDelegate.navigatorKey.currentState,
      body: payload.text,
      jids: const [''],
      attachmentMetadataIds: const <String>[],
    );
    context.read<ShareIntentCubit>().consume();
  }
}

extension ThemeExtension on BuildContext {
  ShadColorScheme get colorScheme => ShadTheme.of(this).colorScheme;

  ShadTextTheme get textTheme => ShadTheme.of(this).textTheme;

  IconThemeData get iconTheme => IconTheme.of(this);

  BorderRadius get radius => ShadTheme.of(this).radius;

  ChatThemeTokens get chatTheme =>
      Theme.of(this).extension<ChatThemeTokens>() ??
      AppTheme.tokens(
        brightness: Theme.of(this).brightness,
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
  const _ShortcutBindings({
    required this.enabled,
    required this.child,
  });

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
            openComposeDraft(
              context,
              attachmentMetadataIds: const <String>[],
            );
            return null;
          },
        ),
      },
      child: child,
    );
    final shortcuts = <ShortcutActivator, Intent>{
      _composeActivator(env.platform): const ComposeIntent(),
    };
    return Shortcuts(
      shortcuts: shortcuts,
      child: routedChild,
    );
  }
}

class _DesktopMenuShell extends StatelessWidget {
  const _DesktopMenuShell({
    required this.actionsEnabled,
    required this.child,
  });

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
