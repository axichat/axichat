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

class UnregisterForm extends StatefulWidget {
  const UnregisterForm({super.key});

  static String title(AppLocalizations l10n) => l10n.authUnregisterTitle;

  @override
  State<UnregisterForm> createState() => _UnregisterFormState();
}

class _UnregisterFormState extends State<UnregisterForm> {
  final _formKey = GlobalKey<FormState>();
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
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final passwordWasSkipped = context
        .read<AuthenticationCubit>()
        .passwordWasSkipped;
    final approved = await confirm(
      context,
      title: context.l10n.authUnregisterConfirmTitle,
      message: context.l10n.authUnregisterConfirmMessage,
      confirmLabel: context.l10n.authUnregisterConfirmAction,
      cancelLabel: context.l10n.commonCancel,
      destructiveConfirm: true,
    );
    if (!context.mounted || approved != true) return;
    await context.read<AuthenticationCubit>().unregister(
      username: context.read<ProfileCubit>().state.username,
      host: context.read<SettingsCubit>().state.endpointConfig.domain,
      password: passwordWasSkipped ? '' : _passwordTextController.value.text,
    );
    if (!context.mounted) return;
    _passwordTextController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationCubit, AuthenticationState>(
      builder: (context, state) {
        final loading = state is AuthenticationUnregisterInProgress;
        final passwordWasSkipped = context.select<AuthenticationCubit, bool>(
          (cubit) => cubit.passwordWasSkipped,
        );
        final spacing = context.spacing;
        final unregisterErrorPadding = EdgeInsets.all(spacing.s);
        final unregisterFieldPadding = EdgeInsets.all(spacing.s);
        return Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                UnregisterForm.title(context.l10n),
                style: context.textTheme.h3,
              ),
              state is AuthenticationUnregisterFailure
                  ? Padding(
                      padding: unregisterErrorPadding,
                      child: Text(
                        state.message.resolve(context.l10n),
                        textAlign: TextAlign.center,
                        style: context.textTheme.small,
                      ),
                    )
                  : SizedBox(height: spacing.l),
              if (passwordWasSkipped)
                Padding(
                  padding: unregisterFieldPadding,
                  child: Text(
                    context.l10n.authDeviceOnlyPasswordManagedDeleteHint,
                    textAlign: TextAlign.center,
                    style: context.textTheme.small,
                  ),
                ),
              if (!passwordWasSkipped)
                Padding(
                  padding: unregisterFieldPadding,
                  child: PasswordInput(
                    placeholder: context.l10n.authPasswordPlaceholder,
                    enabled: !loading,
                    controller: _passwordTextController,
                  ),
                ),
              SizedBox(height: spacing.s),
              AxiButton.destructive(
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
