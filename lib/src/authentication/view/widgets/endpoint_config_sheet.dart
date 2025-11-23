import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class EndpointConfigSheet extends StatefulWidget {
  const EndpointConfigSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const EndpointConfigSheet(),
      );

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

  @override
  void initState() {
    super.initState();
    final config = context.read<AuthenticationCubit>().endpointConfig;
    _enableXmpp = config.enableXmpp;
    _enableSmtp = config.enableSmtp;
    _useDns = config.useDns;
    _useSrv = config.useSrv;
    _requireDnssec = config.requireDnssec;
    _domainController = TextEditingController(text: config.domain);
    _xmppHostController = TextEditingController(text: config.xmppHost ?? '');
    _smtpHostController = TextEditingController(text: config.smtpHost ?? '');
    _xmppPortController =
        TextEditingController(text: config.xmppPort.toString());
    _smtpPortController =
        TextEditingController(text: config.smtpPort.toString());
    _apiPortController = TextEditingController(text: config.apiPort.toString());
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
    final cubit = context.read<AuthenticationCubit>();
    final updated = _buildConfig(cubit.endpointConfig);
    await cubit.updateEndpointConfig(updated);
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
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 16 + viewInsets.bottom,
        top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Custom server',
            style: textTheme.h4,
          ),
          const SizedBox(height: 8),
          Text(
            'Override XMPP/SMTP endpoints or enable DNS lookups. Leave fields '
            'blank to keep defaults.',
            style: textTheme.muted,
          ),
          const SizedBox(height: 16),
          AxiTextFormField(
            autocorrect: false,
            keyboardType: TextInputType.url,
            controller: _domainController,
            placeholder: const Text('Domain or IP'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ToggleTile(
                  label: 'XMPP',
                  value: _enableXmpp,
                  onChanged: (value) =>
                      setState(() => _enableXmpp = value ?? _enableXmpp),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ToggleTile(
                  label: 'SMTP',
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
                  label: 'Use DNS',
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
                  label: 'Use SRV',
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
            label: 'Require DNSSEC',
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
                  keyboardType: TextInputType.url,
                  placeholder: const Text('XMPP host (optional)'),
                  controller: _xmppHostController,
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
                  placeholder: const Text('Port'),
                  controller: _xmppPortController,
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
                  placeholder: const Text('SMTP host (optional)'),
                  controller: _smtpHostController,
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
                  placeholder: const Text('Port'),
                  controller: _smtpPortController,
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
              placeholder: const Text('API port'),
              controller: _apiPortController,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ShadButton.secondary(
                  onPressed: _reset,
                  child: const Text('Reset to axi.im'),
                ).withTapBounce(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ShadButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ).withTapBounce(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Advanced server options stay hidden until you tap the username '
            'suffix.',
            style: textTheme.muted.copyWith(color: colors.muted),
          ),
        ],
      ),
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
      label: 'Open custom server settings',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => EndpointConfigSheet.show(context),
        child: Text('@$server'),
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
    final materialText = Theme.of(context).textTheme.bodyMedium;
    return DecoratedBox(
      decoration: BoxDecoration(
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
              style: (materialText ?? const TextStyle())
                  .copyWith(color: enabled ? colors.foreground : colors.muted),
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
