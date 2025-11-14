import 'dart:io';

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

class _SignupFormState extends State<SignupForm> {
  late TextEditingController _jidTextController;
  late TextEditingController _passwordTextController;
  late TextEditingController _password2TextController;
  late TextEditingController _captchaTextController;
  static final _usernamePattern = RegExp(r'^[a-z][a-z0-9._-]{3,19}$');

  final _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  var allowInsecurePassword = false;
  var rememberMe = true;

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

  bool get _isUsernameValid =>
      _usernamePattern.hasMatch(_jidTextController.text);

  bool get _passwordWithinBounds =>
      _passwordTextController.text.length >= passwordMinLength &&
      _passwordTextController.text.length <= passwordMaxLength;

  bool get _passwordsMatch =>
      _password2TextController.text.isNotEmpty &&
      _password2TextController.text == _passwordTextController.text;

  bool get _arePasswordsValid => _passwordWithinBounds && _passwordsMatch;

  bool get _captchaComplete => _captchaTextController.text.trim().isNotEmpty;

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
                                  enabled: !loading,
                                  controller: _passwordTextController,
                                ),
                              ),
                              Padding(
                                padding: fieldSpacing,
                                child: PasswordInput(
                                  enabled: !loading,
                                  controller: _password2TextController,
                                  confirmValidator: (text) =>
                                      text != _passwordTextController.text
                                          ? 'Passwords don\'t match'
                                          : null,
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
                                child: ShadCheckboxFormField(
                                  enabled: !loading,
                                  initialValue: false,
                                  inputLabel:
                                      const Text('Allow insecure password'),
                                  inputSublabel: const Text('Not recommended'),
                                  onChanged: (value) =>
                                      allowInsecurePassword = value,
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
                      return Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          if (_currentIndex >= 1)
                            ShadButton.secondary(
                              enabled: !loading,
                              onPressed: () => setState(() {
                                _currentIndex--;
                              }),
                              child: const Text('Back'),
                            ).withTapBounce(enabled: !loading),
                          if (_currentIndex < _formKeys.length - 1)
                            ShadButton(
                              enabled: !loading,
                              onPressed: () async {
                                if (_formKeys[_currentIndex]
                                        .currentState
                                        ?.validate() ==
                                    false) {
                                  return;
                                }
                                if (_currentIndex == 1 &&
                                    !allowInsecurePassword &&
                                    !await context
                                        .read<AuthenticationCubit>()
                                        .checkNotPwned(
                                            password:
                                                _passwordTextController.text)) {
                                  return;
                                }
                                setState(() {
                                  _currentIndex++;
                                  _errorText = null;
                                });
                              },
                              child: const Text('Continue'),
                            ).withTapBounce(enabled: !loading),
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
