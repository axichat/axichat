import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/view/debug_delete_credentials.dart';
import 'package:axichat/src/authentication/view/login_form.dart';
import 'package:axichat/src/authentication/view/signup_form.dart';
import 'package:axichat/src/chat/view/chat.dart';
import 'package:axichat/src/common/shorebird_push.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
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
    final colors = context.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AxiAppBar(
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AxiVersion(),
                  if (kDebugMode) ...[
                    const SizedBox(width: 8),
                    DeleteCredentialsButton(),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colors.background,
                  border: Border(
                    top: BorderSide(color: colors.border),
                  ),
                ),
                child: AxiAdaptiveLayout(
                  primaryChild: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: ShorebirdChecker(),
                              ),
                              DecoratedBox(
                                decoration: ShapeDecoration(
                                  color: colors.card,
                                  shape: SquircleBorder(
                                    cornerRadius: 20,
                                    side: BorderSide(color: colors.border),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: AnimatedCrossFade(
                                    crossFadeState: _login
                                        ? CrossFadeState.showFirst
                                        : CrossFadeState.showSecond,
                                    duration: context
                                        .read<SettingsCubit>()
                                        .animationDuration,
                                    firstChild: const LoginForm(),
                                    secondChild: const SignupForm(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ShadButton.ghost(
                                onPressed: () => setState(() {
                                  _login = !_login;
                                }),
                                child: Text(_login ? 'Sign up' : 'Log in'),
                              ).withTapBounce(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  secondaryChild: const GuestChat(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
