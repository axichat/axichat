// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'package:async/async.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/calendar_task_ics_message.dart';
import 'package:axichat/src/calendar/task/task_share_formatter.dart';
import 'package:axichat/src/calendar/view/grid/calendar_drag_payload.dart';
import 'package:axichat/src/chat/models/pending_attachment.dart';
import 'package:axichat/src/attachments/view/pending_attachment_preview.dart';
import 'package:axichat/src/chat/view/composer/pending_attachment_list.dart';
import 'package:axichat/src/common/attachment_drop.dart';
import 'package:axichat/src/common/attachment_import_source.dart';
import 'package:axichat/src/common/composer_attachment_staging.dart';
import 'package:axichat/src/common/compose_recipient.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/draft_limits.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/draft_forwarded_content.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/file_type_detector.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/common/url_safety.dart';
import 'package:axichat/src/email/models/fan_out_recipient_state.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/view/draft_composer_view.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/avatar/avatar_presentation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class DraftForm extends StatefulWidget {
  const DraftForm({
    super.key,
    this.id,
    this.jids = const [''],
    this.body = '',
    this.subject = '',
    this.quoteTarget,
    this.attachmentMetadataIds = const [],
    this.calendarTaskIcsMessage,
    this.forwardedBlocks = const <DraftForwardedBlock>[],
    this.forwardedSourceAttachmentMetadataIds = const <String>[],
    this.recipientTransportOverrides = const <String, MessageTransport>{},
    this.autosaveEnabled = false,
    required this.initialRecipients,
    this.suggestionAddresses = const <String>{},
    this.suggestionDomains = const <String>{},
    this.recipientCountAdjustment = 0,
    this.subjectTrailing,
    this.banner,
    this.onRecipientAddressesChanged,
    this.onClosed,
    this.onDiscarded,
    this.onDraftSaved,
  });

  final int? id;
  final List<String> jids;
  final String body;
  final String subject;
  final DraftQuoteTarget? quoteTarget;
  final List<String> attachmentMetadataIds;
  final CalendarTaskIcsMessage? calendarTaskIcsMessage;
  final List<DraftForwardedBlock> forwardedBlocks;
  final List<String> forwardedSourceAttachmentMetadataIds;
  final Map<String, MessageTransport> recipientTransportOverrides;
  final bool autosaveEnabled;
  final List<ComposerRecipient> initialRecipients;
  final Set<String> suggestionAddresses;
  final Set<String> suggestionDomains;
  final int recipientCountAdjustment;
  final Widget? subjectTrailing;
  final Widget? banner;
  final ValueChanged<List<String>>? onRecipientAddressesChanged;
  final VoidCallback? onClosed;
  final VoidCallback? onDiscarded;
  final ValueChanged<int>? onDraftSaved;

  @override
  State<DraftForm> createState() => DraftFormState();
}

enum _DraftFormCloseAction { save, discard, cancel }

enum _DraftSendAction { sendAsEmail }

final class _ConvertedForwardRange {
  const _ConvertedForwardRange({required this.start, required this.end});

  final int start;
  final int end;

  _ConvertedForwardRange shift(int delta) {
    return _ConvertedForwardRange(start: start + delta, end: end + delta);
  }

  _ConvertedForwardRange replace({required int start, required int end}) {
    return _ConvertedForwardRange(start: start, end: end);
  }
}

class DraftFormState extends State<DraftForm> {
  final _formKey = GlobalKey<FormState>();
  bool _showValidationMessages = false;
  String? _sendErrorMessage;
  late final TextEditingController _bodyTextController;
  late final TextEditingController _subjectTextController;
  late final FocusNode _bodyFocusNode;
  late final FocusNode _subjectFocusNode;
  final Object _recipientTextInputTapRegionGroup = Object();
  late List<ComposerRecipient> _recipients;
  late List<PendingAttachment> _pendingAttachments;
  late List<DraftForwardedBlock> _forwardedBlocks;
  late List<String> _seedAttachmentMetadataIds;
  late String _lastBodyText;
  late String _lastSubjectText;
  Map<ComposerRecipientKey, FanOutRecipientState>
  _latestEmailRecipientStatuses = const {};
  bool _partialSendNoticeVisible = false;
  CalendarTaskIcsMessage? _pendingCalendarTaskIcsMessage;
  final Map<String, _ConvertedForwardRange> _convertedForwardRanges =
      <String, _ConvertedForwardRange>{};
  final Map<String, bool> _forwardPreviewShowImages = <String, bool>{};
  final Map<String, bool> _forwardPreviewUnblockedOriginal = <String, bool>{};
  bool _hydrationScheduled = false;
  bool _forwardAttachmentCloneScheduled = false;

  late var id = widget.id;
  bool _loadingAttachments = false;
  bool _addingAttachment = false;
  late final String _sendOwnerId = 'draft-form-${identityHashCode(this)}';
  bool _savingDraft = false;
  bool _discardingDraft = false;
  Set<String> _draftSubmittedAttachmentKeys = const <String>{};
  bool _retryForceEmail = false;
  bool _sendCompletionHandled = false;
  bool _seedAttachmentCleanupHandled = false;
  bool _autosaveEnabled = false;
  bool _updatingAutosavePreference = false;
  Timer? _autosaveTimer;
  Timer? _autosaveSavedIndicatorTimer;
  int? _lastSavedSignature;
  DateTime? _lastAutosaveAt;
  bool _autosaveInFlight = false;
  Future<void>? _autosaveOperation;
  Future<void>? _attachmentHydrationOperation;
  Future<void>? _attachmentPreparationOperation;
  CancelableCompleter<void>? _attachmentHydrationCancellation;
  CancelableCompleter<void>? _attachmentPreparationCancellation;
  Future<void> Function(String)? _deleteDraftAttachmentMetadata;
  late final String _draftComposerStagingSessionId = const Uuid().v4();
  int _saveEpoch = 0;

  @override
  void initState() {
    super.initState();
    _forwardedBlocks = List<DraftForwardedBlock>.from(
      widget.forwardedBlocks,
      growable: false,
    );
    _seedAttachmentMetadataIds = List<String>.from(
      widget.attachmentMetadataIds,
      growable: false,
    );
    final initialBodyText = _initialBodyTextWithConvertedForwards(
      _initialBodyTextWithPlainForwards(widget.body),
    );
    _lastBodyText = initialBodyText;
    _bodyTextController = TextEditingController(text: initialBodyText)
      ..addListener(_bodyListener);
    _lastSubjectText = widget.subject;
    _subjectTextController = TextEditingController(text: widget.subject)
      ..addListener(_subjectListener);
    _bodyFocusNode = FocusNode();
    _subjectFocusNode = FocusNode();
    _pendingAttachments = const [];
    _pendingCalendarTaskIcsMessage = widget.calendarTaskIcsMessage;
    _recipients = widget.initialRecipients
        .where(
          (recipient) =>
              !isAxiImServerAnnouncementRecipientTarget(recipient.target),
        )
        .toList();
    _autosaveEnabled = widget.autosaveEnabled;
    _lastSavedSignature = _savedSignatureFromSeed();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _deleteDraftAttachmentMetadata = context
        .read<DraftCubit>()
        .deleteDraftAttachmentMetadata;
    if (_hydrationScheduled ||
        (_seedAttachmentMetadataIds.isEmpty &&
            widget.forwardedSourceAttachmentMetadataIds.isEmpty)) {
      return;
    }
    _hydrationScheduled = true;
    _loadingAttachments = true;
    unawaited(_hydrateAttachments(context.read<DraftCubit>()));
  }

  @override
  void didUpdateWidget(covariant DraftForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newId = widget.id;
    if (newId != null && newId != id) {
      id = newId;
    }
    if (oldWidget.id == widget.id &&
        oldWidget.quoteTarget != widget.quoteTarget) {
      _scheduleAutosave();
    }
    if (oldWidget.id == widget.id &&
        oldWidget.calendarTaskIcsMessage != widget.calendarTaskIcsMessage) {
      _pendingCalendarTaskIcsMessage = widget.calendarTaskIcsMessage;
      _scheduleAutosave();
    }
  }

  @override
  void dispose() {
    final deleteDraftAttachmentMetadata = _deleteDraftAttachmentMetadata;
    final autosaveOperation = _autosaveOperation;
    final pendingAttachments = _unsubmittedDraftPendingAttachments();
    if (deleteDraftAttachmentMetadata != null) {
      unawaited(
        _releaseDraftComposerAttachmentsAfterAutosave(
          autosaveOperation: autosaveOperation,
          deleteDraftAttachmentMetadata: deleteDraftAttachmentMetadata,
          pendingAttachments: pendingAttachments,
        ),
      );
    }
    _autosaveTimer?.cancel();
    _autosaveSavedIndicatorTimer?.cancel();
    _invalidatePendingSaves();
    _invalidateAttachmentWork();
    _autosaveOperation = null;
    _autosaveInFlight = false;
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
      _seedAttachmentMetadataIds.isNotEmpty;

  String _initialBodyTextWithConvertedForwards(String introText) {
    var bodyText = introText;
    _convertedForwardRanges.clear();
    for (final block in _forwardedBlocks) {
      if (!block.isConverted) {
        continue;
      }
      final convertedText = block.convertedText ?? '';
      if (convertedText.trim().isEmpty) {
        continue;
      }
      final separator = bodyText.trim().isEmpty ? '' : '\n\n';
      final start = bodyText.length + separator.length;
      bodyText = '$bodyText$separator$convertedText';
      _convertedForwardRanges[block.blockId] = _ConvertedForwardRange(
        start: start,
        end: bodyText.length,
      );
    }
    return bodyText;
  }

  String _initialBodyTextWithPlainForwards(String introText) {
    if (_forwardedBlocks.isEmpty) {
      return introText;
    }
    final retainedBlocks = <DraftForwardedBlock>[];
    var bodyText = introText;
    for (final block in _forwardedBlocks) {
      if (_shouldPreviewForwardedBlock(block)) {
        retainedBlocks.add(block);
        continue;
      }
      final forwardedText = block.isConverted
          ? block.activePlainText
          : DraftForwardedContent.plainForwardedBlock(block);
      if (forwardedText.trim().isEmpty) {
        continue;
      }
      final separator = bodyText.trim().isEmpty ? '' : '\n\n';
      bodyText = '$bodyText$separator$forwardedText';
    }
    _forwardedBlocks = retainedBlocks;
    return bodyText;
  }

  bool _shouldPreviewForwardedBlock(DraftForwardedBlock block) {
    final normalizedHtml = HtmlContentCodec.normalizeHtml(block.originalHtml);
    if (normalizedHtml == null) {
      return false;
    }
    final derivation = HtmlContentCodec.emailDerivations(normalizedHtml);
    return HtmlContentCodec.shouldRenderRichEmailHtml(
      normalizedHtmlBody: normalizedHtml,
      normalizedHtmlText: derivation.visibleBodyText,
      renderedText: block.originalPlainText,
      derivation: derivation,
    );
  }

  void _bodyListener() {
    if (!mounted) {
      return;
    }
    final nextText = _bodyTextController.text;
    if (nextText == _lastBodyText) {
      return;
    }
    _updateConvertedForwardRanges(
      previousText: _lastBodyText,
      nextText: nextText,
    );
    _lastBodyText = nextText;
    _syncConvertedForwardBlocksFromBody();
    setState(() {
      _sendErrorMessage = null;
      _latestEmailRecipientStatuses = const {};
      _partialSendNoticeVisible = false;
      _clearRetryForceEmail();
    });
    _scheduleAutosave();
  }

  void _updateConvertedForwardRanges({
    required String previousText,
    required String nextText,
  }) {
    if (_convertedForwardRanges.isEmpty || previousText == nextText) {
      return;
    }
    var prefixLength = 0;
    final shortestLength = previousText.length < nextText.length
        ? previousText.length
        : nextText.length;
    while (prefixLength < shortestLength &&
        previousText.codeUnitAt(prefixLength) ==
            nextText.codeUnitAt(prefixLength)) {
      prefixLength += 1;
    }
    var previousSuffix = previousText.length;
    var nextSuffix = nextText.length;
    while (previousSuffix > prefixLength &&
        nextSuffix > prefixLength &&
        previousText.codeUnitAt(previousSuffix - 1) ==
            nextText.codeUnitAt(nextSuffix - 1)) {
      previousSuffix -= 1;
      nextSuffix -= 1;
    }
    final delta = nextText.length - previousText.length;
    final updated = <String, _ConvertedForwardRange>{};
    for (final entry in _convertedForwardRanges.entries) {
      final range = entry.value;
      if (previousSuffix <= range.start) {
        updated[entry.key] = range.shift(delta);
        continue;
      }
      if (prefixLength >= range.end) {
        updated[entry.key] = range;
        continue;
      }
      final nextStart = range.start < prefixLength ? range.start : prefixLength;
      final nextEnd = (range.end + delta)
          .clamp(nextStart, nextText.length)
          .toInt();
      updated[entry.key] = range.replace(start: nextStart, end: nextEnd);
    }
    _convertedForwardRanges
      ..clear()
      ..addAll(updated);
  }

  void _syncConvertedForwardBlocksFromBody() {
    if (_convertedForwardRanges.isEmpty) {
      return;
    }
    final bodyText = _bodyTextController.text;
    _forwardedBlocks = _forwardedBlocks
        .map((block) {
          if (!block.isConverted) {
            return block;
          }
          final range = _convertedForwardRanges[block.blockId];
          if (range == null) {
            return block;
          }
          final start = range.start.clamp(0, bodyText.length).toInt();
          final end = range.end.clamp(start, bodyText.length).toInt();
          return block.copyWith(convertedText: bodyText.substring(start, end));
        })
        .toList(growable: false);
  }

  void _subjectListener() {
    if (!mounted) {
      return;
    }
    final nextText = _subjectTextController.text;
    if (nextText == _lastSubjectText) {
      return;
    }
    _lastSubjectText = nextText;
    setState(() {
      _sendErrorMessage = null;
      _latestEmailRecipientStatuses = const {};
      _partialSendNoticeVisible = false;
      _clearRetryForceEmail();
    });
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

  void _handleTaskDrop(CalendarDragPayload payload) {
    setState(() {
      _latestEmailRecipientStatuses = const {};
      _partialSendNoticeVisible = false;
      _clearRetryForceEmail();
      _pendingCalendarTaskIcsMessage = CalendarTaskIcsMessage(
        task: payload.snapshot,
      );
    });
    _appendTaskShareText(payload.snapshot);
    _scheduleAutosave();
  }

  Widget? _composerBanner(Widget? baseBanner) {
    final banners = <Widget>[
      if (_partialSendNoticeVisible) const _DraftPartialSendBanner(),
      ?baseBanner,
    ];
    final calendarTaskIcsMessage = _pendingCalendarTaskIcsMessage;
    if (calendarTaskIcsMessage != null) {
      banners.add(
        _DraftCalendarTaskBanner(
          message: calendarTaskIcsMessage,
          onRemove: _handleCalendarTaskRemoved,
        ),
      );
    }
    if (banners.isEmpty) {
      return null;
    }
    if (banners.length == 1) {
      return banners.single;
    }
    return Column(mainAxisSize: MainAxisSize.min, children: banners);
  }

  void _handleCalendarTaskRemoved() {
    setState(() {
      _latestEmailRecipientStatuses = const {};
      _partialSendNoticeVisible = false;
      _clearRetryForceEmail();
      _pendingCalendarTaskIcsMessage = null;
    });
    _scheduleAutosave();
  }

  Widget? _forwardedPreview(double baseFontSize) {
    if (_forwardedBlocks.isEmpty) {
      return null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final block in _forwardedBlocks)
          _DraftForwardedBlockPreview(
            block: block,
            showImages: _forwardPreviewShowImages[block.blockId] == true,
            originalContentUnblocked:
                _forwardPreviewUnblockedOriginal[block.blockId] == true,
            baseFontSize: baseFontSize,
            onShowImages: () => _handleForwardShowImages(block.blockId),
            onUnblockOriginal: () =>
                _handleForwardUnblockOriginal(block.blockId),
            onConvert: () => _handleForwardConvert(block),
            onRestore: () => _handleForwardRestore(block),
            onLinkTap: (url) => unawaited(_handleForwardPreviewLinkTap(url)),
          ),
      ],
    );
  }

  void _handleForwardShowImages(String blockId) {
    setState(() {
      _forwardPreviewShowImages[blockId] = true;
    });
  }

  Future<void> _handleForwardUnblockOriginal(String blockId) async {
    final l10n = context.l10n;
    final confirmed = await confirm(
      context,
      title: l10n.chatEmailOriginalContentConfirmTitle,
      message: l10n.chatEmailOriginalContentConfirmMessage,
      confirmLabel: l10n.chatEmailViewOriginalButton,
      destructiveConfirm: false,
    );
    if (!mounted || confirmed != true) {
      return;
    }
    setState(() {
      _forwardPreviewUnblockedOriginal[blockId] = true;
    });
  }

  void _handleForwardConvert(DraftForwardedBlock block) {
    if (block.isConverted) {
      return;
    }
    final text = DraftForwardedContent.plainForwardedBlock(block);
    final separator = _bodyTextController.text.trim().isEmpty ? '' : '\n\n';
    final start = _bodyTextController.text.length + separator.length;
    final nextText = '${_bodyTextController.text}$separator$text';
    _convertedForwardRanges[block.blockId] = _ConvertedForwardRange(
      start: start,
      end: nextText.length,
    );
    _replaceForwardedBlock(block.asConverted(text));
    _lastBodyText = nextText;
    _bodyTextController.value = _bodyTextController.value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
      composing: TextRange.empty,
    );
    _bodyFocusNode.requestFocus();
    _scheduleAutosave();
  }

  Future<void> _handleForwardRestore(DraftForwardedBlock block) async {
    if (!block.isConverted) {
      return;
    }
    final restore = await showFadeScaleDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final pop = Navigator.of(dialogContext).pop;
        return AxiDialog(
          constraints: BoxConstraints(
            maxWidth: dialogContext.sizing.dialogMaxWidth,
          ),
          title: Text(
            dialogContext.l10n.draftForwardRestoreTitle,
            style: dialogContext.modalHeaderTextStyle,
          ),
          description: Text(dialogContext.l10n.draftForwardRestoreMessage),
          actions: [
            AxiButton.outline(
              onPressed: () => pop(false),
              child: Text(dialogContext.l10n.commonCancel),
            ),
            AxiButton.primary(
              onPressed: () => pop(true),
              child: Text(dialogContext.l10n.draftForwardRestoreAction),
            ),
          ],
        );
      },
    );
    if (!mounted || restore != true) {
      return;
    }
    _removeConvertedForwardText(block.blockId);
    _replaceForwardedBlock(block.restoredOriginal());
    _scheduleAutosave();
  }

  void _removeConvertedForwardText(String blockId) {
    final range = _convertedForwardRanges.remove(blockId);
    if (range == null) {
      return;
    }
    final bodyText = _bodyTextController.text;
    final removal = _convertedForwardRemovalRange(range, bodyText);
    var nextText = bodyText.replaceRange(removal.start, removal.end, '');
    nextText = _collapseTrailingForwardSeparators(nextText);
    _bodyTextController.value = _bodyTextController.value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(
        offset: removal.start.clamp(0, nextText.length).toInt(),
      ),
      composing: TextRange.empty,
    );
    _lastBodyText = nextText;
  }

  void _replaceForwardedBlock(DraftForwardedBlock replacement) {
    setState(() {
      _forwardedBlocks = _forwardedBlocks
          .map(
            (block) =>
                block.blockId == replacement.blockId ? replacement : block,
          )
          .toList(growable: false);
    });
  }

  Future<void> _handleForwardPreviewLinkTap(String url) async {
    if (!mounted) return;
    final l10n = context.l10n;
    final report = assessLinkSafety(raw: url, kind: LinkSafetyKind.message);
    if (report == null || !report.isSafe) {
      _showToast(l10n.chatInvalidLink(url.trim()));
      return;
    }
    final hostLabel = formatLinkSchemeHostLabel(report);
    final baseMessage = report.needsWarning
        ? l10n.chatOpenLinkWarningMessage(report.displayUri, hostLabel)
        : l10n.chatOpenLinkMessage(report.displayUri, hostLabel);
    final warningBlock = formatLinkWarningText(report.warnings);
    final action = await showLinkActionDialog(
      context,
      title: l10n.chatOpenLinkTitle,
      message: '$baseMessage$warningBlock',
      openLabel: l10n.chatOpenLinkConfirm,
      copyLabel: l10n.chatActionCopy,
      cancelLabel: l10n.commonCancel,
    );
    if (action == null) return;
    if (action == LinkAction.copy) {
      await Clipboard.setData(ClipboardData(text: report.displayUri));
      return;
    }
    final launched = await launchUrl(
      report.uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      _showToast(l10n.chatUnableToOpenHost(report.displayHost));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settingsState = context.watch<SettingsCubit>().state;
    final endpointConfig = settingsState.endpointConfig;

    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, profileState) {
        final profileJid = profileState.jid;
        final resolvedProfileJid = profileJid.trim();
        final String? selfJid = resolvedProfileJid.isNotEmpty
            ? resolvedProfileJid
            : null;
        final selfIdentity = SelfAvatar(
          jid: selfJid,
          avatar: Avatar.tryParseOrNull(
            path: profileState.avatarPath,
            hash: null,
          ),
          hydrating: profileState.avatarHydrating,
        );
        return BlocBuilder<RosterCubit, RosterState>(
          builder: (context, rosterState) {
            final rosterItems = rosterState.items ?? const <RosterItem>[];
            return BlocBuilder<ChatsCubit, ChatsState>(
              builder: (context, chatsState) {
                final chats = chatsState.items ?? const <Chat>[];
                final autovalidateMode = _showValidationMessages
                    ? AutovalidateMode.always
                    : AutovalidateMode.disabled;
                return SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: autovalidateMode,
                    child: BlocConsumer<DraftCubit, DraftState>(
                      listener: (context, state) {
                        if (state is DraftSaveComplete) {
                          if (!state.autoSaved) {
                            ShadToaster.maybeOf(context)?.show(
                              FeedbackToast.success(title: l10n.draftSaved),
                            );
                          }
                        } else if (state is DraftSending) {
                          if (state.ownerId == _sendOwnerId && mounted) {
                            setState(() {
                              _sendErrorMessage = null;
                              _partialSendNoticeVisible = false;
                              if (!state.preparing) {
                                _pendingAttachments = _pendingAttachments
                                    .map(
                                      (pending) => pending.copyWith(
                                        status:
                                            PendingAttachmentStatus.uploading,
                                        clearErrorMessage: true,
                                      ),
                                    )
                                    .toList();
                              }
                            });
                          }
                        } else if (state is DraftFailure) {
                          if (state.ownerId != _sendOwnerId) return;
                          if (mounted) {
                            setState(() {
                              _sendErrorMessage = _draftFailureMessage(
                                state.type,
                                l10n,
                              );
                            });
                          }
                        }
                      },
                      builder: (context, state) {
                        final sendFlowActive = state.isSendingOwner(
                          _sendOwnerId,
                        );
                        final isSending = sendFlowActive;
                        final enabled =
                            !sendFlowActive &&
                            !_savingDraft &&
                            !_discardingDraft;
                        final bodyText = _bodyTextController.text.trim();
                        final subjectText = _subjectTextController.text.trim();
                        final pendingAttachments = _pendingAttachments;
                        final hasAttachments = pendingAttachments.isNotEmpty;
                        final hasCalendarTask =
                            _pendingCalendarTaskIcsMessage != null;
                        final hasForwardedBlocks = _forwardedBlocks.isNotEmpty;
                        final hasQuoteTarget = widget.quoteTarget != null;
                        final hasPreparingAttachments = pendingAttachments.any(
                          (pending) => pending.isPreparing,
                        );
                        final activeRecipients = _recipients.includedRecipients;
                        final hasActiveRecipients = activeRecipients.isNotEmpty;
                        final hasEmailRecipients =
                            activeRecipients.hasEmailRecipients;
                        final hasContent = _hasContent();
                        final recipientCount = _recipientStrings().length;
                        var effectiveRecipientCount =
                            recipientCount - widget.recipientCountAdjustment;
                        if (effectiveRecipientCount < 0) {
                          effectiveRecipientCount = 0;
                        }
                        final recipientOnlyDraftAllowed =
                            effectiveRecipientCount > 0;
                        final canSave =
                            enabled &&
                            (recipientOnlyDraftAllowed ||
                                _hasMeaningfulBodyText(bodyText) ||
                                subjectText.isNotEmpty ||
                                hasQuoteTarget ||
                                hasAttachments ||
                                hasCalendarTask ||
                                hasForwardedBlocks);
                        final canDiscard =
                            enabled &&
                            (id != null ||
                                recipientOnlyDraftAllowed ||
                                _hasMeaningfulBodyText(bodyText) ||
                                subjectText.isNotEmpty ||
                                hasQuoteTarget ||
                                hasAttachments ||
                                hasCalendarTask ||
                                hasForwardedBlocks);
                        final sendBlocker = _sendValidationMessage(
                          hasActiveRecipients: hasActiveRecipients,
                          hasContent: hasContent,
                          emailRecipientsUnavailable:
                              !endpointConfig.smtpEnabled && hasEmailRecipients,
                        );
                        final bool showSendBlockerMessage =
                            _showValidationMessages &&
                            sendBlocker != null &&
                            sendBlocker != l10n.draftNoRecipients;
                        final String? sendErrorMessage = _sendErrorMessage;
                        final readyToSend =
                            sendBlocker == null &&
                            !sendFlowActive &&
                            !_addingAttachment &&
                            !_loadingAttachments &&
                            !hasPreparingAttachments;
                        final canSendAsEmail =
                            readyToSend &&
                            _canForceSendRecipientsAsEmail(
                              recipients: activeRecipients,
                              endpointConfig: endpointConfig,
                            );
                        final bool showAutosaveHint =
                            _autosaveEnabled &&
                            _lastAutosaveAt != null &&
                            _lastSavedSignature == _currentDraftSignature();
                        return DraftComposerView(
                          enabled: enabled,
                          showValidationMessages: _showValidationMessages,
                          recipients: _recipients,
                          availableChats: chats,
                          rosterItems: rosterItems,
                          databaseSuggestionAddresses:
                              chatsState.recipientAddressSuggestions,
                          selfJid: selfJid,
                          selfIdentity: selfIdentity,
                          latestStatuses: _latestEmailRecipientStatuses,
                          collapsedRecipientsByDefault: false,
                          suggestionAddresses: widget.suggestionAddresses,
                          suggestionDomains: widget.suggestionDomains,
                          recipientAddError: _recipientAddError,
                          onRecipientAdded: _handleRecipientAdded,
                          onRecipientRemoved: _handleRecipientRemoved,
                          subjectController: _subjectTextController,
                          subjectFocusNode: _subjectFocusNode,
                          bodyController: _bodyTextController,
                          bodyFocusNode: _bodyFocusNode,
                          onSubjectSubmitted: _bodyFocusNode.requestFocus,
                          forwardedPreview: _forwardedPreview(
                            settingsState.messageTextSize.fontSize,
                          ),
                          banner: _composerBanner(widget.banner),
                          subjectTrailing: widget.subjectTrailing,
                          loadingAttachments: _loadingAttachments,
                          attachments: _pendingAttachments,
                          addingAttachment: _addingAttachment,
                          onAddAttachment: _handleAttachmentAdded,
                          onAttachmentsDropped:
                              enabled &&
                                  !_addingAttachment &&
                                  !_loadingAttachments &&
                                  !hasPreparingAttachments
                              ? _handleAttachmentsDropped
                              : null,
                          onAttachmentRetry: _handlePendingAttachmentRetry,
                          onAttachmentRemove: _handlePendingAttachmentRemoved,
                          onAttachmentPressed: _handlePendingAttachmentPressed,
                          onAttachmentLongPressed:
                              _handlePendingAttachmentLongPressed,
                          onAttachmentPreview: _showAttachmentPreview,
                          readyToSend: readyToSend,
                          sending: isSending,
                          disabledSendReason: sendBlocker,
                          onSendPressed:
                              sendFlowActive ||
                                  _addingAttachment ||
                                  _loadingAttachments ||
                                  hasPreparingAttachments
                              ? null
                              : _handleSendDraft,
                          onSendLongPressed:
                              sendFlowActive ||
                                  _addingAttachment ||
                                  _loadingAttachments ||
                                  hasPreparingAttachments ||
                                  !canSendAsEmail
                              ? null
                              : _handleSendButtonLongPress,
                          showSendBlockerMessage: showSendBlockerMessage,
                          sendBlockerMessage: sendBlocker,
                          sendErrorMessage: sendBlocker == null
                              ? sendErrorMessage
                              : null,
                          showSendingStatus: isSending,
                          showAutosaveHint: showAutosaveHint,
                          autosaveEnabled: _autosaveEnabled,
                          autosaveSaving: _autosaveInFlight,
                          autosaveUpdating: _updatingAutosavePreference,
                          onAutosaveChanged: _handleAutosaveEnabledChanged,
                          canDiscard: canDiscard,
                          canSave: canSave,
                          onDiscardPressed: _handleDiscard,
                          onSavePressed: _handleSaveDraft,
                          onTaskDropped: _handleTaskDrop,
                          tapRegionGroup: _recipientTextInputTapRegionGroup,
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

  Future<void> _hydrateAttachments(DraftCubit draftCubit) async {
    final cancellation = CancelableCompleter<void>();
    final operation = _performAttachmentHydration(
      cancellation: cancellation,
      draftCubit: draftCubit,
    );
    _attachmentHydrationCancellation = cancellation;
    _attachmentHydrationOperation = operation;
    try {
      await operation;
    } finally {
      if (_attachmentHydrationOperation == operation) {
        _attachmentHydrationOperation = null;
      }
      if (identical(_attachmentHydrationCancellation, cancellation)) {
        _attachmentHydrationCancellation = null;
      }
      if (!cancellation.isCompleted && !cancellation.isCanceled) {
        cancellation.complete();
      }
    }
  }

  Future<void> _performAttachmentHydration({
    required CancelableCompleter<void> cancellation,
    required DraftCubit draftCubit,
  }) async {
    if (_seedAttachmentMetadataIds.isEmpty &&
        widget.forwardedSourceAttachmentMetadataIds.isEmpty) {
      return;
    }
    try {
      if (!_forwardAttachmentCloneScheduled &&
          widget.forwardedSourceAttachmentMetadataIds.isNotEmpty) {
        _forwardAttachmentCloneScheduled = true;
        final clonedIds = await draftCubit.cloneDraftAttachmentMetadata(
          widget.forwardedSourceAttachmentMetadataIds,
        );
        if (!mounted || cancellation.isCanceled) {
          await _deleteAttachmentMetadataIds(
            draftCubit.deleteDraftAttachmentMetadata,
            clonedIds,
          );
          return;
        }
        _seedAttachmentMetadataIds = [
          ..._seedAttachmentMetadataIds,
          ...clonedIds,
        ];
      }
      if (_seedAttachmentMetadataIds.isEmpty) {
        return;
      }
      final pending = await _pendingAttachmentsFromMetadata(
        _seedAttachmentMetadataIds,
        draftCubit,
      );
      if (!mounted || cancellation.isCanceled) return;
      setState(() => _pendingAttachments = pending);
    } finally {
      if (mounted &&
          identical(_attachmentHydrationCancellation, cancellation)) {
        setState(() => _loadingAttachments = false);
      }
    }
  }

  Future<List<PendingAttachment>> _pendingAttachmentsFromMetadata(
    Iterable<String> metadataIds,
    DraftCubit draftCubit,
  ) async {
    if (metadataIds.isEmpty) return const [];
    final hydrated = await draftCubit.loadDraftAttachments(
      metadataIds.toList(),
    );
    final List<PendingAttachment> pending = <PendingAttachment>[];
    for (final attachment in hydrated) {
      final Attachment resolvedAttachment = await _resolveAttachmentMimeType(
        attachment,
      );
      pending.add(
        PendingAttachment(
          id: resolvedAttachment.metadataId ?? _nextPendingAttachmentId(),
          attachment: resolvedAttachment,
        ),
      );
    }
    return pending;
  }

  Future<Attachment> _resolveAttachmentMimeType(Attachment attachment) async {
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

  void _clearRetryForceEmail() {
    _retryForceEmail = false;
  }

  Future<bool> _handleRecipientAdded(Contact target) async {
    if (isAxiImServerAnnouncementRecipientTarget(target)) {
      return false;
    }
    final address = target.resolvedAddress;
    if (target.needsTransportSelection &&
        address != null &&
        address.isNotEmpty) {
      final transport = await _resolveAddressTransport(address);
      if (!mounted || transport == null) return false;
      return _applyRecipient(target.withTransport(transport));
    }
    return _applyRecipient(target);
  }

  Future<bool> _ensureRecipientTransports() async {
    final nextRecipients = List<ComposerRecipient>.from(_recipients);
    var updated = false;
    for (var index = 0; index < nextRecipients.length; index++) {
      final recipient = nextRecipients[index];
      if (!recipient.included || !recipient.needsTransportSelection) {
        continue;
      }
      final address = recipient.target.resolvedAddress;
      if (address == null || address.isEmpty) continue;
      final transport = await _resolveAddressTransport(address);
      if (!mounted || transport == null) return false;
      nextRecipients[index] = recipient.withTarget(
        recipient.target.withTransport(transport),
      );
      updated = true;
    }
    if (updated && mounted) {
      setState(() => _recipients = nextRecipients);
      _notifyRecipientAddressesChanged();
    }
    return true;
  }

  bool _canForceSendRecipientsAsEmail({
    required List<ComposerRecipient> recipients,
    required EndpointConfig endpointConfig,
  }) {
    if (recipients.isEmpty || !endpointConfig.smtpEnabled) {
      return false;
    }
    return recipients.forcedEmailPartition(
          emailDomain: endpointConfig.domain,
        ) !=
        null;
  }

  String? _recipientAddError(Contact target) {
    if (!exceedsComposeRecipientLimit(
      recipients: _recipients,
      target: target,
    )) {
      return null;
    }
    return context.l10n.fanOutErrorTooManyRecipients(composeRecipientLimit);
  }

  bool _applyRecipient(Contact target) {
    if (isAxiImServerAnnouncementRecipientTarget(target)) {
      return false;
    }
    final addError = _recipientAddError(target);
    if (addError != null) {
      _showToast(addError);
      return false;
    }
    final existingIndex = _recipients.indexWhere(
      (recipient) => recipient.key == target.key,
    );
    setState(() {
      _sendErrorMessage = null;
      _latestEmailRecipientStatuses = const {};
      _partialSendNoticeVisible = false;
      _clearRetryForceEmail();
      if (existingIndex >= 0) {
        _recipients[existingIndex] = _recipients[existingIndex]
            .withTarget(target)
            .withIncluded(true);
        return;
      }
      _recipients.add(ComposerRecipient(target: target));
    });
    _notifyRecipientAddressesChanged();
    _revalidateFormIfNeeded();
    _scheduleAutosave();
    return true;
  }

  Future<MessageTransport?> _resolveAddressTransport(String address) async {
    final endpointConfig = context.read<SettingsCubit>().state.endpointConfig;
    return resolveAddressTransportChoice(
      context,
      address: address,
      endpointConfig: endpointConfig,
    );
  }

  void _handleRecipientRemoved(String key) {
    setState(() {
      _sendErrorMessage = null;
      _latestEmailRecipientStatuses = const {};
      _partialSendNoticeVisible = false;
      _clearRetryForceEmail();
      _recipients.removeWhere((recipient) => recipient.key == key);
    });
    _notifyRecipientAddressesChanged();
    _revalidateFormIfNeeded();
    _scheduleAutosave();
  }

  void _applyIncompleteRecipientsForSendOutcome(DraftSendOutcome outcome) {
    if (outcome.incompleteRecipients.isEmpty) {
      return;
    }
    _recipients = _recipients
        .where(
          (recipient) =>
              !recipient.included ||
              outcome.incompleteRecipients.contains(recipient.recipientKey),
        )
        .toList();
  }

  Future<void> _handleAttachmentAdded() async {
    final cancellation = CancelableCompleter<void>();
    final operation = _performAttachmentAdded(cancellation: cancellation);
    _attachmentPreparationCancellation = cancellation;
    _attachmentPreparationOperation = operation;
    try {
      await operation;
    } finally {
      if (_attachmentPreparationOperation == operation) {
        _attachmentPreparationOperation = null;
      }
      if (identical(_attachmentPreparationCancellation, cancellation)) {
        _attachmentPreparationCancellation = null;
      }
      if (!cancellation.isCompleted && !cancellation.isCanceled) {
        cancellation.complete();
      }
    }
  }

  Future<void> _handleAttachmentsDropped(
    DroppedAttachmentSourceResult result,
  ) async {
    if (_addingAttachment) return;
    if (result.hasSkippedItems) {
      _showToast(context.l10n.draftAttachmentInaccessible);
    }
    if (result.sources.isEmpty) {
      return;
    }
    final cancellation = CancelableCompleter<void>();
    final operation = _performDroppedAttachmentsAdded(
      result.sources,
      cancellation: cancellation,
    );
    _attachmentPreparationCancellation = cancellation;
    _attachmentPreparationOperation = operation;
    try {
      await operation;
    } finally {
      if (_attachmentPreparationOperation == operation) {
        _attachmentPreparationOperation = null;
      }
      if (identical(_attachmentPreparationCancellation, cancellation)) {
        _attachmentPreparationCancellation = null;
      }
      if (!cancellation.isCompleted && !cancellation.isCanceled) {
        cancellation.complete();
      }
    }
  }

  Future<void> _performAttachmentAdded({
    required CancelableCompleter<void> cancellation,
  }) async {
    if (_addingAttachment) return;
    setState(() => _addingAttachment = true);
    final attachmentInaccessibleMessage =
        context.l10n.draftAttachmentInaccessible;
    final attachmentFailedMessage = context.l10n.draftAttachmentFailed;
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withReadStream: false,
      );
      if (result == null || result.files.isEmpty || !mounted) {
        return;
      }
      if (cancellation.isCanceled) {
        return;
      }
      final sources = <AttachmentImportSource>[];
      var hasInvalidPath = false;
      for (final file in result.files) {
        final path = file.path;
        if (path == null) {
          hasInvalidPath = true;
          continue;
        }
        final fileName = file.name.isNotEmpty
            ? file.name
            : path.split('/').last;
        sources.add(
          LocalFileAttachmentImportSource(
            path: path,
            fileName: fileName,
            sizeBytes: file.size,
          ),
        );
      }
      if (sources.isEmpty) {
        if (hasInvalidPath && mounted && !cancellation.isCanceled) {
          _showToast(attachmentInaccessibleMessage);
        }
        return;
      }
      if (hasInvalidPath && mounted && !cancellation.isCanceled) {
        _showToast(attachmentInaccessibleMessage);
      }
      await _prepareDraftAttachments(sources, cancellation: cancellation);
    } on PlatformException catch (error) {
      if (!mounted || cancellation.isCanceled) return;
      setState(() {
        _pendingAttachments = _pendingAttachments
            .where((pending) => !pending.isPreparing)
            .toList();
      });
      _showToast(error.message ?? attachmentFailedMessage);
    } on Exception {
      if (!mounted || cancellation.isCanceled) return;
      setState(() {
        _pendingAttachments = _pendingAttachments
            .where((pending) => !pending.isPreparing)
            .toList();
      });
      _showToast(attachmentFailedMessage);
    } finally {
      if (mounted &&
          identical(_attachmentPreparationCancellation, cancellation)) {
        setState(() => _addingAttachment = false);
      }
      if (mounted && !cancellation.isCanceled) {
        _scheduleAutosave();
      }
    }
  }

  Future<void> _performDroppedAttachmentsAdded(
    List<AttachmentImportSource> sources, {
    required CancelableCompleter<void> cancellation,
  }) async {
    if (_addingAttachment) return;
    setState(() => _addingAttachment = true);
    final attachmentFailedMessage = context.l10n.draftAttachmentFailed;
    try {
      await _prepareDraftAttachments(sources, cancellation: cancellation);
    } on Exception {
      if (!mounted || cancellation.isCanceled) return;
      setState(() {
        _pendingAttachments = _pendingAttachments
            .where((pending) => !pending.isPreparing)
            .toList();
      });
      _showToast(attachmentFailedMessage);
    } finally {
      if (mounted &&
          identical(_attachmentPreparationCancellation, cancellation)) {
        setState(() => _addingAttachment = false);
      }
      if (mounted && !cancellation.isCanceled) {
        _scheduleAutosave();
      }
    }
  }

  Future<void> _prepareDraftAttachments(
    List<AttachmentImportSource> sources, {
    required CancelableCompleter<void> cancellation,
  }) async {
    if (!mounted || cancellation.isCanceled || sources.isEmpty) {
      return;
    }
    final draftCubit = context.read<DraftCubit>();
    final entries = [
      for (final source in sources)
        (pendingId: _nextPendingAttachmentId(), source: source),
    ];
    final placeholders = [
      for (final entry in entries)
        PendingAttachment(
          id: entry.pendingId,
          attachment: Attachment(
            path: entry.source.path,
            fileName: entry.source.fileName,
            sizeBytes: 0,
            mimeType: entry.source.mimeType,
            metadataId: entry.pendingId,
          ),
          isPreparing: true,
        ),
    ];
    if (cancellation.isCanceled) {
      return;
    }
    setState(() {
      _latestEmailRecipientStatuses = const {};
      _partialSendNoticeVisible = false;
      _clearRetryForceEmail();
      _pendingAttachments = [..._pendingAttachments, ...placeholders];
    });
    await _mapDraftAttachmentEntries(entries, (entry) {
      if (!mounted || cancellation.isCanceled) {
        _removeDraftPendingAttachmentPlaceholder(entry.pendingId);
        return Future<bool>.value(false);
      }
      if (!_pendingAttachments.any(
        (pending) => pending.id == entry.pendingId,
      )) {
        return Future<bool>.value(false);
      }
      final stagedFuture = draftCubit.stageComposerAttachment(
        source: entry.source,
        sessionId: _draftComposerStagingSessionId,
        fallbackId: entry.pendingId,
      );
      return _resolveDraftAttachmentSource(
        pendingId: entry.pendingId,
        stagedFuture: stagedFuture,
        cancellation: cancellation,
      );
    });
  }

  Future<List<T>> _mapDraftAttachmentEntries<E, T>(
    List<E> entries,
    Future<T> Function(E entry) resolve,
  ) async {
    const concurrency = 3;
    final results = List<T?>.filled(entries.length, null);
    var nextIndex = 0;
    final workers = <Future<void>>[];
    for (
      var worker = 0;
      worker < entries.length && worker < concurrency;
      worker += 1
    ) {
      workers.add(() async {
        while (nextIndex < entries.length) {
          final index = nextIndex;
          nextIndex += 1;
          results[index] = await resolve(entries[index]);
        }
      }());
    }
    await Future.wait(workers);
    return results.cast<T>();
  }

  Future<bool> _resolveDraftAttachmentSource({
    required String pendingId,
    required Future<ComposerAttachmentStage> stagedFuture,
    required CancelableCompleter<void> cancellation,
  }) async {
    final ({bool canceled, ComposerAttachmentStage? stage}) stagedResult;
    try {
      stagedResult = await _awaitDraftAttachmentStage(
        stagedFuture,
        cancellation: cancellation,
      );
    } on ComposerAttachmentStagingException {
      _removeDraftPendingAttachmentPlaceholder(pendingId);
      if (mounted && !cancellation.isCanceled) {
        _showToast(context.l10n.draftAttachmentFailed);
      }
      return false;
    }
    if (stagedResult.canceled) {
      _removeDraftPendingAttachmentPlaceholder(pendingId);
      return false;
    }
    final staged = stagedResult.stage;
    if (staged == null) {
      _removeDraftPendingAttachmentPlaceholder(pendingId);
      return false;
    }
    if (!mounted) {
      await deleteComposerStagedAttachment(staged.staged);
      return false;
    }
    final replaced = _replaceDraftPendingAttachment(
      PendingAttachment(
        id: pendingId,
        attachment: staged.attachment.copyWith(metadataId: pendingId),
        stagedAttachment: staged.staged,
      ),
    );
    if (!replaced) {
      await deleteComposerStagedAttachment(staged.staged);
      return false;
    }
    return true;
  }

  bool _replaceDraftPendingAttachment(PendingAttachment pending) {
    if (!mounted) {
      return false;
    }
    final index = _pendingAttachments.indexWhere(
      (candidate) => candidate.id == pending.id,
    );
    if (index == -1) {
      return false;
    }
    setState(() {
      final updated = List<PendingAttachment>.from(_pendingAttachments);
      updated[index] = pending;
      _pendingAttachments = updated;
    });
    return true;
  }

  void _removeDraftPendingAttachmentPlaceholder(String pendingId) {
    if (!mounted) {
      return;
    }
    setState(() {
      _pendingAttachments = _pendingAttachments
          .where((pending) => pending.id != pendingId)
          .toList();
    });
  }

  Future<({bool canceled, ComposerAttachmentStage? stage})>
  _awaitDraftAttachmentStage(
    Future<ComposerAttachmentStage> stageFuture, {
    required CancelableCompleter<void> cancellation,
  }) async {
    final canceled = Object();
    final result = await Future.any<Object?>([
      stageFuture,
      cancellation.operation.valueOrCancellation().then<Object?>(
        (_) => canceled,
      ),
    ]);
    if (!identical(result, canceled)) {
      return (canceled: false, stage: result as ComposerAttachmentStage);
    }
    unawaited(
      stageFuture.then(
        (stage) => deleteComposerStagedAttachment(stage.staged),
        onError: (_) {},
      ),
    );
    return (canceled: true, stage: null);
  }

  void _handlePendingAttachmentRemoved(String id) {
    final removed = _pendingAttachments
        .where((pending) => pending.id == id)
        .toList(growable: false);
    final deleteDraftAttachmentMetadata = context
        .read<DraftCubit>()
        .deleteDraftAttachmentMetadata;
    setState(() {
      _latestEmailRecipientStatuses = const {};
      _partialSendNoticeVisible = false;
      _clearRetryForceEmail();
      _pendingAttachments = _pendingAttachments
          .where((pending) => pending.id != id)
          .toList();
    });
    unawaited(
      _releaseDraftComposerPendingAttachments(
        removed,
        deleteDraftAttachmentMetadata,
      ),
    );
    _scheduleAutosave();
  }

  Future<void> _handleSaveDraft() async {
    if (_savingDraft) return;
    await _awaitAttachmentWorkIfNeeded();
    await _awaitAutosaveIfNeeded();
    if (!mounted || _savingDraft) {
      return;
    }
    setState(() => _savingDraft = true);
    try {
      await _saveDraft(autoSave: false);
    } finally {
      if (mounted) {
        setState(() => _savingDraft = false);
      }
    }
  }

  Future<void> _handleAutosaveEnabledChanged(bool enabled) async {
    if (_autosaveEnabled == enabled ||
        _updatingAutosavePreference ||
        _autosaveInFlight) {
      return;
    }
    final previous = _autosaveEnabled;
    final draftId = id;
    setState(() {
      _autosaveEnabled = enabled;
      _updatingAutosavePreference = draftId != null;
      if (!enabled) {
        _lastAutosaveAt = null;
      }
    });
    _autosaveTimer?.cancel();
    if (!enabled) {
      _autosaveSavedIndicatorTimer?.cancel();
      _autosaveSavedIndicatorTimer = null;
    }
    if (enabled) {
      _scheduleAutosave();
    }
    if (draftId == null) {
      return;
    }
    try {
      await context.read<DraftCubit>().updateDraftAutosaveEnabled(
        id: draftId,
        enabled: enabled,
      );
    } on Exception {
      if (!mounted) return;
      setState(() => _autosaveEnabled = previous);
      _autosaveTimer?.cancel();
      if (previous) {
        _scheduleAutosave();
      }
    } finally {
      if (mounted) {
        setState(() => _updatingAutosavePreference = false);
      }
    }
  }

  Future<void> _saveDraft({required bool autoSave}) async {
    final int saveEpoch = _saveEpoch;
    final bool wasNewDraft = id == null;
    final List<PendingAttachment> pendingAttachments = List.of(
      _pendingAttachments,
    );
    final List<String> attachmentIds = pendingAttachments
        .map((pending) => pending.id)
        .toList();
    final List<String> recipients = _recipientStrings();
    _syncConvertedForwardBlocksFromBody();
    final String body = _draftIntroText();
    final String subject = _subjectTextController.text;
    final DraftQuoteTarget? quoteTarget = widget.quoteTarget;
    final List<Attachment> attachments = pendingAttachments
        .map((pending) => pending.attachment)
        .toList();
    final int signature = _draftSignature(
      recipients: recipients,
      body: body,
      subject: subject,
      quoteTarget: quoteTarget,
      pendingAttachments: pendingAttachments,
      calendarTaskIcsMessage: _pendingCalendarTaskIcsMessage,
      forwardedBlocks: _forwardedBlocks,
    );
    final draftCubit = context.read<DraftCubit>();
    final draft = await draftCubit.saveDraft(
      id: id,
      jids: recipients,
      body: body,
      subject: subject,
      quoteTarget: quoteTarget,
      attachments: attachments,
      calendarTaskIcsMessage: _pendingCalendarTaskIcsMessage,
      forwardedBlocks: _forwardedBlocks,
      autoSave: autoSave,
      autosaveEnabled: _autosaveEnabled,
    );
    if (!mounted || saveEpoch != _saveEpoch) return;
    await _applySavedDraftAttachmentMetadata(
      draft: draft,
      draftCubit: draftCubit,
      cleanupStaleSeedAttachments: wasNewDraft,
      saveEpoch: saveEpoch,
    );
    if (!mounted || saveEpoch != _saveEpoch) return;
    final draftCount = !autoSave && wasNewDraft
        ? await draftCubit.countDrafts()
        : null;
    if (!mounted || saveEpoch != _saveEpoch) return;
    setState(() {
      id = draft.id;
      _lastSavedSignature = signature;
      _lastAutosaveAt = autoSave ? DateTime.now() : null;
    });
    if (autoSave) {
      _scheduleAutosaveSavedIndicatorDismissal();
    } else {
      _autosaveSavedIndicatorTimer?.cancel();
      _autosaveSavedIndicatorTimer = null;
    }
    widget.onDraftSaved?.call(draft.id);
    if (!autoSave &&
        wasNewDraft &&
        draftCount != null &&
        draftCount >= draftSyncWarningThreshold) {
      ShadToaster.maybeOf(context)?.show(
        FeedbackToast.warning(
          message: context.l10n.draftLimitWarning(
            draftSyncMaxItems,
            draftCount,
          ),
        ),
      );
    }
    await _applyAttachmentMetadataIds(
      metadataIds: draft.attachmentMetadata.values,
      expectedAttachmentIds: attachmentIds,
      saveEpoch: saveEpoch,
    );
    if (!mounted) return;
  }

  Future<void> _applySavedDraftAttachmentMetadata({
    required Draft draft,
    required DraftCubit draftCubit,
    required bool cleanupStaleSeedAttachments,
    required int saveEpoch,
  }) async {
    if (!mounted || saveEpoch != _saveEpoch) {
      return;
    }
    final previousSeedMetadataIds = _normalizedMetadataIds(
      _seedAttachmentMetadataIds,
    );
    final savedMetadataIds = _normalizedMetadataIds(
      draft.attachmentMetadata.values,
    );
    _seedAttachmentMetadataIds = savedMetadataIds;
    if (!cleanupStaleSeedAttachments) {
      return;
    }
    _seedAttachmentCleanupHandled = true;
    final retainedMetadataIds = savedMetadataIds.toSet();
    await _deleteAttachmentMetadataIds(
      draftCubit.deleteDraftAttachmentMetadata,
      previousSeedMetadataIds.where(
        (metadataId) => !retainedMetadataIds.contains(metadataId),
      ),
    );
    if (!mounted || saveEpoch != _saveEpoch) {
      return;
    }
  }

  List<String> _normalizedMetadataIds(Iterable<String?> metadataIds) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final metadataId in metadataIds) {
      final trimmed = metadataId?.trim();
      if (trimmed == null || trimmed.isEmpty || !seen.add(trimmed)) {
        continue;
      }
      normalized.add(trimmed);
    }
    return normalized;
  }

  void _scheduleAutosave() {
    if (!mounted) {
      return;
    }
    if (!_autosaveEnabled) {
      _autosaveTimer?.cancel();
      return;
    }
    if (context.read<DraftCubit>().isSendOwnerActive(_sendOwnerId)) {
      return;
    }
    if (_savingDraft || _discardingDraft) {
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
    _autosaveSavedIndicatorTimer?.cancel();
    _autosaveSavedIndicatorTimer = null;
    _lastAutosaveAt = null;
  }

  void _scheduleAutosaveSavedIndicatorDismissal() {
    _autosaveSavedIndicatorTimer?.cancel();
    _autosaveSavedIndicatorTimer = Timer(const Duration(seconds: 3), () {
      _autosaveSavedIndicatorTimer = null;
      if (!mounted || _lastAutosaveAt == null) {
        return;
      }
      setState(() => _lastAutosaveAt = null);
    });
  }

  void _invalidateAttachmentWork() {
    final hydrationCancellation = _attachmentHydrationCancellation;
    _attachmentHydrationCancellation = null;
    if (hydrationCancellation != null) {
      hydrationCancellation.operation.cancel();
    }
    final preparationCancellation = _attachmentPreparationCancellation;
    _attachmentPreparationCancellation = null;
    if (preparationCancellation != null) {
      preparationCancellation.operation.cancel();
    }
    _attachmentHydrationOperation = null;
    _attachmentPreparationOperation = null;
    _loadingAttachments = false;
    _addingAttachment = false;
  }

  int? _savedSignatureFromSeed() {
    if (widget.id == null) {
      return null;
    }
    final recipients =
        widget.initialRecipients.includedRecipients.recipientAddresses;
    final attachmentIds = _seedAttachmentMetadataIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    return Object.hashAll(<Object?>[
      widget.body,
      widget.subject,
      widget.quoteTarget?.stanzaId,
      ...recipients,
      ...attachmentIds,
      _calendarTaskSignature(widget.calendarTaskIcsMessage),
      _forwardedBlocksSignature(_forwardedBlocks),
    ]);
  }

  Future<void> _awaitAutosaveIfNeeded() async {
    final operation = _autosaveOperation;
    if (operation == null) {
      return;
    }
    try {
      await operation;
    } on Exception {
      // Best-effort wait for any in-flight autosave before closing/discarding.
    }
  }

  Future<void> _drainDiscardedAutosave(Future<void> operation) async {
    try {
      await operation;
    } on Exception {
      // Autosave failures remain best-effort after the composer is closed.
    }
  }

  Future<void> _releaseDraftComposerAttachmentsAfterAutosave({
    required Future<void>? autosaveOperation,
    required Future<void> Function(String) deleteDraftAttachmentMetadata,
    required List<PendingAttachment> pendingAttachments,
  }) async {
    if (autosaveOperation != null) {
      await _drainDiscardedAutosave(autosaveOperation);
    }
    await _releaseDraftComposerPendingAttachments(
      pendingAttachments,
      deleteDraftAttachmentMetadata,
    );
    await _cleanupSeedAttachmentMetadata(deleteDraftAttachmentMetadata);
  }

  Future<void> _awaitAttachmentWorkIfNeeded({bool bestEffort = true}) async {
    while (true) {
      final hydrationOperation = _attachmentHydrationOperation;
      if (hydrationOperation != null) {
        try {
          await hydrationOperation;
        } on Exception {
          if (!bestEffort) {
            rethrow;
          }
          // Best-effort wait for attachment hydration before closing/discarding.
        }
        continue;
      }
      final preparationOperation = _attachmentPreparationOperation;
      if (preparationOperation == null) {
        return;
      }
      try {
        await preparationOperation;
      } on Exception {
        if (!bestEffort) {
          rethrow;
        }
        // Best-effort wait for attachment preparation before closing/discarding.
      }
    }
  }

  Future<void> _handleAutosaveTick() async {
    if (!mounted || _autosaveInFlight) {
      return;
    }
    if (!_autosaveEnabled) {
      return;
    }
    if (context.read<DraftCubit>().isSendOwnerActive(_sendOwnerId)) {
      return;
    }
    if (!_hasDraftableContent()) {
      return;
    }
    if (!_shouldAutosave()) {
      return;
    }
    final int signature = _currentDraftSignature();
    if (_lastSavedSignature == signature) {
      return;
    }
    setState(() => _autosaveInFlight = true);
    final int attemptedSaveEpoch = _saveEpoch;
    final int attemptedSignature = signature;
    final operation = _saveDraft(autoSave: true);
    _autosaveOperation = operation;
    try {
      await operation;
    } on Exception {
      // Best-effort autosave should not block composition.
    } finally {
      if (mounted) {
        setState(() {
          if (_autosaveOperation == operation) {
            _autosaveOperation = null;
          }
          _autosaveInFlight = false;
        });
      } else {
        if (_autosaveOperation == operation) {
          _autosaveOperation = null;
        }
        _autosaveInFlight = false;
      }
    }
    if (mounted &&
        _saveEpoch == attemptedSaveEpoch &&
        _currentDraftSignature() != attemptedSignature) {
      _scheduleAutosave();
    }
  }

  bool _shouldAutosave() {
    if (!_autosaveEnabled) {
      return false;
    }
    if (_pendingAttachments.any((pending) => pending.isPreparing)) {
      return false;
    }
    return _hasDraftableContent();
  }

  bool _hasDraftableContent() {
    final String body = _bodyTextController.text.trim();
    final String subject = _subjectTextController.text.trim();
    final bool hasAttachments = _pendingAttachments.isNotEmpty;
    final recipientCount = _recipientStrings().length;
    var effectiveRecipientCount =
        recipientCount - widget.recipientCountAdjustment;
    if (effectiveRecipientCount < 0) {
      effectiveRecipientCount = 0;
    }
    final bool hasRecipients = effectiveRecipientCount > 0;
    return hasRecipients ||
        _hasMeaningfulBodyText(body) ||
        subject.isNotEmpty ||
        widget.quoteTarget != null ||
        hasAttachments ||
        _pendingCalendarTaskIcsMessage != null ||
        _forwardedBlocks.isNotEmpty;
  }

  int _currentDraftSignature() {
    final recipients = _recipientStrings();
    _syncConvertedForwardBlocksFromBody();
    return _draftSignature(
      recipients: recipients,
      body: _draftIntroText(),
      subject: _subjectTextController.text,
      quoteTarget: widget.quoteTarget,
      pendingAttachments: _pendingAttachments,
      calendarTaskIcsMessage: _pendingCalendarTaskIcsMessage,
      forwardedBlocks: _forwardedBlocks,
    );
  }

  String _draftIntroText() {
    if (_convertedForwardRanges.isEmpty) {
      return _bodyTextController.text;
    }
    final bodyText = _bodyTextController.text;
    final ranges = _convertedForwardRanges.values.toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    var introText = bodyText;
    for (final range in ranges) {
      final removal = _convertedForwardRemovalRange(range, introText);
      introText = introText.replaceRange(removal.start, removal.end, '');
    }
    return _collapseTrailingForwardSeparators(introText);
  }

  String _outgoingPreviewText() {
    return DraftForwardedContent.compose(
      introText: _draftIntroText(),
      forwardedBlocks: _forwardedBlocks,
    ).plainText;
  }

  String _collapseTrailingForwardSeparators(String value) {
    return value.replaceFirst(RegExp(r'\n{3,}$'), '\n\n');
  }

  ({int start, int end}) _convertedForwardRemovalRange(
    _ConvertedForwardRange range,
    String bodyText,
  ) {
    var start = range.start.clamp(0, bodyText.length).toInt();
    final end = range.end.clamp(start, bodyText.length).toInt();
    if (start >= 2 && bodyText.substring(start - 2, start) == '\n\n') {
      final before = bodyText.substring(0, start - 2);
      if (before.trim().isNotEmpty) {
        start -= 2;
      }
    }
    return (start: start, end: end);
  }

  int _draftSignature({
    required List<String> recipients,
    required String body,
    required String subject,
    required DraftQuoteTarget? quoteTarget,
    required List<PendingAttachment> pendingAttachments,
    required CalendarTaskIcsMessage? calendarTaskIcsMessage,
    required List<DraftForwardedBlock> forwardedBlocks,
  }) {
    final List<Object?> values = <Object?>[
      body,
      subject,
      quoteTarget?.stanzaId,
      ...recipients,
      ...pendingAttachments.map(
        (pending) => _attachmentSignature(pending.attachment),
      ),
      _calendarTaskSignature(calendarTaskIcsMessage),
      _forwardedBlocksSignature(forwardedBlocks),
    ];
    return Object.hashAll(values);
  }

  Object? _calendarTaskSignature(CalendarTaskIcsMessage? message) {
    if (message == null) {
      return null;
    }
    return Object.hash(message.task, message.readOnly);
  }

  Object _forwardedBlocksSignature(List<DraftForwardedBlock> blocks) {
    return Object.hashAll(
      blocks.map(
        (block) => Object.hash(
          block.blockId,
          block.sourceMessageId,
          block.senderJid,
          block.senderLabel,
          block.timestamp,
          block.originalSubject,
          block.originalPlainText,
          block.originalHtml,
          block.quotedContext?.senderLabel,
          block.quotedContext?.plainText,
          block.conversionState,
          block.convertedText,
        ),
      ),
    );
  }

  Object _attachmentSignature(Attachment attachment) {
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
    required int saveEpoch,
  }) async {
    if (!mounted || saveEpoch != _saveEpoch || metadataIds.isEmpty) {
      return;
    }
    final metadataIdsByPendingId = <String, String>{};
    final metadataCount = metadataIds.length;
    final expectedCount = expectedAttachmentIds.length;
    final count = metadataCount < expectedCount ? metadataCount : expectedCount;
    for (var index = 0; index < count; index += 1) {
      final pendingId = expectedAttachmentIds[index].trim();
      final metadataId = metadataIds[index].trim();
      if (pendingId.isEmpty || metadataId.isEmpty) {
        continue;
      }
      metadataIdsByPendingId[pendingId] = metadataId;
    }
    if (metadataIdsByPendingId.isEmpty) {
      return;
    }
    await _reconcileCurrentDraftPendingAttachments(
      context.read<DraftCubit>(),
      metadataIdsByPendingId: metadataIdsByPendingId,
      saveEpoch: saveEpoch,
    );
  }

  Future<void> _handleDiscard() async {
    final draftCubit = context.read<DraftCubit>();
    final draftId = id;
    if (_discardingDraft) return;
    final autosaveOperation = _autosaveOperation;
    final pendingAttachments = List<PendingAttachment>.from(
      _pendingAttachments,
    );
    _autosaveTimer?.cancel();
    _invalidatePendingSaves();
    _invalidateAttachmentWork();
    _autosaveOperation = null;
    _autosaveInFlight = false;
    setState(() => _discardingDraft = true);
    final onDiscarded = widget.onDiscarded;
    if (onDiscarded != null) {
      onDiscarded();
    } else {
      _closeComposer();
    }
    if (draftId != null) {
      try {
        await draftCubit.deleteDraft(id: draftId);
      } on Exception {
        // Best-effort after local close; the discarded form should stay closed.
      }
    }
    unawaited(
      _releaseDraftComposerAttachmentsAfterAutosave(
        autosaveOperation: autosaveOperation,
        deleteDraftAttachmentMetadata: draftCubit.deleteDraftAttachmentMetadata,
        pendingAttachments: pendingAttachments,
      ),
    );
    if (mounted) {
      _showToast(context.l10n.draftDiscarded);
      setState(() => _discardingDraft = false);
    }
  }

  Future<void> _discardUnsavedChangesAndClose() async {
    final draftCubit = context.read<DraftCubit>();
    if (_discardingDraft) return;
    final autosaveOperation = _autosaveOperation;
    final pendingAttachments = List<PendingAttachment>.from(
      _pendingAttachments,
    );
    _autosaveTimer?.cancel();
    _invalidatePendingSaves();
    _invalidateAttachmentWork();
    _autosaveOperation = null;
    _autosaveInFlight = false;
    setState(() => _discardingDraft = true);
    final onDiscarded = widget.onDiscarded;
    if (onDiscarded != null) {
      onDiscarded();
    } else {
      _closeComposer();
    }
    unawaited(
      _releaseDraftComposerAttachmentsAfterAutosave(
        autosaveOperation: autosaveOperation,
        deleteDraftAttachmentMetadata: draftCubit.deleteDraftAttachmentMetadata,
        pendingAttachments: pendingAttachments,
      ),
    );
    if (mounted) {
      setState(() => _discardingDraft = false);
    }
  }

  Future<bool> handleCloseRequest() async {
    if (_savingDraft ||
        _discardingDraft ||
        context.read<DraftCubit>().isSendOwnerActive(_sendOwnerId)) {
      return false;
    }
    _autosaveTimer?.cancel();
    if (!_shouldPromptBeforeClose()) {
      final autosaveOperation = _autosaveOperation;
      _invalidatePendingSaves();
      _autosaveOperation = null;
      _autosaveInFlight = false;
      _closeComposer();
      if (autosaveOperation != null) {
        unawaited(_drainDiscardedAutosave(autosaveOperation));
      }
      return true;
    }
    final action = await _confirmCloseAction();
    if (!mounted || action == null || action == _DraftFormCloseAction.cancel) {
      _scheduleAutosave();
      return false;
    }
    if (action == _DraftFormCloseAction.discard) {
      await _discardUnsavedChangesAndClose();
      return true;
    }
    final closed = await _saveDraftAndClose();
    if (!closed) {
      _scheduleAutosave();
    }
    return closed;
  }

  bool _shouldPromptBeforeClose() {
    if (_loadingAttachments) {
      return true;
    }
    final savedSignature = _lastSavedSignature;
    if (savedSignature != null) {
      return savedSignature != _currentDraftSignature();
    }
    return _hasDraftableContent();
  }

  Future<_DraftFormCloseAction?> _confirmCloseAction() {
    final l10n = context.l10n;
    return showFadeScaleDialog<_DraftFormCloseAction>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final pop = Navigator.of(dialogContext).pop;
        return AxiDialog(
          constraints: BoxConstraints(
            maxWidth: dialogContext.sizing.dialogMaxWidth,
          ),
          title: Text(
            l10n.draftUnsavedChangesTitle,
            style: dialogContext.modalHeaderTextStyle,
          ),
          actions: [
            AxiButton.outline(
              onPressed: () => pop(_DraftFormCloseAction.cancel),
              child: Text(l10n.commonCancel),
            ),
            AxiButton.destructive(
              onPressed: () => pop(_DraftFormCloseAction.discard),
              child: Text(l10n.draftDiscard),
            ),
            AxiButton.primary(
              onPressed: () => pop(_DraftFormCloseAction.save),
              child: Text(l10n.draftSave),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _saveDraftAndClose() async {
    if (_savingDraft) {
      return false;
    }
    setState(() => _savingDraft = true);
    try {
      await _awaitAttachmentWorkIfNeeded();
      await _awaitAutosaveIfNeeded();
      if (!mounted) {
        return false;
      }
      await _saveDraft(autoSave: false);
    } on Exception {
      if (mounted) {
        _showToast(context.l10n.chatDraftSaveFailed);
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _savingDraft = false);
      }
    }
    if (!mounted) {
      return false;
    }
    _closeComposer();
    return true;
  }

  void _closeComposer() {
    final onClosed = widget.onClosed;
    if (onClosed != null) {
      onClosed();
      return;
    }
    if (Navigator.of(context).canPop()) {
      context.pop();
    }
  }

  Future<void> _cleanupSeedAttachmentMetadata(
    Future<void> Function(String) deleteDraftAttachmentMetadata,
  ) async {
    if (!_shouldCleanupSeedAttachments) {
      return;
    }
    _seedAttachmentCleanupHandled = true;
    final List<String> metadataIds = _seedAttachmentMetadataIds;
    if (metadataIds.isEmpty) {
      return;
    }
    await _deleteAttachmentMetadataIds(
      deleteDraftAttachmentMetadata,
      metadataIds,
    );
  }

  Future<void> _deleteAttachmentMetadataIds(
    Future<void> Function(String) deleteDraftAttachmentMetadata,
    Iterable<String?> metadataIds,
  ) async {
    final released = <String>{};
    for (final metadataId in metadataIds) {
      final normalized = metadataId?.trim();
      if (normalized == null || normalized.isEmpty) {
        continue;
      }
      if (!released.add(normalized)) {
        continue;
      }
      try {
        await deleteDraftAttachmentMetadata(normalized);
      } on Exception {
        // Best-effort cleanup for abandoned compose attachment metadata.
      }
    }
  }

  Future<bool> _confirmEmailSendIfNeeded({
    required SettingsCubit settingsCubit,
    required List<String> recipients,
    required String body,
    required List<String> attachmentNames,
  }) async {
    if (!settingsCubit.state.emailSendConfirmationEnabled) {
      return true;
    }
    final decision = await confirmEmailSend(
      context,
      recipients: recipients,
      body: body,
      attachmentNames: attachmentNames,
    );
    if (!mounted || decision == null || !decision.confirmed) {
      return false;
    }
    if (decision.dontShowAgain) {
      settingsCubit.toggleEmailSendConfirmation(false);
    }
    return true;
  }

  Future<void> _handleSendButtonLongPress() async {
    final action = await showAdaptiveBottomSheet<_DraftSendAction>(
      context: context,
      preferDialogOnMobile: true,
      requestFocus: false,
      surfacePadding: EdgeInsets.zero,
      builder: (dialogContext) {
        return AxiSheetScaffold.scroll(
          header: AxiSheetHeader(
            title: Text(dialogContext.l10n.commonActions),
            onClose: () => Navigator.of(dialogContext).maybePop(),
          ),
          children: [
            AxiListButton(
              leading: const Icon(LucideIcons.mail),
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_DraftSendAction.sendAsEmail),
              child: Text(dialogContext.l10n.chatSendAsEmail),
            ),
          ],
        );
      },
    );
    if (!mounted) {
      return;
    }
    _bodyFocusNode.requestFocus();
    if (action == _DraftSendAction.sendAsEmail) {
      await _handleSendDraft(forceEmail: true);
    }
  }

  Future<void> _handleSendDraft({bool forceEmail = false}) async {
    final draftCubit = context.read<DraftCubit>();
    if (!draftCubit.beginSendPreparation(_sendOwnerId)) {
      return;
    }
    final effectiveForceEmail = forceEmail || _retryForceEmail;
    _autosaveTimer?.cancel();
    setState(() {
      _showValidationMessages = true;
      _sendErrorMessage = null;
      _latestEmailRecipientStatuses = const {};
      _partialSendNoticeVisible = false;
      _sendCompletionHandled = false;
    });
    try {
      await _awaitAttachmentWorkIfNeeded(bestEffort: false);
      await _awaitAutosaveIfNeeded();
    } on Exception {
      draftCubit.cancelSendPreparation(_sendOwnerId);
      if (!mounted) return;
      setState(() {
        _pendingAttachments = _resetUploadingPendingAttachments();
      });
      _showToast(context.l10n.draftAttachmentFailed);
      return;
    }
    if (!mounted) {
      draftCubit.cancelSendPreparation(_sendOwnerId);
      return;
    }
    _invalidatePendingSaves();
    if (_addingAttachment ||
        _pendingAttachments.any((pending) => pending.isPreparing)) {
      draftCubit.cancelSendPreparation(_sendOwnerId);
      setState(() {
        _pendingAttachments = _resetUploadingPendingAttachments();
      });
      return;
    }
    final settingsCubit = context.read<SettingsCubit>();
    final settingsState = settingsCubit.state;
    final endpointConfig = settingsState.endpointConfig;
    if (!effectiveForceEmail) {
      final transportsReady = await _ensureRecipientTransports();
      if (!mounted) {
        draftCubit.cancelSendPreparation(_sendOwnerId);
        return;
      }
      if (!transportsReady) {
        draftCubit.cancelSendPreparation(_sendOwnerId);
        setState(() {
          _pendingAttachments = _resetUploadingPendingAttachments();
        });
        return;
      }
    }
    _syncConvertedForwardBlocksFromBody();
    final includedRecipients = _recipients.includedRecipients;
    final partition = effectiveForceEmail
        ? includedRecipients.forcedEmailPartition(
            emailDomain: endpointConfig.domain,
          )
        : includedRecipients.sendPartition;
    if (partition == null) {
      draftCubit.cancelSendPreparation(_sendOwnerId);
      setState(() {
        _sendErrorMessage = context.l10n.chatComposerEmailRecipientUnavailable;
        _pendingAttachments = _resetUploadingPendingAttachments();
      });
      return;
    }
    if (partition.pending.isNotEmpty || partition.unresolved.isNotEmpty) {
      draftCubit.cancelSendPreparation(_sendOwnerId);
      setState(() {
        _sendErrorMessage = context.l10n.chatComposerDraftRecipientsUnavailable;
        _pendingAttachments = _resetUploadingPendingAttachments();
      });
      return;
    }
    final validationMessage = _sendValidationMessage(
      hasActiveRecipients: includedRecipients.isNotEmpty,
      hasContent: _hasContent(),
      emailRecipientsUnavailable:
          !endpointConfig.smtpEnabled && partition.email.isNotEmpty,
      recipients: includedRecipients,
      emailRecipientCount: partition.email.length,
    );
    final formValid = _formKey.currentState?.validate() ?? false;
    if (validationMessage != null || !formValid) {
      draftCubit.cancelSendPreparation(_sendOwnerId);
      setState(() {
        _pendingAttachments = _resetUploadingPendingAttachments();
      });
      return;
    }
    if (partition.email.isNotEmpty) {
      final shouldSend = await _confirmEmailSendIfNeeded(
        settingsCubit: settingsCubit,
        recipients: _recipientStrings(),
        body: _outgoingPreviewText(),
        attachmentNames: _currentAttachments()
            .map((attachment) => attachment.fileName)
            .toList(growable: false),
      );
      if (!mounted || !shouldSend) {
        draftCubit.cancelSendPreparation(_sendOwnerId);
        if (mounted) {
          setState(() {
            _pendingAttachments = _resetUploadingPendingAttachments();
          });
        }
        return;
      }
    }
    await _reconcileCurrentDraftPendingAttachments(draftCubit);
    if (!mounted) {
      draftCubit.cancelSendPreparation(_sendOwnerId);
      return;
    }
    _syncConvertedForwardBlocksFromBody();
    final submittedAttachments = List<PendingAttachment>.from(
      _pendingAttachments,
    );
    _markDraftAttachmentsSubmittedForSend(submittedAttachments);
    final DraftSendOutcome outcome;
    try {
      outcome = await draftCubit.sendDraft(
        id: id,
        xmppTargets: partition.xmpp,
        emailTargets: partition.email,
        body: _draftIntroText(),
        shareTokenSignatureEnabled: settingsState.shareTokenSignatureEnabled,
        ownerId: _sendOwnerId,
        subject: _subjectTextController.text,
        quoteTarget: widget.quoteTarget,
        attachments: submittedAttachments
            .map((pending) => pending.attachment)
            .toList(growable: false),
        calendarTaskIcsMessage: _pendingCalendarTaskIcsMessage,
        forwardedBlocks: List<DraftForwardedBlock>.from(
          _forwardedBlocks,
          growable: false,
        ),
      );
    } finally {
      _releaseDraftAttachmentsSubmittedForSend(submittedAttachments);
    }
    if (!mounted) {
      await _releaseDraftComposerPendingAttachments(
        submittedAttachments,
        draftCubit.deleteDraftAttachmentMetadata,
      );
      return;
    }
    if (!outcome.succeeded) {
      final recipientCountBeforeFailure = _recipients.length;
      final partialSend = outcome.incomplete;
      final failureType =
          outcome.failureType ?? DraftSendFailureType.sendFailed;
      final failureMessage = partialSend
          ? null
          : _draftFailureMessage(failureType, context.l10n);
      final pendingAttachments = await _reconcileDraftPendingAttachments(
        _resetUploadingPendingAttachments(),
        draftCubit,
      );
      if (!mounted) {
        await _releaseDraftComposerPendingAttachments(
          pendingAttachments,
          draftCubit.deleteDraftAttachmentMetadata,
        );
        return;
      }
      setState(() {
        if (outcome.incomplete) {
          _applyIncompleteRecipientsForSendOutcome(outcome);
        }
        _retryForceEmail = outcome.incomplete && effectiveForceEmail;
        _latestEmailRecipientStatuses = outcome.latestEmailRecipientStatuses;
        _partialSendNoticeVisible = partialSend;
        _sendErrorMessage = failureMessage;
        _pendingAttachments = pendingAttachments;
        _sendCompletionHandled = true;
      });
      if (partialSend || recipientCountBeforeFailure != _recipients.length) {
        _notifyRecipientAddressesChanged();
        _revalidateFormIfNeeded();
        _scheduleAutosave();
      }
      _bodyFocusNode.requestFocus();
      return;
    }
    await _handleSendComplete();
  }

  Future<void> _handleSendComplete() async {
    if (_sendCompletionHandled) {
      return;
    }
    _sendCompletionHandled = true;
    if (!mounted) return;
    final deleteDraftAttachmentMetadata = context
        .read<DraftCubit>()
        .deleteDraftAttachmentMetadata;
    final sentAttachments = List<PendingAttachment>.from(_pendingAttachments);
    setState(() {
      _retryForceEmail = false;
      _pendingAttachments = const [];
      _pendingCalendarTaskIcsMessage = null;
      _partialSendNoticeVisible = false;
      _lastAutosaveAt = null;
      _lastSavedSignature = null;
      _seedAttachmentCleanupHandled = true;
    });
    await _releaseDraftComposerPendingAttachments(
      sentAttachments,
      deleteDraftAttachmentMetadata,
    );
    if (!mounted) {
      return;
    }
    ShadToaster.maybeOf(
      context,
    )?.show(FeedbackToast.success(title: context.l10n.draftSent));
    _closeComposer();
  }

  List<String> _recipientStrings() {
    return _recipients.includedRecipients.recipientAddresses;
  }

  Future<void> _deleteDraftStagedAttachments(
    Iterable<PendingAttachment> pendingAttachments,
  ) async {
    for (final pending in pendingAttachments) {
      final staged = pending.stagedAttachment;
      if (staged == null) {
        continue;
      }
      await deleteComposerStagedAttachment(staged);
    }
  }

  Future<void> _releaseDraftComposerPendingAttachments(
    Iterable<PendingAttachment> pendingAttachments,
    Future<void> Function(String) deleteDraftAttachmentMetadata,
  ) async {
    final pendingList = pendingAttachments.toList(growable: false);
    await _deleteDraftStagedAttachments(pendingList);
    await _deleteAttachmentMetadataIds(
      deleteDraftAttachmentMetadata,
      pendingList.map((pending) => pending.attachment.metadataId),
    );
  }

  Set<String> _submittedKeysForPendingAttachments(
    Iterable<PendingAttachment> pendingAttachments,
  ) {
    final keys = <String>{};
    for (final pending in pendingAttachments) {
      final pendingId = pending.id.trim();
      if (pendingId.isNotEmpty) {
        keys.add('pending:$pendingId');
      }
      final metadataId = pending.attachment.metadataId?.trim();
      if (metadataId != null && metadataId.isNotEmpty) {
        keys.add('metadata:$metadataId');
      }
      final stagedPath = pending.stagedAttachment?.path.trim();
      if (stagedPath != null && stagedPath.isNotEmpty) {
        keys.add('staged:$stagedPath');
      }
    }
    return keys;
  }

  List<PendingAttachment> _unsubmittedDraftPendingAttachments() {
    return _pendingAttachments
        .where((pending) {
          final submittedKeys = _submittedKeysForPendingAttachments([pending]);
          return submittedKeys.isEmpty ||
              submittedKeys.every(
                (key) => !_draftSubmittedAttachmentKeys.contains(key),
              );
        })
        .toList(growable: false);
  }

  void _markDraftAttachmentsSubmittedForSend(
    Iterable<PendingAttachment> pendingAttachments,
  ) {
    final submittedKeys = _submittedKeysForPendingAttachments(
      pendingAttachments,
    );
    if (submittedKeys.isEmpty) {
      return;
    }
    _draftSubmittedAttachmentKeys = {
      ..._draftSubmittedAttachmentKeys,
      ...submittedKeys,
    };
  }

  void _releaseDraftAttachmentsSubmittedForSend(
    Iterable<PendingAttachment> pendingAttachments,
  ) {
    final submittedKeys = _submittedKeysForPendingAttachments(
      pendingAttachments,
    );
    if (submittedKeys.isEmpty || _draftSubmittedAttachmentKeys.isEmpty) {
      return;
    }
    _draftSubmittedAttachmentKeys = {
      for (final key in _draftSubmittedAttachmentKeys)
        if (!submittedKeys.contains(key)) key,
    };
  }

  Future<List<PendingAttachment>> _reconcileDraftPendingAttachments(
    Iterable<PendingAttachment> pendingAttachments,
    DraftCubit draftCubit, {
    Map<String, String>? metadataIdsByPendingId,
  }) async {
    final pendingList = pendingAttachments.toList(growable: false);
    final indexes = <int>[];
    final metadataIds = <String>[];
    for (var index = 0; index < pendingList.length; index += 1) {
      final pending = pendingList[index];
      if (pending.stagedAttachment == null) {
        continue;
      }
      final metadataId =
          metadataIdsByPendingId?[pending.id]?.trim() ??
          pending.attachment.metadataId?.trim();
      if (metadataId == null || metadataId.isEmpty) {
        continue;
      }
      indexes.add(index);
      metadataIds.add(metadataId);
    }
    if (metadataIds.isEmpty) {
      return pendingList;
    }
    final attachments = await draftCubit.loadDraftAttachments(metadataIds);
    final attachmentByMetadataId = {
      for (final attachment in attachments)
        if (attachment.metadataId?.trim().isNotEmpty == true)
          attachment.metadataId!.trim(): attachment,
    };
    if (attachmentByMetadataId.isEmpty) {
      return pendingList;
    }
    final updated = List<PendingAttachment>.from(pendingList);
    for (var index = 0; index < metadataIds.length; index += 1) {
      final attachment = attachmentByMetadataId[metadataIds[index]];
      if (attachment == null) {
        continue;
      }
      final pendingIndex = indexes[index];
      final pending = pendingList[pendingIndex];
      updated[pendingIndex] = pending.copyWith(
        attachment: attachment,
        clearStagedAttachment: true,
      );
    }
    return updated;
  }

  Future<void> _reconcileCurrentDraftPendingAttachments(
    DraftCubit draftCubit, {
    Map<String, String>? metadataIdsByPendingId,
    int? saveEpoch,
  }) async {
    if (!mounted || (saveEpoch != null && saveEpoch != _saveEpoch)) {
      return;
    }
    final current = List<PendingAttachment>.from(_pendingAttachments);
    final reconciled = await _reconcileDraftPendingAttachments(
      current,
      draftCubit,
      metadataIdsByPendingId: metadataIdsByPendingId,
    );
    if (!mounted || (saveEpoch != null && saveEpoch != _saveEpoch)) {
      return;
    }
    if (!_pendingAttachmentListsMatch(_pendingAttachments, current) ||
        _pendingAttachmentListsMatch(current, reconciled)) {
      return;
    }
    final releasedStagedAttachments = _releasedStagedPendingAttachments(
      previous: current,
      current: reconciled,
    );
    setState(() => _pendingAttachments = reconciled);
    await _deleteDraftStagedAttachments(releasedStagedAttachments);
  }

  bool _pendingAttachmentListsMatch(
    List<PendingAttachment> left,
    List<PendingAttachment> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  List<PendingAttachment> _releasedStagedPendingAttachments({
    required List<PendingAttachment> previous,
    required List<PendingAttachment> current,
  }) {
    final retainedStagedPathsById = <String, String>{
      for (final pending in current)
        if (pending.stagedAttachment != null)
          pending.id: pending.stagedAttachment!.path,
    };
    return previous
        .where((pending) {
          final staged = pending.stagedAttachment;
          return staged != null &&
              retainedStagedPathsById[pending.id] != staged.path;
        })
        .toList(growable: false);
  }

  void _notifyRecipientAddressesChanged() {
    final onRecipientAddressesChanged = widget.onRecipientAddressesChanged;
    if (onRecipientAddressesChanged == null) {
      return;
    }
    onRecipientAddressesChanged(_recipientStrings());
  }

  List<Attachment> _currentAttachments() =>
      _pendingAttachments.map((pending) => pending.attachment).toList();

  List<PendingAttachment> _resetUploadingPendingAttachments() =>
      _pendingAttachments
          .map(
            (pending) => pending.status == PendingAttachmentStatus.uploading
                ? pending.copyWith(
                    status: PendingAttachmentStatus.queued,
                    clearErrorMessage: true,
                  )
                : pending,
          )
          .toList();

  void _showToast(String message) {
    ShadToaster.maybeOf(context)?.show(FeedbackToast.info(message: message));
  }

  String _nextPendingAttachmentId() => const Uuid().v4();

  bool _hasContent() {
    return _hasMeaningfulBodyText(_outgoingPreviewText().trim()) ||
        _subjectTextController.text.trim().isNotEmpty ||
        widget.quoteTarget != null ||
        _pendingCalendarTaskIcsMessage != null ||
        _forwardedBlocks.isNotEmpty ||
        _pendingAttachments.isNotEmpty ||
        _pendingAttachments.any(
          (attachment) => attachment.status == PendingAttachmentStatus.queued,
        );
  }

  bool _hasMeaningfulBodyText(String trimmedBody) {
    if (trimmedBody.isEmpty) {
      return false;
    }
    final watermark = context.l10n.chatComposerEmailWatermark.trim();
    if (watermark.isEmpty) {
      return true;
    }
    return trimmedBody != watermark;
  }

  String? _sendValidationMessage({
    required bool hasActiveRecipients,
    required bool hasContent,
    required bool emailRecipientsUnavailable,
    Iterable<ComposerRecipient>? recipients,
    int? emailRecipientCount,
  }) {
    final resolvedEmailRecipientCount =
        emailRecipientCount ??
        (recipients ?? _recipients).emailComposeHintCount;
    if (resolvedEmailRecipientCount > composeRecipientLimit) {
      return context.l10n.fanOutErrorTooManyRecipients(composeRecipientLimit);
    }
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

  void _handlePendingAttachmentRetry(PendingAttachment pending) {}

  void _handlePendingAttachmentPressed(PendingAttachment pending) {
    final commandSurface =
        EnvScope.maybeOf(context)?.commandSurface ?? CommandSurface.sheet;
    if (commandSurface == CommandSurface.menu) {
      _showAttachmentPreview(pending);
      return;
    }
    _showPendingAttachmentActions(pending);
  }

  void _handlePendingAttachmentLongPressed(PendingAttachment pending) {
    _showPendingAttachmentActions(pending);
  }

  Future<void> _showAttachmentPreview(PendingAttachment pending) async {
    if (!mounted) return;
    final l10n = context.l10n;
    await showPendingAttachmentPreview(
      context: context,
      pending: pending,
      onRemove: () => _handlePendingAttachmentRemoved(pending.id),
      removeTooltip: l10n.draftRemoveAttachment,
      closeTooltip: l10n.commonClose,
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
        return AxiSheetScaffold.scroll(
          header: AxiSheetHeader(
            title: Text(sheetContext.l10n.chatAttachmentTooltip),
            onClose: () => Navigator.of(sheetContext).maybePop(),
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

class _DraftForwardedBlockPreview extends StatelessWidget {
  const _DraftForwardedBlockPreview({
    required this.block,
    required this.showImages,
    required this.originalContentUnblocked,
    required this.baseFontSize,
    required this.onShowImages,
    required this.onUnblockOriginal,
    required this.onConvert,
    required this.onRestore,
    required this.onLinkTap,
  });

  final DraftForwardedBlock block;
  final bool showImages;
  final bool originalContentUnblocked;
  final double baseFontSize;
  final VoidCallback onShowImages;
  final Future<void> Function() onUnblockOriginal;
  final VoidCallback onConvert;
  final Future<void> Function() onRestore;
  final ValueChanged<String> onLinkTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final originalHtml = block.originalHtml?.trim();
    final originalSubject = block.originalSubject?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                originalSubject?.isNotEmpty == true
                    ? originalSubject!
                    : context.l10n.chatForwardedMessageHeader,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.small,
              ),
            ),
            SizedBox(width: spacing.s),
            if (block.isConverted)
              AxiButton.outline(
                size: AxiButtonSize.sm,
                onPressed: () => unawaited(onRestore()),
                child: Text(context.l10n.draftForwardRestoreAction),
              )
            else
              AxiButton.outline(
                size: AxiButtonSize.sm,
                onPressed: onConvert,
                child: Text(context.l10n.draftForwardConvertAction),
              ),
          ],
        ),
        if (!block.isConverted) ...[
          SizedBox(height: spacing.s),
          if (originalHtml != null && originalHtml.isNotEmpty)
            AxiEmailHtmlPreview(
              html: originalHtml,
              shouldLoadSafeRemoteImages: showImages,
              originalContentUnblocked: originalContentUnblocked,
              baseFontSize: baseFontSize,
              onRemoteImagesApproved: onShowImages,
              onOriginalContentUnblocked: onUnblockOriginal,
              onLinkTap: onLinkTap,
            ),
        ],
      ],
    );
  }
}

class _DraftPartialSendBanner extends StatelessWidget {
  const _DraftPartialSendBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.destructive,
          border: Border(
            top: context.borderSide.copyWith(color: colors.destructive),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(spacing.m),
          child: Row(
            children: [
              Icon(
                Icons.priority_high_rounded,
                color: colors.destructiveForeground,
                size: context.sizing.menuItemIconSize,
              ),
              SizedBox(width: spacing.s),
              Expanded(
                child: Text(
                  context.l10n.draftPartialSendNotice,
                  style: context.textTheme.p.copyWith(
                    color: colors.destructiveForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftCalendarTaskBanner extends StatelessWidget {
  const _DraftCalendarTaskBanner({
    required this.message,
    required this.onRemove,
  });

  final CalendarTaskIcsMessage message;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final title = message.task.title.trim();
    return SizedBox(
      width: double.infinity,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.card,
            border: Border(top: context.borderSide),
          ),
          child: Padding(
            padding: EdgeInsets.all(spacing.m),
            child: Row(
              children: [
                Icon(
                  LucideIcons.calendarCheck2,
                  color: colors.primary,
                  size: context.sizing.menuItemIconSize,
                ),
                SizedBox(width: spacing.s),
                Expanded(
                  child: Text(
                    title.isEmpty ? context.l10n.calendarTaskShareTitle : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.p,
                  ),
                ),
                SizedBox(width: spacing.s),
                AxiIconButton.ghost(
                  iconData: LucideIcons.x,
                  tooltip: context.l10n.commonRemove,
                  semanticLabel: context.l10n.commonRemove,
                  onPressed: onRemove,
                  color: colors.mutedForeground,
                  backgroundColor: Colors.transparent,
                  iconSize: context.sizing.menuItemIconSize,
                  buttonSize: context.sizing.menuItemHeight,
                  tapTargetSize: context.sizing.menuItemHeight,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
