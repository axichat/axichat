import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
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
  final _messageController = TextEditingController();

  EmailAccount? _account;
  bool _busy = false;
  late String _status;
  bool _requestedInitialLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedInitialLoad) return;
    _requestedInitialLoad = true;
    _status = context.l10n.emailDemoStatusIdle;
    _messageController.text = context.l10n.emailDemoDefaultMessage;
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    final l10n = context.l10n;
    final emailService = context.read<EmailService>();
    final credentialStore = context.read<CredentialStore>();
    final jidKey = CredentialStore.registerKey('jid');
    final jid = await credentialStore.read(key: jidKey);
    if (jid == null) {
      if (!mounted) return;
      setState(() {
        _account = null;
        _status = l10n.emailDemoStatusLoginToProvision;
      });
      return;
    }
    final account = await emailService.currentAccount(jid);
    if (!mounted) return;
    setState(() {
      _account = account;
      _status = account == null
          ? l10n.emailDemoStatusNotProvisioned
          : l10n.emailDemoStatusReady;
    });
  }

  Future<void> _provision() async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _status = l10n.emailDemoStatusProvisioning;
    });

    try {
      final credentialStore = context.read<CredentialStore>();
      final emailService = context.read<EmailService>();
      final jidKey = CredentialStore.registerKey('jid');
      final jid = await credentialStore.read(key: jidKey);
      if (jid == null) {
        throw StateError(l10n.emailDemoErrorMissingProfile);
      }
      final prefixKey = CredentialStore.registerKey('${jid}_database_prefix');
      final databasePrefix = await credentialStore.read(key: prefixKey);
      if (databasePrefix == null) {
        throw StateError(l10n.emailDemoErrorMissingPrefix);
      }
      final passphraseKey =
          CredentialStore.registerKey('${databasePrefix}_database_passphrase');
      final passphrase = await credentialStore.read(key: passphraseKey);
      if (passphrase == null) {
        throw StateError(l10n.emailDemoErrorMissingPassphrase);
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
        _status = l10n.emailDemoStatusProvisioned(account.address);
      });
    } on Exception catch (error, stackTrace) {
      _log.severe('Provisioning failed', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _status = l10n.emailDemoStatusProvisionFailed('$error');
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
    final l10n = context.l10n;
    if (_account == null) {
      setState(() => _status = l10n.emailDemoStatusProvisionFirst);
      return;
    }
    setState(() {
      _busy = true;
      _status = l10n.emailDemoStatusSending;
    });
    try {
      final emailService = context.read<EmailService>();
      final msgId = await emailService.sendToAddress(
        address: _account!.address,
        displayName: l10n.emailDemoDisplayNameSelf,
        body: _messageController.text,
      );
      if (!mounted) return;
      setState(() {
        _status = l10n.emailDemoStatusSent('$msgId');
      });
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to send demo message', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _status = l10n.emailDemoStatusSendFailed('$error');
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
                      tooltip: context.l10n.commonBack,
                      color: context.colorScheme.foreground,
                      borderColor: context.colorScheme.border,
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ),
                ),
              )
            : null,
        title: Text(context.l10n.emailDemoTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.emailDemoStatusLabel(_status)),
            const SizedBox(height: 8),
            Text(
              context.l10n.emailDemoAccountLabel(
                account?.address ?? context.l10n.emailDemoStatusNotProvisioned,
              ),
            ),
            const SizedBox(height: 16),
            AxiTextField(
              controller: _messageController,
              decoration: InputDecoration(
                labelText: context.l10n.emailDemoMessageLabel,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton(
                  onPressed: _busy ? null : _provision,
                  child: Text(context.l10n.emailDemoProvisionButton),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : _sendDemoMessage,
                  child: Text(context.l10n.emailDemoSendButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
