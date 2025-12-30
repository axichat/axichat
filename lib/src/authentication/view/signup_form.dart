import 'dart:async';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/view/widgets/endpoint_config_sheet.dart';
import 'package:axichat/src/authentication/view/terms_checkbox.dart';
import 'package:axichat/src/avatar/bloc/signup_avatar_cubit.dart';
import 'package:axichat/src/avatar/view/widgets/signup_avatar_editor_panel.dart';
import 'package:axichat/src/avatar/view/widgets/signup_avatar_selector.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/xml_safety.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/notifications/view/notification_request.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:xml/xml.dart';

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

const _strengthMediumColor = Color(0xFFF97316);
const _strengthStrongColor = Color(0xFF22C55E);
const int _captchaXmlMaxBytes = 64 * 1024;
const int _captchaXmlMaxNodes = 4000;
const int _captchaXmlMaxDepth = 32;
const Duration _captchaXmlMaxParseDuration = Duration(milliseconds: 120);
const int _httpOkStatus = 200;
const XmlParseLimits _captchaXmlParseLimits = XmlParseLimits(
  maxBytes: _captchaXmlMaxBytes,
  maxNodes: _captchaXmlMaxNodes,
  maxDepth: _captchaXmlMaxDepth,
  maxDuration: _captchaXmlMaxParseDuration,
);

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
  bool _captchaHasLoadedOnce = false;
  Timer? _captchaRetryTimer;
  String? _lastCaptchaServer;
  bool _showAvatarEditor = false;

  var _currentIndex = 0;
  String? _errorText;
  bool? _lastReportedLoading;
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
    _captchaRetryTimer?.cancel();
    widget.onLoadingChanged?.call(false);
    _lastReportedLoading = null;
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context
        .read<SignupAvatarCubit>()
        .setVisible(widget.visible, context.colorScheme);
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

  void _notifyLoadingChanged(bool loading) {
    if (_lastReportedLoading == loading) {
      return;
    }
    _lastReportedLoading = loading;
    final callback = widget.onLoadingChanged;
    if (callback == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      callback(loading);
    });
  }

  @override
  void didUpdateWidget(covariant SignupForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      context
          .read<SignupAvatarCubit>()
          .setVisible(widget.visible, context.colorScheme);
    }
  }

  String? _avatarErrorText(
    SignupAvatarState avatarState,
    AppLocalizations l10n,
  ) {
    final error = avatarState.error;
    if (error == null) {
      return null;
    }
    return switch (error.type) {
      SignupAvatarErrorType.openFailed => l10n.signupAvatarOpenError,
      SignupAvatarErrorType.readFailed => l10n.signupAvatarReadError,
      SignupAvatarErrorType.invalidImage => l10n.signupAvatarInvalidImage,
      SignupAvatarErrorType.sizeExceeded => l10n.signupAvatarSizeError(
          error.maxKilobytes ?? SignupAvatarCubit.avatarMaxKilobytes,
        ),
      SignupAvatarErrorType.processingFailed => avatarState.sourceBytes != null
          ? l10n.signupAvatarProcessError
          : l10n.signupAvatarRenderError,
    };
  }

  void _onPressed(BuildContext context) async {
    if (context.read<SignupAvatarCubit>().state.processing) return;
    if (context.read<SignupAvatarCubit>().state.avatar == null) {
      context.read<SignupAvatarCubit>().materializeCurrentCarouselAvatar();
    }
    if (context.read<SignupAvatarCubit>().state.processing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final splitSrc = (await _captchaSrc).split('/');
    if (!context.mounted || _formKeys.last.currentState?.validate() == false) {
      return;
    }
    widget.onSubmitStart?.call();
    await context.read<AuthenticationCubit>().signup(
          username: _jidTextController.value.text,
          password: _passwordTextController.value.text,
          confirmPassword: _password2TextController.value.text,
          captchaID: splitSrc[splitSrc.indexOf('captcha') + 1],
          captcha: _captchaTextController.value.text,
          rememberMe: rememberMe,
          avatar: context.read<SignupAvatarCubit>().state.avatar,
        );
  }

  Future<String> _loadCaptchaSrc() async {
    XmlDocument? document;
    try {
      final registrationUrl =
          context.read<AuthenticationCubit>().registrationUrl;
      _lastCaptchaServer = context.read<AuthenticationCubit>().state.server;
      final response = await http.get(registrationUrl);
      if (response.statusCode != _httpOkStatus) return '';
      final bodyBytes = response.bodyBytes;
      if (bodyBytes.length > _captchaXmlMaxBytes) return '';
      document = tryParseXml(response.body, _captchaXmlParseLimits);
      if (document == null) return '';
    } on http.ClientException catch (_) {
      return '';
    } on Exception catch (_) {
      return '';
    }
    return document.findAllElements('img').firstOrNull?.getAttribute('src') ??
        '';
  }

  void _reloadCaptcha({bool resetFirstLoad = false}) {
    _captchaRetryTimer?.cancel();
    _captchaRetryTimer = null;
    if (resetFirstLoad) {
      _captchaHasLoadedOnce = false;
    }
    _captchaTextController.clear();
    if (!mounted) return;
    setState(() {
      _captchaSrc = _loadCaptchaSrc();
    });
  }

  void _scheduleInitialCaptchaRetry() {
    if (_captchaHasLoadedOnce || _captchaRetryTimer != null) {
      return;
    }
    _captchaRetryTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted || _captchaHasLoadedOnce) {
        _captchaRetryTimer?.cancel();
        _captchaRetryTimer = null;
        return;
      }
      _captchaRetryTimer = null;
      _reloadCaptcha(resetFirstLoad: true);
    });
  }

  void _openAvatarEditor() {
    if (context.read<SignupAvatarCubit>().state.processing) return;
    setState(() {
      _showAvatarEditor = true;
    });
  }

  void _markCaptchaLoaded() {
    if (_captchaHasLoadedOnce) return;
    _captchaRetryTimer?.cancel();
    _captchaRetryTimer = null;
    if (!mounted) return;
    setState(() {
      _captchaHasLoadedOnce = true;
    });
  }

  static const captchaSize = Size(180, 70);
  static const _progressSegmentCount = 3;

  String get _currentStepLabel {
    final l10n = context.l10n;
    switch (_currentIndex) {
      case 0:
        return l10n.signupStepUsername;
      case 1:
        return l10n.signupStepPassword;
      case 2:
        return l10n.signupStepCaptcha;
      default:
        return l10n.signupStepSetup;
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

  double get _progressValue => _completedStepCount / _progressSegmentCount;

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
    final password = _passwordTextController.text;
    final isWeak = _passwordStrengthLevel == _PasswordStrengthLevel.weak;
    if ((isWeak || _passwordBreached) && !allowInsecurePassword) {
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
    final notPwned = await context
        .read<AuthenticationCubit>()
        .checkNotPwned(password: password);
    if (!mounted) return;
    setState(() {
      _pwnedCheckInProgress = false;
    });

    if (!notPwned) {
      setState(() {
        _passwordBreached = true;
        _lastBreachedPassword = password;
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
        if (state is AuthenticationSignupFailure) {
          _reloadCaptcha(resetFirstLoad: true);
          setState(() {
            _errorText = state.errorText;
          });
        }
      },
      builder: (context, state) {
        final l10n = context.l10n;
        return BlocBuilder<SignupAvatarCubit, SignupAvatarState>(
          builder: (context, avatarState) {
            final avatarErrorText = _avatarErrorText(avatarState, l10n);
            if (_lastCaptchaServer != state.server) {
              _lastCaptchaServer = state.server;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _reloadCaptcha(resetFirstLoad: true);
              });
            }
            final bool onSubmitStep = _currentIndex == _formKeys.length - 1;
            final bool signupFlowActive =
                state is AuthenticationSignUpInProgress &&
                    state.fromSubmission &&
                    onSubmitStep;
            final bool latchActive = (_lastReportedLoading ?? false) &&
                (state is AuthenticationLogInInProgress ||
                    state is AuthenticationComplete);
            final loading = signupFlowActive || latchActive;
            _notifyLoadingChanged(loading);
            final cleanupBlocked =
                state is AuthenticationSignupFailure && state.isCleanupBlocked;
            const horizontalPadding = EdgeInsets.symmetric(horizontal: 8.0);
            const errorPadding = EdgeInsets.fromLTRB(8, 12, 8, 8);
            const globalErrorPadding = EdgeInsets.fromLTRB(8, 10, 8, 20);
            const fieldSpacing = EdgeInsets.symmetric(vertical: 6.0);
            final animationDuration =
                context.watch<SettingsCubit>().animationDuration;
            final usernameDescriptionHeight = _measureTextHeight(
              context,
              text: l10n.authUsernameCaseInsensitive,
              style: context.textTheme.small,
            );
            final showGlobalError =
                !_showBreachedError && (_errorText?.trim().isNotEmpty ?? false);
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
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
                        l10n.signupTitle,
                        style: context.modalHeaderTextStyle,
                      ),
                    ),
                    Padding(
                      padding: globalErrorPadding,
                      child: AnimatedSwitcher(
                        duration: animationDuration,
                        child: showGlobalError
                            ? Semantics(
                                liveRegion: true,
                                container: true,
                                label: l10n.signupErrorPrefix(_errorText!),
                                child: Text(
                                  _errorText!,
                                  key: const ValueKey(
                                      'signup-global-error-text'),
                                  style: TextStyle(
                                    color: context.colorScheme.destructive,
                                  ),
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
                            context.read<NotificationService>(),
                        capability: context.read<Capability>(),
                      ),
                    ),
                    const SizedBox.square(dimension: 16.0),
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
                                  spacing: 10.0,
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
                                        const SizedBox(width: 12),
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6.0,
                                              ),
                                              child: Text(l10n
                                                  .authUsernameCaseInsensitive),
                                            ),
                                            placeholder:
                                                Text(l10n.authUsername),
                                            enabled: !loading,
                                            controller: _jidTextController,
                                            trailing: EndpointSuffix(
                                                server: state.server),
                                            validator: (text) {
                                              if (text.isEmpty) {
                                                return l10n
                                                    .authUsernameRequired;
                                              }
                                              if (!_usernamePattern
                                                  .hasMatch(text)) {
                                                return l10n.authUsernameRules;
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
                                        style: TextStyle(
                                          color:
                                              context.colorScheme.destructive,
                                          fontSize: 12,
                                        ),
                                      ),
                                    if (_showAvatarEditor)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 12.0),
                                        child: Center(
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth: math.min(
                                                MediaQuery.sizeOf(context)
                                                    .width,
                                                960,
                                              ),
                                            ),
                                            child: Stack(
                                              children: [
                                                SignupAvatarEditorPanel(
                                                  mode: avatarState.editorMode,
                                                  avatarBytes: avatarState
                                                      .displayedBytes,
                                                  cropBytes:
                                                      avatarState.sourceBytes,
                                                  cropRect:
                                                      avatarState.cropRect,
                                                  imageWidth:
                                                      avatarState.imageWidth,
                                                  imageHeight:
                                                      avatarState.imageHeight,
                                                  onCropChanged: (rect) => context
                                                      .read<SignupAvatarCubit>()
                                                      .updateCropRect(rect),
                                                  onCropReset: context
                                                      .read<SignupAvatarCubit>()
                                                      .resetCrop,
                                                  onShuffle: () => context
                                                      .read<SignupAvatarCubit>()
                                                      .shuffleTemplate(
                                                        context.colorScheme,
                                                      ),
                                                  onUpload: context
                                                      .read<SignupAvatarCubit>()
                                                      .pickAvatarFromFiles,
                                                  canShuffleBackground:
                                                      avatarState
                                                          .canShuffleBackground,
                                                  onShuffleBackground: avatarState
                                                          .canShuffleBackground
                                                      ? () => context
                                                          .read<
                                                              SignupAvatarCubit>()
                                                          .shuffleBackground(
                                                            context.colorScheme,
                                                          )
                                                      : null,
                                                ),
                                                Positioned(
                                                  top: 6,
                                                  right: 6,
                                                  child: AxiIconButton(
                                                    iconData: LucideIcons.x,
                                                    tooltip: l10n.commonClose,
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
                                      confirmValidator: (text) =>
                                          text != _passwordTextController.text
                                              ? l10n.authPasswordsMismatch
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
                                        const EdgeInsets.only(top: 20),
                                    child: FutureBuilder<String>(
                                      future: _captchaSrc,
                                      builder: (context, snapshot) {
                                        final hasValidUrl = snapshot.hasData &&
                                            (snapshot.data?.isNotEmpty ??
                                                false);
                                        final encounteredError = snapshot
                                                .hasError ||
                                            (snapshot.hasData && !hasValidUrl);
                                        final persistentError =
                                            encounteredError &&
                                                _captchaHasLoadedOnce;
                                        final describingLoading =
                                            (!snapshot.hasData &&
                                                    !encounteredError) ||
                                                (encounteredError &&
                                                    !_captchaHasLoadedOnce);
                                        Widget captchaSurface;
                                        if (encounteredError) {
                                          if (_captchaHasLoadedOnce) {
                                            captchaSurface =
                                                const _CaptchaErrorMessage();
                                          } else {
                                            _scheduleInitialCaptchaRetry();
                                            captchaSurface =
                                                const _CaptchaSkeleton();
                                          }
                                        } else if (!snapshot.hasData) {
                                          captchaSurface =
                                              const _CaptchaSkeleton();
                                        } else {
                                          final captchaUrl =
                                              snapshot.requireData;
                                          captchaSurface = _CaptchaImage(
                                            url: captchaUrl,
                                            showErrorMessageOnError:
                                                _captchaHasLoadedOnce,
                                            onLoaded: _markCaptchaLoaded,
                                            onInitialError:
                                                _scheduleInitialCaptchaRetry,
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
                                                label: persistentError
                                                    ? l10n
                                                        .signupCaptchaUnavailable
                                                    : l10n
                                                        .signupCaptchaChallenge,
                                                hint: persistentError
                                                    ? l10n.signupCaptchaFailed
                                                    : describingLoading
                                                        ? l10n
                                                            .signupCaptchaLoading
                                                        : l10n
                                                            .signupCaptchaInstructions,
                                                image: !persistentError &&
                                                    hasValidUrl,
                                                child: persistentError
                                                    ? _CaptchaFrame(
                                                        child: captchaSurface,
                                                      )
                                                    : ExcludeSemantics(
                                                        child: _CaptchaFrame(
                                                          child: captchaSurface,
                                                        ),
                                                      ),
                                              ),
                                              const SizedBox(width: 12),
                                              Semantics(
                                                button: true,
                                                enabled: !loading,
                                                label: l10n.signupCaptchaReload,
                                                hint: l10n
                                                    .signupCaptchaReloadHint,
                                                child: AxiIconButton(
                                                  iconData:
                                                      LucideIcons.refreshCw,
                                                  tooltip:
                                                      l10n.signupCaptchaReload,
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
                                        placeholder:
                                            Text(l10n.signupCaptchaPlaceholder),
                                        enabled: !loading,
                                        controller: _captchaTextController,
                                        validator: (text) {
                                          if (text.isEmpty) {
                                            return l10n.signupCaptchaValidation;
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: fieldSpacing,
                                    child: TermsCheckbox(
                                      enabled: !loading,
                                    ),
                                  ),
                                  Padding(
                                    padding: fieldSpacing,
                                    child: AxiCheckboxFormField(
                                      key: _rememberMeFieldKey,
                                      enabled: !loading,
                                      initialValue: rememberMe,
                                      inputLabel:
                                          Text(l10n.authRememberMeLabel),
                                      onChanged: (value) {
                                        setState(() {
                                          rememberMe = value;
                                        });
                                        unawaited(
                                          context
                                              .read<AuthenticationCubit>()
                                              .persistRememberMeChoice(value),
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
                    const SizedBox.square(dimension: 16.0),
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
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ShadButton.secondary(
                                      enabled: !loading && !isCheckingPwned,
                                      onPressed: () {
                                        setState(() {
                                          _currentIndex--;
                                        });
                                      },
                                      child: Text(l10n.commonBack),
                                    ).withTapBounce(
                                      enabled: !loading && !isCheckingPwned,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          );

                          final continueButton = showNextButton
                              ? Padding(
                                  padding: EdgeInsets.only(
                                    right: showSubmitButton ? 8 : 0,
                                  ),
                                  child: ShadButton(
                                    enabled: !loading &&
                                        !isCheckingPwned &&
                                        !avatarState.processing,
                                    onPressed: () async {
                                      await _handleContinuePressed(context);
                                    },
                                    leading: AnimatedCrossFade(
                                      crossFadeState: isCheckingPwned
                                          ? CrossFadeState.showSecond
                                          : CrossFadeState.showFirst,
                                      duration: animationDuration,
                                      firstChild: const SizedBox(),
                                      secondChild: AxiProgressIndicator(
                                        color: context
                                            .colorScheme.primaryForeground,
                                        semanticsLabel:
                                            l10n.authPasswordPending,
                                      ),
                                    ),
                                    trailing: const SizedBox.shrink(),
                                    child: Text(l10n.signupContinue),
                                  ).withTapBounce(
                                    enabled: !loading && !isCheckingPwned,
                                  ),
                                )
                              : const SizedBox.shrink();

                          final submitButton = showSubmitButton
                              ? ShadButton(
                                  enabled: !loading &&
                                      !cleanupBlocked &&
                                      !avatarState.processing,
                                  onPressed: cleanupBlocked
                                      ? null
                                      : () => _onPressed(context),
                                  leading: AnimatedCrossFade(
                                    crossFadeState: loading
                                        ? CrossFadeState.showSecond
                                        : CrossFadeState.showFirst,
                                    duration: animationDuration,
                                    firstChild: const SizedBox(),
                                    secondChild: AxiProgressIndicator(
                                      color:
                                          context.colorScheme.primaryForeground,
                                      semanticsLabel: l10n.authSignupPending,
                                    ),
                                  ),
                                  trailing: const SizedBox.shrink(),
                                  child: Text(l10n.authSignUp),
                                ).withTapBounce(
                                  enabled: !loading && !cleanupBlocked,
                                )
                              : const SizedBox.shrink();

                          return Wrap(
                            spacing: 0,
                            runSpacing: 8,
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

/*
class _AvatarSizeException implements Exception {
  const _AvatarSizeException();
}

class _AvatarSelection {
  const _AvatarSelection({
    required this.template,
    required this.background,
  });

  final AvatarTemplate template;
  final Color background;
}

class _CarouselAvatar {
  const _CarouselAvatar({
    required this.bytes,
    required this.sourceBytes,
    required this.background,
    this.template,
    this.category,
  });

  final Uint8List bytes;
  final Uint8List sourceBytes;
  final AvatarTemplate? template;
  final AvatarTemplateCategory? category;
  final Color background;
}

class _SignupAvatarEditorPanel extends StatefulWidget {
  const _SignupAvatarEditorPanel({
    required this.mode,
    required this.avatarBytesListenable,
    required this.onShuffle,
    required this.onUpload,
    required this.canShuffleBackground,
    this.onShuffleBackground,
    this.sourceBytesProvider,
    this.cropRectProvider,
    this.imageWidthProvider,
    this.imageHeightProvider,
    this.onCropChanged,
    this.onCropReset,
  });

  final _AvatarEditorMode mode;
  final ValueListenable<Uint8List?> avatarBytesListenable;
  final Future<void> Function() onShuffle;
  final Future<void> Function() onUpload;
  final bool canShuffleBackground;
  final Future<void> Function()? onShuffleBackground;
  final Uint8List? Function()? sourceBytesProvider;
  final Rect? Function()? cropRectProvider;
  final double? Function()? imageWidthProvider;
  final double? Function()? imageHeightProvider;
  final ValueChanged<Rect>? onCropChanged;
  final VoidCallback? onCropReset;

  @override
  State<_SignupAvatarEditorPanel> createState() =>
      _SignupAvatarEditorPanelState();
}

class _SignupAvatarEditorPanelState extends State<_SignupAvatarEditorPanel> {
  bool _shuffling = false;
  bool _shufflingBackground = false;
  int _previewVersion = 0;
  Uint8List? _lastPreviewBytes;
  Rect? _localCropRect;
  double? _lastImageWidth;
  double? _lastImageHeight;
  Rect? _pendingCropRect;
  bool _cropChangeScheduled = false;

  Future<void> _handleShuffle() async {
    if (_shuffling) return;
    setState(() => _shuffling = true);
    try {
      await widget.onShuffle();
    } finally {
      if (mounted) {
        setState(() => _shuffling = false);
      }
    }
  }

  Future<void> _handleShuffleBackground() async {
    final shuffleBackground = widget.onShuffleBackground;
    if (_shufflingBackground || shuffleBackground == null) {
      return;
    }
    setState(() => _shufflingBackground = true);
    try {
      await shuffleBackground();
    } finally {
      if (mounted) {
        setState(() => _shufflingBackground = false);
      }
    }
  }

  void _scheduleCropChange(Rect rect) {
    _pendingCropRect = rect;
    if (_cropChangeScheduled) return;
    _cropChangeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cropChangeScheduled = false;
      final next = _pendingCropRect;
      _pendingCropRect = null;
      if (!mounted || next == null) return;
      widget.onCropChanged?.call(next);
      setState(() => _localCropRect = next);
    });
  }

  void _handleCropReset() {
    final rect = widget.cropRectProvider?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onCropReset?.call();
      setState(() => _localCropRect = rect);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    const avatarActionSpacing = 8.0;
    final mode = widget.mode;
    final showCrop = mode == _AvatarEditorMode.cropOnly;
    final busy = _shuffling || _shufflingBackground;
    final cropBytes = showCrop
        ? widget.sourceBytesProvider?.call() ?? _lastPreviewBytes
        : null;
    final imageWidth = showCrop ? widget.imageWidthProvider?.call() : null;
    final imageHeight = showCrop ? widget.imageHeightProvider?.call() : null;
    if (imageWidth != null &&
        imageHeight != null &&
        (_lastImageWidth != imageWidth || _lastImageHeight != imageHeight)) {
      _lastImageWidth = imageWidth;
      _lastImageHeight = imageHeight;
      _localCropRect = null;
    }
    final canEditCrop = showCrop &&
        cropBytes != null &&
        imageWidth != null &&
        imageHeight != null &&
        imageWidth > 0 &&
        imageHeight > 0 &&
        widget.onCropChanged != null &&
        widget.onCropReset != null;

    Widget? cropper;
    if (canEditCrop) {
      final Uint8List safeBytes = cropBytes;
      final double safeImageWidth = imageWidth;
      final double safeImageHeight = imageHeight;
      cropper = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12.0,
        children: [
          Text(
            'Crop & focus',
            style: context.textTheme.small.copyWith(color: colors.foreground),
          ),
          Text(
            'Drag or resize the square to frame your avatar. Reset to center the selection.',
            style: context.textTheme.small.copyWith(
              color: colors.mutedForeground,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: AvatarCropper(
                bytes: safeBytes,
                imageWidth: safeImageWidth,
                imageHeight: safeImageHeight,
                cropRect: _localCropRect ??
                    widget.cropRectProvider?.call() ??
                    AvatarCropper.fallbackCropRect(
                      imageWidth: safeImageWidth,
                      imageHeight: safeImageHeight,
                      minCropSide: AvatarEditorCubit.minCropSide,
                    ),
                onCropChanged: _scheduleCropChange,
                onCropReset: _handleCropReset,
                colors: colors,
                borderRadius: context.radius,
                minCropSide: AvatarEditorCubit.minCropSide,
              ),
            ),
          ),
          Text(
            'Only the area inside the circle will appear in the final avatar.',
            style: context.textTheme.small.copyWith(
              color: colors.mutedForeground,
            ),
          ),
        ],
      );
    }

    final allowBackgroundShuffle =
        widget.canShuffleBackground && widget.onShuffleBackground != null;

    Widget preview = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 12.0,
      children: [
        ValueListenableBuilder<Uint8List?>(
          valueListenable: widget.avatarBytesListenable,
          builder: (_, bytes, __) {
            if (!identical(bytes, _lastPreviewBytes)) {
              _lastPreviewBytes = bytes;
              _previewVersion++;
            }
            final previewKey = ValueKey(_previewVersion);
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeIn,
              switchOutCurve: Curves.easeOut,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: child,
              ),
              child: AxiAvatar(
                key: previewKey,
                jid: 'avatar@axichat',
                size: 96,
                subscription: Subscription.none,
                presence: null,
                avatarBytes: bytes,
              ),
            );
          },
        ),
        Text(
          l10n.signupAvatarMenuDescription,
          style:
              context.textTheme.small.copyWith(color: colors.mutedForeground),
          textAlign: TextAlign.center,
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: avatarActionSpacing,
          runSpacing: avatarActionSpacing,
          children: [
            ShadButton(
              onPressed: busy ? null : _handleShuffle,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8.0,
                children: [
                  if (_shuffling)
                    SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.primaryForeground,
                        ),
                        backgroundColor:
                            colors.primaryForeground.withValues(alpha: 0.2),
                      ),
                    )
                  else
                    const Icon(LucideIcons.refreshCw, size: 20),
                  Text(l10n.signupAvatarShuffle),
                ],
              ),
            ).withTapBounce(),
            ShadButton.secondary(
              onPressed: busy || !allowBackgroundShuffle
                  ? null
                  : () => unawaited(_handleShuffleBackground()),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8.0,
                children: [
                  if (_shufflingBackground)
                    SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.secondaryForeground,
                        ),
                        backgroundColor:
                            colors.secondaryForeground.withValues(alpha: 0.2),
                      ),
                    )
                  else
                    const Icon(LucideIcons.palette, size: 20),
                  Text(l10n.signupAvatarBackgroundColor),
                ],
              ),
            ).withTapBounce(),
            ShadButton.outline(
              onPressed: busy ? null : () => unawaited(widget.onUpload()),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8.0,
                children: [
                  const Icon(LucideIcons.upload),
                  Text(l10n.signupAvatarUploadImage),
                ],
              ),
            ).withTapBounce(),
          ],
        ),
      ],
    );

    final previewAndCrop = showCrop && cropper != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12.0,
            children: [
              preview,
              cropper,
            ],
          )
        : preview;

    return ShadCard(
      padding: const EdgeInsets.all(12.0),
      child: previewAndCrop,
    );
  }
}

class _SignupAvatarSelector extends StatefulWidget {
  const _SignupAvatarSelector({
    required this.bytes,
    required this.username,
    required this.processing,
    required this.onTap,
  });

  final Uint8List? bytes;
  final String username;
  final bool processing;
  final VoidCallback onTap;

  @override
  State<_SignupAvatarSelector> createState() => _SignupAvatarSelectorState();
}

class _SignupAvatarSelectorState extends State<_SignupAvatarSelector> {
  static const _size = 56.0;
  bool _hovered = false;
  int _previewVersion = 0;

  @override
  void didUpdateWidget(covariant _SignupAvatarSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) {
      _previewVersion++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final displayJid = widget.username.isEmpty
        ? 'avatar@axichat'
        : '${widget.username}@preview';
    final overlayVisible = _hovered || widget.processing;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _hovered = true),
        onTapUp: (_) => setState(() => _hovered = false),
        onTapCancel: () => setState(() => _hovered = false),
        onTap: widget.onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: _size,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: AxiAvatar(
                  key: ValueKey(_previewVersion),
                  jid: displayJid,
                  size: _size,
                  subscription: Subscription.none,
                  presence: null,
                  avatarBytes: widget.bytes,
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: overlayVisible ? 0.8 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  color: colors.background.withAlpha((0.45 * 255).round()),
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.border),
                ),
                child: widget.processing
                    ? Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.foreground,
                          ),
                        ),
                      )
                    : Icon(
                        LucideIcons.pencil,
                        color: colors.foreground,
                        size: 22,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

*/
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
    final l10n = context.l10n;
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
        return Semantics(
          label: l10n.signupProgressLabel,
          value: l10n.signupProgressValue(
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
                    l10n.signupProgressSection,
                    style: context.textTheme.muted,
                  ),
                  Text(
                    '${clampedPercent.round()}%',
                    style: context.textTheme.muted.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.muted.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: fillFraction,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
    final l10n = context.l10n;
    final targetBits = entropyBits.clamp(0.0, maxEntropyBits);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: targetBits),
      duration: animationDuration,
      curve: Curves.easeInOut,
      builder: (context, animatedBits, child) {
        final normalized = (animatedBits / maxEntropyBits).clamp(0.0, 1.0);
        final fillColor = _colorForLevel(strengthLevel, colors);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.signupPasswordStrength,
                  style: context.textTheme.muted,
                ),
                Text(
                  _labelForLevel(strengthLevel, l10n),
                  style: context.textTheme.muted.copyWith(
                    color: fillColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.muted.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: normalized,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: BorderRadius.circular(999),
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
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l10n.signupPasswordBreached,
                        style: context.textTheme.muted.copyWith(
                          color: colors.destructive,
                          fontWeight: FontWeight.w600,
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
        return _strengthMediumColor;
      case _PasswordStrengthLevel.stronger:
        return _strengthStrongColor;
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
    final l10n = context.l10n;
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
                  inputLabel: Text(l10n.signupRiskAcknowledgement),
                  inputSublabel: Text(_reasonDescription(reason!, l10n)),
                  onChanged: onChanged,
                ),
                AnimatedOpacity(
                  opacity:
                      showAllowInsecureError && !allowInsecurePassword ? 1 : 0,
                  duration: animationDuration,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: Text(
                      l10n.signupRiskError,
                      style: TextStyle(
                        color: context.colorScheme.destructive,
                        fontSize: 12,
                      ),
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
  const _CaptchaFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final radius = BorderRadius.circular(14);
    return Container(
      width: _SignupFormState.captchaSize.width,
      height: _SignupFormState.captchaSize.height,
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
    required this.onLoaded,
    required this.onInitialError,
    required this.showErrorMessageOnError,
  });

  final String url;
  final VoidCallback onLoaded;
  final VoidCallback onInitialError;
  final bool showErrorMessageOnError;

  @override
  State<_CaptchaImage> createState() => _CaptchaImageState();
}

class _CaptchaImageState extends State<_CaptchaImage> {
  bool _isReady = false;
  bool _readyNotified = false;

  @override
  void didUpdateWidget(covariant _CaptchaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _isReady = false;
      _readyNotified = false;
    }
  }

  void _handleImageReady() {
    if (_readyNotified) return;
    _readyNotified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isReady = true;
      });
      widget.onLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget image = Image.network(
      widget.url,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      frameBuilder: (context, child, frame, _) {
        if (frame != null) {
          _handleImageReady();
        }
        return child;
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return child;
      },
      errorBuilder: (context, error, stackTrace) {
        if (widget.showErrorMessageOnError) {
          return const _CaptchaErrorMessage();
        }
        widget.onInitialError();
        return const _CaptchaSkeleton();
      },
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedOpacity(
          opacity: _isReady ? 0 : 1,
          duration: const Duration(milliseconds: 220),
          child: const _CaptchaSkeleton(),
        ),
        AnimatedOpacity(
          opacity: _isReady ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: image,
        ),
      ],
    );
  }
}

class _CaptchaSkeleton extends StatefulWidget {
  const _CaptchaSkeleton();

  @override
  State<_CaptchaSkeleton> createState() => _CaptchaSkeletonState();
}

class _CaptchaSkeletonState extends State<_CaptchaSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.colorScheme.border.withValues(alpha: 0.35);
    final highlight = context.colorScheme.card.withValues(alpha: 0.8);
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
    final l10n = context.l10n;
    return SizedBox.expand(
      child: Center(
        child: Text(
          l10n.signupCaptchaErrorMessage,
          textAlign: TextAlign.center,
          style: context.textTheme.muted.copyWith(
            color: context.colorScheme.destructive,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
