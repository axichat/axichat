// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/email/demo/bloc/email_demo_cubit.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class EmailDemoScreen extends StatefulWidget {
  const EmailDemoScreen({super.key});

  @override
  State<EmailDemoScreen> createState() => _EmailDemoScreenState();
}

class _EmailDemoScreenState extends State<EmailDemoScreen> {
  final _messageController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_messageController.text.isEmpty) {
      _messageController.text = context.l10n.emailDemoDefaultMessage;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _statusLabel(BuildContext context, EmailDemoState state) {
    const String empty = '';
    switch (state.status) {
      case EmailDemoStatus.idle:
        return context.l10n.emailDemoStatusIdle;
      case EmailDemoStatus.loginToProvision:
        return context.l10n.emailDemoStatusLoginToProvision;
      case EmailDemoStatus.notProvisioned:
        return context.l10n.emailDemoStatusNotProvisioned;
      case EmailDemoStatus.ready:
        return context.l10n.emailDemoStatusReady;
      case EmailDemoStatus.provisioning:
        return context.l10n.emailDemoStatusProvisioning;
      case EmailDemoStatus.provisioned:
        final String address = state.account?.address ?? empty;
        return context.l10n.emailDemoStatusProvisioned(address);
      case EmailDemoStatus.provisionFailed:
        return context.l10n.emailDemoStatusProvisionFailed(
          _provisionFailureLabel(context, state),
        );
      case EmailDemoStatus.provisionFirst:
        return context.l10n.emailDemoStatusProvisionFirst;
      case EmailDemoStatus.sending:
        return context.l10n.emailDemoStatusSending;
      case EmailDemoStatus.sent:
        return context.l10n.emailDemoStatusSent(state.detail ?? empty);
      case EmailDemoStatus.sendFailed:
        return context.l10n.emailDemoStatusSendFailed(state.detail ?? empty);
    }
  }

  String _provisionFailureLabel(BuildContext context, EmailDemoState state) {
    const String empty = '';
    switch (state.failure) {
      case EmailDemoFailure.missingProfile:
        return context.l10n.emailDemoErrorMissingProfile;
      case EmailDemoFailure.missingPrefix:
        return context.l10n.emailDemoErrorMissingPrefix;
      case EmailDemoFailure.missingPassphrase:
        return context.l10n.emailDemoErrorMissingPassphrase;
      case EmailDemoFailure.unexpected:
      case null:
        return state.detail ?? empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final endpointConfig = context.read<SettingsCubit>().state.endpointConfig;
    if (!endpointConfig.smtpEnabled && !kEnableDemoChats) {
      return const SizedBox.shrink();
    }
    final spacing = context.spacing;
    final sizing = context.sizing;
    return BlocProvider(
      create: (context) => EmailDemoCubit(
        emailService: context.read<EmailService>(),
        credentialStore: context.read<CredentialStore>(),
      )..loadAccount(),
      child: Builder(
        builder: (context) {
          return BlocBuilder<EmailDemoCubit, EmailDemoState>(
            builder: (context, state) {
              const String empty = '';
              final bool isBusy =
                  state.status == EmailDemoStatus.provisioning ||
                  state.status == EmailDemoStatus.sending;
              final String statusLabel = _statusLabel(context, state);
              final String accountLabel = state.account?.address ?? empty;
              return Scaffold(
                backgroundColor: context.colorScheme.background,
                appBar: AppBar(
                  backgroundColor: context.colorScheme.background,
                  scrolledUnderElevation: 0,
                  forceMaterialTransparency: true,
                  shape: Border(bottom: context.borderSide),
                  leadingWidth: sizing.iconButtonTapTarget + spacing.m,
                  leading: Navigator.canPop(context)
                      ? Padding(
                          padding: EdgeInsets.only(left: spacing.s),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: sizing.iconButtonSize,
                              height: sizing.iconButtonSize,
                              child: AxiIconButton.ghost(
                                iconData: LucideIcons.arrowLeft,
                                tooltip: context.l10n.commonBack,
                                onPressed: () => Navigator.maybePop(context),
                              ),
                            ),
                          ),
                        )
                      : null,
                  title: Text(context.l10n.emailDemoTitle),
                ),
                body: Padding(
                  padding: EdgeInsets.all(spacing.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.emailDemoStatusLabel(statusLabel)),
                      SizedBox(height: spacing.s),
                      Text(
                        context.l10n.emailDemoAccountLabel(
                          accountLabel.isEmpty
                              ? context.l10n.emailDemoStatusNotProvisioned
                              : accountLabel,
                        ),
                      ),
                      SizedBox(height: spacing.m),
                      AxiTextField(
                        controller: _messageController,
                        enabled: !isBusy,
                        decoration: InputDecoration(
                          labelText: context.l10n.emailDemoMessageLabel,
                        ),
                      ),
                      SizedBox(height: spacing.l),
                      Wrap(
                        spacing: spacing.m,
                        runSpacing: spacing.m,
                        children: [
                          AxiButton.primary(
                            onPressed: isBusy
                                ? null
                                : () => context
                                      .read<EmailDemoCubit>()
                                      .provision(),
                            loading:
                                state.status == EmailDemoStatus.provisioning,
                            child: Text(context.l10n.emailDemoProvisionButton),
                          ),
                          AxiButton.secondary(
                            onPressed: isBusy
                                ? null
                                : () => context
                                      .read<EmailDemoCubit>()
                                      .sendDemoMessage(
                                        account: state.account,
                                        demoTarget: kEnableDemoChats
                                            ? FanOutTarget.address(
                                                address:
                                                    state.account?.address ??
                                                    kDemoSelfJid,
                                                displayName: context
                                                    .l10n
                                                    .emailDemoDisplayNameSelf,
                                                shareSignatureEnabled: false,
                                              )
                                            : null,
                                        body: _messageController.text,
                                        displayName: context
                                            .l10n
                                            .emailDemoDisplayNameSelf,
                                      ),
                            loading: state.status == EmailDemoStatus.sending,
                            child: Text(context.l10n.emailDemoSendButton),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
