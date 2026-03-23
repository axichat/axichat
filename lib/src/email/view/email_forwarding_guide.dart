// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/notifications/view/notification_request.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
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

class EmailForwardingWelcomeDialog extends StatelessWidget {
  const EmailForwardingWelcomeDialog({super.key});

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
              onClose: () => context.pop(),
            ),
            footer: Padding(
              padding: EdgeInsets.fromLTRB(spacing.m, 0, spacing.m, spacing.m),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.emailForwardingGuideSettingsHint,
                    style: context.textTheme.muted,
                  ),
                  SizedBox(height: spacing.s),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AxiButton.outline(
                      onPressed: () => context.pop(),
                      child: Text(l10n.emailForwardingGuideSkipLabel),
                    ),
                  ),
                ],
              ),
            ),
            children: const [EmailForwardingWelcomeContent()],
          ),
        ),
      ),
    );
  }
}

class EmailForwardingWelcomeContent extends StatelessWidget {
  const EmailForwardingWelcomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    final capability = context.watch<Capability>();
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
        if (capability.canForegroundService) ...[
          SizedBox(height: spacing.xl),
          Text(
            l10n.emailForwardingGuideNotificationsTitle,
            style: context.textTheme.large,
          ),
          SizedBox(height: spacing.s),
          const NotificationRequest(),
        ],
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
    final capability = context.watch<Capability>();
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
    final Widget? notificationSection = capability.canForegroundService
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: spacing.m),
              Text(
                l10n.emailForwardingGuideNotificationsTitle,
                style: subheaderStyle,
              ),
              SizedBox(height: spacing.s),
              const NotificationRequest(),
            ],
          )
        : null;
    if (edgeToEdgeDivider) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.l),
            child: topSection,
          ),
          if (notificationSection != null) ...[
            SizedBox(height: spacing.xl),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.l),
              child: notificationSection,
            ),
          ],
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        topSection,
        if (notificationSection != null) ...[
          SizedBox(height: spacing.xl),
          notificationSection,
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

class EmailForwardingWelcomeGate extends StatefulWidget {
  const EmailForwardingWelcomeGate({super.key, required this.child});

  final Widget child;

  @override
  State<EmailForwardingWelcomeGate> createState() =>
      _EmailForwardingWelcomeGateState();
}

class _EmailForwardingWelcomeGateState
    extends State<EmailForwardingWelcomeGate> {
  final bool _debugAlwaysShowWelcome = false;
  bool _dialogShown = false;
  bool _dialogScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleWelcomeDialog();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthenticationCubit, AuthenticationState>(
      listenWhen: (previous, current) =>
          current is AuthenticationCompleteFromSignup &&
          previous is! AuthenticationCompleteFromSignup,
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
    if (_dialogShown || !mounted) {
      return;
    }
    if (!_debugAlwaysShowWelcome &&
        !context.read<SettingsCubit>().state.endpointConfig.smtpEnabled) {
      return;
    }
    final authState = context.read<AuthenticationCubit>().state;
    if (!_debugAlwaysShowWelcome &&
        authState is! AuthenticationCompleteFromSignup) {
      return;
    }
    if (!_debugAlwaysShowWelcome &&
        context.read<SettingsCubit>().state.emailForwardingGuideSeen) {
      return;
    }
    _dialogShown = true;
    await showFadeScaleDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const EmailForwardingWelcomeDialog(),
    );
    if (!mounted) {
      return;
    }
    if (!_debugAlwaysShowWelcome) {
      context.read<SettingsCubit>().markEmailForwardingGuideSeen();
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
