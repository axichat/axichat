// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/endpoint_config_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class UnregisterForm extends StatefulWidget {
  const UnregisterForm({super.key});

  static String title(AppLocalizations l10n) => l10n.authUnregisterTitle;

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
    final form = Form.of(context);
    if (!form.validate()) return;
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
          host: context.read<EndpointConfigCubit>().state.domain,
          password: _passwordTextController.value.text,
        );
    if (!context.mounted) return;
    _passwordTextController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationCubit, AuthenticationState>(
      builder: (context, state) {
        final loading = state is AuthenticationUnregisterInProgress;
        final animationDuration =
            context.watch<SettingsCubit>().animationDuration;
        const unregisterErrorPaddingValue = 10.0;
        const unregisterFieldPaddingValue = 8.0;
        const unregisterSpacerHeight = 40.0;
        const unregisterButtonGap = 16.0;
        const unregisterSpinnerDimension = 16.0;
        const unregisterSpinnerPadding = 1.0;
        const unregisterSpinnerSlotSize =
            unregisterSpinnerDimension + (unregisterSpinnerPadding * 2);
        const unregisterSpinnerGap = 8.0;
        const unregisterErrorPadding = EdgeInsets.all(
          unregisterErrorPaddingValue,
        );
        const unregisterFieldPadding = EdgeInsets.all(
          unregisterFieldPaddingValue,
        );
        return Form(
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
                        style: TextStyle(
                          color: context.colorScheme.destructive,
                        ),
                      ),
                    )
                  : const SizedBox(height: unregisterSpacerHeight),
              Padding(
                padding: unregisterFieldPadding,
                child: PasswordInput(
                  placeholder: context.l10n.authPasswordPlaceholder,
                  enabled: !loading,
                  controller: _passwordTextController,
                ),
              ),
              const SizedBox.square(dimension: unregisterButtonGap),
              Builder(
                builder: (context) {
                  final spinner = AxiProgressIndicator(
                    dimension: unregisterSpinnerDimension,
                    color: context.colorScheme.primaryForeground,
                    semanticsLabel: context.l10n.authUnregisterProgressLabel,
                  );
                  final spinnerSlot = ButtonSpinnerSlot(
                    isVisible: loading,
                    spinner: spinner,
                    slotSize: unregisterSpinnerSlotSize,
                    gap: unregisterSpinnerGap,
                    duration: animationDuration,
                  );
                  return ShadButton.destructive(
                    enabled: !loading,
                    onPressed: () => _onPressed(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        spinnerSlot,
                        Text(context.l10n.commonContinue),
                      ],
                    ),
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
