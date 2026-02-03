// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/view/debug_delete_credentials.dart';
import 'package:axichat/src/authentication/view/login_form.dart';
import 'package:axichat/src/authentication/view/signup_form.dart';
import 'package:axichat/src/authentication/view/widgets/operation_progress_bar.dart';
import 'package:axichat/src/avatar/avatar_decode_safety.dart';
import 'package:axichat/src/avatar/bloc/signup_avatar_cubit.dart';
import 'package:axichat/src/calendar/storage/calendar_state_storage_codec.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_registry.dart';
import 'package:axichat/src/calendar/storage/storage_builders.dart';
import 'package:axichat/src/chat/view/chat.dart';
import 'package:axichat/src/common/shorebird_push.dart';
import 'package:axichat/src/common/startup/auth_bootstrap.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/localization/view/language_selector.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart' as models;
import 'package:axichat/src/xmpp/xmpp_service.dart' hide ConnectionState;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:logging/logging.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _AuthFlow { login, signup }

const Duration _authOperationTimeout = Duration(seconds: 45);

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _authUiLog = Logger('AuthUi');
  _AuthFlow _selectedFlow = _AuthFlow.login;
  late AuthProgressController _authProgressController;
  AuthenticationState? _seededAuthState;
  AuthenticationState? _completionHandledState;
  int _authTimeoutGeneration = 0;
  _AuthFlow? _authTimeoutFlow;
  DateTime? _autoLoginRequestedAt;

  @override
  void initState() {
    super.initState();
    final bootstrap = context.read<AuthBootstrap>();
    _selectedFlow = bootstrap.hasStoredLoginCredentials
        ? _AuthFlow.login
        : _AuthFlow.signup;
    _authProgressController = AuthProgressController(vsync: this);
    _maybeAutoLogin();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seededAuthState != null) {
      return;
    }
    _seededAuthState = context.read<AuthenticationCubit>().state;
    _handleAuthState(_seededAuthState!);
  }

  void _maybeAutoLogin() {
    if (_autoLoginRequestedAt != null) {
      return;
    }
    final bootstrap = context.read<AuthBootstrap>();
    if (!bootstrap.hasStoredLoginCredentials) {
      return;
    }
    if (context.read<AuthenticationCubit>().state is! AuthenticationNone) {
      return;
    }
    _autoLoginRequestedAt = DateTime.now();
    context.read<AuthenticationCubit>().login();
  }

  Duration _progressRampDuration(SettingsCubit settings) {
    if (settings.animationDuration == Duration.zero) {
      return Duration.zero;
    }
    return authProgressRampDuration;
  }

  void _startAuthProgress({
    required String label,
    required Duration rampDuration,
  }) {
    if (_authProgressController.snapshot.phase == AuthProgressPhase.running) {
      _authProgressController.continueWithLabel(
        label: label,
        rampDuration: rampDuration,
      );
      return;
    }
    _authProgressController.start(
      label: label,
      rampDuration: rampDuration,
    );
  }

  void _handleSubmissionRequested(_AuthFlow flow) {
    if (_selectedFlow == flow) {
      _completionHandledState = null;
      return;
    }
    setState(() {
      _selectedFlow = flow;
    });
    _completionHandledState = null;
  }

  Future<void> _handleAuthState(AuthenticationState state) async {
    if (kDebugMode) {
      _authUiLog.fine(
        'state=${state.runtimeType} progressPhase='
        '${_authProgressController.snapshot.phase}',
      );
    }

    if (state is AuthenticationSignUpInProgress && !state.fromSubmission) {
      return;
    }
    final settings = context.read<SettingsCubit>();
    if (state is AuthenticationSignUpInProgress) {
      if (_selectedFlow != _AuthFlow.signup) {
        setState(() {
          _selectedFlow = _AuthFlow.signup;
        });
      }
      _completionHandledState = null;
      _startAuthProgress(
        label: context.l10n.authCreatingAccount,
        rampDuration: _progressRampDuration(settings),
      );
      _startAuthTimeout(_AuthFlow.signup);
      return;
    }
    if (state is AuthenticationLogInInProgress) {
      _completionHandledState = null;
      if (state.fromSignup) {
        if (_selectedFlow != _AuthFlow.signup) {
          setState(() {
            _selectedFlow = _AuthFlow.signup;
          });
        }
        _startAuthProgress(
          label: context.l10n.authSecuringLogin,
          rampDuration: _progressRampDuration(settings),
        );
        _startAuthTimeout(_AuthFlow.signup);
      } else {
        if (_selectedFlow != _AuthFlow.login) {
          setState(() {
            _selectedFlow = _AuthFlow.login;
          });
        }
        _startAuthProgress(
          label: context.l10n.authLoggingIn,
          rampDuration: _progressRampDuration(settings),
        );
        _startAuthTimeout(_AuthFlow.login);
      }
      return;
    }
    if (state is AuthenticationFailure ||
        state is AuthenticationSignupFailure) {
      _completionHandledState = null;
      _clearAuthTimeout();
      await _authProgressController.fail(
        duration: settings.animationDuration,
      );
      return;
    }
    if (state is AuthenticationComplete) {
      if (state == _completionHandledState) {
        return;
      }
      if (_authProgressController.snapshot.phase == AuthProgressPhase.idle) {
        _completionHandledState = state;
        _clearAuthTimeout();
        return;
      }
      _completionHandledState = state;
      _clearAuthTimeout();
      final preloadHome = _preloadHomeScreenCache();
      await _authProgressController.complete(
        duration: settings.authCompletionDuration,
      );
      await preloadHome;
      return;
    }
    if (state is AuthenticationNone) {
      _completionHandledState = null;
      _clearAuthTimeout();
      _authProgressController.reset();
    }
  }

  @override
  void dispose() {
    _authProgressController.dispose();
    _clearAuthTimeout();
    super.dispose();
  }

  void _startAuthTimeout(_AuthFlow flow) {
    _authTimeoutGeneration++;
    _authTimeoutFlow = flow;
    final generation = _authTimeoutGeneration;
    _runAuthTimeout(flow, generation);
  }

  void _clearAuthTimeout() {
    _authTimeoutGeneration++;
    _authTimeoutFlow = null;
  }

  Future<void> _runAuthTimeout(_AuthFlow flow, int generation) async {
    await Future<void>.delayed(_authOperationTimeout);
    if (!mounted ||
        _authTimeoutFlow != flow ||
        generation != _authTimeoutGeneration) {
      return;
    }
    await _authProgressController.fail(
      duration: context.read<SettingsCubit>().animationDuration,
    );
  }

  Future<void> _preloadSelfAvatarCache() async {
    XmppService xmppService;
    try {
      xmppService = context.read<XmppService>();
    } on Exception {
      return;
    }
    final storedAvatar =
        xmppService.cachedSelfAvatar ?? await xmppService.getOwnAvatar();
    if (storedAvatar == null || storedAvatar.isEmpty) return;
    final path = storedAvatar.path?.trim();
    if (path == null || path.isEmpty) return;
    final bytes = await xmppService.loadAvatarBytes(path);
    if (bytes == null || bytes.isEmpty || !mounted) return;
    final safeBytes = await sanitizeAvatarBytes(bytes);
    if (safeBytes == null || safeBytes.isEmpty || !mounted) return;
    xmppService.cacheSafeAvatarBytes(path, safeBytes);
    try {
      await precacheImage(MemoryImage(safeBytes), context);
    } on Exception {
      return;
    }
  }

  Future<void> _preloadHomeScreenCache() async {
    final preloads = <Future<void>>[
      _preloadSelfAvatarCache(),
      _preloadChatListCache(),
      _preloadCalendarShortcutCache(),
    ];
    await Future.wait(preloads);
  }

  Future<void> _preloadChatListCache() async {
    if (!mounted) return;
    XmppService xmppService;
    try {
      xmppService = context.read<XmppService>();
    } on Exception {
      return;
    }
    List<models.Chat>? chats;
    try {
      chats = await xmppService.preloadChatList();
    } on Exception {
      return;
    }
    if (!mounted || chats == null || chats.isEmpty) return;
    final preloads = <Future<void>>[
      _precacheChatAvatars(xmppService: xmppService, chats: chats),
      _preloadOpenChatCache(xmppService: xmppService, chats: chats),
    ];
    await Future.wait(preloads);
  }

  models.Chat? _resolveOpenChat(List<models.Chat> chats) {
    for (final chat in chats) {
      if (chat.open) {
        return chat;
      }
    }
    return null;
  }

  Future<models.Chat?> _resolveStoredOpenChat({
    required XmppService xmppService,
  }) async {
    try {
      return await xmppService.loadOpenChat();
    } on Exception {
      return null;
    }
  }

  Future<void> _preloadOpenChatCache({
    required XmppService xmppService,
    required List<models.Chat> chats,
  }) async {
    if (!mounted) return;
    models.Chat? openChat = _resolveOpenChat(chats);
    openChat ??= await _resolveStoredOpenChat(xmppService: xmppService);
    if (!mounted) return;
    final String? openJid = openChat?.jid.trim();
    if (openJid == null || openJid.isEmpty) return;
    try {
      await xmppService.preloadChatWindow(jid: openJid);
    } on Exception {
      return;
    }
  }

  Future<void> _preloadCalendarShortcutCache() async {
    if (!mounted) return;
    final storage = HydratedBloc.storage;
    if (storage is CalendarStorageRegistry &&
        !storage.hasPrefix(authStoragePrefix)) {
      return;
    }
    try {
      final raw = storage.read(_calendarShortcutStorageKey());
      if (raw is! Map) return;
      final snapshot = Map<String, dynamic>.from(raw);
      CalendarStateStorageCodec.decode(snapshot);
    } on Exception {
      return;
    }
  }

  String _calendarShortcutStorageKey() => authStoragePrefix;

  Future<void> _precacheChatAvatars({
    required XmppService xmppService,
    required List<models.Chat> chats,
  }) async {
    if (!mounted) return;
    final avatarPaths = <String>{};
    for (final chat in chats) {
      final resolvedPath = _resolveChatAvatarPath(chat);
      if (resolvedPath != null) {
        avatarPaths.add(resolvedPath);
      }
    }
    if (avatarPaths.isEmpty || !mounted) return;
    for (final path in avatarPaths) {
      final bytes = await xmppService.loadAvatarBytes(path);
      if (!mounted || bytes == null || bytes.isEmpty) continue;
      final safeBytes = await sanitizeAvatarBytes(bytes);
      if (!mounted || safeBytes == null || safeBytes.isEmpty) {
        continue;
      }
      xmppService.cacheSafeAvatarBytes(path, safeBytes);
      try {
        await precacheImage(MemoryImage(safeBytes), context);
      } on Exception {
        continue;
      }
    }
  }

  String? _resolveChatAvatarPath(models.Chat chat) {
    final primaryPath = chat.avatarPath?.trim();
    if (primaryPath != null && primaryPath.isNotEmpty) {
      return primaryPath;
    }
    final fallbackPath = chat.contactAvatarPath?.trim();
    if (fallbackPath != null && fallbackPath.isNotEmpty) {
      return fallbackPath;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final size = MediaQuery.sizeOf(context);
    final allowSplitView = size.shortestSide >= compactDeviceBreakpoint &&
        size.width >= smallScreen;
    final containerMargin = allowSplitView
        ? EdgeInsets.zero
        : EdgeInsets.symmetric(horizontal: spacing.m);
    return BlocListener<AuthenticationCubit, AuthenticationState>(
      listener: (context, state) => _handleAuthState(state),
      child: ValueListenableBuilder<AuthProgressSnapshot>(
        valueListenable: _authProgressController.listenable,
        builder: (context, progress, _) {
          final showProgressBar = progress.isVisible;
          final formsDisabled = showProgressBar;
          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  AxiAppBar(
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const LanguageSelector(
                          compact: true,
                          labelStyle: LanguageLabelStyle.compact,
                        ),
                        SizedBox(width: spacing.s),
                        const AxiVersion(),
                        if (kDebugMode) ...[
                          SizedBox(width: spacing.s),
                          const DeleteCredentialsButton(),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: containerMargin,
                      width: double.infinity,
                      color: colors.background,
                      child: AxiAdaptiveLayout(
                        primaryFlex: 4,
                        secondaryFlex: 6,
                        primaryPadding:
                            EdgeInsets.symmetric(horizontal: spacing.m),
                        secondaryPadding: EdgeInsets.zero,
                        centerSecondary: false,
                        secondaryAlignment: Alignment.topLeft,
                        primaryChild: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: sizing.composeWindowWidth,
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const ShorebirdChecker(),
                                  AxiModalSurface(
                                    child: AxiAnimatedSize(
                                      duration: context
                                          .watch<SettingsCubit>()
                                          .animationDuration,
                                      curve: Curves.easeInOut,
                                      child: AnimatedCrossFade(
                                        firstCurve: Curves.easeInOut,
                                        secondCurve: Curves.easeInOut,
                                        sizeCurve: Curves.easeInOut,
                                        duration: context
                                            .watch<SettingsCubit>()
                                            .animationDuration,
                                        crossFadeState:
                                            _selectedFlow == _AuthFlow.login
                                                ? CrossFadeState.showFirst
                                                : CrossFadeState.showSecond,
                                        firstChild: IgnorePointer(
                                          ignoring: formsDisabled ||
                                              _selectedFlow != _AuthFlow.login,
                                          child: Padding(
                                            padding: EdgeInsets.all(spacing.m),
                                            child: LoginForm(
                                              key: const ValueKey(
                                                'login-form',
                                              ),
                                              busy: formsDisabled,
                                              onSubmitStart: () =>
                                                  _handleSubmissionRequested(
                                                _AuthFlow.login,
                                              ),
                                            ),
                                          ),
                                        ),
                                        secondChild: IgnorePointer(
                                          ignoring: formsDisabled ||
                                              _selectedFlow != _AuthFlow.signup,
                                          child: Padding(
                                            padding: EdgeInsets.all(spacing.m),
                                            child: BlocProvider(
                                              create: (_) =>
                                                  SignupAvatarCubit(),
                                              child: SignupForm(
                                                key: const ValueKey(
                                                  'signup-form',
                                                ),
                                                visible: _selectedFlow ==
                                                    _AuthFlow.signup,
                                                busy: formsDisabled,
                                                onSubmitStart: () =>
                                                    _handleSubmissionRequested(
                                                  _AuthFlow.signup,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: spacing.s),
                                  AnimatedSwitcher(
                                    duration: context
                                        .watch<SettingsCubit>()
                                        .animationDuration,
                                    child: showProgressBar
                                        ? Center(
                                            key: const ValueKey(
                                              'auth-progress-bar',
                                            ),
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                maxWidth:
                                                    sizing.composeWindowWidth,
                                              ),
                                              child: Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: spacing.m,
                                                ),
                                                child: OperationProgressBar(
                                                  animation:
                                                      _authProgressController
                                                          .animation,
                                                  visible: showProgressBar,
                                                  label: progress.label,
                                                  animationDuration: context
                                                      .watch<SettingsCubit>()
                                                      .animationDuration,
                                                ),
                                              ),
                                            ),
                                          )
                                        : KeyedSubtree(
                                            key: const ValueKey(
                                              'auth-toggle-button',
                                            ),
                                            child: AxiButton.ghost(
                                              onPressed: () {
                                                final nextLogin =
                                                    _selectedFlow ==
                                                            _AuthFlow.login
                                                        ? _AuthFlow.signup
                                                        : _AuthFlow.login;
                                                setState(() {
                                                  _selectedFlow = nextLogin;
                                                });
                                              },
                                              child: Text(
                                                _selectedFlow == _AuthFlow.login
                                                    ? l10n.authToggleSignup
                                                    : l10n.authToggleLogin,
                                              ),
                                            ),
                                          ),
                                  ),
                                  SizedBox(height: spacing.m),
                                  AxiButton.outline(
                                    onPressed: () =>
                                        context.go('/guest-calendar'),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.calendar_today),
                                        SizedBox(width: spacing.s),
                                        Text(l10n.authGuestCalendarCta),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: spacing.m),
                                ],
                              ),
                            ),
                          ),
                        ),
                        secondaryChild: const GuestChat(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
