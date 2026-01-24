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

enum EmailForwardingProvider { gmail, outlook }

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
  const EmailForwardingGuideActionButton({super.key});

  Future<void> _showGuideDialog(BuildContext context) async {
    final forwardingAddress = _resolveForwardingAddress(context);
    await showFadeScaleDialog<void>(
      context: context,
      builder: (dialogContext) => EmailForwardingGuideDialog(
        title: context.l10n.emailForwardingGuideTitle,
        forwardingAddress: forwardingAddress,
        notificationService: context.read<NotificationService>(),
        capability: context.read<Capability>(),
      ),
    );
    if (!context.mounted) {
      return;
    }
    context.read<SettingsCubit>().markEmailForwardingGuideSeen();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: ShadButton.ghost(
        size: ShadButtonSize.sm,
        onPressed: () async => await _showGuideDialog(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.mail, color: colors.mutedForeground),
            const SizedBox(width: _guideItemSpacing),
            Text(
              context.l10n.emailForwardingGuideTitle,
              style: context.textTheme.small.copyWith(
                color: colors.mutedForeground,
              ),
            ),
          ],
        ),
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
  });

  final String title;
  final String forwardingAddress;
  final NotificationService notificationService;
  final Capability capability;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AxiInputDialog(
      title: Text(title),
      content: EmailForwardingGuideContent(
        forwardingAddress: forwardingAddress,
        notificationService: notificationService,
        capability: capability,
      ),
      callbackText: l10n.commonDone,
      callback: () => context.pop(),
    );
  }
}

class EmailForwardingWelcomeScreen extends StatelessWidget {
  const EmailForwardingWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final forwardingAddress = _resolveForwardingAddress(context);
    final notificationService = context.read<NotificationService>();
    final capability = context.read<Capability>();
    const EdgeInsets headerPadding = EdgeInsets.fromLTRB(24, 24, 24, 12);
    const EdgeInsets contentPadding = EdgeInsets.fromLTRB(24, 0, 24, 24);
    return Scaffold(
      backgroundColor: colors.background,
      body: ColoredBox(
        color: colors.background,
        child: SafeArea(
          child: EmailForwardingWelcomeLayout(
            header: Padding(
              padding: headerPadding,
              child: Text(
                l10n.emailForwardingWelcomeTitle,
                style: context.modalHeaderTextStyle,
              ),
            ),
            content: SingleChildScrollView(
              padding: contentPadding,
              child: EmailForwardingGuideContent(
                forwardingAddress: forwardingAddress,
                notificationService: notificationService,
                capability: capability,
              ),
            ),
            footer: EmailForwardingWelcomeFooter(
              hint: l10n.emailForwardingGuideSettingsHint,
              actionLabel: l10n.emailForwardingGuideSkipLabel,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ),
    );
  }
}

class EmailForwardingWelcomeLayout extends StatelessWidget {
  const EmailForwardingWelcomeLayout({
    super.key,
    required this.header,
    required this.content,
    required this.footer,
  });

  final Widget header;
  final Widget content;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    const double maxWidth = 500;
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            minHeight: constraints.maxHeight,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const EmailForwardingSectionDivider(),
                Expanded(child: content),
                footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmailForwardingWelcomeFooter extends StatelessWidget {
  const EmailForwardingWelcomeFooter({
    super.key,
    required this.hint,
    required this.actionLabel,
    required this.onPressed,
  });

  final String hint;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const EdgeInsets padding = EdgeInsets.fromLTRB(24, 12, 24, 24);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(hint, style: context.textTheme.muted),
          ),
          ShadButton.outline(
            onPressed: onPressed,
            child: Text(actionLabel),
          ).withTapBounce(),
        ],
      ),
    );
  }
}

class EmailForwardingGuideContent extends StatelessWidget {
  const EmailForwardingGuideContent({
    super.key,
    required this.forwardingAddress,
    required this.notificationService,
    required this.capability,
  });

  final String forwardingAddress;
  final NotificationService notificationService;
  final Capability capability;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final smallStyle = context.textTheme.small;
    final subheaderStyle =
        context.textTheme.large.copyWith(fontWeight: FontWeight.w600);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.emailForwardingGuideLinkExistingEmailTitle,
          style: subheaderStyle,
        ),
        const SizedBox(height: _guideItemSpacing),
        Text(l10n.emailForwardingGuideAddressHint, style: smallStyle),
        const SizedBox(height: _guideItemSpacing),
        EmailForwardingAddressCard(forwardingAddress: forwardingAddress),
        const SizedBox(height: _guideItemSpacing),
        Text(l10n.emailForwardingGuideLinksTitle, style: smallStyle),
        const SizedBox(height: _guideItemSpacing),
        const EmailForwardingLinkRow(),
        const EmailForwardingSectionDivider(),
        Text(l10n.emailForwardingGuideNotificationsTitle,
            style: subheaderStyle),
        const SizedBox(height: _guideItemSpacing),
        NotificationRequest(
          notificationService: notificationService,
          capability: capability,
          displayMode: NotificationRequestDisplayMode.always,
        ),
      ],
    );
  }
}

class EmailForwardingSectionDivider extends StatelessWidget {
  const EmailForwardingSectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    const EdgeInsets padding = EdgeInsets.symmetric(vertical: 24);
    return const Padding(
      padding: padding,
      child: AxiListDivider(),
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
            Expanded(child: SelectableText(addressLabel, style: textStyle)),
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
          AxiLink(text: provider.label(l10n), link: provider.helpUrl),
      ],
    );
  }
}

class EmailForwardingWelcomeGate extends StatefulWidget {
  const EmailForwardingWelcomeGate({super.key, required this.child});

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
    await Navigator.of(context).push<void>(
      AxiFadePageRoute(
        duration: baseAnimationDuration,
        fullscreenDialog: true,
        builder: (routeContext) => const EmailForwardingWelcomeScreen(),
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
