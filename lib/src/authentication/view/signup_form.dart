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
    _jidTextController = TextEditingController();
    _passwordTextController = TextEditingController();
    _password2TextController = TextEditingController();
    _captchaTextController = TextEditingController();
  }

  @override
  void dispose() {
    _jidTextController.dispose();
    _passwordTextController.dispose();
    _password2TextController.dispose();
    _captchaTextController.dispose();
    super.dispose();
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
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              SignupForm.title,
              style: context.textTheme.h3,
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Text(
                _errorText ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colorScheme.destructive,
                ),
              ),
            ),
            NotificationRequest(
              notificationService: context.read<NotificationService>(),
              capability: context.read<Capability>(),
            ),
            const SizedBox.square(dimension: 16.0),
            AnimatedSize(
              duration: context.read<SettingsCubit>().animationDuration,
              curve: Curves.easeIn,
              child: AnimatedSwitcher(
                duration: context.read<SettingsCubit>().animationDuration,
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: AnimatedSwitcher.defaultTransitionBuilder,
                child: [
                  Form(
                    key: _formKeys[0],
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: AxiTextFormField(
                        key: UniqueKey(),
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
                          if (!RegExp(r'^[a-z][a-z0-9._-]{3,19}$')
                              .hasMatch(text)) {
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
                      key: UniqueKey(),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: PasswordInput(
                            enabled: !loading,
                            controller: _passwordTextController,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: PasswordInput(
                            enabled: !loading,
                            controller: _password2TextController,
                            confirmValidator: (text) =>
                                text != _passwordTextController.text
                                    ? 'Passwords don\'t match'
                                    : null,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            //fromLTRB(16.0, 8.0, 16.0, 16.0),
                            child: TermsCheckbox(
                              enabled: !loading,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ShadCheckboxFormField(
                              enabled: !loading,
                              initialValue: false,
                              inputLabel: const Text('Allow insecure password'),
                              inputSublabel: const Text('Not recommended'),
                              onChanged: (value) =>
                                  allowInsecurePassword = value,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Form(
                    key: _formKeys[2],
                    child: Column(
                      key: UniqueKey(),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FutureBuilder(
                          future: _captchaSrc,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return SizedBox(
                                height: captchaSize.height,
                                width: captchaSize.width,
                                child:
                                    const Center(child: AxiProgressIndicator()),
                              );
                            }
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.network(
                                  snapshot.requireData,
                                  height: captchaSize.height,
                                  loadingBuilder: (_, child, progress) =>
                                      progress == null
                                          ? child
                                          : const Center(
                                              child: AxiProgressIndicator()),
                                  errorBuilder: (_, __, ___) => Text(
                                    'Failed to load captcha, try again later.',
                                    style: TextStyle(
                                        color: context.colorScheme.destructive),
                                  ),
                                ),
                                ShadIconButton.ghost(
                                  icon: const Icon(LucideIcons.refreshCw),
                                  onPressed: () => setState(() {
                                    _captchaSrc = _loadCaptchaSrc();
                                  }),
                                ).withTapBounce(),
                              ],
                            );
                          },
                        ),
                        SizedBox(
                          width: captchaSize.width,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: AxiTextFormField(
                              autocorrect: false,
                              keyboardType: TextInputType.number,
                              placeholder: const Text('Enter the above text'),
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
            const SizedBox.square(dimension: 16.0),
            Builder(
              builder: (context) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 8.0,
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
                                      password: _passwordTextController.text)) {
                            return;
                          }
                          setState(() {
                            _currentIndex++;
                            _errorText = null;
                          });
                        },
                        child: const Text('Continue'),
                      ).withTapBounce(enabled: !loading)
                    else
                      ShadButton(
                        enabled: !loading,
                        onPressed: () => _onPressed(context),
                        leading: AnimatedCrossFade(
                          crossFadeState: loading
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration:
                              context.read<SettingsCubit>().animationDuration,
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
          ],
        );
      },
    );
  }
}
