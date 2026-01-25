// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/endpoint_config_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class EndpointConfigSheet extends StatefulWidget {
  const EndpointConfigSheet({super.key, required this.compact});

  final bool compact;

  static Future<void> show(BuildContext context) {
    final commandSurface = resolveCommandSurface(context);
    final bool compact = commandSurface == CommandSurface.sheet;
    return showAdaptiveBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: compact,
      dialogMaxWidth: compact ? 560 : 720,
      surfacePadding: EdgeInsets.zero,
      builder: (_) => EndpointConfigSheet(compact: compact),
    );
  }

  @override
  State<EndpointConfigSheet> createState() => _EndpointConfigSheetState();
}

class _EndpointConfigSheetState extends State<EndpointConfigSheet> {
  late TextEditingController _domainController;
  late TextEditingController _xmppHostController;
  late TextEditingController _imapHostController;
  late TextEditingController _smtpHostController;
  late TextEditingController _xmppPortController;
  late TextEditingController _imapPortController;
  late TextEditingController _smtpPortController;
  late TextEditingController _apiPortController;
  late TextEditingController _emailProvisioningBaseUrlController;
  late TextEditingController _emailProvisioningPublicTokenController;

  late bool _enableXmpp;
  late bool _enableSmtp;
  late bool _useDns;
  late bool _useSrv;
  late bool _requireDnssec;
  var _emailProvisioningTokenObscure = true;
  bool _dependenciesInitialized = false;

  @override
  void initState() {
    super.initState();
    _domainController = TextEditingController();
    _xmppHostController = TextEditingController();
    _imapHostController = TextEditingController();
    _smtpHostController = TextEditingController();
    _xmppPortController = TextEditingController();
    _imapPortController = TextEditingController();
    _smtpPortController = TextEditingController();
    _apiPortController = TextEditingController();
    _emailProvisioningBaseUrlController = TextEditingController();
    _emailProvisioningPublicTokenController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesInitialized) return;
    final config = context.read<EndpointConfigCubit>().state;
    _enableXmpp = config.enableXmpp;
    _enableSmtp = config.enableSmtp;
    _useDns = config.useDns;
    _useSrv = config.useSrv;
    _requireDnssec = config.requireDnssec;
    _domainController.text = config.domain;
    _xmppHostController.text = config.xmppHost ?? '';
    _imapHostController.text = config.imapHost ?? '';
    _smtpHostController.text = config.smtpHost ?? '';
    _xmppPortController.text = config.xmppPort.toString();
    _imapPortController.text = config.imapPort.toString();
    _smtpPortController.text = config.smtpPort.toString();
    _apiPortController.text = config.apiPort.toString();
    _emailProvisioningBaseUrlController.text =
        config.emailProvisioningBaseUrl ?? '';
    _emailProvisioningPublicTokenController.text =
        config.emailProvisioningPublicToken ?? '';
    _dependenciesInitialized = true;
  }

  @override
  void dispose() {
    _domainController.dispose();
    _xmppHostController.dispose();
    _imapHostController.dispose();
    _smtpHostController.dispose();
    _xmppPortController.dispose();
    _imapPortController.dispose();
    _smtpPortController.dispose();
    _apiPortController.dispose();
    _emailProvisioningBaseUrlController.dispose();
    _emailProvisioningPublicTokenController.dispose();
    super.dispose();
  }

  int _parsePort(String value, int fallback) =>
      int.tryParse(value.trim()) ?? fallback;

  EndpointConfig _resolveConfig(EndpointConfig current) {
    final domain = _domainController.text.trim().isEmpty
        ? current.domain
        : _domainController.text.trim();
    final xmppHost = _xmppHostController.text.trim();
    final imapHost = _imapHostController.text.trim();
    final smtpHost = _smtpHostController.text.trim();
    final xmppPort = _parsePort(
      _xmppPortController.text,
      EndpointConfig.defaultXmppPort,
    );
    final imapPort = _parsePort(
      _imapPortController.text,
      EndpointConfig.defaultImapPort,
    );
    final smtpPort = _parsePort(
      _smtpPortController.text,
      EndpointConfig.defaultSmtpPort,
    );
    final apiPort = _parsePort(
      _apiPortController.text,
      EndpointConfig.defaultApiPort,
    );
    final emailProvisioningBaseUrl =
        _emailProvisioningBaseUrlController.text.trim();
    final emailProvisioningPublicToken =
        _emailProvisioningPublicTokenController.text.trim();

    return current.copyWith(
      domain: domain,
      enableXmpp: _enableXmpp,
      enableSmtp: _enableSmtp,
      useDns: _useDns,
      useSrv: _useSrv,
      requireDnssec: _requireDnssec,
      xmppHost: xmppHost.isEmpty ? null : xmppHost,
      imapHost: imapHost.isEmpty ? null : imapHost,
      smtpHost: smtpHost.isEmpty ? null : smtpHost,
      xmppPort: xmppPort,
      imapPort: imapPort,
      smtpPort: smtpPort,
      apiPort: apiPort,
      emailProvisioningBaseUrl:
          emailProvisioningBaseUrl.isEmpty ? null : emailProvisioningBaseUrl,
      emailProvisioningPublicToken: emailProvisioningPublicToken.isEmpty
          ? null
          : emailProvisioningPublicToken,
    );
  }

  Future<void> _save() async {
    final updated = _resolveConfig(
      context.read<EndpointConfigCubit>().state,
    );
    await context.read<EndpointConfigCubit>().updateConfig(updated);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _reset() async {
    await context.read<EndpointConfigCubit>().reset();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final spacing = context.spacing;
    final placeholderStyle = textTheme.muted;
    final inputStyle = textTheme.p;
    final EdgeInsets sheetPadding = EdgeInsets.symmetric(
      horizontal: widget.compact ? spacing.m : spacing.l,
    );
    return AxiSheetScaffold.scroll(
      header: AxiSheetHeader(
        title: Text(context.l10n.authCustomServerTitle),
        subtitle: Text(context.l10n.authCustomServerDescription),
        onClose: () => Navigator.of(context).maybePop(),
        padding: sheetPadding.copyWith(top: spacing.m, bottom: spacing.s),
      ),
      bodyPadding: sheetPadding.copyWith(bottom: spacing.m),
      children: [
        AxiTextFormField(
          autocorrect: false,
          keyboardType: TextInputType.url,
          controller: _domainController,
          placeholder: Text(
            context.l10n.authCustomServerDomainOrIp,
            style: placeholderStyle,
          ),
          placeholderStyle: placeholderStyle,
          style: inputStyle,
        ),
        SizedBox(height: spacing.s),
        Row(
          children: [
            Expanded(
              child: _ToggleTile(
                label: context.l10n.authCustomServerXmppLabel,
                value: _enableXmpp,
                onChanged: (value) =>
                    setState(() => _enableXmpp = value ?? _enableXmpp),
              ),
            ),
            SizedBox(width: spacing.s),
            Expanded(
              child: _ToggleTile(
                label: context.l10n.authCustomServerSmtpLabel,
                value: _enableSmtp,
                onChanged: (value) =>
                    setState(() => _enableSmtp = value ?? _enableSmtp),
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.s),
        Row(
          children: [
            Expanded(
              child: _ToggleTile(
                label: context.l10n.authCustomServerUseDns,
                value: _useDns,
                onChanged: (value) => setState(() {
                  _useDns = value ?? _useDns;
                  if (!_useDns) {
                    _useSrv = false;
                    _requireDnssec = false;
                  }
                }),
              ),
            ),
            SizedBox(width: spacing.s),
            Expanded(
              child: _ToggleTile(
                label: context.l10n.authCustomServerUseSrv,
                value: _useSrv,
                enabled: _useDns,
                onChanged: (value) =>
                    setState(() => _useSrv = value ?? _useSrv),
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.s),
        _ToggleTile(
          label: context.l10n.authCustomServerRequireDnssec,
          value: _requireDnssec,
          enabled: _useDns,
          onChanged: (value) =>
              setState(() => _requireDnssec = value ?? _requireDnssec),
        ),
        SizedBox(height: spacing.s),
        Row(
          children: [
            Expanded(
              child: AxiTextFormField(
                autocorrect: false,
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9._:-]')),
                ],
                placeholder: Text(
                  context.l10n.authCustomServerXmppHostPlaceholder,
                  style: placeholderStyle,
                ),
                placeholderStyle: placeholderStyle,
                controller: _xmppHostController,
                style: inputStyle,
              ),
            ),
            SizedBox(width: spacing.s),
            SizedBox(
              width: spacing.xxl,
              child: AxiTextFormField(
                autocorrect: false,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                placeholder: Text(
                  context.l10n.authCustomServerPortPlaceholder,
                  style: placeholderStyle,
                ),
                placeholderStyle: placeholderStyle,
                controller: _xmppPortController,
                style: inputStyle,
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.s),
        Row(
          children: [
            Expanded(
              child: AxiTextFormField(
                autocorrect: false,
                keyboardType: TextInputType.url,
                placeholder: Text(
                  context.l10n.authCustomServerImapHostPlaceholder,
                  style: placeholderStyle,
                ),
                placeholderStyle: placeholderStyle,
                controller: _imapHostController,
                style: inputStyle,
              ),
            ),
            SizedBox(width: spacing.s),
            SizedBox(
              width: spacing.xxl,
              child: AxiTextFormField(
                autocorrect: false,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                placeholder: Text(
                  context.l10n.authCustomServerPortPlaceholder,
                  style: placeholderStyle,
                ),
                placeholderStyle: placeholderStyle,
                controller: _imapPortController,
                style: inputStyle,
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.s),
        Row(
          children: [
            Expanded(
              child: AxiTextFormField(
                autocorrect: false,
                keyboardType: TextInputType.url,
                placeholder: Text(
                  context.l10n.authCustomServerSmtpHostPlaceholder,
                  style: placeholderStyle,
                ),
                placeholderStyle: placeholderStyle,
                controller: _smtpHostController,
                style: inputStyle,
              ),
            ),
            SizedBox(width: spacing.s),
            SizedBox(
              width: spacing.xxl,
              child: AxiTextFormField(
                autocorrect: false,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                placeholder: Text(
                  context.l10n.authCustomServerPortPlaceholder,
                  style: placeholderStyle,
                ),
                placeholderStyle: placeholderStyle,
                controller: _smtpPortController,
                style: inputStyle,
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.s),
        SizedBox(
          width: spacing.xxl,
          child: AxiTextFormField(
            autocorrect: false,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            placeholder: Text(
              context.l10n.authCustomServerApiPortPlaceholder,
              style: placeholderStyle,
            ),
            placeholderStyle: placeholderStyle,
            controller: _apiPortController,
            style: inputStyle,
          ),
        ),
        SizedBox(height: spacing.s),
        AxiTextFormField(
          autocorrect: false,
          keyboardType: TextInputType.url,
          placeholder: Text(
            context.l10n.authCustomServerEmailProvisioningUrlPlaceholder,
            style: placeholderStyle,
          ),
          placeholderStyle: placeholderStyle,
          controller: _emailProvisioningBaseUrlController,
          style: inputStyle,
        ),
        SizedBox(height: spacing.s),
        AxiTextFormField(
          autocorrect: false,
          keyboardType: TextInputType.visiblePassword,
          obscureText: _emailProvisioningTokenObscure,
          placeholder: Text(
            context.l10n.authCustomServerEmailPublicTokenPlaceholder,
            style: placeholderStyle,
          ),
          placeholderStyle: placeholderStyle,
          controller: _emailProvisioningPublicTokenController,
          style: inputStyle,
          trailing: ShadIconButton(
            backgroundColor: colors.muted,
            foregroundColor: colors.mutedForeground,
            width: spacing.m,
            height: spacing.m,
            padding: EdgeInsets.zero,
            decoration: const ShadDecoration(
              secondaryBorder: ShadBorder.none,
              secondaryFocusedBorder: ShadBorder.none,
            ),
            icon: Icon(
              _emailProvisioningTokenObscure
                  ? LucideIcons.eyeOff
                  : LucideIcons.eye,
              size: spacing.m,
            ),
            onPressed: () => setState(() {
              _emailProvisioningTokenObscure = !_emailProvisioningTokenObscure;
            }),
          ).withTapBounce(),
        ),
        SizedBox(height: spacing.m),
        Row(
          children: [
            Expanded(
              child: ShadButton.secondary(
                onPressed: _reset,
                child: Text(context.l10n.authCustomServerReset),
              ).withTapBounce(),
            ),
            SizedBox(width: spacing.s),
            Expanded(
              child: ShadButton(
                onPressed: _save,
                child: Text(context.l10n.commonSave),
              ).withTapBounce(),
            ),
          ],
        ),
        SizedBox(height: spacing.s),
        Text(
          context.l10n.authCustomServerAdvancedHint,
          style: textTheme.muted,
        ),
      ],
    );
  }
}

class EndpointSuffix extends StatelessWidget {
  const EndpointSuffix({super.key, required this.server});

  final String server;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.authCustomServerOpenSettings,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => EndpointConfigSheet.show(context),
        child: Text(
          '@$server',
          style: context.textTheme.p,
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final spacing = context.spacing;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: context.radius,
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.m,
          vertical: spacing.s,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: textTheme.p),
            ShadSwitch(value: value, onChanged: enabled ? onChanged : null),
          ],
        ),
      ),
    );
  }
}
