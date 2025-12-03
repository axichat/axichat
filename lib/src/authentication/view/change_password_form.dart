import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ChangePasswordForm extends StatefulWidget {
  const ChangePasswordForm({super.key});

  static String title(AppLocalizations l10n) => l10n.profileChangePassword;

  @override
  State<ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<ChangePasswordForm> {
  late TextEditingController _passwordTextController;
  late TextEditingController _newPasswordTextController;
  late TextEditingController _newPassword2TextController;

  @override
  void initState() {
    super.initState();
    _passwordTextController = TextEditingController();
    _newPasswordTextController = TextEditingController();
    _newPassword2TextController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordTextController.dispose();
    _newPasswordTextController.dispose();
    _newPassword2TextController.dispose();
    super.dispose();
  }

  void _onPressed(BuildContext context) async {
    if (!Form.of(context).mounted || !Form.of(context).validate()) return;
    await context.read<AuthenticationCubit>().changePassword(
          username: context.read<ProfileCubit>().state.username,
          host: context.read<AuthenticationCubit>().endpointConfig.domain,
          oldPassword: _passwordTextController.value.text,
          password: _newPasswordTextController.value.text,
          password2: _newPassword2TextController.value.text,
        );
    _passwordTextController.clear();
    _newPasswordTextController.clear();
    _newPassword2TextController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationCubit, AuthenticationState>(
      builder: (context, state) {
        final l10n = context.l10n;
        final loading = state is AuthenticationPasswordChangeInProgress;
        return Form(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ChangePasswordForm.title(l10n),
                style: context.textTheme.h3,
              ),
              state is AuthenticationPasswordChangeSuccess
                  ? Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        state.successText,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : state is AuthenticationPasswordChangeFailure
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
                  placeholder: l10n.authPasswordCurrentPlaceholder,
                  enabled: !loading,
                  controller: _passwordTextController,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: PasswordInput(
                  placeholder: l10n.authPasswordNewPlaceholder,
                  enabled: !loading,
                  controller: _newPasswordTextController,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: PasswordInput(
                  placeholder: l10n.authPasswordConfirmNewPlaceholder,
                  enabled: !loading,
                  controller: _newPassword2TextController,
                ),
              ),
              const SizedBox.square(dimension: 16.0),
              Builder(
                builder: (context) {
                  return ShadButton(
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
                        semanticsLabel: l10n.authChangePasswordProgressLabel,
                      ),
                    ),
                    trailing: const SizedBox.shrink(),
                    child: Text(l10n.commonContinue),
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
