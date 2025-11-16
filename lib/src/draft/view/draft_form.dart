import 'dart:async';
import 'dart:io';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart' show ComposerRecipient;
import 'package:axichat/src/chat/models/pending_attachment.dart';
import 'package:axichat/src/chat/view/pending_attachment_list.dart';
import 'package:axichat/src/chat/view/recipient_chips_bar.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/models/draft_save_result.dart';
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
    this.subject = '',
    this.attachmentMetadataIds = const [],
  });

  final int? id;
  final List<String> jids;
  final String body;
  final String subject;
  final List<String> attachmentMetadataIds;

  @override
  State<DraftForm> createState() => _DraftFormState();
}

class _DraftFormState extends State<DraftForm> {
  late final MessageService _messageService;
  late final TextEditingController _bodyTextController;
  late final TextEditingController _subjectTextController;
  late final FocusNode _bodyFocusNode;
  late final FocusNode _subjectFocusNode;
  late List<ComposerRecipient> _recipients;
  late List<PendingAttachment> _pendingAttachments;

  late var id = widget.id;
  bool _loadingAttachments = false;
  bool _addingAttachment = false;
  int _pendingAttachmentSeed = 0;

  @override
  void initState() {
    super.initState();
    _messageService = context.read<MessageService>();
    _bodyTextController = TextEditingController(text: widget.body)
      ..addListener(_bodyListener);
    _subjectTextController = TextEditingController(text: widget.subject)
      ..addListener(_subjectListener);
    _bodyFocusNode = FocusNode();
    _subjectFocusNode = FocusNode();
    _recipients = _initialRecipients();
    _pendingAttachments = const [];
    if (widget.attachmentMetadataIds.isNotEmpty) {
      unawaited(_hydrateAttachments());
    }
  }

  @override
  void dispose() {
    _bodyTextController.removeListener(_bodyListener);
    _bodyTextController.dispose();
    _subjectTextController.removeListener(_subjectListener);
    _subjectTextController.dispose();
    _bodyFocusNode.dispose();
    _subjectFocusNode.dispose();
    super.dispose();
  }

  void _bodyListener() => setState(() {});
  void _subjectListener() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final chats = context.watch<ChatsCubit?>()?.state.items ?? const <Chat>[];
    const horizontalPadding = EdgeInsets.symmetric(horizontal: 16);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 20),
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
            final bodyText = _bodyTextController.text.trim();
            final subjectText = _subjectTextController.text.trim();
            final pendingAttachments = _pendingAttachments;
            final hasAttachments = pendingAttachments.isNotEmpty;
            final hasQueuedAttachments = pendingAttachments.any(
              (attachment) =>
                  attachment.status == PendingAttachmentStatus.queued,
            );
            final split = _splitRecipients(
              forceEmailAll: hasAttachments,
            );
            final hasActiveRecipients = split.hasActiveRecipients;
            final canSave = enabled &&
                (hasActiveRecipients ||
                    bodyText.isNotEmpty ||
                    subjectText.isNotEmpty ||
                    hasAttachments);
            final canDiscard = enabled &&
                (id != null ||
                    bodyText.isNotEmpty ||
                    subjectText.isNotEmpty ||
                    hasAttachments);
            final canSend = enabled &&
                hasActiveRecipients &&
                (bodyText.isNotEmpty ||
                    subjectText.isNotEmpty ||
                    hasAttachments ||
                    hasQueuedAttachments);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RecipientChipsBar(
                  recipients: _recipients,
                  availableChats: chats,
                  onRecipientAdded: _handleRecipientAdded,
                  onRecipientRemoved: _handleRecipientRemoved,
                  onRecipientToggled: _handleRecipientToggled,
                  latestStatuses: const {},
                  collapsedByDefault: true,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: horizontalPadding,
                  child: AxiTextFormField(
                    controller: _subjectTextController,
                    focusNode: _subjectFocusNode,
                    enabled: enabled,
                    minLines: 1,
                    maxLines: 1,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _bodyFocusNode.requestFocus(),
                    placeholder: const Text('Subject (optional)'),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: horizontalPadding,
                  child: _buildAttachmentsSection(enabled: enabled),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: horizontalPadding,
                  child: AxiTextFormField(
                    controller: _bodyTextController,
                    focusNode: _bodyFocusNode,
                    enabled: enabled,
                    minLines: 7,
                    maxLines: 7,
                    placeholder: const Text('Message'),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: horizontalPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (state is DraftFailure)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            state.message,
                            style: TextStyle(
                              color: context.colorScheme.destructive,
                            ),
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
                  ),
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

  bool _isAxiDestination(String value) =>
      value.toLowerCase().endsWith('@axi.im');

  Future<void> _hydrateAttachments() async {
    if (widget.attachmentMetadataIds.isEmpty) {
      return;
    }
    setState(() => _loadingAttachments = true);
    try {
      final pending =
          await _pendingAttachmentsFromMetadata(widget.attachmentMetadataIds);
      if (!mounted) return;
      setState(() => _pendingAttachments = pending);
    } finally {
      if (mounted) {
        setState(() => _loadingAttachments = false);
      }
    }
  }

  Future<List<PendingAttachment>> _pendingAttachmentsFromMetadata(
    Iterable<String> metadataIds,
  ) async {
    if (metadataIds.isEmpty) return const [];
    final hydrated =
        await _messageService.loadDraftAttachments(metadataIds.toList());
    return hydrated
        .map(
          (attachment) => PendingAttachment(
            id: attachment.metadataId ?? _nextPendingAttachmentId(),
            attachment: attachment,
          ),
        )
        .toList();
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
        _pendingAttachments = [
          ..._pendingAttachments,
          PendingAttachment(
            id: attachment.metadataId ?? _nextPendingAttachmentId(),
            attachment: attachment,
          ),
        ];
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

  void _handlePendingAttachmentRemoved(String id) {
    setState(() {
      _pendingAttachments =
          _pendingAttachments.where((pending) => pending.id != id).toList();
    });
  }

  Future<void> _handleSaveDraft() async {
    final draftCubit = context.read<DraftCubit?>();
    if (draftCubit == null) return;
    final attachmentIds =
        _pendingAttachments.map((pending) => pending.id).toList();
    final DraftSaveResult result = await draftCubit.saveDraft(
      id: id,
      jids: _recipientStrings(),
      body: _bodyTextController.text,
      subject: _subjectTextController.text,
      attachments: _currentAttachments(),
    );
    if (!mounted) return;
    setState(() => id = result.draftId);
    await _applyAttachmentMetadataIds(
      metadataIds: result.attachmentMetadataIds,
      expectedAttachmentIds: attachmentIds,
    );
  }

  Future<void> _applyAttachmentMetadataIds({
    required List<String> metadataIds,
    required List<String> expectedAttachmentIds,
  }) async {
    if (!mounted || metadataIds.isEmpty) {
      return;
    }
    if (metadataIds.length != expectedAttachmentIds.length) {
      return;
    }
    final idToMetadata = <String, String>{};
    for (var index = 0; index < expectedAttachmentIds.length; index++) {
      idToMetadata[expectedAttachmentIds[index]] = metadataIds[index];
    }
    var changed = false;
    final updated = <PendingAttachment>[];
    for (final pending in _pendingAttachments) {
      final metadataId = idToMetadata[pending.id];
      if (metadataId == null || pending.attachment.metadataId == metadataId) {
        updated.add(pending);
        continue;
      }
      changed = true;
      updated.add(
        pending.copyWith(
          attachment: pending.attachment.copyWith(metadataId: metadataId),
        ),
      );
    }
    if (!changed) {
      return;
    }
    setState(() => _pendingAttachments = updated);
  }

  Future<void> _handleDiscard() async {
    final draftCubit = context.read<DraftCubit?>();
    if (draftCubit != null && id != null) {
      await draftCubit.deleteDraft(id: id!);
    }
    setState(() {
      id = null;
      _recipients = [];
      _pendingAttachments = const [];
      _bodyTextController.clear();
      _subjectTextController.clear();
    });
    _showToast('Draft discarded.');
  }

  Future<void> _handleSendDraft() async {
    final draftCubit = context.read<DraftCubit?>();
    if (draftCubit == null) return;
    final hasAttachments = _pendingAttachments.isNotEmpty;
    final split = _splitRecipients(forceEmailAll: hasAttachments);
    final xmppJids = split.xmppTargets
        .where((recipient) => recipient.target.chat != null)
        .map((recipient) => recipient.target.chat!.jid)
        .toList();
    final emailTargets = split.emailTargets.map((recipient) {
      final chat = recipient.target.chat;
      if (chat != null) {
        return FanOutTarget.chat(chat);
      }
      return recipient.target;
    }).toList();
    final succeeded = await draftCubit.sendDraft(
      id: id,
      xmppJids: xmppJids,
      emailTargets: emailTargets,
      body: _bodyTextController.text,
      subject: _subjectTextController.text,
      attachments: _currentAttachments(),
    );
    if (!mounted) {
      return;
    }
    if (succeeded) {
      context.pop();
    } else {
      _bodyFocusNode.requestFocus();
    }
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

  ({
    List<ComposerRecipient> emailTargets,
    List<ComposerRecipient> xmppTargets,
    bool hasActiveRecipients
  }) _splitRecipients({
    required bool forceEmailAll,
  }) {
    final emailTargets = <ComposerRecipient>[];
    final xmppTargets = <ComposerRecipient>[];
    for (final recipient in _recipients) {
      if (!recipient.included) continue;
      if (forceEmailAll) {
        emailTargets.add(recipient);
        continue;
      }
      final chat = recipient.target.chat;
      if (chat == null) {
        emailTargets.add(recipient);
        continue;
      }
      if (_isAxiDestination(chat.jid)) {
        xmppTargets.add(recipient);
      } else {
        emailTargets.add(recipient);
      }
    }
    return (
      emailTargets: emailTargets,
      xmppTargets: xmppTargets,
      hasActiveRecipients: emailTargets.isNotEmpty || xmppTargets.isNotEmpty,
    );
  }

  List<EmailAttachment> _currentAttachments() =>
      _pendingAttachments.map((pending) => pending.attachment).toList();

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

  String _nextPendingAttachmentId() =>
      'draft-pending-${_pendingAttachmentSeed++}';

  Widget _buildAttachmentsSection({required bool enabled}) {
    final attachments = _pendingAttachments;
    final canSelectAttachment = enabled && !_addingAttachment;
    final addHandler = !enabled ? null : _handleAttachmentAdded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Attachments'),
            const Spacer(),
            _composerIconButton(
              tooltip: 'Add attachment',
              icon: LucideIcons.paperclip,
              onPressed: canSelectAttachment ? addHandler : null,
            ),
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
          PendingAttachmentList(
            attachments: attachments,
            onRetry: _handlePendingAttachmentRetry,
            onRemove: _handlePendingAttachmentRemoved,
            onPressed: _handlePendingAttachmentPressed,
            onLongPress: _handlePendingAttachmentLongPressed,
          ),
      ],
    );
  }

  Widget _composerIconButton({
    required String tooltip,
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    final colors = context.colorScheme;
    final enabled = onPressed != null;
    final iconColor = enabled ? colors.foreground : colors.mutedForeground;
    final background = colors.card;
    final decoration = ShapeDecoration(
      color: background,
      shadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
      shape: SquircleBorder(
        cornerRadius: 18,
        side: BorderSide(color: colors.border),
      ),
    );
    final child = Container(
      width: 38,
      height: 38,
      decoration: decoration,
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 18,
        color: iconColor,
      ),
    );
    final tappable = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(child: child),
        ),
      ),
    ).withTapBounce(enabled: enabled);
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: tappable,
    );
  }

  void _handlePendingAttachmentRetry(String id) {}

  void _handlePendingAttachmentPressed(PendingAttachment pending) {
    _showPendingAttachmentActions(pending);
  }

  void _handlePendingAttachmentLongPressed(PendingAttachment pending) {
    _showPendingAttachmentActions(pending);
  }

  Future<void> _showAttachmentPreview(PendingAttachment pending) async {
    if (!mounted) return;
    final attachment = pending.attachment;
    final file = File(attachment.path);
    if (!await file.exists()) {
      _showToast('File no longer exists at ${attachment.path}.');
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(LucideIcons.x),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showPendingAttachmentActions(PendingAttachment pending) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final attachment = pending.attachment;
        final sizeLabel = formatBytes(attachment.sizeBytes);
        final colors = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    attachmentIcon(attachment),
                    color: colors.primary,
                  ),
                  title: Text(attachment.fileName),
                  subtitle: Text(sizeLabel),
                ),
                if (attachment.isImage)
                  ListTile(
                    leading: const Icon(LucideIcons.image),
                    title: const Text('Preview'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _showAttachmentPreview(pending);
                    },
                  ),
                ListTile(
                  leading: const Icon(LucideIcons.trash2),
                  title: const Text('Remove attachment'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _handlePendingAttachmentRemoved(pending.id);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
