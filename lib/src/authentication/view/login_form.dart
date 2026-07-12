// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/view/endpoint_config_sheet.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
    this.onSubmitStart,
    this.busy = false,
    this.enabled = true,
  });

  final VoidCallback? onSubmitStart;
  final bool busy;
  final bool enabled;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  static final _loginLocalPartPattern = RegExp(r'^[a-zA-Z0-9._-]+$');

  final _formKey = GlobalKey<FormState>();
  final _passwordFocusNode = FocusNode();
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
    _passwordFocusNode.dispose();
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
    final settingsCubit = context.read<SettingsCubit>();
    final loginTarget = _loginTargetForInput(
      _jidTextController.value.text,
      settingsCubit.state.endpointConfig,
    );
    if (loginTarget == null) {
      return;
    }
    if (loginTarget.fullAddress) {
      _jidTextController.value = TextEditingValue(
        text: loginTarget.username,
        selection: TextSelection.collapsed(offset: loginTarget.username.length),
      );
    }
    await context.read<AuthenticationCubit>().login(
      username: loginTarget.username,
      password: _passwordTextController.value.text,
      rememberMe: rememberMe,
      endpointConfigOverride: loginTarget.endpointConfig,
    );
  }

  ({String username, EndpointConfig endpointConfig, bool fullAddress})?
  _loginTargetForInput(String value, EndpointConfig endpointConfig) {
    final normalized = normalizeAddress(value);
    if (normalized == null) {
      return null;
    }
    final bare = bareAddressOrNull(normalized);
    if (bare == null) {
      return normalized.contains('@') ||
              !_loginLocalPartPattern.hasMatch(normalized)
          ? null
          : (
              username: normalized,
              endpointConfig: endpointConfig,
              fullAddress: false,
            );
    }
    final localPart = addressLocalPart(bare);
    final domainPart = addressDomainPart(bare);
    if (localPart == null ||
        domainPart == null ||
        !_loginLocalPartPattern.hasMatch(localPart)) {
      return normalized.contains('@') ||
              !_loginLocalPartPattern.hasMatch(normalized)
          ? null
          : (
              username: normalized,
              endpointConfig: endpointConfig,
              fullAddress: false,
            );
    }
    return (
      username: localPart,
      endpointConfig: _endpointConfigForAutofilledDomain(
        endpointConfig,
        domainPart,
      ),
      fullAddress: true,
    );
  }

  EndpointConfig _endpointConfigForAutofilledDomain(
    EndpointConfig endpointConfig,
    String domain,
  ) {
    final normalizedDomain = domain.trim();
    if (normalizedDomain.toLowerCase() ==
        endpointConfig.domain.trim().toLowerCase()) {
      return endpointConfig;
    }
    return endpointConfig.copyWith(
      domain: normalizedDomain,
      imapHost: null,
      smtpHost: null,
      imapPort: EndpointConfig.defaultImapPort,
      smtpPort: EndpointConfig.defaultSmtpPort,
      apiPort: EndpointConfig.defaultApiPort,
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
        final formEnabled = widget.enabled && !isBusy;
        final animationDuration = context
            .watch<SettingsCubit>()
            .animationDuration;
        final spacing = context.spacing;
        final sizing = context.sizing;
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
          child: AutofillGroup(
            onDisposeAction: AutofillContextAction.cancel,
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
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username],
                          placeholder: Text(context.l10n.authUsername),
                          enabled: formEnabled,
                          controller: _jidTextController,
                          onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                          trailing: EndpointSuffix(server: state.server),
                          validator: (text) {
                            if (text.isEmpty) {
                              return context.l10n.authUsernameRequired;
                            }
                            if (_loginTargetForInput(
                                  text,
                                  context
                                      .read<SettingsCubit>()
                                      .state
                                      .endpointConfig,
                                ) ==
                                null) {
                              return context.l10n.jidInputInvalid;
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
                        enabled: formEnabled,
                        controller: _passwordTextController,
                        focusNode: _passwordFocusNode,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                      ),
                    ),
                    SizedBox(height: spacing.m),
                    Padding(
                      padding: horizontalPadding,
                      child: AxiCheckboxFormField(
                        key: _rememberMeFieldKey,
                        enabled: formEnabled,
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
                            onPressed: formEnabled ? _onPressed : null,
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
          ),
        );
      },
    );
  }
}
