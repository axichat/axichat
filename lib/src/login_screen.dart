import 'package:chat/src/app.dart';
import 'package:chat/src/authentication/view/debug_delete_credentials.dart';
import 'package:chat/src/authentication/view/login_form.dart';
import 'package:chat/src/authentication/view/signup_form.dart';
import 'package:chat/src/chat/view/chat.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  var _login = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        shape: Border(
          bottom: BorderSide(color: context.colorScheme.border),
        ),
        title: const Text(appDisplayName),
        actions: <Widget>[
              const AxiVersion(),
              const SizedBox.square(dimension: 8.0)
            ] +
            (kDebugMode
                ? [DeleteCredentialsButton(), const SizedBox(width: 50)]
                : []),
      ),
      body: SafeArea(
        child: AxiAdaptiveLayout(
          primaryChild: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedCrossFade(
                    crossFadeState: _login
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    duration: context.read<SettingsCubit>().animationDuration,
                    firstChild: const LoginForm(),
                    secondChild: const SignupForm(),
                  ),
                  const SizedBox.square(dimension: 2.0),
                  ShadButton.ghost(
                    onPressed: () => setState(() {
                      _login = !_login;
                    }),
                    text: Text(_login ? 'Sign up' : 'Log in'),
                  ),
                ],
              ),
            ),
          ),
          secondaryChild: const GuestChat(),
        ),
      ),
    );
  }
}
