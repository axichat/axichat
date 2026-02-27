// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/view/auth_message_l10n.dart';
import 'package:axichat/src/authentication/view/widgets/endpoint_config_sheet.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key, this.onSubmitStart, this.busy = false});

  final VoidCallback? onSubmitStart;
  final bool busy;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
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
    final preference = await context
        .read<AuthenticationCubit>()
        .loadRememberMeChoice();
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

  void _onPressed() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }
    widget.onSubmitStart?.call();
    await context.read<AuthenticationCubit>().login(
      username: _jidTextController.value.text,
      password: _passwordTextController.value.text,
      rememberMe: rememberMe,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationCubit, AuthenticationState>(
      builder: (context, state) {
        final loading =
            state is AuthenticationInProgress ||
            state is AuthenticationComplete;
        final isBusy = widget.busy || loading;
        final animationDuration = context
            .watch<SettingsCubit>()
            .animationDuration;
        final spacing = context.spacing;
        final sizing = context.sizing;
        final usernameCharactersPattern = RegExp(r'[a-zA-Z0-9._-]');
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
          key: _formKey,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: sizing.dialogMaxWidth),
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
                              style: context.textTheme.small.copyWith(
                                color: context.colorScheme.destructive,
                              ),
                            ),
                          ),
                  ),
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
                        enabled: !isBusy,
                        controller: _jidTextController,
                        trailing: EndpointSuffix(server: state.server),
                        validator: (text) {
                          final value = text;
                          if (value.isEmpty) {
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
                      enabled: !isBusy,
                      controller: _passwordTextController,
                    ),
                  ),
                  SizedBox(height: spacing.m),
                  Padding(
                    padding: horizontalPadding,
                    child: AxiCheckboxFormField(
                      key: _rememberMeFieldKey,
                      enabled: !isBusy,
                      initialValue: rememberMe,
                      inputLabel: Text(context.l10n.authRememberMeLabel),
                      onChanged: (value) async {
                        setState(() {
                          rememberMe = value;
                        });
                        await context
                            .read<AuthenticationCubit>()
                            .persistRememberMeChoice(rememberMe);
                      },
                    ),
                  ),
                  SizedBox(height: spacing.l),
                  Padding(
                    padding: horizontalPadding,
                    child: AxiAnimatedSize(
                      duration: animationDuration,
                      curve: Curves.easeInOut,
                      alignment: Alignment.centerLeft,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: 1,
                        child: AxiButton.primary(
                          key: loginSubmitKey,
                          loading: isBusy,
                          onPressed: isBusy ? null : _onPressed,
                          child: Text(context.l10n.authLogin),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.m),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
