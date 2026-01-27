// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

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
import 'package:axichat/src/common/endpoint_config_cubit.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/localization/view/language_selector.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart' as models;
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:logging/logging.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _AuthFlow { login, signup }

const double _primaryPanePadding = 12.0;
const double _secondaryPaneGutter = 0.0;
const double _unsplitHorizontalMargin = 16.0;
const double _authCardCornerRadius = 20.0;
const Duration _authOperationTimeout = Duration(seconds: 45);
const Duration _authProgressSegmentDuration = Duration(seconds: 4);
const double _authProgressSegmentTarget = 0.8;

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _authUiLog = Logger('AuthUi');
  _AuthFlow _selectedFlow = _AuthFlow.login;
  late OperationProgressController _operationProgressController;
  String _operationLabel = '';
  _AuthFlow? _activeFlow;
  AuthenticationState? _completionHandledState;
  int _authTimeoutGeneration = 0;
  late final Future<void> _bootstrapTask;

  @override
  void initState() {
    super.initState();
    final bootstrap = context.read<AuthBootstrap>();
    _selectedFlow = bootstrap.hasStoredLoginCredentials
        ? _AuthFlow.login
        : _AuthFlow.signup;
    final animationDuration = context.read<SettingsCubit>().animationDuration;
    _operationProgressController = OperationProgressController(
      vsync: this,
      rampDuration: _scaledDuration(animationDuration, 16),
      reachDuration: _scaledDuration(animationDuration, 1.5),
      completeDuration: _scaledDuration(animationDuration, 2),
      failDuration: _scaledDuration(animationDuration, 2 / 3),
    );
    _bootstrapTask = _bootstrap();
  }

  Future<void> _bootstrap() async {
    await context.read<EndpointConfigCubit>().restore();
    if (!mounted) return;
    final bootstrap = context.read<AuthBootstrap>();
    final preferredFlow = bootstrap.hasStoredLoginCredentials
        ? _AuthFlow.login
        : _AuthFlow.signup;
    if (_selectedFlow != preferredFlow) {
      setState(() {
        _selectedFlow = preferredFlow;
      });
    }
    if (bootstrap.hasStoredLoginCredentials &&
        context.read<AuthenticationCubit>().state is AuthenticationNone) {
      await context.read<AuthenticationCubit>().login();
      if (!mounted) return;
    }
    await _handleAuthState(context.read<AuthenticationCubit>().state);
  }

  Duration _scaledDuration(Duration base, double factor) {
    return Duration(
      milliseconds: (base.inMilliseconds * factor).round(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _handleSubmissionRequested(_AuthFlow flow, {required String label}) {
    final shouldRestartProgress =
        _activeFlow != flow || !_operationProgressController.isActive;
    _startAuthTimeout(flow);
    setState(() {
      _activeFlow = flow;
      _operationLabel = label;
      _selectedFlow = flow;
      _completionHandledState = null;
    });
    if (shouldRestartProgress) {
      _operationProgressController.start();
    }
  }

  void _handleSignupLoadingChanged(bool isLoading) {
    if (!mounted) return;
    if (isLoading && _operationLabel.isEmpty) {
      setState(() {
        _operationLabel = context.l10n.authCreatingAccount;
      });
    }
    if (isLoading) {
      if (!_operationProgressController.isActive) {
        _operationProgressController.start();
      }
    } else if (_activeFlow == null) {
      _operationProgressController.reset();
    }
  }

  void _resetAuthUiState() {
    if (_activeFlow == null &&
        _operationLabel.isEmpty &&
        !_operationProgressController.isActive) {
      return;
    }
    setState(() {
      _activeFlow = null;
      _operationLabel = '';
    });
    _operationProgressController.reset();
    _clearAuthTimeout();
  }

  Future<void> _failOperation() async {
    _clearAuthTimeout();
    await _operationProgressController.fail();
    if (!mounted) return;
    setState(() {
      final wasSignupFlow = _activeFlow == _AuthFlow.signup;
      _activeFlow = null;
      if (wasSignupFlow) {
        _selectedFlow = _AuthFlow.signup;
      }
    });
    _operationProgressController.reset();
  }

  Future<void> _completeLoginAnimation() async {
    if (!mounted) return;
    final progressDuration =
        context.read<SettingsCubit>().authCompletionDuration;
    if (!_operationProgressController.isActive &&
        _operationLabel.isEmpty &&
        mounted) {
      setState(() {
        _operationLabel = context.l10n.authLoggingIn;
      });
    }
    final preloadHome = _preloadHomeScreenCache();
    await _operationProgressController.complete(duration: progressDuration);
    await preloadHome;
    if (!mounted) {
      return;
    }
    setState(() {
      if (_activeFlow != _AuthFlow.signup) {
        _selectedFlow = _AuthFlow.login;
      }
    });
  }

  Future<void> _handleAuthState(AuthenticationState state) async {
    if (kDebugMode) {
      _authUiLog.fine(
        'state=${state.runtimeType} activeFlow=$_activeFlow '
        'progressActive=${_operationProgressController.isActive}',
      );
    }

    if (state is AuthenticationSignUpInProgress && !state.fromSubmission) {
      return;
    }
    if (state is AuthenticationLogInInProgress ||
        state is AuthenticationSignUpInProgress) {
      _completionHandledState = null;
    }
    if (state is AuthenticationComplete ||
        state is AuthenticationFailure ||
        state is AuthenticationSignupFailure ||
        state is AuthenticationNone) {
      _clearAuthTimeout();
    }
    if (state is AuthenticationNone) {
      _completionHandledState = null;
      if (_activeFlow != null || _operationProgressController.isActive) {
        // Ignore redundant resets while an auth flow is already in progress.
        return;
      }
      _resetAuthUiState();
      return;
    }

    final signupInProgress = state is AuthenticationSignUpInProgress;
    final loginFromSignup =
        state is AuthenticationLogInInProgress && state.fromSignup;

    if (signupInProgress || loginFromSignup) {
      if (!mounted) return;
      setState(() {
        _activeFlow = _AuthFlow.signup;
        _operationLabel = signupInProgress
            ? context.l10n.authCreatingAccount
            : context.l10n.authSecuringLogin;
        _selectedFlow = _AuthFlow.signup;
      });
      if (!_operationProgressController.isActive) {
        _operationProgressController.start();
      }
      _startAuthTimeout(_AuthFlow.signup);
      if (loginFromSignup) {
        await _operationProgressController.reach(
          _authProgressSegmentTarget,
          duration: _authProgressSegmentDuration,
        );
      }
      return;
    }

    if (state is AuthenticationLogInInProgress) {
      if (!mounted) return;
      setState(() {
        _activeFlow = _AuthFlow.login;
        _operationLabel = context.l10n.authLoggingIn;
        _selectedFlow = _AuthFlow.login;
      });
      if (!_operationProgressController.isActive) {
        _operationProgressController.start();
      }
      _startAuthTimeout(_AuthFlow.login);
      await _operationProgressController.reach(
        _authProgressSegmentTarget,
        duration: _authProgressSegmentDuration,
      );
      return;
    }

    if (state is AuthenticationFailure ||
        state is AuthenticationSignupFailure) {
      _completionHandledState = null;
      await _failOperation();
      return;
    }
    if (state is AuthenticationComplete) {
      if (state == _completionHandledState) {
        return;
      }
      _completionHandledState = state;
      await _completeLoginAnimation();
    }
  }

  @override
  void dispose() {
    _operationProgressController.dispose();
    _clearAuthTimeout();
    super.dispose();
  }

  void _startAuthTimeout(_AuthFlow flow) {
    _authTimeoutGeneration++;
    final generation = _authTimeoutGeneration;
    Future<void>.delayed(_authOperationTimeout).then((_) async {
      if (!mounted ||
          _activeFlow != flow ||
          generation != _authTimeoutGeneration) {
        return;
      }
      await _failOperation();
    });
  }

  void _clearAuthTimeout() {
    _authTimeoutGeneration++;
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
    final authCardShape = SquircleBorder(
      cornerRadius: _authCardCornerRadius,
      side: BorderSide(color: colors.border),
    );
    final authCardClipShape = SquircleBorder(
      cornerRadius: _authCardCornerRadius,
    );
    final showProgressBar =
        _activeFlow != null || _operationProgressController.isActive;
    final size = MediaQuery.sizeOf(context);
    final allowSplitView = size.shortestSide >= compactDeviceBreakpoint &&
        size.width >= smallScreen;
    final containerMargin = allowSplitView
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(horizontal: _unsplitHorizontalMargin);
    return FutureBuilder<void>(
      future: _bootstrapTask,
      builder: (context, snapshot) {
        return BlocListener<AuthenticationCubit, AuthenticationState>(
          listener: (context, state) => _handleAuthState(state),
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  const AxiAppBar(
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LanguageSelector(
                          compact: true,
                          labelStyle: LanguageLabelStyle.compact,
                        ),
                        SizedBox(width: 8),
                        AxiVersion(),
                        if (kDebugMode) ...[
                          SizedBox(width: 8),
                          DeleteCredentialsButton(),
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
                        primaryPadding: const EdgeInsets.symmetric(
                          horizontal: _primaryPanePadding,
                        ),
                        secondaryPadding: const EdgeInsets.only(
                          left: _secondaryPaneGutter,
                        ),
                        centerSecondary: false,
                        secondaryAlignment: Alignment.topLeft,
                        primaryChild: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const ShorebirdChecker(),
                                  DecoratedBox(
                                    decoration: ShapeDecoration(
                                      color: colors.card,
                                      shape: authCardShape,
                                    ),
                                    child: ClipPath(
                                      clipper: ShapeBorderClipper(
                                        shape: authCardClipShape,
                                      ),
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
                                          crossFadeState: (_activeFlow !=
                                                      _AuthFlow.signup &&
                                                  _selectedFlow ==
                                                      _AuthFlow.login)
                                              ? CrossFadeState.showFirst
                                              : CrossFadeState.showSecond,
                                          firstChild: IgnorePointer(
                                            ignoring: _activeFlow ==
                                                    _AuthFlow.signup ||
                                                _selectedFlow !=
                                                    _AuthFlow.login,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(24.0),
                                              child: LoginForm(
                                                key: const ValueKey(
                                                    'login-form'),
                                                onSubmitStart: () =>
                                                    _handleSubmissionRequested(
                                                  _AuthFlow.login,
                                                  label: l10n.authLoggingIn,
                                                ),
                                              ),
                                            ),
                                          ),
                                          secondChild: IgnorePointer(
                                            ignoring: _activeFlow ==
                                                    _AuthFlow.login ||
                                                _selectedFlow !=
                                                    _AuthFlow.signup,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(24.0),
                                              child: BlocProvider(
                                                create: (_) =>
                                                    SignupAvatarCubit(),
                                                child: SignupForm(
                                                  key: const ValueKey(
                                                    'signup-form',
                                                  ),
                                                  visible: _activeFlow ==
                                                          _AuthFlow.signup ||
                                                      _selectedFlow ==
                                                          _AuthFlow.signup,
                                                  onSubmitStart: () =>
                                                      _handleSubmissionRequested(
                                                    _AuthFlow.signup,
                                                    label: l10n
                                                        .authCreatingAccount,
                                                  ),
                                                  onLoadingChanged:
                                                      _handleSignupLoadingChanged,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
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
                                              constraints: const BoxConstraints(
                                                maxWidth: 480,
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 24,
                                                ),
                                                child: OperationProgressBar(
                                                  animation:
                                                      _operationProgressController
                                                          .animation,
                                                  visible: showProgressBar,
                                                  label: _operationLabel,
                                                ),
                                              ),
                                            ),
                                          )
                                        : KeyedSubtree(
                                            key: const ValueKey(
                                              'auth-toggle-button',
                                            ),
                                            child: ShadButton.ghost(
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
                                            ).withTapBounce(),
                                          ),
                                  ),
                                  const SizedBox(height: 18),
                                  ShadButton.outline(
                                    onPressed: () =>
                                        context.go('/guest-calendar'),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.calendar_today),
                                        const SizedBox(width: 8),
                                        Text(l10n.authGuestCalendarCta),
                                      ],
                                    ),
                                  ).withTapBounce(),
                                  const SizedBox(height: 18),
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
          ),
        );
      },
    );
  }
}

// ignore: unused_element
class _AuthModeToggle extends StatelessWidget {
  const _AuthModeToggle({
    required this.loginSelected,
    required this.onChanged,
    required this.duration,
  });

  final bool loginSelected;
  final ValueChanged<bool> onChanged;
  final Duration duration;

  static const double _overlap =
      _MorphingAuthButton._cutoutDepth - 4; // Pulls buttons together

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 240.0;
        final width = math.min(240.0, math.max(190.0, maxWidth));
        return Center(
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MorphingAuthButton(
                  label: l10n.authLogin,
                  selected: loginSelected,
                  cutoutEdge: CutoutEdge.bottom,
                  width: width,
                  duration: duration,
                  onTap: () => onChanged(true),
                ),
                Transform.translate(
                  offset: const Offset(0, -_AuthModeToggle._overlap),
                  child: _MorphingAuthButton(
                    label: l10n.authSignUp,
                    selected: !loginSelected,
                    cutoutEdge: CutoutEdge.top,
                    width: width,
                    duration: duration,
                    onTap: () => onChanged(false),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MorphingAuthButton extends StatefulWidget {
  const _MorphingAuthButton({
    required this.label,
    required this.selected,
    required this.cutoutEdge,
    required this.width,
    required this.duration,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final CutoutEdge cutoutEdge;
  final double width;
  final Duration duration;
  final VoidCallback onTap;

  static const double _primaryHeight = 60;
  static const double _compactHeight = 38;
  static const double _cutoutDepth = 22;

  @override
  State<_MorphingAuthButton> createState() => _MorphingAuthButtonState();
}

class _MorphingAuthButtonState extends State<_MorphingAuthButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.selected ? 1 : 0,
    );
    _focusNode = FocusNode(debugLabel: 'auth-toggle-${widget.label}');
  }

  @override
  void didUpdateWidget(covariant _MorphingAuthButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.selected != widget.selected) {
      if (widget.selected) {
        _controller.animateTo(1, curve: Curves.easeInOut);
      } else {
        _controller.animateTo(0, curve: Curves.easeInOut);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        final textScaler = MediaQuery.of(context).textScaler;
        double scaled(double value) => textScaler.scale(value);
        final scaleFactor = textScaler.scale(1);
        final baseWidth = widget.width;
        final expandedWidth = math.max(baseWidth, scaled(baseWidth));
        final compactWidth = math.max(
          expandedWidth * 0.55,
          scaled(_MorphingAuthButton._primaryHeight),
        );
        final currentWidth =
            lerpDouble(compactWidth, expandedWidth, t) ?? expandedWidth;
        final compactHeight = scaled(_MorphingAuthButton._compactHeight);
        final primaryHeight = scaled(_MorphingAuthButton._primaryHeight);
        final height =
            lerpDouble(compactHeight, primaryHeight, t) ?? primaryHeight;
        final borderRadius =
            lerpDouble(scaled(18), scaled(26), t) ?? scaled(26);
        final baseBorderColor = Color.lerp(
              colors.border.withValues(alpha: 0.9),
              colors.primary,
              t,
            ) ??
            colors.border;
        final borderColor = _focused ? colors.primary : baseBorderColor;
        final borderWidth =
            lerpDouble(scaled(1), scaled(1.8), t) ?? scaled(1.3);
        final baseCutoutThickness =
            lerpDouble(0, math.max(widget.width - 28, 0), t) ?? 0;
        final baseCutoutDepth = _MorphingAuthButton._cutoutDepth * t;
        final visualCutoutDepth = baseCutoutDepth * scaleFactor;
        final baseFillColor =
            Color.lerp(colors.card, colors.primary, t) ?? colors.card;
        final fillColor = _focused && !widget.selected
            ? Color.alphaBlend(
                colors.primary.withValues(alpha: 0.08),
                baseFillColor,
              )
            : baseFillColor;
        final textColor =
            Color.lerp(colors.foreground, colors.primaryForeground, t) ??
                colors.foreground;
        final edgePadding = EdgeInsets.only(
          top:
              widget.cutoutEdge == CutoutEdge.top ? visualCutoutDepth * 0.6 : 0,
          bottom: widget.cutoutEdge == CutoutEdge.bottom
              ? visualCutoutDepth * 0.6
              : 0,
        );
        final cutouts = <CutoutSpec>[];
        if (baseCutoutDepth > 0.1 && baseCutoutThickness > 18) {
          cutouts.add(
            CutoutSpec(
              edge: widget.cutoutEdge,
              alignment: Alignment.center,
              depth: baseCutoutDepth,
              thickness: baseCutoutThickness,
              cornerRadius: 18,
              child: const SizedBox.shrink(),
            ),
          );
        }
        final buttonSurface = CutoutSurface(
          backgroundColor: fillColor,
          borderColor: borderColor,
          shadowOpacity: 0.15 * t,
          shadows: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.2 * t),
              blurRadius: scaled(18),
              offset: Offset(0, scaled(12) * t),
            ),
          ],
          shape: SquircleBorder(
            cornerRadius: borderRadius,
            side: BorderSide(color: borderColor, width: borderWidth),
          ),
          cutouts: cutouts,
          child: Padding(
            padding: edgePadding,
            child: Center(
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: context.textTheme.p.copyWith(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ),
        ).withTapBounce();

        return SizedBox(
          width: currentWidth,
          height: height,
          child: FocusableActionDetector(
            focusNode: _focusNode,
            enabled: true,
            mouseCursor: SystemMouseCursors.click,
            onShowFocusHighlight: (focused) {
              if (_focused != focused) {
                setState(() => _focused = focused);
              }
            },
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            },
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (intent) {
                  widget.onTap();
                  return null;
                },
              ),
            },
            child: Semantics(
              container: true,
              button: true,
              selected: widget.selected,
              label: widget.label,
              hint: widget.selected
                  ? context.l10n.authToggleSelected
                  : context.l10n.authToggleSelectHint(widget.label),
              onTap: widget.onTap,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                child: buttonSurface,
              ),
            ),
          ),
        );
      },
    );
  }
}
