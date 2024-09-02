import 'dart:io';

import 'package:chat/src/app.dart';
import 'package:chat/src/authentication/bloc/authentication_cubit.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/notifications/bloc/notification_permissions.dart';
import 'package:chat/src/notifications/view/notification_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:xml/xml.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({super.key});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  late TextEditingController _jidTextController;
  late TextEditingController _passwordTextController;
  late TextEditingController _password2TextController;
  late TextEditingController _captchaTextController;

  bool rememberMe = true;

  late Future<String> _captchaSrc;

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
    if (!context.mounted ||
        !Form.of(context).mounted ||
        !Form.of(context).validate() ||
        !(await acceptTerms(context) ?? false)) return;
    if (!await hasAllNotificationPermissions() && context.mounted) {
      await showNotificationDialog(context);
    }
    if (!context.mounted) return;
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
    return BlocBuilder<AuthenticationCubit, AuthenticationState>(
      builder: (context, state) {
        return Form(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sign Up',
                style: context.textTheme.h3,
              ),
              state is AuthenticationSignupFailure
                  ? Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        state.errorText,
                        style: TextStyle(
                          color: context.colorScheme.destructive,
                        ),
                      ),
                    )
                  : const SizedBox(height: 40),
              AxiTextFormField(
                autocorrect: false,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                ],
                placeholder: const Text('Username'),
                enabled: state is! AuthenticationInProgress,
                controller: _jidTextController,
                suffix: const Text('@${AuthenticationCubit.defaultServer}'),
                validator: (text) {
                  if (text.isEmpty) {
                    return 'Enter a username';
                  }
                  return null;
                },
              ),
              PasswordInput(
                enabled: state is! AuthenticationInProgress,
                controller: _passwordTextController,
              ),
              PasswordInput(
                enabled: state is! AuthenticationInProgress,
                controller: _password2TextController,
                confirmValidator: (text) => text != _passwordTextController.text
                    ? 'Passwords don\'t match'
                    : null,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 30.0,
                  ),
                  child: ShadCheckbox(
                    label: const Text('Remember Me'),
                    sublabel: const Text('Save login details'),
                    enabled: state is! AuthenticationInProgress,
                    value: rememberMe,
                    onChanged: (checked) => setState(() {
                      rememberMe = checked;
                    }),
                  ),
                ),
              ),
              FutureBuilder(
                future: _captchaSrc,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return SizedBox(
                      height: captchaSize.height,
                      width: captchaSize.width,
                      child: const Center(child: AxiProgressIndicator()),
                    );
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.network(
                        snapshot.requireData,
                        height: captchaSize.height,
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : const Center(child: AxiProgressIndicator()),
                        errorBuilder: (_, __, ___) => Text(
                          'Failed to load captcha, try again later.',
                          style:
                              TextStyle(color: context.colorScheme.destructive),
                        ),
                      ),
                      ShadButton.ghost(
                        icon: const Icon(LucideIcons.refreshCw),
                        onPressed: () => setState(() {
                          _captchaSrc = _loadCaptchaSrc();
                        }),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(
                width: captchaSize.width,
                child: AxiTextFormField(
                  autocorrect: false,
                  keyboardType: TextInputType.number,
                  placeholder: const Text('Enter the above text'),
                  enabled: state is! AuthenticationInProgress,
                  controller: _captchaTextController,
                  validator: (text) {
                    if (text.isEmpty) {
                      return 'Enter the text from the image';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox.square(dimension: 16.0),
              Builder(
                builder: (context) {
                  final loading = state is AuthenticationInProgress;
                  return ShadButton(
                    enabled: !loading,
                    onPressed: () => _onPressed(context),
                    text: const Text('Sign up'),
                    icon: loading
                        ? Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: AxiProgressIndicator(
                              color: context.colorScheme.primaryForeground,
                              semanticsLabel: 'Waiting for signup',
                            ),
                          )
                        : null,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
