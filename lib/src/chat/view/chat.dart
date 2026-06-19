// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:axichat/src/avatar/avatar_presentation.dart';
import 'package:axichat/src/common/email_html_logging.dart';
import 'package:axichat/src/avatar/view/app_icon_avatar.dart';
import 'package:axichat/src/avatar/view/avatar_badge_overlay.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/attachments/bloc/attachment_gallery_bloc.dart';
import 'package:axichat/src/attachments/view/attachment_gallery_view.dart';
import 'package:axichat/src/attachments/view/pending_attachment_preview.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/chat_calendar_bloc.dart';
import 'package:axichat/src/calendar/models/calendar_availability_message.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/calendar_task_ics_message.dart';
import 'package:axichat/src/calendar/reminders/calendar_reminder_controller.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/calendar/storage/chat_calendar_storage.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_coordinator.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_sync_coordinator.dart';
import 'package:axichat/src/calendar/interop/calendar_fragment_formatter.dart';
import 'package:axichat/src/calendar/interop/chat_calendar_support.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/view/tasks/location_autocomplete.dart';
import 'package:axichat/src/calendar/task/task_share_formatter.dart';
import 'package:axichat/src/calendar/task/time_formatter.dart';
import 'package:axichat/src/calendar/view/shell/chat_calendar_widget.dart';
import 'package:axichat/src/calendar/view/shell/feedback_system.dart';
import 'package:axichat/src/calendar/view/grid/calendar_drag_payload.dart';
import 'package:axichat/src/calendar/view/tasks/quick_add_modal.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/models/chat_timeline.dart';
import 'package:axichat/src/chat/models/chat_message.dart';
import 'package:axichat/src/chat/bloc/chat_search_cubit.dart';
import 'package:axichat/src/chat/models/pending_attachment.dart';
import 'package:axichat/src/common/compose_recipient.dart';
import 'package:axichat/src/chat/models/pinned_message_item.dart';
import 'package:axichat/src/chat/models/chat_timeline_projection.dart';
import 'package:axichat/src/chat/models/rfc_email_group.dart';
import 'package:axichat/src/common/chat_subject_codec.dart';
import 'package:axichat/src/chat/view/composer/attachment_approval_dialog.dart';
import 'package:axichat/src/chat/view/composer/attachment_preview.dart';
import 'package:axichat/src/chat/view/timeline/message/bubble_surface.dart';
import 'package:axichat/src/chat/view/composer/cutout_composer.dart';
import 'package:axichat/src/chat/view/timeline/message/text_parser.dart';
import 'package:axichat/src/chat/view/composer/pending_attachment_list.dart';
import 'package:axichat/src/calendar/view/availability/availability_card.dart';
import 'package:axichat/src/calendar/view/availability/availability_request_sheet.dart';
import 'package:axichat/src/calendar/view/availability/availability_viewer.dart';
import 'package:axichat/src/calendar/view/tasks/fragment_card.dart';
import 'package:axichat/src/calendar/view/chat/chat_critical_path_card.dart';
import 'package:axichat/src/calendar/view/chat/chat_task_card.dart';
import 'package:axichat/src/chat/view/timeline/message/email_html_web_view.dart';
import 'package:axichat/src/chat/view/timeline/message/email_image_extension.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/contact_rename_dialog.dart';
import 'package:axichat/src/chats/view/selection_panel_shell.dart';
import 'package:axichat/src/common/bool_tool.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/common/notification_privacy.dart';
import 'package:axichat/src/common/policy.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/safe_logging.dart';
import 'package:axichat/src/common/synthetic_forward.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/common/unicode_safety.dart';
import 'package:axichat/src/common/url_safety.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/view/compose_launcher.dart';
import 'package:axichat/src/draft/view/draft_composer_view.dart';
import 'package:axichat/src/email/models/fan_out_recipient_state.dart';
import 'package:axichat/src/email/models/fan_out_send_report.dart';
import 'package:axichat/src/email/models/share_context.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/util/delta_jids.dart';
import 'package:axichat/src/folders/bloc/folders_cubit.dart';
import 'package:axichat/src/folders/view/folder_picker_sheet.dart';
import 'package:axichat/src/important/view/important_messages_list.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/chat/view/overlays/room_members_sheet.dart';
import 'package:axichat/src/xmpp/muc/occupant.dart';
import 'package:axichat/src/xmpp/muc/room_state.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/share/share_handoff.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/models/chat_models.dart' as chat_models;
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:animations/animations.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_html/flutter_html.dart' as html_widget;
import 'package:flutter/rendering.dart'
    show
        BoxHitTestResult,
        ContainerBoxParentData,
        ContainerRenderObjectMixin,
        PipelineOwner,
        RenderBox,
        RenderBoxContainerDefaultsMixin,
        RenderProxyBox;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:axichat/src/storage/models.dart' as storage_models;

part 'frame/chat_alert.dart';

part 'overlays/chat_message_details.dart';

part 'composer/composer_section.dart';

part 'frame/scaffold_chrome.dart';

part 'frame/scaffold_body.dart';

part 'overlays/chat_search.dart';

part 'overlays/chat_settings.dart';

part 'overlays/calendar_text_selection_dialog.dart';

part 'overlays/chat_overlay.dart';

part 'selection/selection_toolbar.dart';

part 'timeline/conversation_surface.dart';

part 'timeline/message_list.dart';

part 'timeline/message_chrome.dart';

part 'timeline/message_row.dart';

part 'timeline/message_shell.dart';

part 'timeline/pinned_panel.dart';

part 'timeline/timeline_item.dart';

part 'timeline/timeline_pane.dart';

part 'timeline/timeline_visual.dart';

part 'timeline/message/message_body.dart';

const List<BlocklistEntry> _emptyBlocklistEntries = <BlocklistEntry>[];
const int _chatBaseActionCount = 3;
const bool _calendarTaskIcsReadOnlyFallback =
    CalendarTaskIcsMessage.defaultReadOnly;
const Uuid _availabilityResponseIdGenerator = Uuid();
const String _composerShareSeparator = '\n\n';
const String _emptyText = '';
const List<InlineSpan> _emptyInlineSpans = <InlineSpan>[];
const _bubbleFocusDuration = Duration(milliseconds: 620);
const _bubbleFocusCurve = Curves.easeOutCubic;
const _chatScrollStoragePrefix = 'chat-scroll-offset-';

List<BoxShadow> _selectedBubbleShadows(Color color) => [
  BoxShadow(
    color: color.withValues(alpha: 0.12),
    blurRadius: 26,
    offset: const Offset(0, 14),
  ),
  const BoxShadow(
    color: Color(0x33000000),
    blurRadius: 10,
    offset: Offset(0, 4),
  ),
];

List<BoxShadow> _scaleShadows(List<BoxShadow> shadows, double factor) => shadows
    .map(
      (shadow) => shadow.copyWith(
        color: shadow.color.withValues(alpha: shadow.color.a * factor),
      ),
    )
    .toList();

bool _emailHtmlHasVisibleTimelineContent({
  required String? normalizedHtmlBody,
  required String? normalizedHtmlText,
  EmailHtmlDerivation? derivation,
}) {
  if ((derivation?.visibleBodyText ?? normalizedHtmlText)?.trim().isNotEmpty ==
      true) {
    return true;
  }
  if (normalizedHtmlBody == null) {
    return false;
  }
  if (derivation?.containsRemoteImages ??
      HtmlContentCodec.containsRenderableRemoteImages(normalizedHtmlBody)) {
    return true;
  }
  return HtmlContentCodec.imageSources(
    normalizedHtmlBody,
  ).any((source) => source.trim().toLowerCase().startsWith('data:'));
}

@visibleForTesting
bool shouldUseSelectedInlineEmailWebViewForTesting({
  required bool isSingleSelection,
  required bool shouldRenderHtmlBody,
}) => isSingleSelection && shouldRenderHtmlBody;

@visibleForTesting
bool shouldShowSelectedEmailImageLoadButtonForTesting({
  required bool isSingleSelection,
  required bool shouldRenderHtmlBody,
  required bool hasRemoteHtmlImages,
  required bool shouldLoadImages,
  required bool hasLoadCallback,
}) =>
    shouldUseSelectedInlineEmailWebViewForTesting(
      isSingleSelection: isSingleSelection,
      shouldRenderHtmlBody: shouldRenderHtmlBody,
    ) &&
    hasRemoteHtmlImages &&
    !shouldLoadImages &&
    hasLoadCallback;

@visibleForTesting
bool shouldShowEmailWebViewTipForTesting({
  required bool isEmailMessage,
  required bool readOnly,
  required bool multiSelectActive,
  required bool isSingleSelection,
  required String? normalizedHtmlBody,
  required String? renderedText,
  required EmailHtmlDerivation? emailDerivation,
}) {
  if (!isEmailMessage ||
      readOnly ||
      multiSelectActive ||
      isSingleSelection ||
      normalizedHtmlBody == null ||
      emailDerivation == null) {
    return false;
  }
  final hasSelectedWebViewContent =
      _emailHtmlHasVisibleTimelineContent(
        normalizedHtmlBody: normalizedHtmlBody,
        normalizedHtmlText: emailDerivation.visibleBodyText,
        derivation: emailDerivation,
      ) ||
      emailDerivation.containsBlockedWebViewContent ||
      emailDerivation.containsCidImages;
  if (!hasSelectedWebViewContent) {
    return false;
  }
  return HtmlContentCodec.shouldRenderRichEmailHtml(
        normalizedHtmlBody: normalizedHtmlBody,
        normalizedHtmlText: emailDerivation.visibleBodyText,
        renderedText: renderedText ?? _emptyText,
      ) ||
      emailDerivation.containsBlockedWebViewContent ||
      emailDerivation.containsCidImages;
}

@visibleForTesting
bool shouldDeferReadThresholdSyncForTesting({
  required bool messagesLoaded,
  required bool initialTimelineReadinessPending,
}) => !messagesLoaded || initialTimelineReadinessPending;

double _bubbleCornerClearance(BorderRadius baseRadius) =>
    math.max(baseRadius.topLeft.x, baseRadius.topLeft.y);

BorderRadius _bubbleBorderRadius({
  required BorderRadius baseRadius,
  required bool isSelf,
  required bool chainedPrevious,
  required bool chainedNext,
  bool isSelected = false,
  bool flattenBottom = false,
}) {
  var topLeading = baseRadius.topLeft;
  var topTrailing = baseRadius.topRight;
  var bottomLeading = baseRadius.bottomLeft;
  var bottomTrailing = baseRadius.bottomRight;
  if (!isSelected) {
    if (isSelf) {
      if (chainedPrevious) topTrailing = Radius.zero;
      if (chainedNext) bottomTrailing = Radius.zero;
    } else {
      if (chainedPrevious) topLeading = Radius.zero;
      if (chainedNext) bottomLeading = Radius.zero;
    }
  }
  if (flattenBottom) {
    if (isSelf) {
      bottomTrailing = Radius.zero;
    } else {
      bottomLeading = Radius.zero;
    }
  }
  return BorderRadius.only(
    topLeft: topLeading,
    topRight: topTrailing,
    bottomLeft: bottomLeading,
    bottomRight: bottomTrailing,
  );
}

enum _InlineComposerCloseAction { save, discard, cancel }

enum _ComposerSendAction { saveDraft, sendAsEmail }

class Chat extends StatefulWidget {
  const Chat({
    super.key,
    this.readOnly = false,
    this.active = true,
    this.syncWithOpenChatRoute = true,
    this.calendarSurfaceActive = true,
  });

  final bool readOnly;
  final bool active;
  final bool syncWithOpenChatRoute;
  final bool calendarSurfaceActive;

  @override
  State<Chat> createState() => _ChatState();
}

enum _InitialEmailViewportWarmupStatus { pending, warming, warmed }

final class _RenderedHydrationSnapshot {
  const _RenderedHydrationSnapshot({
    required this.emailServiceAvailable,
    required this.emailFullHtmlUnavailableCount,
    required this.emailQuotedTextUnavailableCount,
    required this.messages,
  });

  final bool emailServiceAvailable;
  final int emailFullHtmlUnavailableCount;
  final int emailQuotedTextUnavailableCount;
  final List<_RenderedMessageHydrationSnapshot> messages;

  @override
  bool operator ==(Object other) {
    return other is _RenderedHydrationSnapshot &&
        other.emailServiceAvailable == emailServiceAvailable &&
        other.emailFullHtmlUnavailableCount == emailFullHtmlUnavailableCount &&
        other.emailQuotedTextUnavailableCount ==
            emailQuotedTextUnavailableCount &&
        // listEquals delegates to each message snapshot's ==, so this is deep equality.
        listEquals(other.messages, messages);
  }

  @override
  int get hashCode => Object.hash(
    emailServiceAvailable,
    emailFullHtmlUnavailableCount,
    emailQuotedTextUnavailableCount,
    Object.hashAll(messages),
  );
}

final class _RenderedMessageHydrationSnapshot {
  const _RenderedMessageHydrationSnapshot({
    required this.stanzaId,
    required this.deltaMessageId,
    required this.displayed,
  });

  factory _RenderedMessageHydrationSnapshot.fromMessage(Message message) {
    return _RenderedMessageHydrationSnapshot(
      stanzaId: message.stanzaID,
      deltaMessageId: message.deltaMsgId,
      displayed: message.displayed,
    );
  }

  final String stanzaId;
  final int? deltaMessageId;
  final bool displayed;

  @override
  bool operator ==(Object other) {
    return other is _RenderedMessageHydrationSnapshot &&
        other.stanzaId == stanzaId &&
        other.deltaMessageId == deltaMessageId &&
        other.displayed == displayed;
  }

  @override
  int get hashCode => Object.hash(stanzaId, deltaMessageId, displayed);
}

class _ChatState extends State<Chat> {
  static bool get _debugShowAllComposerBanners => kDebugMode && false;

  static bool get _debugCycleComposerBanners => kDebugMode && false;

  late final ShadPopoverController _emojiPopoverController;
  late Key _inlineComposerKey;
  late _InlineComposerController _inlineComposerController;
  late ScrollController _scrollController;
  bool _composerHasText = false;

  bool get _composerHasContent =>
      _composerHasText ||
      _quotedDraft != null ||
      _pendingCalendarTaskIcs != null;
  String _lastSubjectValue = '';
  bool _subjectChangeSuppressed = false;
  bool _collapseLongEmailMessages = false;
  List<ComposerRecipient> _recipients = const [];
  String? _recipientsChatJid;
  bool _composerExpanded = false;
  int? _inlineComposerDraftId;
  int? _lastSavedInlineDraftSignature;
  bool _savingInlineDraft = false;
  bool _discardingInlineDraft = false;
  ChatCalendarSyncCoordinator? _fallbackChatCalendarCoordinator;
  final _oneTimeAllowedAttachmentStanzaIds = <String>{};
  final _loadedEmailImageMessageIds = <String>{};
  final _animatedMessageIds = <String>{};
  var _hydratedAnimatedMessages = false;
  static final Map<String, double> _scrollOffsetCache = {};
  String? _lastScrollStorageKey;

  var _chatRoute = ChatRouteIndex.main;
  var _previousChatRoute = ChatRouteIndex.main;
  LocalHistoryEntry? _chatRouteHistoryEntry;
  bool _chatCalendarCanHandleBack = false;
  bool _pinnedPanelVisible = false;
  String? _selectedMessageId;
  var _selectedMessageVisibilityRequest = 0;
  final _multiSelectedMessageIds = <String>{};
  final _selectedMessageSnapshots = <String, Message>{};
  final _pendingReactionPreviewsByMessageId =
      <String, ({List<ReactionPreview> base, List<ReactionPreview> preview})>{};
  final _unreadDividerKey = GlobalKey();
  final _messageKeys = <String, GlobalKey>{};
  final _mountedTimelineItemIds = <String>{};
  var _activeUnreadDividerScrollRequestId = 0;
  var _completedUnreadDividerScrollRequestId = 0;
  var _initialEmailViewportWarmupStatus =
      _InitialEmailViewportWarmupStatus.pending;
  Set<int> _initialEmailViewportDeltaIds = const <int>{};
  var _initialEmailViewportWarmupRequestId = 0;
  _RenderedHydrationSnapshot? _lastRenderedHydrationSnapshot;
  List<RosterItem>? _cachedRosterItems;
  List<chat_models.Chat>? _cachedChatItems;
  String? _cachedSelfAvatarPath;
  String? _cachedNormalizedXmppSelfJid;
  String? _cachedNormalizedEmailSelfJid;
  Map<String, String> _cachedRosterAvatarPathsByJid = const {};
  Map<String, String> _cachedChatAvatarPathsByJid = const {};
  List<Message>? _cachedItems;
  Map<String, Message>? _cachedQuotedMessagesById;
  List<Message>? _cachedSearchResults;
  bool _cachedSearchFiltering = false;
  Map<String, List<String>>? _cachedAttachmentsByMessageId;
  Map<String, String>? _cachedGroupLeaderByMessageId;
  Map<int, String>? _cachedEmailFullHtmlByDeltaId;
  Map<String, Message> _cachedMessageById = const {};
  List<Message> _cachedFilteredItems = const [];
  List<ChatTimelineItem> _cachedTimelineItems = const [];
  final _bubbleWidthByMessageId = <String, double>{};
  final _emailWebViewHeightByContentKey =
      <String, ({String messageId, double height})>{};
  final _bubbleRegionRegistry = _BubbleRegionRegistry();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final _messageListKey = GlobalKey();
  Set<String> _reportedReadThresholdMessageIds = const <String>{};
  var _readThresholdSyncScheduled = false;
  final Object _composerTapRegionGroup = Object();
  final Object _selectionTapRegionGroup = Object();
  double _bottomSectionHeight = 0.0;
  int? _outsideTapPointer;
  Offset? _outsideTapStart;
  var _sendingAttachment = false;
  CancelableCompleter<void>? _inlineAttachmentPreparationCancellation;
  Future<void>? _inlineAttachmentPreparationOperation;
  CancelableOperation<PendingAttachment?>? _inlinePendingAttachmentOperation;
  StreamSubscription<ShareComposerSeed>? _shareComposerSeedSubscription;
  final StreamController<void> _shareComposerSeedConsumptionRequests =
      StreamController<void>();
  late final StreamSubscription<void> _shareComposerSeedConsumptionSubscription;
  RequestStatus _shareRequestStatus = RequestStatus.none;
  CalendarTask? _pendingCalendarTaskIcs;
  bool _pendingCalendarTaskIcsReadOnly = _calendarTaskIcsReadOnlyFallback;
  String? _pendingCalendarSeedText;
  Completer<Object?>? _pendingCalendarImportCompleter;
  Message? _quotedDraft;
  var _replyResolveRequestId = 0;
  List<PendingAttachment> _pendingAttachments = const [];
  MessageTransport? _inlineRetryTransportOverride;
  var _pendingAttachmentSeed = 0;
  var _handledPendingOpenMessageRequestId = 0;

  bool get _multiSelectActive => _multiSelectedMessageIds.isNotEmpty;

  ChatSettingsSnapshot _settingsSnapshotFromState(SettingsState settings) =>
      ChatSettingsSnapshot(
        language: settings.language,
        chatReadReceipts: settings.chatReadReceipts,
        emailReadReceipts: settings.emailReadReceipts,
        shareTokenSignatureEnabled: settings.shareTokenSignatureEnabled,
        autoDownloadImages: settings.autoDownloadImages,
        autoDownloadVideos: settings.autoDownloadVideos,
        autoDownloadDocuments: settings.autoDownloadDocuments,
        autoDownloadArchives: settings.autoDownloadArchives,
      );

  double _outsideTapDragThreshold() =>
      MediaQuery.maybeOf(context)?.gestureSettings.touchSlop ?? kTouchSlop;

  void _dismissTextInputFocus() {
    _inlineComposerController.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _recreateInlineComposer() {
    _inlineComposerKey = UniqueKey();
    _inlineComposerController = _InlineComposerController();
  }

  void _armOutsideTapDismiss(PointerDownEvent event) {
    if (_selectedMessageId == null) return;
    _outsideTapPointer = event.pointer;
    _outsideTapStart = event.position;
  }

  void _clearOutsideTapTracking() {
    _outsideTapPointer = null;
    _outsideTapStart = null;
  }

  void _handleOutsideTapMove(PointerMoveEvent event) {
    final pointer = _outsideTapPointer;
    final start = _outsideTapStart;
    if (pointer == null || start == null || event.pointer != pointer) {
      return;
    }
    final delta = event.position - start;
    if (delta.distance <= _outsideTapDragThreshold()) {
      return;
    }
    _clearOutsideTapTracking();
  }

  void _handleOutsideTapUp(PointerUpEvent event) {
    final pointer = _outsideTapPointer;
    final start = _outsideTapStart;
    if (pointer == null || start == null || event.pointer != pointer) {
      return;
    }
    _clearOutsideTapTracking();
    _clearMessageSelection();
  }

  void _handleOutsideTapCancel(PointerCancelEvent event) {
    if (_outsideTapPointer == null || event.pointer != _outsideTapPointer) {
      return;
    }
    _clearOutsideTapTracking();
  }

  void _handleEmailImagesApproved(String messageId) {
    if (!_loadedEmailImageMessageIds.add(messageId)) return;
    if (mounted) {
      setState(() {});
    }
  }

  void _clearInlineRetryTransportOverride() {
    _inlineRetryTransportOverride = null;
  }

  void _handleComposerTextChanged(String text) {
    final hasText = text.isNotEmpty;
    final chatState = context.read<ChatBloc>().state;
    final settings = context.read<SettingsCubit>().state;
    final trimmedHasText =
        _isEmailComposerWatermarkOnly(
          text: text,
          chatState: chatState,
          settings: settings,
        )
        ? false
        : text.trim().isNotEmpty;
    if (_composerHasText != trimmedHasText && mounted) {
      setState(() {
        _composerHasText = trimmedHasText;
        _clearInlineRetryTransportOverride();
      });
    } else {
      _clearInlineRetryTransportOverride();
    }
    _maybeClearPendingCalendarTaskIcs(text);
    if (!hasText) return;
    final chat = context.read<ChatBloc>().state.chat;
    if (chat == null) return;
    if (!(chat.typingIndicatorsEnabled ??
        context.read<SettingsCubit>().state.indicateTyping)) {
      return;
    }
    context.read<ChatBloc>().add(ChatTypingStarted(chat: chat));
  }

  void _resetRecipientsForChat(chat_models.Chat? chat) {
    final jid = chat?.jid;
    final pinnedTarget = chat == null
        ? null
        : Contact.chat(
            chat: chat,
            shareSignatureEnabled:
                chat.shareSignatureEnabled ??
                context.read<SettingsCubit>().state.shareTokenSignatureEnabled,
          );
    if (jid == _recipientsChatJid) {
      if (pinnedTarget == null) {
        return;
      }
      _recipients = [
        for (final recipient in _recipients)
          recipient.isPinned ? recipient.withTarget(pinnedTarget) : recipient,
      ];
      if (!mounted) return;
      setState(() {});
      _syncEmailComposerWatermark(chatState: context.read<ChatBloc>().state);
      return;
    }
    _recipientsChatJid = jid;
    if (pinnedTarget == null) {
      _recipients = const [];
    } else {
      _recipients = [
        ComposerRecipient(target: pinnedTarget, included: true, pinned: true),
      ];
    }
    if (!mounted) return;
    setState(() {});
    _syncEmailComposerWatermark(chatState: context.read<ChatBloc>().state);
  }

  Future<bool> _handleRecipientAdded(Contact target) async {
    final address = target.resolvedAddress;
    if (target.needsTransportSelection &&
        address != null &&
        address.isNotEmpty) {
      final transport = await _resolveAddressTransport(address);
      if (!mounted || transport == null) {
        return false;
      }
      return _applyRecipient(target.withTransport(transport));
    }
    return _applyRecipient(target);
  }

  String? _recipientAddError(Contact target) {
    final chatState = context.read<ChatBloc>().state;
    final chat = chatState.chat;
    final forceEmailDomain =
        chat != null &&
            chatState.canOfferEmailOutboundOverride &&
            chatState.activeTransportForSend(chat).isEmail
        ? addressDomainPart(chatState.emailSelfJid)
        : null;
    if (!exceedsComposeRecipientLimit(
      recipients: _recipients,
      target: target,
      forceEmailDomain: forceEmailDomain,
    )) {
      return null;
    }
    return context.l10n.fanOutErrorTooManyRecipients(composeRecipientLimit);
  }

  bool _applyRecipient(Contact target) {
    final addError = _recipientAddError(target);
    if (addError != null) {
      ShadToaster.maybeOf(
        context,
      )?.show(FeedbackToast.warning(message: addError));
      return false;
    }
    final index = _recipients.indexWhere((recipient) {
      return recipient.key == target.key;
    });
    if (index >= 0) {
      final recipient = _recipients[index];
      final updated = List<ComposerRecipient>.from(_recipients)
        ..[index] = recipient.withTarget(target).withIncluded(true);
      setState(() {
        _recipients = updated;
        _clearInlineRetryTransportOverride();
      });
      _syncEmailComposerWatermark(chatState: context.read<ChatBloc>().state);
      return true;
    }
    setState(() {
      _recipients = [
        ..._recipients,
        ComposerRecipient(target: target, included: true),
      ];
      _clearInlineRetryTransportOverride();
    });
    _syncEmailComposerWatermark(chatState: context.read<ChatBloc>().state);
    return true;
  }

  Future<MessageTransport?> _resolveAddressTransport(String address) async {
    final endpointConfig = context.read<SettingsCubit>().state.endpointConfig;
    final supportsEmail = endpointConfig.smtpEnabled;
    final supportsXmpp = endpointConfig.xmppEnabled;
    if (supportsEmail && !supportsXmpp) {
      return MessageTransport.email;
    }
    if (!supportsEmail && supportsXmpp) {
      return MessageTransport.xmpp;
    }
    if (!supportsEmail && !supportsXmpp) {
      return null;
    }
    final hinted = hintTransportForAddress(
      address,
      xmppDomainHints: {endpointConfig.domain},
    );
    if (hinted != null) {
      return hinted;
    }
    return showTransportChoiceDialog(
      context,
      address: address,
      defaultTransport: hinted,
    );
  }

  void _handleRecipientRemoved(String key) {
    final updated = _recipients
        .where((recipient) {
          return recipient.key != key || recipient.isPinned;
        })
        .toList(growable: false);
    if (updated.length == _recipients.length) return;
    setState(() {
      _recipients = updated;
      _clearInlineRetryTransportOverride();
    });
    _syncEmailComposerWatermark(chatState: context.read<ChatBloc>().state);
  }

  bool _handleRecipientAddedFromChat(chat_models.Chat chat) {
    return _applyRecipient(
      Contact.chat(
        chat: chat,
        shareSignatureEnabled:
            chat.shareSignatureEnabled ??
            context.read<SettingsCubit>().state.shareTokenSignatureEnabled,
      ),
    );
  }

  void _maybeClearPendingCalendarTaskIcs(String text) {
    final seedText = _pendingCalendarSeedText;
    if (_pendingCalendarTaskIcs == null || seedText == null) {
      return;
    }
    if (text.trim().contains(seedText)) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _pendingCalendarTaskIcs = null;
      _pendingCalendarTaskIcsReadOnly = _calendarTaskIcsReadOnlyFallback;
      _pendingCalendarSeedText = null;
      _clearInlineRetryTransportOverride();
    });
  }

  void _updateBottomSectionHeight(Size size) {
    final height = size.height;
    if (!mounted || height == _bottomSectionHeight) {
      return;
    }
    setState(() {
      _bottomSectionHeight = height;
    });
  }

  void _updateMessageBubbleWidth(String messageId, Size size) {
    if (!mounted) {
      return;
    }
    final width = size.width;
    final previous = _bubbleWidthByMessageId[messageId];
    if (previous != null && (previous - width).abs() < 0.5) {
      return;
    }
    setState(() {
      _bubbleWidthByMessageId[messageId] = width;
    });
  }

  String _emailWebViewHeightCacheKey({
    required Object bubbleContentKey,
    required String html,
    required bool shouldLoadImages,
    required double baseFontSize,
  }) {
    return [
      bubbleContentKey,
      html.length,
      html.hashCode,
      shouldLoadImages,
      baseFontSize.toStringAsFixed(2),
    ].join('\n');
  }

  double? _emailWebViewHeightFor(String contentKey) =>
      _emailWebViewHeightByContentKey[contentKey]?.height;

  void _updateEmailWebViewHeight({
    required String contentKey,
    required String messageId,
    required double height,
  }) {
    if (height <= 0) {
      return;
    }
    final normalizedHeight = height.ceilToDouble();
    final previous = _emailWebViewHeightByContentKey[contentKey]?.height;
    if (previous != null && (previous - normalizedHeight).abs() < 0.5) {
      return;
    }
    _emailWebViewHeightByContentKey[contentKey] = (
      messageId: messageId,
      height: normalizedHeight,
    );
    if (_selectedMessageId == messageId) {
      _scheduleSelectedMessageVisibilityCheck(messageId);
    }
  }

  void _pruneEmailWebViewHeights(Set<String> availableIds) {
    _emailWebViewHeightByContentKey.removeWhere(
      (_, entry) => !availableIds.contains(entry.messageId),
    );
  }

  List<String> _demoTypingParticipants(ChatState state) {
    if (!kEnableDemoChats) return const [];
    final chat = state.chat;
    if (chat?.type != ChatType.groupChat) return const [];
    final room = state.roomState;
    if (room == null) return const [];
    final participants = room.occupants.values
        .map((occupant) => occupant.realJid ?? occupant.occupantId)
        .whereType<String>()
        .where((jid) => jid.isNotEmpty)
        .toList(growable: false);
    return participants;
  }

  ChatCalendarSyncCoordinator? _resolveChatCalendarCoordinator({
    required CalendarStorageManager storageManager,
  }) {
    final storage = storageManager.authStorage;
    if (storage == null) {
      return null;
    }
    final locate = context.read;
    final coordinator = _readChatCalendarCoordinator(
      context,
      calendarAvailable: storageManager.isAuthStorageReady,
    );
    if (coordinator != null) {
      return coordinator;
    }
    final fallback = _fallbackChatCalendarCoordinator;
    if (fallback != null) {
      return fallback;
    }
    return _fallbackChatCalendarCoordinator = ChatCalendarSyncCoordinator(
      storage: ChatCalendarStorage(storage: storage),
      sendMessage:
          ({
            required String jid,
            required CalendarSyncOutbound outbound,
            required ChatType chatType,
          }) async {
            await locate<ChatBloc>().sendCalendarSyncMessage(
              jid: jid,
              outbound: outbound,
              chatType: chatType,
            );
          },
      applyPrimaryView:
          ({
            required String chatJid,
            required ChatPrimaryView primaryView,
          }) async {
            await locate<XmppService>().applyRoomPrimaryView(
              roomJid: chatJid,
              primaryView: primaryView,
            );
          },
      sendSnapshotFile: (file) =>
          locate<ChatBloc>().uploadCalendarSnapshot(file),
    );
  }

  void _appendInlineComposerText(String text) {
    if (text.trim().isEmpty) {
      return;
    }
    final String existing = _inlineComposerController.text;
    final String separator = existing.trim().isEmpty
        ? _emptyText
        : _composerShareSeparator;
    final String nextText = '$existing$separator$text';
    _inlineComposerController.setTextValue(
      TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
        composing: TextRange.empty,
      ),
    );
    _inlineComposerController.requestTextFocus();
  }

  void _appendTaskShareText(CalendarTask task, {String? shareText}) {
    _appendInlineComposerText(shareText ?? task.toShareText(context.l10n));
  }

  _CalendarTaskShare? _resolveCalendarTaskShare(CalendarTask task) {
    final String shareText = task.toShareText(context.l10n).trim();
    return _CalendarTaskShare(task: task, text: shareText);
  }

  void _handleTaskDrop(CalendarDragPayload payload) {
    final share = _resolveCalendarTaskShare(payload.snapshot);
    if (share == null) {
      return;
    }
    if (share.task == null) {
      if (_pendingCalendarTaskIcs != null || _pendingCalendarSeedText != null) {
        if (!mounted) return;
        setState(() {
          _pendingCalendarTaskIcs = null;
          _pendingCalendarTaskIcsReadOnly = _calendarTaskIcsReadOnlyFallback;
          _pendingCalendarSeedText = null;
          _clearInlineRetryTransportOverride();
        });
      }
      _appendTaskShareText(payload.snapshot, shareText: share.text);
      return;
    }
    if (!mounted) return;
    setState(() {
      _pendingCalendarTaskIcs = share.task;
      _pendingCalendarTaskIcsReadOnly = _calendarTaskIcsReadOnlyFallback;
      _pendingCalendarSeedText = share.text;
      _clearInlineRetryTransportOverride();
    });
    _appendTaskShareText(payload.snapshot, shareText: share.text);
  }

  void _queueShareComposerSeedConsumption() {
    if (_shareComposerSeedConsumptionRequests.isClosed) {
      return;
    }
    _shareComposerSeedConsumptionRequests.add(null);
  }

  void _handleShareComposerSeed(ShareComposerSeed seed) {
    if (!mounted) {
      return;
    }
    if (context.read<ChatBloc>().state.chat?.jid != seed.jid) {
      return;
    }
    _queueShareComposerSeedConsumption();
  }

  Future<void> _consumePendingShareComposerSeeds() async {
    if (!mounted || _sendingAttachment) {
      return;
    }
    final locate = context.read;
    final chat = locate<ChatBloc>().state.chat;
    if (chat == null) {
      return;
    }
    for (final seed in locate<ShareComposerSeedQueue>().pendingFor(chat.jid)) {
      if (!mounted ||
          _sendingAttachment ||
          locate<ChatBloc>().state.chat?.jid != seed.jid) {
        return;
      }
      final consumed = await _consumeShareComposerSeed(seed);
      if (!consumed) {
        return;
      }
    }
  }

  Future<bool> _consumeShareComposerSeed(ShareComposerSeed seed) async {
    if (!mounted || _sendingAttachment) {
      return false;
    }
    final locate = context.read;
    final chat = locate<ChatBloc>().state.chat;
    if (chat == null || chat.jid != seed.jid) {
      return false;
    }
    if (seed.attachments.isEmpty) {
      if (!locate<ShareComposerSeedQueue>().take(seed)) {
        return true;
      }
      _appendInlineComposerText(seed.body);
      return true;
    }
    final cancellation = CancelableCompleter<void>();
    final preparation = _prepareInlineAttachments(
      chat: chat,
      attachments: seed.attachments,
      cancellation: cancellation,
    );
    final operation = preparation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _inlineAttachmentPreparationCancellation = cancellation;
    _inlineAttachmentPreparationOperation = operation;
    final bool operationResult;
    try {
      operationResult = await preparation;
    } finally {
      if (_inlineAttachmentPreparationOperation == operation) {
        _inlineAttachmentPreparationOperation = null;
      }
      if (identical(_inlineAttachmentPreparationCancellation, cancellation)) {
        _inlineAttachmentPreparationCancellation = null;
      }
      if (!cancellation.isCompleted && !cancellation.isCanceled) {
        cancellation.complete();
      }
    }
    if (!operationResult ||
        !mounted ||
        locate<ChatBloc>().state.chat?.jid != seed.jid) {
      return false;
    }
    if (!locate<ShareComposerSeedQueue>().take(seed)) {
      return true;
    }
    _appendInlineComposerText(seed.body);
    return true;
  }

  List<InlineSpan> _calendarTaskShareMetadata(
    CalendarTask task,
    AppLocalizations l10n,
    TextStyle detailStyle,
  ) {
    final List<InlineSpan> metadata = <InlineSpan>[];
    final String description = task.description?.trim() ?? '';
    if (description.isNotEmpty) {
      metadata.add(TextSpan(text: description, style: detailStyle));
    }
    final String location = task.location?.trim() ?? '';
    if (location.isNotEmpty) {
      metadata.add(
        TextSpan(text: l10n.calendarCopyLocation(location), style: detailStyle),
      );
    }
    final String? scheduleText = _calendarTaskScheduleText(task, l10n);
    if (scheduleText != null && scheduleText.isNotEmpty) {
      metadata.add(TextSpan(text: scheduleText, style: detailStyle));
    }
    return metadata;
  }

  String? _calendarTaskScheduleText(CalendarTask task, AppLocalizations l10n) {
    final DateTime? scheduled = task.scheduledTime;
    if (scheduled == null) {
      return null;
    }
    final DateTime? end =
        task.endDate ??
        (task.duration == null ? null : scheduled.add(task.duration!));
    final String startText = TimeFormatter.formatFriendlyDateTime(
      l10n,
      scheduled,
    );
    if (end == null) {
      return startText;
    }
    final String endText = TimeFormatter.formatFriendlyDateTime(l10n, end);
    if (endText == startText) {
      return startText;
    }
    return l10n.commonRangeLabel(startText, endText);
  }

  Future<void> _handleAvailabilityRequest(
    CalendarAvailabilityShare share,
    String? requesterJid, {
    DateTime? preferredStart,
    DateTime? preferredEnd,
  }) async {
    final chat = context.read<ChatBloc>().state.chat;
    if (chat == null) {
      return;
    }
    if (chat.defaultTransport.isEmail) {
      _showSnackbar(
        context.l10n.chatAvailabilityRequestEmailUnsupportedMessage,
      );
      return;
    }
    final trimmedJid = requesterJid?.trim();
    if (trimmedJid == null || trimmedJid.isEmpty) {
      _showSnackbar(context.l10n.chatAvailabilityRequestAccountMissingMessage);
      return;
    }
    final request = await showCalendarAvailabilityRequestSheet(
      context: context,
      share: share,
      requesterJid: trimmedJid,
      preferredStart: preferredStart,
      preferredEnd: preferredEnd,
    );
    if (!mounted || request == null) {
      return;
    }
    context.read<ChatBloc>().add(
      ChatAvailabilityMessageSent(
        chat: chat,
        message: CalendarAvailabilityMessage.request(request: request),
      ),
    );
  }

  Future<void> _openAvailabilityShareViewer({
    required CalendarAvailabilityShare share,
    required bool chatCalendarAvailable,
    required T Function<T>() locate,
    String? requesterJid,
    String? ownerLabel,
    String? chatLabel,
  }) async {
    final String? trimmedJid = requesterJid?.trim();
    final AvailabilityRequestHandler? onRequest =
        trimmedJid == null || trimmedJid.isEmpty
        ? null
        : (start, end) => _handleAvailabilityRequest(
            share,
            trimmedJid,
            preferredStart: start,
            preferredEnd: end,
          );
    await showCalendarAvailabilityShareViewer(
      context: context,
      share: share,
      enableChatCalendar: chatCalendarAvailable,
      locate: locate,
      onRequest: onRequest,
      ownerLabel: ownerLabel,
      chatLabel: chatLabel,
    );
  }

  Future<void> _handleAvailabilityAccept(
    CalendarAvailabilityRequest request, {
    required bool canAddToPersonalCalendar,
    required bool canAddToChatCalendar,
  }) async {
    final chat = context.read<ChatBloc>().state.chat;
    if (chat == null) {
      return;
    }
    if (chat.defaultTransport.isEmail) {
      _showSnackbar(
        context.l10n.chatAvailabilityRequestEmailUnsupportedMessage,
      );
      return;
    }
    if (!canAddToPersonalCalendar && !canAddToChatCalendar) {
      _showSnackbar(
        context.l10n.chatAvailabilityRequestCalendarUnavailableMessage,
      );
      return;
    }
    final decision = await showCalendarAvailabilityDecisionSheet(
      context: context,
      request: request,
      canAddToPersonal: canAddToPersonalCalendar,
      canAddToChat: canAddToChatCalendar,
    );
    if (!mounted || decision == null) {
      return;
    }
    final availabilityTask = _resolveAvailabilityTaskValues(request);
    if (availabilityTask == null) {
      _showSnackbar(context.l10n.chatAvailabilityRequestInvalidRangeMessage);
      return;
    }
    if (decision.addToPersonal) {
      _addAvailabilityTaskToPersonalCalendar(
        title: availabilityTask.title,
        description: availabilityTask.description,
        start: availabilityTask.start,
        duration: availabilityTask.duration,
      );
    }
    if (decision.addToChat) {
      await _addAvailabilityTaskToChatCalendar(
        title: availabilityTask.title,
        description: availabilityTask.description,
        start: availabilityTask.start,
        duration: availabilityTask.duration,
      );
    }
    if (!mounted) {
      return;
    }
    final response = CalendarAvailabilityResponse(
      id: _availabilityResponseIdGenerator.v4(),
      shareId: request.shareId,
      requestId: request.id,
      status: CalendarAvailabilityResponseStatus.accepted,
    );
    context.read<ChatBloc>().add(
      ChatAvailabilityMessageSent(
        chat: chat,
        message: CalendarAvailabilityMessage.response(response: response),
      ),
    );
  }

  void _handleAvailabilityDecline(CalendarAvailabilityRequest request) {
    final chat = context.read<ChatBloc>().state.chat;
    if (chat == null) {
      return;
    }
    if (chat.defaultTransport.isEmail) {
      _showSnackbar(
        context.l10n.chatAvailabilityRequestEmailUnsupportedMessage,
      );
      return;
    }
    final response = CalendarAvailabilityResponse(
      id: _availabilityResponseIdGenerator.v4(),
      shareId: request.shareId,
      requestId: request.id,
      status: CalendarAvailabilityResponseStatus.declined,
    );
    context.read<ChatBloc>().add(
      ChatAvailabilityMessageSent(
        chat: chat,
        message: CalendarAvailabilityMessage.response(response: response),
      ),
    );
  }

  void _addAvailabilityTaskToPersonalCalendar({
    required String title,
    required String? description,
    required DateTime start,
    required Duration duration,
  }) {
    final storageManager = context.read<CalendarStorageManager>();
    if (!storageManager.isAuthStorageReady) {
      _showSnackbar(
        context.l10n.chatAvailabilityRequestCalendarUnavailableMessage,
      );
      return;
    }
    context.read<CalendarBloc>().add(
      CalendarEvent.taskAdded(
        title: title,
        scheduledTime: start,
        duration: duration,
        description: description,
      ),
    );
  }

  Future<void> _addAvailabilityTaskToChatCalendar({
    required String title,
    required String? description,
    required DateTime start,
    required Duration duration,
  }) async {
    final l10n = context.l10n;
    final locate = context.read;
    final chat = locate<ChatBloc>().state.chat;
    if (chat == null ||
        !chat.supportsChatCalendarForAccount(
          accountJid: locate<XmppService>().myJid,
        )) {
      _showSnackbar(l10n.chatAvailabilityRequestChatCalendarUnavailableMessage);
      return;
    }
    final storageManager = locate<CalendarStorageManager>();
    final coordinator = _readChatCalendarCoordinator(
      context,
      calendarAvailable: storageManager.isAuthStorageReady,
    );
    if (coordinator == null) {
      _showSnackbar(l10n.chatAvailabilityRequestChatCalendarUnavailableMessage);
      return;
    }
    final CalendarTask task = CalendarTask.create(
      title: title,
      description: description,
      scheduledTime: start,
      duration: duration,
    );
    try {
      await coordinator.addTask(
        chatJid: context.read<ChatBloc>().state.chat!.jid,
        chatType: context.read<ChatBloc>().state.chat!.type,
        task: task,
      );
    } on Exception {
      if (!mounted) return;
      _showSnackbar(l10n.chatAvailabilityRequestChatCalendarUnavailableMessage);
    }
  }

  Future<String?> _copyTaskToPersonalCalendar(CalendarTask task) async {
    if (!mounted) {
      return null;
    }
    if (!context.read<CalendarStorageManager>().isAuthStorageReady) {
      FeedbackSystem.showInfo(
        context,
        context.l10n.chatCalendarTaskCopyUnavailableMessage,
      );
      return null;
    }
    if (context.read<CalendarBloc>().state.model.tasks.containsKey(task.id)) {
      FeedbackSystem.showInfo(
        context,
        context.l10n.chatCalendarTaskCopyAlreadyAddedMessage,
      );
      return null;
    }
    if (_pendingCalendarImportCompleter != null ||
        context.read<CalendarBloc>().state.isLoading) {
      FeedbackSystem.showInfo(
        context,
        context.l10n.chatCalendarTaskCopyUnavailableMessage,
      );
      return null;
    }
    final Completer<Object?> completer = Completer<Object?>();
    _pendingCalendarImportCompleter = completer;
    context.read<CalendarBloc>().add(
      CalendarEvent.tasksImported(tasks: <CalendarTask>[task]),
    );
    final Object? result = await completer.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        _pendingCalendarImportCompleter = null;
        return null;
      },
    );
    if (!mounted || result is! String) {
      return null;
    }
    return result;
  }

  Future<bool> _copyCriticalPathToPersonalCalendar(
    CalendarModel model,
    String pathId,
    Set<String> taskIds,
  ) async {
    if (!mounted) {
      return false;
    }
    if (!context.read<CalendarStorageManager>().isAuthStorageReady) {
      FeedbackSystem.showInfo(
        context,
        context.l10n.chatCriticalPathCopyUnavailableMessage,
      );
      return false;
    }
    if (_pendingCalendarImportCompleter != null ||
        context.read<CalendarBloc>().state.isLoading) {
      FeedbackSystem.showInfo(
        context,
        context.l10n.chatCriticalPathCopyUnavailableMessage,
      );
      return false;
    }
    final Completer<Object?> completer = Completer<Object?>();
    _pendingCalendarImportCompleter = completer;
    context.read<CalendarBloc>().add(CalendarEvent.modelImported(model: model));
    final Object? result = await completer.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        _pendingCalendarImportCompleter = null;
        return null;
      },
    );
    return result is bool ? result : false;
  }

  void _handleCalendarImportStateChanged(BuildContext _, CalendarState state) {
    final Completer<Object?>? completer = _pendingCalendarImportCompleter;
    if (completer == null || completer.isCompleted || state.isLoading) {
      return;
    }
    if (state.importError == null &&
        state.lastImportedTaskIds.isEmpty &&
        state.lastImportedModelChecksum == null) {
      return;
    }
    _pendingCalendarImportCompleter = null;
    if (state.importError != null) {
      completer.complete(null);
      return;
    }
    final String? importedChecksum = state.lastImportedModelChecksum;
    if (importedChecksum != null) {
      completer.complete(
        importedChecksum == context.read<CalendarBloc>().state.model.checksum,
      );
      return;
    }
    if (state.lastImportedTaskIds.isNotEmpty) {
      completer.complete(context.read<CalendarBloc>().id);
      return;
    }
    completer.complete(null);
  }

  ({String title, String? description, DateTime start, Duration duration})?
  _resolveAvailabilityTaskValues(CalendarAvailabilityRequest request) {
    final DateTime start = request.start.value;
    final DateTime end = request.end.value;
    if (!end.isAfter(start)) {
      return null;
    }
    final Duration duration = end.difference(start);
    final String? rawTitle = request.title?.trim();
    final String? rawDescription = request.description?.trim();
    final String title = rawTitle == null || rawTitle.isEmpty
        ? context.l10n.chatAvailabilityRequestTaskTitleFallback
        : rawTitle;
    final String? description = rawDescription == null || rawDescription.isEmpty
        ? null
        : rawDescription;
    return (
      title: title,
      description: description,
      start: start,
      duration: duration,
    );
  }

  String get _scrollStorageKey {
    String? chatJid() => context.read<ChatBloc>().jid;
    final suffix = chatJid() == null || chatJid()!.isEmpty
        ? 'unknown'
        : chatJid()!;
    return '$_chatScrollStoragePrefix$suffix';
  }

  double _restoreScrollOffset({String? key}) {
    final storageKey = key ?? _scrollStorageKey;
    final cached = _scrollOffsetCache[storageKey];
    if (cached != null) return cached;
    final bucket = PageStorage.maybeOf(context);
    if (bucket == null) return 0;
    final restored = bucket.readState(context, identifier: storageKey);
    if (restored is double) return restored;
    if (restored is num) return restored.toDouble();
    return 0;
  }

  void _persistScrollOffset({String? key, bool skipPageStorage = false}) {
    if (!mounted) return;
    final offset = _scrollController.hasClients
        ? _scrollController.offset
        : _scrollController.initialScrollOffset;
    final storageKey = key ?? _lastScrollStorageKey ?? _scrollStorageKey;
    if (storageKey.isEmpty) return;
    _scrollOffsetCache[storageKey] = offset;
    if (skipPageStorage) return;
    final bucket = PageStorage.maybeOf(context);
    if (bucket != null) {
      bucket.writeState(context, offset, identifier: storageKey);
    }
  }

  void _handleScrollChanged() {
    _persistScrollOffset();
    _scheduleReadThresholdSync();
  }

  Rect? _messageListViewportRect() {
    final messageListContext = _messageListKey.currentContext;
    if (messageListContext == null) {
      return null;
    }
    final renderObject = messageListContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) {
      return null;
    }
    final origin = renderObject.localToGlobal(Offset.zero);
    return origin & renderObject.size;
  }

  Set<String> _readThresholdMessageIds(ChatState state) {
    if (!state.messagesLoaded || !_chatRoute.allowsChatInteraction) {
      return const <String>{};
    }
    final viewportRect = _messageListViewportRect();
    if (viewportRect == null) {
      return const <String>{};
    }
    final messageIds = <String>{};
    for (final message in state.items) {
      final messageId = message.stanzaID.trim();
      if (messageId.isEmpty) {
        continue;
      }
      final bubbleRect = _bubbleRegionRegistry.rectFor(messageId);
      if (bubbleRect == null || bubbleRect.height <= 0) {
        continue;
      }
      final thresholdY = bubbleRect.top + (bubbleRect.height * 0.6);
      if (thresholdY < viewportRect.top || thresholdY > viewportRect.bottom) {
        continue;
      }
      messageIds.add(messageId);
    }
    return messageIds;
  }

  void _syncReadThresholdIds() {
    if (!mounted) {
      return;
    }
    final chatState = context.read<ChatBloc>().state;
    if (shouldDeferReadThresholdSyncForTesting(
      messagesLoaded: chatState.messagesLoaded,
      initialTimelineReadinessPending: _initialTimelineReadinessPending(
        chatState,
      ),
    )) {
      return;
    }
    final nextIds = _readThresholdMessageIds(chatState);
    if (nextIds.length == _reportedReadThresholdMessageIds.length &&
        nextIds.containsAll(_reportedReadThresholdMessageIds)) {
      return;
    }
    _reportedReadThresholdMessageIds = nextIds;
    final messageIds = nextIds.toList(growable: false)..sort();
    context.read<ChatBloc>().add(ChatReadThresholdChanged(messageIds));
  }

  bool _unreadDividerScrollTargetPending(ChatState state) {
    return state.scrollTargetMessageId ==
            ChatBloc.unreadDividerScrollTargetMessageId &&
        state.scrollTargetRequestId > _completedUnreadDividerScrollRequestId;
  }

  bool _initialUnreadScrollPending(ChatState state) {
    return state.messagesLoaded && _unreadDividerScrollTargetPending(state);
  }

  bool _chatHasEmailBackedMessages(ChatState state) {
    for (final message in state.items) {
      if (message.isEmailBacked) {
        return true;
      }
    }
    return false;
  }

  bool _initialEmailViewportFullHtmlSettled(ChatState state) {
    for (final deltaMessageId in _initialEmailViewportDeltaIds) {
      if (!state.emailFullHtmlByDeltaId.containsKey(deltaMessageId) &&
          !state.emailFullHtmlUnavailable.contains(deltaMessageId)) {
        return false;
      }
    }
    return true;
  }

  bool _initialEmailViewportReadinessPending(ChatState state) {
    if (!state.messagesLoaded || !_chatHasEmailBackedMessages(state)) {
      return false;
    }
    if (_initialEmailViewportWarmupStatus !=
        _InitialEmailViewportWarmupStatus.warmed) {
      return true;
    }
    return !_initialEmailViewportFullHtmlSettled(state);
  }

  bool _initialTimelineReadinessPending(ChatState state) {
    return state.messagesLoaded &&
        (_unreadDividerScrollTargetPending(state) ||
            _initialEmailViewportReadinessPending(state));
  }

  void _resetInitialTimelineReadiness() {
    _initialEmailViewportWarmupStatus =
        _InitialEmailViewportWarmupStatus.pending;
    _initialEmailViewportDeltaIds = const <int>{};
    _lastRenderedHydrationSnapshot = null;
    _initialEmailViewportWarmupRequestId += 1;
  }

  List<Message> _emailWarmWindowForRenderedMessages(
    List<Message> renderedMessages,
  ) {
    if (_cachedFilteredItems.isEmpty || renderedMessages.isEmpty) {
      return renderedMessages;
    }
    final indexByStanzaId = <String, int>{
      for (var index = 0; index < _cachedFilteredItems.length; index += 1)
        _cachedFilteredItems[index].stanzaID: index,
    };
    int? minIndex;
    int? maxIndex;
    for (final message in renderedMessages) {
      final index = indexByStanzaId[message.stanzaID];
      if (index == null) {
        continue;
      }
      minIndex = minIndex == null ? index : math.min(minIndex, index);
      maxIndex = maxIndex == null ? index : math.max(maxIndex, index);
    }
    if (minIndex == null || maxIndex == null) {
      return renderedMessages;
    }
    final margin = ChatBloc.messageBatchSize ~/ 2;
    final start = math.max(0, minIndex - margin);
    final end = math.min(_cachedFilteredItems.length, maxIndex + margin + 1);
    return List<Message>.unmodifiable(_cachedFilteredItems.sublist(start, end));
  }

  Set<int> _visibleEmailDeltaIdsForInitialReadiness(
    List<Message> renderedMessages,
  ) {
    final ids = <int>{};
    for (final message in renderedMessages) {
      if (!message.isEmailBacked) {
        continue;
      }
      final deltaMessageId = message.deltaMsgId;
      if (deltaMessageId != null && deltaMessageId > 0) {
        ids.add(deltaMessageId);
      }
    }
    return Set<int>.unmodifiable(ids);
  }

  _RenderedHydrationSnapshot _renderedHydrationSnapshot(
    List<Message> renderedMessages,
    ChatState state,
  ) {
    return _RenderedHydrationSnapshot(
      emailServiceAvailable: state.emailServiceAvailable,
      emailFullHtmlUnavailableCount: state.emailFullHtmlUnavailable.length,
      emailQuotedTextUnavailableCount: state.emailQuotedTextUnavailable.length,
      messages: List<_RenderedMessageHydrationSnapshot>.unmodifiable(
        renderedMessages.map(_RenderedMessageHydrationSnapshot.fromMessage),
      ),
    );
  }

  void _handleRenderedMessagesChanged(
    List<Message> renderedMessages, {
    required T Function<T>() locate,
  }) {
    if (renderedMessages.isEmpty) {
      return;
    }
    final chatBloc = locate<ChatBloc>();
    final chatState = chatBloc.state;
    final warmWindow = _emailWarmWindowForRenderedMessages(renderedMessages);
    final warmup = _prewarmEmailHtmlDerivationsForMessages(
      messages: warmWindow,
      emailFullHtmlByDeltaId: chatState.emailFullHtmlByDeltaId,
      source:
          _initialEmailViewportWarmupStatus ==
              _InitialEmailViewportWarmupStatus.warmed
          ? 'renderedWindow'
          : 'initialViewport',
    );
    final hydrationSnapshot = _renderedHydrationSnapshot(
      renderedMessages,
      chatState,
    );
    if (hydrationSnapshot != _lastRenderedHydrationSnapshot) {
      _lastRenderedHydrationSnapshot = hydrationSnapshot;
      chatBloc.add(ChatRenderedMessagesHydrationRequested(renderedMessages));
    }
    if (!_initialEmailViewportWarmupApplies(chatState)) {
      unawaited(warmup);
      return;
    }
    final requestId = _initialEmailViewportWarmupRequestId + 1;
    _initialEmailViewportWarmupRequestId = requestId;
    _initialEmailViewportWarmupStatus =
        _InitialEmailViewportWarmupStatus.warming;
    _initialEmailViewportDeltaIds = _visibleEmailDeltaIdsForInitialReadiness(
      renderedMessages,
    );
    unawaited(_completeInitialEmailViewportWarmup(requestId, warmup));
  }

  bool _initialEmailViewportWarmupApplies(ChatState state) {
    return state.messagesLoaded &&
        !_unreadDividerScrollTargetPending(state) &&
        _chatHasEmailBackedMessages(state) &&
        _initialEmailViewportWarmupStatus !=
            _InitialEmailViewportWarmupStatus.warmed;
  }

  Future<void> _completeInitialEmailViewportWarmup(
    int requestId,
    Future<void> warmup,
  ) async {
    await warmup;
    if (!mounted || requestId != _initialEmailViewportWarmupRequestId) {
      return;
    }
    setState(() {
      _initialEmailViewportWarmupStatus =
          _InitialEmailViewportWarmupStatus.warmed;
    });
    _scheduleReadThresholdSync();
  }

  void _handlePendingUnreadDividerScroll(ChatState state) {
    if (!_initialUnreadScrollPending(state)) {
      return;
    }
    if (state.scrollTargetRequestId == _activeUnreadDividerScrollRequestId) {
      return;
    }
    _activeUnreadDividerScrollRequestId = state.scrollTargetRequestId;
    unawaited(
      _handleUnreadBoundaryScrollRequest(
        state.unreadBoundaryStanzaId,
        requestId: state.scrollTargetRequestId,
      ),
    );
  }

  void _completeUnreadDividerScrollRequest(int requestId) {
    if (_activeUnreadDividerScrollRequestId == requestId) {
      _activeUnreadDividerScrollRequestId = 0;
    }
    if (requestId <= _completedUnreadDividerScrollRequestId) {
      return;
    }
    if (!mounted) {
      _completedUnreadDividerScrollRequestId = requestId;
      return;
    }
    setState(() {
      _completedUnreadDividerScrollRequestId = math.max(
        _completedUnreadDividerScrollRequestId,
        requestId,
      );
    });
    _scheduleReadThresholdSync();
  }

  void _scheduleReadThresholdSync() {
    if (!mounted || _readThresholdSyncScheduled) {
      return;
    }
    _readThresholdSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readThresholdSyncScheduled = false;
      if (!mounted) {
        return;
      }
      _syncReadThresholdIds();
    });
  }

  void _restoreScrollOffsetForCurrentChat() {
    if (_unreadDividerScrollTargetPending(context.read<ChatBloc>().state)) {
      _scheduleReadThresholdSync();
      return;
    }
    final target = _restoreScrollOffset();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_unreadDividerScrollTargetPending(context.read<ChatBloc>().state)) {
        _scheduleReadThresholdSync();
        return;
      }
      if (!_scrollController.hasClients) {
        _scheduleReadThresholdSync();
        return;
      }
      final position = _scrollController.position;
      if (!position.hasPixels) {
        _scheduleReadThresholdSync();
        return;
      }
      final maxExtent = position.maxScrollExtent;
      final clamped = target.clamp(0.0, math.max(0.0, maxExtent)).toDouble();
      if (position.pixels != clamped) {
        _scrollController.jumpTo(clamped);
      }
      _scheduleReadThresholdSync();
    });
  }

  String? _resolveAvailabilityOwnerLabel({
    required String? ownerJid,
    required String? normalizedXmppSelfJid,
    required String? normalizedEmailSelfJid,
    required String selfLabel,
  }) {
    final String? trimmedOwner = ownerJid?.trim();
    if (trimmedOwner == null || trimmedOwner.isEmpty) {
      return null;
    }
    final String? normalizedOwner = normalizedAddressKey(trimmedOwner);
    if (normalizedOwner == null) {
      return trimmedOwner;
    }
    if (normalizedOwner == normalizedXmppSelfJid ||
        normalizedOwner == normalizedEmailSelfJid) {
      return selfLabel;
    }
    return trimmedOwner;
  }

  bool _isRoomBootstrapInProgress(ChatState state) {
    if (state.xmppConnectionState != ConnectionState.connected) {
      return false;
    }
    final roomState = state.roomState;
    if (roomState == null) {
      return true;
    }
    return roomState.isBootstrapPending;
  }

  RoomState? _roomJoinFailureState(ChatState state) {
    final roomState = state.roomState;
    if (roomState == null) {
      return null;
    }
    if (roomState.hasJoinError || roomState.hasTerminalExit) {
      return roomState;
    }
    return null;
  }

  bool _isQuotedMessageFromSelf({
    required Message quotedMessage,
    required bool isGroupChat,
    required RoomState? roomState,
    required String? currentUserId,
  }) {
    if (isGroupChat) {
      return isMucSelfMessage(
        message: quotedMessage,
        roomState: roomState,
        selfJid: currentUserId,
      );
    }
    return quotedMessage.isFromAccount(currentUserId);
  }

  String _quotedSenderLabel({
    required Message quotedMessage,
    required bool isGroupChat,
    required RoomState? roomState,
    required String? chatDisplayName,
    required AppLocalizations l10n,
  }) {
    if (isGroupChat) {
      final nick = roomState?.senderNick(quotedMessage.senderJid);
      final normalizedNick = nick?.trim() ?? _emptyText;
      if (normalizedNick.isNotEmpty) {
        return normalizedNick;
      }
    } else {
      final displayName = chatDisplayName?.trim() ?? _emptyText;
      if (displayName.isNotEmpty) {
        return displayName;
      }
    }
    final senderFallback = quotedMessage.senderJid.trim();
    if (senderFallback.isNotEmpty) {
      return senderFallback;
    }
    return l10n.commonUnknownLabel;
  }

  void _appendErrorBubbleContent({
    required BuildContext context,
    required Object bubbleContentKey,
    required String messageText,
    required Color textColor,
    required TextStyle baseTextStyle,
    required TextStyle linkStyle,
    required List<InlineSpan> messageDetails,
    required Map<int, double> detailOpticalOffsetFactors,
    required List<Widget> bubbleTextChildren,
  }) {
    bubbleTextChildren.addAll([
      Text(
        context.l10n.chatErrorLabel,
        style: context.textTheme.small.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      _ParsedMessageBody(
        contentKey: bubbleContentKey,
        text: messageText,
        baseStyle: baseTextStyle,
        linkStyle: linkStyle,
        details: messageDetails,
        detailOpticalOffsetFactors: detailOpticalOffsetFactors,
        onLinkTap: _handleLinkTap,
        onLinkLongPress: _handleLinkTap,
      ),
    ]);
  }

  void _appendInviteBubbleContent({
    required BuildContext context,
    required ChatTimelineMessageItem timelineMessageItem,
    required bool isSelfBubble,
    required Message messageModel,
    required String? selfXmppJid,
    required Object bubbleContentKey,
    required TextStyle baseTextStyle,
    required List<InlineSpan> messageDetails,
    required Map<int, double> detailOpticalOffsetFactors,
    required List<Widget> bubbleTextChildren,
    required _MessageBubbleExtraAdder addExtra,
  }) {
    final inviteActionFallbackLabel =
        context.l10n.chatInviteActionFallbackLabel;
    final inviteLabel = timelineMessageItem.inviteLabel;
    final inviteActionLabel =
        timelineMessageItem.inviteActionLabel.trim().isNotEmpty
        ? timelineMessageItem.inviteActionLabel
        : inviteActionFallbackLabel;
    final inviteRoomName = timelineMessageItem.inviteRoomName?.trim() ?? '';
    final inviteRoom = timelineMessageItem.inviteRoom?.trim() ?? '';
    final inviteActionEnabled = timelineMessageItem.inviteJoinActionEnabled;
    final inviteCardLabel =
        timelineMessageItem.inviteAccepted || timelineMessageItem.inviteRevoked
        ? inviteLabel
        : inviteRoomName.isNotEmpty
        ? inviteRoomName
        : inviteRoom.isNotEmpty
        ? inviteRoom
        : inviteLabel;
    final inviteCardDetail =
        timelineMessageItem.inviteAccepted || timelineMessageItem.inviteRevoked
        ? inviteRoomName.isNotEmpty
              ? inviteRoomName
              : inviteRoom
        : inviteRoom.isNotEmpty
        ? inviteRoom
        : inviteLabel;
    final inviteCardShape = _attachmentSurfaceShape(
      context: context,
      isSelf: isSelfBubble,
      chainedPrevious: bubbleTextChildren.isNotEmpty,
      chainedNext: false,
    );
    if (!timelineMessageItem.inviteAccepted &&
        !timelineMessageItem.inviteRevoked) {
      bubbleTextChildren.add(
        DynamicInlineText(
          key: ValueKey<Object>(bubbleContentKey),
          text: TextSpan(text: inviteLabel, style: baseTextStyle),
          details: messageDetails,
          detailOpticalOffsetFactors: detailOpticalOffsetFactors,
          onLinkTap: _handleLinkTap,
          onLinkLongPress: _handleLinkTap,
        ),
      );
    }
    addExtra(
      _InviteAttachmentCard(
        shape: inviteCardShape,
        enabled: inviteActionEnabled,
        accepted: timelineMessageItem.inviteAccepted,
        revoked: timelineMessageItem.inviteRevoked,
        label: inviteCardLabel,
        detailLabel: inviteCardDetail,
        actionLabel: inviteActionLabel,
        onPressed: () => _handleInviteTap(messageModel, selfJid: selfXmppJid),
      ),
      shape: inviteCardShape,
      spacing: context.spacing.s,
    );
  }

  void _appendAttachmentBubbleExtras({
    required BuildContext context,
    required List<String> attachmentIds,
    required bool hasBubbleAnchor,
    required bool chainsFromPreviousMessage,
    required bool chainsIntoNextMessage,
    required bool isSelfBubble,
    required bool isEmailChat,
    required bool attachmentsBlockedForChat,
    required Message messageModel,
    required ChatState state,
    required Object bubbleContentKey,
    required List<InlineSpan> surfaceDetails,
    required Map<int, double> detailOpticalOffsetFactors,
    required _MessageBubbleExtraAdder addExtra,
  }) {
    final settings = context.watch<SettingsCubit>().state;
    final allowAttachmentOnce = attachmentsBlockedForChat
        ? false
        : _isOneTimeAttachmentAllowed(messageModel.stanzaID);
    final locate = context.read;
    final attachmentUsesEmailProtocol =
        messageModel.isEmailBacked ||
        (isEmailChat &&
            (messageModel.hasRfc822BodyContent ||
                messageModel.hasGeneratedEmailAttachmentCaption));
    final emailDownloadDelegate = attachmentUsesEmailProtocol
        ? AttachmentDownloadDelegate(() async {
            return locate<ChatBloc>().downloadFullEmailMessage(messageModel);
          })
        : null;
    for (var index = 0; index < attachmentIds.length; index += 1) {
      final attachmentId = attachmentIds[index];
      final metadata = _metadataFor(state: state, metadataId: attachmentId);
      final allowAttachmentByTrust = _shouldAllowAttachment(
        isSelf: isSelfBubble,
        chat: state.chat,
        settings: settings,
        metadata: metadata,
        chatBlocked: attachmentsBlockedForChat,
      );
      final allowAttachment =
          !attachmentsBlockedForChat &&
          (attachmentUsesEmailProtocol ||
              allowAttachmentByTrust ||
              allowAttachmentOnce);
      final downloadDelegate = attachmentUsesEmailProtocol
          ? emailDownloadDelegate
          : AttachmentDownloadDelegate(() async {
              final approved = await _confirmManualAttachmentDownload(
                senderJid: messageModel.senderJid,
                isSelf: isSelfBubble,
                senderEmail: state.chat?.emailAddress,
              );
              if (!approved || !mounted) return false;
              return locate<ChatBloc>().downloadInboundAttachment(
                metadataId: attachmentId,
                stanzaId: messageModel.stanzaID,
              );
            });
      final metadataReloadDelegate = AttachmentMetadataReloadDelegate(
        () => context.read<ChatBloc>().reloadFileMetadata(attachmentId),
      );
      final hasAttachmentAbove =
          index > 0 || hasBubbleAnchor || chainsFromPreviousMessage;
      final hasAttachmentBelow =
          index < attachmentIds.length - 1 ||
          (chainsIntoNextMessage && index == attachmentIds.length - 1);
      final attachmentShape = _attachmentSurfaceShape(
        context: context,
        isSelf: isSelfBubble,
        chainedPrevious: hasAttachmentAbove,
        chainedNext: hasAttachmentBelow,
      );
      addExtra(
        ChatAttachmentPreview(
          key: ValueKey<String>(
            '$bubbleContentKey-attachment-preview-$attachmentId',
          ),
          stanzaId: messageModel.stanzaID,
          metadata: metadata,
          metadataPending: _metadataPending(
            state: state,
            metadataId: attachmentId,
          ),
          allowed: allowAttachment,
          downloadDelegate: downloadDelegate,
          metadataReloadDelegate: metadataReloadDelegate,
          onAllowPressed: allowAttachment
              ? null
              : attachmentsBlockedForChat
              ? null
              : () => _approveAttachment(
                  message: messageModel,
                  senderJid: messageModel.senderJid,
                  stanzaId: messageModel.stanzaID,
                  isSelf: isSelfBubble,
                  isEmailChat: isEmailChat,
                  senderEmail: state.chat?.emailAddress,
                ),
          surfaceShape: attachmentShape,
          messageDetails: surfaceDetails,
          detailOpticalOffsetFactors: detailOpticalOffsetFactors,
        ),
        shape: attachmentShape,
        spacing: context.spacing.s,
        key: ValueKey<String>(
          '$bubbleContentKey-attachment-extra-$attachmentId',
        ),
      );
    }
  }

  void _appendMessageSubjectBanner({
    required BuildContext context,
    required String subjectText,
    required Color textColor,
    required List<Widget> bubbleTextChildren,
  }) {
    final textTheme = context.textTheme;
    final baseSubjectStyle = textTheme.small;
    final subjectStyle = baseSubjectStyle.copyWith(
      color: textColor,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
    final subjectPainter = TextPainter(
      text: TextSpan(text: subjectText, style: subjectStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
    )..layout();
    bubbleTextChildren.add(Text(subjectText, style: subjectStyle));
    bubbleTextChildren.add(
      Padding(
        padding: EdgeInsets.zero,
        child: DecoratedBox(
          decoration: BoxDecoration(color: context.colorScheme.border),
          child: SizedBox(
            height: context.borderSide.width,
            width: subjectPainter.width,
          ),
        ),
      ),
    );
  }

  void _appendCollapsedEmailPreviewBubbleContent({
    required BuildContext context,
    required String collapsedEmailPreviewText,
    required Object bubbleContentKey,
    required TextStyle baseTextStyle,
    required List<InlineSpan> messageDetails,
    required Map<int, double> detailOpticalOffsetFactors,
    required List<Widget> bubbleTextChildren,
  }) {
    bubbleTextChildren.add(
      Text(
        collapsedEmailPreviewText,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: baseTextStyle,
      ),
    );
    bubbleTextChildren.add(
      Padding(
        padding: EdgeInsets.only(top: context.spacing.xs),
        child: ChatInlineDetails(
          details: messageDetails,
          detailOpticalOffsetFactors: detailOpticalOffsetFactors,
        ),
      ),
    );
  }

  void _appendInlineEmailHtmlBubbleContent({
    required BuildContext context,
    required bool isSelfBubble,
    required bool isSingleSelection,
    required bool autoLoadEmailImages,
    required bool hasRemoteHtmlImages,
    required String? rawHtmlBody,
    required String normalizedHtmlBody,
    required String? normalizedHtmlText,
    required EmailHtmlDerivation emailDerivation,
    required String preparedHtmlBody,
    required String messageStanzaId,
    required String? messageDatabaseId,
    required Object bubbleContentKey,
    required TextStyle baseTextStyle,
    required TextStyle linkStyle,
    required Color bubbleColor,
    required Color textColor,
    required List<InlineSpan> messageDetails,
    required Map<int, double> detailOpticalOffsetFactors,
    required List<Widget> bubbleTextChildren,
  }) {
    final shouldLoadImagesInWebView =
        autoLoadEmailImages ||
        (messageDatabaseId != null &&
            _loadedEmailImageMessageIds.contains(messageDatabaseId));
    final onLoadRequested = messageDatabaseId == null
        ? null
        : () => _handleEmailImagesApproved(messageDatabaseId);
    final emailFallbackText = normalizedHtmlText?.isNotEmpty == true
        ? normalizedHtmlText
        : null;
    final shouldRenderHtmlBody =
        !emailPlainTextBubbleExperiment &&
        preparedHtmlBody.trim().isNotEmpty &&
        _emailHtmlHasVisibleTimelineContent(
          normalizedHtmlBody: normalizedHtmlBody,
          normalizedHtmlText: normalizedHtmlText,
          derivation: emailDerivation,
        );
    if (preparedHtmlBody.trim().isNotEmpty) {
      logEmailHtmlStages(
        contentKey: bubbleContentKey,
        stages: {
          'raw': rawHtmlBody,
          'normalized': normalizedHtmlBody,
          'prepared-flutter-html': preparedHtmlBody,
        },
      );
    }
    final shouldUseSelectedInlineEmailWebView =
        shouldUseSelectedInlineEmailWebViewForTesting(
          isSingleSelection: isSingleSelection,
          shouldRenderHtmlBody: shouldRenderHtmlBody,
        );
    final shouldShowLoadImagesButton =
        shouldShowSelectedEmailImageLoadButtonForTesting(
          isSingleSelection: isSingleSelection,
          shouldRenderHtmlBody: shouldRenderHtmlBody,
          hasRemoteHtmlImages: hasRemoteHtmlImages,
          shouldLoadImages: shouldLoadImagesInWebView,
          hasLoadCallback: onLoadRequested != null,
        );
    final initialChildCount = bubbleTextChildren.length;
    if (!shouldRenderHtmlBody &&
        emailFallbackText != null &&
        emailFallbackText.isNotEmpty) {
      bubbleTextChildren.add(
        _ParsedMessageBody(
          contentKey: '${bubbleContentKey}_email',
          text: emailFallbackText,
          baseStyle: baseTextStyle,
          linkStyle: linkStyle,
          details: const [],
          onLinkTap: _handleLinkTap,
          onLinkLongPress: _handleLinkTap,
        ),
      );
    }
    if (shouldRenderHtmlBody) {
      final linkColor =
          linkStyle.color ??
          (isSelfBubble
              ? context.colorScheme.primaryForeground
              : context.colorScheme.primary);
      final webViewBaseFontSize =
          baseTextStyle.fontSize ??
          context.textTheme.small.fontSize ??
          context.sizing.menuItemIconSize;
      final webViewHeightCacheKey = _emailWebViewHeightCacheKey(
        bubbleContentKey: bubbleContentKey,
        html: normalizedHtmlBody,
        shouldLoadImages: shouldLoadImagesInWebView,
        baseFontSize: webViewBaseFontSize,
      );
      if (shouldShowLoadImagesButton) {
        bubbleTextChildren.add(
          Padding(
            padding: EdgeInsets.only(bottom: context.spacing.xs),
            child: EmailImagePlaceholder(onTap: onLoadRequested),
          ),
        );
      }
      bubbleTextChildren.add(
        shouldUseSelectedInlineEmailWebView
            ? _MessageHtmlWebViewBody(
                key: ValueKey<String>('${bubbleContentKey}_webview'),
                html: normalizedHtmlBody,
                loadingHtml: preparedHtmlBody,
                rawHtml: rawHtmlBody,
                diagnosticContentKey: '${bubbleContentKey}_selected_webview',
                textStyle: baseTextStyle,
                backgroundColor: bubbleColor,
                textColor: textColor,
                linkColor: linkColor,
                baseFontSize: webViewBaseFontSize,
                shouldLoadImages: shouldLoadImagesInWebView,
                initialContentHeight: _emailWebViewHeightFor(
                  webViewHeightCacheKey,
                ),
                onLinkTap: _handleLinkTap,
                onContentHeightChanged: (height) => _updateEmailWebViewHeight(
                  contentKey: webViewHeightCacheKey,
                  messageId: messageStanzaId,
                  height: height,
                ),
              )
            : _MessageHtmlBody(
                key: ValueKey<Object>(bubbleContentKey),
                html: preparedHtmlBody,
                textStyle: baseTextStyle,
                textColor: textColor,
                linkColor: linkColor,
                shouldLoadImages: false,
                onLinkTap: _handleLinkTap,
              ),
      );
    }
    if (messageDetails.isNotEmpty &&
        bubbleTextChildren.length > initialChildCount) {
      bubbleTextChildren.add(
        Padding(
          padding: EdgeInsets.only(top: context.spacing.xs),
          child: ChatInlineDetails(
            details: messageDetails,
            detailOpticalOffsetFactors: detailOpticalOffsetFactors,
          ),
        ),
      );
    }
  }

  void _appendGroupedEmailBodyBubbleContent({
    required BuildContext context,
    required bool isSelfBubble,
    required bool isSingleSelection,
    required bool autoLoadEmailImages,
    required String messageStanzaId,
    required Object bubbleContentKey,
    required TextStyle baseTextStyle,
    required TextStyle linkStyle,
    required Color bubbleColor,
    required Color textColor,
    required List<InlineSpan> messageDetails,
    required Map<int, double> detailOpticalOffsetFactors,
    required List<Widget> bubbleTextChildren,
    required List<ChatTimelineEmailBodyBlock> emailBodyBlocks,
  }) {
    final visibleBlocks = emailBodyBlocks
        .where(
          (block) =>
              block.plainText.trim().isNotEmpty ||
              HtmlContentCodec.normalizeHtml(block.resolvedHtmlBody) != null,
        )
        .toList(growable: false);
    for (var index = 0; index < visibleBlocks.length; index += 1) {
      final block = visibleBlocks[index];
      if (index > 0) {
        bubbleTextChildren.add(SizedBox(height: context.spacing.s));
      }
      final normalizedHtmlBody = HtmlContentCodec.normalizeHtml(
        block.resolvedHtmlBody,
      );
      final emailDerivation = emailHtmlDerivationForBody(normalizedHtmlBody);
      final visibleSanitizedHtmlText = emailDerivation?.visibleBodyText;
      final normalizedHtmlText = visibleSanitizedHtmlText;
      final renderedText = block.plainText.trim().isNotEmpty
          ? block.plainText
          : (visibleSanitizedHtmlText ?? _emptyText);
      final shouldRenderHtmlBody =
          normalizedHtmlBody != null &&
          emailDerivation != null &&
          (isSingleSelection ||
              HtmlContentCodec.shouldRenderRichEmailHtml(
                normalizedHtmlBody: normalizedHtmlBody,
                normalizedHtmlText: normalizedHtmlText,
                renderedText: renderedText,
              ));
      final blockDetails = index == visibleBlocks.length - 1
          ? messageDetails
          : const <InlineSpan>[];
      if (shouldRenderHtmlBody) {
        _appendInlineEmailHtmlBubbleContent(
          context: context,
          isSelfBubble: isSelfBubble,
          isSingleSelection: isSingleSelection,
          autoLoadEmailImages: autoLoadEmailImages,
          hasRemoteHtmlImages: emailDerivation.containsRemoteImages,
          rawHtmlBody: block.resolvedHtmlBody,
          normalizedHtmlBody: normalizedHtmlBody,
          normalizedHtmlText: visibleSanitizedHtmlText,
          emailDerivation: emailDerivation,
          preparedHtmlBody: emailDerivation.preparedFlutterHtml,
          messageStanzaId: messageStanzaId,
          messageDatabaseId: block.sourceMessageDatabaseId,
          bubbleContentKey:
              '${bubbleContentKey}_email_block_${block.sourceStanzaId}',
          baseTextStyle: baseTextStyle,
          linkStyle: linkStyle,
          bubbleColor: bubbleColor,
          textColor: textColor,
          messageDetails: blockDetails,
          detailOpticalOffsetFactors: detailOpticalOffsetFactors,
          bubbleTextChildren: bubbleTextChildren,
        );
        continue;
      }
      _appendTextBodyBubbleContent(
        context: context,
        bubbleContentKey:
            '${bubbleContentKey}_email_block_${block.sourceStanzaId}',
        displayMessageText: renderedText,
        trimmedDisplayMessageText: renderedText.trim(),
        baseTextStyle: baseTextStyle,
        linkStyle: linkStyle,
        messageDetails: blockDetails,
        detailOpticalOffsetFactors: detailOpticalOffsetFactors,
        bubbleTextChildren: bubbleTextChildren,
      );
    }
  }

  void _appendTextBodyBubbleContent({
    required BuildContext context,
    required Object bubbleContentKey,
    required String displayMessageText,
    required String trimmedDisplayMessageText,
    required TextStyle baseTextStyle,
    required TextStyle linkStyle,
    required List<InlineSpan> messageDetails,
    required Map<int, double> detailOpticalOffsetFactors,
    required List<Widget> bubbleTextChildren,
  }) {
    if (trimmedDisplayMessageText.isNotEmpty) {
      bubbleTextChildren.add(
        _ParsedMessageBody(
          contentKey: bubbleContentKey,
          text: displayMessageText,
          baseStyle: baseTextStyle,
          linkStyle: linkStyle,
          details: messageDetails,
          detailOpticalOffsetFactors: detailOpticalOffsetFactors,
          onLinkTap: _handleLinkTap,
          onLinkLongPress: _handleLinkTap,
        ),
      );
      return;
    }
    bubbleTextChildren.add(
      Padding(
        padding: EdgeInsets.only(top: context.spacing.xs),
        child: ChatInlineDetails(
          details: messageDetails,
          detailOpticalOffsetFactors: detailOpticalOffsetFactors,
        ),
      ),
    );
  }

  ({bool hideFragmentText, bool hideAvailabilityText, bool hideTaskText})
  _appendCalendarBubbleExtras({
    required BuildContext context,
    required chat_models.Chat? chatEntity,
    required Message messageModel,
    required RoomState? roomState,
    required String trimmedRenderedText,
    required String? availabilityActorId,
    required Map<String, String> availabilityShareOwnersById,
    required CalendarAvailabilityShareCoordinator? availabilityCoordinator,
    required String? normalizedXmppSelfJid,
    required String? normalizedEmailSelfJid,
    required bool personalCalendarAvailable,
    required bool chatCalendarAvailable,
    required CalendarTask? calendarTaskIcs,
    required bool calendarTaskIcsReadOnly,
    required CalendarFragment? displayFragment,
    required CalendarAvailabilityMessage? availabilityMessage,
    required bool isSelfBubble,
    required TextStyle surfaceDetailStyle,
    required List<InlineSpan> surfaceDetails,
    required _MessageBubbleExtraAdder addExtra,
  }) {
    final taskShareText = calendarTaskIcs?.toShareText(context.l10n).trim();
    final fragmentFallbackText = displayFragment == null
        ? null
        : CalendarFragmentFormatter(
            context.l10n,
          ).describe(displayFragment).trim();
    final hideFragmentText =
        fragmentFallbackText != null &&
        fragmentFallbackText.isNotEmpty &&
        fragmentFallbackText == trimmedRenderedText;
    final hideAvailabilityText =
        availabilityMessage != null && messageModel.error.isNone;
    final hideTaskText =
        taskShareText != null && taskShareText == trimmedRenderedText;
    final shareMetadataDetails = hideTaskText && calendarTaskIcs != null
        ? _calendarTaskShareMetadata(
            calendarTaskIcs,
            context.l10n,
            surfaceDetailStyle,
          )
        : _emptyInlineSpans;
    final fragmentFooterDetails = hideFragmentText
        ? surfaceDetails
        : _emptyInlineSpans;
    final availabilityFooterDetails = hideAvailabilityText
        ? surfaceDetails
        : _emptyInlineSpans;
    final taskFooterDetails = hideTaskText
        ? <InlineSpan>[...surfaceDetails, ...shareMetadataDetails]
        : _emptyInlineSpans;
    CalendarAvailabilityShare? availabilityShare;
    String? availabilityShareRequesterJid;
    VoidCallback? availabilityOnAccept;
    VoidCallback? availabilityOnDecline;

    bool availabilityActorMatchesClaimedJid(String claimedJid) {
      final currentActor = availabilityActorId;
      if (currentActor == null) {
        return false;
      }
      if (messageModel.effectiveSenderRealJid != null ||
          messageModel.isMucOccupantSender) {
        return messageModel.senderMatchesClaimedJid(claimedJid);
      }
      return sameBareAddress(currentActor, claimedJid);
    }

    final calendarMessageCardShape = ContinuousRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(context.spacing.m)),
    );
    if (availabilityMessage != null) {
      availabilityMessage.map(
        share: (value) {
          final isOwner = availabilityActorMatchesClaimedJid(
            value.share.overlay.owner,
          );
          availabilityShare = value.share;
          availabilityShareRequesterJid = isOwner ? null : availabilityActorId;
        },
        request: (value) {
          final requestOwnerJid = value.request.ownerJid?.trim();
          final ownerJid = requestOwnerJid == null || requestOwnerJid.isEmpty
              ? availabilityShareOwnersById[value.request.shareId] ??
                    availabilityCoordinator?.ownerJidForShare(
                      value.request.shareId,
                    )
              : requestOwnerJid;
          var isOwner = false;
          if (ownerJid != null && ownerJid.trim().isNotEmpty) {
            isOwner = availabilityActorMatchesClaimedJid(ownerJid);
          } else if (chatEntity?.type == ChatType.chat &&
              availabilityActorId != null) {
            isOwner = !availabilityActorMatchesClaimedJid(
              value.request.requesterJid,
            );
          }
          if (isOwner) {
            availabilityOnAccept = () => _handleAvailabilityAccept(
              value.request,
              canAddToPersonalCalendar: personalCalendarAvailable,
              canAddToChatCalendar: chatCalendarAvailable,
            );
            availabilityOnDecline = () =>
                _handleAvailabilityDecline(value.request);
          }
        },
        response: (_) {},
      );
    }
    if (availabilityMessage != null) {
      addExtra(
        Builder(
          builder: (context) {
            final resolvedShare = availabilityShare;
            final resolvedOwnerLabel = _resolveAvailabilityOwnerLabel(
              ownerJid: resolvedShare?.overlay.owner,
              normalizedXmppSelfJid: normalizedXmppSelfJid,
              normalizedEmailSelfJid: normalizedEmailSelfJid,
              selfLabel: context.l10n.chatSenderYou,
            );
            final resolvedOnOpen = resolvedShare == null
                ? null
                : () => _openAvailabilityShareViewer(
                    share: resolvedShare,
                    requesterJid: availabilityShareRequesterJid,
                    chatCalendarAvailable: chatCalendarAvailable,
                    locate: context.read,
                    ownerLabel: resolvedOwnerLabel,
                    chatLabel: chatEntity?.displayName,
                  );
            return CalendarAvailabilityMessageCard(
              message: availabilityMessage,
              footerDetails: availabilityFooterDetails,
              onOpen: resolvedOnOpen,
              onAccept: availabilityOnAccept,
              onDecline: availabilityOnDecline,
            );
          },
        ),
        shape: calendarMessageCardShape,
        spacing: context.spacing.s,
      );
    } else if (calendarTaskIcs != null) {
      addExtra(
        !chatCalendarAvailable
            ? CalendarFragmentCard(
                fragment: CalendarFragment.task(task: calendarTaskIcs),
                footerDetails: taskFooterDetails,
              )
            : ChatCalendarTaskCard(
                task: calendarTaskIcs,
                readOnly: calendarTaskIcsReadOnly && !isSelfBubble,
                requireImportConfirmation: !isSelfBubble,
                allowChatCopy: true,
                canAddToPersonalCalendar: personalCalendarAvailable,
                onCopyToPersonalCalendar: personalCalendarAvailable
                    ? _copyTaskToPersonalCalendar
                    : null,
                demoQuickAdd: false,
                footerDetails: taskFooterDetails,
                isShareFragment: true,
              ),
        shape: calendarMessageCardShape,
        spacing: context.spacing.s,
      );
    } else if (displayFragment != null) {
      final fragmentCard = displayFragment.maybeMap(
        criticalPath: (value) => ChatCalendarCriticalPathCard(
          path: value.path,
          tasks: value.tasks,
          footerDetails: fragmentFooterDetails,
          canAddToPersonal: personalCalendarAvailable,
          canAddToChat: chatCalendarAvailable,
          onCopyToPersonalCalendar: personalCalendarAvailable
              ? _copyCriticalPathToPersonalCalendar
              : null,
        ),
        orElse: () => CalendarFragmentCard(
          fragment: displayFragment,
          footerDetails: fragmentFooterDetails,
        ),
      );
      addExtra(
        fragmentCard,
        shape: calendarMessageCardShape,
        spacing: context.spacing.s,
      );
    }
    return (
      hideFragmentText: hideFragmentText,
      hideAvailabilityText: hideAvailabilityText,
      hideTaskText: hideTaskText,
    );
  }

  void _appendRegularTimelineMessageBubbleContent({
    required BuildContext context,
    required ChatState state,
    required ChatTimelineMessageItem timelineMessageItem,
    required bool isSelfBubble,
    required bool isEmailMessage,
    required bool isSingleSelection,
    required bool isWelcomeChat,
    required String? availabilityActorId,
    required Map<String, String> availabilityShareOwnersById,
    required CalendarAvailabilityShareCoordinator? availabilityCoordinator,
    required String? normalizedXmppSelfJid,
    required String? normalizedEmailSelfJid,
    required bool personalCalendarAvailable,
    required bool chatCalendarAvailable,
    required Object bubbleContentKey,
    required Color bubbleColor,
    required Color textColor,
    required TextStyle baseTextStyle,
    required TextStyle linkStyle,
    required TextStyle surfaceDetailStyle,
    required TextStyle extraStyle,
    required List<InlineSpan> messageDetails,
    required List<InlineSpan> surfaceDetails,
    required Map<int, double> detailOpticalOffsetFactors,
    required _MessageBubbleExtraAdder addExtra,
    required List<String> attachmentIds,
    required List<Widget> bubbleTextChildren,
  }) {
    final messageModel = timelineMessageItem.messageModel;
    final displayFragment = timelineMessageItem.calendarFragment;
    final calendarTaskIcs = timelineMessageItem.calendarTaskIcs;
    final calendarTaskIcsReadOnly = timelineMessageItem.calendarTaskIcsReadOnly;
    final availabilityMessage = timelineMessageItem.availabilityMessage;
    final subjectText = timelineMessageItem.subjectLabel?.trim() ?? _emptyText;
    final showSubjectBanner =
        timelineMessageItem.showSubject && subjectText.isNotEmpty;
    if (showSubjectBanner) {
      _appendMessageSubjectBanner(
        context: context,
        subjectText: subjectText,
        textColor: textColor,
        bubbleTextChildren: bubbleTextChildren,
      );
    }
    final rawRenderedText = timelineMessageItem.renderedText;
    final groupedEmailBodyBlocks = timelineMessageItem.emailBodyBlocks;
    final messageText = isEmailMessage
        ? ChatSubjectCodec.previewBodyText(rawRenderedText)
        : rawRenderedText;
    final trimmedRenderedText = messageText.trim();
    final suppressGroupedEmailHtml =
        timelineMessageItem.emailRfcGroupKey != null &&
        !timelineMessageItem.isEmailRfcGroupLeader;
    final resolvedHtmlBody = isWelcomeChat || suppressGroupedEmailHtml
        ? null
        : timelineMessageItem.resolvedHtmlBody ??
              resolvedEmailHtmlBodyForMessage(
                message: messageModel,
                emailFullHtmlByDeltaId: state.emailFullHtmlByDeltaId,
              );
    final normalizedHtmlBody = HtmlContentCodec.normalizeHtml(resolvedHtmlBody);
    final emailDerivation = emailHtmlDerivationForBody(normalizedHtmlBody);
    final visibleSanitizedHtmlText = emailDerivation?.visibleBodyText;
    final normalizedHtmlText = visibleSanitizedHtmlText;
    final hasVisibleEmailHtmlContent =
        emailDerivation != null &&
        _emailHtmlHasVisibleTimelineContent(
          normalizedHtmlBody: normalizedHtmlBody,
          normalizedHtmlText: visibleSanitizedHtmlText,
          derivation: emailDerivation,
        );
    final displayMessageText = messageText;
    final trimmedDisplayMessageText = displayMessageText.trim();
    final textBubbleMessageText =
        isEmailMessage && trimmedDisplayMessageText.isEmpty
        ? (visibleSanitizedHtmlText?.isNotEmpty == true
              ? visibleSanitizedHtmlText!
              : displayMessageText)
        : displayMessageText;
    final trimmedTextBubbleMessageText = textBubbleMessageText.trim();
    final (
      :hideFragmentText,
      :hideAvailabilityText,
      :hideTaskText,
    ) = _appendCalendarBubbleExtras(
      context: context,
      chatEntity: state.chat,
      messageModel: messageModel,
      roomState: state.roomState,
      trimmedRenderedText: trimmedRenderedText,
      availabilityActorId: availabilityActorId,
      availabilityShareOwnersById: availabilityShareOwnersById,
      availabilityCoordinator: availabilityCoordinator,
      normalizedXmppSelfJid: normalizedXmppSelfJid,
      normalizedEmailSelfJid: normalizedEmailSelfJid,
      personalCalendarAvailable: personalCalendarAvailable,
      chatCalendarAvailable: chatCalendarAvailable,
      calendarTaskIcs: calendarTaskIcs,
      calendarTaskIcsReadOnly: calendarTaskIcsReadOnly,
      displayFragment: displayFragment,
      availabilityMessage: availabilityMessage,
      isSelfBubble: isSelfBubble,
      surfaceDetailStyle: surfaceDetailStyle,
      surfaceDetails: surfaceDetails,
      addExtra: addExtra,
    );
    final shouldRenderTextContent =
        !hideFragmentText && !hideAvailabilityText && !hideTaskText;
    final showsAttachmentOnlySurface =
        shouldRenderTextContent &&
        trimmedDisplayMessageText.isEmpty &&
        !hasVisibleEmailHtmlContent &&
        attachmentIds.isNotEmpty;
    final fullEmailPreviewText = displayMessageText.trim().isNotEmpty
        ? displayMessageText.trim()
        : (visibleSanitizedHtmlText?.trim() ?? _emptyText);
    final collapsedEmailPreviewText =
        ChatSubjectCodec.collapsedEmailPreviewText(fullEmailPreviewText);
    final shouldCollapseEmailPreview =
        _collapseLongEmailMessages &&
        isEmailMessage &&
        shouldRenderTextContent &&
        !showsAttachmentOnlySurface &&
        !isSingleSelection &&
        collapsedEmailPreviewText.isNotEmpty &&
        collapsedEmailPreviewText != fullEmailPreviewText;
    final shouldPreferRichEmailHtml =
        isEmailMessage &&
        emailDerivation != null &&
        HtmlContentCodec.shouldRenderRichEmailHtml(
          normalizedHtmlBody: normalizedHtmlBody,
          normalizedHtmlText: normalizedHtmlText,
          renderedText: displayMessageText,
        );
    final hasEmailHtmlBody = isEmailMessage && normalizedHtmlBody != null;
    final hasRichEmailHtmlBody =
        hasEmailHtmlBody &&
        hasVisibleEmailHtmlContent &&
        shouldPreferRichEmailHtml;
    final defaultShowsInlineEmailHtmlBody =
        shouldRenderTextContent &&
        !showsAttachmentOnlySurface &&
        hasRichEmailHtmlBody;
    final shouldRenderInlineEmailHtmlBody =
        hasEmailHtmlBody &&
        hasVisibleEmailHtmlContent &&
        shouldRenderTextContent &&
        !showsAttachmentOnlySurface &&
        (defaultShowsInlineEmailHtmlBody || isSingleSelection);
    final autoLoadEmailImages =
        state.chat?.emailRemoteImagesEnabled ??
        context.watch<SettingsCubit>().state.autoLoadEmailImages;
    if (groupedEmailBodyBlocks.isNotEmpty) {
      _appendGroupedEmailBodyBubbleContent(
        context: context,
        isSelfBubble: isSelfBubble,
        isSingleSelection: isSingleSelection,
        autoLoadEmailImages: autoLoadEmailImages,
        messageStanzaId: messageModel.stanzaID,
        bubbleContentKey: bubbleContentKey,
        baseTextStyle: baseTextStyle,
        linkStyle: linkStyle,
        bubbleColor: bubbleColor,
        textColor: textColor,
        messageDetails: messageDetails,
        detailOpticalOffsetFactors: detailOpticalOffsetFactors,
        bubbleTextChildren: bubbleTextChildren,
        emailBodyBlocks: groupedEmailBodyBlocks,
      );
    } else if (shouldCollapseEmailPreview) {
      _appendCollapsedEmailPreviewBubbleContent(
        context: context,
        collapsedEmailPreviewText: collapsedEmailPreviewText,
        bubbleContentKey: bubbleContentKey,
        baseTextStyle: baseTextStyle,
        messageDetails: messageDetails,
        detailOpticalOffsetFactors: detailOpticalOffsetFactors,
        bubbleTextChildren: bubbleTextChildren,
      );
    } else if (shouldRenderInlineEmailHtmlBody) {
      _appendInlineEmailHtmlBubbleContent(
        context: context,
        isSelfBubble: isSelfBubble,
        isSingleSelection: isSingleSelection,
        autoLoadEmailImages: autoLoadEmailImages,
        hasRemoteHtmlImages: emailDerivation.containsRemoteImages,
        rawHtmlBody: resolvedHtmlBody,
        normalizedHtmlBody: normalizedHtmlBody,
        normalizedHtmlText: visibleSanitizedHtmlText,
        emailDerivation: emailDerivation,
        preparedHtmlBody: emailDerivation.preparedFlutterHtml,
        messageStanzaId: messageModel.stanzaID,
        messageDatabaseId: messageModel.id,
        bubbleContentKey: bubbleContentKey,
        baseTextStyle: baseTextStyle,
        linkStyle: linkStyle,
        bubbleColor: bubbleColor,
        textColor: textColor,
        messageDetails: messageDetails,
        detailOpticalOffsetFactors: detailOpticalOffsetFactors,
        bubbleTextChildren: bubbleTextChildren,
      );
    } else if (shouldRenderTextContent && !showsAttachmentOnlySurface) {
      _appendTextBodyBubbleContent(
        context: context,
        bubbleContentKey: bubbleContentKey,
        displayMessageText: textBubbleMessageText,
        trimmedDisplayMessageText: trimmedTextBubbleMessageText,
        baseTextStyle: baseTextStyle,
        linkStyle: linkStyle,
        messageDetails: messageDetails,
        detailOpticalOffsetFactors: detailOpticalOffsetFactors,
        bubbleTextChildren: bubbleTextChildren,
      );
    }
    if (timelineMessageItem.retracted) {
      bubbleTextChildren.add(
        Text(context.l10n.chatMessageRetracted, style: extraStyle),
      );
    } else if (timelineMessageItem.edited) {
      bubbleTextChildren.add(
        Text(context.l10n.chatMessageEdited, style: extraStyle),
      );
    }
  }

  ({
    String detailId,
    TextStyle extraStyle,
    bool self,
    double bubbleMaxWidth,
    bool isError,
    Color bubbleColor,
    Color borderColor,
    Color textColor,
    TextStyle baseTextStyle,
    TextStyle linkStyle,
    bool isEmailMessage,
    String messageText,
    TextStyle surfaceDetailStyle,
    List<InlineSpan> messageDetails,
    Map<int, double> detailOpticalOffsetFactors,
    List<InlineSpan> surfaceDetails,
  })
  _resolveTimelineMessageViewData({
    required BuildContext context,
    required ChatTimelineMessageItem timelineMessageItem,
    required bool isPinned,
    required bool isImportant,
    required double inboundMessageRowMaxWidth,
    required double outboundMessageRowMaxWidth,
    required double messageFontSize,
  }) {
    final colors = context.colorScheme;
    final chatTokens = context.chatTheme;
    final messageStatus = switch (timelineMessageItem.delivery) {
      ChatTimelineMessageDelivery.none => MessageStatus.none,
      ChatTimelineMessageDelivery.pending => MessageStatus.pending,
      ChatTimelineMessageDelivery.sent => MessageStatus.sent,
      ChatTimelineMessageDelivery.received => MessageStatus.received,
      ChatTimelineMessageDelivery.read => MessageStatus.read,
      ChatTimelineMessageDelivery.failed => MessageStatus.failed,
    };
    final detailId = timelineMessageItem.id;
    final extraStyle = context.textTheme.muted.copyWith(
      fontStyle: FontStyle.italic,
    );
    final self = timelineMessageItem.isSelf;
    final bubbleMaxWidth = self
        ? outboundMessageRowMaxWidth
        : inboundMessageRowMaxWidth;
    final isError = timelineMessageItem.error.isNotNone;
    final bubbleColor = isError
        ? colors.destructive
        : self
        ? colors.primary
        : colors.card;
    final borderColor = self || isError
        ? Colors.transparent
        : chatTokens.recvEdge;
    final textColor = isError
        ? colors.destructiveForeground
        : self
        ? colors.primaryForeground
        : colors.foreground;
    final selectionFontDelta =
        !_multiSelectActive && _selectedMessageId == detailId
        ? context.sizing.progressIndicatorStrokeWidth
        : 0.0;
    final baseTextStyle = context.textTheme.small.copyWith(
      color: textColor,
      fontSize: messageFontSize + selectionFontDelta,
      height: 1.3,
    );
    final linkStyle = baseTextStyle.copyWith(
      color: self ? colors.primaryForeground : colors.primary,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    );
    final isEmailMessage = timelineMessageItem.isEmailMessage;
    final transportIconData = isEmailMessage
        ? LucideIcons.mail
        : LucideIcons.messageCircle;
    final messageText = isEmailMessage
        ? ChatSubjectCodec.previewBodyText(timelineMessageItem.renderedText)
        : timelineMessageItem.renderedText;
    final detailStyle = context.textTheme.muted.copyWith(
      color: textColor,
      height: 1.0,
      textBaseline: TextBaseline.alphabetic,
    );
    final surfaceDetailStyle = detailStyle.copyWith(color: colors.foreground);

    TextSpan iconDetailSpan(
      IconData icon,
      Color color, {
      required TextStyle baseStyle,
    }) => TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: baseStyle.copyWith(
        color: color,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
      ),
    );

    final timeLabel =
        '${timelineMessageItem.createdAt.hour.toString().padLeft(2, '0')}:'
        '${timelineMessageItem.createdAt.minute.toString().padLeft(2, '0')}';
    final time = TextSpan(text: timeLabel, style: detailStyle);
    final surfaceTime = TextSpan(text: timeLabel, style: surfaceDetailStyle);
    final statusIcon = messageStatus.icon;
    final status = iconDetailSpan(
      statusIcon,
      textColor,
      baseStyle: detailStyle,
    );
    final surfaceStatus = iconDetailSpan(
      statusIcon,
      colors.foreground,
      baseStyle: surfaceDetailStyle,
    );
    final transportDetail = iconDetailSpan(
      transportIconData,
      textColor,
      baseStyle: detailStyle,
    );
    final surfaceTransportDetail = iconDetailSpan(
      transportIconData,
      colors.foreground,
      baseStyle: surfaceDetailStyle,
    );
    final openPgpDetail =
        timelineMessageItem.messageModel.encryptionProtocol.isOpenPgp
        ? iconDetailSpan(LucideIcons.lock, textColor, baseStyle: detailStyle)
        : null;
    final surfaceOpenPgpDetail =
        timelineMessageItem.messageModel.encryptionProtocol.isOpenPgp
        ? iconDetailSpan(
            LucideIcons.lock,
            colors.foreground,
            baseStyle: surfaceDetailStyle,
          )
        : null;
    final trusted = timelineMessageItem.trusted;
    final verification = trusted == null
        ? null
        : iconDetailSpan(
            trusted.toShieldIcon,
            trusted ? axiGreen : colors.destructive,
            baseStyle: detailStyle,
          );
    final surfaceVerification = trusted == null
        ? null
        : iconDetailSpan(
            trusted.toShieldIcon,
            trusted ? axiGreen : colors.destructive,
            baseStyle: surfaceDetailStyle,
          );
    final pinnedDetail = isPinned
        ? iconDetailSpan(LucideIcons.pin, textColor, baseStyle: detailStyle)
        : null;
    final importantDetail = isImportant
        ? iconDetailSpan(Icons.star_rounded, textColor, baseStyle: detailStyle)
        : null;
    final surfacePinnedDetail = isPinned
        ? iconDetailSpan(
            LucideIcons.pin,
            colors.foreground,
            baseStyle: surfaceDetailStyle,
          )
        : null;
    final surfaceImportantDetail = isImportant
        ? iconDetailSpan(
            Icons.star_rounded,
            colors.foreground,
            baseStyle: surfaceDetailStyle,
          )
        : null;
    final messageDetails = <InlineSpan>[
      time,
      transportDetail,
      ?openPgpDetail,
      ?pinnedDetail,
      ?importantDetail,
      ?verification,
      if (self) status,
    ];
    final detailOpticalOffsetFactors = isEmailMessage
        ? const <int, double>{0: -0.08, 1: 0.08}
        : const <int, double>{0: -0.08};
    final surfaceDetails = <InlineSpan>[
      surfaceTime,
      surfaceTransportDetail,
      ?surfaceOpenPgpDetail,
      ?surfacePinnedDetail,
      ?surfaceImportantDetail,
      ?surfaceVerification,
      if (self) surfaceStatus,
    ];
    return (
      detailId: detailId,
      extraStyle: extraStyle,
      self: self,
      bubbleMaxWidth: bubbleMaxWidth,
      isError: isError,
      bubbleColor: bubbleColor,
      borderColor: borderColor,
      textColor: textColor,
      baseTextStyle: baseTextStyle,
      linkStyle: linkStyle,
      isEmailMessage: isEmailMessage,
      messageText: messageText,
      surfaceDetailStyle: surfaceDetailStyle,
      messageDetails: messageDetails,
      detailOpticalOffsetFactors: detailOpticalOffsetFactors,
      surfaceDetails: surfaceDetails,
    );
  }

  ({
    List<ReactionPreview> reactions,
    List<chat_models.Chat> replyParticipants,
    List<chat_models.Chat> recipientCutoutParticipants,
    List<String> attachmentIds,
    bool showReplyStrip,
    bool canReact,
    bool requiresMucReference,
    bool loadingMucReference,
    bool isSingleSelection,
    bool isMultiSelection,
    bool isSelected,
    bool showCompactReactions,
    bool isInviteMessage,
    bool isInviteRevocationMessage,
    bool inviteRevoked,
    bool showRecipientCutout,
  })
  _resolveTimelineMessageInteractionData({
    required ChatState state,
    required ChatTimelineMessageItem timelineMessageItem,
    required Message messageModel,
    required bool isEmailMessage,
    required bool isEmailChat,
    required bool isGroupChat,
    required String? selfXmppJid,
    required String? myOccupantJid,
  }) {
    final reactions = timelineMessageItem.reactions;
    final replyParticipants = timelineMessageItem.replyParticipants;
    final recipientCutoutParticipants = timelineMessageItem.shareParticipants;
    final attachmentIds = timelineMessageItem.attachmentIds;
    final showReplyStrip = isEmailMessage && replyParticipants.isNotEmpty;
    final chatDefaultTransport = isEmailChat
        ? MessageTransport.email
        : MessageTransport.xmpp;
    final messageUsesEmailBackedProtocol = messageModel.isEmailBacked;
    final canReact = messageModel.canSendXmppReaction(
      chatDefaultTransport: chatDefaultTransport,
    );
    final requiresMucReference = messageModel.awaitsMucReference(
      isGroupChat: isGroupChat,
      isEmailBacked: messageUsesEmailBackedProtocol,
    );
    final loadingMucReference = messageModel.waitsForOwnMucReference(
      isGroupChat: isGroupChat,
      isEmailBacked: messageUsesEmailBackedProtocol,
      selfJid: selfXmppJid,
      myOccupantJid: myOccupantJid,
    );
    final isSingleSelection =
        !_multiSelectActive && _selectedMessageId == messageModel.stanzaID;
    final isMultiSelection =
        _multiSelectActive &&
        _multiSelectedMessageIds.contains(messageModel.stanzaID);
    final isSelected = isSingleSelection || isMultiSelection;
    final showCompactReactions = !showReplyStrip && reactions.isNotEmpty;
    final isInviteMessage = timelineMessageItem.isInvite;
    final isInviteRevocationMessage = timelineMessageItem.isInviteRevocation;
    final inviteRevoked = timelineMessageItem.inviteRevoked;
    final showRecipientCutout =
        !showCompactReactions &&
        isEmailChat &&
        recipientCutoutParticipants.length > 1;
    return (
      reactions: reactions,
      replyParticipants: replyParticipants,
      recipientCutoutParticipants: recipientCutoutParticipants,
      attachmentIds: attachmentIds,
      showReplyStrip: showReplyStrip,
      canReact: canReact,
      requiresMucReference: requiresMucReference,
      loadingMucReference: loadingMucReference,
      isSingleSelection: isSingleSelection,
      isMultiSelection: isMultiSelection,
      isSelected: isSelected,
      showCompactReactions: showCompactReactions,
      isInviteMessage: isInviteMessage,
      isInviteRevocationMessage: isInviteRevocationMessage,
      inviteRevoked: inviteRevoked,
      showRecipientCutout: showRecipientCutout,
    );
  }

  ({
    Object bubbleContentKey,
    List<Widget> bubbleTextChildren,
    List<Widget> bubbleExtraChildren,
  })
  _composeTimelineMessageBubbleContent({
    required BuildContext context,
    required ChatState state,
    required Object detailId,
    required ChatTimelineMessageItem timelineMessageItem,
    required Message messageModel,
    required String messageText,
    required bool self,
    required bool isError,
    required bool isInviteMessage,
    required bool isInviteRevocationMessage,
    required bool inviteRevoked,
    required bool isEmailMessage,
    required bool isEmailChat,
    required bool isSingleSelection,
    required bool isWelcomeChat,
    required bool attachmentsBlockedForChat,
    required bool showCompactReactions,
    required bool showReplyStrip,
    required bool showRecipientCutout,
    required String? availabilityActorId,
    required Map<String, String> availabilityShareOwnersById,
    required CalendarAvailabilityShareCoordinator? availabilityCoordinator,
    required String? normalizedXmppSelfJid,
    required String? normalizedEmailSelfJid,
    required bool personalCalendarAvailable,
    required bool chatCalendarAvailable,
    required String? selfXmppJid,
    required Color bubbleColor,
    required Color textColor,
    required TextStyle baseTextStyle,
    required TextStyle linkStyle,
    required TextStyle surfaceDetailStyle,
    required TextStyle extraStyle,
    required List<InlineSpan> messageDetails,
    required List<InlineSpan> surfaceDetails,
    required Map<int, double> detailOpticalOffsetFactors,
    required List<String> attachmentIds,
    required bool chainsFromPreviousMessage,
    required bool chainsIntoNextMessage,
  }) {
    final bubbleContentKey = detailId;
    final bubbleTextChildren = <Widget>[];
    final bubbleExtraChildren = <Widget>[];
    var extraItemCount = 0;
    var extraGapCount = 0;
    final extraSpacing = context.spacing.xs;

    void addExtra(
      Widget child, {
      required ShapeBorder shape,
      double? spacing,
      Key? key,
    }) {
      final extraGap = spacing ?? extraSpacing;
      final extraKey =
          key ?? ValueKey('$bubbleContentKey-extra-item-$extraItemCount');
      extraItemCount += 1;
      final extraChild = _MessageExtraItem(
        key: extraKey,
        shape: shape,
        onLongPress: null,
        onSecondaryTapUp: null,
        child: child,
      );
      if (bubbleExtraChildren.isNotEmpty) {
        final gapKey = ValueKey('$bubbleContentKey-extra-gap-$extraGapCount');
        extraGapCount += 1;
        bubbleExtraChildren
          ..add(_MessageExtraGap(key: gapKey, height: extraGap))
          ..add(extraChild);
        return;
      }
      if (bubbleTextChildren.isNotEmpty && extraGap > 0) {
        final gapKey = ValueKey('$bubbleContentKey-extra-gap-$extraGapCount');
        extraGapCount += 1;
        bubbleExtraChildren.add(
          _MessageExtraGap(key: gapKey, height: extraGap),
        );
      }
      bubbleExtraChildren.add(extraChild);
    }

    if (isError) {
      _appendErrorBubbleContent(
        context: context,
        bubbleContentKey: bubbleContentKey,
        messageText: messageText,
        textColor: textColor,
        baseTextStyle: baseTextStyle,
        linkStyle: linkStyle,
        messageDetails: messageDetails,
        detailOpticalOffsetFactors: detailOpticalOffsetFactors,
        bubbleTextChildren: bubbleTextChildren,
      );
    } else if (isInviteMessage || isInviteRevocationMessage) {
      _appendInviteBubbleContent(
        context: context,
        timelineMessageItem: timelineMessageItem,
        isSelfBubble: self,
        messageModel: messageModel,
        selfXmppJid: selfXmppJid,
        bubbleContentKey: bubbleContentKey,
        baseTextStyle: baseTextStyle,
        messageDetails: messageDetails,
        detailOpticalOffsetFactors: detailOpticalOffsetFactors,
        bubbleTextChildren: bubbleTextChildren,
        addExtra: addExtra,
      );
    } else {
      _appendRegularTimelineMessageBubbleContent(
        context: context,
        state: state,
        timelineMessageItem: timelineMessageItem,
        isSelfBubble: self,
        isEmailMessage: isEmailMessage,
        isSingleSelection: isSingleSelection,
        isWelcomeChat: isWelcomeChat,
        availabilityActorId: availabilityActorId,
        availabilityShareOwnersById: availabilityShareOwnersById,
        availabilityCoordinator: availabilityCoordinator,
        normalizedXmppSelfJid: normalizedXmppSelfJid,
        normalizedEmailSelfJid: normalizedEmailSelfJid,
        personalCalendarAvailable: personalCalendarAvailable,
        chatCalendarAvailable: chatCalendarAvailable,
        bubbleContentKey: bubbleContentKey,
        bubbleColor: bubbleColor,
        textColor: textColor,
        baseTextStyle: baseTextStyle,
        linkStyle: linkStyle,
        surfaceDetailStyle: surfaceDetailStyle,
        extraStyle: extraStyle,
        messageDetails: messageDetails,
        surfaceDetails: surfaceDetails,
        detailOpticalOffsetFactors: detailOpticalOffsetFactors,
        addExtra: addExtra,
        attachmentIds: attachmentIds,
        bubbleTextChildren: bubbleTextChildren,
      );
    }

    final hasBubbleText = bubbleTextChildren.isNotEmpty;
    if (attachmentIds.isNotEmpty) {
      final hasBubbleAnchor =
          hasBubbleText ||
          showCompactReactions ||
          showReplyStrip ||
          showRecipientCutout;
      _appendAttachmentBubbleExtras(
        context: context,
        attachmentIds: attachmentIds,
        hasBubbleAnchor: hasBubbleAnchor,
        chainsFromPreviousMessage: chainsFromPreviousMessage,
        chainsIntoNextMessage: chainsIntoNextMessage,
        isSelfBubble: self,
        isEmailChat: isEmailChat,
        attachmentsBlockedForChat: attachmentsBlockedForChat,
        messageModel: messageModel,
        state: state,
        bubbleContentKey: bubbleContentKey,
        surfaceDetails: surfaceDetails,
        detailOpticalOffsetFactors: detailOpticalOffsetFactors,
        addExtra: addExtra,
      );
    }

    return (
      bubbleContentKey: bubbleContentKey,
      bubbleTextChildren: bubbleTextChildren,
      bubbleExtraChildren: bubbleExtraChildren,
    );
  }

  String? _resolvedDirectChatDisplayName({
    required chat_models.Chat? chat,
    required ChatsState? chatsState,
  }) {
    final currentDisplayName = chat?.displayName.trim();
    if (currentDisplayName != null && currentDisplayName.isNotEmpty) {
      return currentDisplayName;
    }
    final targetJid = chat?.jid ?? chatsState?.openJid;
    final normalizedTargetJid = normalizedAddressValue(targetJid);
    if (normalizedTargetJid == null || normalizedTargetJid.isEmpty) {
      return null;
    }
    for (final item in chatsState?.items ?? const <chat_models.Chat>[]) {
      final normalizedItemJid = normalizedAddressValue(item.jid);
      final normalizedRemoteJid = normalizedAddressValue(item.remoteJid);
      final matchesCurrentChat =
          normalizedItemJid == normalizedTargetJid ||
          normalizedRemoteJid == normalizedTargetJid;
      if (!matchesCurrentChat) {
        continue;
      }
      final displayName = item.displayName.trim();
      if (displayName.isNotEmpty) {
        return displayName;
      }
    }
    return null;
  }

  void _toggleSettingsPanel() {
    if (!mounted) return;
    if (_chatRoute.isSettings) {
      _setChatRoute(ChatRouteIndex.main);
      return;
    }
    _setChatRoute(ChatRouteIndex.settings);
  }

  void _handleReplyRequested(Message message) {
    final locate = context.read;
    final requestId = ++_replyResolveRequestId;
    unawaited(
      _resolveReplyRequested(
        bloc: locate<ChatBloc>(),
        message: message,
        requestId: requestId,
      ),
    );
  }

  Future<void> _resolveReplyRequested({
    required ChatBloc bloc,
    required Message message,
    required int requestId,
  }) async {
    final quotedMessage = await bloc.resolveReplyTargetForMessageAsync(message);
    if (!mounted || requestId != _replyResolveRequestId) {
      return;
    }
    setState(() {
      _quotedDraft = quotedMessage;
      _clearInlineRetryTransportOverride();
    });
    _inlineComposerController.requestTextFocus();
  }

  void _clearQuotedDraftAndInvalidateReplyResolution() {
    _replyResolveRequestId += 1;
    _quotedDraft = null;
    _clearInlineRetryTransportOverride();
  }

  void _handleTimelineBubbleTap(Message message) {
    _logTappedMessageHtml(message);
    unawaited(_toggleMessageSelection(message));
  }

  ChatTimelineMessageItem? _timelineItemForMessage(Message message) {
    for (final item in _cachedTimelineItems) {
      if (item is ChatTimelineMessageItem &&
          item.messageModel.stanzaID == message.stanzaID) {
        return item;
      }
    }
    return null;
  }

  void _logTappedMessageHtml(Message message) {
    if (!kDebugMode && !emailHtmlLoggingEnabled) {
      return;
    }
    final locate = context.read;
    final chatState = locate<ChatBloc>().state;
    final timelineItem = _timelineItemForMessage(message);
    final stages = <String, String?>{};
    final baseFontSize =
        context.textTheme.small.fontSize ?? context.sizing.menuItemIconSize;
    final themeStyle = buildEmailWebViewThemeStyle(
      brightness: context.brightness,
      backgroundColor: context.colorScheme.card,
      baseFontSize: baseFontSize,
    );

    void addStages({
      required String prefix,
      required String? html,
      required bool shouldLoadImages,
    }) {
      final normalizedHtml = HtmlContentCodec.normalizeHtml(html);
      if (normalizedHtml == null) {
        return;
      }
      final emailDerivation = emailHtmlDerivationForBody(normalizedHtml);
      stages['$prefix.raw'] = html;
      stages['$prefix.normalized'] = normalizedHtml;
      stages['$prefix.prepared-flutter-html'] =
          emailDerivation?.preparedFlutterHtml;
      try {
        stages['$prefix.webview-prepared-shell'] = buildEmailHtmlDataForWebView(
          html: normalizedHtml,
          allowRemoteImages: shouldLoadImages,
          themeStyle: themeStyle,
          contentMode: EmailHtmlContentMode.safe,
        );
      } on Exception catch (error) {
        stages['$prefix.webview-prepared-shell'] =
            '<webview-prep-failed type=${error.runtimeType}>';
      }
    }

    final resolvedHtmlBody =
        timelineItem?.resolvedHtmlBody ??
        resolvedEmailHtmlBodyForMessage(
          message: message,
          emailFullHtmlByDeltaId: chatState.emailFullHtmlByDeltaId,
        );
    final messageDatabaseId = message.id;
    addStages(
      prefix: 'message',
      html: resolvedHtmlBody,
      shouldLoadImages:
          messageDatabaseId != null &&
          _loadedEmailImageMessageIds.contains(messageDatabaseId),
    );
    for (final block in timelineItem?.emailBodyBlocks ?? const []) {
      final sourceMessageDatabaseId = block.sourceMessageDatabaseId;
      addStages(
        prefix: 'email-block-${block.sourceStanzaId}',
        html: block.resolvedHtmlBody,
        shouldLoadImages:
            sourceMessageDatabaseId != null &&
            _loadedEmailImageMessageIds.contains(sourceMessageDatabaseId),
      );
    }
    if (stages.isEmpty) {
      return;
    }
    logEmailHtmlStages(
      contentKey: (
        source: 'bubble-tap',
        stanzaId: message.stanzaID,
        messageId: message.id,
        deltaMsgId: message.deltaMsgId,
      ),
      stages: stages,
      dedupe: false,
      force: true,
    );
  }

  void _handleMessageResendRequested(
    Message message, {
    required chat_models.Chat? chat,
  }) {
    if (chat == null) {
      return;
    }
    context.read<ChatBloc>().add(
      ChatMessageResendRequested(message: message, chatType: chat.type),
    );
  }

  Future<void> _handleAddToFolderRequested(
    Message message, {
    required chat_models.Chat? chat,
  }) async {
    if (chat == null) {
      return;
    }
    await showAddToFolderSheet(context, message: message, chat: chat);
  }

  void _handlePinToggleRequested(
    Message message, {
    required bool pin,
    required chat_models.Chat? chat,
    required RoomState? roomState,
  }) {
    if (chat == null) {
      return;
    }
    context.read<ChatBloc>().add(
      ChatMessagePinRequested(
        message: message,
        pin: pin,
        chat: chat,
        roomState: roomState,
      ),
    );
  }

  void _handleInviteRevocationRequested(
    Message message, {
    String? inviteeJidFallback,
  }) {
    context.read<ChatBloc>().add(
      ChatInviteRevocationRequested(
        message: message,
        inviteeJidFallback: inviteeJidFallback,
      ),
    );
  }

  void _openChatFromParticipant(chat_models.Chat chat) {
    context.read<ChatsCubit>().pushChat(jid: chat.jid);
  }

  void _setViewFilter(MessageTimelineFilter filter) {
    final chat = context.read<ChatBloc>().state.chat;
    if (chat == null) {
      return;
    }
    context.read<ChatBloc>().add(
      ChatViewFilterChanged(filter: filter, chatJid: chat.jid),
    );
  }

  void _setNotificationBehavior(ChatNotificationBehavior? behavior) {
    final chat = context.read<ChatBloc>().state.chat;
    if (chat == null) {
      return;
    }
    context.read<ChatBloc>().add(
      ChatNotificationBehaviorChanged(chat: chat, behavior: behavior),
    );
  }

  Future<void> _showMembers({bool refreshMembership = true}) async {
    final locate = context.read;
    if (refreshMembership) {
      locate<ChatBloc>().add(const ChatRoomMembersOpened());
    }
    final navigator = Navigator.of(context);
    final sizing = context.sizing;
    final Duration animationDuration =
        locate<SettingsCubit>().animationDuration;
    final colors = context.colorScheme;
    final motion = context.motion;
    final chatBloc = locate<ChatBloc>();
    final scrimBase = context.brightness == Brightness.dark
        ? colors.background
        : colors.foreground;
    final shadThemeData = ShadTheme.of(context);
    final scrimColor = scrimBase.withValues(
      alpha: motion.tapFocusAlpha + motion.tapHoverAlpha,
    );
    showGeneralDialog(
      context: context,
      useRootNavigator: false,
      barrierDismissible: true,
      barrierLabel: context.l10n.chatRoomMembers,
      barrierColor: scrimColor,
      transitionDuration: animationDuration,
      pageBuilder: (context, animation, secondaryAnimation) {
        return ShadTheme(
          data: shadThemeData,
          child: SafeArea(
            child: Align(
              alignment: Alignment.centerRight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final drawerWidth = math.min(
                    constraints.maxWidth,
                    sizing.dialogMaxWidth,
                  );
                  return SizedBox(
                    width: drawerWidth,
                    height: constraints.maxHeight,
                    child: BlocProvider.value(
                      value: chatBloc,
                      child: Builder(
                        builder: (context) => _RoomMembersDrawerContent(
                          onInvite: (jid) {
                            final locate = context.read;
                            final chatState = locate<ChatBloc>().state;
                            final chat = chatState.chat;
                            if (chat == null) {
                              return;
                            }
                            locate<ChatBloc>().add(
                              ChatInviteRequested(
                                jid,
                                chat: chat,
                                roomState: chatState.roomState,
                              ),
                            );
                          },
                          onAction: (occupantId, action, actionLabel) {
                            final locate = context.read;
                            final chatState = locate<ChatBloc>().state;
                            final chat = chatState.chat;
                            if (chat == null) {
                              return Future<void>.value();
                            }
                            final completer = Completer<void>();
                            locate<ChatBloc>().add(
                              ChatModerationActionRequested(
                                occupantId: occupantId,
                                action: action,
                                actionLabel: actionLabel,
                                chat: chat,
                                roomState: chatState.roomState,
                                completer: completer,
                              ),
                            );
                            return completer.future;
                          },
                          onOpenDirectChat: (jid) async {
                            final locate = context.read;
                            final chatsCubit = locate<ChatsCubit>();
                            final normalizedJid = jid.trim();
                            var opened = false;
                            try {
                              await chatsCubit.openChat(jid: jid);
                              opened = true;
                            } on XmppException {
                              opened =
                                  chatsCubit.state.openJid?.trim() ==
                                  normalizedJid;
                            }
                            if (!opened) {
                              return false;
                            }
                            if (!context.mounted) {
                              return true;
                            }
                            navigator.pop();
                            return true;
                          },
                          onChangeNickname: (nick) {
                            final locate = context.read;
                            final chatState = locate<ChatBloc>().state;
                            final chat = chatState.chat;
                            if (chat == null) {
                              return;
                            }
                            locate<ChatBloc>().add(
                              ChatNicknameChangeRequested(
                                nickname: nick,
                                chatJid: chat.jid,
                                chatType: chat.type,
                              ),
                            );
                          },
                          onLeaveRoom: () async {
                            final locate = context.read;
                            final chatsCubit = locate<ChatsCubit>();
                            final chatState = locate<ChatBloc>().state;
                            final chat = chatState.chat;
                            if (chat == null) {
                              return;
                            }
                            final completer = Completer<void>();
                            locate<ChatBloc>().add(
                              ChatLeaveRoomRequested(
                                chatJid: chat.jid,
                                chatType: chat.type,
                                completer: completer,
                              ),
                            );
                            await completer.future;
                            if (!context.mounted) {
                              return;
                            }
                            navigator.pop();
                            await chatsCubit.popChat();
                          },
                          onDestroyRoom: () async {
                            final locate = context.read;
                            final chatsCubit = locate<ChatsCubit>();
                            final chatState = locate<ChatBloc>().state;
                            final chat = chatState.chat;
                            if (chat == null) {
                              return;
                            }
                            final completer = Completer<void>();
                            locate<ChatBloc>().add(
                              ChatDestroyRoomRequested(
                                chatJid: chat.jid,
                                chatType: chat.type,
                                completer: completer,
                              ),
                            );
                            await completer.future;
                            if (!context.mounted) {
                              return;
                            }
                            navigator.pop();
                            await chatsCubit.popChat();
                          },
                          onClose: navigator.pop,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        if (animationDuration == Duration.zero) {
          return child;
        }
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  Future<void> _promptContactRename() async {
    final chat = context.read<ChatBloc>().state.chat;
    if (chat == null || chat.type != ChatType.chat) {
      return;
    }
    final l10n = context.l10n;
    final result = await showContactRenameDialog(
      context: context,
      initialValue: chat.displayName,
    );
    if (!mounted || result == null) return;
    context.read<ChatBloc>().add(
      ChatContactRenameRequested(
        result,
        chat: chat,
        successMessage: l10n.chatContactRenameSuccess,
        failureMessage: l10n.chatContactRenameFailure,
      ),
    );
  }

  Future<void> _handleSpamToggle({required bool sendToSpam}) async {
    final chat = context.read<ChatBloc>().state.chat;
    if (chat == null) {
      return;
    }
    final l10n = context.l10n;
    final chatTitle = chat.displayName;
    context.read<ChatBloc>().add(
      ChatSpamStatusRequested(
        chat: chat,
        sendToSpam: sendToSpam,
        successTitle: sendToSpam
            ? l10n.chatSpamReportedTitle
            : l10n.chatSpamRestoredTitle,
        successMessage: sendToSpam
            ? l10n.chatSpamSent(chatTitle)
            : l10n.chatSpamRestored(chatTitle),
        failureMessage: l10n.chatSpamUpdateFailed,
      ),
    );
  }

  Future<bool> _handleAddContact() async {
    final chat = context.read<ChatBloc>().state.chat;
    if (chat == null) return false;
    if (chat.remoteJid.trim().isEmpty) {
      return false;
    }
    final l10n = context.l10n;
    final acceptedCompleter = Completer<bool>();
    context.read<ChatBloc>().add(
      ChatContactAddRequested(
        chat: chat,
        failureMessage: l10n.attachmentGalleryRosterErrorTitle,
        acceptedCompleter: acceptedCompleter,
      ),
    );
    return acceptedCompleter.future;
  }

  void _handleSubjectChanged(String text) {
    if (_subjectChangeSuppressed) {
      return;
    }
    if (_lastSubjectValue == text) {
      return;
    }
    _lastSubjectValue = text;
    if (mounted) {
      setState(_clearInlineRetryTransportOverride);
    }
    context.read<ChatBloc>().add(ChatSubjectChanged(text));
  }

  void _hydrateAnimatedMessages(List<Message> messages) {
    _animatedMessageIds
      ..clear()
      ..addAll(
        messages
            .map((message) => (message.id ?? message.stanzaID).trim())
            .where((id) => id.isNotEmpty),
      );
    _hydratedAnimatedMessages = true;
  }

  bool _shouldAnimateMessage(Message message) {
    if (!_hydratedAnimatedMessages) {
      return false;
    }
    final messageId = (message.id ?? message.stanzaID).trim();
    if (messageId.isEmpty) {
      return false;
    }
    if (_animatedMessageIds.contains(messageId)) {
      return false;
    }
    _animatedMessageIds.add(messageId);
    return true;
  }

  void _ensureRecipientBarHeightCleared() {
    // No-op now that recipient bar height is derived from layout constraints.
  }

  FileMetadataData? _metadataFor({
    required ChatState state,
    required String metadataId,
  }) {
    return state.fileMetadataById[metadataId];
  }

  bool _metadataPending({
    required ChatState state,
    required String metadataId,
  }) {
    return !state.fileMetadataById.containsKey(metadataId);
  }

  bool _hasEmailAttachmentTarget({
    required ChatState chatState,
    required chat_models.Chat chat,
    required List<ComposerRecipient> recipients,
  }) {
    if (chatState.canOfferEmailOutboundOverride) {
      return true;
    }
    if (chat.defaultTransport.isEmail) {
      return true;
    }
    return recipients.hasEmailComposeHint;
  }

  bool _hasEmailRecipient(List<ComposerRecipient> recipients) =>
      recipients.hasEmailComposeHint;

  bool _isEmailComposerActive({
    required ChatState chatState,
    List<ComposerRecipient>? recipients,
    MessageTransport? oneShotTransportOverride,
  }) {
    final chat = chatState.chat;
    if (chat != null) {
      final activeTransport = chatState.canOfferEmailOutboundOverride
          ? chatState.activeTransportForSend(
              chat,
              oneShotOverride: oneShotTransportOverride,
            )
          : chat.defaultTransport;
      if (activeTransport.isEmail) {
        return true;
      }
    }
    return _hasEmailRecipient(recipients ?? _recipients);
  }

  int _emailRecipientCountForSend({
    required ChatState chatState,
    required chat_models.Chat chat,
    required List<ComposerRecipient> recipients,
    MessageTransport? oneShotTransportOverride,
  }) {
    final activeTransport = chatState.canOfferEmailOutboundOverride
        ? chatState.activeTransportForSend(
            chat,
            oneShotOverride: oneShotTransportOverride,
          )
        : chat.defaultTransport;
    if (activeTransport.isEmail) {
      return recipients.length;
    }
    return recipients.emailComposeHintCount;
  }

  String _emailComposerWatermarkLabel() {
    return context.l10n.chatComposerEmailWatermark;
  }

  String _emailComposerWatermarkSuffix() {
    return '\n${_emailComposerWatermarkLabel()}';
  }

  String _legacyEmailComposerWatermarkSuffix() {
    return '\n\n${_emailComposerWatermarkLabel()}';
  }

  bool _isDemoModeActive() {
    if (!kEnableDemoChats) {
      return false;
    }
    return context.read<XmppService>().demoOfflineMode;
  }

  bool _isEmailComposerWatermarkOnly({
    required String text,
    required ChatState chatState,
    SettingsState? settings,
  }) {
    final settingsState = settings ?? context.read<SettingsCubit>().state;
    final isEmailComposer = chatState.chat?.defaultTransport.isEmail ?? false;
    final watermarkEnabled =
        chatState.chat?.emailComposerWatermarkEnabled ??
        settingsState.emailComposerWatermarkEnabled;
    if (!isEmailComposer || !watermarkEnabled) {
      return false;
    }
    final watermarkLabel = _emailComposerWatermarkLabel();
    final watermarkSuffix = _emailComposerWatermarkSuffix();
    final legacyWatermarkSuffix = _legacyEmailComposerWatermarkSuffix();
    return text == watermarkLabel ||
        text == watermarkSuffix ||
        text == legacyWatermarkSuffix;
  }

  String _normalizedInlineDraftBody({
    required String text,
    required ChatState chatState,
  }) {
    if (_isEmailComposerWatermarkOnly(text: text, chatState: chatState)) {
      return _emptyText;
    }
    return text;
  }

  void _syncEmailComposerWatermark({
    required ChatState chatState,
    SettingsState? settings,
    bool forceInsert = false,
  }) {
    final settingsState = settings ?? context.read<SettingsCubit>().state;
    final currentText = _inlineComposerController.text;
    final watermarkLabel = _emailComposerWatermarkLabel();
    final watermarkSuffix = _emailComposerWatermarkSuffix();
    final legacyWatermarkSuffix = _legacyEmailComposerWatermarkSuffix();
    final isEmailComposer = chatState.chat?.defaultTransport.isEmail ?? false;
    final watermarkEnabled =
        chatState.chat?.emailComposerWatermarkEnabled ??
        settingsState.emailComposerWatermarkEnabled;
    if (_isDemoModeActive()) {
      return;
    }
    if (!isEmailComposer || !watermarkEnabled) {
      if (currentText == watermarkLabel ||
          currentText == watermarkSuffix ||
          currentText == legacyWatermarkSuffix) {
        _inlineComposerController.setTextValue(
          const TextEditingValue(
            text: _emptyText,
            selection: TextSelection.collapsed(offset: 0),
            composing: TextRange.empty,
          ),
        );
      }
      return;
    }
    if (currentText == legacyWatermarkSuffix) {
      _inlineComposerController.setTextValue(
        TextEditingValue(
          text: watermarkSuffix,
          selection: const TextSelection.collapsed(offset: 0),
          composing: TextRange.empty,
        ),
      );
      return;
    }
    if (currentText == watermarkSuffix) {
      return;
    }
    if (currentText == watermarkLabel) {
      _inlineComposerController.setTextValue(
        TextEditingValue(
          text: watermarkSuffix,
          selection: const TextSelection.collapsed(offset: 0),
          composing: TextRange.empty,
        ),
      );
      return;
    }
    if (currentText.trim().isNotEmpty) {
      if (currentText.endsWith(watermarkSuffix)) {
        return;
      }
      if (currentText.endsWith(legacyWatermarkSuffix)) {
        final normalizedText = currentText.substring(
          0,
          currentText.length - legacyWatermarkSuffix.length,
        );
        final normalizedWithWatermark = '$normalizedText$watermarkSuffix';
        final selection = _inlineComposerController.textSelection;
        final normalizedOffset = selection.isValid
            ? math.min(selection.extentOffset, normalizedWithWatermark.length)
            : normalizedWithWatermark.length;
        _inlineComposerController.setTextValue(
          TextEditingValue(
            text: normalizedWithWatermark,
            selection: TextSelection.collapsed(offset: normalizedOffset),
            composing: TextRange.empty,
          ),
        );
        return;
      }
      final selection = _inlineComposerController.textSelection;
      final watermarkOffset = forceInsert
          ? currentText.length
          : (selection.isValid
                ? selection.extentOffset.clamp(0, currentText.length).toInt()
                : currentText.length);
      _inlineComposerController.setTextValue(
        TextEditingValue(
          text: '$currentText$watermarkSuffix',
          selection: TextSelection.collapsed(offset: watermarkOffset),
          composing: TextRange.empty,
        ),
      );
      return;
    }
    _inlineComposerController.setTextValue(
      TextEditingValue(
        text: watermarkSuffix,
        selection: TextSelection.collapsed(offset: 0),
        composing: TextRange.empty,
      ),
    );
  }

  bool _resolveComposerSendOnEnter({
    required List<ComposerRecipient> recipients,
    required SettingsState settings,
  }) {
    final hasEmail = recipients.hasEmailRecipients;
    final hasXmpp = recipients.hasXmppRecipients;
    if (hasEmail && hasXmpp) {
      return settings.chatSendOnEnter && settings.emailSendOnEnter;
    }
    if (hasEmail) {
      return settings.emailSendOnEnter;
    }
    return settings.chatSendOnEnter;
  }

  List<BlocklistEntry> _resolveBlocklistEntries(BuildContext context) {
    final List<BlocklistEntry>? cachedEntries = context
        .select<BlocklistCubit, List<BlocklistEntry>?>(
          (cubit) =>
              cubit[BlocklistCubit.blocklistItemsCacheKey]
                  as List<BlocklistEntry>?,
        );
    final BlocklistState blocklistState = context.watch<BlocklistCubit>().state;
    final List<BlocklistEntry>? resolvedEntries = switch (blocklistState) {
      BlocklistAvailable state => state.items ?? cachedEntries,
      _ => cachedEntries,
    };
    return resolvedEntries ?? _emptyBlocklistEntries;
  }

  BlocklistEntry? _resolveChatBlocklistEntry({
    required chat_models.Chat chat,
    required List<BlocklistEntry> entries,
  }) {
    if (chat.type != ChatType.chat) {
      return null;
    }
    if (entries.isEmpty) {
      return null;
    }
    if (chat.defaultTransport.isEmail) {
      final String? normalizedCandidate = normalizedAddressValue(
        chat.antiAbuseTargetAddress,
      );
      if (normalizedCandidate == null || normalizedCandidate.isEmpty) {
        return null;
      }
      for (final entry in entries) {
        if (!entry.transport.isEmail) {
          continue;
        }
        if (normalizedAddressValue(entry.address) == normalizedCandidate) {
          return entry;
        }
      }
      return null;
    }
    final String? chatBareJid = normalizedAddressKey(chat.remoteJid);
    if (chatBareJid == null || chatBareJid.isEmpty) {
      return null;
    }
    for (final entry in entries) {
      if (!entry.transport.isXmpp) {
        continue;
      }
      final String? entryBareJid = normalizedAddressKey(entry.address);
      if (entryBareJid != null && entryBareJid == chatBareJid) {
        return entry;
      }
    }
    return null;
  }

  String? _resolveChatBlockAddress({required chat_models.Chat chat}) {
    if (chat.defaultTransport.isEmail) {
      final candidate = chat.antiAbuseTargetAddress.trim();
      if (candidate.isEmpty) {
        return null;
      }
      return candidate;
    }
    final String jid = chat.jid.trim();
    return jid.isEmpty ? null : jid;
  }

  bool _shouldAllowAttachment({
    required bool isSelf,
    required chat_models.Chat? chat,
    required SettingsState settings,
    required FileMetadataData? metadata,
    required bool chatBlocked,
  }) {
    if (isSelf) return true;
    if (chat == null || metadata == null) return false;
    return allowsAttachmentAutoDownload(
      chat: chat,
      metadata: metadata,
      imagesEnabled: settings.autoDownloadImages,
      videosEnabled: settings.autoDownloadVideos,
      documentsEnabled: settings.autoDownloadDocuments,
      archivesEnabled: settings.autoDownloadArchives,
      chatBlocked: chatBlocked,
      requireKnownSize: false,
      maxBytes: maxAttachmentAutoDownloadBytes,
    );
  }

  bool _isOneTimeAttachmentAllowed(String stanzaId) {
    final trimmed = stanzaId.trim();
    if (trimmed.isEmpty) return false;
    return _oneTimeAllowedAttachmentStanzaIds.contains(trimmed);
  }

  Future<bool> _confirmManualAttachmentDownload({
    required String senderJid,
    required bool isSelf,
    String? senderEmail,
  }) async {
    if (!mounted) return false;
    final l10n = context.l10n;
    final displaySender = senderEmail?.isNotEmpty == true
        ? senderEmail!
        : senderJid;
    final chat = context.read<ChatBloc>().state.chat;
    final canTrustChat = !isSelf && chat != null;
    final showAutoTrustToggle = canTrustChat;
    final autoTrustLabel = l10n.attachmentGalleryChatTrustLabel;
    final autoTrustHint = l10n.attachmentGalleryChatTrustHint;
    final inheritedAutoDownloadEnabled = context
        .read<SettingsCubit>()
        .state
        .anyAttachmentAutoDownloadEnabled;
    final decision = await showFadeScaleDialog<AttachmentApprovalDecision>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AttachmentApprovalDialog(
          title: l10n.chatAttachmentConfirmTitle,
          message: l10n.chatAttachmentConfirmMessage(displaySender),
          confirmLabel: l10n.chatAttachmentConfirmButton,
          cancelLabel: l10n.commonCancel,
          showAutoTrustToggle: showAutoTrustToggle,
          autoDownloadValue: chat?.attachmentAutoDownload,
          inheritedAutoDownloadEnabled: inheritedAutoDownloadEnabled,
          autoTrustLabel: autoTrustLabel,
          autoTrustHint: autoTrustHint,
        );
      },
    );
    if (!mounted) return false;
    if (decision == null || !decision.approved) return false;

    if (decision.updateAutoDownloadValue && canTrustChat) {
      final chat = context.read<ChatBloc>().state.chat;
      if (chat != null) {
        context.read<ChatBloc>().add(
          ChatAttachmentAutoDownloadToggled(
            chat: chat,
            value: decision.autoDownloadValue,
          ),
        );
      }
    }
    return true;
  }

  Future<void> _approveAttachment({
    required Message message,
    required String senderJid,
    required String stanzaId,
    required bool isSelf,
    required bool isEmailChat,
    String? senderEmail,
  }) async {
    final approved = await _confirmManualAttachmentDownload(
      senderJid: senderJid,
      isSelf: isSelf,
      senderEmail: senderEmail,
    );
    if (!approved || !mounted) return;

    if (mounted) {
      setState(() {
        _oneTimeAllowedAttachmentStanzaIds.add(stanzaId.trim());
      });
      context.read<ChatBloc>().add(
        ChatAttachmentAutoDownloadRequested(stanzaId.trim()),
      );
    }
  }

  Future<void> _handleLinkTap(String url) async {
    if (!mounted) return;
    final l10n = context.l10n;
    final report = assessLinkSafety(raw: url, kind: LinkSafetyKind.message);
    if (report == null || !report.isSafe) {
      _showSnackbar(l10n.chatInvalidLink(url.trim()));
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
      _showSnackbar(l10n.chatUnableToOpenHost(report.displayHost));
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    final messenger =
        _scaffoldMessengerKey.currentState ??
        ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _awaitInlineAttachmentPreparationIfNeeded() async {
    final operation = _inlineAttachmentPreparationOperation;
    if (operation == null) {
      return;
    }
    try {
      await operation;
    } on Exception {
      // Best-effort wait before saving or closing the inline composer.
    }
  }

  void _cancelInlineAttachmentPreparation() {
    final pendingOperation = _inlinePendingAttachmentOperation;
    _inlinePendingAttachmentOperation = null;
    if (pendingOperation != null) {
      pendingOperation.cancel();
    }
    final cancellation = _inlineAttachmentPreparationCancellation;
    _inlineAttachmentPreparationCancellation = null;
    if (cancellation != null) {
      cancellation.operation.cancel();
    }
  }

  String _nextLocalPendingAttachmentId() {
    final id = _pendingAttachmentSeed;
    _pendingAttachmentSeed += 1;
    return 'local-pending-$id';
  }

  void _replacePendingAttachment(String id, {PendingAttachment? replacement}) {
    final index = _pendingAttachments.indexWhere((pending) => pending.id == id);
    if (index == -1) {
      return;
    }
    setState(() {
      final updated = List<PendingAttachment>.from(_pendingAttachments);
      if (replacement == null) {
        updated.removeAt(index);
      } else {
        updated[index] = replacement;
      }
      _pendingAttachments = updated;
    });
  }

  Future<void> _handleSendMessage({
    required ChatState chatState,
    required ChatSettingsSnapshot settingsSnapshot,
    MessageTransport? oneShotTransportOverride,
  }) async {
    final l10n = context.l10n;
    final locate = context.read;
    final rawComposerText = _inlineComposerController.text;
    final rawText =
        _isEmailComposerWatermarkOnly(
          text: rawComposerText,
          chatState: chatState,
        )
        ? _emptyText
        : rawComposerText.trim();
    final seedText = _pendingCalendarSeedText;
    final String resolvedText = rawText.isNotEmpty
        ? rawText
        : (seedText ?? _emptyText);
    final pendingAttachments = _pendingAttachments;
    final hasPreparingAttachments = pendingAttachments.any(
      (attachment) => attachment.isPreparing,
    );
    final queuedAttachments = pendingAttachments
        .where(
          (attachment) =>
              attachment.status == PendingAttachmentStatus.queued &&
              !attachment.isPreparing,
        )
        .toList();
    final hasQueuedAttachments = queuedAttachments.isNotEmpty;
    final bool hasSubject = _inlineComposerController.subject.trim().isNotEmpty;
    final bool hasCalendarTask = _pendingCalendarTaskIcs != null;
    final bool hasQuotedDraft = _quotedDraft != null;
    final canSend =
        !hasPreparingAttachments &&
        (resolvedText.isNotEmpty ||
            hasQueuedAttachments ||
            hasSubject ||
            hasQuotedDraft ||
            hasCalendarTask);
    if (!canSend) return;
    final chat = chatState.chat;
    if (chat == null) {
      return;
    }
    if (chatState.composerSendStatus.isLoading) {
      return;
    }
    final retryTransportOverride =
        oneShotTransportOverride ?? _inlineRetryTransportOverride;
    final resolvedTransportOverride =
        retryTransportOverride ??
        (chatState.usesSavedEmailTransportOverride
            ? MessageTransport.email
            : null);
    final sendRecipients = _recipients.includedRecipients;
    if (_emailRecipientCountForSend(
          chatState: chatState,
          chat: chat,
          recipients: sendRecipients,
          oneShotTransportOverride: resolvedTransportOverride,
        ) >
        composeRecipientLimit) {
      _showSnackbar(
        context.l10n.fanOutErrorTooManyRecipients(composeRecipientLimit),
      );
      return;
    }
    final shouldSend = await _confirmEmailSendIfNeeded(
      chatState: chatState,
      chat: chat,
      recipients: sendRecipients,
      body: resolvedText,
      attachmentNames: queuedAttachments
          .map((pending) => pending.attachment.fileName)
          .toList(growable: false),
      oneShotTransportOverride: resolvedTransportOverride,
    );
    if (!shouldSend || !mounted) {
      return;
    }
    final calendarTaskShareText = _pendingCalendarTaskIcs?.toShareText(l10n);
    final chatJid = chat.jid;
    final completer = Completer<ChatSendOutcome>();
    locate<ChatBloc>().add(
      ChatMessageSent(
        chat: chat,
        text: resolvedText,
        recipients: sendRecipients,
        pendingAttachments: pendingAttachments,
        settings: settingsSnapshot,
        supportsHttpFileUpload: chatState.supportsHttpFileUpload,
        attachmentFallbackLabel: l10n.chatAttachmentFallbackLabel,
        subject: _inlineComposerController.subject,
        quotedDraft: _quotedDraft,
        roomState: chatState.roomState,
        calendarTaskIcs: _pendingCalendarTaskIcs,
        calendarTaskIcsReadOnly: _pendingCalendarTaskIcsReadOnly,
        calendarTaskShareText: calendarTaskShareText,
        oneShotTransportOverride: resolvedTransportOverride,
        completer: completer,
      ),
    );
    final outcome = await completer.future;
    if (!mounted || locate<ChatBloc>().jid != chatJid) {
      return;
    }
    setState(() {
      _pendingAttachments = outcome.pendingAttachments;
      if (outcome.incomplete) {
        _inlineRetryTransportOverride = retryTransportOverride;
      }
    });
    if (outcome.completed) {
      _inlineRetryTransportOverride = null;
      await _handleInlineComposerSendComplete();
      return;
    }
    if (outcome.incomplete) {
      _applyIncompleteInlineSendOutcome(outcome, chatState: chatState);
    }
  }

  Future<bool> _confirmEmailSendIfNeeded({
    required ChatState chatState,
    required chat_models.Chat chat,
    required List<ComposerRecipient> recipients,
    required String body,
    required List<String> attachmentNames,
    MessageTransport? oneShotTransportOverride,
  }) async {
    if (!_isEmailComposerActive(
      chatState: chatState,
      recipients: recipients,
      oneShotTransportOverride: oneShotTransportOverride,
    )) {
      return true;
    }
    final settingsCubit = context.read<SettingsCubit>();
    final sendConfirmationEnabled =
        chat.emailSendConfirmationEnabled ??
        settingsCubit.state.emailSendConfirmationEnabled;
    if (!sendConfirmationEnabled) {
      return true;
    }
    final draftRecipients = _resolveDraftRecipients(
      chat: chat,
      recipients: recipients,
    );
    final decision = await confirmEmailSend(
      context,
      recipients: draftRecipients,
      body: body,
      attachmentNames: attachmentNames,
    );
    if (!mounted || decision == null || !decision.confirmed) {
      return false;
    }
    if (decision.dontShowAgain) {
      context.read<ChatBloc>().add(
        ChatEmailSendConfirmationChanged(chatJid: chat.jid, enabled: false),
      );
    }
    return true;
  }

  Future<void> _handleSendButtonLongPress({
    required ChatState chatState,
    required ChatSettingsSnapshot settingsSnapshot,
    required bool canSend,
  }) async {
    if (widget.readOnly) return;
    final action = await showAdaptiveBottomSheet<_ComposerSendAction>(
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
              leading: const Icon(LucideIcons.save),
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_ComposerSendAction.saveDraft),
              child: Text(dialogContext.l10n.chatSaveAsDraft),
            ),
            if (canSend && chatState.canOfferEmailOutboundOverride)
              AxiListButton(
                leading: const Icon(LucideIcons.mail),
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_ComposerSendAction.sendAsEmail),
                child: Text(dialogContext.l10n.chatSendAsEmail),
              ),
          ],
        );
      },
    );
    if (!mounted) return;
    _inlineComposerController.requestTextFocus();
    if (action == null) return;
    switch (action) {
      case _ComposerSendAction.saveDraft:
        await _saveComposerAsDraft();
      case _ComposerSendAction.sendAsEmail:
        await _handleSendMessage(
          chatState: chatState,
          settingsSnapshot: settingsSnapshot,
          oneShotTransportOverride: MessageTransport.email,
        );
    }
  }

  Future<bool> _saveComposerAsDraft() async {
    final l10n = context.l10n;
    await _awaitInlineAttachmentPreparationIfNeeded();
    if (!mounted) {
      return false;
    }
    final chatState = context.read<ChatBloc>().state;
    final chat = chatState.chat;
    if (chat == null) {
      _showSnackbar(l10n.chatDraftUnavailable);
      return false;
    }
    final body = _normalizedInlineDraftBody(
      text: _inlineComposerController.text,
      chatState: chatState,
    );
    final subject = _inlineComposerController.subject;
    final trimmedSubject = subject.trim();
    final pendingAttachments = List<PendingAttachment>.from(
      _pendingAttachments,
    );
    final attachmentIds = pendingAttachments
        .map((pending) => pending.id)
        .toList(growable: false);
    final attachments = pendingAttachments
        .map((pending) => pending.attachment)
        .toList();
    if (pendingAttachments.any((pending) => pending.isPreparing)) {
      _showSnackbar(l10n.chatAttachmentFailed);
      return false;
    }
    final quoteTarget = chat.type == ChatType.groupChat
        ? DraftQuoteTarget.fromDraft(
            stanzaId: null,
            originId: null,
            mucStanzaId: _quotedDraft?.trimmedMucStanzaId,
          )
        : DraftQuoteTarget.fromDraft(
            stanzaId: _quotedDraft?.trimmedOriginId == null
                ? _quotedDraft?.trimmedStanzaId
                : null,
            originId: _quotedDraft?.trimmedOriginId,
            mucStanzaId: null,
          );
    final recipients = _resolveDraftRecipients(
      chat: chat,
      recipients: _recipients,
    );
    final allowRecipientOnlyDraft = recipients.length - 1 > 0;
    if (body.trim().isEmpty &&
        trimmedSubject.isEmpty &&
        attachments.isEmpty &&
        quoteTarget == null &&
        _pendingCalendarTaskIcs == null) {
      if (!allowRecipientOnlyDraft) {
        _showSnackbar(l10n.chatDraftMissingContent);
        return false;
      }
    }
    final attemptedSignature = _currentInlineDraftSignature(chatState);
    try {
      final draft = await context.read<DraftCubit>().saveDraft(
        id: _inlineComposerDraftId,
        jids: recipients,
        body: body,
        subject: trimmedSubject.isEmpty ? null : subject,
        quoteTarget: quoteTarget,
        attachments: attachments,
        calendarTaskIcsMessage: _pendingCalendarTaskIcs == null
            ? null
            : CalendarTaskIcsMessage(
                task: _pendingCalendarTaskIcs!,
                readOnly: _pendingCalendarTaskIcsReadOnly,
              ),
      );
      if (!mounted) {
        return false;
      }
      final currentChatState = context.read<ChatBloc>().state;
      final signatureStillCurrent =
          _currentInlineDraftSignature(currentChatState) == attemptedSignature;
      final reconciledAttachments = _inlineAttachmentsWithMetadataIds(
        metadataIds: draft.attachmentMetadata.values,
        expectedAttachmentIds: attachmentIds,
      );
      final savedSignature = signatureStillCurrent
          ? _currentInlineDraftSignature(
              currentChatState,
              pendingAttachments: reconciledAttachments,
            )
          : null;
      setState(() {
        _inlineComposerDraftId = draft.id;
        _pendingAttachments = reconciledAttachments;
        if (savedSignature != null) {
          _lastSavedInlineDraftSignature = savedSignature;
        }
      });
      ShadToaster.maybeOf(
        context,
      )?.show(FeedbackToast.success(title: l10n.draftSaved));
      return true;
    } on Exception {
      if (!mounted) {
        return false;
      }
      _showSnackbar(l10n.chatDraftSaveFailed);
      return false;
    }
  }

  Future<void> _handleInlineComposerSavePressed() async {
    if (_savingInlineDraft) {
      return;
    }
    setState(() {
      _savingInlineDraft = true;
    });
    try {
      await _saveComposerAsDraft();
    } finally {
      if (mounted) {
        setState(() {
          _savingInlineDraft = false;
        });
      }
    }
  }

  Future<void> _handleInlineComposerDiscardPressed() async {
    if (_discardingInlineDraft) {
      return;
    }
    setState(() {
      _discardingInlineDraft = true;
    });
    try {
      await _discardInlineComposer();
    } finally {
      if (mounted) {
        setState(() {
          _discardingInlineDraft = false;
        });
      }
    }
  }

  void _expandEmailComposer() {
    if (!mounted || _composerExpanded) {
      return;
    }
    _dismissTextInputFocus();
    setState(() {
      _composerExpanded = true;
    });
  }

  void _minimizeEmailComposer() {
    if (!mounted || !_composerExpanded) {
      return;
    }
    setState(() {
      _composerExpanded = false;
    });
    _inlineComposerController.requestTextFocus();
  }

  void _clearInlineComposerControllers() {
    _subjectChangeSuppressed = true;
    _inlineComposerController.clear();
    _lastSubjectValue = _emptyText;
    _subjectChangeSuppressed = false;
  }

  void _clearInlineComposerState({required bool clearInlineComposerDraftId}) {
    _cancelInlineAttachmentPreparation();
    _composerHasText = false;
    _clearQuotedDraftAndInvalidateReplyResolution();
    _pendingAttachments = const [];
    _inlineRetryTransportOverride = null;
    _pendingCalendarTaskIcs = null;
    _pendingCalendarTaskIcsReadOnly = _calendarTaskIcsReadOnlyFallback;
    _pendingCalendarSeedText = null;
    _composerExpanded = false;
    _savingInlineDraft = false;
    _discardingInlineDraft = false;
    if (clearInlineComposerDraftId) {
      _inlineComposerDraftId = null;
      _lastSavedInlineDraftSignature = null;
    }
  }

  void _resetInlineComposer({
    required bool clearInlineComposerDraftId,
    bool requestFocus = false,
  }) {
    _clearInlineComposerControllers();
    if (!mounted) return;
    setState(() {
      _clearInlineComposerState(
        clearInlineComposerDraftId: clearInlineComposerDraftId,
      );
    });
    _syncEmailComposerWatermark(
      chatState: context.read<ChatBloc>().state,
      forceInsert: true,
    );
    if (requestFocus) {
      _inlineComposerController.requestTextFocus();
    }
  }

  List<String> _resolveDraftRecipients({
    required chat_models.Chat chat,
    required List<ComposerRecipient> recipients,
  }) => recipients.recipientIds(fallbackJid: chat.jid);

  int _currentInlineDraftSignature(
    ChatState chatState, {
    List<PendingAttachment>? pendingAttachments,
  }) {
    final chat = chatState.chat;
    final resolvedRecipients = chat == null
        ? const <String>[]
        : _resolveDraftRecipients(chat: chat, recipients: _recipients);
    final visibleRecipients = _recipients.includedRecipients
        .map((recipient) => recipient.target.key)
        .toList(growable: false);
    final attachments = pendingAttachments ?? _pendingAttachments;
    String? quotedDraftIdentity;
    if (chat?.type == ChatType.groupChat) {
      quotedDraftIdentity = _quotedDraft?.trimmedMucStanzaId;
    } else {
      final originId = _quotedDraft?.trimmedOriginId;
      if (originId != null) {
        quotedDraftIdentity = originId;
      } else {
        quotedDraftIdentity = _quotedDraft?.trimmedStanzaId;
      }
    }
    return Object.hashAll(<Object?>[
      _normalizedInlineDraftBody(
        text: _inlineComposerController.text,
        chatState: chatState,
      ),
      _inlineComposerController.subject,
      quotedDraftIdentity,
      ...visibleRecipients,
      ...resolvedRecipients,
      ...attachments.map(_inlineAttachmentSignature),
      _pendingCalendarTaskIcs == null
          ? null
          : Object.hash(
              _pendingCalendarTaskIcs,
              _pendingCalendarTaskIcsReadOnly,
            ),
    ]);
  }

  Object _inlineAttachmentSignature(PendingAttachment pending) {
    final attachment = pending.attachment;
    final metadataId = attachment.metadataId;
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

  List<PendingAttachment> _inlineAttachmentsWithMetadataIds({
    required List<String> metadataIds,
    required List<String> expectedAttachmentIds,
  }) {
    if (metadataIds.isEmpty ||
        metadataIds.length != expectedAttachmentIds.length) {
      return _pendingAttachments;
    }
    final idToMetadata = <String, String>{};
    for (var index = 0; index < expectedAttachmentIds.length; index += 1) {
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
    return changed ? updated : _pendingAttachments;
  }

  bool _hasInlineComposerDraftContent(ChatState chatState) {
    final chat = chatState.chat;
    if (chat == null) {
      return false;
    }
    final body = _normalizedInlineDraftBody(
      text: _inlineComposerController.text,
      chatState: chatState,
    );
    final subject = _inlineComposerController.subject.trim();
    final allowRecipientOnlyDraft =
        _resolveDraftRecipients(chat: chat, recipients: _recipients).length -
            1 >
        0;
    return allowRecipientOnlyDraft ||
        body.trim().isNotEmpty ||
        subject.isNotEmpty ||
        _quotedDraft != null ||
        _pendingAttachments.isNotEmpty ||
        _pendingCalendarTaskIcs != null;
  }

  String? _inlineComposerSendBlocker({
    required ChatState chatState,
    required SettingsState settings,
  }) {
    final activeRecipients = _recipients.includedRecipients;
    final emailRecipientsUnavailable =
        !settings.endpointConfig.smtpEnabled &&
        (chatState.usesSavedEmailTransportOverride ||
            activeRecipients.hasEmailRecipients);
    if (emailRecipientsUnavailable) {
      return context.l10n.chatComposerEmailRecipientUnavailable;
    }
    if (activeRecipients.isEmpty) {
      return context.l10n.draftNoRecipients;
    }
    final chat = chatState.chat;
    if (chat != null &&
        _emailRecipientCountForSend(
              chatState: chatState,
              chat: chat,
              recipients: activeRecipients,
            ) >
            composeRecipientLimit) {
      return context.l10n.fanOutErrorTooManyRecipients(composeRecipientLimit);
    }
    final body = _normalizedInlineDraftBody(
      text: _inlineComposerController.text,
      chatState: chatState,
    );
    final subject = _inlineComposerController.subject.trim();
    final hasQueuedAttachments = _pendingAttachments.any(
      (pending) =>
          pending.status == PendingAttachmentStatus.queued &&
          !pending.isPreparing,
    );
    if (body.trim().isEmpty &&
        subject.isEmpty &&
        !hasQueuedAttachments &&
        _quotedDraft == null &&
        _pendingCalendarTaskIcs == null) {
      return context.l10n.draftValidationNoContent;
    }
    return null;
  }

  Future<_InlineComposerCloseAction?> _confirmInlineComposerClose() {
    final l10n = context.l10n;
    return showFadeScaleDialog<_InlineComposerCloseAction>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        var saving = false;
        final pop = Navigator.of(dialogContext).pop;
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> handleSave() async {
              if (saving) {
                return;
              }
              setState(() {
                saving = true;
              });
              final saved = await _saveComposerAsDraft();
              if (!dialogContext.mounted) {
                return;
              }
              if (saved) {
                pop(_InlineComposerCloseAction.save);
                return;
              }
              setState(() {
                saving = false;
              });
            }

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
                  onPressed: saving
                      ? null
                      : () => pop(_InlineComposerCloseAction.cancel),
                  child: Text(l10n.commonCancel),
                ),
                AxiButton.destructive(
                  onPressed: saving
                      ? null
                      : () => pop(_InlineComposerCloseAction.discard),
                  child: Text(l10n.draftDiscard),
                ),
                AxiButton.primary(
                  onPressed: saving ? null : () => unawaited(handleSave()),
                  loading: saving,
                  child: Text(l10n.chatSaveAsDraft),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _handleInlineComposerCloseRequest(ChatState chatState) async {
    final savedSignature = _lastSavedInlineDraftSignature;
    if (savedSignature != null &&
        savedSignature == _currentInlineDraftSignature(chatState)) {
      _resetInlineComposer(clearInlineComposerDraftId: true);
      return true;
    }
    if (!_hasInlineComposerDraftContent(chatState)) {
      if (savedSignature == null) {
        _resetInlineComposer(clearInlineComposerDraftId: true);
        return true;
      }
    }
    final action = await _confirmInlineComposerClose();
    if (!mounted ||
        action == null ||
        action == _InlineComposerCloseAction.cancel) {
      return false;
    }
    if (action == _InlineComposerCloseAction.discard) {
      _resetInlineComposer(clearInlineComposerDraftId: true);
      return true;
    }
    _resetInlineComposer(clearInlineComposerDraftId: true);
    return true;
  }

  Future<void> _discardInlineComposer() async {
    final draftId = _inlineComposerDraftId;
    _resetInlineComposer(clearInlineComposerDraftId: true);
    if (draftId == null) {
      return;
    }
    try {
      await context.read<DraftCubit>().deleteDraft(id: draftId);
    } on Exception {
      // Best-effort after local reset; the composer should stay cleared.
    }
  }

  Future<void> _handleInlineComposerSendComplete() async {
    final draftId = _inlineComposerDraftId;
    setState(() {
      _clearInlineComposerState(clearInlineComposerDraftId: true);
      _recreateInlineComposer();
    });
    _syncEmailComposerWatermark(
      chatState: context.read<ChatBloc>().state,
      forceInsert: true,
    );
    _inlineComposerController.requestTextFocus();
    if (draftId == null) {
      return;
    }
    try {
      await context.read<DraftCubit>().deleteDraft(id: draftId);
    } on Exception {
      // Best-effort after local reset; the composer should stay cleared.
    }
  }

  void _applyIncompleteInlineSendOutcome(
    ChatSendOutcome outcome, {
    required ChatState chatState,
  }) {
    setState(() {
      _recipients = List<ComposerRecipient>.from(outcome.incompleteRecipients);
    });
    _syncEmailComposerWatermark(chatState: chatState);
  }

  Future<bool> _prepareChatExit({
    required bool openChatCalendar,
    required ChatState chatState,
  }) async {
    _dismissTextInputFocus();
    if (!_chatRoute.isMain || openChatCalendar) {
      _returnToMainRoute();
      return false;
    }
    return _handleInlineComposerCloseRequest(chatState);
  }

  Future<void> _handleCloseAllChatsRequested({
    required bool openChatCalendar,
    required ChatState chatState,
  }) async {
    if (!await _prepareChatExit(
      openChatCalendar: openChatCalendar,
      chatState: chatState,
    )) {
      return;
    }
    if (!mounted) {
      return;
    }
    context.read<ChatsCubit>().closeAllChats();
  }

  Future<void> _handlePopChatRequested({
    required bool openChatCalendar,
    required ChatState chatState,
  }) async {
    if (!await _prepareChatExit(
      openChatCalendar: openChatCalendar,
      chatState: chatState,
    )) {
      return;
    }
    if (!mounted) {
      return;
    }
    context.read<ChatsCubit>().popChat();
  }

  Future<void> _handleRestoreChatRequested({
    required bool openChatCalendar,
    required ChatState chatState,
  }) async {
    if (!await _prepareChatExit(
      openChatCalendar: openChatCalendar,
      chatState: chatState,
    )) {
      return;
    }
    if (!mounted) {
      return;
    }
    context.read<ChatsCubit>().restoreChat();
  }

  Future<void> _handleEditMessage(Message message) async {
    if (!mounted) return;
    final chatJid = context.read<ChatBloc>().state.chat?.jid;
    final completer = Completer<List<PendingAttachment>>();
    context.read<ChatBloc>().add(
      ChatMessageEditRequested(message, attachmentsCompleter: completer),
    );
    final attachments = await completer.future;
    if (!mounted || context.read<ChatBloc>().state.chat?.jid != chatJid) {
      return;
    }
    setState(() {
      _pendingAttachments = attachments;
    });
  }

  List<ChatComposerAccessory> _composerAccessories({
    required bool canSend,
    required bool sending,
    required bool attachmentsEnabled,
    required TextEditingController textController,
    required FocusNode attachmentButtonFocusNode,
    required ChatState chatState,
    required ChatSettingsSnapshot settingsSnapshot,
  }) {
    final accessories = <ChatComposerAccessory>[
      ChatComposerAccessory.leading(
        child: FocusTraversalOrder(
          order: const NumericFocusOrder(3),
          child: _EmojiPickerAccessory(
            controller: _emojiPopoverController,
            textController: textController,
          ),
        ),
      ),
      ChatComposerAccessory.leading(
        child: FocusTraversalOrder(
          order: const NumericFocusOrder(2),
          child: Focus(
            focusNode: attachmentButtonFocusNode,
            canRequestFocus: attachmentsEnabled && !_sendingAttachment,
            skipTraversal: !(attachmentsEnabled && !_sendingAttachment),
            child: _AttachmentAccessoryButton(
              enabled: attachmentsEnabled && !_sendingAttachment,
              onPressed: () => _handleAttachmentPressed(chatState),
            ),
          ),
        ),
      ),
      ChatComposerAccessory.trailing(
        child: FocusTraversalOrder(
          order: const NumericFocusOrder(4),
          child: _SendMessageAccessory(
            enabled: canSend,
            loading: sending,
            onPressed: () => _handleSendMessage(
              chatState: chatState,
              settingsSnapshot: settingsSnapshot,
            ),
            onLongPress: widget.readOnly || sending
                ? null
                : () => _handleSendButtonLongPress(
                    chatState: chatState,
                    settingsSnapshot: settingsSnapshot,
                    canSend: canSend,
                  ),
          ),
        ),
      ),
    ];
    return accessories;
  }

  Future<void> _handleAttachmentPressed(ChatState chatState) async {
    final cancellation = CancelableCompleter<void>();
    final operation = _performAttachmentPressed(
      chatState,
      cancellation: cancellation,
    );
    _inlineAttachmentPreparationCancellation = cancellation;
    _inlineAttachmentPreparationOperation = operation;
    try {
      await operation;
    } finally {
      if (_inlineAttachmentPreparationOperation == operation) {
        _inlineAttachmentPreparationOperation = null;
      }
      if (identical(_inlineAttachmentPreparationCancellation, cancellation)) {
        _inlineAttachmentPreparationCancellation = null;
      }
      if (!cancellation.isCompleted && !cancellation.isCanceled) {
        cancellation.complete();
      }
    }
  }

  Future<void> _performAttachmentPressed(
    ChatState chatState, {
    required CancelableCompleter<void> cancellation,
  }) async {
    if (_sendingAttachment) return;
    final l10n = context.l10n;
    setState(() {
      _sendingAttachment = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withReadStream: false,
      );
      if (result == null ||
          result.files.isEmpty ||
          !mounted ||
          cancellation.isCanceled) {
        return;
      }
      final attachments = <Attachment>[];
      var hasInvalidPath = false;
      for (final file in result.files) {
        final path = file.path;
        if (path == null) {
          hasInvalidPath = true;
          continue;
        }
        final String fileName = file.name.isNotEmpty
            ? file.name
            : path.split('/').last;
        attachments.add(
          Attachment(
            path: path,
            fileName: fileName,
            sizeBytes: file.size > 0 ? file.size : 0,
          ),
        );
      }
      if (attachments.isEmpty) {
        if (hasInvalidPath) {
          _showSnackbar(l10n.chatAttachmentInaccessible);
        }
        return;
      }
      if (cancellation.isCanceled) return;
      final chat = chatState.chat;
      if (chat == null) {
        return;
      }
      await _addInlineAttachments(
        chat: chat,
        attachments: attachments,
        cancellation: cancellation,
      );
    } on PlatformException catch (error) {
      _showSnackbar(error.message ?? l10n.chatAttachmentFailed);
    } on Exception {
      _showSnackbar(l10n.chatAttachmentFailed);
    } finally {
      if (mounted) {
        setState(() {
          _sendingAttachment = false;
        });
        _queueShareComposerSeedConsumption();
      }
    }
  }

  Future<bool> _prepareInlineAttachments({
    required chat_models.Chat chat,
    required List<Attachment> attachments,
    required CancelableCompleter<void> cancellation,
  }) async {
    if (_sendingAttachment) {
      return false;
    }
    setState(() {
      _sendingAttachment = true;
    });
    var completed = false;
    try {
      final prepared = await _addInlineAttachments(
        chat: chat,
        attachments: attachments,
        cancellation: cancellation,
      );
      completed = true;
      return prepared;
    } finally {
      if (mounted) {
        setState(() {
          _sendingAttachment = false;
        });
        if (completed) {
          _queueShareComposerSeedConsumption();
        }
      }
    }
  }

  Future<bool> _addInlineAttachments({
    required chat_models.Chat chat,
    required List<Attachment> attachments,
    required CancelableCompleter<void> cancellation,
  }) async {
    final locate = context.read;
    final chatJid = chat.jid;
    for (final attachment in attachments) {
      if (cancellation.isCanceled) {
        return false;
      }
      final placeholderId = _nextLocalPendingAttachmentId();
      setState(() {
        _pendingAttachments = [
          ..._pendingAttachments,
          PendingAttachment(
            id: placeholderId,
            attachment: attachment,
            isPreparing: true,
          ),
        ];
        _clearInlineRetryTransportOverride();
      });
      final completer = CancelableCompleter<PendingAttachment?>();
      final operation = completer.operation;
      _inlinePendingAttachmentOperation = operation;
      locate<ChatBloc>().add(
        ChatAttachmentPicked(
          attachment: attachment,
          recipients: _recipients,
          chat: chat,
          quotedDraft: _quotedDraft,
          completer: completer,
        ),
      );
      final pending = await operation.valueOrCancellation();
      if (_inlinePendingAttachmentOperation == operation) {
        _inlinePendingAttachmentOperation = null;
      }
      if (cancellation.isCanceled ||
          !mounted ||
          locate<ChatBloc>().state.chat?.jid != chatJid) {
        return false;
      }
      _replacePendingAttachment(placeholderId, replacement: pending);
    }
    if (cancellation.isCanceled) {
      return false;
    }
    if (_quotedDraft != null) {
      setState(() {
        _clearQuotedDraftAndInvalidateReplyResolution();
      });
    }
    _inlineComposerController.requestTextFocus();
    return true;
  }

  Future<void> _loadDemoPendingAttachments(chat_models.Chat chat) async {
    final locate = context.read;
    final chatJid = chat.jid;
    final completer = Completer<List<PendingAttachment>>();
    locate<ChatBloc>().add(
      ChatDemoPendingAttachmentsRequested(
        chat: chat,
        existingFileNames: _pendingAttachments
            .map((pending) => pending.attachment.fileName)
            .toSet(),
        completer: completer,
      ),
    );
    final attachments = await completer.future;
    if (!mounted ||
        locate<ChatBloc>().state.chat?.jid != chatJid ||
        attachments.isEmpty) {
      return;
    }
    final existingIds = _pendingAttachments
        .map((pending) => pending.id)
        .toSet();
    final existingFileNames = _pendingAttachments
        .map((pending) => pending.attachment.fileName)
        .toSet();
    final additions = attachments
        .where((pending) {
          return !existingIds.contains(pending.id) &&
              existingFileNames.add(pending.attachment.fileName);
        })
        .toList(growable: false);
    if (additions.isEmpty) {
      return;
    }
    setState(() {
      _pendingAttachments = [..._pendingAttachments, ...additions];
      _clearInlineRetryTransportOverride();
    });
  }

  Future<void> _retryPendingAttachment(
    PendingAttachment pending, {
    required chat_models.Chat? chat,
    required Message? quotedDraft,
    required bool supportsHttpFileUpload,
    required ChatSettingsSnapshot settingsSnapshot,
  }) async {
    if (chat == null) {
      return;
    }
    final locate = context.read;
    final chatJid = chat.jid;
    final index = _pendingAttachments.indexWhere(
      (candidate) => candidate.id == pending.id,
    );
    if (index == -1) {
      return;
    }
    final uploading = pending.copyWith(
      status: PendingAttachmentStatus.uploading,
      clearErrorMessage: true,
    );
    setState(() {
      final updated = List<PendingAttachment>.from(_pendingAttachments);
      updated[index] = uploading;
      _pendingAttachments = updated;
    });
    final completer = Completer<PendingAttachment?>();
    locate<ChatBloc>().add(
      ChatAttachmentRetryRequested(
        attachment: pending,
        recipients: _recipients,
        chat: chat,
        quotedDraft: quotedDraft,
        subject: _inlineComposerController.subject,
        settings: settingsSnapshot,
        supportsHttpFileUpload: supportsHttpFileUpload,
        completer: completer,
      ),
    );
    final updatedPending = await completer.future;
    if (!mounted || locate<ChatBloc>().state.chat?.jid != chatJid) {
      return;
    }
    final currentIndex = _pendingAttachments.indexWhere(
      (candidate) => candidate.id == pending.id,
    );
    if (currentIndex == -1) {
      return;
    }
    setState(() {
      final updated = List<PendingAttachment>.from(_pendingAttachments);
      if (updatedPending == null) {
        updated.removeAt(currentIndex);
      } else {
        updated[currentIndex] = updatedPending;
      }
      _pendingAttachments = updated;
    });
  }

  void _removePendingAttachment(String id) {
    final index = _pendingAttachments.indexWhere((pending) => pending.id == id);
    if (index == -1) {
      return;
    }
    setState(() {
      final updated = List<PendingAttachment>.from(_pendingAttachments)
        ..removeAt(index);
      _pendingAttachments = updated;
      _clearInlineRetryTransportOverride();
    });
  }

  void _handlePendingAttachmentPressed(PendingAttachment pending) {
    if (!mounted) return;
    _showAttachmentPreview(pending);
  }

  void _handlePendingAttachmentLongPressed(PendingAttachment pending) {
    if (!mounted) return;
    _showPendingAttachmentActions(pending);
  }

  List<Widget> _pendingAttachmentMenuItems(
    PendingAttachment pending, {
    required chat_models.Chat? chat,
    required Message? quotedDraft,
    required bool supportsHttpFileUpload,
    required ChatSettingsSnapshot settingsSnapshot,
  }) {
    final l10n = context.l10n;
    final items = <Widget>[];
    items.add(
      ShadContextMenuItem(
        leading: const Icon(LucideIcons.eye),
        onPressed: () => _showAttachmentPreview(pending),
        child: Text(l10n.chatAttachmentView),
      ),
    );
    if (pending.status == PendingAttachmentStatus.failed) {
      items.add(
        ShadContextMenuItem(
          leading: const Icon(LucideIcons.refreshCw),
          onPressed: () => _retryPendingAttachment(
            pending,
            chat: chat,
            quotedDraft: quotedDraft,
            supportsHttpFileUpload: supportsHttpFileUpload,
            settingsSnapshot: settingsSnapshot,
          ),
          child: Text(l10n.chatAttachmentRetry),
        ),
      );
    }
    items.add(
      ShadContextMenuItem(
        leading: const Icon(LucideIcons.trash),
        onPressed: () => _removePendingAttachment(pending.id),
        child: Text(l10n.chatAttachmentRemove),
      ),
    );
    return items;
  }

  Future<void> _showAttachmentPreview(PendingAttachment pending) async {
    if (!mounted) return;
    final l10n = context.l10n;
    await showPendingAttachmentPreview(
      context: context,
      pending: pending,
      onRemove: () => _removePendingAttachment(pending.id),
      removeTooltip: l10n.chatAttachmentRemove,
      closeTooltip: l10n.commonClose,
    );
  }

  Future<void> _showPendingAttachmentActions(PendingAttachment pending) async {
    if (!mounted) return;
    final l10n = context.l10n;
    final locate = context.read;
    final chatBloc = locate<ChatBloc>();
    await showAdaptiveBottomSheet<void>(
      context: context,
      showDragHandle: true,
      dialogMaxWidth: context.sizing.dialogMaxWidth,
      surfacePadding: EdgeInsets.zero,
      builder: (sheetContext) {
        final attachment = pending.attachment;
        final sizeLabel = formatBytes(attachment.sizeBytes, l10n);
        final colors = sheetContext.colorScheme;
        return BlocProvider.value(
          value: chatBloc,
          child: Builder(
            builder: (context) {
              return AxiSheetScaffold.scroll(
                header: AxiSheetHeader(
                  title: Text(l10n.chatAttachmentTooltip),
                  onClose: () => Navigator.of(sheetContext).maybePop(),
                ),
                children: [
                  AxiListButton(
                    leading: Icon(
                      attachmentIcon(attachment),
                      color: colors.primary,
                    ),
                    onPressed: null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(attachment.fileName),
                        Text(
                          sizeLabel,
                          style: context.textTheme.small.copyWith(
                            color: colors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (attachment.isImage)
                    AxiListButton(
                      leading: const Icon(LucideIcons.eye),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _showAttachmentPreview(pending);
                      },
                      child: Text(l10n.chatAttachmentView),
                    ),
                  if (pending.status == PendingAttachmentStatus.failed)
                    AxiListButton(
                      leading: const Icon(LucideIcons.refreshCw),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        final chatState = context.read<ChatBloc>().state;
                        final settingsSnapshot = _settingsSnapshotFromState(
                          context.read<SettingsCubit>().state,
                        );
                        unawaited(
                          _retryPendingAttachment(
                            pending,
                            chat: chatState.chat,
                            quotedDraft: _quotedDraft,
                            supportsHttpFileUpload:
                                chatState.supportsHttpFileUpload,
                            settingsSnapshot: settingsSnapshot,
                          ),
                        );
                      },
                      child: Text(l10n.chatAttachmentRetry),
                    ),
                  AxiListButton(
                    leading: const Icon(LucideIcons.trash),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _removePendingAttachment(pending.id);
                    },
                    child: Text(l10n.chatAttachmentRemove),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _toggleMessageSelection(Message message) async {
    if (widget.readOnly) return;
    final messageId = message.stanzaID;
    if (_multiSelectActive) {
      _toggleMultiSelectMessage(message);
      return;
    }
    if (_selectedMessageId == messageId) {
      await _clearMessageSelection();
    } else {
      await _selectMessage(messageId);
    }
  }

  Future<void> _clearMessageSelection() async {
    if (_selectedMessageId == null) return;
    _selectedMessageVisibilityRequest += 1;
    setState(() {
      _selectedMessageId = null;
    });
  }

  Future<void> _startMultiSelect(Message message) async {
    final messageId = message.stanzaID;
    if (widget.readOnly) return;
    if (_multiSelectedMessageIds.length == 1 &&
        _multiSelectedMessageIds.contains(messageId) &&
        _selectedMessageId == null) {
      return;
    }
    await _clearMessageSelection();
    setState(() {
      _multiSelectedMessageIds
        ..clear()
        ..add(messageId);
      _selectedMessageSnapshots
        ..clear()
        ..[messageId] = message;
    });
  }

  void _toggleMultiSelectMessage(Message message) {
    final messageId = message.stanzaID;
    if (widget.readOnly) return;
    final mutated = _multiSelectedMessageIds.contains(messageId);
    setState(() {
      if (mutated) {
        _multiSelectedMessageIds.remove(messageId);
        _selectedMessageSnapshots.remove(messageId);
      } else {
        _multiSelectedMessageIds.add(messageId);
        _selectedMessageSnapshots[messageId] = message;
      }
    });
  }

  void _syncSelectionCaches(
    ChatState state, {
    Iterable<Message> extraMessages = const [],
    bool notify = true,
  }) {
    if (!mounted) return;
    final messageById = <String, Message>{
      for (final item in state.items) item.stanzaID: item,
      ...state.quotedMessagesById,
    };
    for (final message in extraMessages) {
      messageById[message.stanzaID] = message;
    }
    final availableIds = messageById.keys.toSet();
    final removedKeys = _messageKeys.keys
        .where((id) => !availableIds.contains(id))
        .toList(growable: false);
    final removedSelections = _multiSelectedMessageIds
        .where((id) => !availableIds.contains(id))
        .toList(growable: false);
    var didChange = false;
    if (_emailWebViewHeightByContentKey.isNotEmpty) {
      _pruneEmailWebViewHeights(availableIds);
    }
    if (removedKeys.isNotEmpty) {
      for (final id in removedKeys) {
        _messageKeys.remove(id);
        _bubbleWidthByMessageId.remove(id);
      }
      didChange = true;
    }
    for (final id in availableIds) {
      if (_messageKeys.containsKey(id)) continue;
      _messageKeys[id] = GlobalKey();
      didChange = true;
    }
    if (removedSelections.isNotEmpty) {
      _multiSelectedMessageIds.removeAll(removedSelections);
      for (final id in removedSelections) {
        _selectedMessageSnapshots.remove(id);
      }
      didChange = true;
    }
    if (_multiSelectedMessageIds.isNotEmpty) {
      for (final id in _multiSelectedMessageIds) {
        final message = messageById[id];
        if (message == null) continue;
        if (_selectedMessageSnapshots[id] == message) continue;
        _selectedMessageSnapshots[id] = message;
        didChange = true;
      }
    }
    if (!didChange) return;
    if (!notify) {
      return;
    }
    setState(() {});
  }

  void _ensureAvatarPathCaches({
    required List<RosterItem> rosterItems,
    required List<chat_models.Chat> chatItems,
    required String? selfAvatarPath,
    required String? normalizedXmppSelfJid,
    required String? normalizedEmailSelfJid,
  }) {
    final sameRoster = identical(rosterItems, _cachedRosterItems);
    final sameChats = identical(chatItems, _cachedChatItems);
    final sameSelfAvatar = selfAvatarPath == _cachedSelfAvatarPath;
    final sameXmppSelf = normalizedXmppSelfJid == _cachedNormalizedXmppSelfJid;
    final sameEmailSelf =
        normalizedEmailSelfJid == _cachedNormalizedEmailSelfJid;
    if (sameRoster &&
        sameChats &&
        sameSelfAvatar &&
        sameXmppSelf &&
        sameEmailSelf) {
      return;
    }
    final rosterAvatarPathsByJid = <String, String>{};
    for (final item in rosterItems) {
      final path = item.avatarPath?.trim();
      if (path == null || path.isEmpty) continue;
      final normalizedJid = normalizedAddressValue(item.jid);
      if (normalizedJid == null) continue;
      rosterAvatarPathsByJid[normalizedJid] = path;
    }
    final chatAvatarPathsByJid = <String, String>{};
    for (final chat in chatItems) {
      final path = (chat.avatarPath ?? chat.contactAvatarPath)?.trim();
      if (path == null || path.isEmpty) continue;
      final normalizedJid = normalizedAddressValue(chat.jid);
      if (normalizedJid != null && normalizedJid.isNotEmpty) {
        chatAvatarPathsByJid[normalizedJid] = path;
      }
      final normalizedRemoteJid = normalizedAddressValue(chat.remoteJid);
      if (normalizedRemoteJid != null && normalizedRemoteJid.isNotEmpty) {
        chatAvatarPathsByJid[normalizedRemoteJid] = path;
      }
    }
    final normalizedSelfJids = <String>{};
    if (normalizedXmppSelfJid != null) {
      normalizedSelfJids.add(normalizedXmppSelfJid);
    }
    if (normalizedEmailSelfJid != null) {
      normalizedSelfJids.add(normalizedEmailSelfJid);
    }
    if (normalizedSelfJids.isNotEmpty && selfAvatarPath?.isNotEmpty == true) {
      final selfAvatarPathValue = selfAvatarPath!;
      for (final selfJid in normalizedSelfJids) {
        rosterAvatarPathsByJid.putIfAbsent(selfJid, () => selfAvatarPathValue);
        chatAvatarPathsByJid.putIfAbsent(selfJid, () => selfAvatarPathValue);
      }
    }
    _cachedRosterItems = rosterItems;
    _cachedChatItems = chatItems;
    _cachedSelfAvatarPath = selfAvatarPath;
    _cachedNormalizedXmppSelfJid = normalizedXmppSelfJid;
    _cachedNormalizedEmailSelfJid = normalizedEmailSelfJid;
    _cachedRosterAvatarPathsByJid = rosterAvatarPathsByJid;
    _cachedChatAvatarPathsByJid = chatAvatarPathsByJid;
  }

  List<String> _emailHtmlDerivationPrewarmBodies({
    required List<Message> messages,
    required Map<int, String> emailFullHtmlByDeltaId,
  }) {
    final normalizedHtmlBodies = <String>[];
    final seenHtmlBodies = <String>{};
    void addHtml(String? html) {
      final normalizedHtml = HtmlContentCodec.normalizeHtml(html);
      if (normalizedHtml == null ||
          HtmlContentCodec.cachedEmailDerivations(normalizedHtml) != null ||
          !seenHtmlBodies.add(normalizedHtml)) {
        return;
      }
      normalizedHtmlBodies.add(normalizedHtml);
    }

    for (final message in messages) {
      addHtml(message.htmlBody);
      final deltaMessageId = message.deltaMsgId;
      if (deltaMessageId != null) {
        addHtml(emailFullHtmlByDeltaId[deltaMessageId]);
      }
    }
    return normalizedHtmlBodies;
  }

  Future<void> _prewarmEmailHtmlDerivationsForMessages({
    required List<Message> messages,
    required Map<int, String> emailFullHtmlByDeltaId,
    required String source,
  }) async {
    final normalizedHtmlBodies = _emailHtmlDerivationPrewarmBodies(
      messages: messages,
      emailFullHtmlByDeltaId: emailFullHtmlByDeltaId,
    );
    if (normalizedHtmlBodies.isEmpty) {
      return;
    }
    SafeLogging.profileTrace(
      'chat.emailHtmlPrewarm',
      'requested',
      fields: <String, Object?>{
        'source': source,
        'messageCount': messages.length,
        'pendingCount': normalizedHtmlBodies.length,
        'profileHash': SafeLogging.profileFingerprint(
          jsonEncode(normalizedHtmlBodies),
        ),
      },
    );
    await _precacheEmailHtmlDerivations(normalizedHtmlBodies, source: source);
  }

  Future<bool> _precacheEmailHtmlDerivations(
    List<String> normalizedHtmlBodies, {
    required String source,
  }) async {
    final stopwatch = Stopwatch()..start();
    final bool cacheUpdated;
    try {
      cacheUpdated = await HtmlContentCodec.precacheEmailDerivations(
        normalizedHtmlBodies,
      );
    } on Exception {
      SafeLogging.profileTrace(
        'chat.emailHtmlPrewarm',
        'end',
        fields: <String, Object?>{
          'source': source,
          'pendingCount': normalizedHtmlBodies.length,
          'result': 'error',
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return false;
    }
    SafeLogging.profileTrace(
      'chat.emailHtmlPrewarm',
      'end',
      fields: <String, Object?>{
        'source': source,
        'pendingCount': normalizedHtmlBodies.length,
        'cacheUpdated': cacheUpdated,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      },
    );
    return cacheUpdated;
  }

  void _ensureMessageCaches({
    required List<Message> items,
    required Map<String, Message> quotedMessagesById,
    required List<Message> searchResults,
    required bool searchFiltering,
    required Map<String, List<String>> attachmentsByMessageId,
    required Map<String, String> groupLeaderByMessageId,
    required Map<int, String> emailFullHtmlByDeltaId,
  }) {
    _reconcilePendingReactionPreviews(items);
    final sameItems = identical(items, _cachedItems);
    final sameQuoted = identical(quotedMessagesById, _cachedQuotedMessagesById);
    final sameSearch = identical(searchResults, _cachedSearchResults);
    final sameSearchFiltering = searchFiltering == _cachedSearchFiltering;
    final sameAttachments = identical(
      attachmentsByMessageId,
      _cachedAttachmentsByMessageId,
    );
    final sameGroupLeaders = identical(
      groupLeaderByMessageId,
      _cachedGroupLeaderByMessageId,
    );
    final sameEmailFullHtml = identical(
      emailFullHtmlByDeltaId,
      _cachedEmailFullHtmlByDeltaId,
    );
    if (sameItems &&
        sameQuoted &&
        sameSearch &&
        sameSearchFiltering &&
        sameAttachments &&
        sameGroupLeaders &&
        sameEmailFullHtml) {
      return;
    }
    final messageById = <String, Message>{
      for (final item in items) item.stanzaID: item,
    };
    for (final entry in quotedMessagesById.entries) {
      messageById.putIfAbsent(entry.key, () => entry.value);
    }
    if (searchFiltering) {
      for (final item in searchResults) {
        messageById[item.stanzaID] = item;
      }
    }
    final activeItems = searchFiltering ? searchResults : items;
    bool isGroupedNonLeader(Message message) {
      final messageId = message.id;
      if (messageId == null || messageId.isEmpty) {
        return false;
      }
      final leaderId = groupLeaderByMessageId[messageId];
      return leaderId != null && leaderId != messageId;
    }

    final displayItems = activeItems
        .where((message) => !isGroupedNonLeader(message))
        .toList(growable: false);
    const emptyAttachments = <String>[];
    String messageKey(Message message) => message.id ?? message.stanzaID;
    List<String> attachmentsForMessage(Message message) {
      return attachmentsByMessageId[messageKey(message)] ?? emptyAttachments;
    }

    final filteredItems = displayItems
        .where((message) {
          final hasHtml = message.normalizedHtmlBody?.isNotEmpty == true;
          final hasSubject = message.subject?.trim().isNotEmpty == true;
          final deltaMessageId = message.deltaMsgId;
          final attachments = attachmentsForMessage(message);
          return message.body != null ||
              hasSubject ||
              hasHtml ||
              (deltaMessageId != null && deltaMessageId > 0) ||
              message.error.isNotNone ||
              attachments.isNotEmpty;
        })
        .toList(growable: false);
    _cachedItems = items;
    _cachedQuotedMessagesById = quotedMessagesById;
    _cachedSearchResults = searchResults;
    _cachedSearchFiltering = searchFiltering;
    _cachedAttachmentsByMessageId = attachmentsByMessageId;
    _cachedGroupLeaderByMessageId = groupLeaderByMessageId;
    _cachedEmailFullHtmlByDeltaId = emailFullHtmlByDeltaId;
    _cachedMessageById = messageById;
    _cachedFilteredItems = filteredItems;
  }

  void _syncTimelineItems(List<ChatTimelineItem> items) {
    if (identical(items, _cachedTimelineItems)) {
      return;
    }
    final availableIds = items.map((item) => item.id).toSet();
    _mountedTimelineItemIds.removeWhere((id) => !availableIds.contains(id));
    _cachedTimelineItems = items;
  }

  void _handleTimelineItemMounted(String itemId) {
    _mountedTimelineItemIds.add(itemId);
  }

  void _handleTimelineItemUnmounted(String itemId) {
    _mountedTimelineItemIds.remove(itemId);
  }

  void _clearMultiSelection() {
    if (_multiSelectedMessageIds.isEmpty) return;
    setState(() {
      _multiSelectedMessageIds.clear();
      _selectedMessageSnapshots.clear();
    });
  }

  List<Message> _collectSelectedMessages(List<Message> orderedMessages) {
    if (_multiSelectedMessageIds.isEmpty) return const [];
    final selected = <Message>[];
    final presentIds = <String>{};
    for (final message in orderedMessages) {
      final id = message.stanzaID;
      if (_multiSelectedMessageIds.contains(id)) {
        selected.add(message);
        presentIds.add(id);
      }
    }
    if (selected.length == _multiSelectedMessageIds.length) {
      return selected;
    }
    for (final id in _multiSelectedMessageIds) {
      if (presentIds.contains(id)) continue;
      final snapshot = _selectedMessageSnapshots[id];
      if (snapshot != null) {
        selected.add(snapshot);
      }
    }
    return selected;
  }

  Future<void> _selectMessage(String messageId) async {
    if (_selectedMessageId == messageId) return;
    setState(() {
      _selectedMessageId = messageId;
    });
    if (!mounted) return;
    _scheduleSelectedMessageVisibilityCheck(messageId);
  }

  void _scheduleSelectedMessageVisibilityCheck(String messageId) {
    final request = ++_selectedMessageVisibilityRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          request != _selectedMessageVisibilityRequest ||
          _selectedMessageId != messageId) {
        return;
      }
      unawaited(_scrollSelectedMessageIntoView(messageId));
    });
  }

  Future<void> _scrollSelectedMessageIntoView(String messageId) async {
    final key = _messageKeys[messageId];
    final context = key?.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      duration: _bubbleFocusDuration,
      curve: _bubbleFocusCurve,
    );
  }

  BuildContext? get _unreadDividerContext {
    return _unreadDividerKey.currentContext;
  }

  Future<bool> _waitForUnreadDividerContext() async {
    if (_unreadDividerContext != null) {
      return true;
    }
    for (var attempt = 0; attempt < 8; attempt += 1) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return false;
      }
      if (_unreadDividerContext != null) {
        return true;
      }
    }
    return _unreadDividerContext != null;
  }

  Future<void> _handleUnreadBoundaryScrollRequest(
    String? boundaryMessageId, {
    required int requestId,
  }) async {
    try {
      final messageId = boundaryMessageId?.trim();
      final dividerPrepared = await _prepareTimelineItemContextForScroll(
        ChatBloc.unreadDividerScrollTargetMessageId,
        jumpBeforeWaiting: true,
      );
      if (dividerPrepared) {
        await WidgetsBinding.instance.endOfFrame;
        final ready = await _waitForUnreadDividerContext();
        final dividerContext = _unreadDividerContext;
        if (mounted &&
            ready &&
            dividerContext != null &&
            dividerContext.mounted) {
          await Scrollable.ensureVisible(
            dividerContext,
            alignment: 1,
            alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
            duration: Duration.zero,
          );
          await WidgetsBinding.instance.endOfFrame;
          _scheduleReadThresholdSync();
        }
        return;
      }
      if (_hasCachedTimelineItem(ChatBloc.unreadDividerScrollTargetMessageId)) {
        return;
      }
      if (messageId != null && messageId.isNotEmpty) {
        await _prepareMessageContextForScroll(
          messageId,
          jumpBeforeWaiting: true,
        );
      }
      if (messageId == null || messageId.isEmpty) {
        return;
      }
      final messageContext = _messageKeys[messageId]?.currentContext;
      if (!mounted || messageContext == null || !messageContext.mounted) {
        return;
      }
      await Scrollable.ensureVisible(
        messageContext,
        alignment: 1.0,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        duration: Duration.zero,
      );
      await WidgetsBinding.instance.endOfFrame;
      _scheduleReadThresholdSync();
    } finally {
      _completeUnreadDividerScrollRequest(requestId);
    }
  }

  bool _hasMessageContext(String messageId) {
    return _messageKeys[messageId]?.currentContext != null;
  }

  int? _displayedMessageIndex(String messageId) {
    for (var index = 0; index < _cachedFilteredItems.length; index += 1) {
      if (_cachedFilteredItems[index].stanzaID == messageId) {
        return index;
      }
    }
    return null;
  }

  ({int min, int max})? _mountedMessageIndexRange() {
    int? minIndex;
    int? maxIndex;
    for (var index = 0; index < _cachedFilteredItems.length; index += 1) {
      final messageId = _cachedFilteredItems[index].stanzaID;
      if (_messageKeys[messageId]?.currentContext == null) {
        continue;
      }
      minIndex = minIndex == null ? index : math.min(minIndex, index);
      maxIndex = maxIndex == null ? index : math.max(maxIndex, index);
    }
    if (minIndex == null || maxIndex == null) {
      return null;
    }
    return (min: minIndex, max: maxIndex);
  }

  bool _hasTimelineItemContext(String itemId) {
    return _mountedTimelineItemIds.contains(itemId);
  }

  int? _displayedTimelineItemIndex(String itemId) {
    for (var index = 0; index < _cachedTimelineItems.length; index += 1) {
      if (_cachedTimelineItems[index].id == itemId) {
        return index;
      }
    }
    return null;
  }

  bool _hasCachedTimelineItem(String itemId) {
    return _displayedTimelineItemIndex(itemId) != null;
  }

  ({int min, int max})? _mountedTimelineItemIndexRange() {
    int? minIndex;
    int? maxIndex;
    for (var index = 0; index < _cachedTimelineItems.length; index += 1) {
      final itemId = _cachedTimelineItems[index].id;
      if (!_mountedTimelineItemIds.contains(itemId)) {
        continue;
      }
      minIndex = minIndex == null ? index : math.min(minIndex, index);
      maxIndex = maxIndex == null ? index : math.max(maxIndex, index);
    }
    if (minIndex == null || maxIndex == null) {
      return null;
    }
    return (min: minIndex, max: maxIndex);
  }

  Future<bool> _waitForIndexedContext(bool Function() hasTargetContext) async {
    if (hasTargetContext()) {
      return true;
    }
    for (var attempt = 0; attempt < 8; attempt += 1) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return false;
      }
      if (hasTargetContext()) {
        return true;
      }
    }
    return hasTargetContext();
  }

  Future<bool> _prepareIndexedContextForScroll({
    required int? Function() targetIndex,
    required int Function() itemCount,
    required bool Function() hasTargetContext,
    required ({int min, int max})? Function() mountedIndexRange,
    bool jumpBeforeWaiting = false,
  }) async {
    if (jumpBeforeWaiting) {
      if (hasTargetContext()) {
        return true;
      }
    } else if (await _waitForIndexedContext(hasTargetContext)) {
      return true;
    }
    if (!_scrollController.hasClients ||
        !_scrollController.position.hasPixels) {
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted || !_scrollController.hasClients) {
      return false;
    }
    final position = _scrollController.position;
    if (!position.hasPixels) {
      return false;
    }
    var lowerOffsetBound = 0.0;
    var upperOffsetBound = double.infinity;
    final attemptedOffsets = <double>[];
    double currentUpperOffsetBound() {
      final maxScrollExtent = math.max(0.0, position.maxScrollExtent);
      return upperOffsetBound.isFinite
          ? math.min(upperOffsetBound, maxScrollExtent)
          : maxScrollExtent;
    }

    double clampOffset(double offset) {
      final maxScrollExtent = math.max(0.0, position.maxScrollExtent);
      return offset.clamp(0.0, maxScrollExtent).toDouble();
    }

    bool wasAttempted(double offset) {
      for (final attempted in attemptedOffsets) {
        if ((attempted - offset).abs() < 1) {
          return true;
        }
      }
      return false;
    }

    for (var attempt = 0; attempt < 14; attempt += 1) {
      if (jumpBeforeWaiting) {
        if (hasTargetContext()) {
          return true;
        }
      } else if (await _waitForIndexedContext(hasTargetContext)) {
        return true;
      }
      if (!mounted || !_scrollController.hasClients) {
        return false;
      }
      final currentTargetIndex = targetIndex();
      final currentItemCount = itemCount();
      if (currentTargetIndex == null || currentItemCount <= 0) {
        if (jumpBeforeWaiting) {
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted) {
            return false;
          }
        }
        continue;
      }
      final maxScrollExtent = math.max(0.0, position.maxScrollExtent);
      final mountedRange = mountedIndexRange();
      double targetOffset;
      if (mountedRange == null) {
        targetOffset = currentItemCount <= 1
            ? _scrollController.offset
            : clampOffset(
                maxScrollExtent * (currentTargetIndex / (currentItemCount - 1)),
              );
      } else if (currentTargetIndex > mountedRange.max) {
        lowerOffsetBound = math.max(lowerOffsetBound, _scrollController.offset);
        targetOffset = clampOffset(
          (lowerOffsetBound + currentUpperOffsetBound()) / 2,
        );
        if ((targetOffset - _scrollController.offset).abs() < 1) {
          targetOffset = currentUpperOffsetBound();
        }
      } else if (currentTargetIndex < mountedRange.min) {
        upperOffsetBound = math.min(upperOffsetBound, _scrollController.offset);
        targetOffset = clampOffset((lowerOffsetBound + upperOffsetBound) / 2);
        if ((targetOffset - _scrollController.offset).abs() < 1) {
          targetOffset = lowerOffsetBound;
        }
      } else {
        targetOffset = _scrollController.offset;
      }
      if ((_scrollController.offset - targetOffset).abs() < 1 &&
          wasAttempted(targetOffset)) {
        break;
      }
      if (wasAttempted(targetOffset)) {
        final lowerCandidate = clampOffset(lowerOffsetBound);
        final upperCandidate = clampOffset(currentUpperOffsetBound());
        if (!wasAttempted(lowerCandidate) &&
            (_scrollController.offset - lowerCandidate).abs() >= 1) {
          targetOffset = lowerCandidate;
        } else if (!wasAttempted(upperCandidate) &&
            (_scrollController.offset - upperCandidate).abs() >= 1) {
          targetOffset = upperCandidate;
        } else {
          break;
        }
      }
      attemptedOffsets.add(targetOffset);
      if ((_scrollController.offset - targetOffset).abs() < 1) {
        if (jumpBeforeWaiting) {
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted) {
            return false;
          }
        }
        continue;
      }
      _scrollController.jumpTo(targetOffset);
      if (jumpBeforeWaiting) {
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) {
          return false;
        }
      }
    }
    return hasTargetContext();
  }

  Future<bool> _prepareMessageContextForScroll(
    String messageId, {
    bool jumpBeforeWaiting = false,
  }) {
    return _prepareIndexedContextForScroll(
      targetIndex: () => _displayedMessageIndex(messageId),
      itemCount: () => _cachedFilteredItems.length,
      hasTargetContext: () => _hasMessageContext(messageId),
      mountedIndexRange: _mountedMessageIndexRange,
      jumpBeforeWaiting: jumpBeforeWaiting,
    );
  }

  Future<bool> _prepareTimelineItemContextForScroll(
    String itemId, {
    bool jumpBeforeWaiting = false,
  }) {
    return _prepareIndexedContextForScroll(
      targetIndex: () => _displayedTimelineItemIndex(itemId),
      itemCount: () => _cachedTimelineItems.length,
      hasTargetContext: () => _hasTimelineItemContext(itemId),
      mountedIndexRange: _mountedTimelineItemIndexRange,
      jumpBeforeWaiting: jumpBeforeWaiting,
    );
  }

  Future<void> _handleScrollTargetRequest(String messageId) async {
    if (_pinnedPanelVisible) {
      _closePinnedMessages();
      await WidgetsBinding.instance.endOfFrame;
    }
    final ready = await _prepareMessageContextForScroll(messageId);
    if (!mounted || !ready) {
      return;
    }
    if (_selectedMessageId == messageId) {
      await _scrollSelectedMessageIntoView(messageId);
      return;
    }
    await _selectMessage(messageId);
  }

  @override
  void initState() {
    super.initState();
    _emojiPopoverController = ShadPopoverController();
    _recreateInlineComposer();
    _scrollController = ScrollController(
      initialScrollOffset: _restoreScrollOffset(),
    );
    _scrollController.addListener(_handleScrollChanged);
    _syncSelectionCaches(context.read<ChatBloc>().state, notify: false);
    _scheduleReadThresholdSync();
    final initialState = context.read<ChatBloc>().state;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _handlePendingUnreadDividerScroll(context.read<ChatBloc>().state);
    });
    final chat = initialState.chat;
    _recipientsChatJid = chat?.jid;
    final settings = context.read<SettingsCubit>().state;
    if (chat != null) {
      _recipients = [
        ComposerRecipient(
          target: Contact.chat(
            chat: chat,
            shareSignatureEnabled:
                chat.shareSignatureEnabled ??
                settings.shareTokenSignatureEnabled,
          ),
          included: true,
          pinned: true,
        ),
      ];
    }
    if (chat != null) {
      unawaited(_loadDemoPendingAttachments(chat));
    }
    _shareComposerSeedSubscription = context
        .read<ShareComposerSeedQueue>()
        .stream
        .listen(_handleShareComposerSeed);
    _shareComposerSeedConsumptionSubscription =
        _shareComposerSeedConsumptionRequests.stream
            .asyncMap((_) => _consumePendingShareComposerSeeds())
            .listen((_) {});
    _queueShareComposerSeedConsumption();
    context.read<ChatBloc>().add(
      ChatSettingsUpdated(_settingsSnapshotFromState(settings)),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final chatsState = context.read<ChatsCubit>().state;
    _consumePendingOpenMessageSelection(chatsState);
    final currentKey = _scrollStorageKey;
    if (_lastScrollStorageKey == null) {
      _lastScrollStorageKey = currentKey;
      _restoreScrollOffsetForCurrentChat();
      _syncChatRoute();
      _updateChatRouteHistoryEntry();
      _syncEmailComposerWatermark(chatState: context.read<ChatBloc>().state);
      return;
    }
    if (_lastScrollStorageKey != currentKey) {
      _persistScrollOffset(key: _lastScrollStorageKey);
      _lastScrollStorageKey = currentKey;
      _restoreScrollOffsetForCurrentChat();
    }
    _syncChatRoute();
    _updateChatRouteHistoryEntry();
    _syncEmailComposerWatermark(chatState: context.read<ChatBloc>().state);
  }

  @override
  void dispose() {
    _cancelInlineAttachmentPreparation();
    unawaited(_shareComposerSeedSubscription?.cancel());
    unawaited(_shareComposerSeedConsumptionSubscription.cancel());
    unawaited(_shareComposerSeedConsumptionRequests.close());
    _persistScrollOffset(key: _lastScrollStorageKey, skipPageStorage: true);
    _scrollController.dispose();
    _emojiPopoverController.dispose();
    _bubbleRegionRegistry.clear();
    _clearChatRouteHistoryEntry();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: BlocBuilder<ChatSearchCubit, ChatSearchState>(
        builder: (context, searchState) {
          final trimmedQuery = searchState.query.trim();
          final hasSubjectFilter =
              searchState.subjectFilter?.isNotEmpty == true;
          final searchFiltering =
              searchState.active &&
              (trimmedQuery.isNotEmpty || hasSubjectFilter);
          final searchResults = searchState.results;
          final profileJid = context.watch<ProfileCubit>().state.jid;
          final trimmedProfileJid = profileJid.trim();
          final String? selfJid = trimmedProfileJid.isNotEmpty
              ? trimmedProfileJid
              : null;
          final selfIdentity = SelfAvatar(
            jid: selfJid,
            avatar: Avatar.tryParseOrNull(
              path: context.watch<ProfileCubit>().state.avatarPath,
              hash: null,
            ),
            hydrating: context.watch<ProfileCubit>().state.avatarHydrating,
          );
          final showToast = ShadToaster.maybeOf(context)?.show;
          return MultiBlocListener(
            listeners: [
              BlocListener<SettingsCubit, SettingsState>(
                listenWhen: (previous, current) =>
                    previous.language != current.language ||
                    previous.chatReadReceipts != current.chatReadReceipts ||
                    previous.emailReadReceipts != current.emailReadReceipts ||
                    previous.autoDownloadImages != current.autoDownloadImages ||
                    previous.autoDownloadVideos != current.autoDownloadVideos ||
                    previous.autoDownloadDocuments !=
                        current.autoDownloadDocuments ||
                    previous.autoDownloadArchives !=
                        current.autoDownloadArchives ||
                    previous.shareTokenSignatureEnabled !=
                        current.shareTokenSignatureEnabled ||
                    previous.emailComposerWatermarkEnabled !=
                        current.emailComposerWatermarkEnabled,
                listener: (context, settings) {
                  context.read<ChatBloc>().add(
                    ChatSettingsUpdated(_settingsSnapshotFromState(settings)),
                  );
                  _syncEmailComposerWatermark(
                    chatState: context.read<ChatBloc>().state,
                    settings: settings,
                  );
                },
              ),
              BlocListener<SettingsCubit, SettingsState>(
                listenWhen: (previous, current) =>
                    previous.endpointConfig != current.endpointConfig,
                listener: (context, settings) async {
                  final emailService = settings.endpointConfig.smtpEnabled
                      ? context.read<EmailService>()
                      : null;
                  context.read<ChatBloc>().add(
                    ChatEmailServiceUpdated(emailService),
                  );
                  await context.read<ChatSearchCubit>().updateEmailService(
                    emailService,
                  );
                },
              ),
              BlocListener<ChatSearchCubit, ChatSearchState>(
                listenWhen: (previous, current) =>
                    previous.active != current.active ||
                    !identical(previous.results, current.results),
                listener: (context, searchState) {
                  if (!mounted) return;
                  _syncSelectionCaches(
                    context.read<ChatBloc>().state,
                    extraMessages: searchState.active
                        ? searchState.results
                        : const [],
                  );
                  if (searchState.active) {
                    context.read<ChatBloc>().add(
                      ChatRenderedMessagesHydrationRequested(
                        searchState.results,
                        allowOffWindowEmailContentHydration: true,
                      ),
                    );
                    _openChatSearch();
                    return;
                  }
                  if (_chatRoute.isSearch) {
                    _returnToMainRoute();
                  }
                },
              ),
              BlocListener<CalendarBloc, CalendarState>(
                listenWhen: (previous, current) =>
                    previous.isLoading != current.isLoading,
                listener: _handleCalendarImportStateChanged,
              ),
              BlocListener<ChatsCubit, ChatsState>(
                listenWhen: (previous, current) =>
                    previous.openChatRoute != current.openChatRoute,
                listener: (context, chatsState) {
                  if (!widget.syncWithOpenChatRoute) {
                    return;
                  }
                  if (!mounted) return;
                  final storedRoute = chatsState.openChatRoute;
                  if (_chatRoute == storedRoute) return;
                  final nextRoute = _resolvedStoredChatRoute(
                    route: storedRoute,
                    state: context.read<ChatBloc>().state,
                  );
                  if (nextRoute == _chatRoute) {
                    if (nextRoute != storedRoute) {
                      context.read<ChatsCubit>().setOpenChatRoute(
                        route: nextRoute,
                      );
                    }
                    return;
                  }
                  _setChatRoute(nextRoute);
                },
              ),
              BlocListener<ChatBloc, ChatState>(
                listenWhen: (previous, current) =>
                    previous.toastId != current.toastId &&
                    current.toast != null,
                listener: (context, state) {
                  final toast = state.toast;
                  final show = showToast;
                  if (toast == null || show == null) return;
                  final l10n = context.l10n;
                  const actionLabel = null;
                  const VoidCallback? onAction = null;
                  final toastTitle =
                      toast.title ??
                      switch (toast.variant) {
                        ChatToastVariant.destructive => l10n.toastWhoopsTitle,
                        ChatToastVariant.warning => l10n.toastHeadsUpTitle,
                        ChatToastVariant.info => l10n.toastAllSetTitle,
                      };
                  final toastMessage =
                      toast.messageText ??
                      toast.message?.label(
                        l10n,
                        moderationAction: toast.messageActionLabel,
                        moderationTarget: toast.messageTargetLabel,
                      );
                  final toastWidget = switch (toast.variant) {
                    ChatToastVariant.destructive => FeedbackToast.error(
                      title: toastTitle,
                      message: toastMessage,
                      actionLabel: actionLabel,
                      onAction: onAction,
                    ),
                    ChatToastVariant.warning => FeedbackToast.warning(
                      title: toastTitle,
                      message: toastMessage,
                      actionLabel: actionLabel,
                      onAction: onAction,
                    ),
                    ChatToastVariant.info => FeedbackToast.success(
                      title: toastTitle,
                      message: toastMessage,
                      actionLabel: actionLabel,
                      onAction: onAction,
                    ),
                  };
                  show(toastWidget);
                },
              ),
              BlocListener<ChatBloc, ChatState>(
                listenWhen: (previous, current) =>
                    previous.pendingForwardDraft !=
                        current.pendingForwardDraft &&
                    current.pendingForwardDraft != null,
                listener: (context, state) {
                  final draft = state.pendingForwardDraft;
                  if (draft == null) {
                    return;
                  }
                  openComposeDraft(
                    context,
                    jids: const [''],
                    subject: _forwardDraftSubject(context.l10n, draft),
                    forwardedBlocks: draft.forwardedBlocks,
                    forwardedSourceAttachmentMetadataIds:
                        draft.attachmentMetadataIds,
                  );
                  _clearMultiSelection();
                  context.read<ChatBloc>().add(
                    const ChatForwardDraftConsumed(),
                  );
                },
              ),
              BlocListener<ChatBloc, ChatState>(
                listenWhen: (previous, current) =>
                    previous.openChatRequestId != current.openChatRequestId,
                listener: (context, state) {
                  final targetJid = state.openChatJid;
                  if (targetJid == null || targetJid.trim().isEmpty) {
                    return;
                  }
                  context.read<ChatsCubit>().openChat(jid: targetJid);
                },
              ),
              BlocListener<ChatsCubit, ChatsState>(
                listenWhen: (previous, current) =>
                    previous.pendingOpenMessageRequestId !=
                        current.pendingOpenMessageRequestId ||
                    previous.pendingOpenMessageReferenceId !=
                        current.pendingOpenMessageReferenceId ||
                    previous.pendingOpenMessageChatJid !=
                        current.pendingOpenMessageChatJid,
                listener: (context, state) {
                  _consumePendingOpenMessageSelection(state);
                },
              ),
              BlocListener<ChatBloc, ChatState>(
                listenWhen: (previous, current) =>
                    previous.chat?.jid != current.chat?.jid,
                listener: (context, _) {
                  _consumePendingOpenMessageSelection(
                    context.read<ChatsCubit>().state,
                  );
                },
              ),
              BlocListener<ChatBloc, ChatState>(
                listenWhen: (previous, current) =>
                    current.scrollTargetMessageId != null &&
                    (current.scrollTargetMessageId ==
                            ChatBloc.unreadDividerScrollTargetMessageId
                        ? _initialUnreadScrollPending(current) &&
                              (previous.scrollTargetRequestId !=
                                      current.scrollTargetRequestId ||
                                  previous.messagesLoaded !=
                                      current.messagesLoaded ||
                                  previous.items != current.items ||
                                  previous.unreadBoundaryStanzaId !=
                                      current.unreadBoundaryStanzaId)
                        : previous.scrollTargetRequestId !=
                              current.scrollTargetRequestId),
                listener: (_, state) {
                  final messageId = state.scrollTargetMessageId;
                  if (messageId == null || messageId.trim().isEmpty) {
                    return;
                  }
                  if (messageId ==
                      ChatBloc.unreadDividerScrollTargetMessageId) {
                    _handlePendingUnreadDividerScroll(state);
                    return;
                  }
                  unawaited(_handleScrollTargetRequest(messageId));
                },
              ),
              BlocListener<ChatBloc, ChatState>(
                listenWhen: (previous, current) =>
                    previous.chat?.jid != current.chat?.jid,
                listener: (_, state) {
                  _activeUnreadDividerScrollRequestId = 0;
                  _completedUnreadDividerScrollRequestId = 0;
                  _reportedReadThresholdMessageIds = const <String>{};
                  _resetInitialTimelineReadiness();
                  _mountedTimelineItemIds.clear();
                  _cachedTimelineItems = const [];
                  _animatedMessageIds.clear();
                  _hydratedAnimatedMessages = false;
                  _clearInlineComposerControllers();
                  _clearInlineComposerState(clearInlineComposerDraftId: true);
                  _resetRecipientsForChat(state.chat);
                  _syncEmailComposerWatermark(chatState: state);
                  _queueShareComposerSeedConsumption();
                  if (state.messagesLoaded) {
                    _hydrateAnimatedMessages(state.items);
                  }
                },
              ),
              BlocListener<ChatBloc, ChatState>(
                listenWhen: (previous, current) =>
                    previous.chat != current.chat &&
                    previous.chat?.jid == current.chat?.jid,
                listener: (_, state) => _resetRecipientsForChat(state.chat),
              ),
              BlocListener<ChatBloc, ChatState>(
                listenWhen: (previous, current) =>
                    previous.chat?.jid != current.chat?.jid,
                listener: (_, state) {
                  final chat = state.chat;
                  if (chat == null) {
                    return;
                  }
                  unawaited(_loadDemoPendingAttachments(chat));
                },
              ),
              BlocListener<ChatBloc, ChatState>(
                listenWhen: (previous, current) =>
                    previous.savedTransportOverride !=
                        current.savedTransportOverride ||
                    previous.emailServiceAvailable !=
                        current.emailServiceAvailable,
                listener: (_, state) {
                  _syncEmailComposerWatermark(chatState: state);
                },
              ),
              BlocListener<ChatBloc, ChatState>(
                listenWhen: (previous, current) =>
                    previous.focused?.stanzaID != current.focused?.stanzaID ||
                    previous.chat?.jid != current.chat?.jid,
                listener: (_, state) {
                  final nextRoute = _resolvedStoredChatRoute(
                    route: _chatRoute,
                    state: state,
                  );
                  if (nextRoute == _chatRoute) {
                    return;
                  }
                  _setChatRoute(nextRoute);
                },
              ),
              BlocListener<ChatBloc, ChatState>(
                listenWhen: (previous, current) =>
                    !_hydratedAnimatedMessages &&
                    current.messagesLoaded &&
                    (previous.items != current.items ||
                        previous.messagesLoaded != current.messagesLoaded),
                listener: (_, state) => _hydrateAnimatedMessages(state.items),
              ),
              BlocListener<ChatBloc, ChatState>(
                listenWhen: (previous, current) =>
                    previous.items != current.items ||
                    previous.quotedMessagesById != current.quotedMessagesById,
                listener: (context, state) {
                  final searchState = context.read<ChatSearchCubit>().state;
                  _syncSelectionCaches(
                    state,
                    extraMessages: searchState.active
                        ? searchState.results
                        : const [],
                  );
                },
              ),
              BlocListener<ChatBloc, ChatState>(
                listenWhen: (previous, current) =>
                    previous.chat?.jid != current.chat?.jid ||
                    previous.items != current.items ||
                    previous.messagesLoaded != current.messagesLoaded ||
                    previous.emailFullHtmlByDeltaId !=
                        current.emailFullHtmlByDeltaId ||
                    previous.emailFullHtmlUnavailable !=
                        current.emailFullHtmlUnavailable,
                listener: (_, _) => _scheduleReadThresholdSync(),
              ),
            ],
            child: BlocConsumer<ChatBloc, ChatState>(
              listenWhen: (previous, current) {
                if (current.composerHydrationId == 0) return false;
                return previous.composerHydrationId !=
                    current.composerHydrationId;
              },
              listener: (context, state) {
                final text = state.composerHydrationText ?? '';
                final subject = state.chat?.defaultTransport.isEmail == true
                    ? (state.emailSubject ?? '')
                    : _emptyText;
                _subjectChangeSuppressed = true;
                _inlineComposerController.setSubjectText(subject);
                _lastSubjectValue = subject;
                _subjectChangeSuppressed = false;
                _inlineComposerController.setTextValue(
                  TextEditingValue(
                    text: text,
                    selection: TextSelection.collapsed(offset: text.length),
                    composing: TextRange.empty,
                  ),
                );
                _composerHasText =
                    _isEmailComposerWatermarkOnly(text: text, chatState: state)
                    ? false
                    : text.trim().isNotEmpty;
                final calendarTaskIcsMessage =
                    state.composerHydrationCalendarTaskIcsMessage;
                _pendingCalendarTaskIcs = calendarTaskIcsMessage?.task;
                _pendingCalendarTaskIcsReadOnly =
                    calendarTaskIcsMessage?.readOnly ??
                    _calendarTaskIcsReadOnlyFallback;
                _pendingCalendarSeedText = calendarTaskIcsMessage?.task
                    .toShareText(context.l10n)
                    .trim();
                _syncEmailComposerWatermark(
                  chatState: state,
                  forceInsert: true,
                );
                if (!_inlineComposerController.hasTextFocus) {
                  _inlineComposerController.requestTextFocus();
                }
              },
              builder: (context, state) {
                ProfileState? profileState() =>
                    context.watch<ProfileCubit>().state;
                ChatsState? chatsState() => context.watch<ChatsCubit>().state;
                final chatsCubitState = chatsState();
                final readOnly = widget.readOnly;
                final emailSelfJid = state.emailSelfJid;
                final String? resolvedEmailSelfJid = emailSelfJid
                    .resolveDeltaPlaceholderJid();
                final chatEntity = state.chat;
                final resolvedDirectChatDisplayName =
                    _resolvedDirectChatDisplayName(
                      chat: chatEntity,
                      chatsState: chatsCubitState,
                    );
                final isWelcomeChat =
                    chatEntity?.isAxichatWelcomeThread == true;
                final List<BlocklistEntry> blocklistEntries =
                    _resolveBlocklistEntries(context);
                final BlocklistEntry? chatBlocklistEntry = chatEntity == null
                    ? null
                    : _resolveChatBlocklistEntry(
                        chat: chatEntity,
                        entries: blocklistEntries,
                      );
                final bool isChatBlocked = chatBlocklistEntry != null;
                final String? blockAddress = chatEntity == null
                    ? null
                    : _resolveChatBlockAddress(chat: chatEntity);
                final bool attachmentsBlockedForChat =
                    isChatBlocked || (chatEntity?.spam ?? false);
                final jid = chatEntity?.jid;
                final isDefaultEmail =
                    chatEntity?.defaultTransport.isEmail ?? false;
                final isGroupChat = chatEntity?.type == ChatType.groupChat;
                final currentUserId = isDefaultEmail
                    ? (resolvedEmailSelfJid ?? profileState()?.jid ?? '')
                    : (profileState()?.jid ?? resolvedEmailSelfJid ?? '');
                final String? trimmedProfileJid = profileState()?.jid.trim();
                final String? selfXmppJid =
                    trimmedProfileJid?.isNotEmpty == true
                    ? trimmedProfileJid
                    : null;
                final String? accountJidForPins = isDefaultEmail
                    ? (resolvedEmailSelfJid ?? selfXmppJid)
                    : (selfXmppJid ?? resolvedEmailSelfJid);
                final String? normalizedXmppSelfJid = normalizedAddressKey(
                  selfXmppJid,
                );
                final String? normalizedEmailSelfJid = normalizedAddressKey(
                  resolvedEmailSelfJid,
                );
                final String? normalizedChatJid = normalizedAddressKey(
                  chatEntity?.remoteJid,
                );
                final bool isSelfChat =
                    normalizedChatJid != null &&
                    ((normalizedXmppSelfJid != null &&
                            normalizedChatJid == normalizedXmppSelfJid) ||
                        (normalizedEmailSelfJid != null &&
                            normalizedChatJid == normalizedEmailSelfJid));
                final String? selfAvatarPath = profileState()?.avatarPath
                    ?.trim();
                final myOccupantJid = state.roomState?.myOccupantJid;
                final myOccupant = state.roomState?.selfOccupant;
                final selfNick = (myOccupant?.nick ?? chatEntity?.myNickname)
                    ?.trim();
                final trimmedCurrentUserId = currentUserId.trim();
                final String? availabilityActorId = isGroupChat
                    ? state.roomState?.resolvedSelfJid(
                        fallbackJid: currentUserId,
                      )
                    : trimmedCurrentUserId.isEmpty
                    ? null
                    : trimmedCurrentUserId;
                final roomBootstrapInProgress =
                    isGroupChat && _isRoomBootstrapInProgress(state);
                final roomJoinFailureState = isGroupChat
                    ? _roomJoinFailureState(state)
                    : null;
                final roomJoinFailed = roomJoinFailureState != null;
                final shareContexts = state.shareContexts;
                final shareReplies = state.shareReplies;
                final recipients = _recipients;
                final isEmailComposer = _isEmailComposerActive(
                  chatState: state,
                  recipients: recipients,
                );
                final pendingAttachments = _pendingAttachments;
                final settingsState = context.watch<SettingsCubit>().state;
                final settingsSnapshot = _settingsSnapshotFromState(
                  settingsState,
                );
                final composerSendOnEnter = _resolveComposerSendOnEnter(
                  recipients: recipients,
                  settings: settingsState,
                );
                final canSendEmailAttachments =
                    state.emailServiceAvailable &&
                    chatEntity != null &&
                    _hasEmailAttachmentTarget(
                      chatState: state,
                      chat: chatEntity,
                      recipients: recipients,
                    );
                final attachmentsEnabled =
                    isWelcomeChat ||
                    state.supportsHttpFileUpload ||
                    canSendEmailAttachments;
                final latestStatuses = _latestRecipientStatuses(state);
                final fanOutReports = state.fanOutReports;
                final warningEntry = fanOutReports.entries.isEmpty
                    ? null
                    : fanOutReports.entries.last;
                final showAttachmentWarning =
                    warningEntry?.value.attachmentWarning ?? false;
                final rosterItems =
                    context.watch<RosterCubit>().state.items ??
                    (context.watch<RosterCubit>()[RosterCubit.itemsCacheKey]
                        as List<RosterItem>?) ??
                    const <RosterItem>[];
                final chatItems =
                    chatsState()?.items ?? const <chat_models.Chat>[];
                _ensureAvatarPathCaches(
                  rosterItems: rosterItems,
                  chatItems: chatItems,
                  selfAvatarPath: selfAvatarPath,
                  normalizedXmppSelfJid: normalizedXmppSelfJid,
                  normalizedEmailSelfJid: normalizedEmailSelfJid,
                );
                final rosterAvatarPathsByJid = _cachedRosterAvatarPathsByJid;
                final chatAvatarPathsByJid = _cachedChatAvatarPathsByJid;
                String? avatarPathForBareJid(String jid) {
                  final normalized = normalizedAddressValue(jid);
                  if (normalized == null || normalized.isEmpty) return null;
                  return rosterAvatarPathsByJid[normalized] ??
                      chatAvatarPathsByJid[normalized];
                }

                String? avatarPathForTypingParticipant(String participant) {
                  final trimmed = participant.trim();
                  if (trimmed.isEmpty) return null;
                  final bareParticipant = bareAddress(trimmed);
                  if (bareParticipant == null) return null;
                  if (bareParticipant == trimmed) {
                    return avatarPathForBareJid(trimmed);
                  }
                  final roomJid = normalizedAddressValue(chatEntity?.jid);
                  final isRoomParticipant =
                      normalizedAddressValue(bareParticipant) == roomJid;
                  if (!isRoomParticipant) {
                    return avatarPathForBareJid(bareParticipant);
                  }
                  final roomState = state.roomState!;
                  final realJid = roomState.senderRealJid(trimmed);
                  if (realJid == null || realJid.isEmpty) return null;
                  final bareRealJid = bareAddress(realJid) ?? realJid;
                  return avatarPathForBareJid(bareRealJid);
                }

                final storageManager = context.watch<CalendarStorageManager>();
                final chatCalendarCoordinator = _resolveChatCalendarCoordinator(
                  storageManager: storageManager,
                );
                final storage = storageManager.authStorage;
                final bool personalCalendarAvailable =
                    storageManager.isAuthStorageReady;
                final bool supportsChatCalendar =
                    chatEntity?.supportsChatCalendarForAccount(
                      accountJid: selfXmppJid,
                    ) ??
                    false;
                final bool chatCalendarReady =
                    storageManager.isAuthStorageReady &&
                    chatCalendarCoordinator != null;
                final bool chatCalendarEnabled =
                    supportsChatCalendar && chatCalendarReady;
                final ChatCalendarSyncCoordinator?
                resolvedChatCalendarCoordinator = chatCalendarCoordinator;
                final bool chatCalendarAvailable =
                    chatCalendarEnabled &&
                    resolvedChatCalendarCoordinator != null &&
                    storage != null &&
                    chatEntity != null;
                final retryEntry = _lastReportEntryWhere(
                  fanOutReports.entries,
                  (entry) => entry.value.hasFailures,
                );
                final retryReport = retryEntry?.value;
                final retryShareId = retryEntry?.key;
                VoidCallback? onFanOutRetry;
                if (retryReport != null &&
                    retryShareId != null &&
                    chatEntity != null) {
                  final draft = state.fanOutDrafts[retryShareId];
                  if (draft != null) {
                    final failedStatuses = retryReport.statuses
                        .where(
                          (status) =>
                              status.state == FanOutRecipientState.failed,
                        )
                        .toList();
                    final settingsSnapshot = _settingsSnapshotFromState(
                      context.read<SettingsCubit>().state,
                    );
                    final recipients = failedStatuses
                        .map(
                          (status) => ComposerRecipient(
                            target: status.requestedTarget.toContact(),
                            recipientKey: status.recipientKey,
                            included: true,
                          ),
                        )
                        .toList();
                    if (recipients.isNotEmpty) {
                      onFanOutRetry = () => context.read<ChatBloc>().add(
                        ChatFanOutRetryRequested(
                          draft: draft,
                          recipients: recipients,
                          chat: chatEntity,
                          settings: settingsSnapshot,
                        ),
                      );
                    }
                  }
                }
                final availableChats =
                    (chatsState()?.items ?? const <chat_models.Chat>[])
                        .where((chat) => chat.jid != chatEntity?.jid)
                        .toList();
                final openStack = chatsState()?.openStack ?? const <String>[];
                final forwardStack =
                    chatsState()?.forwardStack ?? const <String>[];
                final bool openChatCalendar =
                    chatsState()?.openChatCalendar ?? false;

                final selfUserId = isGroupChat && myOccupantJid != null
                    ? myOccupantJid
                    : currentUserId;
                final user = ChatUser(
                  id: selfUserId,
                  firstName:
                      (isGroupChat ? myOccupant?.nick : null) ??
                      profileState()?.username ??
                      '',
                );
                final bool canShowSettings = !readOnly && jid != null;
                final bool isSettingsRoute =
                    canShowSettings && _chatRoute.isSettings;
                final isEmailBacked =
                    chatEntity?.defaultTransport.isEmail ?? false;
                final canManagePins =
                    !isEmailBacked &&
                    (!isGroupChat ||
                        (state.roomState != null &&
                            !state.roomState!.myRole.isVisitor &&
                            !state.roomState!.myRole.isNone &&
                            ((state.roomState?.myRole.isParticipant ?? false) ||
                                (state.roomState?.myRole.canManagePins ??
                                    false) ||
                                (state.roomState?.myAffiliation.isMember ??
                                    false) ||
                                (state.roomState?.myAffiliation.canManagePins ??
                                    false))));
                final canTogglePins = !readOnly && canManagePins;
                final int pinnedCount = state.pinnedMessages.length;
                final bool calendarFirstRoom =
                    chatEntity?.isCalendarFirstRoom ?? false;
                final bool showingChatCalendar =
                    openChatCalendar || _chatRoute.isCalendar;
                final mediaQuery = MediaQuery.sizeOf(context);
                final bool isCompactChat = mediaQuery.width < smallScreen;
                final bool showCloseButton =
                    !readOnly && (!isWelcomeChat || isCompactChat);
                final List<AppBarActionItem> navigationActions =
                    <AppBarActionItem>[
                      if (!readOnly && openStack.length > 1)
                        AppBarActionItem(
                          label: context.l10n.chatBack,
                          iconData: LucideIcons.arrowLeft,
                          onPressed: () {
                            unawaited(
                              _handlePopChatRequested(
                                openChatCalendar: openChatCalendar,
                                chatState: state,
                              ),
                            );
                          },
                        ),
                      if (!readOnly && forwardStack.isNotEmpty)
                        AppBarActionItem(
                          label: context.l10n.chatMessageOpenChat,
                          iconData: LucideIcons.arrowRight,
                          onPressed: () {
                            unawaited(
                              _handleRestoreChatRequested(
                                openChatCalendar: openChatCalendar,
                                chatState: state,
                              ),
                            );
                          },
                        ),
                    ];
                final int navigationActionCount = navigationActions.length;
                final int chatActionCount =
                    _chatBaseActionCount +
                    (isEmailBacked ? 1 : 0) +
                    (isGroupChat ? 1 : 0) +
                    (chatCalendarAvailable ? 1 : 0) +
                    (canShowSettings ? 1 : 0);
                final scaffold = _ChatScaffoldLayout(
                  owner: this,
                  state: state,
                  chatEntity: chatEntity,
                  jid: jid,
                  readOnly: readOnly,
                  isWelcomeChat: isWelcomeChat,
                  isSelfChat: isSelfChat,
                  isGroupChat: isGroupChat,
                  isEmailBacked: isEmailBacked,
                  isEmailComposer: isEmailComposer,
                  chatCalendarAvailable: chatCalendarAvailable,
                  personalCalendarAvailable: personalCalendarAvailable,
                  showCloseButton: showCloseButton,
                  canShowSettings: canShowSettings,
                  isSettingsRoute: isSettingsRoute,
                  calendarFirstRoom: calendarFirstRoom,
                  showingChatCalendar: showingChatCalendar,
                  calendarSurfaceActive: widget.calendarSurfaceActive,
                  pinnedCount: pinnedCount,
                  navigationActions: navigationActions,
                  navigationActionCount: navigationActionCount,
                  chatActionCount: chatActionCount,
                  selfIdentity: selfIdentity,
                  user: user,
                  selfAvatarPath: selfAvatarPath,
                  selfXmppJid: selfXmppJid,
                  currentUserId: currentUserId,
                  myOccupantJid: myOccupantJid,
                  selfNick: selfNick,
                  normalizedXmppSelfJid: normalizedXmppSelfJid,
                  normalizedEmailSelfJid: normalizedEmailSelfJid,
                  resolvedEmailSelfJid: resolvedEmailSelfJid,
                  resolvedDirectChatDisplayName: resolvedDirectChatDisplayName,
                  availabilityActorId: availabilityActorId,
                  accountJidForPins: accountJidForPins,
                  attachmentsBlockedForChat: attachmentsBlockedForChat,
                  searchFiltering: searchFiltering,
                  searchResults: searchResults,
                  shareContexts: shareContexts,
                  shareReplies: shareReplies,
                  showAttachmentWarning: showAttachmentWarning,
                  retryReport: retryReport,
                  retryShareId: retryShareId,
                  onFanOutRetry: onFanOutRetry,
                  availableChats: availableChats,
                  recipients: recipients,
                  pendingAttachments: pendingAttachments,
                  settingsState: settingsState,
                  settingsSnapshot: settingsSnapshot,
                  composerSendOnEnter: composerSendOnEnter,
                  attachmentsEnabled: attachmentsEnabled,
                  canTogglePins: canTogglePins,
                  roomBootstrapInProgress: roomBootstrapInProgress,
                  roomJoinFailed: roomJoinFailed,
                  roomJoinFailureState: roomJoinFailureState,
                  latestStatuses: latestStatuses,
                  isChatBlocked: isChatBlocked,
                  chatBlocklistEntry: chatBlocklistEntry,
                  blockAddress: blockAddress,
                  profileJid: profileJid,
                  avatarPathForBareJid: avatarPathForBareJid,
                  avatarPathForTypingParticipant:
                      avatarPathForTypingParticipant,
                  onToggleCollapseLongEmails: () {
                    setState(() {
                      _collapseLongEmailMessages = !_collapseLongEmailMessages;
                    });
                  },
                  onClearQuote: _quotedDraft == null
                      ? () {}
                      : () => setState(() {
                          _clearQuotedDraftAndInvalidateReplyResolution();
                        }),
                  storageManager: storageManager,
                );
                return _ChatContentSurface(
                  chatEntity: chatEntity,
                  calendarAvailable: chatCalendarAvailable,
                  resolvedChatCalendarCoordinator:
                      resolvedChatCalendarCoordinator,
                  storage: storage,
                  storageManager: storageManager,
                  child: scaffold,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<String?> _pickEmoji() async {
    if (!mounted) return null;
    return showAdaptiveBottomSheet<String>(
      context: context,
      dialogMaxWidth: context.sizing.dialogMaxWidth,
      surfacePadding: EdgeInsets.zero,
      builder: (sheetContext) {
        final picker = SizedBox(
          height: sheetContext.sizing.menuMaxHeight,
          child: EmojiPicker(
            config: Config(
              emojiViewConfig: EmojiViewConfig(
                emojiSizeMax: sheetContext.read<Policy>().getMaxEmojiSize(),
              ),
            ),
            onEmojiSelected: (_, emoji) =>
                Navigator.of(sheetContext).pop(emoji.emoji),
          ),
        );
        return AxiSheetScaffold(
          header: AxiSheetHeader(
            title: Text(sheetContext.l10n.chatReactionsPick),
            onClose: () => Navigator.of(sheetContext).maybePop(),
          ),
          body: picker,
        );
      },
    );
  }

  List<ReactionPreview> _reactionPreviewsForMessage(Message message) {
    return _pendingReactionPreviewsByMessageId[message.stanzaID]?.preview ??
        message.reactionsPreview;
  }

  void _reconcilePendingReactionPreviews(Iterable<Message> messages) {
    final availableIds = messages
        .map((message) => message.stanzaID)
        .where((id) => id.isNotEmpty)
        .toSet();
    _pendingReactionPreviewsByMessageId.removeWhere((id, pending) {
      if (!availableIds.contains(id)) {
        return true;
      }
      for (final message in messages) {
        if (message.stanzaID == id) {
          return !listEquals(pending.base, message.reactionsPreview);
        }
      }
      return true;
    });
  }

  List<ReactionPreview> _toggleReactionPreview(
    List<ReactionPreview> reactions, {
    required String emoji,
  }) {
    final next = reactions.toList(growable: true);
    final index = next.indexWhere((reaction) => reaction.emoji == emoji);
    if (index < 0) {
      next.add(ReactionPreview(emoji: emoji, count: 1, reactedBySelf: true));
    } else {
      final existing = next[index];
      if (existing.reactedBySelf) {
        if (existing.count <= 1) {
          next.removeAt(index);
        } else {
          next[index] = existing.copyWith(
            count: existing.count - 1,
            reactedBySelf: false,
          );
        }
      } else {
        next[index] = existing.copyWith(
          count: existing.count + 1,
          reactedBySelf: true,
        );
      }
    }
    next.sort((a, b) {
      final countCompare = b.count.compareTo(a.count);
      if (countCompare != 0) {
        return countCompare;
      }
      return a.emoji.compareTo(b.emoji);
    });
    return List<ReactionPreview>.unmodifiable(next);
  }

  Future<void> _handleReactionSelection(Message message) async {
    final selected = await _pickEmoji();
    if (!mounted || selected == null || selected.isEmpty) return;
    await _applyQuickReaction(message, selected);
  }

  void _toggleQuickReactionForMessages(
    Iterable<Message> messages,
    String emoji,
  ) {
    for (final message in messages) {
      _toggleQuickReaction(message, emoji);
    }
  }

  Future<void> _handleMultiReactionSelection(List<Message> messages) async {
    if (messages.isEmpty) return;
    final selected = await _pickEmoji();
    if (!mounted || selected == null || selected.isEmpty) return;
    _toggleQuickReactionForMessages(messages, selected);
  }

  Future<void> _handleForward(Message message) async {
    context.read<ChatBloc>().add(ChatMessageForwardRequested(message: message));
  }

  Future<void> _handleInviteTap(
    Message message, {
    required String? selfJid,
  }) async {
    final l10n = context.l10n;
    final data = message.pseudoMessageData ?? const {};
    final roomJid = data['roomJid'] as String?;
    final roomName = (data['roomName'] as String?)?.trim();
    final invitee = data['invitee'] as String?;
    if (roomJid == null) return;
    if (invitee != null &&
        selfJid != null &&
        mox.JID.fromString(invitee).toBare().toString() !=
            mox.JID.fromString(selfJid).toBare().toString()) {
      _showSnackbar(l10n.chatInviteWrongAccount);
      return;
    }
    final unknownRoomFallbackLabel = l10n.chatInviteRoomFallbackLabel;
    final roomDisplayName = roomName?.isNotEmpty == true
        ? roomName!
        : unknownRoomFallbackLabel;
    final accepted = await confirm(
      context,
      title: l10n.chatInviteConfirmTitle,
      message: l10n.chatInviteConfirmMessage(roomDisplayName),
      confirmLabel: l10n.chatInviteConfirmLabel,
      destructiveConfirm: false,
    );
    if (!mounted || accepted != true) return;
    context.read<ChatBloc>().add(ChatInviteJoinRequested(message));
    await context.read<ChatsCubit>().openChat(jid: roomJid);
  }

  Future<void> _runShareAction(Future<void> Function() action) async {
    if (_shareRequestStatus.isLoading) return;
    setState(() {
      _shareRequestStatus = RequestStatus.loading;
    });
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _shareRequestStatus = RequestStatus.none;
        });
      }
    }
  }

  Future<void> _shareMessage({
    required String fallbackText,
    required Message model,
  }) async {
    await _runShareAction(() async {
      final l10n = context.l10n;
      final content = plainTextForMessage(
        fallbackText: fallbackText,
        model: model,
      ).trim();
      if (content.isEmpty) {
        _showSnackbar(l10n.chatShareNoText);
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          text: content,
          subject: l10n.chatShareSubjectPrefix(
            context.read<ChatBloc>().state.chat?.title ??
                l10n.chatShareFallbackSubject,
          ),
        ),
      );
    });
  }

  Future<void> _copyMessage({
    required String fallbackText,
    required Message model,
  }) async {
    final successMessage = context.l10n.chatCopySuccessMessage;
    final copiedText = plainTextForMessage(
      fallbackText: fallbackText,
      model: model,
    );
    if (copiedText.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: copiedText));
    if (!mounted) return;
    FeedbackSystem.showSuccess(context, successMessage);
  }

  Future<void> _handleAddToCalendar({
    required String fallbackText,
    required Message model,
  }) async {
    final l10n = context.l10n;
    final calendarAvailable = context
        .read<CalendarStorageManager>()
        .isAuthStorageReady;
    const bool demoEmailQuickAdd = kEnableDemoChats;
    if (demoEmailQuickAdd) {
      if (!calendarAvailable) {
        _showSnackbar(l10n.chatCalendarUnavailable);
        return;
      }
      final DateTime baseDate = demoNow();
      final DateTime scheduledTime = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day + 1,
        13,
      );
      const Duration duration = Duration(hours: 1);
      const String title = 'hang out';
      context.read<CalendarBloc>().add(
        CalendarEvent.taskAdded(
          title: title,
          scheduledTime: scheduledTime,
          duration: duration,
          priority: TaskPriority.none,
        ),
      );
      FeedbackSystem.showSuccess(
        context,
        l10n.chatCalendarTaskCopySuccessMessage,
      );
      return;
    }
    final seededText = plainTextForMessage(
      fallbackText: fallbackText,
      model: model,
    ).trim();
    if (seededText.isEmpty) {
      _showSnackbar(l10n.chatCalendarNoText);
      return;
    }
    if (!calendarAvailable) {
      _showSnackbar(l10n.chatCalendarUnavailable);
      return;
    }
    final calendarText = await pickCalendarSeed(seededText);
    if (!mounted || calendarText == null) {
      return;
    }

    final locationHelper = LocationAutocompleteHelper.fromState(
      context.read<CalendarBloc>().state,
    );

    await showQuickAddModal(
      context: context,
      prefilledText: calendarText,
      locationHelper: locationHelper,
      locateCalendarBloc: () => context.read<CalendarBloc>(),
      onTaskAdded: (task, queuedCriticalPathIds) {
        context.read<CalendarBloc>().add(
          CalendarEvent.taskAdded(
            title: task.title,
            scheduledTime: task.scheduledTime,
            description: task.description,
            duration: task.duration,
            deadline: task.deadline,
            location: task.location,
            endDate: task.endDate,
            priority: task.priority ?? TaskPriority.none,
            recurrence: task.recurrence,
            queuedCriticalPathIds: queuedCriticalPathIds,
          ),
        );
      },
    );
  }

  Future<String?> pickCalendarSeed(String seededText) async {
    final trimmed = seededText.trim();
    if (trimmed.isEmpty) return null;
    final selection = await showFadeScaleDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) =>
          _CalendarTextSelectionDialog(initialText: trimmed),
    );
    if (!mounted) return null;
    if (selection == null) return null;
    final normalized = selection.trim();
    return normalized.isEmpty ? null : normalized;
  }

  String displayTextForMessage(Message message) {
    final body = message.plainText.trim();
    if (message.error.isNotNone) {
      final l10n = context.l10n;
      final label = message.error.label(l10n);
      return body.isEmpty ? label : l10n.chatMessageErrorWithBody(label, body);
    }
    return body;
  }

  String plainTextForMessage({
    required String fallbackText,
    required Message model,
  }) {
    final plainText = model.plainText.trim();
    if (plainText.isNotEmpty) return plainText;
    return fallbackText.trim();
  }

  String? _recipientVisibilityLabel({
    required chat_models.Chat? chat,
    required List<ComposerRecipient> recipients,
  }) {
    if (chat == null) return null;
    if (recipients.length <= 1) return null;
    final shouldFanOut = shouldFanOutRecipients(
      chat: chat,
      recipients: recipients,
    );
    if (!shouldFanOut) return null;
    return context.l10n.chatRecipientVisibilityBccLabel;
  }

  bool shouldFanOutRecipients({
    required chat_models.Chat chat,
    required List<ComposerRecipient> recipients,
  }) => recipients.shouldFanOut(chat);

  String joinedMessageText(List<Message> messages) {
    final buffer = StringBuffer();
    for (final message in messages) {
      final text = displayTextForMessage(message);
      if (text.isEmpty) continue;
      if (buffer.isNotEmpty) buffer.write('\n\n');
      buffer.write(text);
    }
    return buffer.toString();
  }

  String _forwardDraftSubject(AppLocalizations l10n, ChatForwardDraft draft) {
    final prefix = l10n.chatForwardPrefix.trim();
    if (draft.sources.length != 1) {
      return prefix;
    }
    final originalSubject = draft.sources.single.originalSubject?.trim();
    if (originalSubject == null || originalSubject.isEmpty) {
      return prefix;
    }
    return '$prefix $originalSubject';
  }

  Future<void> _copySelectedMessages(List<Message> messages) async {
    final l10n = context.l10n;
    final joined = joinedMessageText(messages);
    if (joined.isEmpty) {
      _showSnackbar(l10n.chatCopyNoText);
      return;
    }
    final successMessage = l10n.chatCopySuccessMessage;
    await Clipboard.setData(ClipboardData(text: joined));
    if (!mounted) return;
    FeedbackSystem.showSuccess(context, successMessage);
    _clearMultiSelection();
  }

  Future<void> _shareSelectedMessages(List<Message> messages) async {
    await _runShareAction(() async {
      final l10n = context.l10n;
      final joined = joinedMessageText(messages).trim();
      if (joined.isEmpty) {
        _showSnackbar(l10n.chatShareSelectedNoText);
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          text: joined,
          subject: l10n.chatShareSubjectPrefix(
            context.read<ChatBloc>().state.chat?.title ??
                l10n.chatShareFallbackSubject,
          ),
        ),
      );
      _clearMultiSelection();
    });
  }

  void _forwardSelectedMessages(List<Message> messages) {
    if (messages.length != 1) return;
    context.read<ChatBloc>().add(
      ChatMessageForwardRequested(message: messages.single),
    );
  }

  Future<void> _addSelectedToCalendar(List<Message> messages) async {
    final l10n = context.l10n;
    final calendarAvailable = context
        .read<CalendarStorageManager>()
        .isAuthStorageReady;
    final joined = joinedMessageText(messages).trim();
    if (joined.isEmpty) {
      _showSnackbar(l10n.chatAddToCalendarNoText);
      return;
    }
    if (!calendarAvailable) {
      _showSnackbar(l10n.chatCalendarUnavailable);
      return;
    }
    final calendarText = await pickCalendarSeed(joined);
    if (!mounted || calendarText == null) {
      return;
    }
    final locationHelper = LocationAutocompleteHelper.fromState(
      context.read<CalendarBloc>().state,
    );
    await showQuickAddModal(
      context: context,
      prefilledText: calendarText,
      locationHelper: locationHelper,
      locateCalendarBloc: () => context.read<CalendarBloc>(),
      onTaskAdded: (task, queuedCriticalPathIds) {
        context.read<CalendarBloc>().add(
          CalendarEvent.taskAdded(
            title: task.title,
            scheduledTime: task.scheduledTime,
            description: task.description,
            duration: task.duration,
            deadline: task.deadline,
            location: task.location,
            endDate: task.endDate,
            priority: task.priority ?? TaskPriority.none,
            recurrence: task.recurrence,
            queuedCriticalPathIds: queuedCriticalPathIds,
          ),
        );
      },
    );
    _clearMultiSelection();
  }

  void _showMessageDetailsById(String messageId) {
    final detailId = messageId.trim();
    if (detailId.isEmpty) return;
    context.read<ChatBloc>().add(ChatMessageFocused(detailId));
    _setChatRoute(ChatRouteIndex.details);
  }

  void _syncChatRoute() {
    if (!widget.syncWithOpenChatRoute) {
      return;
    }
    final storedRoute = context.read<ChatsCubit>().state.openChatRoute;
    final nextRoute = _resolvedStoredChatRoute(
      route: storedRoute,
      state: context.read<ChatBloc>().state,
    );
    if (nextRoute == _chatRoute) {
      if (nextRoute != storedRoute) {
        context.read<ChatsCubit>().setOpenChatRoute(route: nextRoute);
      }
      return;
    }
    _setChatRoute(nextRoute);
  }

  ChatRouteIndex _resolvedStoredChatRoute({
    required ChatRouteIndex route,
    required ChatState state,
  }) => resolveStoredChatRoute(
    route: route,
    hasChat: state.chat != null,
    hasFocusedMessage: state.focused != null,
  );

  void _handleChatRouteHistoryRemoved() {
    if (_chatRouteHistoryEntry == null) {
      return;
    }
    _chatRouteHistoryEntry = null;
    if (!mounted) {
      return;
    }
    if (_chatRoute.isMain) {
      return;
    }
    _setChatRoute(ChatRouteIndex.main);
  }

  void _handleChatCalendarCanHandleBackChanged(bool canHandleBack) {
    final nextCanHandleBack = _chatRoute.isCalendar && canHandleBack;
    if (_chatCalendarCanHandleBack == nextCanHandleBack) {
      return;
    }
    _chatCalendarCanHandleBack = nextCanHandleBack;
    if (!mounted) {
      return;
    }
    _updateChatRouteHistoryEntry();
  }

  void _clearChatRouteHistoryEntry() {
    final entry = _chatRouteHistoryEntry;
    _chatRouteHistoryEntry = null;
    entry?.remove();
  }

  void _updateChatRouteHistoryEntry() {
    if (!widget.syncWithOpenChatRoute) {
      _clearChatRouteHistoryEntry();
      return;
    }
    final route = ModalRoute.of(context);
    if (route == null) {
      _clearChatRouteHistoryEntry();
      return;
    }
    if (_chatRoute.isMain) {
      _clearChatRouteHistoryEntry();
      return;
    }
    if (_chatRoute.isCalendar && _chatCalendarCanHandleBack) {
      _clearChatRouteHistoryEntry();
      return;
    }
    if (_chatRouteHistoryEntry != null) {
      return;
    }
    final entry = LocalHistoryEntry(onRemove: _handleChatRouteHistoryRemoved);
    _chatRouteHistoryEntry = entry;
    route.addLocalHistoryEntry(entry);
  }

  void _setChatRoute(
    ChatRouteIndex nextRoute, {
    bool persistToNavigationSession = true,
  }) {
    if (!mounted) return;
    final bool leavingCalendar = _chatRoute.isCalendar && !nextRoute.isCalendar;
    if (!nextRoute.isCalendar && _chatCalendarCanHandleBack) {
      _chatCalendarCanHandleBack = false;
    }
    final bool wasSettings = _chatRoute.isSettings;
    setState(() {
      _previousChatRoute = _chatRoute;
      _chatRoute = nextRoute;
      _pinnedPanelVisible = false;
      if (_inlineComposerController.hasTextFocus) {
        _inlineComposerController.unfocus();
      }
    });
    if (!wasSettings && nextRoute.isSettings) {}
    if (leavingCalendar) {
      FocusScope.of(context).unfocus();
    }
    if (!nextRoute.isDetails) {
      if (context.read<SettingsCubit>().animationDuration == Duration.zero) {
        context.read<ChatBloc>().add(const ChatMessageFocused(null));
      } else {
        Future.delayed(context.read<SettingsCubit>().animationDuration, () {
          if (!mounted || _chatRoute.isDetails) return;
          context.read<ChatBloc>().add(const ChatMessageFocused(null));
        });
      }
    }
    if (!nextRoute.isSearch) {
      context.read<ChatSearchCubit>().setActive(false);
    }
    if (widget.syncWithOpenChatRoute && persistToNavigationSession) {
      context.read<ChatsCubit>().setOpenChatRoute(route: nextRoute);
    }
    _updateChatRouteHistoryEntry();
    _scheduleReadThresholdSync();
  }

  void _returnToMainRoute() {
    _setChatRoute(ChatRouteIndex.main);
  }

  void _openChatSearch() {
    if (!mounted) return;
    if (_chatRoute.isSearch) {
      return;
    }
    _setChatRoute(ChatRouteIndex.search);
  }

  void _openChatCalendar() {
    _setChatRoute(ChatRouteIndex.calendar);
  }

  void _openChatAttachments() {
    if (!mounted) return;
    final chat = context.read<ChatBloc>().state.chat;
    if (chat == null) return;
    if (_chatRoute.isGallery) {
      _setChatRoute(ChatRouteIndex.main);
      return;
    }
    _setChatRoute(ChatRouteIndex.gallery);
  }

  void _toggleImportantMessagesRoute() {
    if (!mounted) {
      return;
    }
    if (_chatRoute.isImportant) {
      _setChatRoute(ChatRouteIndex.main);
      return;
    }
    _setChatRoute(ChatRouteIndex.important);
  }

  void _handleImportantMessageSelected(String messageReferenceId) {
    _setChatRoute(ChatRouteIndex.main);
    context.read<ChatBloc>().add(
      ChatImportantMessageSelected(messageReferenceId),
    );
  }

  void _consumePendingOpenMessageSelection(ChatsState chatsState) {
    final requestId = chatsState.pendingOpenMessageRequestId;
    if (requestId == 0 || requestId == _handledPendingOpenMessageRequestId) {
      return;
    }
    final pendingChatJid = chatsState.pendingOpenMessageChatJid?.trim();
    final pendingReferenceId = chatsState.pendingOpenMessageReferenceId?.trim();
    final chatJid = context.read<ChatBloc>().state.chat?.jid.trim();
    if (pendingChatJid == null ||
        pendingChatJid.isEmpty ||
        pendingReferenceId == null ||
        pendingReferenceId.isEmpty ||
        chatJid == null ||
        chatJid.isEmpty ||
        pendingChatJid != chatJid) {
      return;
    }
    _handledPendingOpenMessageRequestId = requestId;
    context.read<ChatsCubit>().clearPendingOpenMessageSelection(
      requestId: requestId,
    );
    context.read<ChatBloc>().add(
      ChatImportantMessageSelected(pendingReferenceId),
    );
  }

  void _togglePinnedMessages() {
    if (!mounted) return;
    final bool isChatCalendarOpen = context
        .read<ChatsCubit>()
        .state
        .openChatCalendar;
    if (!_chatRoute.isMain || isChatCalendarOpen) {
      _returnToMainRoute();
    }
    setState(() {
      _pinnedPanelVisible = !_pinnedPanelVisible;
      if (_inlineComposerController.hasTextFocus) {
        _inlineComposerController.unfocus();
      }
    });
  }

  void _openPinnedMessages() {
    if (!mounted) return;
    final bool isChatCalendarOpen = context
        .read<ChatsCubit>()
        .state
        .openChatCalendar;
    if (!_chatRoute.isMain || isChatCalendarOpen) {
      _returnToMainRoute();
    }
    setState(() {
      _pinnedPanelVisible = true;
      if (_inlineComposerController.hasTextFocus) {
        _inlineComposerController.unfocus();
      }
    });
  }

  void _closeChatCalendar() {
    if (!mounted) return;
    _returnToMainRoute();
  }

  void _closePinnedMessages() {
    if (!mounted) return;
    setState(() {
      _pinnedPanelVisible = false;
    });
  }

  void _toggleQuickReaction(Message message, String emoji) {
    unawaited(_applyQuickReaction(message, emoji));
  }

  Future<void> _applyQuickReaction(Message message, String emoji) async {
    final chat = context.read<ChatBloc>().state.chat;
    if (chat == null) {
      return;
    }
    final currentMessage = _cachedMessageById[message.stanzaID] ?? message;
    if (!currentMessage.canSendXmppReaction(
      chatDefaultTransport: chat.defaultTransport,
    )) {
      return;
    }
    final nextReactions = _toggleReactionPreview(
      _reactionPreviewsForMessage(currentMessage),
      emoji: emoji,
    );
    setState(() {
      _pendingReactionPreviewsByMessageId[message.stanzaID] = (
        base: currentMessage.reactionsPreview,
        preview: nextReactions,
      );
    });
    final completer = Completer<bool>();
    context.read<ChatBloc>().add(
      ChatMessageReactionToggled(
        message: currentMessage,
        emoji: emoji,
        completer: completer,
      ),
    );
    final success = await completer.future;
    if (!mounted || success) {
      return;
    }
    setState(() {
      _pendingReactionPreviewsByMessageId.remove(message.stanzaID);
    });
  }

  Map<ComposerRecipientKey, FanOutRecipientState> _latestRecipientStatuses(
    ChatState state,
  ) {
    if (state.fanOutReports.isEmpty) {
      return const {};
    }
    final lastEntry = state.fanOutReports.entries.last.value;
    final statuses = <ComposerRecipientKey, FanOutRecipientState>{};
    for (final status in lastEntry.statuses) {
      statuses[status.recipientKey] = status.state;
    }
    return statuses;
  }

  List<chat_models.Chat> _participantsForBanner(
    ShareContext? context,
    String? chatJid,
    String? selfJid,
  ) {
    if (context == null) return const [];
    return context.participants.where((chat_models.Chat participant) {
      final jid = participant.jid;
      if (chatJid != null && jid == chatJid) return false;
      if (selfJid != null && jid == selfJid) return false;
      return true;
    }).toList();
  }

  MapEntry<String, FanOutSendReport>? _lastReportEntryWhere(
    Iterable<MapEntry<String, FanOutSendReport>> entries,
    bool Function(MapEntry<String, FanOutSendReport> entry) predicate,
  ) {
    final ordered = entries.toList();
    for (var i = ordered.length - 1; i >= 0; i--) {
      final entry = ordered[i];
      if (predicate(entry)) {
        return entry;
      }
    }
    return null;
  }
}
