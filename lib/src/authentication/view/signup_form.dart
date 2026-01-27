// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/view/terms_checkbox.dart';
import 'package:axichat/src/authentication/view/widgets/endpoint_config_sheet.dart';
import 'package:axichat/src/avatar/bloc/signup_avatar_cubit.dart';
import 'package:axichat/src/avatar/view/widgets/signup_avatar_editor_panel.dart';
import 'package:axichat/src/avatar/view/widgets/signup_avatar_selector.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/notifications/view/notification_request.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({
    super.key,
    this.onSubmitStart,
    this.onLoadingChanged,
    this.visible = true,
  });

  final VoidCallback? onSubmitStart;
  final ValueChanged<bool>? onLoadingChanged;
  final bool visible;

  @override
  State<SignupForm> createState() => _SignupFormState();
}

enum _PasswordStrengthLevel { empty, weak, medium, stronger }

enum _InsecurePasswordReason { weak, breached }

class _SignupFormState extends State<SignupForm>
    with AutomaticKeepAliveClientMixin {
  late TextEditingController _jidTextController;
  late TextEditingController _passwordTextController;
  late TextEditingController _password2TextController;
  late TextEditingController _captchaTextController;
  final _rememberMeFieldKey = GlobalKey<FormFieldState<bool>>();
  static final _usernamePattern = RegExp(r'^[a-z][a-z0-9._-]{3,19}$');
  static final _digitCharacters = RegExp(r'[0-9]');
  static final _lowercaseCharacters = RegExp(r'[a-z]');
  static final _uppercaseCharacters = RegExp(r'[A-Z]');
  static final _symbolCharacters = RegExp(r'[^A-Za-z0-9]');
  static const double _maxEntropyBits = 120;
  static const double _weakEntropyThreshold = 50;
  static const double _strongEntropyThreshold = 80;

  final _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  bool allowInsecurePassword = false;
  bool rememberMe = true;
  bool _passwordBreached = false;
  String? _lastBreachedPassword;
  bool _pwnedCheckInProgress = false;
  bool _showAllowInsecureError = false;
  bool _showBreachedError = false;
  String _lastPasswordValue = '';
  int _allowInsecureResetTick = 0;
  int _captchaImageFailureReloads = 0;
  String? _lastCaptchaServer;
  bool _showAvatarEditor = false;
  double? _usernameDescriptionHeight;

  var _currentIndex = 0;
  String? _errorText;
  late Future<String> _captchaSrc;
  bool _captchaSrcInitialized = false;

  @override
  void initState() {
    super.initState();
    _jidTextController = TextEditingController()
      ..addListener(_handleFieldProgressChanged);
    _passwordTextController = TextEditingController()
      ..addListener(_handleFieldProgressChanged);
    _password2TextController = TextEditingController()
      ..addListener(_handleFieldProgressChanged);
    _captchaTextController = TextEditingController()
      ..addListener(_handleFieldProgressChanged);
    _restoreRememberMePreference();
  }

  Future<void> _restoreRememberMePreference() async {
    final preference =
        await context.read<AuthenticationCubit>().loadRememberMeChoice();
    if (!mounted) return;
    setState(() {
      rememberMe = preference;
    });
    _rememberMeFieldKey.currentState?.didChange(preference);
  }

  @override
  void dispose() {
    _jidTextController
      ..removeListener(_handleFieldProgressChanged)
      ..dispose();
    _passwordTextController
      ..removeListener(_handleFieldProgressChanged)
      ..dispose();
    _password2TextController
      ..removeListener(_handleFieldProgressChanged)
      ..dispose();
    _captchaTextController
      ..removeListener(_handleFieldProgressChanged)
      ..dispose();
    widget.onLoadingChanged?.call(false);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<SignupAvatarCubit>().setVisible(
          widget.visible,
          context.colorScheme,
        );
    _usernameDescriptionHeight = _measureTextHeight(
      context,
      text: context.l10n.authUsernameCaseInsensitive,
      style: context.textTheme.small,
    );
    if (_captchaSrcInitialized) {
      return;
    }
    _lastCaptchaServer = context.read<AuthenticationCubit>().state.server;
    _captchaSrc = _loadCaptchaSrc();
    _captchaSrcInitialized = true;
  }

  void _handleFieldProgressChanged() {
    if (!mounted) return;
    final password = _passwordTextController.text;
    if (_lastPasswordValue != password) {
      _lastPasswordValue = password;
      _showAllowInsecureError = false;
      _showBreachedError = false;
      if (_passwordBreached && _lastBreachedPassword != password) {
        _passwordBreached = false;
        _lastBreachedPassword = null;
      }
    }
    if (_insecurePasswordReason == null && allowInsecurePassword) {
      allowInsecurePassword = false;
      _allowInsecureResetTick++;
    }
    setState(() {});
  }

  double _measureTextHeight(
    BuildContext context, {
    required String text,
    required TextStyle style,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout(maxWidth: double.infinity);
    return painter.height;
  }

  bool _isLoadingForState(AuthenticationState state) {
    final isSubmittingLastStep = state is AuthenticationSignUpInProgress &&
        state.fromSubmission &&
        _currentIndex == _formKeys.length - 1;
    final isPostSubmitState = state is AuthenticationLogInInProgress ||
        state is AuthenticationComplete;
    return isSubmittingLastStep || isPostSubmitState;
  }

  @override
  void didUpdateWidget(covariant SignupForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      context.read<SignupAvatarCubit>().setVisible(
            widget.visible,
            context.colorScheme,
          );
    }
  }

  String? _avatarErrorText(
    SignupAvatarState avatarState,
    AppLocalizations l10n,
  ) {
    final errorType = avatarState.errorType;
    if (errorType == null) {
      return null;
    }
    return errorType.resolve(
      l10n,
      hasSourceBytes: avatarState.avatar?.sourceBytes != null,
      maxKilobytes: avatarState.errorMaxKilobytes,
      fallbackMaxKilobytes: SignupAvatarCubit.avatarMaxKilobytes,
    );
  }

  void _onPressed(BuildContext context) async {
    if (context.read<SignupAvatarCubit>().state.processing) return;
    context.read<SignupAvatarCubit>().pauseCarousel();
    final avatarPayload =
        await context.read<SignupAvatarCubit>().buildSelectedAvatarPayload();
    FocusManager.instance.primaryFocus?.unfocus();
    final captchaSrc = await _captchaSrc;
    if (!context.mounted || _formKeys.last.currentState?.validate() == false) {
      return;
    }
    final captchaId = _resolveCaptchaId(captchaSrc);
    if (captchaId == null) {
      setState(() {
        _errorText = context.l10n.signupCaptchaErrorMessage;
      });
      return;
    }
    widget.onSubmitStart?.call();
    await context.read<AuthenticationCubit>().signup(
          username: _jidTextController.value.text,
          password: _passwordTextController.value.text,
          confirmPassword: _password2TextController.value.text,
          captchaID: captchaId,
          captcha: _captchaTextController.value.text,
          rememberMe: rememberMe,
          avatar: avatarPayload,
        );
  }

  String? _resolveCaptchaId(String src) {
    final trimmed = src.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final uri = Uri.parse(trimmed);
      final segments = uri.pathSegments;
      final captchaIndex = segments.indexOf('captcha');
      if (captchaIndex == -1 || captchaIndex + 1 >= segments.length) {
        return null;
      }
      final id = segments[captchaIndex + 1].trim();
      return id.isEmpty ? null : id;
    } on FormatException {
      return null;
    }
  }

  Future<String> _loadCaptchaSrc() async {
    _lastCaptchaServer = context.read<AuthenticationCubit>().state.server;
    return context.read<AuthenticationCubit>().fetchCaptchaSrcWithRetry();
  }

  void _reloadCaptcha() {
    _captchaImageFailureReloads = 0;
    _captchaTextController.clear();
    if (!mounted) return;
    setState(() {
      _captchaSrc = _loadCaptchaSrc();
    });
  }

  void _reloadCaptchaForAutoRetry() {
    _captchaTextController.clear();
    if (!mounted) return;
    setState(() {
      _captchaSrc = _loadCaptchaSrc();
    });
  }

  void _retryCaptchaAfterImageFailure() {
    const maxAutoReloads = 1;
    if (_captchaImageFailureReloads >= maxAutoReloads) {
      return;
    }
    _captchaImageFailureReloads++;
    _reloadCaptchaForAutoRetry();
  }

  void _openAvatarEditor() {
    if (context.read<SignupAvatarCubit>().state.processing) return;
    setState(() {
      _showAvatarEditor = true;
    });
  }

  String get _currentStepLabel {
    switch (_currentIndex) {
      case 0:
        return context.l10n.signupStepUsername;
      case 1:
        return context.l10n.signupStepPassword;
      case 2:
        return context.l10n.signupStepCaptcha;
      default:
        return context.l10n.signupStepSetup;
    }
  }

  double get _passwordEntropyBits {
    final password = _passwordTextController.text;
    if (password.isEmpty) {
      return 0;
    }
    final pool = _estimateCharacterPool(password);
    return password.length * (math.log(pool) / math.ln2);
  }

  _PasswordStrengthLevel get _passwordStrengthLevel {
    if (_passwordTextController.text.isEmpty) {
      return _PasswordStrengthLevel.empty;
    }
    final entropy = _passwordEntropyBits;
    if (entropy < _weakEntropyThreshold) {
      return _PasswordStrengthLevel.weak;
    }
    if (entropy < _strongEntropyThreshold) {
      return _PasswordStrengthLevel.medium;
    }
    return _PasswordStrengthLevel.stronger;
  }

  _InsecurePasswordReason? get _insecurePasswordReason {
    if (_passwordBreached) {
      return _InsecurePasswordReason.breached;
    }
    if (_passwordStrengthLevel == _PasswordStrengthLevel.weak) {
      return _InsecurePasswordReason.weak;
    }
    return null;
  }

  int _estimateCharacterPool(String password) {
    var pool = 0;
    if (_digitCharacters.hasMatch(password)) {
      pool += 10;
    }
    if (_lowercaseCharacters.hasMatch(password)) {
      pool += 26;
    }
    if (_uppercaseCharacters.hasMatch(password)) {
      pool += 26;
    }
    if (_symbolCharacters.hasMatch(password)) {
      pool += 33;
    }
    return pool == 0 ? 1 : pool;
  }

  bool get _isUsernameValid =>
      _usernamePattern.hasMatch(_jidTextController.text);

  bool get _passwordWithinBounds =>
      _passwordTextController.text.isNotEmpty &&
      _passwordTextController.text.length <= passwordMaxLength;

  bool get _passwordsMatch =>
      _password2TextController.text.isNotEmpty &&
      _password2TextController.text == _passwordTextController.text;

  bool get _arePasswordsValid => _passwordWithinBounds && _passwordsMatch;

  bool get _captchaComplete => _captchaTextController.text.trim().isNotEmpty;

  bool get _hasStartedPasswordConfirmation =>
      _passwordTextController.text.isNotEmpty &&
      _password2TextController.text.isNotEmpty;

  _InsecurePasswordReason? get _visibleInsecurePasswordReason {
    final reason = _insecurePasswordReason;
    if (reason == _InsecurePasswordReason.weak &&
        !_hasStartedPasswordConfirmation) {
      return null;
    }
    return reason;
  }

  int get _completedStepCount => [
        _isUsernameValid,
        _arePasswordsValid,
        _captchaComplete,
      ].where((complete) => complete).length;

  double get _progressValue => _completedStepCount / _formKeys.length;

  Future<void> _handleContinuePressed(BuildContext context) async {
    if (context.read<SignupAvatarCubit>().state.processing) return;
    final formState = _formKeys[_currentIndex].currentState;
    if (formState?.validate() == false) {
      return;
    }
    if (_currentIndex == 1) {
      await _advanceFromPasswordStep(context);
      return;
    }
    _goToNextSignupStep();
  }

  Future<void> _advanceFromPasswordStep(BuildContext context) async {
    final passwordSnapshot = _passwordTextController.text;
    if ((_passwordStrengthLevel == _PasswordStrengthLevel.weak ||
            _passwordBreached) &&
        !allowInsecurePassword) {
      if (!mounted) return;
      setState(() {
        _showAllowInsecureError = true;
        _showBreachedError = _passwordBreached;
      });
      return;
    }

    if (allowInsecurePassword) {
      _goToNextSignupStep();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _pwnedCheckInProgress = true;
    });
    final notPwned = await context.read<AuthenticationCubit>().checkNotPwned(
          password: passwordSnapshot,
        );
    if (!mounted) return;
    final currentPassword = _passwordTextController.text;
    if (currentPassword != passwordSnapshot) {
      setState(() {
        _pwnedCheckInProgress = false;
      });
      return;
    }
    setState(() {
      _pwnedCheckInProgress = false;
    });

    if (!notPwned) {
      setState(() {
        _passwordBreached = true;
        _lastBreachedPassword = passwordSnapshot;
        _showBreachedError = true;
        _showAllowInsecureError = true;
      });
      _formKeys[1].currentState?.validate();
      return;
    }

    setState(() {
      _passwordBreached = false;
      _lastBreachedPassword = null;
    });
    _goToNextSignupStep();
  }

  void _goToNextSignupStep() {
    if (!mounted) return;
    setState(() {
      _currentIndex++;
      _errorText = null;
      _showAllowInsecureError = false;
      _showBreachedError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocConsumer<AuthenticationCubit, AuthenticationState>(
      // listenWhen: (previous, current) => current is AuthenticationSignupFailure && previous is!AuthenticationSignupFailure,
      listener: (context, state) {
        widget.onLoadingChanged?.call(_isLoadingForState(state));
        if (_lastCaptchaServer != state.server) {
          _lastCaptchaServer = state.server;
          _reloadCaptcha();
        }
        if (state is AuthenticationSignupFailure) {
          _reloadCaptcha();
          setState(() {
            _errorText = state.message.resolve(context.l10n);
          });
        }
      },
      builder: (context, state) {
        return BlocBuilder<SignupAvatarCubit, SignupAvatarState>(
          builder: (context, avatarState) {
            final avatarErrorText = _avatarErrorText(
              avatarState,
              context.l10n,
            );
            final loading = _isLoadingForState(state);
            final cleanupBlocked =
                state is AuthenticationSignupFailure && state.isCleanupBlocked;
            final spacing = context.spacing;
            final sizing = context.sizing;
            final horizontalPadding =
                EdgeInsets.symmetric(horizontal: spacing.s);
            final errorPadding = EdgeInsets.fromLTRB(
              spacing.s,
              spacing.m,
              spacing.s,
              spacing.s,
            );
            final globalErrorPadding = EdgeInsets.fromLTRB(
              spacing.s,
              spacing.s,
              spacing.s,
              spacing.m,
            );
            final fieldSpacing = EdgeInsets.symmetric(vertical: spacing.s);
            final captchaSize = Size(
              sizing.menuItemHeight * 5,
              sizing.menuItemHeight * 2,
            );
            final animationDuration =
                context.watch<SettingsCubit>().animationDuration;
            const defaultDescriptionHeight = 0.0;
            final usernameDescriptionHeight =
                _usernameDescriptionHeight ?? defaultDescriptionHeight;
            final errorText = _errorText?.trim();
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: sizing.dialogMaxWidth),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: errorPadding,
                      child: _SignupProgressMeter(
                        progressValue: _progressValue,
                        currentStepIndex: _currentIndex,
                        totalSteps: _formKeys.length,
                        currentStepLabel: _currentStepLabel,
                        animationDuration: animationDuration,
                      ),
                    ),
                    Padding(
                      padding: horizontalPadding,
                      child: Text(
                        context.l10n.signupTitle,
                        style: context.modalHeaderTextStyle,
                      ),
                    ),
                    Padding(
                      padding: globalErrorPadding,
                      child: AnimatedSwitcher(
                        duration: animationDuration,
                        child: !_showBreachedError &&
                                (errorText?.isNotEmpty ?? false)
                            ? Semantics(
                                liveRegion: true,
                                container: true,
                                label: context.l10n.signupErrorPrefix(
                                  errorText ?? '',
                                ),
                                child: Text(
                                  errorText ?? '',
                                  key: const ValueKey(
                                    'signup-global-error-text',
                                  ),
                                  style: context.textTheme.small,
                                ),
                              )
                            : const SizedBox(
                                key: ValueKey('signup-global-error-empty'),
                              ),
                      ),
                    ),
                    Padding(
                      padding: horizontalPadding,
                      child: NotificationRequest(
                        notificationService:
                            context.watch<NotificationService>(),
                        capability: context.watch<Capability>(),
                      ),
                    ),
                    const SizedBox.square(),
                    Padding(
                      padding: horizontalPadding,
                      child: AxiAnimatedSize(
                        duration:
                            context.watch<SettingsCubit>().animationDuration,
                        curve: Curves.easeIn,
                        child: AnimatedSwitcher(
                          duration:
                              context.watch<SettingsCubit>().animationDuration,
                          switchInCurve: Curves.easeIn,
                          switchOutCurve: Curves.easeOut,
                          transitionBuilder:
                              AnimatedSwitcher.defaultTransitionBuilder,
                          child: [
                            Form(
                              key: _formKeys[0],
                              child: Padding(
                                padding: fieldSpacing,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  spacing: spacing.s,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Transform.translate(
                                          offset: Offset(
                                            0,
                                            -usernameDescriptionHeight,
                                          ),
                                          child: SignupAvatarSelector(
                                            bytes: avatarState.displayedBytes,
                                            username: _jidTextController.text,
                                            processing: avatarState.processing,
                                            onTap: _openAvatarEditor,
                                          ),
                                        ),
                                        SizedBox(width: spacing.s),
                                        Expanded(
                                          child: AxiTextFormField(
                                            autocorrect: false,
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(
                                                RegExp(r'[a-z0-9._-]'),
                                              ),
                                            ],
                                            keyboardType: TextInputType.name,
                                            description: Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: spacing.xs,
                                              ),
                                              child: Text(
                                                context.l10n
                                                    .authUsernameCaseInsensitive,
                                              ),
                                            ),
                                            placeholder: Text(
                                              context.l10n.authUsername,
                                            ),
                                            enabled: !loading,
                                            controller: _jidTextController,
                                            trailing: EndpointSuffix(
                                              server: state.server,
                                            ),
                                            validator: (text) {
                                              if (text.isEmpty) {
                                                return context
                                                    .l10n.authUsernameRequired;
                                              }
                                              if (!_usernamePattern
                                                  .hasMatch(text)) {
                                                return context
                                                    .l10n.authUsernameRules;
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (avatarErrorText != null)
                                      Text(
                                        avatarErrorText,
                                        style: context.textTheme.small,
                                      ),
                                    if (_showAvatarEditor)
                                      Padding(
                                        padding:
                                            EdgeInsets.only(top: spacing.s),
                                        child: Center(
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth: math.min(
                                                MediaQuery.sizeOf(
                                                  context,
                                                ).width,
                                                sizing.dialogMaxWidth,
                                              ),
                                            ),
                                            child: Stack(
                                              children: [
                                                SignupAvatarEditorPanel(
                                                  mode: avatarState.editorMode,
                                                  avatarBytes: avatarState
                                                      .displayedBytes,
                                                  cropBytes: avatarState
                                                      .avatar?.sourceBytes,
                                                  cropRect: avatarState
                                                      .avatar?.cropRect,
                                                  imageWidth: avatarState
                                                      .avatar?.sourceWidth
                                                      ?.toDouble(),
                                                  imageHeight: avatarState
                                                      .avatar?.sourceHeight
                                                      ?.toDouble(),
                                                  onCropChanged: (rect) => context
                                                      .read<SignupAvatarCubit>()
                                                      .updateCropRect(rect),
                                                  onCropReset: context
                                                      .read<SignupAvatarCubit>()
                                                      .resetCrop,
                                                  onCropCommitted: (_) => context
                                                      .read<SignupAvatarCubit>()
                                                      .commitCrop(),
                                                  onShuffle: () => context
                                                      .read<SignupAvatarCubit>()
                                                      .shuffleCarousel(
                                                        context.colorScheme,
                                                      ),
                                                  onUpload: context
                                                      .read<SignupAvatarCubit>()
                                                      .pickAvatarFromFiles,
                                                  onUseCurrent: () => context
                                                      .read<SignupAvatarCubit>()
                                                      .pauseCarousel(),
                                                  useActionEnabled: avatarState
                                                      .canUseCarouselAvatar,
                                                  canShuffleBackground: avatarState
                                                          .hasCarouselPreview &&
                                                      avatarState
                                                          .canShuffleBackground,
                                                  onShuffleBackground: avatarState
                                                              .hasCarouselPreview &&
                                                          avatarState
                                                              .canShuffleBackground
                                                      ? () => context
                                                          .read<
                                                              SignupAvatarCubit>()
                                                          .shuffleCarouselBackground(
                                                            context.colorScheme,
                                                          )
                                                      : null,
                                                ),
                                                Positioned(
                                                  top: spacing.xs,
                                                  right: spacing.xs,
                                                  child: AxiIconButton(
                                                    iconData: LucideIcons.x,
                                                    tooltip: context
                                                        .l10n.commonClose,
                                                    onPressed: () {
                                                      setState(() {
                                                        _showAvatarEditor =
                                                            false;
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Form(
                              key: _formKeys[1],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: fieldSpacing,
                                    child: PasswordInput(
                                      enabled:
                                          !loading && !_pwnedCheckInProgress,
                                      controller: _passwordTextController,
                                    ),
                                  ),
                                  Padding(
                                    padding: fieldSpacing,
                                    child: PasswordInput(
                                      enabled:
                                          !loading && !_pwnedCheckInProgress,
                                      controller: _password2TextController,
                                      confirmValidator: (text) => text !=
                                              _passwordTextController.text
                                          ? context.l10n.authPasswordsMismatch
                                          : null,
                                    ),
                                  ),
                                  Padding(
                                    padding: fieldSpacing,
                                    child: _SignupPasswordStrengthMeter(
                                      entropyBits: _passwordEntropyBits,
                                      maxEntropyBits: _maxEntropyBits,
                                      strengthLevel: _passwordStrengthLevel,
                                      showBreachWarning: _showBreachedError &&
                                          _passwordBreached,
                                      animationDuration: animationDuration,
                                    ),
                                  ),
                                  Padding(
                                    padding: fieldSpacing,
                                    child: _SignupInsecurePasswordNotice(
                                      reason: _visibleInsecurePasswordReason,
                                      allowInsecurePassword:
                                          allowInsecurePassword,
                                      loading: loading,
                                      pwnedCheckInProgress:
                                          _pwnedCheckInProgress,
                                      showAllowInsecureError:
                                          _showAllowInsecureError,
                                      animationDuration: animationDuration,
                                      resetTick: _allowInsecureResetTick,
                                      onChanged: (value) {
                                        setState(() {
                                          allowInsecurePassword = value;
                                          if (value) {
                                            _showAllowInsecureError = false;
                                            _showBreachedError = false;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Form(
                              key: _formKeys[2],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: fieldSpacing +
                                        EdgeInsets.only(top: spacing.m),
                                    child: FutureBuilder<String>(
                                      future: _captchaSrc,
                                      builder: (context, snapshot) {
                                        Widget captchaSurface;
                                        if (snapshot.hasData) {
                                          final url =
                                              snapshot.requireData.trim();
                                          captchaSurface = url.isEmpty
                                              ? const _CaptchaErrorMessage()
                                              : _CaptchaImage(
                                                  url: url,
                                                  animationDuration:
                                                      animationDuration,
                                                  showErrorMessageOnError: true,
                                                  onRetry:
                                                      _retryCaptchaAfterImageFailure,
                                                );
                                        } else if (snapshot.hasError) {
                                          captchaSurface =
                                              const _CaptchaErrorMessage();
                                        } else {
                                          captchaSurface = _CaptchaSkeleton(
                                            animationDuration:
                                                animationDuration,
                                          );
                                        }
                                        return Align(
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Semantics(
                                                  label: context.l10n
                                                      .signupCaptchaChallenge,
                                                  hint: context.l10n
                                                      .signupCaptchaInstructions,
                                                  image: true,
                                                  child: _CaptchaFrame(
                                                    size: captchaSize,
                                                    child: captchaSurface,
                                                  )),
                                              SizedBox(width: spacing.s),
                                              Semantics(
                                                button: true,
                                                enabled: !loading,
                                                label: context
                                                    .l10n.signupCaptchaReload,
                                                hint: context.l10n
                                                    .signupCaptchaReloadHint,
                                                child: AxiIconButton(
                                                  iconData:
                                                      LucideIcons.refreshCw,
                                                  tooltip: context
                                                      .l10n.signupCaptchaReload,
                                                  onPressed: loading
                                                      ? null
                                                      : () => _reloadCaptcha(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: fieldSpacing,
                                    child: SizedBox(
                                      width: captchaSize.width,
                                      child: AxiTextFormField(
                                        autocorrect: false,
                                        keyboardType: TextInputType.number,
                                        placeholder: Text(
                                          context.l10n.signupCaptchaPlaceholder,
                                        ),
                                        enabled: !loading,
                                        controller: _captchaTextController,
                                        validator: (text) {
                                          final value = text;
                                          if (value.isEmpty) {
                                            return context
                                                .l10n.signupCaptchaValidation;
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: fieldSpacing,
                                    child: TermsCheckbox(enabled: !loading),
                                  ),
                                  Padding(
                                    padding: fieldSpacing,
                                    child: AxiCheckboxFormField(
                                      key: _rememberMeFieldKey,
                                      enabled: !loading,
                                      initialValue: rememberMe,
                                      inputLabel: Text(
                                        context.l10n.authRememberMeLabel,
                                      ),
                                      onChanged: (value) async {
                                        setState(() {
                                          rememberMe = value;
                                        });
                                        await context
                                            .read<AuthenticationCubit>()
                                            .persistRememberMeChoice(
                                              rememberMe,
                                            );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ][_currentIndex],
                        ),
                      ),
                    ),
                    const SizedBox.square(),
                    Padding(
                      padding: horizontalPadding,
                      child: Builder(
                        builder: (context) {
                          final isPasswordStep = _currentIndex == 1;
                          final isCheckingPwned =
                              isPasswordStep && _pwnedCheckInProgress;
                          final showBackButton = _currentIndex >= 1;
                          final showNextButton =
                              _currentIndex < _formKeys.length - 1;
                          final showSubmitButton = !showNextButton;

                          final backButton = AxiAnimatedSize(
                            duration: animationDuration,
                            curve: Curves.easeInOut,
                            alignment: Alignment.centerLeft,
                            child: showBackButton
                                ? Padding(
                                    padding: EdgeInsets.only(right: spacing.s),
                                    child: AxiButton.secondary(
                                      onPressed: loading || isCheckingPwned
                                          ? null
                                          : () {
                                              setState(() {
                                                _currentIndex--;
                                              });
                                            },
                                      child: Text(context.l10n.commonBack),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          );

                          final continueButton = showNextButton
                              ? Padding(
                                  padding: EdgeInsets.only(
                                    right: showSubmitButton ? spacing.s : 0,
                                  ),
                                  child: AxiButton.primary(
                                    loading: isCheckingPwned,
                                    onPressed: loading ||
                                            isCheckingPwned ||
                                            avatarState.processing
                                        ? null
                                        : () async {
                                            await _handleContinuePressed(
                                              context,
                                            );
                                          },
                                    child: Text(context.l10n.signupContinue),
                                  ),
                                )
                              : const SizedBox.shrink();

                          final submitButton = showSubmitButton
                              ? AxiButton.primary(
                                  loading: loading,
                                  onPressed: loading ||
                                          cleanupBlocked ||
                                          avatarState.processing
                                      ? null
                                      : () => _onPressed(context),
                                  child: Text(context.l10n.authSignUp),
                                )
                              : const SizedBox.shrink();

                          return Wrap(
                            spacing: 0,
                            runSpacing: spacing.s,
                            children: [
                              backButton,
                              if (showNextButton) continueButton,
                              if (showSubmitButton) submitButton,
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _SignupProgressMeter extends StatelessWidget {
  const _SignupProgressMeter({
    required this.progressValue,
    required this.currentStepIndex,
    required this.totalSteps,
    required this.currentStepLabel,
    required this.animationDuration,
  });

  final double progressValue;
  final int currentStepIndex;
  final int totalSteps;
  final String currentStepLabel;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final motion = context.motion;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final targetPercent = (progressValue * 100).clamp(0.0, 100.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: targetPercent),
      duration: animationDuration,
      curve: Curves.easeInOut,
      builder: (context, animatedPercent, child) {
        final clampedPercent = animatedPercent.clamp(0.0, 100.0);
        final fillFraction = (clampedPercent / 100).clamp(0.0, 1.0);
        final currentStepNumber =
            (currentStepIndex + 1).clamp(1, totalSteps).toInt();
        final percentLabel =
            context.l10n.commonPercentLabel(clampedPercent.round());
        final barHeight = sizing.progressIndicatorStrokeWidth * 4;
        final barRadius = BorderRadius.circular(sizing.containerRadius);
        return Semantics(
          label: context.l10n.signupProgressLabel,
          value: context.l10n.signupProgressValue(
            currentStepNumber,
            totalSteps,
            currentStepLabel,
            clampedPercent.round(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.signupProgressSection,
                    style: context.textTheme.muted,
                  ),
                  Text(
                    percentLabel,
                    style: context.textTheme.muted,
                  ),
                ],
              ),
              SizedBox(height: spacing.s),
              Stack(
                children: [
                  Container(
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: colors.muted.withValues(
                        alpha: motion.tapHoverAlpha,
                      ),
                      borderRadius: barRadius,
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: fillFraction,
                    child: Container(
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: barRadius,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.m),
            ],
          ),
        );
      },
    );
  }
}

class _SignupPasswordStrengthMeter extends StatelessWidget {
  const _SignupPasswordStrengthMeter({
    required this.entropyBits,
    required this.maxEntropyBits,
    required this.strengthLevel,
    required this.showBreachWarning,
    required this.animationDuration,
  });

  final double entropyBits;
  final double maxEntropyBits;
  final _PasswordStrengthLevel strengthLevel;
  final bool showBreachWarning;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final motion = context.motion;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final targetBits = entropyBits.clamp(0.0, maxEntropyBits);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: targetBits),
      duration: animationDuration,
      curve: Curves.easeInOut,
      builder: (context, animatedBits, child) {
        final normalized = (animatedBits / maxEntropyBits).clamp(0.0, 1.0);
        final fillColor = _colorForLevel(strengthLevel, colors);
        final barHeight = sizing.progressIndicatorStrokeWidth * 4;
        final barRadius = BorderRadius.circular(sizing.containerRadius);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.signupPasswordStrength,
                  style: context.textTheme.muted,
                ),
                Text(
                  _labelForLevel(strengthLevel, context.l10n),
                  style: context.textTheme.muted.copyWith(color: fillColor),
                ),
              ],
            ),
            SizedBox(height: spacing.s),
            Stack(
              children: [
                Container(
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: colors.muted.withValues(
                      alpha: motion.tapHoverAlpha,
                    ),
                    borderRadius: barRadius,
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: normalized,
                  child: Container(
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: barRadius,
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: animationDuration,
              child: showBreachWarning
                  ? Padding(
                      key: const ValueKey('breach-warning'),
                      padding: EdgeInsets.only(top: spacing.s),
                      child: Text(
                        context.l10n.signupPasswordBreached,
                        style: context.textTheme.muted.copyWith(
                          color: colors.destructive,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  static String _labelForLevel(
    _PasswordStrengthLevel level,
    AppLocalizations l10n,
  ) {
    switch (level) {
      case _PasswordStrengthLevel.empty:
        return l10n.signupStrengthNone;
      case _PasswordStrengthLevel.weak:
        return l10n.signupStrengthWeak;
      case _PasswordStrengthLevel.medium:
        return l10n.signupStrengthMedium;
      case _PasswordStrengthLevel.stronger:
        return l10n.signupStrengthStronger;
    }
  }

  static Color _colorForLevel(
    _PasswordStrengthLevel level,
    ShadColorScheme colors,
  ) {
    switch (level) {
      case _PasswordStrengthLevel.weak:
      case _PasswordStrengthLevel.empty:
        return colors.destructive;
      case _PasswordStrengthLevel.medium:
        return axiWarning;
      case _PasswordStrengthLevel.stronger:
        return axiGreen;
    }
  }
}

class _SignupInsecurePasswordNotice extends StatelessWidget {
  const _SignupInsecurePasswordNotice({
    required this.reason,
    required this.allowInsecurePassword,
    required this.loading,
    required this.pwnedCheckInProgress,
    required this.showAllowInsecureError,
    required this.animationDuration,
    required this.resetTick,
    required this.onChanged,
  });

  final _InsecurePasswordReason? reason;
  final bool allowInsecurePassword;
  final bool loading;
  final bool pwnedCheckInProgress;
  final bool showAllowInsecureError;
  final Duration animationDuration;
  final int resetTick;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return AnimatedSwitcher(
      duration: animationDuration,
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      child: reason == null
          ? const SizedBox.shrink()
          : Column(
              key: ValueKey(reason),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AxiCheckboxFormField(
                  key: ValueKey('${reason!.name}-$resetTick'),
                  enabled: !loading && !pwnedCheckInProgress,
                  initialValue: allowInsecurePassword,
                  inputLabel: Text(context.l10n.signupRiskAcknowledgement),
                  inputSublabel:
                      Text(_reasonDescription(reason!, context.l10n)),
                  onChanged: onChanged,
                ),
                AnimatedOpacity(
                  opacity:
                      showAllowInsecureError && !allowInsecurePassword ? 1 : 0,
                  duration: animationDuration,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: spacing.xs,
                      top: spacing.xs,
                    ),
                    child: Text(
                      context.l10n.signupRiskError,
                      style: context.textTheme.small,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  static String _reasonDescription(
    _InsecurePasswordReason reason,
    AppLocalizations l10n,
  ) {
    if (reason == _InsecurePasswordReason.breached) {
      return l10n.signupRiskAllowBreach;
    }
    return l10n.signupRiskAllowWeak;
  }
}

class _CaptchaFrame extends StatelessWidget {
  const _CaptchaFrame({required this.child, required this.size});

  final Widget child;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final radius = BorderRadius.circular(context.sizing.containerRadius);
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: colors.border),
        color: colors.card,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox.expand(child: child),
      ),
    );
  }
}

class _CaptchaImage extends StatefulWidget {
  const _CaptchaImage({
    required this.url,
    required this.animationDuration,
    required this.onRetry,
    required this.showErrorMessageOnError,
  });

  final String url;
  final Duration animationDuration;
  final VoidCallback onRetry;
  final bool showErrorMessageOnError;

  @override
  State<_CaptchaImage> createState() => _CaptchaImageState();
}

class _CaptchaImageState extends State<_CaptchaImage> {
  int _retryCount = 0;

  @override
  void didUpdateWidget(covariant _CaptchaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _retryCount = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      widget.url,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      loadingBuilder: (context, child, loadingProgress) {
        final ready = loadingProgress == null;
        return AnimatedSwitcher(
          duration: widget.animationDuration,
          child: ready
              ? child
              : _CaptchaSkeleton(animationDuration: widget.animationDuration),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        const maxAttempts = 1;
        if (_retryCount < maxAttempts - 1) {
          _retryCount++;
          imageCache.evict(NetworkImage(widget.url));
          return _CaptchaSkeleton(animationDuration: widget.animationDuration);
        }
        if (_retryCount == maxAttempts - 1) {
          _retryCount++;
          widget.onRetry();
        }
        if (widget.showErrorMessageOnError) {
          return const _CaptchaErrorMessage();
        }
        return _CaptchaSkeleton(animationDuration: widget.animationDuration);
      },
    );
  }
}

class _CaptchaSkeleton extends StatefulWidget {
  const _CaptchaSkeleton({required this.animationDuration});

  final Duration animationDuration;

  @override
  State<_CaptchaSkeleton> createState() => _CaptchaSkeletonState();
}

class _CaptchaSkeletonState extends State<_CaptchaSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.animationDuration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animationDuration != Duration.zero) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _CaptchaSkeleton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationDuration == widget.animationDuration) {
      return;
    }
    _controller.duration = widget.animationDuration;
    if (widget.animationDuration == Duration.zero) {
      _controller.stop();
      _controller.value = 0;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final base =
        context.colorScheme.border.withValues(alpha: motion.tapHoverAlpha);
    final highlight =
        context.colorScheme.card.withValues(alpha: motion.tapFocusAlpha);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final shimmer = _controller.value;
          final start = (shimmer - 0.25).clamp(0.0, 1.0);
          final mid = shimmer.clamp(0.0, 1.0);
          final end = (shimmer + 0.25).clamp(0.0, 1.0);
          return SizedBox.expand(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [base, highlight, base],
                  stops: [start, mid, end],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CaptchaErrorMessage extends StatelessWidget {
  const _CaptchaErrorMessage();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Center(
        child: Text(
          context.l10n.signupCaptchaErrorMessage,
          textAlign: TextAlign.center,
          style: context.textTheme.muted,
        ),
      ),
    );
  }
}
