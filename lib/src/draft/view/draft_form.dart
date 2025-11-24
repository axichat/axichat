import 'dart:async';
import 'dart:io';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart' show ComposerRecipient;
import 'package:axichat/src/chat/models/pending_attachment.dart';
import 'package:axichat/src/chat/view/pending_attachment_list.dart';
import 'package:axichat/src/chat/view/recipient_chips_bar.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
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

const double _draftComposerControlExtent = 44;

class DraftForm extends StatefulWidget {
  const DraftForm({
    super.key,
    this.id,
    this.jids = const [''],
    this.body = '',
    this.subject = '',
    this.attachmentMetadataIds = const [],
    this.suggestionAddresses = const <String>{},
    this.suggestionDomains = const <String>{},
  });

  final int? id;
  final List<String> jids;
  final String body;
  final String subject;
  final List<String> attachmentMetadataIds;
  final Set<String> suggestionAddresses;
  final Set<String> suggestionDomains;

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
              ShadToaster.maybeOf(context)?.show(
                FeedbackToast.success(title: 'Draft saved'),
              );
            } else if (state is DraftFailure) {
              ShadToaster.maybeOf(context)?.show(
                FeedbackToast.error(
                  title: 'Whoops',
                  message: state.message,
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
                  collapsedByDefault: false,
                  suggestionAddresses: widget.suggestionAddresses,
                  suggestionDomains: widget.suggestionDomains,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: horizontalPadding,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Semantics(
                          label: 'Email subject',
                          textField: true,
                          child: AxiTextFormField(
                            controller: _subjectTextController,
                            focusNode: _subjectFocusNode,
                            enabled: enabled,
                            minLines: 1,
                            maxLines: 1,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => _bodyFocusNode.requestFocus(),
                            placeholder: const Text('Subject (optional)'),
                            constraints: const BoxConstraints.tightFor(
                              height: _draftComposerControlExtent,
                            ),
                            crossAxisAlignment: CrossAxisAlignment.center,
                            placeholderAlignment: Alignment.centerLeft,
                            inputPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _DraftSendIconButton(
                        enabled: canSend,
                        onPressed: canSend ? _handleSendDraft : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: horizontalPadding,
                  child: _DraftAttachmentsSection(
                    enabled: enabled,
                    loading: _loadingAttachments,
                    attachments: _pendingAttachments,
                    addingAttachment: _addingAttachment,
                    onAddAttachment: _handleAttachmentAdded,
                    onRetry: _handlePendingAttachmentRetry,
                    onRemove: _handlePendingAttachmentRemoved,
                    onAttachmentPressed: _handlePendingAttachmentPressed,
                    onAttachmentLongPressed:
                        _handlePendingAttachmentLongPressed,
                    onPreview: _showAttachmentPreview,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: horizontalPadding,
                  child: Semantics(
                    label: 'Message body',
                    textField: true,
                    child: AxiTextFormField(
                      controller: _bodyTextController,
                      focusNode: _bodyFocusNode,
                      enabled: enabled,
                      minLines: 7,
                      maxLines: 7,
                      placeholder: const Text('Message'),
                    ),
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
                        children: [
                          ShadButton.destructive(
                            enabled: canDiscard,
                            onPressed: canDiscard ? _handleDiscard : null,
                            child: const Text('Discard'),
                          ).withTapBounce(enabled: canDiscard),
                          const Spacer(),
                          ShadButton.outline(
                            enabled: canSave,
                            onPressed: canSave ? _handleSaveDraft : null,
                            child: const Text('Save draft'),
                          ).withTapBounce(enabled: canSave),
                        ],
                      ),
                      const SizedBox(height: 12),
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
    final xmppJids =
        split.xmppTargets.map(_resolveXmppJid).whereType<String>().toList();
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
          final xmppJid = _resolveXmppJid(recipient);
          if (xmppJid != null) {
            return xmppJid;
          }
          return recipient.target.normalizedAddress ??
              recipient.target.address ??
              '';
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
      final xmppJid = _resolveXmppJid(recipient);
      if (xmppJid != null) {
        xmppTargets.add(recipient);
        continue;
      }
      emailTargets.add(recipient);
    }
    return (
      emailTargets: emailTargets,
      xmppTargets: xmppTargets,
      hasActiveRecipients: emailTargets.isNotEmpty || xmppTargets.isNotEmpty,
    );
  }

  String? _resolveXmppJid(ComposerRecipient recipient) {
    final chat = recipient.target.chat;
    if (chat != null) {
      return _isAxiDestination(chat.jid) ? chat.jid : null;
    }
    final normalizedAddress = recipient.target.normalizedAddress;
    final rawAddress = recipient.target.address;
    final candidate = normalizedAddress ?? rawAddress?.trim();
    if (candidate == null || candidate.isEmpty) {
      return null;
    }
    return _isAxiDestination(candidate) ? candidate : null;
  }

  List<EmailAttachment> _currentAttachments() =>
      _pendingAttachments.map((pending) => pending.attachment).toList();

  void _showToast(String message) {
    ShadToaster.maybeOf(context)?.show(
      FeedbackToast.info(message: message),
    );
  }

  String _nextPendingAttachmentId() =>
      'draft-pending-${_pendingAttachmentSeed++}';

  void _handlePendingAttachmentRetry(String id) {}

  void _handlePendingAttachmentPressed(PendingAttachment pending) {
    final commandSurface =
        EnvScope.maybeOf(context)?.commandSurface ?? CommandSurface.sheet;
    if (commandSurface == CommandSurface.menu) {
      if (pending.attachment.isImage) {
        _showAttachmentPreview(pending);
      }
      return;
    }
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
    await showAdaptiveBottomSheet<void>(
      context: context,
      showDragHandle: true,
      dialogMaxWidth: 520,
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

class _DraftSendIconButton extends StatelessWidget {
  const _DraftSendIconButton({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final iconColor = enabled ? colors.primary : colors.mutedForeground;
    final borderColor = enabled ? colors.primary : colors.border;
    // ignore: prefer_const_constructors
    // ignore: prefer_const_constructors
    return Tooltip(
      message: 'Send draft',
      waitDuration: const Duration(milliseconds: 400),
      child: _DraftComposerIconButton(
        tooltip: 'Send draft',
        icon: LucideIcons.send,
        onPressed: enabled ? onPressed : null,
        iconColorOverride: iconColor,
        borderColorOverride: borderColor,
      ),
    );
  }
}

class _DraftAttachmentsSection extends StatelessWidget {
  const _DraftAttachmentsSection({
    required this.enabled,
    required this.loading,
    required this.attachments,
    required this.addingAttachment,
    required this.onAddAttachment,
    required this.onRetry,
    required this.onRemove,
    required this.onAttachmentPressed,
    required this.onAttachmentLongPressed,
    required this.onPreview,
  });

  final bool enabled;
  final bool loading;
  final bool addingAttachment;
  final List<PendingAttachment> attachments;
  final Future<void> Function()? onAddAttachment;
  final ValueChanged<String> onRetry;
  final ValueChanged<String> onRemove;
  final ValueChanged<PendingAttachment> onAttachmentPressed;
  final ValueChanged<PendingAttachment> onAttachmentLongPressed;
  final Future<void> Function(PendingAttachment) onPreview;

  @override
  Widget build(BuildContext context) {
    final canSelectAttachment = enabled && !addingAttachment;
    final commandSurface =
        EnvScope.maybeOf(context)?.commandSurface ?? CommandSurface.sheet;
    final useDesktopMenu = commandSurface == CommandSurface.menu;

    List<Widget> menuItems(PendingAttachment pending) {
      final items = <Widget>[];
      if (pending.attachment.isImage) {
        items.add(
          ShadContextMenuItem(
            leading: const Icon(LucideIcons.image),
            onPressed: () => onPreview(pending),
            child: const Text('Preview'),
          ),
        );
      }
      items.add(
        ShadContextMenuItem(
          leading: const Icon(LucideIcons.trash2),
          onPressed: () => onRemove(pending.id),
          child: const Text('Remove attachment'),
        ),
      );
      return items;
    }

    Widget body;
    if (loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (attachments.isEmpty) {
      body = Text(
        'No attachments yet',
        style: context.textTheme.muted,
      );
    } else {
      body = PendingAttachmentList(
        attachments: attachments,
        onRetry: onRetry,
        onRemove: onRemove,
        onPressed: onAttachmentPressed,
        onLongPress: useDesktopMenu ? null : onAttachmentLongPressed,
        contextMenuBuilder: useDesktopMenu ? menuItems : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Attachments'),
            const Spacer(),
            _DraftComposerIconButton(
              tooltip: 'Add attachment',
              icon: LucideIcons.paperclip,
              onPressed: canSelectAttachment ? onAddAttachment : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        body,
      ],
    );
  }
}

class _DraftComposerIconButton extends StatelessWidget {
  const _DraftComposerIconButton({
    required this.tooltip,
    required this.icon,
    this.onPressed,
    this.iconColorOverride,
    this.borderColorOverride,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? iconColorOverride;
  final Color? borderColorOverride;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final enabled = onPressed != null;
    final iconColor = iconColorOverride ??
        (enabled ? colors.foreground : colors.mutedForeground);
    final borderColor = borderColorOverride ?? colors.border;
    final button = IconButton(
      icon: Icon(icon, size: 24, color: iconColor),
      tooltip: tooltip,
      onPressed: onPressed,
      splashRadius: _draftComposerControlExtent / 2,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: _draftComposerControlExtent,
        minHeight: _draftComposerControlExtent,
      ),
      visualDensity: VisualDensity.compact,
    );
    final decorated = DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.card,
        shape: SquircleBorder(
          cornerRadius: 16,
          side: BorderSide(
            color: borderColor,
            width: 1.4,
          ),
        ),
      ),
      child: button,
    );
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        onTap: enabled ? onPressed : null,
        child: decorated.withTapBounce(enabled: enabled),
      ),
    );
  }
}
