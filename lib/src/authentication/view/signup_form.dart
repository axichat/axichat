import 'package:chat/src/app.dart';
import 'package:chat/src/authentication/bloc/authentication_cubit.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({super.key});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  TextEditingController? _jidTextController;
  TextEditingController? _passwordTextController;
  TextEditingController? _password2TextController;

  bool rememberMe = false;
  bool agreeToTerms = false;

  @override
  void initState() {
    super.initState();
    _jidTextController = TextEditingController();
    _passwordTextController = TextEditingController();
    _password2TextController = TextEditingController();
  }

  @override
  void dispose() {
    _jidTextController?.dispose();
    _passwordTextController?.dispose();
    _password2TextController?.dispose();
    super.dispose();
  }

  void _onPressed() {
    if (!Form.of(context).mounted || !Form.of(context).validate()) return;
    context.read<AuthenticationCubit>().signup(
          username: _jidTextController!.value.text,
          password: _passwordTextController!.value.text,
          rememberMe: rememberMe,
          agreeToTerms: agreeToTerms,
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
                'Login',
                style: context.textTheme.h3,
              ),
              const SizedBox(height: 40),
              AxiTextFormField(
                placeholder: const Text('Username'),
                enabled: state is! AuthenticationInProgress,
                controller: _jidTextController,
                validator: (text) => text.isEmpty ? 'Enter a username' : null,
              ),
              const SizedBox(height: 20),
              AxiTextFormField(
                placeholder: const Text('Password'),
                enabled: state is! AuthenticationInProgress,
                obscureText: true,
                controller: _passwordTextController,
                validator: (text) {
                  if (text.isEmpty) {
                    return 'Enter a password';
                  }
                  if (text.length < 8 || text.length > 64) {
                    return 'Must be between 8 and 64 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              AxiTextFormField(
                placeholder: const Text('Confirm Password'),
                enabled: state is! AuthenticationInProgress,
                obscureText: true,
                controller: _password2TextController,
                validator: (text) => text != _passwordTextController?.text
                    ? 'Passwords don\'t match'
                    : null,
              ),
              const SizedBox(height: 40),
              CheckboxListTile(
                title: const Text('Remember Me'),
                subtitle: const Text('Save login for next time'),
                checkboxSemanticLabel: 'Remember me',
                enabled: state is! AuthenticationInProgress,
                value: rememberMe,
                onChanged: (checked) => setState(() {
                  rememberMe = checked ?? rememberMe;
                }),
              ),
              FormField<bool>(
                enabled: state is! AuthenticationInProgress,
                builder: (FormFieldState<bool> field) {
                  return CheckboxListTile(
                    title: const Text('I agree to the terms'),
                    checkboxSemanticLabel: 'Agree to the terms',
                    subtitle: field.errorText == null
                        ? null
                        : Text(
                            field.errorText!,
                            style: const TextStyle(color: Colors.red),
                          ),
                    value: agreeToTerms,
                    onChanged: (checked) => setState(() {
                      field.didChange(checked);
                      agreeToTerms = field.value ?? agreeToTerms;
                    }),
                    isError: field.hasError,
                  );
                },
                validator: (checked) {
                  if (checked == null || checked == false) {
                    return 'You must agree to the terms';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),
              ShadButton(
                onPressed:
                    state is! AuthenticationInProgress ? _onPressed : null,
                text: const Text('Log In'),
              ),
            ],
          ),
        );
      },
    );
  }
}
