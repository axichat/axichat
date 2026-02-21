// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/view/auth_message_l10n.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
      host: context.read<SettingsCubit>().state.endpointConfig.domain,
      oldPassword: _passwordTextController.value.text,
      password: _newPasswordTextController.value.text,
      password2: _newPassword2TextController.value.text,
    );
    if (!context.mounted) return;
    _passwordTextController.clear();
    _newPasswordTextController.clear();
    _newPassword2TextController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationCubit, AuthenticationState>(
      builder: (context, state) {
        final loading = state is AuthenticationPasswordChangeInProgress;
        final spacing = context.spacing;
        return Form(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ChangePasswordForm.title(context.l10n),
                style: context.textTheme.h3,
              ),
              state is AuthenticationPasswordChangeSuccess
                  ? Padding(
                      padding: EdgeInsets.all(spacing.s),
                      child: Text(
                        state.message.resolve(context.l10n),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : state is AuthenticationPasswordChangeFailure
                  ? Padding(
                      padding: EdgeInsets.all(spacing.s),
                      child: Text(
                        state.message.resolve(context.l10n),
                        textAlign: TextAlign.center,
                        style: context.textTheme.small,
                      ),
                    )
                  : SizedBox(height: spacing.l),
              Padding(
                padding: EdgeInsets.all(spacing.s),
                child: PasswordInput(
                  placeholder: context.l10n.authPasswordCurrentPlaceholder,
                  enabled: !loading,
                  controller: _passwordTextController,
                ),
              ),
              Padding(
                padding: EdgeInsets.all(spacing.s),
                child: PasswordInput(
                  placeholder: context.l10n.authPasswordNewPlaceholder,
                  enabled: !loading,
                  controller: _newPasswordTextController,
                ),
              ),
              Padding(
                padding: EdgeInsets.all(spacing.s),
                child: PasswordInput(
                  placeholder: context.l10n.authPasswordConfirmNewPlaceholder,
                  enabled: !loading,
                  controller: _newPassword2TextController,
                  validator: (value) {
                    final newPassword = _newPasswordTextController.text;
                    if (value != null &&
                        newPassword.isNotEmpty &&
                        value != newPassword) {
                      return context.l10n.authPasswordsMismatch;
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(height: spacing.s),
              AxiButton.primary(
                loading: loading,
                onPressed: loading ? null : () => _onPressed(context),
                child: Text(context.l10n.commonContinue),
              ),
            ],
          ),
        );
      },
    );
  }
}
