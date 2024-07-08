import 'package:chat/src/authentication/bloc/authentication_bloc.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  TextEditingController? _jidTextController;
  TextEditingController? _passwordTextController;

  bool rememberMe = false;
  bool agreeToTerms = false;

  @override
  void initState() {
    super.initState();
    _jidTextController = TextEditingController();
    _passwordTextController = TextEditingController();
  }

  @override
  void dispose() {
    _jidTextController?.dispose();
    _passwordTextController?.dispose();
    super.dispose();
  }

  void _onPressed(BuildContext context) {
    if (!Form.of(context).mounted || !Form.of(context).validate()) return;
    context.read<AuthenticationBloc>().add(
          AuthenticationLoginRequested(
            username: _jidTextController!.value.text,
            password: _passwordTextController!.value.text,
            rememberMe: rememberMe,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationBloc, AuthenticationState>(
      builder: (context, state) {
        return Form(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Login',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              state is AuthenticationFailure
                  ? Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        state.errorText,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  : const SizedBox(height: 40),
              AxiTextFormField(
                labelText: 'Username',
                enabled: state is! AuthenticationInProgress,
                controller: _jidTextController,
                validator: (text) {
                  if (text == null || text.isEmpty) {
                    return 'Enter a username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              AxiTextFormField(
                labelText: 'Password',
                enabled: state is! AuthenticationInProgress,
                obscureText: true,
                controller: _passwordTextController,
                validator: (text) {
                  if (text == null || text.isEmpty) {
                    return 'Enter a password';
                  }
                  if (text.length < 8 || text.length > 64) {
                    return 'Must be between 8 and 64 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),
              CheckboxListTile(
                title: const Text('Remember Me'),
                subtitle: const Text('Save login details'),
                checkboxSemanticLabel: 'Remember me',
                enabled: state is! AuthenticationInProgress,
                value: rememberMe,
                onChanged: (checked) => setState(() {
                  rememberMe = checked ?? rememberMe;
                }),
              ),
              const SizedBox(height: 40),
              Builder(builder: (context) {
                return ElevatedButton(
                  onPressed: state is! AuthenticationInProgress
                      ? () => _onPressed(context)
                      : null,
                  child: const Text('Log In'),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
