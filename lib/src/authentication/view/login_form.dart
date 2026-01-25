// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/view/widgets/endpoint_config_sheet.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/notifications/view/notification_request.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key, this.onSubmitStart});

  final VoidCallback? onSubmitStart;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  late TextEditingController _jidTextController;
  late TextEditingController _passwordTextController;
  final _rememberMeFieldKey = GlobalKey<FormFieldState<bool>>();

  bool rememberMe = true;

  @override
  void initState() {
    super.initState();
    _jidTextController = TextEditingController();
    _passwordTextController = TextEditingController();
    _restoreRememberMePreference();
  }

  Future<void> _restoreRememberMePreference() async {
    final preference =
        await context.read<AuthenticationCubit>().loadRememberMeChoice();
    if (!mounted) return;
    setState(() {
      rememberMe = preference;
    });
    _rememberMeFieldKey.currentState?.didChange(preference);
  }

  @override
  void dispose() {
    _jidTextController.dispose();
    _passwordTextController.dispose();
    super.dispose();
  }

  void _onPressed(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!Form.of(context).mounted || !Form.of(context).validate()) return;
    widget.onSubmitStart?.call();
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
        final animationDuration =
            context.watch<SettingsCubit>().animationDuration;
        final spacing = context.spacing;
        final usernameCharactersPattern = RegExp(r'[a-zA-Z0-9._-]');
        final loginSpinnerDimension = spacing.m;
        final loginSpinnerPadding = spacing.xxs;
        final loginSpinnerSlotSize =
            loginSpinnerDimension + (loginSpinnerPadding * 2);
        final loginSpinnerGap = spacing.s;
        final horizontalPadding = EdgeInsets.symmetric(horizontal: spacing.s);
        final errorPadding = EdgeInsets.fromLTRB(
          spacing.s,
          spacing.m,
          spacing.s,
          spacing.s,
        );
        final errorMessagePadding = EdgeInsets.fromLTRB(
          spacing.s,
          spacing.s,
          spacing.s,
          spacing.m,
        );
        final errorText = state is AuthenticationFailure
            ? state.message.resolve(context.l10n)
            : null;
        return Form(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: errorPadding,
                    child: Text(
                      context.l10n.authLogin,
                      style: context.modalHeaderTextStyle,
                    ),
                  ),
                  Padding(
                    padding: errorMessagePadding,
                    child: errorText == null || errorText.isEmpty
                        ? const SizedBox.shrink()
                        : Semantics(
                            liveRegion: true,
                            container: true,
                            label: context.l10n.signupErrorPrefix(errorText),
                            child: Text(
                              errorText,
                              style: context.textTheme.small,
                            ),
                          ),
                  ),
                  Padding(
                    padding: horizontalPadding,
                    child: NotificationRequest(
                      notificationService: context.watch<NotificationService>(),
                      capability: context.watch<Capability>(),
                    ),
                  ),
                  SizedBox.square(dimension: spacing.m),
                  Padding(
                    padding: horizontalPadding,
                    child: Semantics(
                      label: context.l10n.authUsername,
                      textField: true,
                      child: AxiTextFormField(
                        key: loginUsernameKey,
                        autocorrect: false,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            usernameCharactersPattern,
                          ),
                        ],
                        keyboardType: TextInputType.emailAddress,
                        placeholder: Text(context.l10n.authUsername),
                        enabled: !loading,
                        controller: _jidTextController,
                        trailing: EndpointSuffix(server: state.server),
                        validator: (text) {
                          if (text.isEmpty) {
                            return context.l10n.authUsernameRequired;
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.s),
                  Padding(
                    padding: horizontalPadding,
                    child: PasswordInput(
                      key: loginPasswordKey,
                      enabled: !loading,
                      controller: _passwordTextController,
                    ),
                  ),
                  Padding(
                    padding: horizontalPadding.add(
                      EdgeInsets.only(top: spacing.s, bottom: spacing.xs),
                    ),
                    child: AxiCheckboxFormField(
                      key: _rememberMeFieldKey,
                      enabled: !loading,
                      initialValue: rememberMe,
                      inputLabel: Text(context.l10n.authRememberMeLabel),
                      onChanged: (value) async {
                        setState(() {
                          rememberMe = value;
                        });
                        await context
                            .read<AuthenticationCubit>()
                            .persistRememberMeChoice(value);
                      },
                    ),
                  ),
                  SizedBox.square(dimension: spacing.m),
                  Padding(
                    padding: horizontalPadding,
                    child: Builder(
                      builder: (context) {
                        final spinner = AxiProgressIndicator(
                          dimension: loginSpinnerDimension,
                          color: context.colorScheme.primaryForeground,
                          semanticsLabel: context.l10n.authLoginPending,
                        );
                        final spinnerSlot = ButtonSpinnerSlot(
                          isVisible: loading,
                          spinner: spinner,
                          slotSize: loginSpinnerSlotSize,
                          gap: loginSpinnerGap,
                          duration: animationDuration,
                        );
                        final button = ShadButton(
                          key: loginSubmitKey,
                          enabled: !loading,
                          onPressed: () => _onPressed(context),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              spinnerSlot,
                              Text(context.l10n.authLogin),
                            ],
                          ),
                        ).withTapBounce(enabled: !loading);
                        return AxiAnimatedSize(
                          duration: animationDuration,
                          curve: Curves.easeInOut,
                          alignment: Alignment.centerLeft,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            widthFactor: 1,
                            child: button,
                          ),
                        );
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
