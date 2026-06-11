// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/password_safety.dart';
import 'package:axichat/src/authentication/view/password_safety_widgets.dart';
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
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _passwordTextController;
  late TextEditingController _newPasswordTextController;
  late TextEditingController _newPassword2TextController;
  AuthPasswordRisk? _acknowledgedPasswordRisk;
  PasswordBreachCheckResult? _breachCheckResult;
  String? _lastBreachCheckedPassword;
  String _lastNewPasswordValue = '';
  bool _passwordSafetyCheckInProgress = false;
  bool _showPasswordRiskPrompt = false;
  bool _showPasswordRiskError = false;
  int _passwordRiskResetTick = 0;

  @override
  void initState() {
    super.initState();
    _passwordTextController = TextEditingController();
    _newPasswordTextController = TextEditingController()
      ..addListener(_handleNewPasswordChanged);
    _newPassword2TextController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordTextController.dispose();
    _newPasswordTextController.dispose();
    _newPassword2TextController.dispose();
    super.dispose();
  }

  void _handleNewPasswordChanged() {
    if (!mounted) return;
    final password = _newPasswordTextController.text;
    if (_lastNewPasswordValue == password) {
      return;
    }
    setState(() {
      _lastNewPasswordValue = password;
      _acknowledgedPasswordRisk = null;
      _showPasswordRiskPrompt = false;
      _showPasswordRiskError = false;
      _passwordRiskResetTick++;
      if (_lastBreachCheckedPassword != password) {
        _breachCheckResult = null;
        _lastBreachCheckedPassword = null;
      }
    });
  }

  AuthPasswordAssessment get _newPasswordAssessment =>
      assessAuthPassword(_newPasswordTextController.text);

  PasswordBreachCheckResult? get _currentBreachCheckResult =>
      _lastBreachCheckedPassword == _newPasswordTextController.text
      ? _breachCheckResult
      : null;

  AuthPasswordRisk? _passwordRisk({required bool usesStrictPasswordPolicy}) {
    if (!usesStrictPasswordPolicy) {
      return null;
    }
    return authPasswordRiskForHostedPolicy(
      assessment: _newPasswordAssessment,
      breachCheckResult: _currentBreachCheckResult,
    );
  }

  bool _passwordRiskAcknowledged(AuthPasswordRisk? risk) =>
      risk != null && _acknowledgedPasswordRisk == risk;

  void _clearPasswordSafetyState() {
    _acknowledgedPasswordRisk = null;
    _breachCheckResult = null;
    _lastBreachCheckedPassword = null;
    _showPasswordRiskPrompt = false;
    _showPasswordRiskError = false;
    _passwordRiskResetTick++;
  }

  void _onPressed(BuildContext context) async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final locate = context.read;
    final settingsState = locate<SettingsCubit>().state;
    final usesStrictPasswordPolicy = settingsState.endpointConfig.isAxiImDomain;
    final passwordSnapshot = _newPasswordTextController.text;
    if (usesStrictPasswordPolicy && _currentBreachCheckResult == null) {
      setState(() {
        _passwordSafetyCheckInProgress = true;
      });
      final breachCheckResult = await locate<AuthenticationCubit>()
          .checkPasswordBreach(password: passwordSnapshot);
      if (!mounted) return;
      if (_newPasswordTextController.text != passwordSnapshot) {
        setState(() {
          _passwordSafetyCheckInProgress = false;
        });
        return;
      }
      setState(() {
        _passwordSafetyCheckInProgress = false;
        _breachCheckResult = breachCheckResult;
        _lastBreachCheckedPassword = passwordSnapshot;
      });
    }
    final passwordRisk = _passwordRisk(
      usesStrictPasswordPolicy: usesStrictPasswordPolicy,
    );
    if (passwordRisk != null && !_passwordRiskAcknowledged(passwordRisk)) {
      setState(() {
        _showPasswordRiskPrompt = true;
        _showPasswordRiskError = true;
      });
      return;
    }
    final passwordWasSkipped = locate<AuthenticationCubit>().passwordWasSkipped;
    await locate<AuthenticationCubit>().changePassword(
      username: locate<ProfileCubit>().state.username,
      host: settingsState.endpointConfig.domain,
      oldPassword: passwordWasSkipped ? '' : _passwordTextController.value.text,
      password: _newPasswordTextController.value.text,
      password2: _newPassword2TextController.value.text,
    );
    if (!mounted) return;
    _passwordTextController.clear();
    _newPasswordTextController.clear();
    _newPassword2TextController.clear();
    setState(_clearPasswordSafetyState);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationCubit, AuthenticationState>(
      builder: (context, state) {
        final loading = state is AuthenticationPasswordChangeInProgress;
        final submitting = loading || _passwordSafetyCheckInProgress;
        final passwordWasSkipped = context.select<AuthenticationCubit, bool>(
          (cubit) => cubit.passwordWasSkipped,
        );
        final usesStrictPasswordPolicy = context.select<SettingsCubit, bool>(
          (cubit) => cubit.state.endpointConfig.isAxiImDomain,
        );
        final animationDuration = context.select<SettingsCubit, Duration>(
          (cubit) => cubit.animationDuration,
        );
        final passwordRisk = _passwordRisk(
          usesStrictPasswordPolicy: usesStrictPasswordPolicy,
        );
        final visiblePasswordRisk = _showPasswordRiskPrompt
            ? passwordRisk
            : null;
        final spacing = context.spacing;
        return Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ChangePasswordForm.title(context.l10n),
                style: context.textTheme.h3,
              ),
              if (state is AuthenticationPasswordChangeSuccess)
                Padding(
                  padding: EdgeInsets.all(spacing.s),
                  child: Text(
                    state.message.resolve(context.l10n),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                SizedBox(height: spacing.l),
              if (passwordWasSkipped)
                Padding(
                  padding: EdgeInsets.all(spacing.s),
                  child: Text(
                    context.l10n.authDeviceOnlyPasswordManagedChangeHint,
                    textAlign: TextAlign.center,
                    style: context.textTheme.small,
                  ),
                ),
              if (state is AuthenticationPasswordChangeFailure)
                Padding(
                  padding: EdgeInsets.all(spacing.s),
                  child: Text(
                    state.message.resolve(context.l10n),
                    textAlign: TextAlign.center,
                    style: context.textTheme.small.copyWith(
                      color: context.colorScheme.destructive,
                    ),
                  ),
                ),
              if (!passwordWasSkipped)
                Padding(
                  padding: EdgeInsets.all(spacing.s),
                  child: PasswordInput(
                    placeholder: context.l10n.authPasswordCurrentPlaceholder,
                    enabled: !submitting,
                    controller: _passwordTextController,
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(spacing.s),
                child: PasswordInput(
                  placeholder: context.l10n.authPasswordNewPlaceholder,
                  enabled: !submitting,
                  controller: _newPasswordTextController,
                ),
              ),
              Padding(
                padding: EdgeInsets.all(spacing.s),
                child: PasswordInput(
                  placeholder: context.l10n.authPasswordConfirmNewPlaceholder,
                  enabled: !submitting,
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
              Padding(
                padding: EdgeInsets.all(spacing.s),
                child: AuthPasswordStrengthMeter(
                  assessment: _newPasswordAssessment,
                  showBreachWarning:
                      visiblePasswordRisk == AuthPasswordRisk.breached,
                  showSafetyUnavailableWarning:
                      visiblePasswordRisk == AuthPasswordRisk.unavailable,
                  animationDuration: animationDuration,
                ),
              ),
              Padding(
                padding: EdgeInsets.all(spacing.s),
                child: AuthPasswordRiskNotice(
                  risk: visiblePasswordRisk,
                  allowed: _passwordRiskAcknowledged(visiblePasswordRisk),
                  enabled: !submitting,
                  showError: _showPasswordRiskError,
                  animationDuration: animationDuration,
                  resetTick: _passwordRiskResetTick,
                  onChanged: (value) {
                    setState(() {
                      _acknowledgedPasswordRisk = value
                          ? visiblePasswordRisk
                          : null;
                      if (value) {
                        _showPasswordRiskError = false;
                      }
                    });
                  },
                ),
              ),
              SizedBox(height: spacing.s),
              AxiButton.primary(
                loading: submitting,
                onPressed: submitting ? null : () => _onPressed(context),
                child: Text(context.l10n.commonContinue),
              ),
            ],
          ),
        );
      },
    );
  }
}
