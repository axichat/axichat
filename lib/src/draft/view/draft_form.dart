import 'dart:async';
import 'dart:io';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/task_share_formatter.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/models/calendar_drag_payload.dart';
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
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mime/mime.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _draftComposerControlExtent = 42;
const double _draftSubjectHeight = 32;

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
    this.onClosed,
    this.onDiscarded,
  });

  final int? id;
  final List<String> jids;
  final String body;
  final String subject;
  final List<String> attachmentMetadataIds;
  final Set<String> suggestionAddresses;
  final Set<String> suggestionDomains;
  final VoidCallback? onClosed;
  final VoidCallback? onDiscarded;

  @override
  State<DraftForm> createState() => _DraftFormState();
}

class _DraftFormState extends State<DraftForm> {
  final _formKey = GlobalKey<FormState>();
  bool _showValidationMessages = false;
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
  bool _sendingDraft = false;
  bool _sendCompletionHandled = false;

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

  void _appendTaskShareText(CalendarTask task) {
    final String shareText = task.toShareText();
    final String existing = _bodyTextController.text;
    final String separator = existing.trim().isEmpty ? '' : '\n\n';
    final String nextText = '$existing$separator$shareText';
    _bodyTextController.value = _bodyTextController.value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
      composing: TextRange.empty,
    );
    _bodyFocusNode.requestFocus();
  }

  void _handleTaskDrop(CalendarDragPayload payload) {
    _appendTaskShareText(payload.snapshot);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chats = context.watch<ChatsCubit?>()?.state.items ?? const <Chat>[];
    final autovalidateMode = _showValidationMessages
        ? AutovalidateMode.always
        : AutovalidateMode.disabled;
    const horizontalPadding = EdgeInsets.symmetric(horizontal: 16);
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Form(
        key: _formKey,
        autovalidateMode: autovalidateMode,
        child: BlocConsumer<DraftCubit, DraftState>(
          listener: (context, state) {
            if (state is DraftSaveComplete) {
              ShadToaster.maybeOf(context)?.show(
                FeedbackToast.success(title: l10n.draftSaved),
              );
            }
            if (state is DraftSending) {
              if (_sendingDraft && mounted) {
                setState(() {
                  _pendingAttachments = _pendingAttachments
                      .map(
                        (pending) => pending.copyWith(
                          status: PendingAttachmentStatus.uploading,
                          clearErrorMessage: true,
                        ),
                      )
                      .toList();
                });
              }
            } else if (state is DraftFailure) {
              if (!_sendingDraft) return;
              if (mounted) {
                setState(() {
                  _sendCompletionHandled = true;
                  _sendingDraft = false;
                  _pendingAttachments = _pendingAttachments
                      .map(
                        (pending) => pending.copyWith(
                          status: PendingAttachmentStatus.failed,
                          errorMessage: state.message,
                        ),
                      )
                      .toList();
                });
              }
              ShadToaster.maybeOf(context)?.show(
                FeedbackToast.error(
                  title: l10n.draftErrorTitle,
                  message: state.message,
                ),
              );
            } else if (state is DraftSendComplete) {
              _handleSendComplete();
            }
          },
          builder: (context, state) {
            final isSending = state is DraftSending && _sendingDraft;
            final showFailure = state is DraftFailure && _sendingDraft;
            final enabled = !isSending;
            final bodyText = _bodyTextController.text.trim();
            final subjectText = _subjectTextController.text.trim();
            final pendingAttachments = _pendingAttachments;
            final hasAttachments = pendingAttachments.isNotEmpty;
            final split = _splitRecipients();
            final hasActiveRecipients = split.hasActiveRecipients;
            final hasContent = _hasContent(hasAttachments: hasAttachments);
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
            final sendBlocker = _sendValidationMessage(
              hasActiveRecipients: hasActiveRecipients,
              hasContent: hasContent,
            );
            final readyToSend = sendBlocker == null;

            return _DraftTaskDropRegion(
              onTaskDropped: enabled ? _handleTaskDrop : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FormField<void>(
                    validator: (_) =>
                        hasActiveRecipients ? null : l10n.draftNoRecipients,
                    builder: (field) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          RecipientChipsBar(
                            recipients: _recipients,
                            availableChats: chats,
                            onRecipientAdded: (target) {
                              _handleRecipientAdded(target);
                              field.didChange(null);
                            },
                            onRecipientRemoved: (key) {
                              _handleRecipientRemoved(key);
                              field.didChange(null);
                            },
                            onRecipientToggled: (key) {
                              _handleRecipientToggled(key);
                              field.didChange(null);
                            },
                            latestStatuses: const {},
                            collapsedByDefault: false,
                            suggestionAddresses: widget.suggestionAddresses,
                            suggestionDomains: widget.suggestionDomains,
                          ),
                          if (_showValidationMessages && field.hasError)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                field.errorText ?? '',
                                style: TextStyle(
                                  color: context.colorScheme.destructive,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: horizontalPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Semantics(
                                label: l10n.draftSubjectSemantics,
                                textField: true,
                                child: AxiTextFormField(
                                  controller: _subjectTextController,
                                  focusNode: _subjectFocusNode,
                                  enabled: enabled,
                                  minLines: 1,
                                  maxLines: 1,
                                  textInputAction: TextInputAction.next,
                                  onSubmitted: (_) =>
                                      _bodyFocusNode.requestFocus(),
                                  placeholder:
                                      Text(l10n.draftSubjectHintOptional),
                                  constraints: const BoxConstraints.tightFor(
                                    height: _draftSubjectHeight,
                                  ),
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  placeholderAlignment: Alignment.centerLeft,
                                  inputPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _DraftSendIconButton(
                              readyToSend: readyToSend,
                              sending: isSending,
                              disabledReason: sendBlocker,
                              onPressed: isSending ? null : _handleSendDraft,
                            ),
                          ],
                        ),
                        if (_showValidationMessages && sendBlocker != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              sendBlocker,
                              style: TextStyle(
                                color: context.colorScheme.destructive,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
                      label: l10n.draftMessageSemantics,
                      textField: true,
                      child: AxiTextFormField(
                        controller: _bodyTextController,
                        focusNode: _bodyFocusNode,
                        enabled: enabled,
                        minLines: 7,
                        maxLines: null,
                        placeholder: Text(l10n.draftMessageHint),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: horizontalPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isSending)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation(
                                      context.colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  l10n.draftSendingStatus,
                                  style: context.textTheme.muted,
                                ),
                              ],
                            ),
                          ),
                        if (showFailure)
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
                              child: Text(l10n.draftDiscard),
                            ).withTapBounce(enabled: canDiscard),
                            const Spacer(),
                            ShadButton.outline(
                              enabled: canSave,
                              onPressed: canSave ? _handleSaveDraft : null,
                              child: Text(l10n.draftSave),
                            ).withTapBounce(enabled: canSave),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
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

  bool _isAxiDestination(String value) {
    final lower = value.toLowerCase();
    final atIndex = lower.indexOf('@');
    if (atIndex == -1) {
      return false;
    }
    final domain = lower.substring(atIndex + 1);
    return domain == 'axi.im' || domain.endsWith('.axi.im');
  }

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
    _revalidateFormIfNeeded();
  }

  void _handleRecipientRemoved(String key) {
    setState(() {
      _recipients.removeWhere((recipient) => recipient.key == key);
    });
    _revalidateFormIfNeeded();
  }

  void _handleRecipientToggled(String key) {
    setState(() {
      final index = _recipients.indexWhere((recipient) => recipient.key == key);
      if (index == -1) return;
      final recipient = _recipients[index];
      _recipients[index] = recipient.copyWith(included: !recipient.included);
    });
    _revalidateFormIfNeeded();
  }

  Future<void> _handleAttachmentAdded() async {
    final l10n = context.l10n;
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
        _showToast(l10n.draftAttachmentInaccessible);
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
      _showToast(error.message ?? l10n.draftAttachmentFailed);
    } on Exception {
      _showToast(l10n.draftAttachmentFailed);
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
    final l10n = context.l10n;
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
      _showValidationMessages = false;
    });
    _showToast(l10n.draftDiscarded);
    widget.onDiscarded?.call();
  }

  Future<void> _handleSendDraft() async {
    final l10n = context.l10n;
    setState(() => _showValidationMessages = true);
    final draftCubit = context.read<DraftCubit?>();
    if (draftCubit == null) return;
    final hasAttachments = _pendingAttachments.isNotEmpty;
    final split = _splitRecipients();
    final xmppJids =
        split.xmppTargets.map(_resolveXmppJid).whereType<String>().toList();
    final emailTargets = split.emailTargets.map((recipient) {
      final chat = recipient.target.chat;
      if (chat != null) {
        final address = _recipientAddress(chat);
        if (address != null && address.isNotEmpty) {
          return FanOutTarget.address(
            address: address,
            displayName: chat.contactDisplayName ?? chat.title,
            shareSignatureEnabled: chat.shareSignatureEnabled,
          );
        }
      }
      return recipient.target;
    }).toList();
    final validationMessage = _sendValidationMessage(
      hasActiveRecipients: split.hasActiveRecipients,
      hasContent: _hasContent(hasAttachments: hasAttachments),
    );
    final formValid = _formKey.currentState?.validate() ?? false;
    if (validationMessage != null || !formValid) {
      if (validationMessage != null) {
        _showToast(validationMessage);
      }
      return;
    }
    if (mounted) {
      setState(() {
        _sendingDraft = true;
        _sendCompletionHandled = false;
        _pendingAttachments = _pendingAttachments
            .map(
              (pending) => pending.copyWith(
                status: PendingAttachmentStatus.uploading,
                clearErrorMessage: true,
              ),
            )
            .toList();
      });
    }
    var succeeded = false;
    try {
      succeeded = await draftCubit.sendDraft(
        id: id,
        xmppJids: xmppJids,
        emailTargets: emailTargets,
        body: _bodyTextController.text,
        l10n: l10n,
        subject: _subjectTextController.text,
        attachments: _currentAttachments(),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sendingDraft = false;
        _sendCompletionHandled = true;
      });
      _showToast(l10n.draftSendFailed);
      return;
    }
    if (!mounted) {
      return;
    }
    if (!succeeded) {
      setState(() {
        _sendingDraft = false;
        _sendCompletionHandled = true;
      });
      _bodyFocusNode.requestFocus();
      return;
    }
    _handleSendComplete();
    if (mounted && !_sendCompletionHandled && _sendingDraft) {
      setState(() => _sendingDraft = false);
    }
  }

  void _handleSendComplete() {
    final l10n = context.l10n;
    if (_sendCompletionHandled) {
      return;
    }
    _sendCompletionHandled = true;
    if (!mounted) return;
    setState(() {
      _sendingDraft = false;
      _pendingAttachments = const [];
      _pendingAttachmentSeed = 0;
    });
    ShadToaster.maybeOf(context)?.show(
      FeedbackToast.success(title: l10n.draftSent),
    );
    final onClosed = widget.onClosed;
    if (onClosed != null) {
      onClosed();
    } else if (Navigator.of(context).canPop()) {
      context.pop();
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
  }) _splitRecipients() {
    final emailTargets = <ComposerRecipient>[];
    final xmppTargets = <ComposerRecipient>[];
    for (final recipient in _recipients) {
      if (!recipient.included) continue;
      final xmppJid = _resolveXmppJid(recipient);
      final isEmailRecipient = _isEmailRecipient(recipient);
      if (isEmailRecipient) {
        emailTargets.add(recipient);
        continue;
      }
      if (xmppJid != null) {
        xmppTargets.add(recipient);
      }
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

  bool _isEmailRecipient(ComposerRecipient recipient) {
    final chat = recipient.target.chat;
    if (chat != null) {
      final address = _recipientAddress(chat);
      return address != null && !_isAxiDestination(address);
    }
    final normalizedAddress = recipient.target.normalizedAddress;
    final rawAddress = recipient.target.address;
    final candidate = normalizedAddress ?? rawAddress?.trim();
    if (candidate == null || candidate.isEmpty) {
      return false;
    }
    return !_isAxiDestination(candidate);
  }

  String? _recipientAddress(Chat chat) {
    final email = chat.emailAddress?.trim();
    if (email?.isNotEmpty == true) {
      return email;
    }
    return chat.jid;
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

  bool _hasContent({required bool hasAttachments}) {
    return _bodyTextController.text.trim().isNotEmpty ||
        _subjectTextController.text.trim().isNotEmpty ||
        hasAttachments ||
        _pendingAttachments.any(
          (attachment) => attachment.status == PendingAttachmentStatus.queued,
        );
  }

  String? _sendValidationMessage({
    required bool hasActiveRecipients,
    required bool hasContent,
  }) {
    if (!hasActiveRecipients) {
      return context.l10n.draftNoRecipients;
    }
    if (!hasContent) {
      return context.l10n.draftValidationNoContent;
    }
    return null;
  }

  void _revalidateFormIfNeeded() {
    if (!_showValidationMessages) return;
    _formKey.currentState?.validate();
  }

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
    final l10n = context.l10n;
    if (!mounted) return;
    final attachment = pending.attachment;
    final file = File(attachment.path);
    if (!await file.exists()) {
      _showToast(l10n.draftFileMissing(attachment.path));
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
                child: AxiIconButton(
                  iconData: LucideIcons.x,
                  tooltip: l10n.commonClose,
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
    final l10n = context.l10n;
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
                    title: Text(l10n.draftAttachmentPreview),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _showAttachmentPreview(pending);
                    },
                  ),
                ListTile(
                  leading: const Icon(LucideIcons.trash2),
                  title: Text(l10n.draftRemoveAttachment),
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

class _DraftTaskDropRegion extends StatefulWidget {
  const _DraftTaskDropRegion({
    required this.child,
    this.onTaskDropped,
  });

  final Widget child;
  final ValueChanged<CalendarDragPayload>? onTaskDropped;

  @override
  State<_DraftTaskDropRegion> createState() => _DraftTaskDropRegionState();
}

class _DraftTaskDropRegionState extends State<_DraftTaskDropRegion> {
  CalendarDragPayload? _hoverPayload;
  Offset? _localPosition;

  RenderBox? get _box => context.findRenderObject() as RenderBox?;

  void _updateHover(DragTargetDetails<CalendarDragPayload> details) {
    final RenderBox? box = _box;
    final Offset local =
        box != null ? box.globalToLocal(details.offset) : details.offset;
    setState(() {
      _hoverPayload = details.data;
      _localPosition = local;
    });
  }

  void _handleLeave(CalendarDragPayload? payload) {
    if (_hoverPayload == null) {
      return;
    }
    setState(() {
      _hoverPayload = null;
      _localPosition = null;
    });
  }

  void _handleDrop(DragTargetDetails<CalendarDragPayload> details) {
    widget.onTaskDropped?.call(details.data);
    _handleLeave(details.data);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTaskDropped == null) {
      return widget.child;
    }
    final colors = context.colorScheme;
    final borderRadius = context.radius;
    return DragTarget<CalendarDragPayload>(
      hitTestBehavior: HitTestBehavior.translucent,
      onWillAcceptWithDetails: (details) {
        _updateHover(details);
        return true;
      },
      onMove: _updateHover,
      onAcceptWithDetails: _handleDrop,
      onLeave: _handleLeave,
      builder: (context, candidates, __) {
        final hovering = candidates.isNotEmpty || _hoverPayload != null;
        final payload = _hoverPayload;
        final Offset? anchor = _localPosition;
        final RenderBox? box = _box;
        final Size? regionSize = box?.size;
        final Widget highlight = AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            border: Border.all(
              color: hovering ? colors.primary : Colors.transparent,
              width: 1.5,
            ),
            borderRadius: borderRadius,
            color: hovering ? colors.primary.withValues(alpha: 0.04) : null,
          ),
          child: widget.child,
        );
        if (payload == null || anchor == null || regionSize == null) {
          return highlight;
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            highlight,
            _TaskDragGhostOverlay(
              payload: payload,
              anchor: anchor,
              regionSize: regionSize,
            ),
          ],
        );
      },
    );
  }
}

class _TaskDragGhostOverlay extends StatelessWidget {
  const _TaskDragGhostOverlay({
    required this.payload,
    required this.anchor,
    required this.regionSize,
  });

  final CalendarDragPayload payload;
  final Offset anchor;
  final Size regionSize;
  static const double _defaultGhostWidth = 240;
  static const double _defaultGhostHeight = 84;
  static const double _minGhostWidth = 180;
  static const double _maxGhostWidth = 360;
  static const double _minGhostHeight = 64;
  static const double _maxGhostHeight = 180;
  static const double _pointerClampPadding = 0.25;

  Size _ghostSize() {
    final double width = payload.sourceBounds?.width ?? _defaultGhostWidth;
    final double height = payload.sourceBounds?.height ?? _defaultGhostHeight;
    return Size(
      width.clamp(_minGhostWidth, _maxGhostWidth),
      height.clamp(_minGhostHeight, _maxGhostHeight),
    );
  }

  Offset _ghostOffset(Size ghostSize) {
    final double pointerFraction =
        (payload.pointerNormalizedX ?? 0.5).clamp(0.0, 1.0).toDouble();
    final double pointerOffsetY =
        (payload.pointerOffsetY ?? (ghostSize.height / 2))
            .clamp(0.0, ghostSize.height)
            .toDouble();
    double left = anchor.dx - (ghostSize.width * pointerFraction);
    double top = anchor.dy - pointerOffsetY;
    final double minLeft = -ghostSize.width * _pointerClampPadding;
    final double maxLeft =
        regionSize.width - (ghostSize.width * (1 - _pointerClampPadding));
    final double minTop = -ghostSize.height * _pointerClampPadding;
    final double maxTop =
        regionSize.height - (ghostSize.height * _pointerClampPadding);
    left = left.clamp(minLeft, maxLeft);
    top = top.clamp(minTop, maxTop);
    return Offset(left, top);
  }

  @override
  Widget build(BuildContext context) {
    final Size ghostSize = _ghostSize();
    final Offset offset = _ghostOffset(ghostSize);
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: IgnorePointer(
        child: _DraftTaskDragGhost(
          payload: payload,
          size: ghostSize,
        ),
      ),
    );
  }
}

class _DraftTaskDragGhost extends StatelessWidget {
  const _DraftTaskDragGhost({
    required this.payload,
    required this.size,
  });

  final CalendarDragPayload payload;
  final Size size;

  String _timingLabel(BuildContext context) {
    final CalendarTask task = payload.snapshot;
    final DateTime? start = task.scheduledTime;
    final DateTime? deadline = task.deadline;
    final l10n = context.l10n;
    if (start != null) {
      return TimeFormatter.formatFriendlyDateTime(start);
    }
    if (deadline != null) {
      return l10n.draftTaskDue(TimeFormatter.formatFriendlyDateTime(deadline));
    }
    return l10n.draftTaskNoSchedule;
  }

  @override
  Widget build(BuildContext context) {
    final CalendarTask task = payload.snapshot;
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final materialScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final String title =
        task.title.trim().isEmpty ? l10n.draftTaskUntitled : task.title.trim();
    final String? description = task.description?.trim().isNotEmpty == true
        ? task.description!.trim()
        : null;
    final borderRadius = context.radius;
    return Material(
      color: Colors.transparent,
      elevation: 8,
      borderRadius: borderRadius,
      child: Container(
        width: size.width,
        constraints: BoxConstraints(minHeight: size.height),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.card.withValues(alpha: 0.96),
          borderRadius: borderRadius,
          border: Border.all(
            color: colors.primary,
            width: 1.25,
          ),
          boxShadow: [
            BoxShadow(
              color: materialScheme.shadow.withValues(alpha: 0.14),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.small.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.foreground,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.calendarClock,
                  size: 14,
                  color: colors.primary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _timingLabel(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.muted.copyWith(
                      color: colors.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.muted.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DraftSendIconButton extends StatelessWidget {
  const _DraftSendIconButton({
    required this.readyToSend,
    required this.sending,
    this.disabledReason,
    required this.onPressed,
  });

  final bool readyToSend;
  final bool sending;
  final String? disabledReason;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final disabledColor = colors.mutedForeground.withValues(alpha: 0.9);
    final iconColor = sending
        ? disabledColor
        : readyToSend
            ? colors.primary
            : disabledColor;
    final borderColor =
        sending || !readyToSend ? colors.border : colors.primary;
    final tooltip =
        sending ? l10n.draftSendingEllipsis : disabledReason ?? l10n.draftSend;
    final interactive = onPressed != null && !sending;
    return _DraftComposerIconButton(
      tooltip: tooltip,
      icon: LucideIcons.send,
      onPressed: interactive ? onPressed : null,
      iconColorOverride: iconColor,
      borderColorOverride: borderColor,
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
    final l10n = context.l10n;
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
            child: Text(l10n.draftAttachmentPreview),
          ),
        );
      }
      items.add(
        ShadContextMenuItem(
          leading: const Icon(LucideIcons.trash2),
          onPressed: () => onRemove(pending.id),
          child: Text(l10n.draftRemoveAttachment),
        ),
      );
      return items;
    }

    Widget body;
    if (loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (attachments.isEmpty) {
      body = Text(
        l10n.draftNoAttachments,
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
            Text(l10n.draftAttachmentsLabel),
            const Spacer(),
            _DraftComposerIconButton(
              tooltip: l10n.draftAddAttachment,
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
    return AxiIconButton(
      iconData: icon,
      tooltip: tooltip,
      semanticLabel: tooltip,
      onPressed: onPressed,
      color: iconColor,
      backgroundColor: colors.card,
      borderColor: borderColor,
      borderWidth: 1.4,
      cornerRadius: 16,
      buttonSize: _draftComposerControlExtent,
      tapTargetSize: _draftComposerControlExtent,
      iconSize: 24,
    );
  }
}
