import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class UnregisterForm extends StatefulWidget {
  const UnregisterForm({super.key});

  static const title = 'Unregister';

  @override
  State<UnregisterForm> createState() => _UnregisterFormState();
}

class _UnregisterFormState extends State<UnregisterForm> {
  late TextEditingController _passwordTextController;

  @override
  void initState() {
    super.initState();
    _passwordTextController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordTextController.dispose();
    super.dispose();
  }

  void _onPressed(BuildContext context) async {
    if (!Form.of(context).mounted || !Form.of(context).validate()) return;
    await context.read<AuthenticationCubit>().unregister(
          username: context.read<ProfileCubit>().state.username,
          host: context.read<AuthenticationCubit>().endpointConfig.domain,
          password: _passwordTextController.value.text,
        );
    _passwordTextController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationCubit, AuthenticationState>(
      builder: (context, state) {
        final loading = state is AuthenticationUnregisterInProgress;
        return Form(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                UnregisterForm.title,
                style: context.textTheme.h3,
              ),
              state is AuthenticationUnregisterFailure
                  ? Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        state.errorText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colorScheme.destructive,
                        ),
                      ),
                    )
                  : const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: PasswordInput(
                  placeholder: 'Password',
                  enabled: !loading,
                  controller: _passwordTextController,
                ),
              ),
              const SizedBox.square(dimension: 16.0),
              Builder(
                builder: (context) {
                  return ShadButton.destructive(
                    enabled: !loading,
                    onPressed: () => _onPressed(context),
                    leading: AnimatedCrossFade(
                      crossFadeState: loading
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration:
                          context.watch<SettingsCubit>().animationDuration,
                      firstChild: const SizedBox(),
                      secondChild: AxiProgressIndicator(
                        color: context.colorScheme.primaryForeground,
                        semanticsLabel: 'Waiting for account deletion',
                      ),
                    ),
                    trailing: const SizedBox.shrink(),
                    child: const Text('Continue'),
                  ).withTapBounce(enabled: !loading);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
