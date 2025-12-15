import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/endpoint_config.dart';
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
      backgroundColor: Colors.transparent,
      dialogMaxWidth: compact ? 560 : 720,
      builder: (_) => EndpointConfigSheet(compact: compact),
    );
  }

  @override
  State<EndpointConfigSheet> createState() => _EndpointConfigSheetState();
}

class _EndpointConfigSheetState extends State<EndpointConfigSheet> {
  late TextEditingController _domainController;
  late TextEditingController _xmppHostController;
  late TextEditingController _smtpHostController;
  late TextEditingController _xmppPortController;
  late TextEditingController _smtpPortController;
  late TextEditingController _apiPortController;

  late bool _enableXmpp;
  late bool _enableSmtp;
  late bool _useDns;
  late bool _useSrv;
  late bool _requireDnssec;
  bool _dependenciesInitialized = false;

  @override
  void initState() {
    super.initState();
    _domainController = TextEditingController();
    _xmppHostController = TextEditingController();
    _smtpHostController = TextEditingController();
    _xmppPortController = TextEditingController();
    _smtpPortController = TextEditingController();
    _apiPortController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesInitialized) return;
    final config = context.read<AuthenticationCubit>().endpointConfig;
    _enableXmpp = config.enableXmpp;
    _enableSmtp = config.enableSmtp;
    _useDns = config.useDns;
    _useSrv = config.useSrv;
    _requireDnssec = config.requireDnssec;
    _domainController.text = config.domain;
    _xmppHostController.text = config.xmppHost ?? '';
    _smtpHostController.text = config.smtpHost ?? '';
    _xmppPortController.text = config.xmppPort.toString();
    _smtpPortController.text = config.smtpPort.toString();
    _apiPortController.text = config.apiPort.toString();
    _dependenciesInitialized = true;
  }

  @override
  void dispose() {
    _domainController.dispose();
    _xmppHostController.dispose();
    _smtpHostController.dispose();
    _xmppPortController.dispose();
    _smtpPortController.dispose();
    _apiPortController.dispose();
    super.dispose();
  }

  int _parsePort(String value, int fallback) =>
      int.tryParse(value.trim()) ?? fallback;

  EndpointConfig _buildConfig(EndpointConfig current) {
    final domain = _domainController.text.trim().isEmpty
        ? current.domain
        : _domainController.text.trim();
    final xmppHost = _xmppHostController.text.trim();
    final smtpHost = _smtpHostController.text.trim();
    final xmppPort =
        _parsePort(_xmppPortController.text, EndpointConfig.defaultXmppPort);
    final smtpPort =
        _parsePort(_smtpPortController.text, EndpointConfig.defaultSmtpPort);
    final apiPort =
        _parsePort(_apiPortController.text, EndpointConfig.defaultApiPort);

    return current.copyWith(
      domain: domain,
      enableXmpp: _enableXmpp,
      enableSmtp: _enableSmtp,
      useDns: _useDns,
      useSrv: _useSrv,
      requireDnssec: _requireDnssec,
      xmppHost: xmppHost.isEmpty ? null : xmppHost,
      smtpHost: smtpHost.isEmpty ? null : smtpHost,
      xmppPort: xmppPort,
      smtpPort: smtpPort,
      apiPort: apiPort,
    );
  }

  Future<void> _save() async {
    final updated = _buildConfig(
      context.read<AuthenticationCubit>().endpointConfig,
    );
    await context.read<AuthenticationCubit>().updateEndpointConfig(updated);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _reset() async {
    await context.read<AuthenticationCubit>().resetEndpointConfig();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final l10n = context.l10n;
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final titleStyle = textTheme.h4.copyWith(color: colors.foreground);
    final placeholderStyle =
        textTheme.muted.copyWith(color: colors.mutedForeground);
    final inputStyle = TextStyle(color: colors.foreground);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.authCustomServerTitle,
          style: titleStyle,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.authCustomServerDescription,
          style: textTheme.muted.copyWith(color: colors.mutedForeground),
        ),
        const SizedBox(height: 16),
        AxiTextFormField(
          autocorrect: false,
          keyboardType: TextInputType.url,
          controller: _domainController,
          placeholder:
              Text(l10n.authCustomServerDomainOrIp, style: placeholderStyle),
          placeholderStyle: placeholderStyle,
          style: inputStyle,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ToggleTile(
                label: l10n.authCustomServerXmppLabel,
                value: _enableXmpp,
                onChanged: (value) =>
                    setState(() => _enableXmpp = value ?? _enableXmpp),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ToggleTile(
                label: l10n.authCustomServerSmtpLabel,
                value: _enableSmtp,
                onChanged: (value) =>
                    setState(() => _enableSmtp = value ?? _enableSmtp),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ToggleTile(
                label: l10n.authCustomServerUseDns,
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
            const SizedBox(width: 12),
            Expanded(
              child: _ToggleTile(
                label: l10n.authCustomServerUseSrv,
                value: _useSrv,
                enabled: _useDns,
                onChanged: (value) =>
                    setState(() => _useSrv = value ?? _useSrv),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ToggleTile(
          label: l10n.authCustomServerRequireDnssec,
          value: _requireDnssec,
          enabled: _useDns,
          onChanged: (value) =>
              setState(() => _requireDnssec = value ?? _requireDnssec),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AxiTextFormField(
                autocorrect: false,
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[A-Za-z0-9._:-]'),
                  ),
                ],
                placeholder: Text(
                  l10n.authCustomServerXmppHostPlaceholder,
                  style: placeholderStyle,
                ),
                placeholderStyle: placeholderStyle,
                controller: _xmppHostController,
                style: inputStyle,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 96,
              child: AxiTextFormField(
                autocorrect: false,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                placeholder: Text(
                  l10n.authCustomServerPortPlaceholder,
                  style: placeholderStyle,
                ),
                placeholderStyle: placeholderStyle,
                controller: _xmppPortController,
                style: inputStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AxiTextFormField(
                autocorrect: false,
                keyboardType: TextInputType.url,
                placeholder: Text(
                  l10n.authCustomServerSmtpHostPlaceholder,
                  style: placeholderStyle,
                ),
                placeholderStyle: placeholderStyle,
                controller: _smtpHostController,
                style: inputStyle,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 96,
              child: AxiTextFormField(
                autocorrect: false,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                placeholder: Text(
                  l10n.authCustomServerPortPlaceholder,
                  style: placeholderStyle,
                ),
                placeholderStyle: placeholderStyle,
                controller: _smtpPortController,
                style: inputStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 120,
          child: AxiTextFormField(
            autocorrect: false,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            placeholder: Text(
              l10n.authCustomServerApiPortPlaceholder,
              style: placeholderStyle,
            ),
            placeholderStyle: placeholderStyle,
            controller: _apiPortController,
            style: inputStyle,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ShadButton.secondary(
                onPressed: _reset,
                child: Text(l10n.authCustomServerReset),
              ).withTapBounce(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ShadButton(
                onPressed: _save,
                child: Text(l10n.commonSave),
              ).withTapBounce(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.authCustomServerAdvancedHint,
          style: textTheme.muted.copyWith(color: colors.mutedForeground),
        ),
      ],
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: () {
          final double basePadding = widget.compact ? 12 : 24;
          return EdgeInsets.only(
            left: basePadding,
            right: basePadding,
            top: basePadding,
            bottom: basePadding + keyboardInset,
          );
        }(),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: widget.compact ? 560 : 680,
            ),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: colors.card,
                shadows: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
                shape: SquircleBorder(
                  cornerRadius: 18,
                  side: const BorderSide(color: Colors.transparent),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 16 : 20,
                  vertical: widget.compact ? 16 : 20,
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EndpointSuffix extends StatelessWidget {
  const EndpointSuffix({super.key, required this.server});

  final String server;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: l10n.authCustomServerOpenSettings,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => EndpointConfigSheet.show(context),
        child: Text(
          '@$server',
          style: context.textTheme.p.copyWith(
            color: context.colorScheme.foreground,
          ),
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
    final textStyle = textTheme.p.copyWith(
      color: enabled ? colors.foreground : colors.mutedForeground,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: textStyle,
            ),
            ShadSwitch(
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}
