import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class EmailDemoScreen extends StatefulWidget {
  const EmailDemoScreen({super.key});

  @override
  State<EmailDemoScreen> createState() => _EmailDemoScreenState();
}

class _EmailDemoScreenState extends State<EmailDemoScreen> {
  final _log = Logger('EmailDemoScreen');
  final _messageController = TextEditingController(text: 'Hello from Axichat');

  EmailAccount? _account;
  bool _busy = false;
  String _status = 'Idle';
  bool _requestedInitialLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedInitialLoad) return;
    _requestedInitialLoad = true;
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    final emailService = context.read<EmailService>();
    final credentialStore = context.read<CredentialStore>();
    final jidKey = CredentialStore.registerKey('jid');
    final jid = await credentialStore.read(key: jidKey);
    if (jid == null) {
      if (!mounted) return;
      setState(() {
        _account = null;
        _status = 'Log in to provision email.';
      });
      return;
    }
    final account = await emailService.currentAccount(jid);
    if (!mounted) return;
    setState(() {
      _account = account;
      _status = account == null ? 'Not provisioned' : 'Ready';
    });
  }

  Future<void> _provision() async {
    setState(() {
      _busy = true;
      _status = 'Provisioning email account…';
    });

    try {
      final credentialStore = context.read<CredentialStore>();
      final emailService = context.read<EmailService>();
      final jidKey = CredentialStore.registerKey('jid');
      final jid = await credentialStore.read(key: jidKey);
      if (jid == null) {
        throw StateError('No primary profile found. Log in first.');
      }
      final prefixKey = CredentialStore.registerKey('${jid}_database_prefix');
      final databasePrefix = await credentialStore.read(key: prefixKey);
      if (databasePrefix == null) {
        throw StateError('Missing database prefix.');
      }
      final passphraseKey =
          CredentialStore.registerKey('${databasePrefix}_database_passphrase');
      final passphrase = await credentialStore.read(key: passphraseKey);
      if (passphrase == null) {
        throw StateError('Missing database passphrase.');
      }

      final account = await emailService.ensureProvisioned(
        displayName: jid.split('@').first,
        databasePrefix: databasePrefix,
        databasePassphrase: passphrase,
        jid: jid,
      );
      if (!mounted) return;
      setState(() {
        _account = account;
        _status = 'Provisioned ${account.address}';
      });
    } on Exception catch (error, stackTrace) {
      _log.severe('Provisioning failed', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _status = 'Provisioning failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _sendDemoMessage() async {
    if (_account == null) {
      setState(() => _status = 'Provision an account first.');
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Sending demo message…';
    });
    try {
      final emailService = context.read<EmailService>();
      final msgId = await emailService.sendToAddress(
        address: _account!.address,
        displayName: 'Self',
        body: _messageController.text,
      );
      if (!mounted) return;
      setState(() {
        _status = 'Sent demo message (id=$msgId)';
      });
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to send demo message', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _status = 'Send failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    return Scaffold(
      backgroundColor: context.colorScheme.background,
      appBar: AppBar(
        backgroundColor: context.colorScheme.background,
        scrolledUnderElevation: 0,
        forceMaterialTransparency: true,
        shape: Border(
          bottom: BorderSide(color: context.colorScheme.border),
        ),
        leadingWidth: AxiIconButton.kDefaultSize + 24,
        leading: Navigator.canPop(context)
            ? Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: AxiIconButton.kDefaultSize,
                    height: AxiIconButton.kDefaultSize,
                    child: AxiIconButton(
                      iconData: LucideIcons.arrowLeft,
                      tooltip: 'Back',
                      color: context.colorScheme.foreground,
                      borderColor: context.colorScheme.border,
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ),
                ),
              )
            : null,
        title: const Text('Email Transport Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $_status'),
            const SizedBox(height: 8),
            Text('Account: ${account?.address ?? 'Not provisioned'}'),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Demo message',
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton(
                  onPressed: _busy ? null : _provision,
                  child: const Text('Provision Email'),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : _sendDemoMessage,
                  child: const Text('Send Demo Message'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
