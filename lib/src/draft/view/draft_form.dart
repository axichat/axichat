import 'dart:async';
import 'dart:io';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart' show ComposerRecipient;
import 'package:axichat/src/chat/view/recipient_chips_bar.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/attachment_optimizer.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mime/mime.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class DraftForm extends StatefulWidget {
  const DraftForm({
    super.key,
    this.id,
    this.jids = const [''],
    this.body = '',
    this.attachmentMetadataIds = const [],
  });

  final int? id;
  final List<String> jids;
  final String body;
  final List<String> attachmentMetadataIds;

  @override
  State<DraftForm> createState() => _DraftFormState();
}

class _DraftFormState extends State<DraftForm> {
  late final MessageService _messageService;
  late final TextEditingController _bodyTextController;
  late List<ComposerRecipient> _recipients;
  late List<EmailAttachment> _attachments;

  late var id = widget.id;
  late MessageTransport _transport;
  bool _loadingAttachments = false;
  bool _addingAttachment = false;

  @override
  void initState() {
    super.initState();
    _messageService = context.read<MessageService>();
    _bodyTextController = TextEditingController(text: widget.body)
      ..addListener(_bodyListener);
    _recipients = _initialRecipients();
    _attachments = const [];
    _transport = _defaultTransportFor(_recipients);
    if (widget.attachmentMetadataIds.isNotEmpty) {
      unawaited(_hydrateAttachments());
    }
  }

  @override
  void dispose() {
    _bodyTextController.removeListener(_bodyListener);
    _bodyTextController.dispose();
    super.dispose();
  }

  void _bodyListener() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final chats = context.watch<ChatsCubit?>()?.state.items ?? const <Chat>[];
    return SingleChildScrollView(
      child: Form(
        child: BlocConsumer<DraftCubit, DraftState>(
          listener: (context, state) {
            if (state is DraftSaveComplete) {
              ShadToaster.maybeOf(context)?.show(const ShadToast(
                title: Text('Draft saved'),
                alignment: Alignment.topRight,
                showCloseIconOnlyWhenHovered: false,
              ));
            } else if (state is DraftFailure) {
              ShadToaster.maybeOf(context)?.show(
                ShadToast.destructive(
                  title: const Text('Whoops'),
                  description: Text(state.message),
                  alignment: Alignment.topRight,
                  showCloseIconOnlyWhenHovered: false,
                ),
              );
            }
          },
          builder: (context, state) {
            final enabled = state is! DraftSending;
            final hasRecipients =
                _recipients.any((recipient) => recipient.included);
            final bodyText = _bodyTextController.text.trim();
            final attachmentsBlocked =
                _transport == MessageTransport.xmpp && _attachments.isNotEmpty;
            final canSave = enabled &&
                (hasRecipients ||
                    bodyText.isNotEmpty ||
                    _attachments.isNotEmpty);
            final canDiscard = enabled &&
                (id != null || bodyText.isNotEmpty || _attachments.isNotEmpty);
            final canSend = enabled &&
                hasRecipients &&
                bodyText.isNotEmpty &&
                !attachmentsBlocked;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: MessageTransport.values.map((transport) {
                    final selected = _transport == transport;
                    final buttonChild = Text(transport.label);
                    final handler = enabled
                        ? () => setState(() => _transport = transport)
                        : null;
                    if (selected) {
                      return ShadButton(
                        onPressed: handler,
                        child: buttonChild,
                      ).withTapBounce(enabled: handler != null);
                    }
                    return ShadButton.outline(
                      onPressed: handler,
                      child: buttonChild,
                    ).withTapBounce(enabled: handler != null);
                  }).toList(),
                ),
                const SizedBox(height: 12),
                RecipientChipsBar(
                  recipients: _recipients,
                  availableChats: chats,
                  onRecipientAdded: _handleRecipientAdded,
                  onRecipientRemoved: _handleRecipientRemoved,
                  onRecipientToggled: _handleRecipientToggled,
                  latestStatuses: const {},
                ),
                const SizedBox(height: 12),
                _buildAttachmentsSection(enabled: enabled),
                const SizedBox(height: 12),
                AxiTextFormField(
                  controller: _bodyTextController,
                  enabled: enabled,
                  minLines: 7,
                  maxLines: 7,
                  placeholder: const Text('Message'),
                ),
                const SizedBox(height: 12),
                if (state is DraftFailure)
                  Text(
                    state.message,
                    style: TextStyle(
                      color: context.colorScheme.destructive,
                    ),
                  ),
                if (attachmentsBlocked)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Attachments send only over email. Switch transports or discard.',
                      style: context.textTheme.muted,
                    ),
                  ),
                Row(
                  spacing: 8,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ShadButton.destructive(
                      enabled: canDiscard,
                      onPressed: canDiscard ? _handleDiscard : null,
                      child: const Text('Discard'),
                    ).withTapBounce(enabled: canDiscard),
                    ShadButton.outline(
                      enabled: canSave,
                      onPressed: canSave ? _handleSaveDraft : null,
                      child: const Text('Save draft'),
                    ).withTapBounce(enabled: canSave),
                    ShadButton(
                      enabled: canSend,
                      onPressed: canSend ? _handleSendDraft : null,
                      child: const Text('Send'),
                    ).withTapBounce(enabled: canSend),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<ComposerRecipient> _initialRecipients() {
    final chats = context.read<ChatsCubit?>()?.state.items ?? const <Chat>[];
    final recipients = <ComposerRecipient>[];
    for (final value in widget.jids) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      Chat? match;
      for (final chat in chats) {
        if (chat.jid == trimmed) {
          match = chat;
          break;
        }
      }
      if (match != null) {
        recipients.add(
          ComposerRecipient(target: FanOutTarget.chat(match)),
        );
      } else {
        recipients.add(
          ComposerRecipient(target: FanOutTarget.address(address: trimmed)),
        );
      }
    }
    return recipients;
  }

  MessageTransport _defaultTransportFor(List<ComposerRecipient> recipients) {
    if (recipients.isEmpty) {
      return MessageTransport.xmpp;
    }
    final hasForeign = recipients.any((recipient) {
      final address = _recipientAddress(recipient);
      return !_isAxiDestination(address);
    });
    return hasForeign ? MessageTransport.email : MessageTransport.xmpp;
  }

  String _recipientAddress(ComposerRecipient recipient) {
    final chat = recipient.target.chat;
    if (chat != null) {
      return chat.jid;
    }
    return recipient.target.address ?? '';
  }

  bool _isAxiDestination(String value) =>
      value.toLowerCase().endsWith('@axi.im');

  Future<void> _hydrateAttachments() async {
    setState(() => _loadingAttachments = true);
    try {
      final hydrated = await _messageService
          .loadDraftAttachments(widget.attachmentMetadataIds);
      if (!mounted) return;
      setState(() => _attachments = hydrated);
    } finally {
      if (mounted) {
        setState(() => _loadingAttachments = false);
      }
    }
  }

  void _handleRecipientAdded(FanOutTarget target) {
    setState(() {
      final existingIndex =
          _recipients.indexWhere((recipient) => recipient.key == target.key);
      if (existingIndex >= 0) {
        _recipients[existingIndex] =
            _recipients[existingIndex].copyWith(target: target, included: true);
      } else {
        _recipients.add(ComposerRecipient(target: target));
      }
    });
  }

  void _handleRecipientRemoved(String key) {
    setState(() {
      _recipients.removeWhere((recipient) => recipient.key == key);
    });
  }

  void _handleRecipientToggled(String key) {
    setState(() {
      final index = _recipients.indexWhere((recipient) => recipient.key == key);
      if (index == -1) return;
      final recipient = _recipients[index];
      _recipients[index] = recipient.copyWith(included: !recipient.included);
    });
  }

  Future<void> _handleAttachmentAdded() async {
    if (_addingAttachment) return;
    setState(() => _addingAttachment = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withReadStream: false,
      );
      if (result == null || result.files.isEmpty || !mounted) {
        return;
      }
      final file = result.files.single;
      final path = file.path;
      if (path == null) {
        _showToast('Selected file is not accessible.');
        return;
      }
      final size = file.size > 0 ? file.size : await File(path).length();
      final mimeType = lookupMimeType(file.name) ?? lookupMimeType(path);
      var attachment = EmailAttachment(
        path: path,
        fileName: file.name.isNotEmpty ? file.name : path.split('/').last,
        sizeBytes: size,
        mimeType: mimeType,
      );
      attachment = await EmailAttachmentOptimizer.optimize(attachment);
      if (!mounted) return;
      setState(() {
        _attachments = [..._attachments, attachment];
      });
    } on PlatformException catch (error) {
      _showToast(error.message ?? 'Unable to attach file.');
    } on Exception {
      _showToast('Unable to attach file.');
    } finally {
      if (mounted) {
        setState(() => _addingAttachment = false);
      }
    }
  }

  void _handleAttachmentRemoved(String id) {
    setState(() {
      _attachments.removeWhere((attachment) => attachment.metadataId == id);
    });
  }

  Future<void> _handleSaveDraft() async {
    final draftCubit = context.read<DraftCubit?>();
    if (draftCubit == null) return;
    final savedId = await draftCubit.saveDraft(
      id: id,
      jids: _recipientStrings(),
      body: _bodyTextController.text,
      attachments: _attachments,
    );
    setState(() => id = savedId);
  }

  Future<void> _handleDiscard() async {
    final draftCubit = context.read<DraftCubit?>();
    if (draftCubit != null && id != null) {
      await draftCubit.deleteDraft(id: id!);
    }
    setState(() {
      id = null;
      _recipients = [];
      _attachments = const [];
      _bodyTextController.clear();
    });
    _showToast('Draft discarded.');
  }

  Future<void> _handleSendDraft() async {
    final draftCubit = context.read<DraftCubit?>();
    if (draftCubit == null) return;
    await draftCubit.sendDraft(
      id: id,
      jids: _recipientStrings(),
      body: _bodyTextController.text,
      transport: _transport,
    );
    if (!mounted) return;
    context.pop();
  }

  List<String> _recipientStrings() {
    return _recipients
        .where((recipient) => recipient.included)
        .map((recipient) {
          final chat = recipient.target.chat;
          if (chat != null) {
            return chat.jid;
          }
          return recipient.target.address ?? '';
        })
        .where((value) => value.isNotEmpty)
        .toList();
  }

  void _showToast(String message) {
    ShadToaster.maybeOf(context)?.show(
      ShadToast(
        title: const Text('Heads up'),
        description: Text(message),
        alignment: Alignment.topRight,
        showCloseIconOnlyWhenHovered: false,
      ),
    );
  }

  Widget _buildAttachmentsSection({required bool enabled}) {
    final colors = context.colorScheme;
    final attachments = _attachments;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Attachments'),
            const Spacer(),
            ShadButton.outline(
              enabled: enabled && !_addingAttachment,
              onPressed: enabled ? _handleAttachmentAdded : null,
              child: const Text('Add'),
            ).withTapBounce(enabled: enabled && !_addingAttachment),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingAttachments)
          const Center(child: CircularProgressIndicator())
        else if (attachments.isEmpty)
          Text(
            'No attachments yet',
            style: context.textTheme.muted,
          )
        else
          Column(
            children: attachments
                .map(
                  (attachment) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(attachment.fileName),
                    subtitle: Text(_formatBytes(attachment.sizeBytes)),
                    trailing: IconButton(
                      icon: Icon(LucideIcons.x, color: colors.foreground),
                      onPressed: () {
                        final metadataId = attachment.metadataId;
                        if (metadataId == null) {
                          setState(() => _attachments = _attachments
                              .where((item) => item != attachment)
                              .toList());
                        } else {
                          _handleAttachmentRemoved(metadataId);
                        }
                      },
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}
