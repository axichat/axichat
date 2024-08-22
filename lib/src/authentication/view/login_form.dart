import 'package:chat/src/app.dart';
import 'package:chat/src/authentication/bloc/authentication_cubit.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  late TextEditingController _jidTextController;
  late TextEditingController _passwordTextController;

  bool rememberMe = true;
  bool agreeToTerms = false;

  @override
  void initState() {
    super.initState();
    _jidTextController = TextEditingController();
    _passwordTextController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<AuthenticationCubit>().login();
  }

  @override
  void dispose() {
    _jidTextController.dispose();
    _passwordTextController.dispose();
    super.dispose();
  }

  void _onPressed(BuildContext context) {
    if (!Form.of(context).mounted || !Form.of(context).validate()) return;
    context.read<AuthenticationCubit>().login(
          username: _jidTextController.value.text,
          password: _passwordTextController.value.text,
          rememberMe: rememberMe,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationCubit, AuthenticationState>(
      builder: (context, state) {
        return Form(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Log In',
                style: context.textTheme.h3,
              ),
              state is AuthenticationFailure
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
              Builder(
                builder: (context) {
                  final loading = state is AuthenticationInProgress;
                  return ShadButton(
                    enabled: !loading,
                    onPressed: () => _onPressed(context),
                    text: const Text('Log in'),
                    icon: loading
                        ? Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: AxiProgressIndicator(
                              color: context.colorScheme.primaryForeground,
                              semanticsLabel: 'Waiting for login',
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
