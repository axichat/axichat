// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/bloc/email_provisioning_client.dart'
    as provisioning;
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/notifications/view/notification_request.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/settings/view/account_recovery_settings.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum EmailForwardingProvider { gmail, outlook }

extension EmailForwardingProviderMetadata on EmailForwardingProvider {
  static const String _gmailForwardingUrl =
      'https://support.google.com/mail/answer/10957';
  static const String _outlookForwardingUrl =
      'https://support.microsoft.com/en-us/office/turn-on-automatic-forwarding-in-outlook-7f2670a1-7fff-4475-8a3c-5822d63b0c8e';

  String label(AppLocalizations l10n) {
    switch (this) {
      case EmailForwardingProvider.gmail:
        return l10n.emailForwardingProviderGmail;
      case EmailForwardingProvider.outlook:
        return l10n.emailForwardingProviderOutlook;
    }
  }

  String get helpUrl {
    switch (this) {
      case EmailForwardingProvider.gmail:
        return _gmailForwardingUrl;
      case EmailForwardingProvider.outlook:
        return _outlookForwardingUrl;
    }
  }

  IconData get iconData {
    switch (this) {
      case EmailForwardingProvider.gmail:
        return FontAwesomeIcons.google;
      case EmailForwardingProvider.outlook:
        return FontAwesomeIcons.microsoft;
    }
  }
}

class EmailForwardingGuideTile extends StatelessWidget {
  const EmailForwardingGuideTile({super.key});

  Future<void> _showGuideDialog(BuildContext context) async {
    final l10n = context.l10n;
    final forwardingAddress = _resolveForwardingAddress(
      context.read<XmppService>(),
    );
    await showFadeScaleDialog<void>(
      context: context,
      builder: (dialogContext) => EmailForwardingGuideDialog(
        title: l10n.emailForwardingGuideTitle,
        forwardingAddress: forwardingAddress,
      ),
    );
    if (!context.mounted) {
      return;
    }
    context.read<SettingsCubit>().markEmailForwardingGuideSeen();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListItemPadding(
      child: AxiListTile(
        leading: const Icon(LucideIcons.mail),
        title: l10n.emailForwardingGuideTitle,
        subtitle: l10n.emailForwardingGuideSubtitle,
        onTap: () => _showGuideDialog(context),
      ),
    );
  }
}

class EmailForwardingGuideActionButton extends StatelessWidget {
  const EmailForwardingGuideActionButton({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  Future<void> _showGuideDialog(BuildContext context) async {
    final forwardingAddress = _resolveForwardingAddress(
      context.read<XmppService>(),
    );
    await showFadeScaleDialog<void>(
      context: context,
      builder: (dialogContext) => EmailForwardingGuideDialog(
        title: context.l10n.emailForwardingGuideTitle,
        forwardingAddress: forwardingAddress,
      ),
    );
    if (!context.mounted) {
      return;
    }
    context.read<SettingsCubit>().markEmailForwardingGuideSeen();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Padding(
      padding:
          padding ??
          EdgeInsets.symmetric(horizontal: spacing.l, vertical: spacing.xs),
      child: AxiListButton(
        leading: const Icon(LucideIcons.mail),
        onPressed: () async => await _showGuideDialog(context),
        child: Text(context.l10n.emailForwardingGuideTitle),
      ),
    );
  }
}

class EmailForwardingGuideDialog extends StatelessWidget {
  const EmailForwardingGuideDialog({
    super.key,
    required this.title,
    required this.forwardingAddress,
  });

  final String title;
  final String forwardingAddress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AxiInputDialog(
      title: Text(title),
      content: EmailForwardingGuideContent(
        forwardingAddress: forwardingAddress,
      ),
      callbackText: l10n.commonDone,
      callback: () => context.pop(),
    );
  }
}

class AccountWelcomeDialog extends StatelessWidget {
  const AccountWelcomeDialog({
    super.key,
    required this.accountJid,
    required this.showEmailOnboarding,
    required this.showRecoveryPrompt,
    required this.onForegroundActivationStarted,
    required this.onForegroundActivationFinished,
    required this.onForegroundActivated,
    required this.onRecoveryDismissed,
    required this.onRecoveryConfigured,
  });

  final String accountJid;
  final bool showEmailOnboarding;
  final bool showRecoveryPrompt;
  final void Function() onForegroundActivationStarted;
  final void Function() onForegroundActivationFinished;
  final Future<void> Function() onForegroundActivated;
  final Future<void> Function() onRecoveryDismissed;
  final Future<void> Function() onRecoveryConfigured;

  Future<void> _dismiss(BuildContext context) async {
    if (showRecoveryPrompt) {
      await onRecoveryDismissed();
    }
    if (context.mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: spacing.l,
        vertical: spacing.l,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.sizing.dialogMaxWidth),
        child: AxiModalSurface(
          padding: EdgeInsets.zero,
          child: AxiSheetScaffold.scroll(
            header: AxiSheetHeader(
              title: Text(l10n.emailForwardingWelcomeTitle),
              onClose: () => _dismiss(context),
            ),
            footer: Padding(
              padding: EdgeInsets.fromLTRB(spacing.m, 0, spacing.m, spacing.m),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showEmailOnboarding) ...[
                    Text(
                      l10n.emailForwardingGuideSettingsHint,
                      style: context.textTheme.muted,
                    ),
                    SizedBox(height: spacing.s),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: AxiButton.outline(
                      onPressed: () => _dismiss(context),
                      child: Text(l10n.emailForwardingGuideSkipLabel),
                    ),
                  ),
                ],
              ),
            ),
            children: [
              if (showEmailOnboarding)
                EmailOnboardingWelcomeContent(
                  onForegroundActivationStarted: onForegroundActivationStarted,
                  onForegroundActivationFinished:
                      onForegroundActivationFinished,
                  onForegroundActivated: onForegroundActivated,
                ),
              if (showRecoveryPrompt) ...[
                if (showEmailOnboarding) SizedBox(height: spacing.xl),
                AccountRecoveryWelcomeContent(
                  accountJid: accountJid,
                  onRecoveryDismissed: onRecoveryDismissed,
                  onRecoveryConfigured: onRecoveryConfigured,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EmailOnboardingWelcomeContent extends StatelessWidget {
  const EmailOnboardingWelcomeContent({
    super.key,
    required this.onForegroundActivationStarted,
    required this.onForegroundActivationFinished,
    required this.onForegroundActivated,
  });

  final void Function() onForegroundActivationStarted;
  final void Function() onForegroundActivationFinished;
  final Future<void> Function() onForegroundActivated;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.emailForwardingWelcomeSetupFrom,
          style: context.textTheme.large,
        ),
        SizedBox(height: spacing.s),
        const EmailForwardingProviderLinkList(),
        SizedBox(height: spacing.s),
        Text(
          l10n.emailForwardingWelcomeOtherProviderHint,
          style: context.textTheme.muted,
        ),
        SizedBox(height: spacing.xl),
        NotificationRequest(
          allowCurrentSessionMigration: true,
          onForegroundActivationStarted: onForegroundActivationStarted,
          onForegroundActivationFinished: onForegroundActivationFinished,
          onForegroundActivated: onForegroundActivated,
        ),
      ],
    );
  }
}

class AccountRecoveryWelcomeContent extends StatelessWidget {
  const AccountRecoveryWelcomeContent({
    super.key,
    required this.accountJid,
    required this.onRecoveryDismissed,
    required this.onRecoveryConfigured,
  });

  final String accountJid;
  final Future<void> Function() onRecoveryDismissed;
  final Future<void> Function() onRecoveryConfigured;

  Future<void> _showEmailSetup(BuildContext context) async {
    final changed = await showRecoveryEmailSetupDialog(
      context,
      accountJid: accountJid,
    );
    if (!context.mounted || !changed) {
      return;
    }
    await onRecoveryConfigured();
    if (context.mounted) {
      context.pop();
    }
  }

  Future<void> _showTotpSetup(BuildContext context) async {
    final changed = await showRecoveryTotpSetupDialog(
      context,
      accountJid: accountJid,
    );
    if (!context.mounted || !changed) {
      return;
    }
    await onRecoveryConfigured();
    if (context.mounted) {
      context.pop();
    }
  }

  Future<void> _skip(BuildContext context) async {
    await onRecoveryDismissed();
    if (context.mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<SettingsCubit>().state.endpointConfig.isAxiImDomain ||
        !isAxiJid(accountJid)) {
      return const SizedBox.shrink();
    }
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.recoveryWelcomeTitle, style: context.textTheme.large),
        SizedBox(height: spacing.s),
        Text(
          context.l10n.recoveryWelcomeDescription,
          style: context.textTheme.muted,
        ),
        SizedBox(height: spacing.m),
        Wrap(
          spacing: spacing.s,
          runSpacing: spacing.s,
          children: [
            AxiButton.secondary(
              leading: const Icon(LucideIcons.mail),
              onPressed: () async => await _showEmailSetup(context),
              child: Text(context.l10n.recoveryAddEmailAction),
            ),
            AxiButton.secondary(
              leading: const Icon(LucideIcons.smartphone),
              onPressed: () async => await _showTotpSetup(context),
              child: Text(context.l10n.recoveryAddTotpAction),
            ),
            AxiButton.outline(
              onPressed: () async => await _skip(context),
              child: Text(context.l10n.recoverySkipForNow),
            ),
          ],
        ),
      ],
    );
  }
}

class EmailForwardingGuideContent extends StatelessWidget {
  const EmailForwardingGuideContent({
    super.key,
    required this.forwardingAddress,
    this.edgeToEdgeDivider = false,
  });

  final String forwardingAddress;
  final bool edgeToEdgeDivider;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final paragraphStyle = context.textTheme.muted;
    final subheaderStyle = context.textTheme.large;
    final topSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: spacing.m),
        Text(
          l10n.emailForwardingGuideLinkExistingEmailTitle,
          style: subheaderStyle,
        ),
        SizedBox(height: spacing.s),
        Text(l10n.emailForwardingGuideAddressHint, style: paragraphStyle),
        SizedBox(height: spacing.s),
        EmailForwardingAddressCard(forwardingAddress: forwardingAddress),
        SizedBox(height: spacing.s),
        Text(l10n.emailForwardingGuideLinksTitle, style: paragraphStyle),
        SizedBox(height: spacing.s),
        const EmailForwardingLinkRow(),
      ],
    );
    if (edgeToEdgeDivider) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.l),
            child: topSection,
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [topSection],
    );
  }
}

class EmailForwardingAddressCard extends StatelessWidget {
  const EmailForwardingAddressCard({
    super.key,
    required this.forwardingAddress,
  });

  final String forwardingAddress;

  Future<void> _copyForwardingAddress(String address) async {
    await Clipboard.setData(ClipboardData(text: address));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final l10n = context.l10n;
    final resolved = forwardingAddress.bareJid?.trim() ?? '';
    final hasAddress = resolved.isNotEmpty;
    final textStyle = hasAddress
        ? context.textTheme.small
        : context.textTheme.muted;
    final addressLabel = hasAddress
        ? resolved
        : l10n.emailForwardingGuideAddressFallback;
    final copyButton = AxiIconButton.ghost(
      iconData: LucideIcons.copy,
      tooltip: l10n.chatActionCopy,
      onPressed: hasAddress ? () => _copyForwardingAddress(resolved) : null,
      color: hasAddress ? colors.foreground : colors.mutedForeground,
      buttonSize: context.sizing.inputSuffixButtonSize,
      iconSize: context.sizing.inputSuffixIconSize,
      tapTargetSize: context.sizing.iconButtonSize,
    );
    return AxiModalSurface(
      backgroundColor: colors.muted,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.m,
        vertical: spacing.xs,
      ),
      child: Row(
        children: [
          Expanded(child: SelectableText(addressLabel, style: textStyle)),
          SizedBox(width: spacing.s),
          copyButton,
        ],
      ),
    );
  }
}

class EmailForwardingLinkRow extends StatelessWidget {
  const EmailForwardingLinkRow({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    return Wrap(
      spacing: spacing.m,
      runSpacing: spacing.s,
      children: [
        for (final provider in EmailForwardingProvider.values)
          AxiLink(text: provider.label(l10n), link: provider.helpUrl),
      ],
    );
  }
}

class EmailForwardingProviderLinkList extends StatelessWidget {
  const EmailForwardingProviderLinkList({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final sizing = context.sizing;
    final colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final provider in EmailForwardingProvider.values)
          Padding(
            padding: EdgeInsets.only(
              bottom: provider == EmailForwardingProvider.values.last
                  ? 0
                  : spacing.s,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(
                  provider.iconData,
                  size: sizing.menuItemIconSize,
                  color: colors.foreground,
                ),
                SizedBox(width: spacing.s),
                AxiLink(
                  text: provider.label(context.l10n),
                  link: provider.helpUrl,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class AccountWelcomeGate extends StatefulWidget {
  const AccountWelcomeGate({super.key, required this.child});

  final Widget child;

  @override
  State<AccountWelcomeGate> createState() => _AccountWelcomeGateState();
}

class _AccountWelcomeGateState extends State<AccountWelcomeGate> {
  final bool _debugAlwaysShowWelcome = false;
  String? _dialogShownForAccount;
  bool _dialogScheduled = false;
  Completer<void>? _foregroundActivationCompleter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleWelcomeDialog();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthenticationCubit, AuthenticationState>(
      listenWhen: (previous, current) =>
          current is AuthenticationComplete &&
          previous is! AuthenticationComplete,
      listener: (context, state) => _scheduleWelcomeDialog(),
      child: widget.child,
    );
  }

  void _scheduleWelcomeDialog() {
    if (_dialogScheduled || !mounted) {
      return;
    }
    _dialogScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dialogScheduled = false;
      if (!mounted) {
        return;
      }
      _showWelcomeDialog();
    });
  }

  Future<void> _showWelcomeDialog() async {
    if (!mounted) {
      return;
    }
    final authenticationCubit = context.read<AuthenticationCubit>();
    final authState = authenticationCubit.state;
    if (!_debugAlwaysShowWelcome && authState is! AuthenticationComplete) {
      return;
    }
    final accountJid = _resolveForwardingAddress(context.read<XmppService>());
    if (accountJid.isEmpty || _dialogShownForAccount == accountJid) {
      await authenticationCubit.releaseSignupPostLoginWorkHold();
      return;
    }
    final settingsCubit = context.read<SettingsCubit>();
    if (!_debugAlwaysShowWelcome &&
        await settingsCubit.accountWelcomeShownFor(accountJid)) {
      await authenticationCubit.releaseSignupPostLoginWorkHold();
      return;
    }
    final showEmailOnboarding = settingsCubit.state.endpointConfig.smtpEnabled;
    final showRecoveryPrompt = await _shouldShowRecoverySetup(
      settingsCubit: settingsCubit,
      authenticationCubit: authenticationCubit,
      accountJid: accountJid,
    );
    if (!mounted) {
      await authenticationCubit.releaseSignupPostLoginWorkHold();
      return;
    }
    if (!showEmailOnboarding && !showRecoveryPrompt) {
      await authenticationCubit.releaseSignupPostLoginWorkHold();
      return;
    }
    _dialogShownForAccount = accountJid;
    if (!_debugAlwaysShowWelcome) {
      await settingsCubit.markAccountWelcomeShownFor(accountJid);
    }
    if (!mounted) {
      await authenticationCubit.releaseSignupPostLoginWorkHold();
      return;
    }
    try {
      await showFadeScaleDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AccountWelcomeDialog(
          accountJid: accountJid,
          showEmailOnboarding: showEmailOnboarding,
          showRecoveryPrompt: showRecoveryPrompt,
          onForegroundActivationStarted: _handleForegroundActivationStarted,
          onForegroundActivationFinished: _handleForegroundActivationFinished,
          onForegroundActivated:
              authenticationCubit.releaseSignupPostLoginWorkHold,
          onRecoveryDismissed: () =>
              settingsCubit.dismissRecoveryWelcomeFor(accountJid),
          onRecoveryConfigured: () =>
              settingsCubit.dismissRecoveryWelcomeFor(accountJid),
        ),
      );
    } finally {
      await _foregroundActivationCompleter?.future;
      await authenticationCubit.releaseSignupPostLoginWorkHold();
    }
    if (!mounted || _debugAlwaysShowWelcome) {
      return;
    }
    if (showEmailOnboarding) {
      settingsCubit.markEmailForwardingGuideSeen();
    }
  }

  Future<bool> _shouldShowRecoverySetup({
    required SettingsCubit settingsCubit,
    required AuthenticationCubit authenticationCubit,
    required String accountJid,
  }) async {
    if (!settingsCubit.recoveryAvailableForAccount(accountJid)) {
      return false;
    }
    if (await settingsCubit.recoveryWelcomeDismissedFor(accountJid)) {
      return false;
    }
    final password = await authenticationCubit.currentEmailPasswordForAccount(
      accountJid,
    );
    if (password == null) {
      return false;
    }
    try {
      final status = await settingsCubit.recoveryStatus(
        accountJid: accountJid,
        password: password,
      );
      return !(status?.hasRecoveryMethod ?? true);
    } on provisioning.EmailProvisioningApiException {
      return false;
    }
  }

  void _handleForegroundActivationStarted() {
    _foregroundActivationCompleter ??= Completer<void>();
  }

  void _handleForegroundActivationFinished() {
    final completer = _foregroundActivationCompleter;
    if (completer == null) {
      return;
    }
    _foregroundActivationCompleter = null;
    if (!completer.isCompleted) {
      completer.complete();
    }
  }
}

String _resolveForwardingAddress(XmppService service) {
  final String? jid = service.myJid;
  final bare = jid?.bareJid?.trim();
  if (bare == null || bare.isEmpty) {
    return '';
  }
  return bare;
}

Future<void> showEmailForwardingGuideDialog(BuildContext context) async {
  final forwardingAddress = _resolveForwardingAddress(
    context.read<XmppService>(),
  );
  await showFadeScaleDialog<void>(
    context: context,
    builder: (dialogContext) => EmailForwardingGuideDialog(
      title: context.l10n.emailForwardingGuideTitle,
      forwardingAddress: forwardingAddress,
    ),
  );
  if (!context.mounted) {
    return;
  }
  context.read<SettingsCubit>().markEmailForwardingGuideSeen();
}
