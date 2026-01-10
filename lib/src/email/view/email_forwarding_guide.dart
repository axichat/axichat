// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/jid_transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/notifications/view/notification_request.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _guideSectionSpacing = 12.0;
const double _guideItemSpacing = 8.0;
const double _guideLinkSpacing = 12.0;
const double _guideLinkRunSpacing = 8.0;
const double _guideAddressPadding = 12.0;
const bool _forceShowEmailForwardingWelcome = false;
const String _emptyForwardingAddress = '';

const String _gmailForwardingUrl =
    'https://support.google.com/mail/answer/10957';
const String _outlookForwardingUrl =
    'https://support.microsoft.com/en-us/office/turn-on-automatic-forwarding-in-outlook-7f2670a1-7fff-4475-8a3c-5822d63b0c8e';

enum EmailForwardingProvider {
  gmail,
  outlook,
}

extension EmailForwardingProviderMetadata on EmailForwardingProvider {
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
}

class EmailForwardingGuideTile extends StatelessWidget {
  const EmailForwardingGuideTile({super.key});

  Future<void> _showGuideDialog(BuildContext context) async {
    final l10n = context.l10n;
    final forwardingAddress = _resolveForwardingAddress(context);
    await showFadeScaleDialog<void>(
      context: context,
      builder: (dialogContext) => EmailForwardingGuideDialog(
        title: l10n.emailForwardingGuideTitle,
        forwardingAddress: forwardingAddress,
        notificationService: context.read<NotificationService>(),
        capability: context.read<Capability>(),
        showSettingsHint: false,
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

class EmailForwardingGuideDialog extends StatelessWidget {
  const EmailForwardingGuideDialog({
    super.key,
    required this.title,
    required this.forwardingAddress,
    required this.notificationService,
    required this.capability,
    required this.showSettingsHint,
  });

  final String title;
  final String forwardingAddress;
  final NotificationService notificationService;
  final Capability capability;
  final bool showSettingsHint;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AxiInputDialog(
      title: Text(title),
      content: EmailForwardingGuideContent(
        forwardingAddress: forwardingAddress,
        notificationService: notificationService,
        capability: capability,
        showSettingsHint: showSettingsHint,
      ),
      callbackText: l10n.commonDone,
      callback: () => context.pop(),
    );
  }
}

class EmailForwardingGuideContent extends StatelessWidget {
  const EmailForwardingGuideContent({
    super.key,
    required this.forwardingAddress,
    required this.notificationService,
    required this.capability,
    required this.showSettingsHint,
  });

  final String forwardingAddress;
  final NotificationService notificationService;
  final Capability capability;
  final bool showSettingsHint;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mutedStyle = context.textTheme.muted;
    final smallStyle = context.textTheme.small;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.emailForwardingGuideIntro,
          style: mutedStyle,
        ),
        const SizedBox(height: _guideSectionSpacing),
        Text(
          l10n.emailForwardingGuideAddressHint,
          style: smallStyle,
        ),
        const SizedBox(height: _guideItemSpacing),
        EmailForwardingAddressCard(
          forwardingAddress: forwardingAddress,
        ),
        const SizedBox(height: _guideSectionSpacing),
        Text(
          l10n.emailForwardingGuideLinksTitle,
          style: smallStyle,
        ),
        const SizedBox(height: _guideItemSpacing),
        Text(
          l10n.emailForwardingGuideLinksSubtitle,
          style: mutedStyle,
        ),
        const SizedBox(height: _guideItemSpacing),
        const EmailForwardingLinkRow(),
        if (capability.canForegroundService) ...[
          const SizedBox(height: _guideSectionSpacing),
          NotificationRequest(
            notificationService: notificationService,
            capability: capability,
          ),
        ],
        if (showSettingsHint) ...[
          const SizedBox(height: _guideSectionSpacing),
          Text(
            l10n.emailForwardingGuideSettingsHint,
            style: mutedStyle,
          ),
        ],
      ],
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
    final radius = context.radius;
    final l10n = context.l10n;
    final resolved = forwardingAddress.bareJid.trim();
    final hasAddress = resolved.isNotEmpty;
    final textStyle =
        hasAddress ? context.textTheme.small : context.textTheme.muted;
    final addressLabel =
        hasAddress ? resolved : l10n.emailForwardingGuideAddressFallback;
    final copyButton = AxiIconButton.ghost(
      iconData: LucideIcons.copy,
      tooltip: l10n.chatActionCopy,
      onPressed: hasAddress ? () => _copyForwardingAddress(resolved) : null,
      color: hasAddress ? colors.foreground : colors.mutedForeground,
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.muted,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colors.border),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_guideAddressPadding),
        child: Row(
          children: [
            Expanded(
              child: SelectableText(
                addressLabel,
                style: textStyle,
              ),
            ),
            const SizedBox(width: _guideItemSpacing),
            copyButton,
          ],
        ),
      ),
    );
  }
}

class EmailForwardingLinkRow extends StatelessWidget {
  const EmailForwardingLinkRow({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: _guideLinkSpacing,
      runSpacing: _guideLinkRunSpacing,
      children: [
        for (final provider in EmailForwardingProvider.values)
          AxiLink(
            text: provider.label(l10n),
            link: provider.helpUrl,
          ),
      ],
    );
  }
}

class EmailForwardingWelcomeGate extends StatefulWidget {
  const EmailForwardingWelcomeGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<EmailForwardingWelcomeGate> createState() =>
      _EmailForwardingWelcomeGateState();
}

class _EmailForwardingWelcomeGateState
    extends State<EmailForwardingWelcomeGate> {
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _showWelcomeDialog();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthenticationCubit, AuthenticationState>(
      listenWhen: (previous, current) =>
          current is AuthenticationCompleteFromSignup &&
          previous is! AuthenticationCompleteFromSignup,
      listener: (context, state) => _showWelcomeDialog(),
      child: widget.child,
    );
  }

  Future<void> _showWelcomeDialog() async {
    if (_dialogShown || !mounted) {
      return;
    }
    final authState = context.read<AuthenticationCubit>().state;
    if (!_forceShowEmailForwardingWelcome) {
      if (authState is! AuthenticationCompleteFromSignup) {
        return;
      }
      if (context.read<SettingsCubit>().state.emailForwardingGuideSeen) {
        return;
      }
    } else if (authState is! AuthenticationComplete) {
      return;
    }
    _dialogShown = true;
    final forwardingAddress = _resolveForwardingAddress(context);
    await showFadeScaleDialog<void>(
      context: context,
      builder: (dialogContext) => EmailForwardingGuideDialog(
        title: dialogContext.l10n.emailForwardingWelcomeTitle,
        forwardingAddress: forwardingAddress,
        notificationService: context.read<NotificationService>(),
        capability: context.read<Capability>(),
        showSettingsHint: true,
      ),
    );
    if (!mounted) {
      return;
    }
    context.read<SettingsCubit>().markEmailForwardingGuideSeen();
  }
}

String _resolveForwardingAddress(BuildContext context) {
  final String? jid = context.read<XmppService>().myJid;
  return (jid ?? _emptyForwardingAddress).bareJid.trim();
}
