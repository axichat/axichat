import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/notifications/view/notification_request.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
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
        final loading = state is AuthenticationInProgress ||
            state is AuthenticationComplete;
        const horizontalPadding = EdgeInsets.symmetric(horizontal: 8.0);
        return Form(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: horizontalPadding,
                    child: Text(
                      LoginForm.title,
                      style: context.textTheme.h3,
                    ),
                  ),
                  Padding(
                    padding: horizontalPadding,
                    child: Text(
                      state is AuthenticationFailure ? state.errorText : '',
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
                    child: AxiTextFormField(
                      key: loginUsernameKey,
                      autocorrect: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp('[a-zA-Z0-9]'),
                        ),
                      ],
                      placeholder: const Text('Username'),
                      enabled: !loading,
                      controller: _jidTextController,
                      trailing: Text('@${state.server}'),
                      validator: (text) {
                        if (text.isEmpty) {
                          return 'Enter a username';
                        }
                        return null;
                      },
                    ),
                  ),
                  Padding(
                    padding: horizontalPadding,
                    child: PasswordInput(
                      key: loginPasswordKey,
                      enabled: !loading,
                      controller: _passwordTextController,
                    ),
                  ),
                  const SizedBox.square(dimension: 20.0),
                  Padding(
                    padding: horizontalPadding,
                    child: Builder(
                      builder: (context) {
                        return ShadButton(
                          key: loginSubmitKey,
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
                              semanticsLabel: 'Waiting for login',
                            ),
                          ),
                          trailing: const SizedBox.shrink(),
                          child: const Text('Log in'),
                        ).withTapBounce(enabled: !loading);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
