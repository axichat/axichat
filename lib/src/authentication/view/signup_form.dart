import 'dart:io';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/view/terms_checkbox.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/notifications/view/notification_request.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:xml/xml.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({super.key});

  static const title = 'Sign Up';

  @override
  State<SignupForm> createState() => _SignupFormState();
}

enum _PasswordStrengthLevel { empty, weak, medium, stronger }

enum _InsecurePasswordReason { weak, breached }

class _SignupFormState extends State<SignupForm> {
  late TextEditingController _jidTextController;
  late TextEditingController _passwordTextController;
  late TextEditingController _password2TextController;
  late TextEditingController _captchaTextController;
  static final _usernamePattern = RegExp(r'^[a-z][a-z0-9._-]{3,19}$');
  static final _digitCharacters = RegExp(r'[0-9]');
  static final _lowercaseCharacters = RegExp(r'[a-z]');
  static final _uppercaseCharacters = RegExp(r'[A-Z]');
  static final _symbolCharacters = RegExp(r'[^A-Za-z0-9]');
  static const double _maxEntropyBits = 120;
  static const double _weakEntropyThreshold = 50;
  static const double _strongEntropyThreshold = 80;
  static const _strengthMediumColor = Color(0xFFF97316);
  static const _strengthStrongColor = Color(0xFF22C55E);

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

  var _currentIndex = 0;
  String? _errorText;

  late Future<String> _captchaSrc = _loadCaptchaSrc();

  @override
  void initState() {
    super.initState();
    _captchaSrc = _loadCaptchaSrc();
    _jidTextController = TextEditingController()
      ..addListener(_handleFieldProgressChanged);
    _passwordTextController = TextEditingController()
      ..addListener(_handleFieldProgressChanged);
    _password2TextController = TextEditingController()
      ..addListener(_handleFieldProgressChanged);
    _captchaTextController = TextEditingController()
      ..addListener(_handleFieldProgressChanged);
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
    super.dispose();
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
    }
    setState(() {});
  }

  void _onPressed(BuildContext context) async {
    final splitSrc = (await _captchaSrc).split('/');
    if (!context.mounted || _formKeys.last.currentState?.validate() == false) {
      return;
    }
    await context.read<AuthenticationCubit>().signup(
          username: _jidTextController.value.text,
          password: _passwordTextController.value.text,
          confirmPassword: _password2TextController.value.text,
          captchaID: splitSrc[splitSrc.indexOf('captcha') + 1],
          captcha: _captchaTextController.value.text,
          rememberMe: rememberMe,
        );
  }

  Future<String> _loadCaptchaSrc() async {
    late final XmlDocument document;
    try {
      final response = await http.get(AuthenticationCubit.registrationUrl);
      if (response.statusCode != 200) return '';
      document = XmlDocument.parse(response.body);
    } on HttpException catch (_) {
      return '';
    } on XmlParserException catch (_) {
      return '';
    } on XmlTagException catch (_) {
      return '';
    }
    return document.findAllElements('img').firstOrNull?.getAttribute('src') ??
        '';
  }

  static const captchaSize = Size(180, 70);
  static const _progressSegmentCount = 3;

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

  Widget _buildProgressMeter(BuildContext context) {
    final colors = context.colorScheme;
    final duration = context.read<SettingsCubit>().animationDuration;
    final targetPercent = (_progressValue * 100).clamp(0.0, 100.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: targetPercent),
      duration: duration,
      curve: Curves.easeInOut,
      builder: (context, animatedPercent, child) {
        final clampedPercent = animatedPercent.clamp(0.0, 100.0);
        final fillFraction = (clampedPercent / 100).clamp(0.0, 1.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Account setup',
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
        );
      },
    );
  }

  Widget _buildPasswordStrengthMeter(BuildContext context) {
    final colors = context.colorScheme;
    final duration = context.read<SettingsCubit>().animationDuration;
    final targetBits = _passwordEntropyBits.clamp(0.0, _maxEntropyBits);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: targetBits),
      duration: duration,
      curve: Curves.easeInOut,
      builder: (context, animatedBits, child) {
        final normalized = (animatedBits / _maxEntropyBits).clamp(0.0, 1.0);
        final level = _passwordStrengthLevel;
        final fillColor = _strengthColor(level, colors);
        final showBreachWarning = _showBreachedError && _passwordBreached;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Password strength',
                  style: context.textTheme.muted,
                ),
                Text(
                  _strengthLabel(level),
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
              duration: duration,
              child: showBreachWarning
                  ? Padding(
                      key: const ValueKey('breach-warning'),
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'This password has been found in a hacked database.',
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

  String _strengthLabel(_PasswordStrengthLevel level) {
    switch (level) {
      case _PasswordStrengthLevel.empty:
        return 'None';
      case _PasswordStrengthLevel.weak:
        return 'Weak';
      case _PasswordStrengthLevel.medium:
        return 'Medium';
      case _PasswordStrengthLevel.stronger:
        return 'Stronger';
    }
  }

  Color _strengthColor(
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

  Widget _buildAllowInsecurePasswordNotice(
    BuildContext context,
    bool loading,
  ) {
    final duration = context.read<SettingsCubit>().animationDuration;
    final reason = _visibleInsecurePasswordReason;
    final showReasonMessage = reason == _InsecurePasswordReason.weak;
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      child: reason == null
          ? const SizedBox.shrink()
          : Column(
              key: ValueKey(reason),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showReasonMessage) ...[
                  Text(
                    _insecurePasswordMessage(reason),
                    style: context.textTheme.muted.copyWith(
                      color: context.colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                AxiCheckboxFormField(
                  key: ValueKey(
                    '${reason.name}-${allowInsecurePassword ? 1 : 0}',
                  ),
                  enabled: !loading && !_pwnedCheckInProgress,
                  initialValue: allowInsecurePassword,
                  inputLabel: const Text('I understand the risk'),
                  inputSublabel: Text(
                    reason == _InsecurePasswordReason.breached
                        ? 'Allow this password even though it appeared in a breach.'
                        : 'Allow this password even though it is considered weak.',
                  ),
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
                AnimatedOpacity(
                  opacity:
                      _showAllowInsecureError && !allowInsecurePassword ? 1 : 0,
                  duration: duration,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: Text(
                      'Check the box above to continue.',
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

  String _insecurePasswordMessage(_InsecurePasswordReason reason) {
    switch (reason) {
      case _InsecurePasswordReason.breached:
        return 'This password has been found in a hacked database.';
      case _InsecurePasswordReason.weak:
        return 'This password looks weak. Check the box below if you still want to use it.';
    }
  }

  Future<void> _handleContinuePressed(BuildContext context) async {
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
    return BlocConsumer<AuthenticationCubit, AuthenticationState>(
      // listenWhen: (previous, current) => current is AuthenticationSignupFailure && previous is!AuthenticationSignupFailure,
      listener: (context, state) {
        if (state is AuthenticationSignupFailure) {
          if (state.errorText.contains('captcha')) {
            setState(() {
              _captchaSrc = _loadCaptchaSrc();
            });
          }
          _errorText = state.errorText;
        }
      },
      builder: (context, state) {
        final loading = state is AuthenticationInProgress ||
            state is AuthenticationComplete;
        const horizontalPadding = EdgeInsets.symmetric(horizontal: 8.0);
        const fieldSpacing = EdgeInsets.symmetric(vertical: 6.0);
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: horizontalPadding,
                  child: _buildProgressMeter(context),
                ),
                Padding(
                  padding: horizontalPadding,
                  child: Text(
                    SignupForm.title,
                    style: context.textTheme.h3,
                  ),
                ),
                Padding(
                  padding: horizontalPadding,
                  child: Text(
                    _errorText ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colorScheme.destructive,
                    ),
                  ),
                ),
                Padding(
                  padding: horizontalPadding,
                  child: NotificationRequest(
                    notificationService: context.read<NotificationService>(),
                    capability: context.read<Capability>(),
                  ),
                ),
                const SizedBox.square(dimension: 16.0),
                Padding(
                  padding: horizontalPadding,
                  child: AnimatedSize(
                    duration: context.read<SettingsCubit>().animationDuration,
                    curve: Curves.easeIn,
                    child: AnimatedSwitcher(
                      duration: context.read<SettingsCubit>().animationDuration,
                      switchInCurve: Curves.easeIn,
                      switchOutCurve: Curves.easeOut,
                      transitionBuilder:
                          AnimatedSwitcher.defaultTransitionBuilder,
                      child: [
                        Form(
                          key: _formKeys[0],
                          child: Padding(
                            padding: fieldSpacing,
                            child: AxiTextFormField(
                              autocorrect: false,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-z0-9._-]'),
                                ),
                              ],
                              keyboardType: TextInputType.emailAddress,
                              description: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6.0),
                                child: Text('Case insensitive'),
                              ),
                              placeholder: const Text('Username'),
                              enabled: !loading,
                              controller: _jidTextController,
                              trailing: Text('@${state.server}'),
                              validator: (text) {
                                if (text.isEmpty) {
                                  return 'Enter a username';
                                }
                                if (!_usernamePattern.hasMatch(text)) {
                                  return '4-20 alphanumeric, allowing ".", "_" and "-".';
                                }
                                return null;
                              },
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
                                  enabled: !loading && !_pwnedCheckInProgress,
                                  controller: _passwordTextController,
                                ),
                              ),
                              Padding(
                                padding: fieldSpacing,
                                child: PasswordInput(
                                  enabled: !loading && !_pwnedCheckInProgress,
                                  controller: _password2TextController,
                                  confirmValidator: (text) =>
                                      text != _passwordTextController.text
                                          ? 'Passwords don\'t match'
                                          : null,
                                ),
                              ),
                              Padding(
                                padding: fieldSpacing,
                                child: _buildPasswordStrengthMeter(context),
                              ),
                              Padding(
                                padding: fieldSpacing,
                                child: _buildAllowInsecurePasswordNotice(
                                  context,
                                  loading,
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
                                padding: fieldSpacing,
                                child: FutureBuilder(
                                  future: _captchaSrc,
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return SizedBox(
                                        height: captchaSize.height,
                                        width: captchaSize.width,
                                        child: const Center(
                                          child: AxiProgressIndicator(),
                                        ),
                                      );
                                    }
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.network(
                                            snapshot.requireData,
                                            height: captchaSize.height,
                                            loadingBuilder: (_, child,
                                                    progress) =>
                                                progress == null
                                                    ? child
                                                    : const Center(
                                                        child:
                                                            AxiProgressIndicator()),
                                            errorBuilder: (_, __, ___) => Text(
                                              'Failed to load captcha, try again later.',
                                              style: TextStyle(
                                                color: context
                                                    .colorScheme.destructive,
                                              ),
                                            ),
                                          ),
                                          ShadIconButton.ghost(
                                            icon: const Icon(
                                                LucideIcons.refreshCw),
                                            onPressed: () => setState(() {
                                              _captchaSrc = _loadCaptchaSrc();
                                            }),
                                          ).withTapBounce(),
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
                                        const Text('Enter the above text'),
                                    enabled: !loading,
                                    controller: _captchaTextController,
                                    validator: (text) {
                                      if (text.isEmpty) {
                                        return 'Enter the text from the image';
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
                      final animationDuration =
                          context.read<SettingsCubit>().animationDuration;
                      return Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          AnimatedSwitcher(
                            duration: animationDuration,
                            child: _currentIndex >= 1
                                ? ShadButton.secondary(
                                    key: const ValueKey('signup-back-button'),
                                    enabled: !loading && !isCheckingPwned,
                                    onPressed: () => setState(() {
                                      _currentIndex--;
                                    }),
                                    child: const Text('Back'),
                                  ).withTapBounce(
                                    enabled: !loading && !isCheckingPwned)
                                : const SizedBox(
                                    key: ValueKey('signup-back-button-empty'),
                                  ),
                          ),
                          if (_currentIndex < _formKeys.length - 1)
                            ShadButton(
                              enabled: !loading && !isCheckingPwned,
                              onPressed: () async {
                                await _handleContinuePressed(context);
                              },
                              leading: AnimatedCrossFade(
                                crossFadeState: isCheckingPwned
                                    ? CrossFadeState.showSecond
                                    : CrossFadeState.showFirst,
                                duration: context
                                    .read<SettingsCubit>()
                                    .animationDuration,
                                firstChild: const SizedBox(),
                                secondChild: AxiProgressIndicator(
                                  color: context.colorScheme.primaryForeground,
                                  semanticsLabel: 'Checking password safety',
                                ),
                              ),
                              trailing: const SizedBox.shrink(),
                              child: const Text('Continue'),
                            ).withTapBounce(
                                enabled: !loading && !isCheckingPwned),
                          if (_currentIndex == _formKeys.length - 1)
                            ShadButton(
                              enabled: !loading,
                              onPressed: () => _onPressed(context),
                              leading: AnimatedCrossFade(
                                crossFadeState: loading
                                    ? CrossFadeState.showSecond
                                    : CrossFadeState.showFirst,
                                duration: context
                                    .read<SettingsCubit>()
                                    .animationDuration,
                                firstChild: const SizedBox(),
                                secondChild: AxiProgressIndicator(
                                  color: context.colorScheme.primaryForeground,
                                  semanticsLabel: 'Waiting for signup',
                                ),
                              ),
                              trailing: const SizedBox.shrink(),
                              child: const Text('Sign up'),
                            ).withTapBounce(enabled: !loading),
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
  }
}
