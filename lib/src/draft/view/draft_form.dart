// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

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
import 'package:axichat/src/common/draft_limits.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/file_type_detector.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/models/draft_save_result.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/chats/view/widgets/transport_aware_avatar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
    required this.locate,
    this.onClosed,
    this.onDiscarded,
    this.onDraftSaved,
  });

  final int? id;
  final List<String> jids;
  final String body;
  final String subject;
  final List<String> attachmentMetadataIds;
  final Set<String> suggestionAddresses;
  final Set<String> suggestionDomains;
  final T Function<T>() locate;
  final VoidCallback? onClosed;
  final VoidCallback? onDiscarded;
  final ValueChanged<int>? onDraftSaved;

  @override
  State<DraftForm> createState() => _DraftFormState();
}

class _DraftFormState extends State<DraftForm> {
  final _formKey = GlobalKey<FormState>();
  bool _showValidationMessages = false;
  String? _sendErrorMessage;
  late final TextEditingController _bodyTextController;
  late final TextEditingController _subjectTextController;
  late final FocusNode _bodyFocusNode;
  late final FocusNode _subjectFocusNode;
  late List<ComposerRecipient> _recipients;
  late List<PendingAttachment> _pendingAttachments;
  bool _recipientsInitialized = false;
  bool _hydrationScheduled = false;

  late var id = widget.id;
  bool _loadingAttachments = false;
  bool _addingAttachment = false;
  int _pendingAttachmentSeed = 0;
  bool _sendingDraft = false;
  bool _savingDraft = false;
  bool _discardingDraft = false;
  bool _sendCompletionHandled = false;
  bool _seedAttachmentCleanupHandled = false;
  Timer? _autosaveTimer;
  int? _lastSavedSignature;
  DateTime? _lastAutosaveAt;
  bool _autosaveInFlight = false;
  int _saveEpoch = 0;

  @override
  void initState() {
    super.initState();
    _bodyTextController = TextEditingController(text: widget.body)
      ..addListener(_bodyListener);
    _subjectTextController = TextEditingController(text: widget.subject)
      ..addListener(_subjectListener);
    _bodyFocusNode = FocusNode();
    _subjectFocusNode = FocusNode();
    _pendingAttachments = const [];
    _recipients = const [];
  }

  @override
  void didUpdateWidget(covariant DraftForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newId = widget.id;
    if (newId != null && newId != id) {
      id = newId;
    }
  }

  @override
  void dispose() {
    if (_shouldCleanupSeedAttachments) {
      unawaited(
        _cleanupSeedAttachmentMetadata(widget.locate<DraftCubit>()),
      );
    }
    _autosaveTimer?.cancel();
    _bodyTextController.removeListener(_bodyListener);
    _bodyTextController.dispose();
    _subjectTextController.removeListener(_subjectListener);
    _subjectTextController.dispose();
    _bodyFocusNode.dispose();
    _subjectFocusNode.dispose();
    super.dispose();
  }

  bool get _shouldCleanupSeedAttachments =>
      !_seedAttachmentCleanupHandled &&
      id == null &&
      widget.attachmentMetadataIds.isNotEmpty;

  void _bodyListener() {
    if (!mounted) {
      return;
    }
    setState(() => _sendErrorMessage = null);
    _scheduleAutosave();
  }

  void _subjectListener() {
    if (!mounted) {
      return;
    }
    setState(() => _sendErrorMessage = null);
    _scheduleAutosave();
  }

  void _appendTaskShareText(CalendarTask task) {
    final String shareText = task.toShareText(context.l10n);
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrationScheduled || widget.attachmentMetadataIds.isEmpty) {
      return;
    }
    _hydrationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _hydrateAttachments();
    });
  }

  void _handleTaskDrop(CalendarDragPayload payload) {
    _appendTaskShareText(payload.snapshot);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final endpointConfig = context.watch<SettingsCubit>().state.endpointConfig;
    final locate = widget.locate;
    final horizontalPadding = EdgeInsets.symmetric(horizontal: spacing.m);
    final sectionSpacing = spacing.s + spacing.xs;
    final smallGap = spacing.xs + spacing.xxs;
    final inputPadding = EdgeInsets.symmetric(
      horizontal: spacing.s,
      vertical: spacing.xs,
    );
    final subjectHeight = sizing.buttonHeightRegular;

    return BlocBuilder<ProfileCubit, ProfileState>(
      bloc: locate<ProfileCubit>(),
      builder: (context, profileState) {
        final profileJid = profileState.jid;
        final resolvedProfileJid = profileJid.trim();
        final String? selfJid =
            resolvedProfileJid.isNotEmpty ? resolvedProfileJid : null;
        final selfIdentity = SelfIdentitySnapshot(
          selfJid: selfJid,
          avatarPath: profileState.avatarPath,
        );
        return BlocBuilder<RosterCubit, RosterState>(
          bloc: locate<RosterCubit>(),
          builder: (context, rosterState) {
            final rosterItems = rosterState.items ?? const <RosterItem>[];
            return BlocBuilder<ChatsCubit, ChatsState>(
              bloc: locate<ChatsCubit>(),
              builder: (context, chatsState) {
                final chats = chatsState.items ?? const <Chat>[];
                _scheduleRecipientsInitialization(chats);
                final autovalidateMode = _showValidationMessages
                    ? AutovalidateMode.always
                    : AutovalidateMode.disabled;
                return SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: Form(
                    key: _formKey,
                    autovalidateMode: autovalidateMode,
                    child: BlocConsumer<DraftCubit, DraftState>(
                      bloc: locate<DraftCubit>(),
                      listener: (context, state) async {
                        if (state is DraftSaveComplete) {
                          if (!state.autoSaved) {
                            ShadToaster.maybeOf(
                              context,
                            )?.show(
                                FeedbackToast.success(title: l10n.draftSaved));
                          }
                        }
                        if (state is DraftSending) {
                          if (_sendingDraft && mounted) {
                            setState(() {
                              _sendErrorMessage = null;
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
                              _sendErrorMessage =
                                  _draftFailureMessage(state.type, l10n);
                              _pendingAttachments = _pendingAttachments
                                  .map(
                                    (pending) => pending.copyWith(
                                      status: PendingAttachmentStatus.queued,
                                      clearErrorMessage: true,
                                    ),
                                  )
                                  .toList();
                            });
                          }
                        } else if (state is DraftSendComplete) {
                          await _handleSendComplete();
                        }
                      },
                      builder: (context, state) {
                        final isSending =
                            state is DraftSending && _sendingDraft;
                        final enabled =
                            !isSending && !_savingDraft && !_discardingDraft;
                        final bodyText = _bodyTextController.text.trim();
                        final subjectText = _subjectTextController.text.trim();
                        final pendingAttachments = _pendingAttachments;
                        final hasAttachments = pendingAttachments.isNotEmpty;
                        final hasPreparingAttachments = pendingAttachments.any(
                          (pending) => pending.isPreparing,
                        );
                        final split = _splitRecipients();
                        final hasActiveRecipients = split.hasActiveRecipients;
                        final hasContent =
                            _hasContent(hasAttachments: hasAttachments);
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
                          emailRecipientsUnavailable:
                              !endpointConfig.enableSmtp &&
                                  split.emailTargets.isNotEmpty,
                        );
                        final bool showSendBlockerMessage =
                            _showValidationMessages &&
                                sendBlocker != null &&
                                sendBlocker != l10n.draftNoRecipients;
                        final String? sendErrorMessage = _sendErrorMessage;
                        final readyToSend = sendBlocker == null &&
                            !_addingAttachment &&
                            !hasPreparingAttachments;
                        final bool showAutosaveHint = _lastAutosaveAt != null &&
                            _lastSavedSignature == _currentDraftSignature();
                        return _DraftTaskDropRegion(
                          onTaskDropped: enabled ? _handleTaskDrop : null,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FormField<void>(
                                validator: (_) => hasActiveRecipients
                                    ? null
                                    : l10n.draftNoRecipients,
                                builder: (field) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      RecipientChipsBar(
                                        recipients: _recipients,
                                        availableChats: chats,
                                        rosterItems: rosterItems,
                                        recipientSuggestionsStream: locate<
                                                ChatsCubit>()
                                            .recipientAddressSuggestionsStream(),
                                        selfJid: locate<ChatsCubit>().selfJid,
                                        selfIdentity: selfIdentity,
                                        onRecipientAdded: (target) {
                                          _handleRecipientAdded(target).then(
                                            (added) {
                                              if (!mounted || !added) return;
                                              field.didChange(null);
                                            },
                                          );
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
                                        suggestionAddresses:
                                            widget.suggestionAddresses,
                                        suggestionDomains:
                                            widget.suggestionDomains,
                                      ),
                                      if (_showValidationMessages &&
                                          field.hasError)
                                        Padding(
                                          padding:
                                              EdgeInsets.only(top: spacing.s),
                                          child: Text(
                                            field.errorText ?? '',
                                            style: textTheme.small.copyWith(
                                              color: colors.destructive,
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                              SizedBox(height: sectionSpacing),
                              Padding(
                                padding: horizontalPadding,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Semantics(
                                            label: l10n.draftSubjectSemantics,
                                            textField: true,
                                            child: AxiTextFormField(
                                              controller:
                                                  _subjectTextController,
                                              focusNode: _subjectFocusNode,
                                              enabled: enabled,
                                              minLines: 1,
                                              maxLines: 1,
                                              textInputAction:
                                                  TextInputAction.next,
                                              onSubmitted: (_) =>
                                                  _bodyFocusNode.requestFocus(),
                                              placeholder: Text(
                                                l10n.draftSubjectHintOptional,
                                              ),
                                              constraints:
                                                  BoxConstraints.tightFor(
                                                height: subjectHeight,
                                              ),
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              placeholderAlignment:
                                                  Alignment.centerLeft,
                                              inputPadding: inputPadding,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: sectionSpacing),
                                        _DraftSendIconButton(
                                          readyToSend: readyToSend,
                                          sending: isSending,
                                          disabledReason: sendBlocker,
                                          onPressed: isSending ||
                                                  _addingAttachment ||
                                                  hasPreparingAttachments
                                              ? null
                                              : _handleSendDraft,
                                        ),
                                      ],
                                    ),
                                    if (showSendBlockerMessage)
                                      Padding(
                                        padding:
                                            EdgeInsets.only(top: spacing.s),
                                        child: Text(
                                          sendBlocker,
                                          style: textTheme.small.copyWith(
                                            color: colors.destructive,
                                          ),
                                        ),
                                      ),
                                    if (sendErrorMessage != null &&
                                        sendBlocker == null)
                                      Padding(
                                        padding:
                                            EdgeInsets.only(top: spacing.s),
                                        child: Text(
                                          sendErrorMessage,
                                          style: textTheme.small.copyWith(
                                            color: colors.destructive,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              SizedBox(height: sectionSpacing),
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
                                  onAttachmentPressed:
                                      _handlePendingAttachmentPressed,
                                  onAttachmentLongPressed:
                                      _handlePendingAttachmentLongPressed,
                                  onPreview: _showAttachmentPreview,
                                ),
                              ),
                              SizedBox(height: sectionSpacing),
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
                              SizedBox(height: sectionSpacing),
                              Padding(
                                padding: horizontalPadding,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (isSending)
                                      Padding(
                                        padding:
                                            EdgeInsets.only(bottom: spacing.s),
                                        child: Row(
                                          children: [
                                            AxiProgressIndicator(
                                              color: colors.primary,
                                            ),
                                            SizedBox(width: smallGap),
                                            Text(
                                              l10n.draftSendingStatus,
                                              style: textTheme.muted,
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (showAutosaveHint)
                                      Padding(
                                        padding:
                                            EdgeInsets.only(bottom: spacing.s),
                                        child: Text(
                                          l10n.draftAutosaved,
                                          style: textTheme.muted,
                                        ),
                                      ),
                                    Row(
                                      children: [
                                        AxiButton.destructive(
                                          onPressed: canDiscard
                                              ? _handleDiscard
                                              : null,
                                          child: Text(l10n.draftDiscard),
                                        ),
                                        const Spacer(),
                                        AxiButton.outline(
                                          onPressed:
                                              canSave ? _handleSaveDraft : null,
                                          child: Text(l10n.draftSave),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: sectionSpacing),
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
              },
            );
          },
        );
      },
    );
  }

  void _scheduleRecipientsInitialization(List<Chat> chats) {
    if (_recipientsInitialized) return;
    _recipientsInitialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _recipients = _initialRecipients(chats));
    });
  }

  List<ComposerRecipient> _initialRecipients(List<Chat> chats) {
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
          ComposerRecipient(
            target: FanOutTarget.chat(
              chat: match,
              shareSignatureEnabled: match.shareSignatureEnabled ??
                  widget
                      .locate<SettingsCubit>()
                      .state
                      .shareTokenSignatureEnabled,
            ),
          ),
        );
      } else {
        recipients.add(
          ComposerRecipient(
            target: FanOutTarget.address(
              address: trimmed,
              shareSignatureEnabled: widget
                  .locate<SettingsCubit>()
                  .state
                  .shareTokenSignatureEnabled,
            ),
          ),
        );
      }
    }
    return recipients;
  }

  Future<void> _hydrateAttachments() async {
    if (widget.attachmentMetadataIds.isEmpty) {
      return;
    }
    setState(() => _loadingAttachments = true);
    try {
      final pending = await _pendingAttachmentsFromMetadata(
        widget.attachmentMetadataIds,
      );
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
    final hydrated = await widget
        .locate<DraftCubit>()
        .loadDraftAttachments(metadataIds.toList());
    final List<PendingAttachment> pending = <PendingAttachment>[];
    for (final attachment in hydrated) {
      final EmailAttachment resolvedAttachment =
          await _resolveAttachmentMimeType(attachment);
      pending.add(
        PendingAttachment(
          id: resolvedAttachment.metadataId ?? _nextPendingAttachmentId(),
          attachment: resolvedAttachment,
        ),
      );
    }
    return pending;
  }

  Future<EmailAttachment> _resolveAttachmentMimeType(
    EmailAttachment attachment,
  ) async {
    final String? resolvedMimeType = await resolveMimeTypeFromPath(
      path: attachment.path,
      fileName: attachment.fileName,
      declaredMimeType: attachment.mimeType,
    );
    if (resolvedMimeType == null || resolvedMimeType == attachment.mimeType) {
      return attachment;
    }
    return attachment.copyWith(mimeType: resolvedMimeType);
  }

  Future<bool> _handleRecipientAdded(FanOutTarget target) async {
    final address = target.address?.trim();
    if (target.chat == null &&
        target.transport == null &&
        address != null &&
        address.isNotEmpty) {
      final transport = await _resolveAddressTransport(address);
      if (!mounted || transport == null) return false;
      final resolved = FanOutTarget.address(
        address: address,
        displayName: target.displayName,
        shareSignatureEnabled: target.shareSignatureEnabled,
        transport: transport,
      );
      _applyRecipient(resolved);
      return true;
    }
    _applyRecipient(target);
    return true;
  }

  Future<bool> _ensureRecipientTransports() async {
    final nextRecipients = List<ComposerRecipient>.from(_recipients);
    var updated = false;
    for (var index = 0; index < nextRecipients.length; index++) {
      final recipient = nextRecipients[index];
      if (!recipient.included) continue;
      if (recipient.target.chat != null) continue;
      if (recipient.target.transport != null) continue;
      final address = recipient.target.address?.trim();
      if (address == null || address.isEmpty) continue;
      final transport = await _resolveAddressTransport(address);
      if (!mounted || transport == null) return false;
      nextRecipients[index] = recipient.copyWith(
        target: FanOutTarget.address(
          address: address,
          displayName: recipient.target.displayName,
          shareSignatureEnabled: recipient.target.shareSignatureEnabled,
          transport: transport,
        ),
      );
      updated = true;
    }
    if (updated && mounted) {
      setState(() => _recipients = nextRecipients);
    }
    return true;
  }

  void _applyRecipient(FanOutTarget target) {
    setState(() {
      _sendErrorMessage = null;
      final existingIndex = _recipients.indexWhere(
        (recipient) => recipient.key == target.key,
      );
      if (existingIndex >= 0) {
        _recipients[existingIndex] = _recipients[existingIndex].copyWith(
          target: target,
          included: true,
        );
      } else {
        _recipients.add(ComposerRecipient(target: target));
      }
    });
    _revalidateFormIfNeeded();
    _scheduleAutosave();
  }

  Future<MessageTransport?> _resolveAddressTransport(String address) async {
    final endpointConfig = widget.locate<SettingsCubit>().state.endpointConfig;
    final supportsEmail = endpointConfig.enableSmtp;
    final supportsXmpp = endpointConfig.enableXmpp;
    if (supportsEmail && !supportsXmpp) {
      return MessageTransport.email;
    }
    if (!supportsEmail && supportsXmpp) {
      return MessageTransport.xmpp;
    }
    if (!supportsEmail && !supportsXmpp) {
      return null;
    }
    final hinted = hintTransportForAddress(address);
    return showTransportChoiceDialog(
      context,
      address: address,
      defaultTransport: hinted,
    );
  }

  void _handleRecipientRemoved(String key) {
    setState(() {
      _sendErrorMessage = null;
      _recipients.removeWhere((recipient) => recipient.key == key);
    });
    _revalidateFormIfNeeded();
    _scheduleAutosave();
  }

  void _handleRecipientToggled(String key) {
    setState(() {
      _sendErrorMessage = null;
      final index = _recipients.indexWhere((recipient) => recipient.key == key);
      if (index == -1) return;
      final recipient = _recipients[index];
      _recipients[index] = recipient.copyWith(included: !recipient.included);
    });
    _revalidateFormIfNeeded();
    _scheduleAutosave();
  }

  Future<void> _handleAttachmentAdded() async {
    if (_addingAttachment) return;
    setState(() => _addingAttachment = true);
    final attachmentInaccessibleMessage =
        context.l10n.draftAttachmentInaccessible;
    final attachmentFailedMessage = context.l10n.draftAttachmentFailed;
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
        if (!mounted) return;
        _showToast(attachmentInaccessibleMessage);
        return;
      }
      final pendingId = _nextPendingAttachmentId();
      final fileName = file.name.isNotEmpty ? file.name : path.split('/').last;
      var attachment = EmailAttachment(
        path: path,
        fileName: fileName,
        sizeBytes: file.size > 0 ? file.size : 0,
      );
      setState(() {
        _pendingAttachments = [
          ..._pendingAttachments,
          PendingAttachment(
            id: pendingId,
            attachment: attachment,
            isPreparing: true,
          ),
        ];
      });

      final String? resolvedMimeType = await resolveMimeTypeFromPath(
        path: path,
        fileName: fileName,
      );
      if (!mounted) return;
      attachment = attachment.copyWith(mimeType: resolvedMimeType);
      if (attachment.sizeBytes <= 0) {
        try {
          final resolvedSize = await File(path).length();
          if (!mounted) return;
          attachment = attachment.copyWith(sizeBytes: resolvedSize);
        } on Exception {
          // Best-effort. Keep placeholder size until optimization completes.
        }
      }
      if (!mounted) return;
      attachment =
          await widget.locate<DraftCubit>().optimizeAttachment(attachment);
      if (!mounted) return;
      setState(() {
        _pendingAttachments = _pendingAttachments
            .map(
              (pending) => pending.id == pendingId
                  ? pending.copyWith(attachment: attachment, isPreparing: false)
                  : pending,
            )
            .toList();
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _pendingAttachments = _pendingAttachments
            .where((pending) => !pending.isPreparing)
            .toList();
      });
      _showToast(error.message ?? attachmentFailedMessage);
    } on Exception {
      if (!mounted) return;
      setState(() {
        _pendingAttachments = _pendingAttachments
            .where((pending) => !pending.isPreparing)
            .toList();
      });
      _showToast(attachmentFailedMessage);
    } finally {
      if (mounted) {
        setState(() => _addingAttachment = false);
      }
      _scheduleAutosave();
    }
  }

  void _handlePendingAttachmentRemoved(String id) {
    setState(() {
      _pendingAttachments =
          _pendingAttachments.where((pending) => pending.id != id).toList();
    });
    _scheduleAutosave();
  }

  Future<void> _handleSaveDraft() async {
    if (_savingDraft) return;
    setState(() => _savingDraft = true);
    try {
      await _saveDraft(autoSave: false);
    } finally {
      if (mounted) {
        setState(() => _savingDraft = false);
      }
    }
  }

  Future<void> _saveDraft({required bool autoSave}) async {
    final int saveEpoch = _saveEpoch;
    final bool wasNewDraft = id == null;
    final List<String> attachmentIds =
        _pendingAttachments.map((pending) => pending.id).toList();
    final List<String> recipients = _recipientStrings();
    final DraftSaveResult result = await widget.locate<DraftCubit>().saveDraft(
          id: id,
          jids: recipients,
          body: _bodyTextController.text,
          subject: _subjectTextController.text,
          attachments: _currentAttachments(),
          autoSave: autoSave,
        );
    if (!mounted || saveEpoch != _saveEpoch) return;
    final int signature = _draftSignature(
      recipients: recipients,
      body: _bodyTextController.text,
      subject: _subjectTextController.text,
      pendingAttachments: _pendingAttachments,
    );
    setState(() {
      id = result.draftId;
      _lastSavedSignature = signature;
      _lastAutosaveAt = autoSave ? DateTime.now() : null;
    });
    widget.onDraftSaved?.call(result.draftId);
    if (!autoSave &&
        wasNewDraft &&
        result.draftCount >= draftSyncWarningThreshold) {
      ShadToaster.maybeOf(context)?.show(
        FeedbackToast.warning(
          message: context.l10n.draftLimitWarning(
            draftSyncMaxItems,
            result.draftCount,
          ),
        ),
      );
    }
    await _applyAttachmentMetadataIds(
      metadataIds: result.attachmentMetadataIds,
      expectedAttachmentIds: attachmentIds,
    );
    if (!mounted) return;
    if (wasNewDraft && widget.attachmentMetadataIds.isNotEmpty) {
      final Set<String> retainedMetadataIds =
          result.attachmentMetadataIds.toSet();
      final List<String> staleMetadataIds = widget.attachmentMetadataIds
          .where((metadataId) => !retainedMetadataIds.contains(metadataId))
          .toList();
      if (staleMetadataIds.isNotEmpty) {
        for (final metadataId in staleMetadataIds) {
          try {
            await context
                .read<DraftCubit>()
                .deleteDraftAttachmentMetadata(metadataId);
          } on Exception {
            // Best-effort cleanup for share intent attachment metadata.
          }
        }
      }
      _seedAttachmentCleanupHandled = true;
    }
  }

  void _scheduleAutosave() {
    if (_sendingDraft || _savingDraft || _discardingDraft) {
      return;
    }
    if (_addingAttachment) {
      return;
    }
    _autosaveTimer?.cancel();
    const delay = Duration(seconds: 2);
    _autosaveTimer = Timer(delay, _handleAutosaveTick);
  }

  void _invalidatePendingSaves() {
    _saveEpoch += 1;
  }

  Future<void> _handleAutosaveTick() async {
    if (!mounted || _autosaveInFlight) {
      return;
    }
    if (!_shouldAutosave()) {
      return;
    }
    final int signature = _currentDraftSignature();
    if (_lastSavedSignature == signature) {
      return;
    }
    _autosaveInFlight = true;
    try {
      await _saveDraft(autoSave: true);
    } on Exception {
      // Best-effort autosave should not block composition.
    } finally {
      _autosaveInFlight = false;
    }
  }

  bool _shouldAutosave() {
    if (_pendingAttachments.any((pending) => pending.isPreparing)) {
      return false;
    }
    final String body = _bodyTextController.text.trim();
    final String subject = _subjectTextController.text.trim();
    final bool hasAttachments = _pendingAttachments.isNotEmpty;
    final bool hasRecipients = _recipientStrings().isNotEmpty;
    return hasRecipients ||
        body.isNotEmpty ||
        subject.isNotEmpty ||
        hasAttachments;
  }

  int _currentDraftSignature() {
    return _draftSignature(
      recipients: _recipientStrings(),
      body: _bodyTextController.text,
      subject: _subjectTextController.text,
      pendingAttachments: _pendingAttachments,
    );
  }

  int _draftSignature({
    required List<String> recipients,
    required String body,
    required String subject,
    required List<PendingAttachment> pendingAttachments,
  }) {
    final List<Object?> values = <Object?>[
      body,
      subject,
      ...recipients,
      ...pendingAttachments.map(
        (pending) => _attachmentSignature(pending.attachment),
      ),
    ];
    return Object.hashAll(values);
  }

  Object _attachmentSignature(EmailAttachment attachment) {
    final String? metadataId = attachment.metadataId;
    if (metadataId != null && metadataId.isNotEmpty) {
      return metadataId;
    }
    return Object.hash(
      attachment.path,
      attachment.fileName,
      attachment.sizeBytes,
      attachment.mimeType,
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
    final bool shouldCleanupSeedAttachments = _shouldCleanupSeedAttachments;
    if (_discardingDraft) return;
    setState(() => _discardingDraft = true);
    _autosaveTimer?.cancel();
    _invalidatePendingSaves();
    try {
      if (id != null) {
        await widget.locate<DraftCubit>().deleteDraft(id: id!);
      }
      if (!mounted) return;
      if (shouldCleanupSeedAttachments) {
        await _cleanupSeedAttachmentMetadata(widget.locate<DraftCubit>());
      }
      if (!mounted) return;
      setState(() {
        id = null;
        _recipients = [];
        _recipientsInitialized = false;
        _pendingAttachments = const [];
        _bodyTextController.clear();
        _subjectTextController.clear();
        _showValidationMessages = false;
        _lastAutosaveAt = null;
        _lastSavedSignature = null;
      });
      _showToast(context.l10n.draftDiscarded);
      widget.onDiscarded?.call();
    } finally {
      if (mounted) {
        setState(() => _discardingDraft = false);
      }
    }
  }

  Future<void> _cleanupSeedAttachmentMetadata(
    DraftCubit draftCubit,
  ) async {
    if (!_shouldCleanupSeedAttachments) {
      return;
    }
    _seedAttachmentCleanupHandled = true;
    final List<String> metadataIds = widget.attachmentMetadataIds;
    if (metadataIds.isEmpty) {
      return;
    }
    for (final metadataId in metadataIds) {
      try {
        await draftCubit.deleteDraftAttachmentMetadata(metadataId);
      } on Exception {
        // Best-effort cleanup for share intent attachment metadata.
      }
    }
  }

  Future<void> _handleSendDraft() async {
    _autosaveTimer?.cancel();
    _invalidatePendingSaves();
    setState(() {
      _showValidationMessages = true;
      _sendErrorMessage = null;
    });
    if (_addingAttachment ||
        _pendingAttachments.any((pending) => pending.isPreparing)) {
      return;
    }
    final transportsReady = await _ensureRecipientTransports();
    if (!mounted) return;
    if (!transportsReady) return;
    final hasAttachments = _pendingAttachments.isNotEmpty;
    final split = _splitRecipients();
    final endpointConfig = context.read<SettingsCubit>().state.endpointConfig;
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
            shareSignatureEnabled: chat.shareSignatureEnabled ??
                widget.locate<SettingsCubit>().state.shareTokenSignatureEnabled,
          );
        }
      }
      return recipient.target;
    }).toList();
    final validationMessage = _sendValidationMessage(
      hasActiveRecipients: split.hasActiveRecipients,
      hasContent: _hasContent(hasAttachments: hasAttachments),
      emailRecipientsUnavailable:
          !endpointConfig.enableSmtp && split.emailTargets.isNotEmpty,
    );
    final formValid = _formKey.currentState?.validate() ?? false;
    if (validationMessage != null || !formValid) return;
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
      succeeded = await widget.locate<DraftCubit>().sendDraft(
            id: id,
            xmppJids: xmppJids,
            emailTargets: emailTargets,
            body: _bodyTextController.text,
            subject: _subjectTextController.text,
            attachments: _currentAttachments(),
          );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sendingDraft = false;
        _sendCompletionHandled = true;
      });
      _showToast(context.l10n.draftSendFailed);
      return;
    }
    if (!mounted || !succeeded) {
      if (mounted && succeeded == false) {
        setState(() {
          _sendingDraft = false;
          _sendCompletionHandled = true;
        });
        _bodyFocusNode.requestFocus();
      }
      return;
    }
    await _handleSendComplete();
    if (mounted && !_sendCompletionHandled && _sendingDraft) {
      setState(() => _sendingDraft = false);
    }
  }

  Future<void> _handleSendComplete() async {
    if (_sendCompletionHandled) {
      return;
    }
    _sendCompletionHandled = true;
    if (!mounted) return;
    final bool shouldCleanupSeedAttachments = _shouldCleanupSeedAttachments;
    setState(() {
      _sendingDraft = false;
      _pendingAttachments = const [];
      _pendingAttachmentSeed = 0;
      _lastAutosaveAt = null;
      _lastSavedSignature = null;
    });
    ShadToaster.maybeOf(
      context,
    )?.show(FeedbackToast.success(title: context.l10n.draftSent));
    if (shouldCleanupSeedAttachments) {
      await _cleanupSeedAttachmentMetadata(widget.locate<DraftCubit>());
    }
    if (!mounted) {
      return;
    }
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
    bool hasActiveRecipients,
  }) _splitRecipients() {
    final emailTargets = <ComposerRecipient>[];
    final xmppTargets = <ComposerRecipient>[];
    var hasActiveRecipients = false;
    for (final recipient in _recipients) {
      if (!recipient.included) continue;
      hasActiveRecipients = true;
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
      hasActiveRecipients: hasActiveRecipients,
    );
  }

  String? _resolveXmppJid(ComposerRecipient recipient) {
    final chat = recipient.target.chat;
    final transport = recipient.target.transport ?? chat?.defaultTransport;
    if (transport?.isEmail ?? false) {
      return null;
    }
    if (transport?.isXmpp ?? false) {
      if (chat != null) {
        return chat.jid;
      }
    }
    if (chat != null) {
      return null;
    }
    final normalizedAddress = recipient.target.normalizedAddress;
    final rawAddress = recipient.target.address;
    final candidate = normalizedAddress ?? rawAddress?.trim();
    if (candidate == null || candidate.isEmpty) {
      return null;
    }
    if (transport?.isXmpp ?? false) {
      return candidate;
    }
    return null;
  }

  bool _isEmailRecipient(ComposerRecipient recipient) {
    final chat = recipient.target.chat;
    final transport = recipient.target.transport ?? chat?.defaultTransport;
    if (transport?.isEmail ?? false) {
      return true;
    }
    if (transport?.isXmpp ?? false) {
      return false;
    }
    if (chat != null) {
      return false;
    }
    final normalizedAddress = recipient.target.normalizedAddress;
    final rawAddress = recipient.target.address;
    final candidate = normalizedAddress ?? rawAddress?.trim();
    if (candidate == null || candidate.isEmpty) {
      return false;
    }
    return false;
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
    ShadToaster.maybeOf(context)?.show(FeedbackToast.info(message: message));
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
    required bool emailRecipientsUnavailable,
  }) {
    if (emailRecipientsUnavailable) {
      return context.l10n.chatComposerEmailRecipientUnavailable;
    }
    if (!hasActiveRecipients) {
      return context.l10n.draftNoRecipients;
    }
    if (!hasContent) {
      return context.l10n.draftValidationNoContent;
    }
    return null;
  }

  String _draftFailureMessage(
    DraftSendFailureType type,
    AppLocalizations l10n,
  ) {
    return switch (type) {
      DraftSendFailureType.noRecipients => l10n.draftNoRecipients,
      DraftSendFailureType.noContent => l10n.draftValidationNoContent,
      DraftSendFailureType.sendFailed => l10n.draftSendFailed,
    };
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
    final spacing = context.spacing;
    if (!mounted) return;
    final attachment = pending.attachment;
    final file = File(attachment.path);
    final missingMessage = context.l10n.draftFileMissing(attachment.path);
    if (!await file.exists()) {
      if (!mounted) return;
      _showToast(missingMessage);
      return;
    }
    if (!mounted) return;
    await showFadeScaleDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: AxiModalSurface(
            padding: EdgeInsets.zero,
            child: Stack(
              children: [
                Positioned.fill(child: Image.file(file, fit: BoxFit.contain)),
                Positioned(
                  top: spacing.s,
                  right: spacing.s,
                  child: AxiIconButton(
                    iconData: LucideIcons.x,
                    tooltip: dialogContext.l10n.commonClose,
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ],
            ),
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
      dialogMaxWidth: context.sizing.dialogMaxWidth,
      surfacePadding: EdgeInsets.zero,
      builder: (sheetContext) {
        final attachment = pending.attachment;
        final sizeLabel = formatBytes(attachment.sizeBytes, context.l10n);
        final colors = sheetContext.colorScheme;
        final spacing = sheetContext.spacing;
        return AxiSheetScaffold.scroll(
          header: AxiSheetHeader(
            title: Text(sheetContext.l10n.chatAttachmentTooltip),
            onClose: () => Navigator.of(sheetContext).maybePop(),
            padding: EdgeInsets.fromLTRB(
              spacing.m,
              spacing.m,
              spacing.m,
              spacing.s,
            ),
          ),
          bodyPadding: EdgeInsets.fromLTRB(
            spacing.m,
            0,
            spacing.m,
            spacing.m,
          ),
          children: [
            AxiListTile(
              leading: Icon(attachmentIcon(attachment), color: colors.primary),
              title: attachment.fileName,
              subtitle: sizeLabel,
              paintSurface: false,
            ),
            if (attachment.isImage)
              AxiListButton(
                leading: const Icon(LucideIcons.image),
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _showAttachmentPreview(pending);
                },
                child: Text(sheetContext.l10n.draftAttachmentPreview),
              ),
            AxiListButton.destructive(
              leading: const Icon(LucideIcons.trash2),
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _handlePendingAttachmentRemoved(pending.id);
              },
              child: Text(sheetContext.l10n.draftRemoveAttachment),
            ),
          ],
        );
      },
    );
  }
}

class _DraftTaskDropRegion extends StatefulWidget {
  const _DraftTaskDropRegion({required this.child, this.onTaskDropped});

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
    final borderWidth = context.borderSide.width;
    final hoverAlpha = context.motion.tapHoverAlpha;
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
          duration: baseAnimationDuration,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            border: Border.all(
              color: hovering ? colors.primary : Colors.transparent,
              width: borderWidth,
            ),
            borderRadius: borderRadius,
            color:
                hovering ? colors.primary.withValues(alpha: hoverAlpha) : null,
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

  Size _ghostSize(BuildContext context) {
    final sizing = context.sizing;
    final spacing = context.spacing;
    final double defaultGhostWidth = sizing.menuMaxWidth;
    final double defaultGhostHeight = sizing.listButtonHeight + spacing.s;
    final double minGhostWidth = sizing.menuMaxWidth - spacing.l;
    final double maxGhostWidth = sizing.dialogMaxWidth;
    final double minGhostHeight = sizing.listButtonHeight + spacing.xs;
    final double maxGhostHeight = sizing.listButtonHeight * 4;
    final double width = payload.sourceBounds?.width ?? defaultGhostWidth;
    final double height = payload.sourceBounds?.height ?? defaultGhostHeight;
    return Size(
      width.clamp(minGhostWidth, maxGhostWidth),
      height.clamp(minGhostHeight, maxGhostHeight),
    );
  }

  Offset _ghostOffset(BuildContext context, Size ghostSize) {
    final spacing = context.spacing;
    final double pointerClampPadding = spacing.xs / (spacing.m * 2);
    final double centerFraction = spacing.m / (spacing.m * 2);
    final double pointerFraction =
        (payload.pointerNormalizedX ?? centerFraction)
            .clamp(0.0, 1.0)
            .toDouble();
    final double pointerOffsetY =
        (payload.pointerOffsetY ?? (ghostSize.height / 2))
            .clamp(0.0, ghostSize.height)
            .toDouble();
    double left = anchor.dx - (ghostSize.width * pointerFraction);
    double top = anchor.dy - pointerOffsetY;
    final double minLeft = -ghostSize.width * pointerClampPadding;
    final double maxLeft =
        regionSize.width - (ghostSize.width * (1 - pointerClampPadding));
    final double minTop = -ghostSize.height * pointerClampPadding;
    final double maxTop =
        regionSize.height - (ghostSize.height * pointerClampPadding);
    left = left.clamp(minLeft, maxLeft);
    top = top.clamp(minTop, maxTop);
    return Offset(left, top);
  }

  @override
  Widget build(BuildContext context) {
    final Size ghostSize = _ghostSize(context);
    final Offset offset = _ghostOffset(context, ghostSize);
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: IgnorePointer(
        child: _DraftTaskDragGhost(payload: payload, size: ghostSize),
      ),
    );
  }
}

class _DraftTaskDragGhost extends StatelessWidget {
  const _DraftTaskDragGhost({required this.payload, required this.size});

  final CalendarDragPayload payload;
  final Size size;

  String _timingLabel(BuildContext context) {
    final CalendarTask task = payload.snapshot;
    final DateTime? start = task.scheduledTime;
    final DateTime? deadline = task.deadline;
    if (start != null) {
      return TimeFormatter.formatFriendlyDateTime(context.l10n, start);
    }
    if (deadline != null) {
      return context.l10n.draftTaskDue(
        TimeFormatter.formatFriendlyDateTime(context.l10n, deadline),
      );
    }
    return context.l10n.draftTaskNoSchedule;
  }

  @override
  Widget build(BuildContext context) {
    final CalendarTask task = payload.snapshot;
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final spacing = context.spacing;
    final l10n = context.l10n;
    final String title =
        task.title.trim().isEmpty ? l10n.draftTaskUntitled : task.title.trim();
    final String? description = task.description?.trim().isNotEmpty == true
        ? task.description!.trim()
        : null;
    final borderRadius = context.radius;
    final shadowColor = colors.foreground.withValues(
      alpha: context.motion.tapSplashAlpha,
    );
    return Material(
      color: Colors.transparent,
      elevation: 0,
      borderRadius: borderRadius,
      child: Container(
        width: size.width,
        constraints: BoxConstraints(minHeight: size.height),
        padding: EdgeInsets.all(spacing.s + spacing.xs),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: borderRadius,
          border: Border.all(
            color: colors.primary,
            width: context.borderSide.width,
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: context.sizing.modalShadowBlur,
              offset: Offset(0, context.sizing.modalShadowOffsetY),
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
              style: textTheme.small.copyWith(color: colors.foreground),
            ),
            SizedBox(height: spacing.xs + spacing.xxs),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.calendarClock,
                  size: context.sizing.menuItemIconSize,
                  color: colors.primary,
                ),
                SizedBox(width: spacing.xs + spacing.xxs),
                Flexible(
                  child: Text(
                    _timingLabel(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.muted.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
            if (description != null) ...[
              SizedBox(height: spacing.xs + spacing.xxs),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.muted.copyWith(color: colors.mutedForeground),
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
    final disabledColor = colors.mutedForeground;
    final iconColor = readyToSend && !sending ? colors.primary : disabledColor;
    final borderColor =
        sending || !readyToSend ? colors.border : colors.primary;
    final tooltip =
        sending ? l10n.draftSendingEllipsis : disabledReason ?? l10n.draftSend;
    final interactive = onPressed != null && !sending;
    return _DraftComposerIconButton(
      tooltip: tooltip,
      icon: LucideIcons.send,
      onPressed: interactive ? onPressed : null,
      loading: sending,
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
      final actions = <AxiMenuAction>[];
      if (pending.attachment.isImage) {
        actions.add(
          AxiMenuAction(
            label: l10n.draftAttachmentPreview,
            icon: LucideIcons.image,
            onPressed: () => onPreview(pending),
          ),
        );
      }
      actions.add(
        AxiMenuAction(
          label: l10n.draftRemoveAttachment,
          icon: LucideIcons.trash2,
          destructive: true,
          onPressed: () => onRemove(pending.id),
        ),
      );
      if (actions.isEmpty) {
        return const [];
      }
      return [AxiMenu(actions: actions)];
    }

    Widget body;
    if (loading) {
      body = Center(
        child: AxiProgressIndicator(color: context.colorScheme.foreground),
      );
    } else if (attachments.isEmpty) {
      body = Text(l10n.draftNoAttachments, style: context.textTheme.muted);
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
        SizedBox(height: context.spacing.s),
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
    this.loading = false,
    this.iconColorOverride,
    this.borderColorOverride,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? iconColorOverride;
  final Color? borderColorOverride;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final sizing = context.sizing;
    final enabled = onPressed != null;
    final iconColor = iconColorOverride ??
        (enabled ? colors.foreground : colors.mutedForeground);
    final borderColor = borderColorOverride ?? colors.border;
    return AxiIconButton(
      iconData: icon,
      tooltip: tooltip,
      semanticLabel: tooltip,
      onPressed: onPressed,
      loading: loading,
      color: iconColor,
      backgroundColor: colors.card,
      borderColor: borderColor,
      borderWidth: context.borderSide.width,
      cornerRadius: context.radii.squircle,
      buttonSize: sizing.iconButtonSize,
      tapTargetSize: sizing.iconButtonTapTarget,
      iconSize: sizing.iconButtonIconSize,
    );
  }
}
