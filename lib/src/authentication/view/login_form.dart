import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/view/terms_checkbox.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/notifications/view/notification_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  static const title = 'Log In';

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  late TextEditingController _jidTextController;
  late TextEditingController _passwordTextController;

  bool rememberMe = true;

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

  void _onPressed(BuildContext context) async {
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
                LoginForm.title,
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
                key: loginUsernameKey,
                autocorrect: false,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                ],
                placeholder: const Text('Username'),
                enabled: state is! AuthenticationInProgress,
                controller: _jidTextController,
                suffix: Text('@${state.server}'),
                validator: (text) {
                  if (text.isEmpty) {
                    return 'Enter a username';
                  }
                  return null;
                },
              ),
              PasswordInput(
                key: loginPasswordKey,
                enabled: state is! AuthenticationInProgress,
                controller: _passwordTextController,
              ),
              const Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                  child: TermsCheckbox(),
                ),
              ),
              NotificationRequest(
                notificationService: context.read<NotificationService>(),
              ),
              const SizedBox.square(dimension: 16.0),
              Builder(
                builder: (context) {
                  final loading = state is AuthenticationInProgress;
                  return ShadButton(
                    key: loginSubmitKey,
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
