// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
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
    final spacing = context.spacing;
    final sizing = context.sizing;
    return showAdaptiveBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: compact,
      dialogMaxWidth: sizing.dialogMaxWidth,
      surfacePadding: EdgeInsets.all(spacing.xxs),
      builder: (_) => EndpointConfigSheet(compact: compact),
    );
  }

  @override
  State<EndpointConfigSheet> createState() => _EndpointConfigSheetState();
}

class _EndpointConfigSheetState extends State<EndpointConfigSheet> {
  late TextEditingController _domainController;
  late TextEditingController _emailProvisioningPublicTokenController;

  EndpointConfig? _draftConfig;
  var _emailProvisioningTokenObscure = true;

  @override
  void initState() {
    super.initState();
    _domainController = TextEditingController();
    _emailProvisioningPublicTokenController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draftConfig != null) return;
    final config = context.read<SettingsCubit>().state.endpointConfig;
    _draftConfig = config;
    _domainController.text = config.domain;
    _emailProvisioningPublicTokenController.text =
        config.emailProvisioningPublicToken ?? '';
  }

  @override
  void dispose() {
    _domainController.dispose();
    _emailProvisioningPublicTokenController.dispose();
    super.dispose();
  }

  EndpointConfig _resolveConfig(EndpointConfig current) {
    final candidate = _domainController.text.trim();
    final resolvedDomain = candidate.isEmpty ? current.domain : candidate;
    final parsed = InternetAddress.tryParse(resolvedDomain);
    final fallbackDomain = InternetAddress.tryParse(current.domain) == null
        ? current.domain
        : EndpointConfig.defaultDomain;
    final domain = parsed == null ? resolvedDomain : fallbackDomain;
    final emailProvisioningPublicToken =
        _emailProvisioningPublicTokenController.text.trim();

    return current.copyWith(
      domain: domain,
      xmppHost: null,
      imapHost: null,
      smtpHost: null,
      xmppPort: EndpointConfig.defaultXmppPort,
      imapPort: EndpointConfig.defaultImapPort,
      smtpPort: EndpointConfig.defaultSmtpPort,
      apiPort: EndpointConfig.defaultApiPort,
      emailProvisioningBaseUrl: null,
      emailProvisioningPublicToken: emailProvisioningPublicToken.isEmpty
          ? null
          : emailProvisioningPublicToken,
    );
  }

  Future<void> _save() async {
    final baseConfig =
        _draftConfig ?? context.read<SettingsCubit>().state.endpointConfig;
    final updated = _resolveConfig(baseConfig);
    context.read<SettingsCubit>().updateEndpointConfig(updated);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _reset() async {
    context.read<SettingsCubit>().resetEndpointConfig();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final config =
        _draftConfig ?? context.watch<SettingsCubit>().state.endpointConfig;
    final placeholderStyle = textTheme.muted;
    final inputStyle = textTheme.p;
    final EdgeInsets sheetPadding = EdgeInsets.symmetric(
      horizontal: widget.compact ? spacing.m : spacing.l,
    );
    return AxiSheetScaffold.scroll(
      header: AxiSheetHeader(
        title: Text(context.l10n.authCustomServerTitle),
        onClose: () => Navigator.of(context).maybePop(),
        padding: sheetPadding.copyWith(top: spacing.m, bottom: spacing.s),
      ),
      bodyPadding: sheetPadding.copyWith(bottom: spacing.m),
      children: [
        AxiTextFormField(
          autocorrect: false,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          minLines: 1,
          maxLines: 1,
          placeholderAlignment: Alignment.centerLeft,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9.-]')),
          ],
          controller: _domainController,
          placeholder: Text(
            context.l10n.authEndpointDomainPlaceholder,
            style: placeholderStyle,
          ),
          placeholderStyle: placeholderStyle,
          style: inputStyle,
        ),
        SizedBox(height: spacing.s),
        _ToggleTile(
          label: context.l10n.authCustomServerSmtpLabel,
          value: config.smtpEnabled,
          onChanged: (value) => setState(
            () => _draftConfig = config.copyWith(smtpEnabled: value),
          ),
        ),
        SizedBox(height: spacing.s),
        AxiTextFormField(
          autocorrect: false,
          keyboardType: TextInputType.visiblePassword,
          obscureText: _emailProvisioningTokenObscure,
          enabled: config.smtpEnabled,
          placeholder: Text(
            context.l10n.authCustomServerEmailPublicTokenPlaceholder,
            style: placeholderStyle,
          ),
          placeholderStyle: placeholderStyle,
          controller: _emailProvisioningPublicTokenController,
          style: inputStyle,
          trailing: AxiIconButton.ghost(
            iconData: _emailProvisioningTokenObscure
                ? LucideIcons.eyeOff
                : LucideIcons.eye,
            iconSize: sizing.inputSuffixIconSize,
            buttonSize: sizing.inputSuffixButtonSize,
            tapTargetSize: sizing.inputSuffixButtonSize,
            color: colors.mutedForeground,
            backgroundColor: colors.muted,
            onPressed: config.smtpEnabled
                ? () => setState(() {
                      _emailProvisioningTokenObscure =
                          !_emailProvisioningTokenObscure;
                    })
                : null,
          ),
        ),
        SizedBox(height: spacing.m),
        Row(
          children: [
            Expanded(
              child: AxiButton.secondary(
                onPressed: _reset,
                child: Text(context.l10n.authCustomServerReset),
              ),
            ),
            SizedBox(width: spacing.s),
            Expanded(
              child: AxiButton.primary(
                onPressed: _save,
                child: Text(context.l10n.commonSave),
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.s),
      ],
    );
  }
}

class EndpointSuffix extends StatelessWidget {
  const EndpointSuffix({super.key, required this.server});

  final String server;

  @override
  Widget build(BuildContext context) {
    return AxiButton.ghost(
      size: AxiButtonSize.sm,
      semanticLabel: context.l10n.authCustomServerOpenSettings,
      onPressed: () => EndpointConfigSheet.show(context),
      child: Text(
        '@$server',
        style: context.textTheme.small.copyWith(
          color: context.colorScheme.foreground,
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
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AxiCheckboxFormField(
      key: ValueKey('$label-$value'),
      initialValue: value,
      inputLabel: Text(label),
      onChanged: onChanged,
    );
  }
}
