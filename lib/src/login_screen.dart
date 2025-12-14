import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/view/debug_delete_credentials.dart';
import 'package:axichat/src/authentication/view/login_form.dart';
import 'package:axichat/src/authentication/view/signup_form.dart';
import 'package:axichat/src/authentication/view/widgets/operation_progress_bar.dart';
import 'package:axichat/src/avatar/bloc/signup_avatar_cubit.dart';
import 'package:axichat/src/chat/view/chat.dart';
import 'package:axichat/src/common/shorebird_push.dart';
import 'package:axichat/src/common/startup/auth_bootstrap.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/localization/view/language_selector.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:logging/logging.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _AuthFlow {
  login,
  signup,
}

const double _primaryPanePadding = 12.0;
const double _secondaryPaneGutter = 0.0;
const double _unsplitHorizontalMargin = 16.0;
const double _authCardCornerRadius = 20.0;
const Duration _authOperationTimeout = Duration(seconds: 45);

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _authUiLog = Logger('AuthUi');
  var _login = false;
  var _signupFlowLocked = false;
  var _progressStickyVisible = false;
  late OperationProgressController _operationProgressController;
  String _operationLabel = '';
  _AuthFlow? _activeFlow;
  bool _operationAcknowledged = false;
  bool _signupButtonLoading = false;
  bool _handledInitialAuthState = false;
  bool _initialAuthModeResolved = false;
  bool _loginSuccessHandled = false;
  Timer? _authTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _operationProgressController = OperationProgressController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialAuthModeResolved) {
      _initialAuthModeResolved = true;
      _login = context.read<AuthBootstrap>().hasStoredLoginCredentials;
    }
    if (_handledInitialAuthState) return;
    _handledInitialAuthState = true;
    _handleAuthState(context.read<AuthenticationCubit>().state);
  }

  void _handleSubmissionRequested(
    _AuthFlow flow, {
    required String label,
  }) {
    final shouldRestartProgress =
        _activeFlow != flow || !_operationProgressController.isActive;
    _startAuthTimeout(flow);
    setState(() {
      _activeFlow = flow;
      _operationLabel = label;
      _operationAcknowledged = false;
      _progressStickyVisible = true;
      if (flow == _AuthFlow.signup) {
        _signupFlowLocked = true;
        _login = false;
      } else {
        _login = true;
        if (_signupFlowLocked) {
          _signupFlowLocked = false;
        }
      }
      _loginSuccessHandled = false;
    });
    if (shouldRestartProgress) {
      _operationProgressController.start();
    }
  }

  void _handleSignupLoadingChanged(bool isLoading) {
    if (!mounted) return;
    if (_signupButtonLoading != isLoading ||
        (isLoading && _operationLabel.isEmpty)) {
      setState(() {
        _signupButtonLoading = isLoading;
        if (isLoading && _operationLabel.isEmpty) {
          _operationLabel = context.l10n.authCreatingAccount;
        }
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
        !_signupButtonLoading &&
        !_signupFlowLocked &&
        _operationLabel.isEmpty &&
        !_operationProgressController.isActive &&
        !_operationAcknowledged) {
      return;
    }
    setState(() {
      _activeFlow = null;
      _operationLabel = '';
      _operationAcknowledged = false;
      _signupFlowLocked = false;
      _signupButtonLoading = false;
      _progressStickyVisible = false;
      _loginSuccessHandled = false;
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
      _operationAcknowledged = false;
      _progressStickyVisible = false;
      if (wasSignupFlow && _signupFlowLocked) {
        _signupFlowLocked = false;
        _login = false;
      }
      _loginSuccessHandled = false;
    });
    _operationProgressController.reset();
  }

  void _handleAutologinRequested() {
    if (_activeFlow == _AuthFlow.signup || _signupFlowLocked) {
      return;
    }
    _handleSubmissionRequested(
      _AuthFlow.login,
      label: context.l10n.authLoggingIn,
    );
  }

  Future<void> _completeLoginAnimation() async {
    if (_loginSuccessHandled) {
      return;
    }
    _loginSuccessHandled = true;
    final duration = context.read<SettingsCubit>().animationDuration;
    final progressDuration =
        duration == Duration.zero ? baseAnimationDuration : duration;
    await _operationProgressController.complete(duration: progressDuration);
    if (!mounted) {
      return;
    }
    setState(() {
      _signupButtonLoading = false;
      if (_activeFlow != _AuthFlow.signup) {
        _signupFlowLocked = false;
      }
    });
  }

  void _handleAuthState(AuthenticationState state) {
    if (kDebugMode) {
      _authUiLog.fine(
        'state=${state.runtimeType} activeFlow=$_activeFlow '
        'ack=$_operationAcknowledged progressActive=${_operationProgressController.isActive}',
      );
    }

    if (state is AuthenticationSignUpInProgress && !state.fromSubmission) {
      return;
    }
    if (state is AuthenticationComplete ||
        state is AuthenticationFailure ||
        state is AuthenticationSignupFailure ||
        state is AuthenticationNone) {
      _clearAuthTimeout();
    }
    if (state is AuthenticationNone) {
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
        _operationAcknowledged = true;
        _operationLabel = signupInProgress
            ? context.l10n.authCreatingAccount
            : context.l10n.authSecuringLogin;
        _signupFlowLocked = true;
        _login = false;
      });
      if (!_operationProgressController.isActive) {
        _operationProgressController.start();
      }
      _startAuthTimeout(_AuthFlow.signup);
      if (loginFromSignup) {
        unawaited(_operationProgressController.reach(0.75));
      }
      return;
    }

    if (state is AuthenticationLogInInProgress) {
      if (!mounted) return;
      setState(() {
        _activeFlow = _AuthFlow.login;
        _operationAcknowledged = true;
        _operationLabel = context.l10n.authLoggingIn;
        _login = true;
      });
      if (!_operationProgressController.isActive) {
        _operationProgressController.start();
      }
      _startAuthTimeout(_AuthFlow.login);
      unawaited(_operationProgressController.reach(
        0.75,
        duration: const Duration(milliseconds: 500),
      ));
      return;
    }

    if (state is AuthenticationFailure ||
        state is AuthenticationSignupFailure) {
      unawaited(_failOperation());
      return;
    }
    if (state is AuthenticationComplete) {
      if (_operationProgressController.isActive || _activeFlow != null) {
        unawaited(_completeLoginAnimation());
      } else {
        _operationProgressController.reset();
      }
    }
  }

  @override
  void dispose() {
    _operationProgressController.dispose();
    _clearAuthTimeout();
    super.dispose();
  }

  void _startAuthTimeout(_AuthFlow flow) {
    _authTimeoutTimer?.cancel();
    _authTimeoutTimer = Timer(_authOperationTimeout, () async {
      if (!mounted || _activeFlow != flow) return;
      await _failOperation();
    });
  }

  void _clearAuthTimeout() {
    _authTimeoutTimer?.cancel();
    _authTimeoutTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final animationDuration = context.watch<SettingsCubit>().animationDuration;
    final authCardShape = SquircleBorder(
      cornerRadius: _authCardCornerRadius,
      side: BorderSide(color: colors.border),
    );
    final authCardClipShape = SquircleBorder(
      cornerRadius: _authCardCornerRadius,
    );
    final showProgressBar = _progressStickyVisible ||
        _activeFlow != null ||
        _signupButtonLoading ||
        _operationProgressController.isActive;
    final size = MediaQuery.sizeOf(context);
    final allowSplitView = size.shortestSide >= compactDeviceBreakpoint &&
        size.width >= smallScreen;
    final containerMargin = allowSplitView
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(horizontal: _unsplitHorizontalMargin);
    return BlocListener<AuthenticationCubit, AuthenticationState>(
      listener: (context, state) => _handleAuthState(state),
      child: Scaffold(
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
                    const SizedBox(width: 8),
                    const AxiVersion(),
                    if (kDebugMode) ...[
                      const SizedBox(width: 8),
                      DeleteCredentialsButton(),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: containerMargin,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colors.background,
                    border: Border(
                      top: BorderSide(color: colors.border),
                    ),
                  ),
                  child: AxiAdaptiveLayout(
                    primaryFlex: 4,
                    secondaryFlex: 6,
                    primaryPadding: const EdgeInsets.symmetric(
                      horizontal: _primaryPanePadding,
                    ),
                    secondaryPadding:
                        const EdgeInsets.only(left: _secondaryPaneGutter),
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
                                    duration: animationDuration,
                                    curve: Curves.easeInOut,
                                    child: AnimatedCrossFade(
                                      firstCurve: Curves.easeInOut,
                                      secondCurve: Curves.easeInOut,
                                      sizeCurve: Curves.easeInOut,
                                      duration: animationDuration,
                                      crossFadeState:
                                          (!_signupFlowLocked && _login)
                                              ? CrossFadeState.showFirst
                                              : CrossFadeState.showSecond,
                                      firstChild: IgnorePointer(
                                        ignoring: _signupFlowLocked || !_login,
                                        child: Padding(
                                          padding: const EdgeInsets.all(24.0),
                                          child: LoginForm(
                                            key: const ValueKey('login-form'),
                                            onSubmitStart: () =>
                                                _handleSubmissionRequested(
                                              _AuthFlow.login,
                                              label: l10n.authLoggingIn,
                                            ),
                                            onAutologinStart:
                                                _handleAutologinRequested,
                                          ),
                                        ),
                                      ),
                                      secondChild: IgnorePointer(
                                        ignoring: !_signupFlowLocked && _login,
                                        child: Padding(
                                          padding: const EdgeInsets.all(24.0),
                                          child: BlocProvider(
                                            create: (_) => SignupAvatarCubit(),
                                            child: SignupForm(
                                              key: const ValueKey(
                                                'signup-form',
                                              ),
                                              visible:
                                                  _signupFlowLocked || !_login,
                                              onSubmitStart: () =>
                                                  _handleSubmissionRequested(
                                                _AuthFlow.signup,
                                                label: l10n.authCreatingAccount,
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
                                duration: animationDuration,
                                child: showProgressBar
                                    ? Center(
                                        key:
                                            const ValueKey('auth-progress-bar'),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 480,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
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
                                            'auth-toggle-button'),
                                        child: ShadButton.ghost(
                                          onPressed: () {
                                            final nextLogin = !_login;
                                            setState(() {
                                              _login = nextLogin;
                                            });
                                          },
                                          child: Text(
                                            _login
                                                ? l10n.authToggleSignup
                                                : l10n.authToggleLogin,
                                          ),
                                        ).withTapBounce(),
                                      ),
                              ),
                              const SizedBox(height: 18),
                              ShadButton.outline(
                                onPressed: () => context.go('/guest-calendar'),
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
            expandedWidth * 0.55, scaled(_MorphingAuthButton._primaryHeight));
        final currentWidth =
            lerpDouble(compactWidth, expandedWidth, t) ?? expandedWidth;
        final compactHeight = scaled(_MorphingAuthButton._compactHeight);
        final primaryHeight = scaled(_MorphingAuthButton._primaryHeight);
        final height =
            lerpDouble(compactHeight, primaryHeight, t) ?? primaryHeight;
        final borderRadius =
            lerpDouble(scaled(18), scaled(26), t) ?? scaled(26);
        final baseBorderColor = Color.lerp(
                colors.border.withValues(alpha: 0.9), colors.primary, t) ??
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
