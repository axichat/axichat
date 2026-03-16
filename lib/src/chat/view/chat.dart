// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:axichat/src/avatar/avatar_presentation.dart';
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
import 'package:axichat/src/common/policy.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/axi_input.dart';
import 'package:axichat/src/common/ui/context_action_button.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/keyboard_pop_scope.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/common/unicode_safety.dart';
import 'package:axichat/src/common/url_safety.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/draft/bloc/compose_window_cubit.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/view/compose_draft_content.dart';
import 'package:axichat/src/email/models/fan_out_recipient_state.dart';
import 'package:axichat/src/email/models/fan_out_send_report.dart';
import 'package:axichat/src/email/models/share_context.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/util/delta_jids.dart';
import 'package:axichat/src/important/bloc/important_messages_cubit.dart';
import 'package:axichat/src/important/view/important_messages_list.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/chat/view/overlays/room_members_sheet.dart';
import 'package:axichat/src/xmpp/muc/occupant.dart';
import 'package:axichat/src/xmpp/muc/room_state.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
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
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'package:logging/logging.dart';
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

part 'overlays/forward_recipient_sheet.dart';

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

class Chat extends StatefulWidget {
  const Chat({super.key, this.readOnly = false});

  final bool readOnly;

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  static bool get _debugShowAllComposerBanners => kDebugMode && false;

  static bool get _debugCycleComposerBanners => kDebugMode && false;

  late final ShadPopoverController _emojiPopoverController;
  late final FocusNode _focusNode;
  late final TextEditingController _textController;
  late final TextEditingController _subjectController;
  late final FocusNode _subjectFocusNode;
  late final FocusNode _attachmentButtonFocusNode;
  late ScrollController _scrollController;
  bool _composerHasText = false;

  bool get _composerHasContent =>
      _composerHasText || _pendingCalendarTaskIcs != null;
  String _lastSubjectValue = '';
  bool _subjectChangeSuppressed = false;
  bool _collapseLongEmailMessages = false;
  List<ComposerRecipient> _recipients = const [];
  String? _recipientsChatJid;
  int? _expandedComposerDraftId;
  bool _expandingComposerDraft = false;
  ComposeDraftSeed? _expandedComposerSeed;
  ChatCalendarSyncCoordinator? _fallbackChatCalendarCoordinator;
  final _oneTimeAllowedAttachmentStanzaIds = <String>{};
  final _loadedEmailImageMessageIds = <String>{};
  final _inlineEmailBodyOverrideMessageIds = <String>{};
  final _animatedMessageIds = <String>{};
  var _hydratedAnimatedMessages = false;
  static final Map<String, double> _scrollOffsetCache = {};
  String? _lastScrollStorageKey;

  var _chatRoute = ChatRouteIndex.main;
  var _previousChatRoute = ChatRouteIndex.main;
  LocalHistoryEntry? _chatRouteHistoryEntry;
  bool _pinnedPanelVisible = false;
  String? _selectedMessageId;
  final _multiSelectedMessageIds = <String>{};
  final _selectedMessageSnapshots = <String, Message>{};
  final _pendingReactionPreviewsByMessageId =
      <String, ({List<ReactionPreview> base, List<ReactionPreview> preview})>{};
  final _messageKeys = <String, GlobalKey>{};
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
  Map<String, Message> _cachedMessageById = const {};
  List<Message> _cachedFilteredItems = const [];
  final _bubbleWidthByMessageId = <String, double>{};
  final _bubbleRegionRegistry = _BubbleRegionRegistry();
  final _messageListKey = GlobalKey();
  Set<String> _reportedReadThresholdMessageIds = const <String>{};
  var _readThresholdSyncScheduled = false;
  final Object _composerTapRegionGroup = Object();
  final Object _selectionTapRegionGroup = Object();
  double _bottomSectionHeight = 0.0;
  int? _outsideTapPointer;
  Offset? _outsideTapStart;
  var _sendingAttachment = false;
  RequestStatus _shareRequestStatus = RequestStatus.none;
  static const CalendarChatSupport _calendarFragmentPolicy =
      CalendarChatSupport();
  CalendarTask? _pendingCalendarTaskIcs;
  String? _pendingCalendarSeedText;
  final Map<String, Completer<Object?>> _pendingCalendarImportCompleters =
      <String, Completer<Object?>>{};
  int _handledCalendarImportOutcomeToken = 0;
  Message? _quotedDraft;
  List<PendingAttachment> _pendingAttachments = const [];
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
    _focusNode.unfocus();
    _subjectFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
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

  bool _usesAlternateInlineEmailBody(String messageId) {
    final normalizedMessageId = messageId.trim();
    if (normalizedMessageId.isEmpty) {
      return false;
    }
    return _inlineEmailBodyOverrideMessageIds.contains(normalizedMessageId);
  }

  void _toggleInlineEmailBody(String messageId) {
    final normalizedMessageId = messageId.trim();
    if (normalizedMessageId.isEmpty) {
      return;
    }
    setState(() {
      if (!_inlineEmailBodyOverrideMessageIds.add(normalizedMessageId)) {
        _inlineEmailBodyOverrideMessageIds.remove(normalizedMessageId);
      }
    });
  }

  ({
    List<InlineSpan> details,
    Map<int, DynamicInlineDetailAction> detailActions,
    Map<int, double> detailOpticalOffsetFactors,
  })
  _emailInlineDetailActionData({
    required BuildContext context,
    required List<InlineSpan> details,
    required Map<int, double> detailOpticalOffsetFactors,
    required bool enabled,
    required String label,
    required VoidCallback onTap,
  }) {
    if (!enabled) {
      return (
        details: details,
        detailActions: const <int, DynamicInlineDetailAction>{},
        detailOpticalOffsetFactors: detailOpticalOffsetFactors,
      );
    }
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final actionTextStyle = context.textTheme.small.copyWith(
      color: colors.secondaryForeground,
      fontSize: 11.0,
      height: 1.0,
      fontWeight: FontWeight.w600,
      textBaseline: TextBaseline.alphabetic,
    );
    final actionIndex = details.length;
    return (
      details: <InlineSpan>[
        ...details,
        TextSpan(text: label, style: actionTextStyle),
      ],
      detailActions: <int, DynamicInlineDetailAction>{
        actionIndex: DynamicInlineDetailAction(
          onTap: onTap,
          backgroundColor: colors.secondary,
          borderRadius: context.radii.squircleSm,
          padding: EdgeInsets.symmetric(
            horizontal: spacing.xs,
            vertical: spacing.xxs,
          ),
          minimumHeight:
              (actionTextStyle.fontSize ?? spacing.s) +
              spacing.xs +
              (context.borderSide.width * 2),
        ),
      },
      detailOpticalOffsetFactors: detailOpticalOffsetFactors,
    );
  }

  void _typingListener() {
    final text = _textController.text;
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
      });
    }
    _maybeClearPendingCalendarTaskIcs(text);
    if (!context.read<SettingsCubit>().state.indicateTyping) return;
    if (!hasText) return;
    final chat = context.read<ChatBloc>().state.chat;
    if (chat == null) return;
    context.read<ChatBloc>().add(ChatTypingStarted(chat: chat));
  }

  void _resetRecipientsForChat(chat_models.Chat? chat) {
    final jid = chat?.jid;
    if (jid == _recipientsChatJid) {
      return;
    }
    _recipientsChatJid = jid;
    if (chat == null) {
      _recipients = const [];
    } else {
      _recipients = [
        ComposerRecipient(
          target: Contact.chat(
            chat: chat,
            shareSignatureEnabled:
                chat.shareSignatureEnabled ??
                context.read<SettingsCubit>().state.shareTokenSignatureEnabled,
          ),
          included: true,
          pinned: true,
        ),
      ];
    }
    if (!mounted) return;
    setState(() {});
    _syncEmailComposerWatermark(chatState: context.read<ChatBloc>().state);
  }

  void _handleRecipientAdded(Contact target) {
    final address = target.resolvedAddress;
    if (target.needsTransportSelection &&
        address != null &&
        address.isNotEmpty) {
      _resolveAddressTransport(address).then((transport) {
        if (!mounted || transport == null) return;
        _applyRecipient(target.withTransport(transport));
      });
      return;
    }
    _applyRecipient(target);
  }

  void _applyRecipient(Contact target) {
    final index = _recipients.indexWhere((recipient) {
      return recipient.key == target.key;
    });
    if (index >= 0) {
      final recipient = _recipients[index];
      final updated = List<ComposerRecipient>.from(_recipients)
        ..[index] = recipient.withTarget(target).withIncluded(true);
      setState(() {
        _recipients = updated;
      });
      _syncEmailComposerWatermark(chatState: context.read<ChatBloc>().state);
      return;
    }
    setState(() {
      _recipients = [
        ..._recipients,
        ComposerRecipient(target: target, included: true),
      ];
    });
    _syncEmailComposerWatermark(chatState: context.read<ChatBloc>().state);
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
    final hinted = hintTransportForAddress(address);
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
    });
    _syncEmailComposerWatermark(chatState: context.read<ChatBloc>().state);
  }

  void _handleRecipientToggled(String key) {
    final index = _recipients.indexWhere((recipient) {
      return recipient.key == key;
    });
    if (index == -1) return;
    final current = _recipients[index];
    if (current.isPinned) return;
    final updated = List<ComposerRecipient>.from(_recipients)
      ..[index] = current.toggledIncluded();
    setState(() {
      _recipients = updated;
    });
    _syncEmailComposerWatermark(chatState: context.read<ChatBloc>().state);
  }

  void _handleRecipientAddedFromChat(chat_models.Chat chat) {
    _handleRecipientAdded(
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
    if (text.trim() == seedText) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _pendingCalendarTaskIcs = null;
      _pendingCalendarSeedText = null;
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

  void _appendTaskShareText(CalendarTask task, {String? shareText}) {
    final String resolvedShareText =
        shareText ?? task.toShareText(context.l10n);
    final String existing = _textController.text;
    final String separator = existing.trim().isEmpty
        ? _emptyText
        : _composerShareSeparator;
    final String nextText = '$existing$separator$resolvedShareText';
    _textController.value = _textController.value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
      composing: TextRange.empty,
    );
    _focusNode.requestFocus();
  }

  _CalendarTaskShare? _resolveCalendarTaskShare(CalendarTask task) {
    if (context.read<ChatBloc>().state.chat == null) {
      return null;
    }
    final decision = _calendarFragmentPolicy.decisionForChat(
      chat: context.read<ChatBloc>().state.chat!,
      roomState: context.read<ChatBloc>().state.roomState,
    );
    final String shareText = task.toShareText(context.l10n).trim();
    final bool canShareIcs =
        decision.canWrite ||
        context.read<ChatBloc>().state.chat!.defaultTransport.isEmail;
    if (!canShareIcs) {
      _showSnackbar(context.l10n.chatCalendarFragmentShareDeniedMessage);
      return _CalendarTaskShare(task: null, text: shareText);
    }
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
          _pendingCalendarSeedText = null;
        });
      }
      _appendTaskShareText(payload.snapshot, shareText: share.text);
      return;
    }
    if (!mounted) return;
    setState(() {
      _pendingCalendarTaskIcs = share.task;
      _pendingCalendarSeedText = share.text;
    });
    _appendTaskShareText(payload.snapshot, shareText: share.text);
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
        requestId: const Uuid().v4(),
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
    if (context.read<ChatBloc>().state.chat == null ||
        !context.read<ChatBloc>().state.chat!.supportsChatCalendar) {
      _showSnackbar(l10n.chatAvailabilityRequestChatCalendarUnavailableMessage);
      return;
    }
    final storageManager = context.read<CalendarStorageManager>();
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
    final String requestId = const Uuid().v4();
    final Completer<Object?> completer = Completer<Object?>();
    _pendingCalendarImportCompleters[requestId] = completer;
    context.read<CalendarBloc>().add(
      CalendarEvent.tasksImported(
        requestId: requestId,
        tasks: <CalendarTask>[task],
      ),
    );
    final Object? result = await completer.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        _pendingCalendarImportCompleters.remove(requestId);
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
    final String requestId = const Uuid().v4();
    final Completer<Object?> completer = Completer<Object?>();
    _pendingCalendarImportCompleters[requestId] = completer;
    context.read<CalendarBloc>().add(
      CalendarEvent.modelImported(requestId: requestId, model: model),
    );
    final Object? result = await completer.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        _pendingCalendarImportCompleters.remove(requestId);
        return null;
      },
    );
    return result is bool ? result : false;
  }

  void _handleCalendarImportStateChanged(BuildContext _, CalendarState state) {
    if (state.importOutcomeToken == _handledCalendarImportOutcomeToken) {
      return;
    }
    _handledCalendarImportOutcomeToken = state.importOutcomeToken;
    final String? requestId = state.importRequestId;
    if (requestId == null) {
      return;
    }
    final Completer<Object?>? completer = _pendingCalendarImportCompleters
        .remove(requestId);
    if (completer == null || completer.isCompleted) {
      return;
    }
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

  KeyEventResult _handleSubjectKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.tab &&
        !_isShiftPressed(event) &&
        mounted) {
      _focusNode.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleComposerKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.tab && mounted) {
      if (_isShiftPressed(event)) {
        _subjectFocusNode.requestFocus();
      } else {
        final attachmentCanFocus = _attachmentButtonFocusNode.canRequestFocus;
        if (attachmentCanFocus) {
          _attachmentButtonFocusNode.requestFocus();
        } else {
          FocusScope.of(context).nextFocus();
        }
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool _isShiftPressed(KeyEvent event) {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
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

  bool _usesBubbleReadThreshold(ChatState state) {
    if ((state.chat?.isEmailBacked ?? false) ||
        (state.chat?.defaultTransport.isEmail ?? false)) {
      return true;
    }
    return state.items.any((message) => message.isEmailBacked);
  }

  Set<String> _readThresholdMessageIds(ChatState state) {
    if (!state.messagesLoaded ||
        !_chatRoute.allowsChatInteraction ||
        !_usesBubbleReadThreshold(state)) {
      return const <String>{};
    }
    final viewportRect = _messageListViewportRect();
    if (viewportRect == null) {
      return const <String>{};
    }
    final messageIds = <String>{};
    for (final message in state.items) {
      if (!message.isEmailBacked) {
        continue;
      }
      final messageId = message.stanzaID.trim();
      if (messageId.isEmpty) {
        continue;
      }
      final bubbleRect = _bubbleRegionRegistry.rectFor(messageId);
      if (bubbleRect == null || bubbleRect.height <= 0) {
        continue;
      }
      // The side indicator sits halfway down the bubble edge, so wait until it
      // has entered the viewport before clearing read state.
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
    final nextIds = _readThresholdMessageIds(chatState);
    if (nextIds.length == _reportedReadThresholdMessageIds.length &&
        nextIds.containsAll(_reportedReadThresholdMessageIds)) {
      return;
    }
    _reportedReadThresholdMessageIds = nextIds;
    final messageIds = nextIds.toList(growable: false)..sort();
    context.read<ChatBloc>().add(ChatReadThresholdChanged(messageIds));
  }

  void _requestReadOnTap(Message message) {
    final messageId = message.stanzaID.trim();
    if (messageId.isEmpty) {
      return;
    }
    context.read<ChatBloc>().add(ChatMessageReadRequested(messageId));
  }

  void _scheduleReadThresholdSync() {
    if (!mounted || _readThresholdSyncScheduled) {
      return;
    }
    _readThresholdSyncScheduled = true;
    WidgetsBinding.instance.endOfFrame.then((_) {
      _readThresholdSyncScheduled = false;
      if (!mounted) {
        return;
      }
      _syncReadThresholdIds();
    });
  }

  void _restoreScrollOffsetForCurrentChat() {
    final target = _restoreScrollOffset();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    required String? fallbackSelfNick,
    required String? currentUserId,
  }) {
    if (isGroupChat) {
      return isMucSelfMessage(
        senderJid: quotedMessage.senderJid,
        roomState: roomState,
        fallbackSelfNick: fallbackSelfNick,
      );
    }
    return quotedMessage.isFromAuthorizedJid(currentUserId);
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
    required bool inviteRevoked,
    required bool isInviteRevocationMessage,
    required Message messageModel,
    required RoomState? roomState,
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
    final inviteActionEnabled = !inviteRevoked && !isInviteRevocationMessage;
    final inviteCardLabel = inviteRoomName.isNotEmpty
        ? inviteRoomName
        : inviteRoom.isNotEmpty
        ? inviteRoom
        : inviteLabel;
    final inviteCardDetail = inviteRoom.isNotEmpty ? inviteRoom : inviteLabel;
    final inviteCardShape = _attachmentSurfaceShape(
      context: context,
      isSelf: isSelfBubble,
      chainedPrevious: bubbleTextChildren.isNotEmpty,
      chainedNext: false,
    );
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
    addExtra(
      _InviteAttachmentCard(
        shape: inviteCardShape,
        enabled: inviteActionEnabled,
        label: inviteCardLabel,
        detailLabel: inviteCardDetail,
        actionLabel: inviteActionLabel,
        onPressed: () => _handleInviteTap(
          messageModel,
          roomState: roomState,
          selfJid: selfXmppJid,
        ),
      ),
      shape: inviteCardShape,
      spacing: context.spacing.s,
    );
  }

  void _appendAttachmentBubbleExtras({
    required BuildContext context,
    required List<String> attachmentIds,
    required bool hasBubbleAnchor,
    required bool isSelfBubble,
    required bool isEmailChat,
    required bool attachmentsBlockedForChat,
    required Message messageModel,
    required ChatState state,
    required Object bubbleContentKey,
    required _MessageBubbleExtraAdder addExtra,
  }) {
    final allowAttachmentByTrust = _shouldAllowAttachment(
      isSelf: isSelfBubble,
      chat: state.chat,
    );
    final allowAttachmentOnce = attachmentsBlockedForChat
        ? false
        : _isOneTimeAttachmentAllowed(messageModel.stanzaID);
    final allowAttachment =
        !attachmentsBlockedForChat &&
        (allowAttachmentByTrust || allowAttachmentOnce);
    final emailDownloadDelegate = isEmailChat
        ? AttachmentDownloadDelegate(() async {
            await context.read<ChatBloc>().downloadFullEmailMessage(
              messageModel,
            );
            return true;
          })
        : null;
    for (var index = 0; index < attachmentIds.length; index += 1) {
      final attachmentId = attachmentIds[index];
      final downloadDelegate = isEmailChat
          ? emailDownloadDelegate
          : AttachmentDownloadDelegate(
              () => context.read<ChatBloc>().downloadInboundAttachment(
                metadataId: attachmentId,
                stanzaId: messageModel.stanzaID,
              ),
            );
      final metadataReloadDelegate = AttachmentMetadataReloadDelegate(
        () => context.read<ChatBloc>().reloadFileMetadata(attachmentId),
      );
      final hasAttachmentAbove = index > 0 || hasBubbleAnchor;
      final hasAttachmentBelow = index < attachmentIds.length - 1;
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
          metadata: _metadataFor(state: state, metadataId: attachmentId),
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
        ),
        shape: attachmentShape,
        spacing: context.spacing.s,
        key: ValueKey<String>(
          '$bubbleContentKey-attachment-extra-$attachmentId',
        ),
      );
    }
  }

  void _appendAttachmentCaptionBubbleContent({
    required BuildContext context,
    required ChatState state,
    required String metadataId,
    required Object bubbleContentKey,
    required TextStyle baseTextStyle,
    required List<InlineSpan> messageDetails,
    required Map<int, double> detailOpticalOffsetFactors,
    required List<Widget> bubbleTextChildren,
  }) {
    final metadata = _metadataFor(state: state, metadataId: metadataId);
    final filename = metadata?.filename.trim() ?? _emptyText;
    final displayFilename = filename.isNotEmpty
        ? filename
        : context.l10n.chatAttachmentFallbackLabel;
    final sizeBytes = metadata?.sizeBytes;
    final sizeLabel = sizeBytes != null && sizeBytes > 0
        ? formatBytes(sizeBytes, context.l10n)
        : context.l10n.chatAttachmentUnknownSize;
    final caption = context.l10n.chatAttachmentCaption(
      displayFilename,
      sizeLabel,
    );
    bubbleTextChildren.add(
      DynamicInlineText(
        key: ValueKey<Object>(bubbleContentKey),
        text: TextSpan(text: caption, style: baseTextStyle),
        details: messageDetails,
        detailOpticalOffsetFactors: detailOpticalOffsetFactors,
        onLinkTap: _handleLinkTap,
        onLinkLongPress: _handleLinkTap,
      ),
    );
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
    required bool isSelfBubble,
    required bool shouldShowViewFullEmailAction,
    required bool shouldShowEmailHtmlAction,
    required String collapsedEmailPreviewText,
    required String messageId,
    required Object bubbleContentKey,
    required TextStyle baseTextStyle,
    required List<InlineSpan> messageDetails,
    required Map<int, double> detailOpticalOffsetFactors,
    required List<Widget> bubbleTextChildren,
  }) {
    final l10n = context.l10n;
    final (
      :details,
      :detailActions,
      detailOpticalOffsetFactors: collapsedDetailOpticalOffsetFactors,
    ) = _emailInlineDetailActionData(
      context: context,
      details: messageDetails,
      detailOpticalOffsetFactors: detailOpticalOffsetFactors,
      enabled: shouldShowEmailHtmlAction,
      label: l10n.chatMessageViewHtmlAction,
      onTap: () => _toggleInlineEmailBody(messageId),
    );
    if (shouldShowViewFullEmailAction) {
      bubbleTextChildren.add(
        _MessageViewFullAction(
          self: isSelfBubble,
          label: l10n.chatMessageViewFullAction,
          onPressed: () => unawaited(_selectMessage(messageId)),
        ),
      );
    }
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
          details: details,
          detailActions: detailActions,
          detailOpticalOffsetFactors: collapsedDetailOpticalOffsetFactors,
        ),
      ),
    );
  }

  void _appendInlineEmailHtmlBubbleContent({
    required BuildContext context,
    required bool isSelfBubble,
    required bool isSingleSelection,
    required bool shouldShowEmailHtmlAction,
    required bool shouldShowViewFullEmailAction,
    required bool autoLoadEmailImages,
    required bool hasRemoteHtmlImages,
    required String normalizedHtmlBody,
    required String? normalizedHtmlText,
    required String messageId,
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
    final l10n = context.l10n;
    final shouldLoadImages =
        autoLoadEmailImages ||
        (messageDatabaseId != null &&
            _loadedEmailImageMessageIds.contains(messageDatabaseId));
    final onLoadRequested = messageDatabaseId == null
        ? null
        : () => _handleEmailImagesApproved(messageDatabaseId);
    final preparedHtmlBody = HtmlContentCodec.prepareEmailHtmlForFlutterHtml(
      normalizedHtmlBody,
      allowRemoteImages: shouldLoadImages,
    );
    final emailFallbackText = normalizedHtmlText?.isNotEmpty == true
        ? normalizedHtmlText
        : null;
    final shouldRenderHtmlBody = preparedHtmlBody.trim().isNotEmpty;
    final shouldUseSelectedInlineEmailWebView =
        isSingleSelection && shouldRenderHtmlBody;
    final shouldShowImageGallery = hasRemoteHtmlImages && shouldRenderHtmlBody;
    final (
      :details,
      :detailActions,
      detailOpticalOffsetFactors: htmlDetailOpticalOffsetFactors,
    ) = _emailInlineDetailActionData(
      context: context,
      details: messageDetails,
      detailOpticalOffsetFactors: detailOpticalOffsetFactors,
      enabled: shouldShowEmailHtmlAction && shouldRenderHtmlBody,
      label: l10n.chatMessageShowTextAction,
      onTap: () => _toggleInlineEmailBody(messageId),
    );
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
      if (shouldShowViewFullEmailAction &&
          !shouldUseSelectedInlineEmailWebView) {
        bubbleTextChildren.add(
          _MessageViewFullAction(
            self: isSelfBubble,
            label: l10n.chatMessageViewFullAction,
            onPressed: () => unawaited(_selectMessage(messageId)),
          ),
        );
      }
      final linkColor =
          linkStyle.color ??
          (isSelfBubble
              ? context.colorScheme.primaryForeground
              : context.colorScheme.primary);
      bubbleTextChildren.add(
        shouldUseSelectedInlineEmailWebView
            ? _MessageHtmlWebViewBody(
                key: ValueKey<String>('${bubbleContentKey}_webview'),
                html: normalizedHtmlBody,
                backgroundColor: bubbleColor,
                textColor: textColor,
                linkColor: linkColor,
                shouldLoadImages: shouldLoadImages,
                onLinkTap: _handleLinkTap,
              )
            : _MessageHtmlBody(
                key: ValueKey<Object>(bubbleContentKey),
                html: preparedHtmlBody,
                textStyle: baseTextStyle,
                textColor: textColor,
                linkColor: linkColor,
                shouldLoadImages: shouldLoadImages,
                onLinkTap: _handleLinkTap,
              ),
      );
    }
    if (shouldShowImageGallery &&
        !shouldLoadImages &&
        onLoadRequested != null) {
      bubbleTextChildren.add(
        Padding(
          padding: EdgeInsets.only(top: context.spacing.xs),
          child: EmailImagePlaceholder(onTap: onLoadRequested),
        ),
      );
    }
    bubbleTextChildren.add(
      Padding(
        padding: EdgeInsets.only(top: context.spacing.xs),
        child: ChatInlineDetails(
          details: details,
          detailActions: detailActions,
          detailOpticalOffsetFactors: htmlDetailOpticalOffsetFactors,
        ),
      ),
    );
  }

  void _appendTextBodyBubbleContent({
    required BuildContext context,
    required bool isSelfBubble,
    required bool shouldShowViewFullEmailAction,
    required bool shouldShowEmailHtmlAction,
    required String messageId,
    required Object bubbleContentKey,
    required String displayMessageText,
    required String trimmedDisplayMessageText,
    required TextStyle baseTextStyle,
    required TextStyle linkStyle,
    required List<InlineSpan> messageDetails,
    required Map<int, double> detailOpticalOffsetFactors,
    required List<Widget> bubbleTextChildren,
  }) {
    final l10n = context.l10n;
    final (
      :details,
      :detailActions,
      detailOpticalOffsetFactors: textDetailOpticalOffsetFactors,
    ) = _emailInlineDetailActionData(
      context: context,
      details: messageDetails,
      detailOpticalOffsetFactors: detailOpticalOffsetFactors,
      enabled: shouldShowEmailHtmlAction,
      label: l10n.chatMessageViewHtmlAction,
      onTap: () => _toggleInlineEmailBody(messageId),
    );
    if (shouldShowViewFullEmailAction) {
      bubbleTextChildren.add(
        _MessageViewFullAction(
          self: isSelfBubble,
          label: l10n.chatMessageViewFullAction,
          onPressed: () => unawaited(_selectMessage(messageId)),
        ),
      );
    }
    if (trimmedDisplayMessageText.isNotEmpty) {
      bubbleTextChildren.add(
        _ParsedMessageBody(
          contentKey: bubbleContentKey,
          text: displayMessageText,
          baseStyle: baseTextStyle,
          linkStyle: linkStyle,
          details: details,
          detailActions: detailActions,
          detailOpticalOffsetFactors: textDetailOpticalOffsetFactors,
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
          details: details,
          detailActions: detailActions,
          detailOpticalOffsetFactors: textDetailOpticalOffsetFactors,
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
      if (roomState == null) {
        return sameNormalizedAddressValue(currentActor, claimedJid);
      }
      return roomState.senderMatchesClaimedJid(
        senderJid: currentActor,
        claimedJid: claimedJid,
      );
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
      addExtra(fragmentCard, shape: calendarMessageCardShape);
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
    final messageText = isEmailMessage
        ? ChatSubjectCodec.previewBodyText(rawRenderedText)
        : rawRenderedText;
    final trimmedRenderedText = messageText.trim();
    final deltaMessageId = messageModel.deltaMsgId;
    final resolvedHtmlBody = isWelcomeChat
        ? null
        : timelineMessageItem.resolvedHtmlBody ??
              (deltaMessageId == null
                  ? messageModel.htmlBody
                  : state.emailFullHtmlByDeltaId[deltaMessageId] ??
                        messageModel.htmlBody);
    final normalizedHtmlBody = HtmlContentCodec.normalizeHtml(resolvedHtmlBody);
    final normalizedHtmlText = normalizedHtmlBody == null
        ? null
        : HtmlContentCodec.toPlainText(normalizedHtmlBody).trim();
    final displayMessageText = messageText;
    final trimmedDisplayMessageText = displayMessageText.trim();
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
    final metadataIdForCaption = attachmentIds.isNotEmpty
        ? attachmentIds.first
        : messageModel.fileMetadataID;
    final shouldRenderTextContent =
        !hideFragmentText && !hideAvailabilityText && !hideTaskText;
    final hasAttachmentCaption =
        shouldRenderTextContent &&
        trimmedDisplayMessageText.isEmpty &&
        metadataIdForCaption != null &&
        metadataIdForCaption.isNotEmpty;
    final fullEmailPreviewText = displayMessageText.trim().isNotEmpty
        ? displayMessageText.trim()
        : (normalizedHtmlText?.trim() ?? _emptyText);
    final hasRemoteHtmlImages =
        normalizedHtmlBody != null &&
        HtmlContentCodec.containsRemoteImages(normalizedHtmlBody);
    final collapsedEmailPreviewText = _collapsedEmailPreviewText(
      fullEmailPreviewText,
    );
    final shouldCollapseEmailPreview =
        _collapseLongEmailMessages &&
        isEmailMessage &&
        shouldRenderTextContent &&
        !hasAttachmentCaption &&
        !isSingleSelection &&
        collapsedEmailPreviewText.isNotEmpty &&
        collapsedEmailPreviewText != fullEmailPreviewText;
    final hasVisibleEmailText =
        trimmedDisplayMessageText.isNotEmpty || subjectText.isNotEmpty;
    final shouldPreferRichEmailHtml =
        isEmailMessage &&
        HtmlContentCodec.shouldRenderRichEmailHtml(
          normalizedHtmlBody: normalizedHtmlBody,
          normalizedHtmlText: normalizedHtmlText,
          renderedText: displayMessageText,
        );
    final hasEmailHtmlBody = isEmailMessage && normalizedHtmlBody != null;
    final usesAlternateInlineEmailBody = _usesAlternateInlineEmailBody(
      messageModel.stanzaID,
    );
    final defaultShowsInlineEmailHtmlBody =
        shouldRenderTextContent &&
        !hasAttachmentCaption &&
        hasEmailHtmlBody &&
        (!hasVisibleEmailText || shouldPreferRichEmailHtml);
    final shouldShowEmailHtmlAction =
        shouldRenderTextContent &&
        !hasAttachmentCaption &&
        hasEmailHtmlBody &&
        hasVisibleEmailText;
    final shouldRenderInlineEmailHtmlBody =
        hasEmailHtmlBody &&
        shouldRenderTextContent &&
        !hasAttachmentCaption &&
        (defaultShowsInlineEmailHtmlBody
            ? !usesAlternateInlineEmailBody
            : usesAlternateInlineEmailBody);
    final shouldShowViewFullEmailAction =
        hasEmailHtmlBody &&
        shouldRenderTextContent &&
        !hasAttachmentCaption &&
        !isSingleSelection;
    final autoLoadEmailImages = context
        .watch<SettingsCubit>()
        .state
        .autoLoadEmailImages;
    if (hasAttachmentCaption) {
      _appendAttachmentCaptionBubbleContent(
        context: context,
        state: state,
        metadataId: metadataIdForCaption,
        bubbleContentKey: bubbleContentKey,
        baseTextStyle: baseTextStyle,
        messageDetails: messageDetails,
        detailOpticalOffsetFactors: detailOpticalOffsetFactors,
        bubbleTextChildren: bubbleTextChildren,
      );
    } else if (shouldCollapseEmailPreview) {
      _appendCollapsedEmailPreviewBubbleContent(
        context: context,
        isSelfBubble: isSelfBubble,
        shouldShowViewFullEmailAction: shouldShowViewFullEmailAction,
        shouldShowEmailHtmlAction: shouldShowEmailHtmlAction,
        collapsedEmailPreviewText: collapsedEmailPreviewText,
        messageId: messageModel.stanzaID,
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
        shouldShowEmailHtmlAction: shouldShowEmailHtmlAction,
        shouldShowViewFullEmailAction: shouldShowViewFullEmailAction,
        autoLoadEmailImages: autoLoadEmailImages,
        hasRemoteHtmlImages: hasRemoteHtmlImages,
        normalizedHtmlBody: normalizedHtmlBody,
        normalizedHtmlText: normalizedHtmlText,
        messageId: messageModel.stanzaID,
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
    } else if (shouldRenderTextContent) {
      _appendTextBodyBubbleContent(
        context: context,
        isSelfBubble: isSelfBubble,
        shouldShowViewFullEmailAction: shouldShowViewFullEmailAction,
        shouldShowEmailHtmlAction: shouldShowEmailHtmlAction,
        messageId: messageModel.stanzaID,
        bubbleContentKey: bubbleContentKey,
        displayMessageText: displayMessageText,
        trimmedDisplayMessageText: trimmedDisplayMessageText,
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
      ?pinnedDetail,
      ?importantDetail,
      ?verification,
      if (self) status,
    ];
    final detailOpticalOffsetFactors = isEmailMessage
        ? const <int, double>{1: 0.08}
        : const <int, double>{};
    final surfaceDetails = <InlineSpan>[
      surfaceTime,
      surfaceTransportDetail,
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
    final canReact =
        !isEmailChat &&
        (state.xmppCapabilities?.supportsFeature(mox.messageReactionsXmlns) ??
            false);
    final requiresMucReference = messageModel.awaitsMucReference(
      isGroupChat: isGroupChat,
      isEmailBacked: isEmailChat,
    );
    final loadingMucReference = messageModel.waitsForOwnMucReference(
      isGroupChat: isGroupChat,
      isEmailBacked: isEmailChat,
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
        inviteRevoked: inviteRevoked,
        isInviteRevocationMessage: isInviteRevocationMessage,
        messageModel: messageModel,
        roomState: state.roomState,
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
        isSelfBubble: self,
        isEmailChat: isEmailChat,
        attachmentsBlockedForChat: attachmentsBlockedForChat,
        messageModel: messageModel,
        state: state,
        bubbleContentKey: bubbleContentKey,
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
    setState(() {
      _quotedDraft = message;
    });
    _focusNode.requestFocus();
  }

  void _handleTimelineBubbleTap(
    Message message, {
    required bool showUnreadIndicator,
  }) {
    if (showUnreadIndicator) {
      _requestReadOnTap(message);
    }
    unawaited(_toggleMessageSelection(message));
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

  void _handleImportantToggleRequested(
    Message message, {
    required bool important,
    required chat_models.Chat? chat,
  }) {
    if (chat == null) {
      return;
    }
    context.read<ChatBloc>().add(
      ChatMessageImportantToggled(
        message: message,
        important: important,
        chat: chat,
      ),
    );
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

  void _toggleNotifications(bool enable) {
    final chat = context.read<ChatBloc>().state.chat;
    if (chat == null) {
      return;
    }
    context.read<ChatBloc>().add(ChatMuted(chatJid: chat.jid, muted: !enable));
  }

  void _showMembers({bool refreshMembership = true}) {
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
        return SafeArea(
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
                        onOpenDirectChat: (jid) {
                          final locate = context.read;
                          return locate<ChatsCubit>().openChat(jid: jid);
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

  Future<void> _handleAddContact() async {
    final chat = context.read<ChatBloc>().state.chat;
    if (chat == null) return;
    if (chat.remoteJid.trim().isEmpty) {
      return;
    }
    final l10n = context.l10n;
    final successLabel = chat.displayName.trim().isNotEmpty
        ? chat.displayName.trim()
        : chat.remoteJid.trim();
    context.read<ChatBloc>().add(
      ChatContactAddRequested(
        chat: chat,
        successMessage: l10n.rosterAddedToContacts(successLabel),
        failureMessage: l10n.attachmentGalleryRosterErrorTitle,
      ),
    );
  }

  void _handleSubjectChanged() {
    if (_subjectChangeSuppressed) {
      return;
    }
    final text = _subjectController.text;
    if (_lastSubjectValue == text) {
      return;
    }
    _lastSubjectValue = text;
    if (mounted) {
      setState(() {});
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
    required chat_models.Chat chat,
    required List<ComposerRecipient> recipients,
  }) {
    if (chat.defaultTransport.isEmail || chat.isEmailBacked) {
      return true;
    }
    return recipients.hasEmailRecipients(allowHint: true);
  }

  bool _hasIncludedEmailRecipient(List<ComposerRecipient> recipients) =>
      recipients.includedRecipients.hasEmailRecipients(allowHint: true);

  bool _isEmailComposerActive({
    required ChatState chatState,
    List<ComposerRecipient>? recipients,
  }) {
    if ((chatState.chat?.isEmailBacked ?? false) ||
        (chatState.chat?.defaultTransport.isEmail ?? false)) {
      return true;
    }
    return _hasIncludedEmailRecipient(recipients ?? _recipients);
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
    final isEmailComposer = _isEmailComposerActive(chatState: chatState);
    if (!isEmailComposer || !settingsState.emailComposerWatermarkEnabled) {
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
    final currentText = _textController.text;
    final watermarkLabel = _emailComposerWatermarkLabel();
    final watermarkSuffix = _emailComposerWatermarkSuffix();
    final legacyWatermarkSuffix = _legacyEmailComposerWatermarkSuffix();
    final isEmailComposer = _isEmailComposerActive(chatState: chatState);
    if (_isDemoModeActive()) {
      return;
    }
    if (!isEmailComposer || !settingsState.emailComposerWatermarkEnabled) {
      if (currentText == watermarkLabel ||
          currentText == watermarkSuffix ||
          currentText == legacyWatermarkSuffix) {
        _textController.value = _textController.value.copyWith(
          text: _emptyText,
          selection: const TextSelection.collapsed(offset: 0),
          composing: TextRange.empty,
        );
      }
      return;
    }
    if (currentText == legacyWatermarkSuffix) {
      _textController.value = _textController.value.copyWith(
        text: watermarkSuffix,
        selection: const TextSelection.collapsed(offset: 0),
        composing: TextRange.empty,
      );
      return;
    }
    if (currentText == watermarkSuffix) {
      return;
    }
    if (currentText == watermarkLabel) {
      _textController.value = _textController.value.copyWith(
        text: watermarkSuffix,
        selection: const TextSelection.collapsed(offset: 0),
        composing: TextRange.empty,
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
        final selection = _textController.selection;
        final normalizedOffset = selection.isValid
            ? math.min(selection.extentOffset, normalizedWithWatermark.length)
            : normalizedWithWatermark.length;
        _textController.value = _textController.value.copyWith(
          text: normalizedWithWatermark,
          selection: TextSelection.collapsed(offset: normalizedOffset),
          composing: TextRange.empty,
        );
        return;
      }
      final selection = _textController.selection;
      final watermarkOffset = forceInsert
          ? currentText.length
          : (selection.isValid
                ? selection.extentOffset.clamp(0, currentText.length).toInt()
                : currentText.length);
      _textController.value = _textController.value.copyWith(
        text: '$currentText$watermarkSuffix',
        selection: TextSelection.collapsed(offset: watermarkOffset),
        composing: TextRange.empty,
      );
      return;
    }
    _textController.value = _textController.value.copyWith(
      text: watermarkSuffix,
      selection: const TextSelection.collapsed(offset: 0),
      composing: TextRange.empty,
    );
  }

  bool _resolveComposerSendOnEnter({
    required List<ComposerRecipient> recipients,
    required SettingsState settings,
  }) {
    final includedRecipients = recipients.includedRecipients;
    final hasEmail = includedRecipients.hasEmailRecipients();
    final hasXmpp = includedRecipients.hasXmppRecipients();
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
    if (chat.isEmailBacked) {
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
    if (chat.isEmailBacked) {
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
  }) {
    if (isSelf) return true;
    if (chat == null) return false;
    return (chat.attachmentAutoDownload ??
            context
                .watch<SettingsCubit>()
                .state
                .defaultChatAttachmentAutoDownload)
        .isAllowed;
  }

  bool _isOneTimeAttachmentAllowed(String stanzaId) {
    final trimmed = stanzaId.trim();
    if (trimmed.isEmpty) return false;
    return _oneTimeAllowedAttachmentStanzaIds.contains(trimmed);
  }

  Future<void> _approveAttachment({
    required Message message,
    required String senderJid,
    required String stanzaId,
    required bool isSelf,
    required bool isEmailChat,
    String? senderEmail,
  }) async {
    if (!mounted) return;
    final l10n = context.l10n;
    final displaySender = senderEmail?.isNotEmpty == true
        ? senderEmail!
        : senderJid;
    final canTrustChat = !isSelf && context.read<ChatBloc>().state.chat != null;
    final showAutoTrustToggle = canTrustChat;
    final autoTrustLabel = l10n.attachmentGalleryChatTrustLabel;
    final autoTrustHint = l10n.attachmentGalleryChatTrustHint;
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
          autoTrustLabel: autoTrustLabel,
          autoTrustHint: autoTrustHint,
        );
      },
    );
    if (!mounted) return;
    if (decision == null || !decision.approved) return;

    if (decision.alwaysAllow && canTrustChat) {
      final chat = context.read<ChatBloc>().state.chat;
      if (chat != null) {
        context.read<ChatBloc>().add(
          ChatAttachmentAutoDownloadToggled(chat: chat, enabled: true),
        );
      }
    }

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
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

  void _markPendingAttachmentsUploading(Iterable<String> ids) {
    final resolvedIds = ids.toSet();
    if (resolvedIds.isEmpty) {
      return;
    }
    setState(() {
      final updated = List<PendingAttachment>.from(_pendingAttachments);
      for (var index = 0; index < updated.length; index += 1) {
        final pending = updated[index];
        if (!resolvedIds.contains(pending.id) || pending.isPreparing) {
          continue;
        }
        updated[index] = pending.copyWith(
          status: PendingAttachmentStatus.uploading,
          clearErrorMessage: true,
        );
      }
      _pendingAttachments = updated;
    });
  }

  Future<void> _handleSendMessage({
    required ChatState chatState,
    required ChatSettingsSnapshot settingsSnapshot,
  }) async {
    final l10n = context.l10n;
    final rawComposerText = _textController.text;
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
    final bool hasSubject = _subjectController.text.trim().isNotEmpty;
    final bool hasCalendarTask = _pendingCalendarTaskIcs != null;
    final canSend =
        !hasPreparingAttachments &&
        (resolvedText.isNotEmpty ||
            hasQueuedAttachments ||
            hasSubject ||
            hasCalendarTask);
    if (!canSend) return;
    final confirmed = await _confirmMediaMetadataIfNeeded(queuedAttachments);
    if (!confirmed || !mounted) return;
    final chat = chatState.chat;
    if (chat == null) {
      return;
    }
    final shouldSend = await _confirmEmailSendIfNeeded(
      chatState: chatState,
      chat: chat,
      body: resolvedText,
      attachmentNames: queuedAttachments
          .map((pending) => pending.attachment.fileName)
          .toList(growable: false),
    );
    if (!shouldSend || !mounted) {
      return;
    }
    final calendarTaskShareText = _pendingCalendarTaskIcs?.toShareText(l10n);
    final chatJid = chat.jid;
    final completer = Completer<List<PendingAttachment>>();
    if (queuedAttachments.isNotEmpty) {
      _markPendingAttachmentsUploading(
        queuedAttachments.map((pending) => pending.id),
      );
    }
    context.read<ChatBloc>().add(
      ChatMessageSent(
        chat: chat,
        text: resolvedText,
        recipients: _recipients,
        pendingAttachments: pendingAttachments,
        settings: settingsSnapshot,
        supportsHttpFileUpload: chatState.supportsHttpFileUpload,
        attachmentFallbackLabel: l10n.chatAttachmentFallbackLabel,
        subject: _subjectController.text,
        quotedDraft: _quotedDraft,
        roomState: chatState.roomState,
        calendarTaskIcs: _pendingCalendarTaskIcs,
        calendarTaskIcsReadOnly: _calendarTaskIcsReadOnlyFallback,
        calendarTaskShareText: calendarTaskShareText,
        completer: completer,
      ),
    );
    final updatedAttachments = await completer.future;
    if (!mounted || context.read<ChatBloc>().state.chat?.jid != chatJid) {
      return;
    }
    setState(() {
      _pendingAttachments = updatedAttachments;
    });
  }

  Future<bool> _confirmEmailSendIfNeeded({
    required ChatState chatState,
    required chat_models.Chat chat,
    required String body,
    required List<String> attachmentNames,
  }) async {
    if (!_isEmailComposerActive(
      chatState: chatState,
      recipients: _recipients,
    )) {
      return true;
    }
    final settingsCubit = context.read<SettingsCubit>();
    if (!settingsCubit.state.emailSendConfirmationEnabled) {
      return true;
    }
    final recipients = _resolveDraftRecipients(
      chat: chat,
      recipients: _recipients,
    );
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

  Future<bool> _confirmMediaMetadataIfNeeded(
    List<PendingAttachment> attachments,
  ) async {
    if (!mounted) return false;
    final hasMedia = attachments.any(
      (attachment) =>
          attachment.attachment.isImage || attachment.attachment.isVideo,
    );
    if (!hasMedia) {
      return true;
    }
    final l10n = context.l10n;
    final approved = await confirm(
      context,
      title: l10n.chatMediaMetadataWarningTitle,
      message: l10n.chatMediaMetadataWarningMessage,
      confirmLabel: l10n.commonContinue,
      cancelLabel: l10n.commonCancel,
      destructiveConfirm: false,
    );
    return approved == true;
  }

  Future<void> _handleSendButtonLongPress() async {
    if (widget.readOnly) return;
    final approved = await confirm(
      context,
      title: context.l10n.commonActions,
      message: '',
      confirmLabel: context.l10n.chatSaveAsDraft,
      cancelLabel: context.l10n.commonCancel,
      destructiveConfirm: false,
    );
    if (!mounted || approved != true) return;
    await _saveComposerAsDraft();
  }

  Future<void> _saveComposerAsDraft() async {
    final l10n = context.l10n;
    final chatState = context.read<ChatBloc>().state;
    final chat = chatState.chat;
    if (chat == null) {
      _showSnackbar(l10n.chatDraftUnavailable);
      return;
    }
    final body = _normalizedInlineDraftBody(
      text: _textController.text,
      chatState: chatState,
    );
    final subject = _subjectController.text;
    final trimmedSubject = subject.trim();
    final attachments = _pendingAttachments
        .map((pending) => pending.attachment)
        .toList();
    final quotedReference = _quotedDraft?.replyReference(
      isGroupChat: chat.type == ChatType.groupChat,
    );
    final quoteTarget = DraftQuoteTarget.fromDraft(
      stanzaId: quotedReference?.value,
      referenceKind: quotedReference?.kind,
    );
    final recipients = _resolveDraftRecipients(
      chat: chat,
      recipients: _recipients,
    );
    final allowRecipientOnlyDraft = recipients.length - 1 > 0;
    if (body.trim().isEmpty && trimmedSubject.isEmpty && attachments.isEmpty) {
      if (!allowRecipientOnlyDraft) {
        _showSnackbar(l10n.chatDraftMissingContent);
        return;
      }
    }
    try {
      await context.read<DraftCubit>().saveDraft(
        id: null,
        jids: recipients,
        body: body,
        subject: trimmedSubject.isEmpty ? null : subject,
        quoteTarget: quoteTarget,
        attachments: attachments,
      );
      if (!mounted) return;
      _showSnackbar(l10n.chatDraftSaved);
    } catch (_) {
      if (!mounted) return;
      _showSnackbar(l10n.chatDraftSaveFailed);
    }
  }

  Future<void> _expandEmailComposerToDraft(ChatState chatState) async {
    if (_expandingComposerDraft) return;
    final chat = chatState.chat;
    if (chat == null) {
      _showSnackbar(context.l10n.chatDraftUnavailable);
      return;
    }
    final recipients = _resolveDraftRecipients(
      chat: chat,
      recipients: _recipients,
    );
    final attachments = _pendingAttachments
        .map((pending) => pending.attachment)
        .toList(growable: false);
    final quotedReference = _quotedDraft?.replyReference(
      isGroupChat: chat.type == ChatType.groupChat,
    );
    final quoteTarget = DraftQuoteTarget.fromDraft(
      stanzaId: quotedReference?.value,
      referenceKind: quotedReference?.kind,
    );
    final body = _normalizedInlineDraftBody(
      text: _textController.text,
      chatState: chatState,
    );
    final subject = _subjectController.text;
    final trimmedSubject = subject.trim();
    if (body.trim().isEmpty && trimmedSubject.isEmpty && attachments.isEmpty) {
      _dismissTextInputFocus();
      setState(() {
        _expandedComposerDraftId = null;
        _expandedComposerSeed = ComposeDraftSeed(
          id: null,
          jids: recipients,
          body: body,
          subject: subject,
          quoteTarget: quoteTarget,
          attachmentMetadataIds: const <String>[],
        );
      });
      return;
    }
    setState(() {
      _expandingComposerDraft = true;
    });
    try {
      final draft = await context.read<DraftCubit>().saveDraft(
        id: _expandedComposerDraftId,
        jids: recipients,
        body: body,
        subject: trimmedSubject.isEmpty ? null : subject,
        quoteTarget: quoteTarget,
        attachments: attachments,
      );
      if (!mounted) return;
      _dismissTextInputFocus();
      setState(() {
        _expandedComposerDraftId = draft.id;
        _expandedComposerSeed = ComposeDraftSeed(
          id: draft.id,
          jids: recipients,
          body: body,
          subject: subject,
          quoteTarget: quoteTarget,
          attachmentMetadataIds: draft.attachmentMetadata.values,
        );
      });
    } on Exception {
      if (!mounted) return;
      _showSnackbar(context.l10n.chatDraftSaveFailed);
    } finally {
      if (mounted) {
        setState(() {
          _expandingComposerDraft = false;
        });
      }
    }
  }

  void _collapseExpandedDraftComposer({required bool clearInlineComposer}) {
    final locate = context.read;
    if (!mounted) return;
    setState(() {
      _expandedComposerSeed = null;
      _expandingComposerDraft = false;
      if (clearInlineComposer) {
        _expandedComposerDraftId = null;
      }
    });
    if (!clearInlineComposer) {
      _focusNode.requestFocus();
      return;
    }
    _subjectChangeSuppressed = true;
    _subjectController.clear();
    _lastSubjectValue = _emptyText;
    _subjectChangeSuppressed = false;
    _textController.clear();
    _composerHasText = false;
    _pendingAttachments = const [];
    final chatState = locate<ChatBloc>().state;
    _syncEmailComposerWatermark(chatState: chatState, forceInsert: true);
  }

  List<String> _resolveDraftRecipients({
    required chat_models.Chat chat,
    required List<ComposerRecipient> recipients,
  }) => recipients.includedRecipients.recipientIds(fallbackJid: chat.jid);

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
    required bool attachmentsEnabled,
    required ChatState chatState,
    required ChatSettingsSnapshot settingsSnapshot,
  }) {
    final accessories = <ChatComposerAccessory>[
      ChatComposerAccessory.leading(
        child: FocusTraversalOrder(
          order: const NumericFocusOrder(3),
          child: _EmojiPickerAccessory(
            controller: _emojiPopoverController,
            textController: _textController,
          ),
        ),
      ),
      ChatComposerAccessory.leading(
        child: FocusTraversalOrder(
          order: const NumericFocusOrder(2),
          child: Focus(
            focusNode: _attachmentButtonFocusNode,
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
            onPressed: () => _handleSendMessage(
              chatState: chatState,
              settingsSnapshot: settingsSnapshot,
            ),
            onLongPress: widget.readOnly ? null : _handleSendButtonLongPress,
          ),
        ),
      ),
    ];
    return accessories;
  }

  Future<void> _handleAttachmentPressed(ChatState chatState) async {
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
      if (result == null || result.files.isEmpty || !mounted) {
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
      if (!mounted) return;
      final chat = chatState.chat;
      if (chat == null) {
        return;
      }
      final chatJid = chat.jid;
      for (final attachment in attachments) {
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
        });
        final completer = Completer<PendingAttachment?>();
        context.read<ChatBloc>().add(
          ChatAttachmentPicked(
            attachment: attachment,
            recipients: _recipients,
            chat: chat,
            quotedDraft: _quotedDraft,
            completer: completer,
          ),
        );
        final pending = await completer.future;
        if (!mounted || context.read<ChatBloc>().state.chat?.jid != chatJid) {
          return;
        }
        _replacePendingAttachment(placeholderId, replacement: pending);
      }
      if (_quotedDraft != null) {
        setState(() {
          _quotedDraft = null;
        });
      }
      _focusNode.requestFocus();
    } on PlatformException catch (error) {
      _showSnackbar(error.message ?? l10n.chatAttachmentFailed);
    } on Exception {
      _showSnackbar(l10n.chatAttachmentFailed);
    } finally {
      if (mounted) {
        setState(() {
          _sendingAttachment = false;
        });
      }
    }
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
        subject: _subjectController.text,
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
        final spacing = sheetContext.spacing;
        return BlocProvider.value(
          value: chatBloc,
          child: Builder(
            builder: (context) {
              return AxiSheetScaffold.scroll(
                header: AxiSheetHeader(
                  title: Text(l10n.chatAttachmentTooltip),
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
                  spacing.xs,
                  spacing.m,
                  spacing.m,
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

  void _ensureMessageCaches({
    required List<Message> items,
    required Map<String, Message> quotedMessagesById,
    required List<Message> searchResults,
    required bool searchFiltering,
    required Map<String, List<String>> attachmentsByMessageId,
    required Map<String, String> groupLeaderByMessageId,
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
    if (sameItems &&
        sameQuoted &&
        sameSearch &&
        sameSearchFiltering &&
        sameAttachments &&
        sameGroupLeaders) {
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
          final attachments = attachmentsForMessage(message);
          return message.body != null ||
              hasSubject ||
              hasHtml ||
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
    _cachedMessageById = messageById;
    _cachedFilteredItems = filteredItems;
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
    await _scrollSelectedMessageIntoView(messageId);
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

  Future<bool> _waitForMessageContext(String messageId) async {
    if (_messageKeys[messageId]?.currentContext != null) {
      return true;
    }
    for (var attempt = 0; attempt < 8; attempt += 1) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return false;
      }
      if (_messageKeys[messageId]?.currentContext != null) {
        return true;
      }
    }
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

  Future<bool> _prepareMessageContextForScroll(String messageId) async {
    if (await _waitForMessageContext(messageId)) {
      return true;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_scrollController.hasClients) {
      return false;
    }
    final position = _scrollController.position;
    if (!position.hasPixels) {
      return false;
    }
    final targetIndex = _displayedMessageIndex(messageId);
    if (targetIndex == null) {
      return false;
    }
    final maxScrollExtent = math.max(0.0, position.maxScrollExtent);
    final itemCount = _cachedFilteredItems.length;
    var lowerOffsetBound = 0.0;
    var upperOffsetBound = maxScrollExtent;
    final attemptedOffsets = <double>[];
    double clampOffset(double offset) {
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
      if (await _waitForMessageContext(messageId)) {
        return true;
      }
      if (!mounted || !_scrollController.hasClients) {
        return false;
      }
      final mountedRange = _mountedMessageIndexRange();
      double targetOffset;
      if (mountedRange == null) {
        targetOffset = itemCount <= 1
            ? _scrollController.offset
            : clampOffset(maxScrollExtent * (targetIndex / (itemCount - 1)));
      } else if (targetIndex > mountedRange.max) {
        lowerOffsetBound = math.max(lowerOffsetBound, _scrollController.offset);
        targetOffset = clampOffset((lowerOffsetBound + upperOffsetBound) / 2);
        if ((targetOffset - _scrollController.offset).abs() < 1) {
          targetOffset = upperOffsetBound;
        }
      } else if (targetIndex < mountedRange.min) {
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
        final upperCandidate = clampOffset(upperOffsetBound);
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
        continue;
      }
      _scrollController.jumpTo(targetOffset);
    }
    return _messageKeys[messageId]?.currentContext != null;
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
    _focusNode = FocusNode();
    _textController = TextEditingController();
    _subjectController = TextEditingController();
    _subjectFocusNode = FocusNode();
    _attachmentButtonFocusNode = FocusNode();
    _scrollController = ScrollController(
      initialScrollOffset: _restoreScrollOffset(),
    );
    _scrollController.addListener(_handleScrollChanged);
    _syncSelectionCaches(context.read<ChatBloc>().state, notify: false);
    _subjectFocusNode.onKeyEvent = _handleSubjectKeyEvent;
    _focusNode.onKeyEvent = _handleComposerKeyEvent;
    _textController.addListener(_typingListener);
    _subjectController.addListener(_handleSubjectChanged);
    _scheduleReadThresholdSync();
    final initialState = context.read<ChatBloc>().state;
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
    context.read<ChatBloc>().add(
      ChatSettingsUpdated(_settingsSnapshotFromState(settings)),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _consumePendingOpenMessageSelection(context.read<ChatsCubit>().state);
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
    _persistScrollOffset(key: _lastScrollStorageKey, skipPageStorage: true);
    _scrollController.dispose();
    _focusNode.dispose();
    _textController.removeListener(_typingListener);
    _textController.dispose();
    _subjectController.removeListener(_handleSubjectChanged);
    _subjectController.dispose();
    _subjectFocusNode.dispose();
    _attachmentButtonFocusNode.dispose();
    _emojiPopoverController.dispose();
    _bubbleRegionRegistry.clear();
    _clearChatRouteHistoryEntry();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatSearchCubit, ChatSearchState>(
      builder: (context, searchState) {
        final trimmedQuery = searchState.query.trim();
        final hasSubjectFilter = searchState.subjectFilter?.isNotEmpty == true;
        final searchFiltering =
            searchState.active && (trimmedQuery.isNotEmpty || hasSubjectFilter);
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
                  _openChatSearch();
                  return;
                }
                if (_chatRoute.isSearch) {
                  _returnToMainRoute();
                }
              },
            ),
            BlocListener<CalendarBloc, CalendarState>(
              listener: _handleCalendarImportStateChanged,
            ),
            BlocListener<ChatsCubit, ChatsState>(
              listenWhen: (previous, current) =>
                  previous.openChatRoute != current.openChatRoute,
              listener: (context, chatsState) {
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
                  previous.toastId != current.toastId && current.toast != null,
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
                  previous.scrollTargetRequestId !=
                      current.scrollTargetRequestId &&
                  current.scrollTargetMessageId != null,
              listener: (_, state) {
                final messageId = state.scrollTargetMessageId;
                if (messageId == null || messageId.trim().isEmpty) {
                  return;
                }
                unawaited(_handleScrollTargetRequest(messageId));
              },
            ),
            BlocListener<ChatBloc, ChatState>(
              listenWhen: (previous, current) =>
                  current.composerClearId != 0 &&
                  previous.composerClearId != current.composerClearId,
              listener: (_, _) {
                _textController.clear();
                _composerHasText = false;
                _quotedDraft = null;
                _subjectChangeSuppressed = true;
                _subjectController.clear();
                _lastSubjectValue = _emptyText;
                _subjectChangeSuppressed = false;
                _expandedComposerDraftId = null;
                _expandingComposerDraft = false;
                _expandedComposerSeed = null;
                if (_pendingCalendarTaskIcs != null ||
                    _pendingCalendarSeedText != null) {
                  setState(() {
                    _pendingCalendarTaskIcs = null;
                    _pendingCalendarSeedText = null;
                  });
                }
                _syncEmailComposerWatermark(
                  chatState: context.read<ChatBloc>().state,
                  forceInsert: true,
                );
                _focusNode.requestFocus();
              },
            ),
            BlocListener<ChatBloc, ChatState>(
              listenWhen: (previous, current) =>
                  previous.chat?.jid != current.chat?.jid,
              listener: (_, state) {
                _animatedMessageIds.clear();
                _hydratedAnimatedMessages = false;
                _textController.clear();
                _composerHasText = false;
                _quotedDraft = null;
                _pendingAttachments = const [];
                _subjectChangeSuppressed = true;
                _subjectController.clear();
                _lastSubjectValue = _emptyText;
                _subjectChangeSuppressed = false;
                _expandedComposerDraftId = null;
                _expandingComposerDraft = false;
                _expandedComposerSeed = null;
                if (_pendingCalendarTaskIcs != null ||
                    _pendingCalendarSeedText != null) {
                  _pendingCalendarTaskIcs = null;
                  _pendingCalendarSeedText = null;
                }
                _resetRecipientsForChat(state.chat);
                _syncEmailComposerWatermark(chatState: state);
                if (state.messagesLoaded) {
                  _hydrateAnimatedMessages(state.items);
                }
              },
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
                  previous.messagesLoaded != current.messagesLoaded,
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
              final subject = state.chat?.supportsEmail == true
                  ? (state.emailSubject ?? '')
                  : _emptyText;
              _subjectChangeSuppressed = true;
              _subjectController
                ..text = subject
                ..selection = TextSelection.collapsed(offset: subject.length);
              _lastSubjectValue = subject;
              _subjectChangeSuppressed = false;
              _textController
                ..text = text
                ..selection = TextSelection.collapsed(offset: text.length);
              _composerHasText =
                  _isEmailComposerWatermarkOnly(text: text, chatState: state)
                  ? false
                  : text.trim().isNotEmpty;
              _syncEmailComposerWatermark(chatState: state, forceInsert: true);
              if (!_focusNode.hasFocus) {
                _focusNode.requestFocus();
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
              final isWelcomeChat = chatEntity?.isAxichatWelcomeThread == true;
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
              final String? selfXmppJid = trimmedProfileJid?.isNotEmpty == true
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
              final String? selfAvatarPath = profileState()?.avatarPath?.trim();
              final myOccupantJid = state.roomState?.myOccupantJid;
              final myOccupant = state.roomState?.selfOccupant;
              final selfNick = (myOccupant?.nick ?? chatEntity?.myNickname)
                  ?.trim();
              final trimmedCurrentUserId = currentUserId.trim();
              final String? availabilityActorId = isGroupChat
                  ? state.roomState?.resolvedSelfJid(fallbackJid: currentUserId)
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
                    chat: chatEntity,
                    recipients: recipients,
                  );
              final attachmentsEnabled =
                  state.supportsHttpFileUpload || canSendEmailAttachments;
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
                final occupant = roomState.occupantForSenderJid(
                  trimmed,
                  preferRealJid: true,
                );

                final realJid = occupant?.realJid?.trim();
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
                  chatEntity?.supportsChatCalendar ?? false;
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
                        (status) => status.state == FanOutRecipientState.failed,
                      )
                      .toList();
                  final settingsSnapshot = _settingsSnapshotFromState(
                    context.read<SettingsCubit>().state,
                  );
                  final recipients = failedStatuses
                      .map(
                        (status) => ComposerRecipient(
                          target: Contact.chat(
                            chat: status.chat,
                            shareSignatureEnabled:
                                status.chat.shareSignatureEnabled ??
                                settingsSnapshot.shareTokenSignatureEnabled,
                          ),
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
              bool prepareChatExit() {
                _dismissTextInputFocus();
                if (!_chatRoute.isMain || openChatCalendar) {
                  _returnToMainRoute();
                  return false;
                }
                return true;
              }

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
              final isEmailBacked = chatEntity?.isEmailBacked ?? false;
              final canManagePins =
                  !isGroupChat ||
                  isEmailBacked ||
                  (state.roomState?.myAffiliation.canManagePins ?? false);
              final canTogglePins = !readOnly && canManagePins;
              final int pinnedCount = state.pinnedMessages.length;
              final bool calendarFirstRoom =
                  chatEntity?.isCalendarFirstRoom ?? false;
              final bool showingChatCalendar =
                  openChatCalendar || _chatRoute.isCalendar;
              final bool showCloseButton = !readOnly && !isWelcomeChat;
              final List<AppBarActionItem> navigationActions =
                  <AppBarActionItem>[
                    if (!readOnly && openStack.length > 1)
                      AppBarActionItem(
                        label: context.l10n.chatBack,
                        iconData: LucideIcons.arrowLeft,
                        onPressed: () {
                          if (!prepareChatExit()) return;
                          context.read<ChatsCubit>().popChat();
                        },
                      ),
                    if (!readOnly && forwardStack.isNotEmpty)
                      AppBarActionItem(
                        label: context.l10n.chatMessageOpenChat,
                        iconData: LucideIcons.arrowRight,
                        onPressed: () {
                          if (!prepareChatExit()) return;
                          context.read<ChatsCubit>().restoreChat();
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
                avatarPathForTypingParticipant: avatarPathForTypingParticipant,
                onToggleCollapseLongEmails: () {
                  setState(() {
                    _collapseLongEmailMessages = !_collapseLongEmailMessages;
                  });
                },
                onExpandedComposerDraftSaved: (draftId) {
                  if (!mounted) return;
                  setState(() {
                    _expandedComposerDraftId = draftId;
                    final current = _expandedComposerSeed;
                    if (current == null) {
                      return;
                    }
                    _expandedComposerSeed = current.copyWith(id: draftId);
                  });
                },
                onClearQuote: _quotedDraft == null
                    ? () {}
                    : () => setState(() {
                        _quotedDraft = null;
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
    final target = await _selectForwardTarget();
    if (!mounted || target == null) return;
    context.read<ChatBloc>().add(
      ChatMessageForwardRequested(message: message, target: target),
    );
  }

  Future<void> _handleInviteTap(
    Message message, {
    required RoomState? roomState,
    required String? selfJid,
  }) async {
    final l10n = context.l10n;
    final data = message.pseudoMessageData ?? const {};
    final roomJid = data['roomJid'] as String?;
    final roomName = (data['roomName'] as String?)?.trim();
    final invitee = data['invitee'] as String?;
    if (roomJid == null) return;
    if (roomState?.myOccupantJid != null) {
      _showSnackbar(l10n.chatInviteAlreadyInRoom);
      return;
    }
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
          requestId: const Uuid().v4(),
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
      onTaskAdded: (task, requestId) {
        context.read<CalendarBloc>().add(
          CalendarEvent.taskAdded(
            requestId: requestId,
            title: task.title,
            scheduledTime: task.scheduledTime,
            description: task.description,
            duration: task.duration,
            deadline: task.deadline,
            location: task.location,
            endDate: task.endDate,
            priority: task.priority ?? TaskPriority.none,
            recurrence: task.recurrence,
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
    final included = recipients.includedRecipients;
    if (included.length <= 1) return null;
    final shouldFanOut = shouldFanOutRecipients(
      chat: chat,
      recipients: included,
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

  Future<void> _forwardSelectedMessages(List<Message> messages) async {
    final l10n = context.l10n;
    if (messages.isEmpty) return;
    final forwardable = messages.where(
      (message) =>
          message.pseudoMessageType != PseudoMessageType.mucInvite &&
          message.pseudoMessageType != PseudoMessageType.mucInviteRevocation,
    );
    if (forwardable.isEmpty) {
      _showSnackbar(l10n.chatForwardInviteForbidden);
      return;
    }
    final candidates = forwardable.toList();
    final target = await _selectForwardTarget();
    if (!mounted || target == null) return;
    for (final message in candidates) {
      context.read<ChatBloc>().add(
        ChatMessageForwardRequested(message: message, target: target),
      );
    }
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
      onTaskAdded: (task, requestId) {
        context.read<CalendarBloc>().add(
          CalendarEvent.taskAdded(
            requestId: requestId,
            title: task.title,
            scheduledTime: task.scheduledTime,
            description: task.description,
            duration: task.duration,
            deadline: task.deadline,
            location: task.location,
            endDate: task.endDate,
            priority: task.priority ?? TaskPriority.none,
            recurrence: task.recurrence,
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

  void _clearChatRouteHistoryEntry() {
    final entry = _chatRouteHistoryEntry;
    _chatRouteHistoryEntry = null;
    entry?.remove();
  }

  void _updateChatRouteHistoryEntry() {
    final route = ModalRoute.of(context);
    if (route == null) {
      _clearChatRouteHistoryEntry();
      return;
    }
    if (_chatRoute.isMain) {
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

  void _setChatRoute(ChatRouteIndex nextRoute) {
    if (!mounted) return;
    final bool leavingCalendar = _chatRoute.isCalendar && !nextRoute.isCalendar;
    final bool wasSettings = _chatRoute.isSettings;
    setState(() {
      _previousChatRoute = _chatRoute;
      _chatRoute = nextRoute;
      _pinnedPanelVisible = false;
      if (_focusNode.hasFocus) {
        _focusNode.unfocus();
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
    context.read<ChatsCubit>().setOpenChatRoute(route: nextRoute);
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
      if (_focusNode.hasFocus) {
        _focusNode.unfocus();
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

  Future<Contact?> _selectForwardTarget() async {
    if (!mounted) return null;
    final options =
        (context.read<ChatsCubit>().state.items ?? const <chat_models.Chat>[])
            .cast<chat_models.Chat>()
            .toList(growable: false);
    return showAdaptiveBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      preferDialogOnMobile: true,
      surfacePadding: EdgeInsets.zero,
      builder: (sheetContext) =>
          _ForwardRecipientSheet(availableChats: options),
    );
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
        message: message,
        emoji: emoji,
        isEmailChat: chat.isEmailBacked,
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

  Map<String, FanOutRecipientState> _latestRecipientStatuses(ChatState state) {
    if (state.fanOutReports.isEmpty) {
      return const {};
    }
    final lastEntry = state.fanOutReports.entries.last.value;
    final statuses = <String, FanOutRecipientState>{};
    for (final status in lastEntry.statuses) {
      statuses[status.chat.jid] = status.state;
      final emailKey = normalizedAddressValue(status.chat.emailAddress);
      if (emailKey != null && emailKey.isNotEmpty) {
        statuses[emailKey] = status.state;
      }
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
