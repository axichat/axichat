// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/bloc/email_provisioning_client.dart'
    as provisioning;
import 'package:axichat/src/authentication/password_safety.dart';
import 'package:axichat/src/authentication/view/password_safety_widgets.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<String?> showAccountRecoveryDialog(
  BuildContext context, {
  String? initialUsername,
}) async {
  final locate = context.read;
  if (!locate<SettingsCubit>().state.endpointConfig.isAxiImDomain) {
    return null;
  }
  final checkPasswordBreach = locate<AuthenticationCubit>().checkPasswordBreach;
  return showFadeScaleDialog<String>(
    context: context,
    builder: (dialogContext) => AccountRecoveryDialog(
      initialUsername: initialUsername,
      checkPasswordBreach: checkPasswordBreach,
    ),
  );
}

String _initialAxiLocalpart(String? raw) {
  final value = raw?.trim().toLowerCase();
  if (value == null || value.isEmpty) {
    return '';
  }
  if (!value.contains('@')) {
    return value;
  }
  if (!isAxiJid(value)) {
    return '';
  }
  return addressLocalPart(value) ?? '';
}

enum _RecoveryStep {
  method,
  emailAddress,
  emailCode,
  totpCode,
  newPassword,
  complete,
}

enum _RecoveryMethod { email, totp }

class AccountRecoveryDialog extends StatefulWidget {
  const AccountRecoveryDialog({
    super.key,
    this.initialUsername,
    required this.checkPasswordBreach,
  });

  final String? initialUsername;
  final Future<PasswordBreachCheckResult> Function({required String password})
  checkPasswordBreach;

  @override
  State<AccountRecoveryDialog> createState() => _AccountRecoveryDialogState();
}

class _AccountRecoveryDialogState extends State<AccountRecoveryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _recoveryEmailController;
  late final TextEditingController _codeController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _newPasswordConfirmController;
  _RecoveryStep _step = _RecoveryStep.method;
  _RecoveryMethod? _method;
  String? _challenge;
  String? _resetToken;
  String? _errorText;
  AuthPasswordRisk? _acknowledgedPasswordRisk;
  PasswordBreachCheckResult? _breachCheckResult;
  String? _lastBreachCheckedPassword;
  String _lastNewPasswordValue = '';
  bool _loading = false;
  bool _showPasswordRiskPrompt = false;
  bool _showPasswordRiskError = false;
  int _passwordRiskResetTick = 0;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: _initialAxiLocalpart(widget.initialUsername),
    );
    _recoveryEmailController = TextEditingController();
    _codeController = TextEditingController();
    _newPasswordController = TextEditingController()
      ..addListener(_handleNewPasswordChanged);
    _newPasswordConfirmController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _recoveryEmailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _newPasswordConfirmController.dispose();
    super.dispose();
  }

  void _handleNewPasswordChanged() {
    if (!mounted) return;
    final password = _newPasswordController.text;
    if (_lastNewPasswordValue == password) {
      return;
    }
    setState(() {
      _lastNewPasswordValue = password;
      _clearPasswordSafetyState();
    });
  }

  String get _accountJid {
    final raw = _usernameController.text.trim().toLowerCase();
    return '$raw@${EndpointConfig.axiImDomain}';
  }

  AuthPasswordAssessment get _newPasswordAssessment =>
      assessAuthPassword(_newPasswordController.text);

  PasswordBreachCheckResult? get _currentBreachCheckResult =>
      _lastBreachCheckedPassword == _newPasswordController.text
      ? _breachCheckResult
      : null;

  AuthPasswordRisk? get _visiblePasswordRisk => authPasswordRiskForHostedPolicy(
    assessment: _newPasswordAssessment,
    breachCheckResult: _currentBreachCheckResult,
  );

  bool get _passwordRiskAcknowledged =>
      _acknowledgedPasswordRisk != null &&
      _acknowledgedPasswordRisk == _visiblePasswordRisk;

  void _clearPasswordSafetyState() {
    _acknowledgedPasswordRisk = null;
    _breachCheckResult = null;
    _lastBreachCheckedPassword = null;
    _showPasswordRiskPrompt = false;
    _showPasswordRiskError = false;
    _passwordRiskResetTick++;
  }

  bool _validateForm() {
    final form = _formKey.currentState;
    return form != null && form.validate();
  }

  void _chooseMethod(_RecoveryMethod method) {
    if (!_validateForm()) {
      return;
    }
    setState(() {
      _method = method;
      _step = switch (method) {
        _RecoveryMethod.email => _RecoveryStep.emailAddress,
        _RecoveryMethod.totp => _RecoveryStep.totpCode,
      };
      _errorText = null;
    });
  }

  bool get _canGoBack =>
      !_loading &&
      switch (_step) {
        _RecoveryStep.method || _RecoveryStep.complete => false,
        _RecoveryStep.emailAddress ||
        _RecoveryStep.emailCode ||
        _RecoveryStep.totpCode ||
        _RecoveryStep.newPassword => true,
      };

  void _goBack() {
    if (!_canGoBack) {
      return;
    }
    setState(() {
      _errorText = null;
      switch (_step) {
        case _RecoveryStep.method || _RecoveryStep.complete:
          return;
        case _RecoveryStep.emailAddress:
          _method = null;
          _step = _RecoveryStep.method;
        case _RecoveryStep.emailCode:
          _challenge = null;
          _codeController.clear();
          _step = _RecoveryStep.emailAddress;
        case _RecoveryStep.totpCode:
          _method = null;
          _codeController.clear();
          _step = _RecoveryStep.method;
        case _RecoveryStep.newPassword:
          _resetToken = null;
          _newPasswordController.clear();
          _newPasswordConfirmController.clear();
          _clearPasswordSafetyState();
          if (_method == _RecoveryMethod.email) {
            _challenge = null;
            _codeController.clear();
            _step = _RecoveryStep.emailAddress;
          } else {
            _codeController.clear();
            _step = _RecoveryStep.totpCode;
          }
      }
    });
  }

  Future<void> _startEmailReset() async {
    if (!_validateForm()) {
      return;
    }
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final challenge = await context
          .read<SettingsCubit>()
          .startRecoveryEmailReset(
            accountJid: _accountJid,
            recoveryEmail: _recoveryEmailController.text,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _challenge = challenge?.challenge;
        _step = _RecoveryStep.emailCode;
      });
    } on provisioning.EmailProvisioningApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = recoveryErrorText(context, error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _verifyEmailCode() async {
    if (!_validateForm()) {
      return;
    }
    final challenge = _challenge;
    if (challenge == null || challenge.isEmpty) {
      setState(() {
        _errorText = context.l10n.recoveryRestartRequired;
      });
      return;
    }
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final token = await context
          .read<SettingsCubit>()
          .verifyRecoveryEmailReset(
            accountJid: _accountJid,
            challenge: challenge,
            code: _codeController.text,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _resetToken = token?.resetToken;
        _step = _RecoveryStep.newPassword;
      });
    } on provisioning.EmailProvisioningApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = recoveryErrorText(context, error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _verifyTotpCode() async {
    if (!_validateForm()) {
      return;
    }
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final token = await context.read<SettingsCubit>().verifyRecoveryTotpReset(
        accountJid: _accountJid,
        code: _codeController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _resetToken = token?.resetToken;
        _step = _RecoveryStep.newPassword;
      });
    } on provisioning.EmailProvisioningApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = recoveryErrorText(context, error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (!_validateForm()) {
      return;
    }
    final resetToken = _resetToken;
    if (resetToken == null || resetToken.isEmpty) {
      setState(() {
        _errorText = context.l10n.recoveryRestartRequired;
      });
      return;
    }
    final passwordSnapshot = _newPasswordController.text;
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      if (_currentBreachCheckResult == null) {
        final breachCheckResult = await widget.checkPasswordBreach(
          password: passwordSnapshot,
        );
        if (!mounted) {
          return;
        }
        if (_newPasswordController.text != passwordSnapshot) {
          return;
        }
        setState(() {
          _breachCheckResult = breachCheckResult;
          _lastBreachCheckedPassword = passwordSnapshot;
        });
      }
      final passwordRisk = _visiblePasswordRisk;
      if (passwordRisk != null && !_passwordRiskAcknowledged) {
        setState(() {
          _showPasswordRiskPrompt = true;
          _showPasswordRiskError = true;
        });
        return;
      }
      await context.read<SettingsCubit>().resetPasswordWithRecovery(
        accountJid: _accountJid,
        resetToken: resetToken,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _step = _RecoveryStep.complete;
      });
    } on provisioning.EmailProvisioningApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = recoveryErrorText(context, error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  VoidCallback? get _primaryAction {
    if (_loading) {
      return null;
    }
    return switch (_step) {
      _RecoveryStep.method => null,
      _RecoveryStep.emailAddress => () async => await _startEmailReset(),
      _RecoveryStep.emailCode => () async => await _verifyEmailCode(),
      _RecoveryStep.totpCode => () async => await _verifyTotpCode(),
      _RecoveryStep.newPassword => () async => await _resetPassword(),
      _RecoveryStep.complete => () => Navigator.of(
        context,
      ).pop(addressLocalPart(_accountJid) ?? _accountJid),
    };
  }

  String get _primaryLabel {
    return switch (_step) {
      _RecoveryStep.method => context.l10n.commonContinue,
      _RecoveryStep.emailAddress => context.l10n.commonContinue,
      _RecoveryStep.emailCode => context.l10n.commonContinue,
      _RecoveryStep.totpCode => context.l10n.commonContinue,
      _RecoveryStep.newPassword => context.l10n.commonContinue,
      _RecoveryStep.complete => context.l10n.commonDone,
    };
  }

  @override
  Widget build(BuildContext context) {
    final endpointConfig = context.watch<SettingsCubit>().state.endpointConfig;
    if (!endpointConfig.isAxiImDomain) {
      return const SizedBox.shrink();
    }
    final spacing = context.spacing;
    return AxiInputDialog(
      title: Text(context.l10n.recoveryTitle),
      loading: _loading,
      callbackText: _primaryLabel,
      callback: _primaryAction,
      canPop: !_loading,
      showPrimaryButton: _step != _RecoveryStep.method,
      actions: [
        if (_canGoBack)
          AxiButton.secondary(
            onPressed: _goBack,
            child: Text(context.l10n.commonBack),
          ),
      ],
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RecoveryStepContent(
              step: _step,
              method: _method,
              errorText: _errorText,
              usernameController: _usernameController,
              recoveryEmailController: _recoveryEmailController,
              codeController: _codeController,
              newPasswordController: _newPasswordController,
              newPasswordConfirmController: _newPasswordConfirmController,
              newPasswordAssessment: _newPasswordAssessment,
              passwordRisk: _showPasswordRiskPrompt
                  ? _visiblePasswordRisk
                  : null,
              passwordRiskAcknowledged: _passwordRiskAcknowledged,
              showPasswordRiskError: _showPasswordRiskError,
              passwordRiskResetTick: _passwordRiskResetTick,
              onPasswordRiskChanged: (value) {
                setState(() {
                  _acknowledgedPasswordRisk = value
                      ? _visiblePasswordRisk
                      : null;
                  if (value) {
                    _showPasswordRiskError = false;
                  }
                });
              },
              enabled: !_loading,
            ),
            if (_step == _RecoveryStep.method) ...[
              SizedBox(height: spacing.m),
              Text(
                context.l10n.recoveryChooseMethod,
                style: context.textTheme.small,
              ),
              SizedBox(height: spacing.s),
              AxiButton.primary(
                widthBehavior: AxiButtonWidth.expand,
                onPressed: _loading
                    ? null
                    : () => _chooseMethod(_RecoveryMethod.email),
                child: Text(context.l10n.recoveryEmailCodeAction),
              ),
              SizedBox(height: spacing.s),
              AxiButton.secondary(
                widthBehavior: AxiButtonWidth.expand,
                onPressed: _loading
                    ? null
                    : () => _chooseMethod(_RecoveryMethod.totp),
                child: Text(context.l10n.recoveryAuthenticatorCodeAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecoveryErrorText extends StatelessWidget {
  const _RecoveryErrorText({required this.errorText});

  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final value = errorText?.trim();
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink();
    }
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.s),
      child: Text(
        value,
        style: context.textTheme.small.copyWith(
          color: context.colorScheme.destructive,
        ),
      ),
    );
  }
}

class _RecoveryStepContent extends StatelessWidget {
  const _RecoveryStepContent({
    required this.step,
    required this.method,
    required this.errorText,
    required this.usernameController,
    required this.recoveryEmailController,
    required this.codeController,
    required this.newPasswordController,
    required this.newPasswordConfirmController,
    required this.newPasswordAssessment,
    required this.passwordRisk,
    required this.passwordRiskAcknowledged,
    required this.showPasswordRiskError,
    required this.passwordRiskResetTick,
    required this.onPasswordRiskChanged,
    required this.enabled,
  });

  final _RecoveryStep step;
  final _RecoveryMethod? method;
  final String? errorText;
  final TextEditingController usernameController;
  final TextEditingController recoveryEmailController;
  final TextEditingController codeController;
  final TextEditingController newPasswordController;
  final TextEditingController newPasswordConfirmController;
  final AuthPasswordAssessment newPasswordAssessment;
  final AuthPasswordRisk? passwordRisk;
  final bool passwordRiskAcknowledged;
  final bool showPasswordRiskError;
  final int passwordRiskResetTick;
  final ValueChanged<bool> onPasswordRiskChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return switch (step) {
      _RecoveryStep.method => _RecoveryUsernameFields(
        controller: usernameController,
        errorText: errorText,
        enabled: enabled,
      ),
      _RecoveryStep.emailAddress => _RecoveryEmailFields(
        usernameController: usernameController,
        recoveryEmailController: recoveryEmailController,
        errorText: errorText,
        enabled: enabled,
      ),
      _RecoveryStep.emailCode => _RecoveryCodeFields(
        description: context.l10n.recoveryNeutralEmailSent,
        controller: codeController,
        errorText: errorText,
        enabled: enabled,
      ),
      _RecoveryStep.totpCode => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RecoveryUsernameFields(
            controller: usernameController,
            enabled: enabled,
          ),
          SizedBox(height: context.spacing.s),
          _RecoveryCodeFields(
            description: context.l10n.recoveryAuthenticatorCodeHint,
            controller: codeController,
            errorText: errorText,
            enabled: enabled,
          ),
        ],
      ),
      _RecoveryStep.newPassword => _RecoveryNewPasswordFields(
        newPasswordController: newPasswordController,
        confirmController: newPasswordConfirmController,
        assessment: newPasswordAssessment,
        passwordRisk: passwordRisk,
        passwordRiskAcknowledged: passwordRiskAcknowledged,
        showPasswordRiskError: showPasswordRiskError,
        passwordRiskResetTick: passwordRiskResetTick,
        onPasswordRiskChanged: onPasswordRiskChanged,
        errorText: errorText,
        enabled: enabled,
      ),
      _RecoveryStep.complete => Text(
        context.l10n.recoveryPasswordResetComplete,
        style: context.textTheme.muted,
      ),
    };
  }
}

class _RecoveryUsernameFields extends StatelessWidget {
  const _RecoveryUsernameFields({
    required this.controller,
    this.errorText,
    required this.enabled,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecoveryErrorText(errorText: errorText),
        AxiTextFormField(
          key: const ValueKey('recovery-username-field'),
          autocorrect: false,
          enabled: enabled,
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          placeholder: Text(context.l10n.authUsername),
          trailing: const _RecoveryAxiImSuffix(),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._-]')),
          ],
          validator: (text) {
            final value = text.trim();
            if (value.isEmpty) {
              return context.l10n.authUsernameRequired;
            }
            if (!isAxiJid('$value@${EndpointConfig.axiImDomain}')) {
              return context.l10n.recoveryAxiAccountRequired;
            }
            return null;
          },
        ),
      ],
    );
  }
}

class _RecoveryAxiImSuffix extends StatelessWidget {
  const _RecoveryAxiImSuffix();

  @override
  Widget build(BuildContext context) {
    return Text(
      '@${EndpointConfig.axiImDomain}',
      style: context.textTheme.small.copyWith(
        color: context.colorScheme.foreground,
      ),
    );
  }
}

class _RecoveryEmailFields extends StatelessWidget {
  const _RecoveryEmailFields({
    required this.usernameController,
    required this.recoveryEmailController,
    required this.errorText,
    required this.enabled,
  });

  final TextEditingController usernameController;
  final TextEditingController recoveryEmailController;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecoveryUsernameFields(
          controller: usernameController,
          enabled: enabled,
        ),
        SizedBox(height: context.spacing.s),
        _RecoveryErrorText(errorText: errorText),
        AxiTextFormField(
          autocorrect: false,
          enabled: enabled,
          controller: recoveryEmailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          placeholder: Text(context.l10n.recoveryEmailPlaceholder),
          validator: (text) {
            if (text.trim().isEmpty) {
              return context.l10n.recoveryEmailRequired;
            }
            return null;
          },
        ),
      ],
    );
  }
}

class _RecoveryCodeFields extends StatelessWidget {
  const _RecoveryCodeFields({
    required this.description,
    required this.controller,
    required this.errorText,
    required this.enabled,
  });

  final String description;
  final TextEditingController controller;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(description, style: context.textTheme.muted),
        SizedBox(height: context.spacing.s),
        _RecoveryErrorText(errorText: errorText),
        AxiOtpFormField(
          enabled: enabled,
          controller: controller,
          validator: (text) {
            final value = text.trim();
            if (value.isEmpty) {
              return context.l10n.recoveryCodeRequired;
            }
            if (value.length != AxiOtpFormField.defaultLength) {
              return context.l10n.recoveryCodeIncomplete;
            }
            return null;
          },
        ),
      ],
    );
  }
}

class _RecoveryNewPasswordFields extends StatelessWidget {
  const _RecoveryNewPasswordFields({
    required this.newPasswordController,
    required this.confirmController,
    required this.assessment,
    required this.passwordRisk,
    required this.passwordRiskAcknowledged,
    required this.showPasswordRiskError,
    required this.passwordRiskResetTick,
    required this.onPasswordRiskChanged,
    required this.errorText,
    required this.enabled,
  });

  final TextEditingController newPasswordController;
  final TextEditingController confirmController;
  final AuthPasswordAssessment assessment;
  final AuthPasswordRisk? passwordRisk;
  final bool passwordRiskAcknowledged;
  final bool showPasswordRiskError;
  final int passwordRiskResetTick;
  final ValueChanged<bool> onPasswordRiskChanged;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final animationDuration = context.watch<SettingsCubit>().animationDuration;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.recoveryNewPasswordHint,
          style: context.textTheme.muted,
        ),
        SizedBox(height: context.spacing.s),
        _RecoveryErrorText(errorText: errorText),
        PasswordInput(
          enabled: enabled,
          controller: newPasswordController,
          placeholder: context.l10n.authPasswordNewPlaceholder,
        ),
        SizedBox(height: context.spacing.s),
        PasswordInput(
          enabled: enabled,
          controller: confirmController,
          placeholder: context.l10n.authPasswordConfirmNewPlaceholder,
          confirmValidator: (value) {
            if (value != newPasswordController.text) {
              return context.l10n.authPasswordsMismatch;
            }
            return null;
          },
        ),
        SizedBox(height: context.spacing.s),
        AuthPasswordStrengthMeter(
          assessment: assessment,
          showBreachWarning: passwordRisk == AuthPasswordRisk.breached,
          showSafetyUnavailableWarning:
              passwordRisk == AuthPasswordRisk.unavailable,
          animationDuration: animationDuration,
        ),
        SizedBox(height: context.spacing.s),
        AuthPasswordRiskNotice(
          risk: passwordRisk,
          allowed: passwordRiskAcknowledged,
          enabled: enabled,
          showError: showPasswordRiskError,
          animationDuration: animationDuration,
          resetTick: passwordRiskResetTick,
          onChanged: onPasswordRiskChanged,
        ),
      ],
    );
  }
}

String recoveryErrorText(
  BuildContext context,
  provisioning.EmailProvisioningApiException error,
) {
  if (error is provisioning.EmailProvisioningApiNetworkException) {
    return context.l10n.authEmailServerUnreachable;
  }
  if (error is provisioning.EmailProvisioningApiUnavailableException) {
    return context.l10n.messageErrorServiceUnavailable;
  }
  if (error is provisioning.EmailProvisioningApiRejectedException) {
    return switch (error.code) {
      provisioning.EmailProvisioningApiErrorCode.authFailed =>
        context.l10n.authPasswordIncorrect,
      provisioning.EmailProvisioningApiErrorCode.invalidCode =>
        context.l10n.recoveryInvalidCode,
      provisioning.EmailProvisioningApiErrorCode.challengeExpired =>
        context.l10n.recoveryChallengeExpired,
      provisioning.EmailProvisioningApiErrorCode.challengeFailed =>
        context.l10n.recoveryChallengeFailed,
      provisioning.EmailProvisioningApiErrorCode.rateLimited =>
        context.l10n.authRateLimited,
      provisioning.EmailProvisioningApiErrorCode.recoveryNotConfigured =>
        context.l10n.recoveryNotConfigured,
      provisioning.EmailProvisioningApiErrorCode.repairRequired =>
        context.l10n.authAccountRepairRequired,
      provisioning.EmailProvisioningApiErrorCode.idempotencyConflict =>
        context.l10n.authIdempotencyConflict,
      provisioning.EmailProvisioningApiErrorCode.invalidResetToken ||
      provisioning.EmailProvisioningApiErrorCode.resetTokenExpired =>
        context.l10n.recoveryRestartRequired,
      provisioning.EmailProvisioningApiErrorCode.xmppServiceUnavailable =>
        context.l10n.messageErrorServiceUnavailable,
      provisioning.EmailProvisioningApiErrorCode.unknown =>
        context.l10n.recoveryGenericError,
    };
  }
  return context.l10n.recoveryGenericError;
}
