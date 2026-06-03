// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/email_provisioning_client.dart'
    as provisioning;
import 'package:axichat/src/authentication/view/recovery_dialog.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AccountRecoverySettingsPage extends StatefulWidget {
  const AccountRecoverySettingsPage({super.key, this.active = true});

  final bool active;

  static String title(AppLocalizations l10n) => l10n.recoverySettingsTitle;

  @override
  State<AccountRecoverySettingsPage> createState() =>
      _AccountRecoverySettingsPageState();
}

Future<bool> showRecoveryEmailSetupDialog(
  BuildContext context, {
  required String accountJid,
  String? currentPassword,
  bool allowPasswordPrompt = true,
}) async {
  final result = await _showRecoveryEmailSetupDialog(
    context,
    accountJid: accountJid,
    currentPassword: currentPassword,
    allowPasswordPrompt: allowPasswordPrompt,
  );
  return result != null;
}

Future<_RecoveryMutationResult?> _showRecoveryEmailSetupDialog(
  BuildContext context, {
  required String accountJid,
  String? currentPassword,
  bool allowPasswordPrompt = true,
}) async {
  if (!context.read<SettingsCubit>().state.endpointConfig.isAxiImDomain ||
      !isAxiJid(accountJid)) {
    return null;
  }
  return showFadeScaleDialog<_RecoveryMutationResult>(
    context: context,
    builder: (_) => _RecoveryEmailSetupDialog(
      accountJid: accountJid,
      currentPassword: currentPassword,
      allowPasswordPrompt: allowPasswordPrompt,
    ),
  );
}

Future<bool> showRecoveryTotpSetupDialog(
  BuildContext context, {
  required String accountJid,
  String? currentPassword,
  bool allowPasswordPrompt = true,
}) async {
  final result = await _showRecoveryTotpSetupDialog(
    context,
    accountJid: accountJid,
    currentPassword: currentPassword,
    allowPasswordPrompt: allowPasswordPrompt,
  );
  return result != null;
}

Future<_RecoveryMutationResult?> _showRecoveryTotpSetupDialog(
  BuildContext context, {
  required String accountJid,
  String? currentPassword,
  bool allowPasswordPrompt = true,
}) async {
  if (!context.read<SettingsCubit>().state.endpointConfig.isAxiImDomain ||
      !isAxiJid(accountJid)) {
    return null;
  }
  return showFadeScaleDialog<_RecoveryMutationResult>(
    context: context,
    builder: (_) => _RecoveryTotpSetupDialog(
      accountJid: accountJid,
      currentPassword: currentPassword,
      allowPasswordPrompt: allowPasswordPrompt,
    ),
  );
}

Future<String?> showRecoveryPasswordPromptDialog(BuildContext context) {
  return showFadeScaleDialog<String>(
    context: context,
    builder: (_) => const _RecoveryPasswordPromptDialog(),
  );
}

class _AccountRecoverySettingsPageState
    extends State<AccountRecoverySettingsPage> {
  final _statusPasswordFormKey = GlobalKey<FormState>();
  final _statusPasswordController = TextEditingController();
  String? _currentPassword;
  String? _currentPasswordAccountJid;
  provisioning.RecoveryStatus? _status;
  String? _errorText;
  bool _loading = false;

  @override
  void didUpdateWidget(AccountRecoverySettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) {
      _clearRecoveryPassword();
      _status = null;
      _errorText = null;
    }
  }

  @override
  void dispose() {
    _clearRecoveryPassword();
    _statusPasswordController.clear();
    _statusPasswordController.dispose();
    super.dispose();
  }

  String get _accountJid => context.read<ProfileCubit>().state.jid;

  void _clearRecoveryPassword() {
    _currentPassword = null;
    _currentPasswordAccountJid = null;
  }

  void _rememberRecoveryPassword(String password) {
    _currentPassword = password;
    _currentPasswordAccountJid = _accountJid;
  }

  String? get _sessionRecoveryPassword {
    final password = _currentPassword;
    if (password == null) {
      return null;
    }
    if (_currentPasswordAccountJid != _accountJid) {
      _clearRecoveryPassword();
      return null;
    }
    return password;
  }

  Future<String?> _currentRecoveryPassword() async {
    final sessionPassword = _sessionRecoveryPassword;
    if (sessionPassword != null) {
      return sessionPassword;
    }
    final password = await showRecoveryPasswordPromptDialog(context);
    final trimmedPassword = password?.trim();
    if (!mounted || trimmedPassword == null || trimmedPassword.isEmpty) {
      return null;
    }
    return password;
  }

  Future<void> _submitStatusPassword() async {
    final form = _statusPasswordFormKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final password = _statusPasswordController.text;
    _statusPasswordController.clear();
    await _loadStatus(password);
  }

  Future<void> _refreshStatus() async {
    final currentPassword = await _currentRecoveryPassword();
    if (!mounted || currentPassword == null) {
      return;
    }
    await _loadStatus(currentPassword);
  }

  Future<void> _loadStatus(String currentPassword) async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final status = await context.read<SettingsCubit>().recoveryStatus(
        accountJid: _accountJid,
        password: currentPassword,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _rememberRecoveryPassword(currentPassword);
        _status = status;
      });
    } on provisioning.EmailProvisioningApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error is provisioning.EmailProvisioningApiRejectedException &&
          error.code == provisioning.EmailProvisioningApiErrorCode.authFailed) {
        _clearRecoveryPassword();
        _status = null;
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

  Future<void> _showEmailSetup() async {
    final currentPassword = await _currentRecoveryPassword();
    if (!mounted || currentPassword == null) {
      return;
    }
    final result = await _showRecoveryEmailSetupDialog(
      context,
      accountJid: _accountJid,
      currentPassword: currentPassword,
    );
    if (!mounted || result == null) {
      return;
    }
    _rememberRecoveryPassword(result.currentPassword);
    await _loadStatus(result.currentPassword);
  }

  Future<void> _showTotpSetup() async {
    final currentPassword = await _currentRecoveryPassword();
    if (!mounted || currentPassword == null) {
      return;
    }
    final result = await _showRecoveryTotpSetupDialog(
      context,
      accountJid: _accountJid,
      currentPassword: currentPassword,
    );
    if (!mounted || result == null) {
      return;
    }
    _rememberRecoveryPassword(result.currentPassword);
    await _loadStatus(result.currentPassword);
  }

  Future<void> _showRemoveEmail() async {
    final currentPassword = await _currentRecoveryPassword();
    if (!mounted || currentPassword == null) {
      return;
    }
    final result = await showFadeScaleDialog<_RecoveryMutationResult>(
      context: context,
      builder: (_) => _RecoveryRemoveDialog(
        accountJid: _accountJid,
        method: _RecoveryRemoveMethod.email,
        currentPassword: currentPassword,
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    _rememberRecoveryPassword(result.currentPassword);
    await _loadStatus(result.currentPassword);
  }

  Future<void> _showRemoveTotp() async {
    final currentPassword = await _currentRecoveryPassword();
    if (!mounted || currentPassword == null) {
      return;
    }
    final result = await showFadeScaleDialog<_RecoveryMutationResult>(
      context: context,
      builder: (_) => _RecoveryRemoveDialog(
        accountJid: _accountJid,
        method: _RecoveryRemoveMethod.totp,
        currentPassword: currentPassword,
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    _rememberRecoveryPassword(result.currentPassword);
    await _loadStatus(result.currentPassword);
  }

  @override
  Widget build(BuildContext context) {
    final accountJid = context.watch<ProfileCubit>().state.jid;
    final endpointConfig = context.watch<SettingsCubit>().state.endpointConfig;
    if (!endpointConfig.isAxiImDomain || !isAxiJid(accountJid)) {
      return const SizedBox.shrink();
    }
    final spacing = context.spacing;
    final status = _status;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AccountRecoverySettingsPage.title(context.l10n),
          textAlign: TextAlign.center,
          style: context.textTheme.h3,
        ),
        SizedBox(height: spacing.s),
        Text(
          status == null
              ? context.l10n.recoverySettingsPasswordDescription
              : context.l10n.recoverySettingsDescription,
          textAlign: TextAlign.center,
          style: context.textTheme.muted,
        ),
        SizedBox(height: spacing.m),
        if (status == null)
          _RecoveryStatusPasswordForm(
            formKey: _statusPasswordFormKey,
            controller: _statusPasswordController,
            errorText: _errorText,
            loading: _loading,
            onSubmit: _submitStatusPassword,
          )
        else ...[
          _RecoverySettingsErrorText(errorText: _errorText),
          _RecoverySettingsMethodButton(
            iconData: LucideIcons.mail,
            title: context.l10n.recoveryEmailTitle,
            value: status.recoveryEmailConfigured
                ? status.maskedRecoveryEmail ?? context.l10n.recoveryEnabled
                : context.l10n.recoveryNotSet,
            actionIconData: status.recoveryEmailConfigured
                ? LucideIcons.pencil
                : LucideIcons.plus,
            onPressed: _showEmailSetup,
          ),
          SizedBox(height: spacing.s),
          if (status.recoveryEmailConfigured) ...[
            _RecoverySettingsRemoveButton(
              iconData: LucideIcons.trash2,
              title: context.l10n.recoveryRemoveEmailTitle,
              onPressed: _showRemoveEmail,
            ),
            SizedBox(height: spacing.s),
          ],
          _RecoverySettingsMethodButton(
            iconData: LucideIcons.smartphone,
            title: context.l10n.recoveryTotpTitle,
            value: status.totpConfigured
                ? context.l10n.recoveryEnabled
                : context.l10n.recoveryNotSet,
            actionIconData: status.totpConfigured
                ? LucideIcons.pencil
                : LucideIcons.plus,
            onPressed: _showTotpSetup,
          ),
          if (status.totpConfigured) ...[
            SizedBox(height: spacing.s),
            _RecoverySettingsRemoveButton(
              iconData: LucideIcons.trash2,
              title: context.l10n.recoveryRemoveTotpTitle,
              onPressed: _showRemoveTotp,
            ),
          ],
        ],
        if (status != null) ...[
          SizedBox(height: spacing.s),
          Align(
            alignment: Alignment.center,
            child: AxiButton.secondary(
              loading: _loading,
              onPressed: _loading ? null : _refreshStatus,
              child: Text(context.l10n.commonRefresh),
            ),
          ),
        ],
      ],
    );
  }
}

class _RecoveryStatusPasswordForm extends StatelessWidget {
  const _RecoveryStatusPasswordForm({
    required this.formKey,
    required this.controller,
    required this.errorText,
    required this.loading,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final String? errorText;
  final bool loading;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RecoverySettingsErrorText(errorText: errorText),
          Padding(
            padding: EdgeInsets.all(spacing.s),
            child: PasswordInput(
              controller: controller,
              enabled: !loading,
              placeholder: context.l10n.authPasswordPlaceholder,
              textInputAction: TextInputAction.done,
              onEditingComplete: () async => await onSubmit(),
            ),
          ),
          SizedBox(height: spacing.s),
          Align(
            alignment: Alignment.center,
            child: AxiButton.primary(
              loading: loading,
              onPressed: loading ? null : () async => await onSubmit(),
              child: Text(context.l10n.commonContinue),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoverySettingsMethodButton extends StatelessWidget {
  const _RecoverySettingsMethodButton({
    required this.iconData,
    required this.title,
    required this.value,
    required this.actionIconData,
    required this.onPressed,
  });

  final IconData iconData;
  final String title;
  final String value;
  final IconData actionIconData;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final sizing = context.sizing;
    return AxiListButton(
      onPressed: onPressed,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconData, size: sizing.menuItemIconSize),
          SizedBox(width: spacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.textTheme.small),
                SizedBox(height: spacing.xs),
                Text(value, style: context.textTheme.muted),
              ],
            ),
          ),
          SizedBox(width: spacing.s),
          Icon(actionIconData, size: sizing.menuItemIconSize),
        ],
      ),
    );
  }
}

class _RecoverySettingsRemoveButton extends StatelessWidget {
  const _RecoverySettingsRemoveButton({
    required this.iconData,
    required this.title,
    required this.onPressed,
  });

  final IconData iconData;
  final String title;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AxiListButton.destructiveGhost(
      leading: Icon(iconData, size: context.sizing.menuItemIconSize),
      onPressed: onPressed,
      child: Text(title),
    );
  }
}

class _RecoveryMutationResult {
  const _RecoveryMutationResult({required this.currentPassword});

  final String currentPassword;
}

class _RecoveryPasswordPromptDialog extends StatefulWidget {
  const _RecoveryPasswordPromptDialog();

  @override
  State<_RecoveryPasswordPromptDialog> createState() =>
      _RecoveryPasswordPromptDialogState();
}

class _RecoveryPasswordPromptDialogState
    extends State<_RecoveryPasswordPromptDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.clear();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final password = _passwordController.text;
    _passwordController.clear();
    Navigator.of(context).pop(password);
  }

  @override
  Widget build(BuildContext context) {
    return AxiInputDialog(
      title: Text(context.l10n.authPassword),
      callback: _submit,
      callbackText: context.l10n.commonContinue,
      content: Form(
        key: _formKey,
        child: PasswordInput(
          controller: _passwordController,
          enabled: true,
          placeholder: context.l10n.authPasswordPlaceholder,
          textInputAction: TextInputAction.done,
          onEditingComplete: _submit,
        ),
      ),
    );
  }
}

class _RecoveryEmailSetupDialog extends StatefulWidget {
  const _RecoveryEmailSetupDialog({
    required this.accountJid,
    this.currentPassword,
    required this.allowPasswordPrompt,
  });

  final String accountJid;
  final String? currentPassword;
  final bool allowPasswordPrompt;

  @override
  State<_RecoveryEmailSetupDialog> createState() =>
      _RecoveryEmailSetupDialogState();
}

class _RecoveryEmailSetupDialogState extends State<_RecoveryEmailSetupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  String? _challenge;
  String? _errorText;
  bool _passwordOverrideRequired = false;
  bool _loading = false;

  @override
  void dispose() {
    _passwordController.clear();
    _passwordController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _password => _passwordOverrideRequired
      ? _passwordController.text
      : widget.currentPassword ?? _passwordController.text;

  void _handleApiError(provisioning.EmailProvisioningApiException error) {
    if (error is provisioning.EmailProvisioningApiRejectedException &&
        error.code == provisioning.EmailProvisioningApiErrorCode.authFailed &&
        widget.allowPasswordPrompt &&
        widget.currentPassword != null) {
      _passwordOverrideRequired = true;
    }
    _errorText = recoveryErrorText(context, error);
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final challenge = _challenge;
      if (challenge == null) {
        final started = await context
            .read<SettingsCubit>()
            .startRecoveryEmailSetup(
              accountJid: widget.accountJid,
              password: _password,
              recoveryEmail: _emailController.text,
            );
        if (!mounted) {
          return;
        }
        setState(() {
          _challenge = started?.challenge;
        });
        return;
      }
      await context.read<SettingsCubit>().confirmRecoveryEmailSetup(
        accountJid: widget.accountJid,
        password: _password,
        challenge: challenge,
        code: _codeController.text,
      );
      if (mounted) {
        context.pop(_RecoveryMutationResult(currentPassword: _password));
      }
    } on provisioning.EmailProvisioningApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _handleApiError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<SettingsCubit>().state.endpointConfig.isAxiImDomain ||
        !isAxiJid(widget.accountJid)) {
      return const SizedBox.shrink();
    }
    return AxiInputDialog(
      title: Text(context.l10n.recoveryEmailTitle),
      loading: _loading,
      callback: _submit,
      callbackText: context.l10n.commonContinue,
      canPop: !_loading,
      content: _RecoveryEmailSetupFields(
        formKey: _formKey,
        passwordController: _passwordController,
        emailController: _emailController,
        codeController: _codeController,
        challengeStarted: _challenge != null,
        showPasswordField:
            widget.allowPasswordPrompt &&
            (_passwordOverrideRequired ||
                (widget.currentPassword == null && _challenge == null)),
        errorText: _errorText,
        enabled: !_loading,
      ),
    );
  }
}

class _RecoveryEmailSetupFields extends StatelessWidget {
  const _RecoveryEmailSetupFields({
    required this.formKey,
    required this.passwordController,
    required this.emailController,
    required this.codeController,
    required this.challengeStarted,
    required this.showPasswordField,
    required this.errorText,
    required this.enabled,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController passwordController;
  final TextEditingController emailController;
  final TextEditingController codeController;
  final bool challengeStarted;
  final bool showPasswordField;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RecoverySettingsErrorText(errorText: errorText),
          if (!challengeStarted) ...[
            if (showPasswordField) ...[
              PasswordInput(
                enabled: enabled,
                controller: passwordController,
                placeholder: context.l10n.authPasswordPlaceholder,
              ),
              SizedBox(height: spacing.s),
            ],
            AxiTextFormField(
              enabled: enabled,
              autocorrect: false,
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              placeholder: Text(context.l10n.recoveryEmailPlaceholder),
              validator: (text) => text.trim().isEmpty
                  ? context.l10n.recoveryEmailRequired
                  : null,
            ),
          ] else ...[
            Text(
              context.l10n.recoveryEmailSetupCodeHint,
              style: context.textTheme.muted,
            ),
            SizedBox(height: spacing.s),
            if (showPasswordField) ...[
              PasswordInput(
                enabled: enabled,
                controller: passwordController,
                placeholder: context.l10n.authPasswordPlaceholder,
              ),
              SizedBox(height: spacing.s),
            ],
            AxiOtpFormField(
              enabled: enabled,
              controller: codeController,
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
        ],
      ),
    );
  }
}

class _RecoveryTotpSetupDialog extends StatefulWidget {
  const _RecoveryTotpSetupDialog({
    required this.accountJid,
    this.currentPassword,
    required this.allowPasswordPrompt,
  });

  final String accountJid;
  final String? currentPassword;
  final bool allowPasswordPrompt;

  @override
  State<_RecoveryTotpSetupDialog> createState() =>
      _RecoveryTotpSetupDialogState();
}

class _RecoveryTotpSetupDialogState extends State<_RecoveryTotpSetupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  provisioning.RecoveryTotpSetup? _setup;
  String? _errorText;
  bool _passwordOverrideRequired = false;
  bool _loading = false;

  @override
  void dispose() {
    _passwordController.clear();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _password => _passwordOverrideRequired
      ? _passwordController.text
      : widget.currentPassword ?? _passwordController.text;

  void _handleApiError(provisioning.EmailProvisioningApiException error) {
    if (error is provisioning.EmailProvisioningApiRejectedException &&
        error.code == provisioning.EmailProvisioningApiErrorCode.authFailed &&
        widget.allowPasswordPrompt &&
        widget.currentPassword != null) {
      _passwordOverrideRequired = true;
    }
    _errorText = recoveryErrorText(context, error);
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final setup = _setup;
      if (setup == null) {
        final started = await context
            .read<SettingsCubit>()
            .startRecoveryTotpSetup(
              accountJid: widget.accountJid,
              password: _password,
            );
        if (!mounted) {
          return;
        }
        setState(() {
          _setup = started;
        });
        return;
      }
      await context.read<SettingsCubit>().confirmRecoveryTotpSetup(
        accountJid: widget.accountJid,
        password: _password,
        challenge: setup.challenge,
        code: _codeController.text,
      );
      if (mounted) {
        context.pop(_RecoveryMutationResult(currentPassword: _password));
      }
    } on provisioning.EmailProvisioningApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _handleApiError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<SettingsCubit>().state.endpointConfig.isAxiImDomain ||
        !isAxiJid(widget.accountJid)) {
      return const SizedBox.shrink();
    }
    return AxiInputDialog(
      title: Text(context.l10n.recoveryTotpTitle),
      loading: _loading,
      callback: _submit,
      callbackText: context.l10n.commonContinue,
      canPop: !_loading,
      content: _RecoveryTotpSetupFields(
        formKey: _formKey,
        passwordController: _passwordController,
        codeController: _codeController,
        setup: _setup,
        showPasswordField:
            widget.allowPasswordPrompt &&
            (_passwordOverrideRequired ||
                (widget.currentPassword == null && _setup == null)),
        errorText: _errorText,
        enabled: !_loading,
      ),
    );
  }
}

class _RecoveryTotpSetupFields extends StatelessWidget {
  const _RecoveryTotpSetupFields({
    required this.formKey,
    required this.passwordController,
    required this.codeController,
    required this.setup,
    required this.showPasswordField,
    required this.errorText,
    required this.enabled,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController passwordController;
  final TextEditingController codeController;
  final provisioning.RecoveryTotpSetup? setup;
  final bool showPasswordField;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final currentSetup = setup;
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RecoverySettingsErrorText(errorText: errorText),
          if (currentSetup == null)
            if (showPasswordField)
              PasswordInput(
                enabled: enabled,
                controller: passwordController,
                placeholder: context.l10n.authPasswordPlaceholder,
              )
            else
              Text(
                context.l10n.recoveryTotpSetupStartHint,
                style: context.textTheme.muted,
              )
          else ...[
            Text(
              context.l10n.recoveryTotpSetupHint,
              style: context.textTheme.muted,
            ),
            SizedBox(height: spacing.s),
            if (showPasswordField) ...[
              PasswordInput(
                enabled: enabled,
                controller: passwordController,
                placeholder: context.l10n.authPasswordPlaceholder,
              ),
              SizedBox(height: spacing.s),
            ],
            _RecoveryTotpQrCode(otpauthUri: currentSetup.otpauthUri),
            SizedBox(height: spacing.s),
            SelectableText(currentSetup.secret, style: context.textTheme.small),
            SizedBox(height: spacing.s),
            SelectableText(
              currentSetup.otpauthUri,
              style: context.textTheme.muted,
            ),
            SizedBox(height: spacing.s),
            AxiOtpFormField(
              enabled: enabled,
              controller: codeController,
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
        ],
      ),
    );
  }
}

class _RecoveryTotpQrCode extends StatelessWidget {
  const _RecoveryTotpQrCode({required this.otpauthUri});

  final String otpauthUri;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: context.sizing.profileHeaderCompactMaxWidth,
        ),
        child: AxiModalSurface(
          backgroundColor: colors.background,
          padding: EdgeInsets.all(context.spacing.s),
          child: AspectRatio(
            aspectRatio: 1,
            child: QrImageView(
              data: otpauthUri,
              padding: EdgeInsets.zero,
              backgroundColor: colors.background,
              eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: colors.foreground,
              ),
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: colors.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _RecoveryRemoveMethod {
  email,
  totp;

  String title(AppLocalizations l10n) => switch (this) {
    email => l10n.recoveryRemoveEmailTitle,
    totp => l10n.recoveryRemoveTotpTitle,
  };
}

class _RecoveryRemoveDialog extends StatefulWidget {
  const _RecoveryRemoveDialog({
    required this.accountJid,
    required this.method,
    required this.currentPassword,
  });

  final String accountJid;
  final _RecoveryRemoveMethod method;
  final String currentPassword;

  @override
  State<_RecoveryRemoveDialog> createState() => _RecoveryRemoveDialogState();
}

class _RecoveryRemoveDialogState extends State<_RecoveryRemoveDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  String? _errorText;
  bool _passwordOverrideRequired = false;
  bool _loading = false;

  @override
  void dispose() {
    _passwordController.clear();
    _passwordController.dispose();
    super.dispose();
  }

  String get _password => _passwordOverrideRequired
      ? _passwordController.text
      : widget.currentPassword;

  void _handleApiError(provisioning.EmailProvisioningApiException error) {
    if (error is provisioning.EmailProvisioningApiRejectedException &&
        error.code == provisioning.EmailProvisioningApiErrorCode.authFailed) {
      _passwordOverrideRequired = true;
    }
    _errorText = recoveryErrorText(context, error);
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      switch (widget.method) {
        case _RecoveryRemoveMethod.email:
          await context.read<SettingsCubit>().removeRecoveryEmail(
            accountJid: widget.accountJid,
            password: _password,
          );
        case _RecoveryRemoveMethod.totp:
          await context.read<SettingsCubit>().removeRecoveryTotp(
            accountJid: widget.accountJid,
            password: _password,
          );
      }
      if (mounted) {
        context.pop(_RecoveryMutationResult(currentPassword: _password));
      }
    } on provisioning.EmailProvisioningApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _handleApiError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<SettingsCubit>().state.endpointConfig.isAxiImDomain ||
        !isAxiJid(widget.accountJid)) {
      return const SizedBox.shrink();
    }
    return AxiInputDialog(
      title: Text(widget.method.title(context.l10n)),
      loading: _loading,
      callback: _submit,
      callbackText: context.l10n.commonRemove,
      canPop: !_loading,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RecoverySettingsErrorText(errorText: _errorText),
            Text(
              context.l10n.recoveryRemoveConfirmMessage,
              style: context.textTheme.muted,
            ),
            if (_passwordOverrideRequired) ...[
              SizedBox(height: context.spacing.s),
              PasswordInput(
                enabled: !_loading,
                controller: _passwordController,
                placeholder: context.l10n.authPasswordPlaceholder,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecoverySettingsErrorText extends StatelessWidget {
  const _RecoverySettingsErrorText({required this.errorText});

  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final value = errorText?.trim();
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.s),
      child: Text(
        value,
        style: context.textTheme.small.copyWith(
          color: context.colorScheme.destructive,
        ),
      ),
    );
  }
}
