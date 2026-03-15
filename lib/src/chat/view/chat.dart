// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/attachments/bloc/attachment_gallery_bloc.dart';
import 'package:axichat/src/attachments/view/attachment_gallery_view.dart';
import 'package:axichat/src/attachments/view/pending_attachment_preview.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/blocklist/models/blocklist_entry.dart';
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
import 'package:axichat/src/calendar/utils/calendar_fragment_policy.dart';
import 'package:axichat/src/calendar/utils/calendar_state_waiter.dart';
import 'package:axichat/src/calendar/utils/location_autocomplete.dart';
import 'package:axichat/src/calendar/utils/task_share_formatter.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/chat_calendar_widget.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/calendar/view/calendar_drag_payload.dart';
import 'package:axichat/src/calendar/view/quick_add_modal.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/models/chat_timeline.dart';
import 'package:axichat/src/chat/models/chat_message.dart';
import 'package:axichat/src/chat/bloc/chat_search_cubit.dart';
import 'package:axichat/src/chat/models/pending_attachment.dart';
import 'package:axichat/src/common/compose_recipient.dart';
import 'package:axichat/src/chat/models/pinned_message_item.dart';
import 'package:axichat/src/chat/util/chat_timeline_projector.dart';
import 'package:axichat/src/chat/util/chat_subject_codec.dart';
import 'package:axichat/src/chat/view/attachment_approval_dialog.dart';
import 'package:axichat/src/chat/view/chat_alert.dart';
import 'package:axichat/src/chat/view/chat_attachment_preview.dart';
import 'package:axichat/src/chat/view/chat_bubble_surface.dart';
import 'package:axichat/src/chat/view/chat_cutout_composer.dart';
import 'package:axichat/src/chat/view/chat_message_details.dart';
import 'package:axichat/src/chat/view/message_text_parser.dart';
import 'package:axichat/src/chat/view/pending_attachment_list.dart';
import 'package:axichat/src/chat/view/widgets/calendar_availability_card.dart';
import 'package:axichat/src/chat/view/widgets/calendar_availability_request_sheet.dart';
import 'package:axichat/src/chat/view/widgets/calendar_availability_viewer.dart';
import 'package:axichat/src/chat/view/widgets/calendar_fragment_card.dart';
import 'package:axichat/src/chat/view/widgets/chat_calendar_critical_path_card.dart';
import 'package:axichat/src/chat/view/widgets/chat_calendar_task_card.dart';
import 'package:axichat/src/chat/view/widgets/email_html_web_view.dart';
import 'package:axichat/src/chat/view/widgets/chat_inline_details.dart';
import 'package:axichat/src/chat/view/widgets/email_image_extension.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/widgets/contact_rename_dialog.dart';
import 'package:axichat/src/chats/view/widgets/selection_panel_shell.dart';
import 'package:axichat/src/chats/view/widgets/chat_avatar_support.dart';
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
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/models/fan_out_models.dart';
import 'package:axichat/src/email/util/delta_jids.dart';
import 'package:axichat/src/important/bloc/important_messages_cubit.dart';
import 'package:axichat/src/important/view/important_messages_list.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/muc/muc_models.dart';
import 'package:axichat/src/muc/view/room_members_sheet.dart';
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
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

extension on MessageStatus {
  IconData get icon => switch (this) {
    MessageStatus.read => LucideIcons.checkCheck,
    MessageStatus.received || MessageStatus.sent => LucideIcons.check,
    MessageStatus.failed => LucideIcons.x,
    _ => LucideIcons.dot,
  };
}

final class _ChatTimelineSpecialItemView extends StatelessWidget {
  const _ChatTimelineSpecialItemView({
    required this.item,
    required this.quotedMessage,
    required this.quotedSenderLabel,
    required this.quotedIsSelf,
    required this.notices,
    required this.banner,
    required this.animationDuration,
  });

  final ChatTimelineSpecialItem item;
  final Message? quotedMessage;
  final String? quotedSenderLabel;
  final bool quotedIsSelf;
  final Widget? notices;
  final Widget? banner;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) => switch (item) {
    ChatTimelineComposerOverlaySpacerItem() => _ComposerOverlayHeadroomSpacer(
      child: _ComposerBottomOverlay(
        quotedMessage: quotedMessage,
        quotedSenderLabel: quotedSenderLabel,
        quotedIsSelf: quotedIsSelf,
        onClearQuote: () {},
        notices: notices,
        banner: banner,
        animationDuration: animationDuration,
      ),
    ),
    ChatTimelineUnreadDividerItem(:final label) => _UnreadDivider(label: label),
    ChatTimelineEmptyStateItem(:final label) => Padding(
      padding: EdgeInsets.symmetric(
        vertical: context.spacing.l,
        horizontal: context.spacing.m,
      ),
      child: Center(child: Text(label, style: context.textTheme.muted)),
    ),
  };
}

class _ChatTimelineItemView extends StatelessWidget {
  const _ChatTimelineItemView({
    required this.currentItem,
    required this.previous,
    required this.next,
    required this.state,
    required this.chatEntity,
    required this.currentUserId,
    required this.selfNick,
    required this.selfXmppJid,
    required this.myOccupantJid,
    required this.resolvedDirectChatDisplayName,
    required this.readOnly,
    required this.isGroupChat,
    required this.isEmailChat,
    required this.isWelcomeChat,
    required this.attachmentsBlockedForChat,
    required this.multiSelectActive,
    required this.selectedMessageId,
    required this.canTogglePins,
    required this.availabilityActorId,
    required this.availabilityShareOwnersById,
    required this.availabilityCoordinator,
    required this.normalizedXmppSelfJid,
    required this.normalizedEmailSelfJid,
    required this.personalCalendarAvailable,
    required this.chatCalendarAvailable,
    required this.messageFontSize,
    required this.availableWidth,
    required this.inboundMessageRowMaxWidth,
    required this.outboundMessageRowMaxWidth,
    required this.inboundClampedBubbleWidth,
    required this.outboundClampedBubbleWidth,
    required this.messageRowMaxWidth,
    required this.selectionExtrasPreferredMaxWidth,
    required this.overlayQuotedMessage,
    required this.overlayQuotedSenderLabel,
    required this.overlayQuotedIsSelf,
    required this.overlayNotices,
    required this.composerOverlayBanner,
    required this.overlayAnimationDuration,
    required this.shareRequestStatus,
    required this.bubbleRegionRegistry,
    required this.selectionTapRegionGroup,
    required this.messageKeys,
    required this.bubbleWidthByMessageId,
    required this.shouldAnimateMessage,
    required this.isPinnedMessage,
    required this.isImportantMessage,
    required this.onTapOutsideRequested,
    required this.resolveViewData,
    required this.resolveInteractionData,
    required this.composeBubbleContent,
    required this.onReplyRequested,
    required this.onForwardRequested,
    required this.onCopyRequested,
    required this.onShareRequested,
    required this.onAddToCalendarRequested,
    required this.onDetailsRequested,
    required this.onStartMultiSelectRequested,
    required this.onResendRequested,
    required this.onEditRequested,
    required this.onImportantToggleRequested,
    required this.onPinToggleRequested,
    required this.onRevokeInviteRequested,
    required this.onBubbleTapRequested,
    required this.onToggleMultiSelectRequested,
    required this.onToggleQuickReactionRequested,
    required this.onReactionSelectionRequested,
    required this.onRecipientTap,
    required this.onBubbleSizeChanged,
  });

  final ChatTimelineItem currentItem;
  final ChatTimelineItem? previous;
  final ChatTimelineItem? next;
  final ChatState state;
  final chat_models.Chat? chatEntity;
  final String? currentUserId;
  final String? selfNick;
  final String? selfXmppJid;
  final String? myOccupantJid;
  final String? resolvedDirectChatDisplayName;
  final bool readOnly;
  final bool isGroupChat;
  final bool isEmailChat;
  final bool isWelcomeChat;
  final bool attachmentsBlockedForChat;
  final bool multiSelectActive;
  final String? selectedMessageId;
  final bool canTogglePins;
  final String? availabilityActorId;
  final Map<String, String> availabilityShareOwnersById;
  final CalendarAvailabilityShareCoordinator? availabilityCoordinator;
  final String? normalizedXmppSelfJid;
  final String? normalizedEmailSelfJid;
  final bool personalCalendarAvailable;
  final bool chatCalendarAvailable;
  final double messageFontSize;
  final double availableWidth;
  final double inboundMessageRowMaxWidth;
  final double outboundMessageRowMaxWidth;
  final double inboundClampedBubbleWidth;
  final double outboundClampedBubbleWidth;
  final double messageRowMaxWidth;
  final double selectionExtrasPreferredMaxWidth;
  final Message? overlayQuotedMessage;
  final String? overlayQuotedSenderLabel;
  final bool overlayQuotedIsSelf;
  final Widget? overlayNotices;
  final Widget? composerOverlayBanner;
  final Duration overlayAnimationDuration;
  final RequestStatus shareRequestStatus;
  final _BubbleRegionRegistry bubbleRegionRegistry;
  final Object selectionTapRegionGroup;
  final Map<String, GlobalKey> messageKeys;
  final Map<String, double> bubbleWidthByMessageId;
  final bool Function(Message message) shouldAnimateMessage;
  final bool Function(Message message) isPinnedMessage;
  final bool Function(Message message) isImportantMessage;
  final TapRegionCallback onTapOutsideRequested;
  final ({
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
  Function({
    required BuildContext context,
    required ChatTimelineMessageItem timelineMessageItem,
    required bool isPinned,
    required bool isImportant,
    required double inboundMessageRowMaxWidth,
    required double outboundMessageRowMaxWidth,
    required double messageFontSize,
  })
  resolveViewData;
  final ({
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
  Function({
    required ChatState state,
    required ChatTimelineMessageItem timelineMessageItem,
    required Message messageModel,
    required bool isEmailMessage,
    required bool isEmailChat,
    required bool isGroupChat,
    required String? selfXmppJid,
    required String? myOccupantJid,
  })
  resolveInteractionData;
  final ({
    Object bubbleContentKey,
    List<Widget> bubbleTextChildren,
    List<Widget> bubbleExtraChildren,
  })
  Function({
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
  })
  composeBubbleContent;
  final void Function(Message message) onReplyRequested;
  final Future<void> Function(Message message) onForwardRequested;
  final Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onCopyRequested;
  final Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onShareRequested;
  final Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onAddToCalendarRequested;
  final void Function(String detailId) onDetailsRequested;
  final void Function(Message message) onStartMultiSelectRequested;
  final void Function(Message message, {required chat_models.Chat? chat})
  onResendRequested;
  final Future<void> Function(Message message) onEditRequested;
  final void Function(
    Message message, {
    required bool important,
    required chat_models.Chat? chat,
  })
  onImportantToggleRequested;
  final void Function(
    Message message, {
    required bool pin,
    required chat_models.Chat? chat,
    required RoomState? roomState,
  })
  onPinToggleRequested;
  final void Function(Message message, {String? inviteeJidFallback})
  onRevokeInviteRequested;
  final void Function(Message message, {required bool showUnreadIndicator})
  onBubbleTapRequested;
  final void Function(Message message) onToggleMultiSelectRequested;
  final void Function(Message message, String emoji)
  onToggleQuickReactionRequested;
  final Future<void> Function(Message message) onReactionSelectionRequested;
  final void Function(chat_models.Chat chat) onRecipientTap;
  final void Function(String messageId, Size size) onBubbleSizeChanged;

  @override
  Widget build(BuildContext context) {
    if (currentItem case final ChatTimelineSpecialItem item) {
      return _ChatTimelineSpecialItemView(
        item: item,
        quotedMessage: overlayQuotedMessage,
        quotedSenderLabel: overlayQuotedSenderLabel,
        quotedIsSelf: overlayQuotedIsSelf,
        notices: overlayNotices,
        banner: composerOverlayBanner,
        animationDuration: overlayAnimationDuration,
      );
    }
    if (currentItem case final ChatTimelineMessageItem timelineMessageItem) {
      return _ChatTimelineMessageInteractionView(
        currentItem: currentItem,
        previous: previous,
        next: next,
        timelineMessageItem: timelineMessageItem,
        state: state,
        chatEntity: chatEntity,
        roomState: state.roomState,
        currentUserId: currentUserId,
        selfNick: selfNick,
        selfXmppJid: selfXmppJid,
        myOccupantJid: myOccupantJid,
        resolvedDirectChatDisplayName: resolvedDirectChatDisplayName,
        readOnly: readOnly,
        isGroupChat: isGroupChat,
        isEmailChat: isEmailChat,
        isWelcomeChat: isWelcomeChat,
        attachmentsBlockedForChat: attachmentsBlockedForChat,
        multiSelectActive: multiSelectActive,
        selectedMessageId: selectedMessageId,
        canTogglePins: canTogglePins,
        availabilityActorId: availabilityActorId,
        availabilityShareOwnersById: availabilityShareOwnersById,
        availabilityCoordinator: availabilityCoordinator,
        normalizedXmppSelfJid: normalizedXmppSelfJid,
        normalizedEmailSelfJid: normalizedEmailSelfJid,
        personalCalendarAvailable: personalCalendarAvailable,
        chatCalendarAvailable: chatCalendarAvailable,
        messageFontSize: messageFontSize,
        availableWidth: availableWidth,
        inboundMessageRowMaxWidth: inboundMessageRowMaxWidth,
        outboundMessageRowMaxWidth: outboundMessageRowMaxWidth,
        inboundClampedBubbleWidth: inboundClampedBubbleWidth,
        outboundClampedBubbleWidth: outboundClampedBubbleWidth,
        messageRowMaxWidth: messageRowMaxWidth,
        selectionExtrasPreferredMaxWidth: selectionExtrasPreferredMaxWidth,
        shareRequestStatus: shareRequestStatus,
        bubbleRegionRegistry: bubbleRegionRegistry,
        selectionTapRegionGroup: selectionTapRegionGroup,
        messageKeys: messageKeys,
        bubbleWidthByMessageId: bubbleWidthByMessageId,
        shouldAnimateMessage: shouldAnimateMessage,
        isPinnedMessage: isPinnedMessage,
        isImportantMessage: isImportantMessage,
        onTapOutsideRequested: onTapOutsideRequested,
        resolveViewData: resolveViewData,
        resolveInteractionData: resolveInteractionData,
        composeBubbleContent: composeBubbleContent,
        onReplyRequested: onReplyRequested,
        onForwardRequested: onForwardRequested,
        onCopyRequested: onCopyRequested,
        onShareRequested: onShareRequested,
        onAddToCalendarRequested: onAddToCalendarRequested,
        onDetailsRequested: onDetailsRequested,
        onStartMultiSelectRequested: onStartMultiSelectRequested,
        onResendRequested: onResendRequested,
        onEditRequested: onEditRequested,
        onImportantToggleRequested: onImportantToggleRequested,
        onPinToggleRequested: onPinToggleRequested,
        onRevokeInviteRequested: onRevokeInviteRequested,
        onBubbleTapRequested: onBubbleTapRequested,
        onToggleMultiSelectRequested: onToggleMultiSelectRequested,
        onToggleQuickReactionRequested: onToggleQuickReactionRequested,
        onReactionSelectionRequested: onReactionSelectionRequested,
        onRecipientTap: onRecipientTap,
        onBubbleSizeChanged: onBubbleSizeChanged,
      );
    }
    return const SizedBox.shrink();
  }
}

BorderRadius _bubbleBaseRadius(BuildContext context) =>
    BorderRadius.circular(context.radii.squircle);

EdgeInsets _bubblePadding(BuildContext context) => EdgeInsets.symmetric(
  horizontal: context.spacing.s,
  vertical: context.spacing.s,
);
const List<BlocklistEntry> _emptyBlocklistEntries = <BlocklistEntry>[];
const String _chatCalendarPanelKeyPrefix = 'chat-calendar-';
const String _chatPinnedPanelKeyPrefix = 'chat-pins-';
const String _chatPanelKeyFallback = '';
const int _chatBaseActionCount = 3;
const int _pinnedBadgeHiddenCount = 0;
const bool _calendarTaskIcsReadOnlyFallback =
    CalendarTaskIcsMessage.defaultReadOnly;
const Uuid _availabilityResponseIdGenerator = Uuid();
const String _composerShareSeparator = '\n\n';
const String _emptyText = '';
const List<InlineSpan> _emptyInlineSpans = <InlineSpan>[];
const _bubbleFocusDuration = Duration(milliseconds: 620);
const _bubbleFocusCurve = Curves.easeOutCubic;
const _messageArrivalDuration = Duration(milliseconds: 420);
const _messageArrivalCurve = Curves.easeOutCubic;
const Curve _chatOverlayFadeCurve = Curves.easeOutCubic;
const Offset _chatCalendarSlideOffset = Offset(0.0, 0.04);
const double _chatCalendarTransitionVisibleValue = 1.0;
const double _chatCalendarTransitionHiddenValue = 0.0;
final _selectionSpacerTimestamp = DateTime.fromMillisecondsSinceEpoch(
  0,
  isUtc: true,
);
const _reactionQuickChoices = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '👏'];
const _composerOverlaySpacerMessageId = '__composer_overlay_spacer__';
const _emptyStateMessageId = '__empty_state__';
const _unreadDividerMessageId = '__unread_divider__';
const _chatScrollStoragePrefix = 'chat-scroll-offset-';
const _typingIndicatorMaxAvatars = 7;
typedef _MessageBubbleExtraAdder =
    void Function(
      Widget child, {
      required ShapeBorder shape,
      double? spacing,
      Key? key,
    });

class _MessageFilterOption {
  const _MessageFilterOption(this.filter, this.label);

  final MessageTimelineFilter filter;
  final String label;
}

class _CalendarTaskShare {
  const _CalendarTaskShare({required this.task, required this.text});

  final CalendarTask? task;
  final String text;
}

List<_MessageFilterOption> _messageFilterOptions(AppLocalizations l10n) => [
  _MessageFilterOption(
    MessageTimelineFilter.directOnly,
    MessageTimelineFilter.directOnly.menuLabel(l10n),
  ),
  _MessageFilterOption(
    MessageTimelineFilter.allWithContact,
    MessageTimelineFilter.allWithContact.menuLabel(l10n),
  ),
];

extension MessageTimelineFilterLabels on MessageTimelineFilter {
  String menuLabel(AppLocalizations l10n) => switch (this) {
    MessageTimelineFilter.directOnly => l10n.chatFilterDirectOnly,
    MessageTimelineFilter.allWithContact => l10n.chatFilterAllWithContact,
  };

  String statusLabel(AppLocalizations l10n) => switch (this) {
    MessageTimelineFilter.directOnly => l10n.chatShowingDirectOnly,
    MessageTimelineFilter.allWithContact => l10n.chatShowingAll,
  };
}

String _sortLabel(SearchSortOrder order, AppLocalizations l10n) =>
    switch (order) {
      SearchSortOrder.newestFirst => l10n.chatSearchSortNewestFirst,
      SearchSortOrder.oldestFirst => l10n.chatSearchSortOldestFirst,
    };

String _collapsedEmailPreviewText(String text) {
  final normalized = text.trim();
  if (normalized.isEmpty) {
    return normalized;
  }
  final lines = normalized
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (lines.isEmpty) {
    return normalized;
  }
  final preview = lines.take(2).join('\n');
  const maxChars = 280;
  if (preview.length > maxChars) {
    return preview.substring(0, maxChars).trimRight();
  }
  return preview;
}

class _ChatSearchPanel extends StatefulWidget {
  const _ChatSearchPanel();

  @override
  State<_ChatSearchPanel> createState() => _ChatSearchPanelState();
}

class _ChatSearchPanelState extends State<_ChatSearchPanel> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  var _programmatic = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    if (_programmatic) return;
    context.read<ChatSearchCubit>().updateQuery(_controller.text);
  }

  void _syncController(String text) {
    if (_controller.text == text) return;
    _programmatic = true;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _programmatic = false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatSearchCubit, ChatSearchState>(
      listener: (context, state) {
        _syncController(state.query);
        if (state.active) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _focusNode.hasFocus) return;
            _focusNode.requestFocus();
          });
        } else if (_focusNode.hasFocus) {
          _focusNode.unfocus();
        }
      },
      builder: (context, state) {
        final l10n = context.l10n;
        final spacing = context.spacing;
        final colors = context.colorScheme;
        final messageFilterOptions = _messageFilterOptions(l10n);
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: spacing.m,
            vertical: spacing.s,
          ),
          decoration: BoxDecoration(
            color: colors.card,
            border: Border(bottom: context.borderSide),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SearchInputField(
                      controller: _controller,
                      focusNode: _focusNode,
                      placeholder: Text(l10n.chatSearchMessages),
                      clearTooltip: l10n.commonClear,
                      onClear: _controller.clear,
                    ),
                  ),
                  SizedBox(width: spacing.s),
                  AxiButton(
                    variant: AxiButtonVariant.ghost,
                    onPressed: () =>
                        context.read<ChatSearchCubit>().setActive(false),
                    child: Text(l10n.commonCancel),
                  ),
                ],
              ),
              SizedBox(height: spacing.s),
              Row(
                children: [
                  Expanded(
                    child: AxiSelect<SearchSortOrder>(
                      initialValue: state.sort,
                      onChanged: (value) {
                        if (value == null) return;
                        context.read<ChatSearchCubit>().updateSort(value);
                      },
                      options: SearchSortOrder.values
                          .map(
                            (order) => ShadOption<SearchSortOrder>(
                              value: order,
                              child: Text(_sortLabel(order, l10n)),
                            ),
                          )
                          .toList(),
                      selectedOptionBuilder: (_, value) =>
                          Text(_sortLabel(value, l10n)),
                    ),
                  ),
                  SizedBox(width: spacing.s),
                  Expanded(
                    child: AxiSelect<MessageTimelineFilter>(
                      initialValue: state.filter,
                      onChanged: (value) {
                        if (value == null) return;
                        context.read<ChatSearchCubit>().updateFilter(value);
                      },
                      options: messageFilterOptions
                          .map(
                            (option) => ShadOption<MessageTimelineFilter>(
                              value: option.filter,
                              child: Text(option.label),
                            ),
                          )
                          .toList(),
                      selectedOptionBuilder: (_, value) => Text(
                        messageFilterOptions
                            .firstWhere((option) => option.filter == value)
                            .label,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.s),
              Row(
                children: [
                  Expanded(
                    child: AxiSelect<String>(
                      initialValue: state.subjectFilter ?? '',
                      onChanged: (value) {
                        context.read<ChatSearchCubit>().updateSubjectFilter(
                          value?.isEmpty == true ? null : value,
                        );
                      },
                      options: [
                        ShadOption<String>(
                          value: '',
                          child: Text(l10n.chatSearchAnySubject),
                        ),
                        ...state.subjects.map(
                          (subject) => ShadOption<String>(
                            value: subject,
                            child: Text(subject),
                          ),
                        ),
                      ],
                      selectedOptionBuilder: (_, value) => Text(
                        value.isNotEmpty ? value : l10n.chatSearchAnySubject,
                      ),
                    ),
                  ),
                  SizedBox(width: spacing.s),
                  ShadSwitch(
                    value: state.excludeSubject,
                    onChanged: (value) => context
                        .read<ChatSearchCubit>()
                        .toggleExcludeSubject(value),
                  ),
                  SizedBox(width: spacing.s),
                  Text(
                    l10n.chatSearchExcludeSubject,
                    style: context.textTheme.muted,
                  ),
                ],
              ),
              SizedBox(height: spacing.s),
              Row(
                children: [
                  ShadSwitch(
                    value: state.importantOnly,
                    onChanged: (value) => context
                        .read<ChatSearchCubit>()
                        .updateImportantOnly(value),
                  ),
                  SizedBox(width: spacing.s),
                  Text(
                    l10n.chatSearchImportantOnly,
                    style: context.textTheme.muted,
                  ),
                ],
              ),
              SizedBox(height: spacing.s),
              Builder(
                builder: (context) {
                  final trimmedQuery = state.query.trim();
                  final hasSubject = state.subjectFilter?.isNotEmpty == true;
                  final queryEmpty =
                      trimmedQuery.isEmpty &&
                      !hasSubject &&
                      !state.importantOnly;
                  Widget? statusChild;
                  if (state.error != null) {
                    statusChild = Text(
                      state.error ?? l10n.chatSearchFailed,
                      style: TextStyle(color: context.colorScheme.destructive),
                    );
                  } else if (state.status.isLoading) {
                    statusChild = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.chatSearchInProgress,
                          style: context.textTheme.muted,
                        ),
                      ],
                    );
                  } else if (queryEmpty) {
                    statusChild = Text(
                      l10n.chatSearchEmptyPrompt,
                      style: context.textTheme.muted,
                    );
                  } else if (state.status.isSuccess) {
                    final matchCount = state.results.length;
                    statusChild = Text(
                      matchCount == 0
                          ? l10n.chatSearchNoMatches
                          : l10n.chatSearchMatchCount(matchCount),
                      style: context.textTheme.muted,
                    );
                  }
                  if (statusChild == null) {
                    return const SizedBox.shrink();
                  }
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: statusChild,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatTopPanelVisibility extends StatelessWidget {
  const _ChatTopPanelVisibility({required this.visible, this.child});

  final bool visible;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final duration = context.watch<SettingsCubit>().animationDuration;
    final currentChild = visible && child != null
        ? child!
        : const SizedBox.shrink(key: ValueKey<String>('chat-top-panel-hidden'));
    return AxiAnimatedSize(
      duration: duration,
      reverseDuration: duration,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        reverseDuration: duration,
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              ...previousChildren,
              if (currentChild case final Widget current) current,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          return _ChatTopPanelTransition(animation: animation, child: child);
        },
        child: currentChild,
      ),
    );
  }
}

class _ChatTopPanelTransition extends StatelessWidget {
  const _ChatTopPanelTransition({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SlideTransition(
        position: Tween<Offset>(
          begin: context.motion.statusBannerSlideOffset,
          end: Offset.zero,
        ).animate(animation),
        child: SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1.0,
          child: child,
        ),
      ),
    );
  }
}

class _SizeReportingWidget extends SingleChildRenderObjectWidget {
  const _SizeReportingWidget({
    required this.onSizeChange,
    required super.child,
  });

  final ValueChanged<Size> onSizeChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _SizeReportingRenderObject(onSizeChange);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _SizeReportingRenderObject renderObject,
  ) {
    renderObject.onSizeChange = onSizeChange;
  }
}

class _SizeReportingRenderObject extends RenderProxyBox {
  _SizeReportingRenderObject(this.onSizeChange);

  ValueChanged<Size> onSizeChange;
  Size? _lastSize;

  @override
  void performLayout() {
    super.performLayout();
    final newSize = size;
    if (_lastSize == newSize) {
      return;
    }
    _lastSize = newSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onSizeChange(newSize);
    });
  }
}

class _UnknownSenderBanner extends StatelessWidget {
  const _UnknownSenderBanner({
    required this.readOnly,
    required this.isSelfChat,
    required this.onAddContact,
    required this.onReportSpam,
  });

  final bool readOnly;
  final bool isSelfChat;
  final Future<void> Function()? onAddContact;
  final Future<void> Function()? onReportSpam;

  @override
  Widget build(BuildContext context) {
    if (readOnly || isSelfChat) {
      return const SizedBox.shrink();
    }
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final chat = state.chat;
        if (chat == null ||
            chat.type != ChatType.chat ||
            chat.spam ||
            chat.isAxichatWelcomeThread ||
            chat.isEmailBacked) {
          return const SizedBox.shrink();
        }
        return BlocBuilder<RosterCubit, RosterState>(
          buildWhen: (previous, current) => previous.items != current.items,
          builder: (context, rosterState) {
            final rosterItems =
                rosterState.items ??
                (context.read<RosterCubit>()[RosterCubit.itemsCacheKey]
                    as List<RosterItem>?) ??
                const <RosterItem>[];
            final normalizedChatJid = normalizedAddressKey(chat.remoteJid);
            final rosterEntry = normalizedChatJid == null
                ? null
                : rosterItems
                      .where(
                        (entry) =>
                            normalizedAddressKey(entry.jid) ==
                            normalizedChatJid,
                      )
                      .firstOrNull;
            final inRoster = rosterEntry != null;
            final showBanner = !inRoster;
            if (!showBanner) {
              return const SizedBox.shrink();
            }
            final l10n = context.l10n;
            final spacing = context.spacing;
            final iconSize = spacing.m;
            final actions = <Widget>[
              if (onAddContact != null)
                ContextActionButton(
                  icon: Icon(LucideIcons.userPlus, size: iconSize),
                  label: l10n.rosterAddTitle,
                  onPressed: () async {
                    await onAddContact!();
                  },
                ),
              if (onReportSpam != null)
                ContextActionButton(
                  icon: Icon(LucideIcons.shieldAlert, size: iconSize),
                  label: l10n.chatReportSpam,
                  onPressed: () async {
                    await onReportSpam!();
                  },
                  destructive: true,
                ),
            ];
            return ListItemPadding(
              child: ShadCard(
                padding: EdgeInsets.all(spacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.userX,
                          size: iconSize,
                          color: context.colorScheme.destructive,
                        ),
                        SizedBox(width: spacing.s),
                        Expanded(
                          child: Text(
                            l10n.accessibilityUnknownContact,
                            style: context.textTheme.small.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.s),
                    Text(
                      l10n.chatAttachmentBlockedDescription,
                      style: context.textTheme.muted,
                    ),
                    if (actions.isNotEmpty) ...[
                      SizedBox(height: spacing.s),
                      Wrap(
                        spacing: spacing.s,
                        runSpacing: spacing.s,
                        children: actions,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

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

OutlinedBorder _attachmentSurfaceShape({
  required BuildContext context,
  required bool isSelf,
  required bool chainedPrevious,
  required bool chainedNext,
}) {
  final spacing = context.spacing;
  final radius = Radius.circular(spacing.m);
  if (!chainedPrevious && !chainedNext) {
    return ContinuousRectangleBorder(borderRadius: BorderRadius.all(radius));
  }
  var topLeading = radius;
  var topTrailing = radius;
  var bottomLeading = radius;
  var bottomTrailing = radius;
  if (isSelf) {
    if (chainedPrevious) topTrailing = Radius.zero;
    if (chainedNext) bottomTrailing = Radius.zero;
  } else {
    if (chainedPrevious) topLeading = Radius.zero;
    if (chainedNext) bottomLeading = Radius.zero;
  }
  return ContinuousRectangleBorder(
    borderRadius: BorderRadius.only(
      topLeft: topLeading,
      topRight: topTrailing,
      bottomLeft: bottomLeading,
      bottomRight: bottomTrailing,
    ),
  );
}

bool _chatMessagesShouldChain(ChatMessage current, ChatMessage? neighbor) {
  if (neighbor == null) return false;
  if (neighbor.user.id != current.user.id) return false;
  final neighborDate = DateTime(
    neighbor.createdAt.year,
    neighbor.createdAt.month,
    neighbor.createdAt.day,
  );
  final currentDate = DateTime(
    current.createdAt.year,
    current.createdAt.month,
    current.createdAt.day,
  );
  return neighborDate == currentDate;
}

bool _chatTimelineItemsShouldChain(
  ChatTimelineItem current,
  ChatTimelineItem? neighbor,
) {
  if (current is! ChatTimelineMessageItem ||
      neighbor is! ChatTimelineMessageItem) {
    return false;
  }
  if (neighbor.authorId != current.authorId) {
    return false;
  }
  final neighborDate = DateTime(
    neighbor.createdAt.year,
    neighbor.createdAt.month,
    neighbor.createdAt.day,
  );
  final currentDate = DateTime(
    current.createdAt.year,
    current.createdAt.month,
    current.createdAt.day,
  );
  return neighborDate == currentDate;
}

Widget? _senderLabelForTimelineMessage({
  required BuildContext context,
  required bool shouldShow,
  required bool isSelfBubble,
  required bool hasAvatarSlot,
  required double avatarContentInset,
  required ChatUser user,
  required String selfLabel,
}) {
  if (!shouldShow) {
    return null;
  }
  final spacing = context.spacing;
  final leftInset = !isSelfBubble && hasAvatarSlot
      ? avatarContentInset + _bubblePadding(context).left + spacing.xxs
      : 0.0;
  return _MessageSenderLabel(
    user: user,
    isSelf: isSelfBubble,
    selfLabel: selfLabel,
    leftInset: leftInset,
  );
}

bool _timelineQuotedMessageIsSelf({
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

String _timelineForwardedSenderLabel({
  required String? forwardedFromJid,
  required String fallbackSenderJid,
  required bool fallbackIsSelf,
  required bool isGroupChat,
  required RoomState? roomState,
  required String? currentUserId,
  required AppLocalizations l10n,
}) {
  final source = forwardedFromJid?.trim();
  if (source == null || source.isEmpty) {
    if (fallbackIsSelf) {
      return l10n.chatSenderYou;
    }
    final fallbackNick = roomState?.senderNick(fallbackSenderJid);
    if (fallbackNick != null && fallbackNick.isNotEmpty) {
      return fallbackNick;
    }
    final fallbackResolved = fallbackSenderJid.trim();
    return fallbackResolved.isNotEmpty
        ? fallbackResolved
        : l10n.commonUnknownLabel;
  }
  if (bareAddress(source) == bareAddress(currentUserId)) {
    return l10n.chatSenderYou;
  }
  if (isGroupChat) {
    final nick = roomState?.senderNick(source);
    if (nick != null && nick.isNotEmpty) {
      return nick;
    }
  }
  return source;
}

String _timelineQuotedSenderLabel({
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

Widget? _timelineQuotedPreview({
  required Message? quotedMessage,
  required bool isGroupChat,
  required RoomState? roomState,
  required String? fallbackSelfNick,
  required String? currentUserId,
  required String? chatDisplayName,
  required AppLocalizations l10n,
  required bool isSelfBubble,
}) {
  if (quotedMessage == null) {
    return null;
  }
  final quotedIsSelf = _timelineQuotedMessageIsSelf(
    quotedMessage: quotedMessage,
    isGroupChat: isGroupChat,
    roomState: roomState,
    fallbackSelfNick: fallbackSelfNick,
    currentUserId: currentUserId,
  );
  return _QuotedMessagePreview(
    message: quotedMessage,
    senderLabel: quotedIsSelf
        ? l10n.chatSenderYou
        : _timelineQuotedSenderLabel(
            quotedMessage: quotedMessage,
            isGroupChat: isGroupChat,
            roomState: roomState,
            chatDisplayName: chatDisplayName,
            l10n: l10n,
          ),
    isSelf: isSelfBubble,
  );
}

Widget? _timelineForwardedPreview({
  required bool isForwarded,
  required String? forwardedFromJid,
  required String? forwardedSubjectSenderLabel,
  required String fallbackSenderJid,
  required bool fallbackIsSelf,
  required bool isGroupChat,
  required RoomState? roomState,
  required String? currentUserId,
  required AppLocalizations l10n,
  required bool isSelfBubble,
}) {
  if (!isForwarded) {
    return null;
  }
  final resolvedForwardedSenderLabel = _timelineForwardedSenderLabel(
    forwardedFromJid: forwardedFromJid,
    fallbackSenderJid: fallbackSenderJid,
    fallbackIsSelf: fallbackIsSelf,
    isGroupChat: isGroupChat,
    roomState: roomState,
    currentUserId: currentUserId,
    l10n: l10n,
  );
  return _ForwardedPreviewText(
    senderLabel: forwardedFromJid?.trim().isNotEmpty == true
        ? resolvedForwardedSenderLabel
        : (forwardedSubjectSenderLabel ?? resolvedForwardedSenderLabel),
    isSelf: isSelfBubble,
  );
}

({
  Widget? avatarOverlay,
  CutoutStyle? avatarStyle,
  ChatBubbleCutoutAnchor avatarAnchor,
})
resolveTimelineMessageAvatarCutout({
  required BuildContext context,
  required bool requiresAvatarHeadroom,
  required ChatTimelineMessageItem timelineMessageItem,
  required double messageAvatarSize,
  required double avatarCutoutDepth,
  required double avatarCutoutRadius,
  required double avatarMinThickness,
  required double messageAvatarCornerClearance,
  required EdgeInsets messageAvatarCutoutPadding,
  required double avatarCutoutAlignment,
}) {
  if (!requiresAvatarHeadroom) {
    return (
      avatarOverlay: null,
      avatarStyle: null,
      avatarAnchor: ChatBubbleCutoutAnchor.left,
    );
  }
  final messageAvatarPath = timelineMessageItem.authorAvatarPath?.trim();
  return (
    avatarOverlay: _MessageAvatar(
      jid: timelineMessageItem.authorAvatarKey,
      size: messageAvatarSize,
      avatarPath: messageAvatarPath?.isNotEmpty == true
          ? messageAvatarPath
          : null,
    ),
    avatarStyle: CutoutStyle(
      depth: avatarCutoutDepth,
      cornerRadius: avatarCutoutRadius,
      shapeCornerRadius: context.radii.squircle,
      padding: messageAvatarCutoutPadding,
      offset: Offset.zero,
      minThickness: avatarMinThickness,
      cornerClearance: messageAvatarCornerClearance,
      alignment: avatarCutoutAlignment,
    ),
    avatarAnchor: ChatBubbleCutoutAnchor.left,
  );
}

String resolveMessageAvatarSeed({
  required Message message,
  required RoomState? roomState,
  required Occupant? occupant,
  required String fallbackLabel,
  required String unknownLabel,
}) {
  final resolvedOccupant =
      occupant ??
      roomState?.occupantForSenderJid(message.senderJid, preferRealJid: true);
  final occupantNick = resolvedOccupant?.nick.trim();
  if (occupantNick != null && occupantNick.isNotEmpty) {
    return occupantNick;
  }

  final trimmedFallback = fallbackLabel.trim();
  if (trimmedFallback.isEmpty) {
    return unknownLabel;
  }

  final senderBare = bareAddressValue(message.senderJid);
  final chatBare = bareAddressValue(message.chatJid);
  final fallbackBare = bareAddressValue(trimmedFallback);
  if (senderBare != null &&
      chatBare != null &&
      senderBare == chatBare &&
      fallbackBare == chatBare) {
    return unknownLabel;
  }
  return trimmedFallback;
}

ChatCalendarSyncCoordinator? _readChatCalendarCoordinator(
  BuildContext context, {
  required bool calendarAvailable,
}) => calendarAvailable ? context.read<ChatCalendarSyncCoordinator>() : null;

CalendarAvailabilityShareCoordinator? _readAvailabilityShareCoordinator(
  BuildContext context, {
  required bool calendarAvailable,
}) => calendarAvailable
    ? context.read<CalendarAvailabilityShareCoordinator>()
    : null;

class Chat extends StatefulWidget {
  const Chat({super.key, this.readOnly = false});

  final bool readOnly;

  @override
  State<Chat> createState() => _ChatState();
}

class _RoomMembersDrawerContent extends StatelessWidget {
  const _RoomMembersDrawerContent({
    required this.onInvite,
    required this.onAction,
    required this.onOpenDirectChat,
    required this.onChangeNickname,
    required this.onLeaveRoom,
    required this.onDestroyRoom,
    required this.onClose,
  });

  final ValueChanged<String> onInvite;
  final Future<void> Function(
    String occupantId,
    MucModerationAction action,
    String actionLabel,
  )
  onAction;
  final Future<void> Function(String jid) onOpenDirectChat;
  final ValueChanged<String> onChangeNickname;
  final Future<void> Function() onLeaveRoom;
  final Future<void> Function() onDestroyRoom;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final l10n = context.l10n;
        final roomState = state.roomState;
        if (roomState == null ||
            (!roomState.isReadyForMessaging &&
                !roomState.hasJoinError &&
                !roomState.hasTerminalExit)) {
          final colors = context.colorScheme;
          final textTheme = context.textTheme;
          final spacing = context.spacing;
          return SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AxiProgressIndicator(
                    color: colors.foreground,
                    semanticsLabel: l10n.chatMembersLoading,
                  ),
                  SizedBox(height: spacing.s),
                  Text(
                    l10n.chatMembersLoadingEllipsis,
                    style: textTheme.muted.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return RoomMembersSheet(
          roomState: roomState,
          memberSections: state.roomMemberSections,
          avatarUpdateInFlight: state.roomAvatarUpdateStatus.isLoading,
          canInvite:
              roomState.myAffiliation.isOwner ||
              roomState.myAffiliation.isAdmin ||
              roomState.myRole.isModerator,
          onInvite: onInvite,
          onAction: onAction,
          onOpenDirectChat: onOpenDirectChat,
          roomAvatarPath: state.chat?.avatarPath,
          onChangeNickname: onChangeNickname,
          onLeaveRoom: onLeaveRoom,
          onDestroyRoom: onDestroyRoom,
          currentNickname: roomState.selfNick,
          onClose: onClose,
          useSurface: true,
        );
      },
    );
  }
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
  static const CalendarFragmentPolicy _calendarFragmentPolicy =
      CalendarFragmentPolicy();
  CalendarTask? _pendingCalendarTaskIcs;
  String? _pendingCalendarSeedText;
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
    final draft = _availabilityTaskDraft(request);
    if (draft == null) {
      _showSnackbar(context.l10n.chatAvailabilityRequestInvalidRangeMessage);
      return;
    }
    if (decision.addToPersonal) {
      _addAvailabilityTaskToPersonalCalendar(draft);
    }
    if (decision.addToChat) {
      await _addAvailabilityTaskToChatCalendar(draft);
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

  void _addAvailabilityTaskToPersonalCalendar(_AvailabilityTaskDraft draft) {
    final storageManager = context.read<CalendarStorageManager>();
    if (!storageManager.isAuthStorageReady) {
      _showSnackbar(
        context.l10n.chatAvailabilityRequestCalendarUnavailableMessage,
      );
      return;
    }
    context.read<CalendarBloc>().add(
      CalendarEvent.taskAdded(
        title: draft.title,
        scheduledTime: draft.start,
        duration: draft.duration,
        description: draft.description,
      ),
    );
  }

  Future<void> _addAvailabilityTaskToChatCalendar(
    _AvailabilityTaskDraft draft,
  ) async {
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
      title: draft.title,
      description: draft.description,
      scheduledTime: draft.start,
      duration: draft.duration,
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
    context.read<CalendarBloc>().add(
      CalendarEvent.tasksImported(tasks: <CalendarTask>[task]),
    );
    final bool copied = await waitForTasksInCalendar(
      bloc: context.read<CalendarBloc>(),
      taskIds: <String>{task.id},
    );
    if (!mounted || !copied) {
      return null;
    }
    return context.read<CalendarBloc>().id;
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
    context.read<CalendarBloc>().add(CalendarEvent.modelImported(model: model));
    return waitForCriticalPathTasks(
      bloc: context.read<CalendarBloc>(),
      pathId: pathId,
      taskIds: taskIds,
    );
  }

  _AvailabilityTaskDraft? _availabilityTaskDraft(
    CalendarAvailabilityRequest request,
  ) {
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
    return _AvailabilityTaskDraft(
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
      final result = await context.read<DraftCubit>().saveDraft(
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
        _expandedComposerDraftId = result.draftId;
        _expandedComposerSeed = ComposeDraftSeed(
          id: result.draftId,
          jids: recipients,
          body: body,
          subject: subject,
          quoteTarget: quoteTarget,
          attachmentMetadataIds: result.attachmentMetadataIds,
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
        final selfIdentity = SelfIdentitySnapshot(
          selfJid: selfJid,
          avatarPath: context.watch<ProfileCubit>().state.avatarPath,
          avatarLoading: context.watch<ProfileCubit>().state.avatarHydrating,
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
              const IconData pinnedIcon = LucideIcons.pin;
              final bool calendarFirstRoom =
                  chatEntity?.isCalendarFirstRoom ?? false;
              final bool showingChatCalendar =
                  openChatCalendar || _chatRoute.isCalendar;
              final bool showCloseButton = !readOnly;
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
              final scaffold = LayoutBuilder(
                builder: (context, constraints) {
                  final spacing = context.spacing;
                  final leadingInset = spacing.m;
                  final leadingSpacing = spacing.xs;
                  final actionSpacing = spacing.xxs;
                  final appBarActionsPadding = spacing.s;
                  final appBarTitleSpacing = spacing.m;
                  final collapsedLeadingWidth = 0.0;
                  final avatarTitleSpacing = spacing.m;
                  final titleMinWidth = context.sizing.iconButtonTapTarget * 3;
                  final showTitleAvatar = !isEmailBacked && chatEntity != null;
                  final rosterItems = jid == null
                      ? const <RosterItem>[]
                      : context.select<RosterCubit, List<RosterItem>>(
                          (cubit) => cubit.state.items ?? const <RosterItem>[],
                        );
                  final item = jid == null
                      ? null
                      : rosterItems
                            .where((entry) => entry.jid == jid)
                            .singleOrNull;
                  final canRenameContact =
                      !readOnly &&
                      chatEntity != null &&
                      chatEntity.type == ChatType.chat &&
                      !chatEntity.isAxichatWelcomeThread;
                  final statusLabel = item?.status?.trim() ?? '';
                  final addressLabel = isWelcomeChat || jid == null
                      ? _emptyText
                      : jid.trim();
                  const addressStatusSeparator = ' · ';
                  final secondaryLabel = switch ((
                    addressLabel.isNotEmpty,
                    statusLabel.isNotEmpty,
                  )) {
                    (true, true) =>
                      '$addressLabel$addressStatusSeparator$statusLabel',
                    (true, false) => addressLabel,
                    (false, true) => statusLabel,
                    (false, false) => _emptyText,
                  };
                  final avatarTooltip = isGroupChat
                      ? context.l10n.chatRoomMembers
                      : null;
                  final baseTitleStyle = context.textTheme.h4;
                  final titleStyle = baseTitleStyle.copyWith(
                    fontSize: context.textTheme.large.fontSize,
                  );
                  final TextStyle subtitleStyle = context.textTheme.muted;
                  final textScaler =
                      MediaQuery.maybeTextScalerOf(context) ??
                      TextScaler.noScaling;
                  double measureTextWidth(String text, TextStyle style) {
                    final normalized = text.trim();
                    if (normalized.isEmpty) {
                      return 0.0;
                    }
                    final painter = TextPainter(
                      text: TextSpan(text: normalized, style: style),
                      textDirection: Directionality.of(context),
                      textScaler: textScaler,
                      maxLines: 1,
                    )..layout();
                    return painter.width;
                  }

                  final double appBarWidth = constraints.maxWidth;
                  final int leadingButtonCountExpanded =
                      navigationActionCount + (showCloseButton ? 1 : 0);
                  final double leadingWidthExpanded =
                      leadingButtonCountExpanded == 0
                      ? collapsedLeadingWidth
                      : leadingInset +
                            (AxiIconButton.kTapTargetSize *
                                leadingButtonCountExpanded) +
                            (leadingSpacing *
                                math.max(0, leadingButtonCountExpanded - 1));
                  final double chatActionsWidth = chatActionCount == 0
                      ? 0
                      : (AxiIconButton.kTapTargetSize * chatActionCount) +
                            (actionSpacing * math.max(0, chatActionCount - 1));
                  final double titleReserveWidth = math.max(
                    titleMinWidth,
                    (showTitleAvatar
                            ? context.sizing.iconButtonSize + avatarTitleSpacing
                            : 0.0) +
                        math.max(
                          measureTextWidth(
                            state.chat?.displayName ?? _emptyText,
                            titleStyle,
                          ),
                          measureTextWidth(secondaryLabel, subtitleStyle),
                        ),
                  );
                  final double actionsPaddingWidth = appBarActionsPadding * 2;
                  final double toolbarMiddleSpacingWidth =
                      appBarTitleSpacing * 2;
                  final double trailingActionsAvailableWidth = math.max(
                    0.0,
                    appBarWidth -
                        leadingWidthExpanded -
                        titleReserveWidth -
                        actionsPaddingWidth -
                        toolbarMiddleSpacingWidth,
                  );
                  final bool collapseAppBarActions =
                      trailingActionsAvailableWidth < chatActionsWidth;
                  final int visibleLeadingButtonCount =
                      (showCloseButton ? 1 : 0) +
                      (collapseAppBarActions ? 0 : navigationActionCount);
                  final double navigationActionsWidth =
                      navigationActionCount == 0
                      ? 0.0
                      : (AxiIconButton.kTapTargetSize * navigationActionCount) +
                            (leadingSpacing *
                                math.max(0, navigationActionCount - 1));
                  final double leadingWidth = visibleLeadingButtonCount == 0
                      ? collapsedLeadingWidth
                      : leadingInset +
                            (AxiIconButton.kTapTargetSize *
                                visibleLeadingButtonCount) +
                            (leadingSpacing *
                                math.max(0, visibleLeadingButtonCount - 1));
                  return Scaffold(
                    backgroundColor: context.colorScheme.background,
                    appBar: AppBar(
                      scrolledUnderElevation: 0,
                      forceMaterialTransparency: true,
                      automaticallyImplyLeading: false,
                      centerTitle: false,
                      titleSpacing: appBarTitleSpacing,
                      shape: Border(
                        bottom: BorderSide(color: context.colorScheme.border),
                      ),
                      actionsPadding: EdgeInsets.symmetric(
                        horizontal: appBarActionsPadding,
                      ),
                      leadingWidth: leadingWidth,
                      leading: visibleLeadingButtonCount == 0
                          ? null
                          : Padding(
                              padding: EdgeInsets.only(left: leadingInset),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (showCloseButton)
                                      AxiIconButton.ghost(
                                        iconData: LucideIcons.arrowLeft,
                                        tooltip: context.l10n.commonBack,
                                        onPressed: () {
                                          _dismissTextInputFocus();
                                          context
                                              .read<ChatsCubit>()
                                              .closeAllChats();
                                        },
                                      ),
                                    if (showCloseButton &&
                                        !collapseAppBarActions &&
                                        navigationActionCount > 0)
                                      SizedBox(width: leadingSpacing),
                                    if (!collapseAppBarActions &&
                                        navigationActionCount > 0)
                                      AppBarActions(
                                        actions: navigationActions,
                                        spacing: leadingSpacing,
                                        overflowBreakpoint: 0,
                                        availableWidth: navigationActionsWidth,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                      title: jid == null
                          ? const SizedBox.shrink()
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (showTitleAvatar)
                                  Builder(
                                    builder: (context) {
                                      final avatarData = chatEntity.avatarData(
                                        selfJid: selfIdentity.selfJid,
                                        selfAvatarPath: selfIdentity.avatarPath,
                                        selfAvatarLoading:
                                            selfIdentity.avatarLoading,
                                      );
                                      Widget avatar = avatarData.isAppIcon
                                          ? AxichatAppIconAvatar(
                                              size:
                                                  context.sizing.iconButtonSize,
                                            )
                                          : AvatarTransportBadgeOverlay(
                                              size:
                                                  context.sizing.iconButtonSize,
                                              transport:
                                                  chatEntity.defaultTransport,
                                              child: HydratedAxiAvatar(
                                                jid: avatarData.identifier!,
                                                colorSeed: avatarData.colorSeed,
                                                size: context
                                                    .sizing
                                                    .iconButtonSize,
                                                loading: avatarData.loading,
                                                avatarPath:
                                                    avatarData.avatarPath,
                                              ),
                                            );
                                      if (avatarTooltip != null) {
                                        avatar = AxiTooltip(
                                          builder: (context) =>
                                              Text(avatarTooltip),
                                          child: avatar,
                                        );
                                      }
                                      if (isGroupChat) {
                                        avatar = MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: GestureDetector(
                                            onTap: _showMembers,
                                            child: avatar,
                                          ),
                                        );
                                      }
                                      return avatar;
                                    },
                                  ),
                                if (showTitleAvatar)
                                  SizedBox(width: avatarTitleSpacing),
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Flexible(
                                            fit: FlexFit.loose,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (canRenameContact)
                                                  AxiPlainHeaderButton(
                                                    onPressed:
                                                        _promptContactRename,
                                                    semanticLabel: context
                                                        .l10n
                                                        .chatContactRenameTooltip,
                                                    child: Text(
                                                      state.chat?.displayName ??
                                                          '',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: titleStyle,
                                                    ),
                                                  )
                                                else
                                                  Text(
                                                    state.chat?.displayName ??
                                                        '',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: titleStyle,
                                                  ),
                                                if (secondaryLabel.isNotEmpty)
                                                  SelectableText(
                                                    secondaryLabel,
                                                    maxLines: 1,
                                                    style: subtitleStyle,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                      actions: [
                        if (jid != null)
                          BlocSelector<ChatSearchCubit, ChatSearchState, bool>(
                            selector: (state) => state.active,
                            builder: (context, searchActive) {
                              final l10n = context.l10n;
                              final colors = context.colorScheme;
                              final bool isPinnedPanelVisible =
                                  _pinnedPanelVisible;
                              final int importantCount = context
                                  .select<ImportantMessagesCubit, int>(
                                    (cubit) => cubit.state.items?.length ?? 0,
                                  );
                              final Color importantIconColor =
                                  _chatRoute.isImportant
                                  ? colors.primary
                                  : colors.foreground;
                              final Color pinnedIconColor = isPinnedPanelVisible
                                  ? colors.primary
                                  : colors.foreground;
                              final List<AppBarActionItem> chatActions =
                                  <AppBarActionItem>[
                                    if (isEmailBacked)
                                      AppBarActionItem(
                                        label: l10n.chatCollapseLongEmails,
                                        iconData: LucideIcons.minimize2,
                                        selected: _collapseLongEmailMessages,
                                        onPressed: () {
                                          setState(() {
                                            _collapseLongEmailMessages =
                                                !_collapseLongEmailMessages;
                                          });
                                        },
                                      ),
                                    if (isGroupChat)
                                      AppBarActionItem(
                                        label: l10n.chatRoomMembers,
                                        iconData: LucideIcons.users,
                                        onPressed: _showMembers,
                                      ),
                                    AppBarActionItem(
                                      label: searchActive
                                          ? l10n.chatSearchClose
                                          : l10n.chatSearchMessages,
                                      iconData: LucideIcons.search,
                                      selected: _chatRoute.isSearch,
                                      onPressed: () => context
                                          .read<ChatSearchCubit>()
                                          .toggleActive(),
                                    ),
                                    AppBarActionItem(
                                      label: l10n.chatAttachmentTooltip,
                                      iconData: LucideIcons.image,
                                      selected: _chatRoute.isGallery,
                                      onPressed: _openChatAttachments,
                                    ),
                                    AppBarActionItem(
                                      label: _chatRoute.isImportant
                                          ? l10n.commonClose
                                          : l10n.chatImportantMessagesTooltip,
                                      iconData: Icons.star_outline_rounded,
                                      icon: _ActionCountBadgeIcon(
                                        iconData: Icons.star_outline_rounded,
                                        count: importantCount,
                                        iconColor: importantIconColor,
                                      ),
                                      selected: _chatRoute.isImportant,
                                      onPressed: _toggleImportantMessagesRoute,
                                    ),
                                    AppBarActionItem(
                                      label: _pinnedPanelVisible
                                          ? l10n.commonClose
                                          : l10n.chatPinnedMessagesTooltip,
                                      iconData: pinnedIcon,
                                      icon: _PinnedBadgeIcon(
                                        iconData: pinnedIcon,
                                        count: pinnedCount,
                                        iconColor: pinnedIconColor,
                                      ),
                                      selected: _pinnedPanelVisible,
                                      onPressed: _togglePinnedMessages,
                                    ),
                                    if (chatCalendarAvailable)
                                      calendarFirstRoom
                                          ? AppBarActionItem(
                                              label: showingChatCalendar
                                                  ? l10n.sessionCapabilityChat
                                                  : l10n.homeRailCalendar,
                                              iconData: showingChatCalendar
                                                  ? LucideIcons.messagesSquare
                                                  : LucideIcons.calendarClock,
                                              onPressed: () {
                                                if (showingChatCalendar) {
                                                  _returnToMainRoute();
                                                  return;
                                                }
                                                _openChatCalendar();
                                              },
                                            )
                                          : AppBarActionItem(
                                              label: showingChatCalendar
                                                  ? l10n.commonClose
                                                  : l10n.homeRailCalendar,
                                              iconData:
                                                  LucideIcons.calendarClock,
                                              selected: showingChatCalendar,
                                              onPressed: () {
                                                if (showingChatCalendar) {
                                                  _closeChatCalendar();
                                                  return;
                                                }
                                                _openChatCalendar();
                                              },
                                            ),
                                    if (canShowSettings)
                                      AppBarActionItem(
                                        label: isSettingsRoute
                                            ? l10n.chatCloseSettings
                                            : l10n.chatSettings,
                                        iconData: LucideIcons.settings,
                                        selected: isSettingsRoute,
                                        onPressed: _toggleSettingsPanel,
                                      ),
                                  ];
                              final List<AppBarActionItem> combinedActions =
                                  collapseAppBarActions
                                  ? <AppBarActionItem>[
                                      ...navigationActions,
                                      ...chatActions,
                                    ]
                                  : chatActions;
                              return AppBarActions(
                                actions: combinedActions,
                                spacing: actionSpacing,
                                overflowBreakpoint: 0,
                                availableWidth: trailingActionsAvailableWidth,
                                forceCollapsed: collapseAppBarActions
                                    ? true
                                    : null,
                              );
                            },
                          )
                        else
                          const SizedBox.shrink(),
                      ],
                    ),
                    body: Builder(
                      builder: (context) {
                        final Widget chatMainBody = Column(
                          children: [
                            _ChatTopPanelVisibility(
                              visible: _chatRoute.isSearch,
                              child: const _ChatSearchPanel(),
                            ),
                            const ChatAlert(),
                            _UnknownSenderBanner(
                              readOnly: readOnly,
                              isSelfChat: isSelfChat,
                              onAddContact: _handleAddContact,
                              onReportSpam: () =>
                                  _handleSpamToggle(sendToSpam: true),
                            ),
                            Expanded(
                              child: IgnorePointer(
                                ignoring: !_chatRoute.allowsChatInteraction,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final spacing = context.spacing;
                                    final messageListHorizontalPadding =
                                        spacing.s;
                                    final pinnedPanelMinHeight = 0.0;
                                    final rawContentWidth = math.max(
                                      0.0,
                                      constraints.maxWidth,
                                    );
                                    final availableWidth = math.max(
                                      0.0,
                                      rawContentWidth -
                                          (messageListHorizontalPadding * 2),
                                    );
                                    final isCompact =
                                        availableWidth < smallScreen;
                                    final pinnedPanelMaxHeight = math.max(
                                      pinnedPanelMinHeight,
                                      constraints.maxHeight -
                                          _bottomSectionHeight,
                                    );
                                    final pinnedMessageIds = state
                                        .pinnedMessages
                                        .map((item) => item.messageStanzaId)
                                        .toSet();
                                    final attachmentsByMessageId =
                                        state.attachmentMetadataIdsByMessageId;
                                    final groupLeaderByMessageId =
                                        state.attachmentGroupLeaderByMessageId;
                                    _ensureMessageCaches(
                                      items: state.items,
                                      quotedMessagesById:
                                          state.quotedMessagesById,
                                      searchResults: searchResults,
                                      searchFiltering: searchFiltering,
                                      attachmentsByMessageId:
                                          attachmentsByMessageId,
                                      groupLeaderByMessageId:
                                          groupLeaderByMessageId,
                                    );
                                    final messageById = _cachedMessageById;
                                    const emptyAttachments = <String>[];
                                    final importantMessageIds = context
                                        .select<
                                          ImportantMessagesCubit,
                                          Set<String>
                                        >((cubit) {
                                          final items = cubit.state.items;
                                          if (items == null) {
                                            return const <String>{};
                                          }
                                          return items
                                              .map(
                                                (item) => item
                                                    .messageReferenceId
                                                    .trim(),
                                              )
                                              .where(
                                                (value) => value.isNotEmpty,
                                              )
                                              .toSet();
                                        });
                                    String messageKey(Message message) =>
                                        message.id ?? message.stanzaID;

                                    List<String> attachmentsForMessage(
                                      Message message,
                                    ) {
                                      final key = messageKey(message);
                                      return attachmentsByMessageId[key] ??
                                          emptyAttachments;
                                    }

                                    bool isPinnedMessage(Message message) {
                                      return message.referenceIds.any(
                                        pinnedMessageIds.contains,
                                      );
                                    }

                                    bool isImportantMessage(Message message) {
                                      return message.referenceIds.any(
                                        importantMessageIds.contains,
                                      );
                                    }

                                    final filteredItems = _cachedFilteredItems;
                                    final availabilityCoordinator =
                                        _readAvailabilityShareCoordinator(
                                          context,
                                          calendarAvailable:
                                              chatCalendarAvailable,
                                        );
                                    final availabilityShareOwnersById =
                                        <String, String>{};
                                    for (final item in filteredItems) {
                                      final availabilityMessage =
                                          item.calendarAvailabilityMessage;
                                      if (availabilityMessage == null) {
                                        continue;
                                      }
                                      availabilityMessage.maybeMap(
                                        share: (value) {
                                          final owner =
                                              value.share.overlay.owner;
                                          final bool isValid = item
                                              .senderMatchesClaimedJid(
                                                owner,
                                                roomState: state.roomState,
                                              );
                                          if (isValid) {
                                            availabilityShareOwnersById[value
                                                    .share
                                                    .id] =
                                                owner;
                                          }
                                        },
                                        orElse: () {},
                                      );
                                    }
                                    final isEmailChat =
                                        state.chat?.isEmailBacked == true;
                                    final loadingMessages =
                                        !state.messagesLoaded;
                                    final selectedMessages =
                                        _collectSelectedMessages(filteredItems);
                                    if (_multiSelectActive &&
                                        selectedMessages.isEmpty) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (!mounted) return;
                                            _clearMultiSelection();
                                          });
                                    }
                                    const compactBubbleWidthFraction = 0.8;
                                    const regularBubbleWidthFraction = 0.8;
                                    const selectionExtrasPreferredMaxWidth =
                                        500.0;
                                    final selectionCutoutDepth = spacing.m;
                                    final selectionOuterInset =
                                        selectionCutoutDepth +
                                        (SelectionIndicator.size / 2);
                                    final messageRowAvatarReservation =
                                        spacing.l;
                                    final baseBubbleMaxWidth =
                                        availableWidth *
                                        (isCompact
                                            ? compactBubbleWidthFraction
                                            : regularBubbleWidthFraction);
                                    final inboundAvatarReservation = isGroupChat
                                        ? messageRowAvatarReservation
                                        : 0.0;
                                    final inboundClampedBubbleWidth =
                                        baseBubbleMaxWidth.clamp(
                                          0.0,
                                          availableWidth -
                                              inboundAvatarReservation,
                                        );
                                    final outboundClampedBubbleWidth =
                                        baseBubbleMaxWidth.clamp(
                                          0.0,
                                          availableWidth,
                                        );
                                    final inboundMessageRowMaxWidth = math.min(
                                      availableWidth - inboundAvatarReservation,
                                      inboundClampedBubbleWidth +
                                          selectionOuterInset,
                                    );
                                    final outboundMessageRowMaxWidth = math.min(
                                      availableWidth,
                                      outboundClampedBubbleWidth +
                                          selectionOuterInset,
                                    );
                                    final messageRowMaxWidth = rawContentWidth;
                                    final revokedInviteTokens = <String>{
                                      for (final invite in filteredItems.where(
                                        (m) =>
                                            m.pseudoMessageType ==
                                            PseudoMessageType
                                                .mucInviteRevocation,
                                      ))
                                        if (invite.pseudoMessageData
                                                ?.containsKey('token') ==
                                            true)
                                          invite.pseudoMessageData?['token']
                                              as String,
                                    };
                                    const pinnedPreviewMessagePrefix =
                                        'pinned-preview:';

                                    final emptyStateLabel = searchFiltering
                                        ? context.l10n.chatEmptySearch
                                        : context.l10n.chatEmptyMessages;
                                    final xmppCapabilities =
                                        state.xmppCapabilities;
                                    final supportsMarkers =
                                        isEmailChat ||
                                        xmppCapabilities?.supportsMarkers ==
                                            true;
                                    final supportsReceipts =
                                        isEmailChat ||
                                        xmppCapabilities?.supportsReceipts ==
                                            true;
                                    final timelineItems =
                                        buildMainChatTimelineItems(
                                          messages: filteredItems,
                                          loadingMessages: loadingMessages,
                                          unreadBoundaryStanzaId:
                                              state.unreadBoundaryStanzaId,
                                          emptyStateCreatedAt:
                                              _selectionSpacerTimestamp,
                                          unreadDividerItemId:
                                              _unreadDividerMessageId,
                                          unreadDividerLabel: context
                                              .l10n
                                              .chatUnreadDividerLabel,
                                          emptyStateItemId:
                                              _emptyStateMessageId,
                                          emptyStateLabel: emptyStateLabel,
                                          isGroupChat: isGroupChat,
                                          isEmailChat: isEmailChat,
                                          profileJid: profileState()?.jid,
                                          resolvedEmailSelfJid:
                                              resolvedEmailSelfJid,
                                          currentUserId: currentUserId,
                                          selfUserId: user.id,
                                          selfDisplayName: user.firstName ?? '',
                                          selfAvatarPath: selfAvatarPath,
                                          myOccupantJid: myOccupantJid,
                                          selfNick: selfNick,
                                          roomState: state.roomState,
                                          roomMemberSections:
                                              state.roomMemberSections,
                                          chat: state.chat,
                                          messageById: messageById,
                                          shareContexts: shareContexts,
                                          shareReplies: shareReplies,
                                          emailFullHtmlByDeltaId:
                                              state.emailFullHtmlByDeltaId,
                                          revokedInviteTokens:
                                              revokedInviteTokens,
                                          inviteRoomFallbackLabel: context
                                              .l10n
                                              .chatInviteRoomFallbackLabel,
                                          inviteBodyLabel:
                                              context.l10n.chatInviteBodyLabel,
                                          inviteRevokedBodyLabel: context
                                              .l10n
                                              .chatInviteRevokedLabel,
                                          unknownAuthorLabel:
                                              context.l10n.commonUnknownLabel,
                                          inviteActionLabel: context
                                              .l10n
                                              .chatInviteActionLabel,
                                          supportsMarkers: supportsMarkers,
                                          supportsReceipts: supportsReceipts,
                                          attachmentsForMessage:
                                              attachmentsForMessage,
                                          reactionPreviewsForMessage:
                                              _reactionPreviewsForMessage,
                                          participantsForBanner:
                                              _participantsForBanner,
                                          avatarPathForBareJid:
                                              avatarPathForBareJid,
                                          ownerJidForShare: (shareId) =>
                                              availabilityShareOwnersById[shareId] ??
                                              availabilityCoordinator
                                                  ?.ownerJidForShare(shareId),
                                          errorLabel: (error) =>
                                              error.label(context.l10n),
                                          errorLabelWithBody: (error, body) =>
                                              context.l10n
                                                  .chatMessageErrorWithBody(
                                                    error.label(context.l10n),
                                                    body,
                                                  ),
                                        );
                                    final mainTimelineItems =
                                        <ChatTimelineItem>[
                                          ChatTimelineComposerOverlaySpacerItem(
                                            id: _composerOverlaySpacerMessageId,
                                            createdAt:
                                                _selectionSpacerTimestamp,
                                          ),
                                          ...timelineItems,
                                        ];
                                    late final MessageListOptions
                                    dashMessageListOptions;
                                    dashMessageListOptions = MessageListOptions(
                                      scrollController: _scrollController,
                                      scrollPhysics:
                                          const AlwaysScrollableScrollPhysics(
                                            parent: BouncingScrollPhysics(),
                                          ),
                                      separatorFrequency:
                                          SeparatorFrequency.days,
                                      dateSeparatorBuilder: (date) {
                                        if (date.isAtSameMomentAs(
                                          _selectionSpacerTimestamp,
                                        )) {
                                          return const SizedBox.shrink();
                                        }
                                        return DefaultDateSeparator(
                                          date: date,
                                          messageListOptions:
                                              dashMessageListOptions,
                                        );
                                      },
                                      typingBuilder: (_) =>
                                          const SizedBox.shrink(),
                                      onLoadEarlier:
                                          searchFiltering ||
                                              state.items.length %
                                                      ChatBloc
                                                          .messageBatchSize !=
                                                  0
                                          ? null
                                          : () async {
                                              final completer =
                                                  Completer<void>();
                                              context.read<ChatBloc>().add(
                                                ChatLoadEarlier(
                                                  completer: completer,
                                                ),
                                              );
                                              await completer.future;
                                            },
                                      loadEarlierBuilder: Padding(
                                        padding: EdgeInsets.all(
                                          context.spacing.m,
                                        ),
                                        child: const Center(
                                          child: AxiProgressIndicator(),
                                        ),
                                      ),
                                    );
                                    final composerHintText = isEmailComposer
                                        ? context.l10n.chatComposerEmailHint
                                        : context.l10n.chatComposerMessageHint;
                                    final settingsAnimationDuration = context
                                        .watch<SettingsCubit>()
                                        .animationDuration;
                                    final overlayAnimationDuration =
                                        settingsAnimationDuration;
                                    final quotedMessage =
                                        _quotedDraft ??
                                        (_debugShowAllComposerBanners &&
                                                filteredItems.isNotEmpty
                                            ? filteredItems.first
                                            : null);
                                    final quotedIsSelf = quotedMessage == null
                                        ? false
                                        : _isQuotedMessageFromSelf(
                                            quotedMessage: quotedMessage,
                                            isGroupChat: isGroupChat,
                                            roomState: state.roomState,
                                            fallbackSelfNick: selfNick,
                                            currentUserId: currentUserId,
                                          );
                                    final quotedSenderLabel =
                                        quotedMessage == null
                                        ? null
                                        : quotedIsSelf
                                        ? context.l10n.chatSenderYou
                                        : _quotedSenderLabel(
                                            quotedMessage: quotedMessage,
                                            isGroupChat: isGroupChat,
                                            roomState: state.roomState,
                                            chatDisplayName:
                                                resolvedDirectChatDisplayName,
                                            l10n: context.l10n,
                                          );
                                    final composerErrorKey =
                                        state.composerError;
                                    final composerErrorMessage =
                                        composerErrorKey?.label(context.l10n);
                                    final onComposerErrorCleared =
                                        state
                                                .emailSyncState
                                                .requiresAttention &&
                                            composerErrorKey ==
                                                ChatMessageKey
                                                    .messageErrorServiceUnavailable
                                        ? null
                                        : () => context.read<ChatBloc>().add(
                                            const ChatComposerErrorCleared(),
                                          );
                                    final composerNotices = _ComposerNotices(
                                      composerError: composerErrorMessage,
                                      onComposerErrorCleared:
                                          onComposerErrorCleared,
                                      showAttachmentWarning:
                                          showAttachmentWarning,
                                      retryReport: retryReport,
                                      retryShareId: retryShareId,
                                      onFanOutRetry: onFanOutRetry,
                                    );
                                    final showComposerNotices =
                                        composerErrorMessage?.isNotEmpty ==
                                            true ||
                                        showAttachmentWarning ||
                                        (retryReport != null &&
                                            retryShareId != null &&
                                            retryReport.statuses.any(
                                              (status) =>
                                                  status.state ==
                                                  FanOutRecipientState.failed,
                                            ));
                                    Widget? overlayNotices = showComposerNotices
                                        ? composerNotices
                                        : (_debugShowAllComposerBanners
                                              ? const _DebugComposerNotices()
                                              : null);
                                    var overlayQuotedMessage = quotedMessage;
                                    var overlayQuotedSenderLabel =
                                        quotedSenderLabel;
                                    var overlayQuotedIsSelf = quotedIsSelf;
                                    final demoTypingAvatars =
                                        _demoTypingParticipants(state);
                                    final typingAvatars =
                                        demoTypingAvatars.isNotEmpty
                                        ? demoTypingAvatars
                                        : state.typingParticipants.isNotEmpty
                                        ? state.typingParticipants
                                        : const <String>[];
                                    final typingAvatarPaths =
                                        <String, String>{};
                                    for (final participant in typingAvatars) {
                                      final path =
                                          avatarPathForTypingParticipant(
                                            participant,
                                          );
                                      if (path == null || path.isEmpty) {
                                        continue;
                                      }
                                      typingAvatarPaths[participant] = path;
                                    }
                                    final typingVisible =
                                        state.typing == true ||
                                        typingAvatars.isNotEmpty;
                                    Widget? composerOverlayBanner;
                                    final Widget bottomContent;
                                    if (_multiSelectActive &&
                                        selectedMessages.isNotEmpty) {
                                      final targets = List<Message>.of(
                                        selectedMessages,
                                        growable: false,
                                      );
                                      final canReact =
                                          !isEmailChat &&
                                          (state.xmppCapabilities
                                                  ?.supportsFeature(
                                                    mox.messageReactionsXmlns,
                                                  ) ??
                                              false);
                                      composerOverlayBanner = _MessageSelectionToolbar(
                                        count: targets.length,
                                        onClear: _clearMultiSelection,
                                        onCopy: () => _copySelectedMessages(
                                          List<Message>.of(targets),
                                        ),
                                        onShare: () => _shareSelectedMessages(
                                          List<Message>.of(targets),
                                        ),
                                        shareStatus: _shareRequestStatus,
                                        onForward: () =>
                                            _forwardSelectedMessages(
                                              List<Message>.of(targets),
                                            ),
                                        onAddToCalendar: () =>
                                            _addSelectedToCalendar(
                                              List<Message>.of(targets),
                                            ),
                                        showReactions: canReact,
                                        onReactionSelected: canReact
                                            ? (emoji) =>
                                                  _toggleQuickReactionForMessages(
                                                    targets,
                                                    emoji,
                                                  )
                                            : null,
                                        onReactionPicker: canReact
                                            ? () =>
                                                  _handleMultiReactionSelection(
                                                    List<Message>.of(targets),
                                                  )
                                            : null,
                                      );
                                      bottomContent = const SizedBox.shrink();
                                    } else if (widget.readOnly) {
                                      _ensureRecipientBarHeightCleared();
                                      composerOverlayBanner =
                                          const _ReadOnlyComposerBanner();
                                      bottomContent = const SizedBox.shrink();
                                    } else {
                                      final visibilityLabel =
                                          _recipientVisibilityLabel(
                                            chat: state.chat,
                                            recipients: recipients,
                                          );
                                      final expandedComposerSeed =
                                          _expandedComposerSeed;
                                      final Widget composerChild;
                                      if (expandedComposerSeed != null) {
                                        final locate = context.read;
                                        composerChild =
                                            _InlineExpandedDraftComposerSection(
                                              key: const ValueKey<String>(
                                                'expanded-composer',
                                              ),
                                              seed: expandedComposerSeed,
                                              locate: locate,
                                              onUnexpand: () =>
                                                  _collapseExpandedDraftComposer(
                                                    clearInlineComposer: false,
                                                  ),
                                              onClosed: () =>
                                                  _collapseExpandedDraftComposer(
                                                    clearInlineComposer: true,
                                                  ),
                                              onDiscarded: () =>
                                                  _collapseExpandedDraftComposer(
                                                    clearInlineComposer: true,
                                                  ),
                                              onDraftSaved: (draftId) {
                                                if (!mounted) return;
                                                setState(() {
                                                  _expandedComposerDraftId =
                                                      draftId;
                                                  final current =
                                                      _expandedComposerSeed;
                                                  if (current == null) {
                                                    return;
                                                  }
                                                  _expandedComposerSeed =
                                                      current.copyWith(
                                                        id: draftId,
                                                      );
                                                });
                                              },
                                            );
                                        bottomContent = _ComposerModeTransition(
                                          duration: overlayAnimationDuration,
                                          child: composerChild,
                                        );
                                      } else {
                                        composerChild = _ChatComposerSection(
                                          key: const ValueKey<String>(
                                            'inline-composer',
                                          ),
                                          enabled:
                                              !isWelcomeChat &&
                                              !roomBootstrapInProgress &&
                                              !roomJoinFailed,
                                          hintText: composerHintText,
                                          recipients: recipients,
                                          availableChats: availableChats,
                                          latestStatuses: latestStatuses,
                                          visibilityLabel: visibilityLabel,
                                          pendingAttachments:
                                              pendingAttachments,
                                          composerHasText: _composerHasContent,
                                          composerMinLines: 1,
                                          composerMaxLines: 6,
                                          selfJid: selfXmppJid,
                                          selfIdentity: selfIdentity,
                                          composerError: null,
                                          onComposerErrorCleared: null,
                                          showAttachmentWarning: false,
                                          retryReport: null,
                                          retryShareId: null,
                                          onFanOutRetry: null,
                                          subjectController: _subjectController,
                                          subjectFocusNode: _subjectFocusNode,
                                          textController: _textController,
                                          textFocusNode: _focusNode,
                                          tapRegionGroup:
                                              _composerTapRegionGroup,
                                          onSubjectSubmitted: () =>
                                              _focusNode.requestFocus(),
                                          showExpandDraftAction:
                                              isEmailComposer,
                                          expandDraftEnabled:
                                              !_expandingComposerDraft,
                                          onExpandDraftPressed: () =>
                                              _expandEmailComposerToDraft(
                                                state,
                                              ),
                                          onRecipientAdded:
                                              _handleRecipientAdded,
                                          onRecipientRemoved:
                                              _handleRecipientRemoved,
                                          onRecipientToggled:
                                              _handleRecipientToggled,
                                          onAttachmentRetry: (pending) {
                                            final chat = chatEntity;
                                            if (chat == null) {
                                              return;
                                            }
                                            unawaited(
                                              _retryPendingAttachment(
                                                pending,
                                                chat: chat,
                                                quotedDraft: _quotedDraft,
                                                supportsHttpFileUpload: state
                                                    .supportsHttpFileUpload,
                                                settingsSnapshot:
                                                    settingsSnapshot,
                                              ),
                                            );
                                          },
                                          onAttachmentRemove:
                                              _removePendingAttachment,
                                          onPendingAttachmentPressed:
                                              _handlePendingAttachmentPressed,
                                          onPendingAttachmentLongPressed:
                                              _handlePendingAttachmentLongPressed,
                                          pendingAttachmentMenuBuilder:
                                              (
                                                pending,
                                              ) => _pendingAttachmentMenuItems(
                                                pending,
                                                chat: chatEntity,
                                                quotedDraft: _quotedDraft,
                                                supportsHttpFileUpload: state
                                                    .supportsHttpFileUpload,
                                                settingsSnapshot:
                                                    settingsSnapshot,
                                              ),
                                          buildComposerAccessories:
                                              ({required bool canSend}) =>
                                                  _composerAccessories(
                                                    canSend: canSend,
                                                    attachmentsEnabled:
                                                        attachmentsEnabled,
                                                    chatState: state,
                                                    settingsSnapshot:
                                                        settingsSnapshot,
                                                  ),
                                          onTaskDropped: _handleTaskDrop,
                                          sendOnEnter: composerSendOnEnter,
                                          onSend: () => _handleSendMessage(
                                            chatState: state,
                                            settingsSnapshot: settingsSnapshot,
                                          ),
                                        );
                                        bottomContent = _ComposerModeTransition(
                                          duration: overlayAnimationDuration,
                                          child: composerChild,
                                        );
                                        if (roomBootstrapInProgress) {
                                          composerOverlayBanner =
                                              const _RoomBootstrapComposerBanner();
                                        } else if (roomJoinFailureState !=
                                            null) {
                                          composerOverlayBanner =
                                              _RoomJoinFailureComposerBanner(
                                                detail:
                                                    roomJoinFailureState
                                                        .joinErrorText ??
                                                    roomJoinFailureState
                                                        .selfPresenceReason,
                                              );
                                        }
                                      }
                                    }
                                    composerOverlayBanner ??=
                                        _debugShowAllComposerBanners
                                        ? const _DebugComposerOverlayBanner()
                                        : null;
                                    if (_debugCycleComposerBanners) {
                                      overlayQuotedMessage = null;
                                      overlayQuotedSenderLabel = null;
                                      overlayQuotedIsSelf = false;
                                      overlayNotices = null;
                                      composerOverlayBanner =
                                          _DebugComposerBannerCycle(
                                            animationDuration:
                                                overlayAnimationDuration,
                                            interval: context
                                                .motion
                                                .statusBannerSuccessDuration,
                                          );
                                    }
                                    return _ChatConversationPane(
                                      pinnedPanel: _ChatPinnedMessagesPanel(
                                        key: ValueKey(
                                          '$_chatPinnedPanelKeyPrefix${chatEntity?.jid ?? _chatPanelKeyFallback}',
                                        ),
                                        chat: chatEntity,
                                        visible: _pinnedPanelVisible,
                                        maxHeight: pinnedPanelMaxHeight,
                                        accountJid: accountJidForPins,
                                        pinnedMessages: state.pinnedMessages,
                                        pinnedMessagesLoaded:
                                            state.pinnedMessagesLoaded,
                                        pinnedMessagesHydrating:
                                            state.pinnedMessagesHydrating,
                                        onClose: _closePinnedMessages,
                                        canTogglePins: canTogglePins,
                                        canShowCalendarTasks:
                                            chatCalendarAvailable,
                                        canAddToPersonalCalendar:
                                            personalCalendarAvailable,
                                        canAddToChatCalendar:
                                            chatCalendarAvailable,
                                        onCopyTaskToPersonalCalendar:
                                            personalCalendarAvailable
                                            ? _copyTaskToPersonalCalendar
                                            : null,
                                        onCopyCriticalPathToPersonalCalendar:
                                            personalCalendarAvailable
                                            ? _copyCriticalPathToPersonalCalendar
                                            : null,
                                        locate: context.read,
                                        roomState: state.roomState,
                                        metadataFor: (metadataId) =>
                                            _metadataFor(
                                              state: state,
                                              metadataId: metadataId,
                                            ),
                                        metadataPendingFor: (metadataId) =>
                                            _metadataPending(
                                              state: state,
                                              metadataId: metadataId,
                                            ),
                                        attachmentsBlocked:
                                            attachmentsBlockedForChat,
                                        isOneTimeAttachmentAllowed:
                                            _isOneTimeAttachmentAllowed,
                                        shouldAllowAttachment:
                                            _shouldAllowAttachment,
                                        onApproveAttachment: _approveAttachment,
                                        previewTimelineItemForItem: (item) {
                                          final message = item.message;
                                          if (message == null) {
                                            return null;
                                          }
                                          return buildPreviewChatTimelineMessageItem(
                                            message: message,
                                            messageIdPrefix:
                                                pinnedPreviewMessagePrefix,
                                            shownSubjectShares: <String>{},
                                            isGroupChat: isGroupChat,
                                            isEmailChat: isEmailChat,
                                            profileJid: profileState()?.jid,
                                            resolvedEmailSelfJid:
                                                resolvedEmailSelfJid,
                                            currentUserId: currentUserId,
                                            selfUserId: user.id,
                                            selfDisplayName:
                                                user.firstName ?? _emptyText,
                                            selfAvatarPath: selfAvatarPath,
                                            myOccupantJid: myOccupantJid,
                                            selfNick: selfNick,
                                            roomState: state.roomState,
                                            roomMemberSections:
                                                state.roomMemberSections,
                                            chat: state.chat,
                                            messageById: messageById,
                                            shareContexts: shareContexts,
                                            shareReplies: shareReplies,
                                            emailFullHtmlByDeltaId:
                                                state.emailFullHtmlByDeltaId,
                                            revokedInviteTokens:
                                                revokedInviteTokens,
                                            inviteRoomFallbackLabel: context
                                                .l10n
                                                .chatInviteRoomFallbackLabel,
                                            inviteBodyLabel: context
                                                .l10n
                                                .chatInviteBodyLabel,
                                            inviteRevokedBodyLabel: context
                                                .l10n
                                                .chatInviteRevokedLabel,
                                            unknownAuthorLabel:
                                                context.l10n.commonUnknownLabel,
                                            inviteActionLabel: context
                                                .l10n
                                                .chatInviteActionLabel,
                                            supportsMarkers: supportsMarkers,
                                            supportsReceipts: supportsReceipts,
                                            attachmentsForMessage:
                                                attachmentsForMessage,
                                            reactionPreviewsForMessage:
                                                _reactionPreviewsForMessage,
                                            participantsForBanner:
                                                _participantsForBanner,
                                            avatarPathForBareJid:
                                                avatarPathForBareJid,
                                            ownerJidForShare: (shareId) =>
                                                availabilityShareOwnersById[shareId] ??
                                                availabilityCoordinator
                                                    ?.ownerJidForShare(shareId),
                                            errorLabel: (error) =>
                                                error.label(context.l10n),
                                            errorLabelWithBody: (error, body) =>
                                                context.l10n
                                                    .chatMessageErrorWithBody(
                                                      error.label(context.l10n),
                                                      body,
                                                    ),
                                          );
                                        },
                                        resolvedHtmlBodyFor: (message) {
                                          final deltaMessageId =
                                              message.deltaMsgId;
                                          if (deltaMessageId == null) {
                                            return message.htmlBody;
                                          }
                                          return state
                                                  .emailFullHtmlByDeltaId[deltaMessageId] ??
                                              message.htmlBody;
                                        },
                                        resolvedQuotedTextFor: (message) {
                                          final deltaMessageId =
                                              message.deltaMsgId;
                                          if (deltaMessageId == null) {
                                            return null;
                                          }
                                          return state
                                              .emailQuotedTextByDeltaId[deltaMessageId];
                                        },
                                        onMessageLinkTap: _handleLinkTap,
                                      ),
                                      timelineViewport: _ChatTimelineViewport(
                                        loadingMessages: loadingMessages,
                                        messageListKey: _messageListKey,
                                        onPointerMove: _handleOutsideTapMove,
                                        onPointerUp: _handleOutsideTapUp,
                                        onPointerCancel:
                                            _handleOutsideTapCancel,
                                        messageList: MediaQuery.removePadding(
                                          context: context,
                                          removeLeft: true,
                                          removeRight: true,
                                          child: _ChatMessageList(
                                            items: mainTimelineItems,
                                            scrollToBottomOptions:
                                                const ScrollToBottomOptions(),
                                            itemBuilder: (currentItem, previous, next) => _ChatTimelineItemView(
                                              currentItem: currentItem,
                                              previous: previous,
                                              next: next,
                                              state: state,
                                              chatEntity: chatEntity,
                                              currentUserId: currentUserId,
                                              selfNick: selfNick,
                                              selfXmppJid: selfXmppJid,
                                              myOccupantJid: myOccupantJid,
                                              resolvedDirectChatDisplayName:
                                                  resolvedDirectChatDisplayName,
                                              readOnly: widget.readOnly,
                                              isGroupChat: isGroupChat,
                                              isEmailChat: isEmailChat,
                                              isWelcomeChat: isWelcomeChat,
                                              attachmentsBlockedForChat:
                                                  attachmentsBlockedForChat,
                                              multiSelectActive:
                                                  _multiSelectActive,
                                              selectedMessageId:
                                                  _selectedMessageId,
                                              canTogglePins: canTogglePins,
                                              availabilityActorId:
                                                  availabilityActorId,
                                              availabilityShareOwnersById:
                                                  availabilityShareOwnersById,
                                              availabilityCoordinator:
                                                  availabilityCoordinator,
                                              normalizedXmppSelfJid:
                                                  normalizedXmppSelfJid,
                                              normalizedEmailSelfJid:
                                                  normalizedEmailSelfJid,
                                              personalCalendarAvailable:
                                                  personalCalendarAvailable,
                                              chatCalendarAvailable:
                                                  chatCalendarAvailable,
                                              messageFontSize: settingsState
                                                  .messageTextSize
                                                  .fontSize,
                                              availableWidth: availableWidth,
                                              inboundMessageRowMaxWidth:
                                                  inboundMessageRowMaxWidth,
                                              outboundMessageRowMaxWidth:
                                                  outboundMessageRowMaxWidth,
                                              inboundClampedBubbleWidth:
                                                  inboundClampedBubbleWidth,
                                              outboundClampedBubbleWidth:
                                                  outboundClampedBubbleWidth,
                                              messageRowMaxWidth:
                                                  messageRowMaxWidth,
                                              selectionExtrasPreferredMaxWidth:
                                                  selectionExtrasPreferredMaxWidth,
                                              overlayQuotedMessage:
                                                  overlayQuotedMessage,
                                              overlayQuotedSenderLabel:
                                                  overlayQuotedSenderLabel,
                                              overlayQuotedIsSelf:
                                                  overlayQuotedIsSelf,
                                              overlayNotices: overlayNotices,
                                              composerOverlayBanner:
                                                  composerOverlayBanner,
                                              overlayAnimationDuration:
                                                  overlayAnimationDuration,
                                              shareRequestStatus:
                                                  _shareRequestStatus,
                                              bubbleRegionRegistry:
                                                  _bubbleRegionRegistry,
                                              selectionTapRegionGroup:
                                                  _selectionTapRegionGroup,
                                              messageKeys: _messageKeys,
                                              bubbleWidthByMessageId:
                                                  _bubbleWidthByMessageId,
                                              shouldAnimateMessage:
                                                  _shouldAnimateMessage,
                                              isPinnedMessage: isPinnedMessage,
                                              isImportantMessage:
                                                  isImportantMessage,
                                              onTapOutsideRequested:
                                                  _armOutsideTapDismiss,
                                              resolveViewData:
                                                  _resolveTimelineMessageViewData,
                                              resolveInteractionData:
                                                  _resolveTimelineMessageInteractionData,
                                              composeBubbleContent:
                                                  _composeTimelineMessageBubbleContent,
                                              onReplyRequested:
                                                  _handleReplyRequested,
                                              onForwardRequested:
                                                  _handleForward,
                                              onCopyRequested: _copyMessage,
                                              onShareRequested: _shareMessage,
                                              onAddToCalendarRequested:
                                                  _handleAddToCalendar,
                                              onDetailsRequested:
                                                  _showMessageDetailsById,
                                              onStartMultiSelectRequested:
                                                  (message) => unawaited(
                                                    _startMultiSelect(message),
                                                  ),
                                              onResendRequested:
                                                  _handleMessageResendRequested,
                                              onEditRequested:
                                                  _handleEditMessage,
                                              onImportantToggleRequested:
                                                  _handleImportantToggleRequested,
                                              onPinToggleRequested:
                                                  _handlePinToggleRequested,
                                              onRevokeInviteRequested:
                                                  _handleInviteRevocationRequested,
                                              onBubbleTapRequested:
                                                  _handleTimelineBubbleTap,
                                              onToggleMultiSelectRequested:
                                                  _toggleMultiSelectMessage,
                                              onToggleQuickReactionRequested:
                                                  _toggleQuickReaction,
                                              onReactionSelectionRequested:
                                                  _handleReactionSelection,
                                              onRecipientTap:
                                                  _openChatFromParticipant,
                                              onBubbleSizeChanged:
                                                  _updateMessageBubbleWidth,
                                            ),
                                            messageListOptions:
                                                dashMessageListOptions,
                                            readOnly: true,
                                          ),
                                        ),
                                        typingVisible: typingVisible,
                                        typingAvatars: typingAvatars,
                                        typingAvatarPaths: typingAvatarPaths,
                                        quotedMessage: overlayQuotedMessage,
                                        quotedSenderLabel:
                                            overlayQuotedSenderLabel,
                                        quotedIsSelf: overlayQuotedIsSelf,
                                        onClearQuote: _quotedDraft == null
                                            ? () {}
                                            : () => setState(() {
                                                _quotedDraft = null;
                                              }),
                                        notices: overlayNotices,
                                        banner: composerOverlayBanner,
                                        overlayAnimationDuration:
                                            overlayAnimationDuration,
                                      ),
                                      bottomPane: _ChatComposerBottomPane(
                                        maxHeight: constraints.maxHeight,
                                        onSizeChange:
                                            _updateBottomSectionHeight,
                                        child: bottomContent,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                        final Widget calendarOverlay = _ChatCalendarOverlay(
                          key: ValueKey(
                            '$_chatCalendarPanelKeyPrefix${chatEntity?.jid ?? _chatPanelKeyFallback}',
                          ),
                          chat: chatEntity,
                          calendarAvailable: chatCalendarAvailable,
                        );
                        final Widget overlayChild = switch (_chatRoute) {
                          ChatRouteIndex.main => const SizedBox.expand(),
                          ChatRouteIndex.search => const SizedBox.expand(),
                          ChatRouteIndex.details => _ChatDetailsOverlay(
                            onAddRecipient: _handleRecipientAddedFromChat,
                            loadedEmailImageMessageIds:
                                _loadedEmailImageMessageIds,
                            onEmailImagesApproved: _handleEmailImagesApproved,
                          ),
                          ChatRouteIndex.settings => _ChatSettingsOverlay(
                            state: state,
                            onViewFilterChanged: _setViewFilter,
                            onToggleNotifications: _toggleNotifications,
                            onSpamToggle: (sendToSpam) =>
                                _handleSpamToggle(sendToSpam: sendToSpam),
                            onRenameContact: canRenameContact
                                ? _promptContactRename
                                : null,
                            isChatBlocked: isChatBlocked,
                            blocklistEntry: chatBlocklistEntry,
                            blockAddress: blockAddress,
                          ),
                          ChatRouteIndex.important => _ChatImportantOverlay(
                            onMessageSelected: _handleImportantMessageSelected,
                          ),
                          ChatRouteIndex.gallery => _ChatGalleryOverlay(
                            chat: chatEntity,
                          ),
                          ChatRouteIndex.calendar => const SizedBox.expand(),
                        };

                        final bool isDesktopPlatform =
                            EnvScope.maybeOf(context)?.isDesktopPlatform ??
                            false;
                        final bool isLeavingToMain =
                            _chatRoute.isMain && !_previousChatRoute.isMain;
                        final bool isOverlaySwap =
                            !_chatRoute.isMain && !_previousChatRoute.isMain;
                        final bool isCalendarEnter = _chatRoute.isCalendar;
                        final Key chatRouteKey = ValueKey(_chatRoute);
                        final Duration overlayDuration =
                            isDesktopPlatform &&
                                (_chatRoute.isCalendar ||
                                    _previousChatRoute.isCalendar)
                            ? Duration.zero
                            : context.watch<SettingsCubit>().animationDuration;
                        final Widget overlayStack = PageTransitionSwitcher(
                          reverse: isLeavingToMain,
                          duration: overlayDuration,
                          layoutBuilder: (entries) =>
                              Stack(fit: StackFit.expand, children: entries),
                          transitionBuilder:
                              (child, primaryAnimation, secondaryAnimation) {
                                final bool isExiting =
                                    child.key != chatRouteKey;
                                final Animation<double> enterAnimation =
                                    CurvedAnimation(
                                      parent: primaryAnimation,
                                      curve: _chatOverlayFadeCurve,
                                      reverseCurve: Curves.easeInCubic,
                                    );
                                final Animation<double> exitAnimation =
                                    CurvedAnimation(
                                      parent: isLeavingToMain
                                          ? primaryAnimation
                                          : secondaryAnimation,
                                      curve: _chatOverlayFadeCurve,
                                      reverseCurve: Curves.easeInCubic,
                                    );
                                if (isExiting) {
                                  final Widget exiting = isOverlaySwap
                                      ? child
                                      : FadeTransition(
                                          opacity: exitAnimation,
                                          child: child,
                                        );
                                  return IgnorePointer(
                                    ignoring: true,
                                    child: ExcludeSemantics(
                                      excluding: true,
                                      child: exiting,
                                    ),
                                  );
                                }
                                final Widget entering = isCalendarEnter
                                    ? (isDesktopPlatform
                                          ? FadeTransition(
                                              opacity: enterAnimation,
                                              child: child,
                                            )
                                          : SlideTransition(
                                              position: Tween<Offset>(
                                                begin: _chatCalendarSlideOffset,
                                                end: Offset.zero,
                                              ).animate(enterAnimation),
                                              child: FadeScaleTransition(
                                                animation: enterAnimation,
                                                child: child,
                                              ),
                                            ))
                                    : FadeTransition(
                                        opacity: enterAnimation,
                                        child: child,
                                      );
                                return IgnorePointer(
                                  ignoring: isExiting,
                                  child: ExcludeSemantics(
                                    excluding: isExiting,
                                    child: entering,
                                  ),
                                );
                              },
                          child: KeyedSubtree(
                            key: chatRouteKey,
                            child: overlayChild,
                          ),
                        );
                        final Widget calendarOverlayVisibility =
                            _ChatCalendarOverlayVisibility(
                              visible: _chatRoute.isCalendar,
                              duration: overlayDuration,
                              curve: _chatOverlayFadeCurve,
                              useDesktopFade: isDesktopPlatform,
                              child: calendarOverlay,
                            );
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            chatMainBody,
                            overlayStack,
                            calendarOverlayVisibility,
                          ],
                        );
                      },
                    ),
                  );
                },
              );
              final Widget content = _ChatCalendarScope(
                chat: chatEntity,
                calendarAvailable: chatCalendarAvailable,
                coordinator: resolvedChatCalendarCoordinator,
                storage: storage,
                xmppService: context.read<XmppService>(),
                emailService:
                    context
                        .watch<SettingsCubit>()
                        .state
                        .endpointConfig
                        .smtpEnabled
                    ? context.read<EmailService>()
                    : null,
                reminderController: context.read<CalendarReminderController>(),
                availabilityCoordinator: _readAvailabilityShareCoordinator(
                  context,
                  calendarAvailable: storageManager.isAuthStorageReady,
                ),
                child: scaffold,
              );
              final colors = context.colorScheme;
              return Container(
                decoration: BoxDecoration(
                  color: colors.background,
                  border: Border(left: context.borderSide),
                ),
                child: content,
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
      onTaskAdded: (task) {
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
      onTaskAdded: (task) {
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

class _ActionCountBadgeIcon extends StatelessWidget {
  const _ActionCountBadgeIcon({
    required this.iconData,
    required this.count,
    required this.iconColor,
  });

  final IconData iconData;
  final int count;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final sizing = context.sizing;
    final double iconSize = context.iconTheme.size ?? sizing.iconButtonIconSize;
    final Icon icon = Icon(iconData, size: iconSize, color: iconColor);
    if (count <= _pinnedBadgeHiddenCount) {
      return icon;
    }

    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          PositionedDirectional(
            top: -spacing.xs,
            end: -spacing.xs,
            child: AxiCountBadge(
              count: count,
              diameter: sizing.menuItemIconSize,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedBadgeIcon extends StatelessWidget {
  const _PinnedBadgeIcon({
    required this.iconData,
    required this.count,
    required this.iconColor,
  });

  final IconData iconData;
  final int count;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return _ActionCountBadgeIcon(
      iconData: iconData,
      count: count,
      iconColor: iconColor,
    );
  }
}

class _ChatPinnedMessagesPanel extends StatefulWidget {
  const _ChatPinnedMessagesPanel({
    super.key,
    required this.chat,
    required this.visible,
    required this.maxHeight,
    required this.accountJid,
    required this.pinnedMessages,
    required this.pinnedMessagesLoaded,
    required this.pinnedMessagesHydrating,
    required this.onClose,
    required this.canTogglePins,
    required this.canShowCalendarTasks,
    required this.canAddToPersonalCalendar,
    required this.canAddToChatCalendar,
    required this.onCopyTaskToPersonalCalendar,
    required this.onCopyCriticalPathToPersonalCalendar,
    required this.locate,
    required this.roomState,
    required this.metadataFor,
    required this.metadataPendingFor,
    required this.attachmentsBlocked,
    required this.isOneTimeAttachmentAllowed,
    required this.shouldAllowAttachment,
    required this.onApproveAttachment,
    required this.previewTimelineItemForItem,
    required this.resolvedHtmlBodyFor,
    required this.resolvedQuotedTextFor,
    required this.onMessageLinkTap,
  });

  final chat_models.Chat? chat;
  final bool visible;
  final double maxHeight;
  final String? accountJid;
  final List<PinnedMessageItem> pinnedMessages;
  final bool pinnedMessagesLoaded;
  final bool pinnedMessagesHydrating;
  final VoidCallback onClose;
  final bool canTogglePins;
  final bool canShowCalendarTasks;
  final bool canAddToPersonalCalendar;
  final bool canAddToChatCalendar;
  final Future<String?> Function(CalendarTask task)?
  onCopyTaskToPersonalCalendar;
  final Future<bool> Function(
    CalendarModel model,
    String pathId,
    Set<String> taskIds,
  )?
  onCopyCriticalPathToPersonalCalendar;
  final T Function<T>() locate;
  final RoomState? roomState;
  final FileMetadataData? Function(String) metadataFor;
  final bool Function(String) metadataPendingFor;
  final bool attachmentsBlocked;
  final bool Function(String stanzaId) isOneTimeAttachmentAllowed;
  final bool Function({required bool isSelf, required chat_models.Chat? chat})
  shouldAllowAttachment;
  final Future<void> Function({
    required Message message,
    required String senderJid,
    required String stanzaId,
    required bool isSelf,
    required bool isEmailChat,
    String? senderEmail,
  })
  onApproveAttachment;
  final ChatTimelineMessageItem? Function(PinnedMessageItem item)
  previewTimelineItemForItem;
  final String? Function(Message message) resolvedHtmlBodyFor;
  final String? Function(Message message) resolvedQuotedTextFor;
  final ValueChanged<String> onMessageLinkTap;

  @override
  State<_ChatPinnedMessagesPanel> createState() =>
      _ChatPinnedMessagesPanelState();
}

class _ChatPinnedMessagesPanelState extends State<_ChatPinnedMessagesPanel> {
  @override
  void initState() {
    super.initState();
    _requestPinnedHydration();
  }

  @override
  void didUpdateWidget(covariant _ChatPinnedMessagesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool becameVisible = !oldWidget.visible && widget.visible;
    final bool pinnedChanged =
        oldWidget.pinnedMessages != widget.pinnedMessages;
    if (becameVisible || (widget.visible && pinnedChanged)) {
      _requestPinnedHydration();
    }
  }

  void _requestPinnedHydration() {
    if (!widget.visible) {
      return;
    }
    final hasMissingMessage = widget.pinnedMessages.any(
      (item) => item.message == null && item.messageStanzaId.trim().isNotEmpty,
    );
    if (!hasMissingMessage) {
      return;
    }
    context.read<ChatBloc>().add(const ChatPinnedMessagesOpened());
  }

  @override
  Widget build(BuildContext context) {
    final currentChat = widget.chat;
    if (currentChat == null) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final showPanel = widget.visible && widget.maxHeight > (0.0);
    final showLoading = showPanel && !widget.pinnedMessagesLoaded;
    final Widget panelBody = LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 0) {
          return const SizedBox.shrink();
        }
        if (showLoading) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.m),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [AxiProgressIndicator(color: colors.mutedForeground)],
            ),
          );
        }
        if (widget.pinnedMessages.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.m),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    l10n.chatPinnedEmptyState,
                    textAlign: TextAlign.center,
                    style: context.textTheme.muted.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          primary: false,
          physics: const ClampingScrollPhysics(),
          itemCount: widget.pinnedMessages.length,
          itemBuilder: (context, index) {
            final item = widget.pinnedMessages[index];
            return _PinnedMessageTile(
              item: item,
              chat: currentChat,
              roomState: widget.roomState,
              canTogglePins: widget.canTogglePins,
              canShowCalendarTasks: widget.canShowCalendarTasks,
              canAddToPersonalCalendar: widget.canAddToPersonalCalendar,
              canAddToChatCalendar: widget.canAddToChatCalendar,
              onCopyTaskToPersonalCalendar: widget.onCopyTaskToPersonalCalendar,
              onCopyCriticalPathToPersonalCalendar:
                  widget.onCopyCriticalPathToPersonalCalendar,
              locate: widget.locate,
              isHydrating: widget.pinnedMessagesHydrating,
              accountJid: widget.accountJid,
              metadataFor: widget.metadataFor,
              metadataPendingFor: widget.metadataPendingFor,
              attachmentsBlocked: widget.attachmentsBlocked,
              isOneTimeAttachmentAllowed: widget.isOneTimeAttachmentAllowed,
              shouldAllowAttachment: widget.shouldAllowAttachment,
              onApproveAttachment: widget.onApproveAttachment,
              previewTimelineItemForItem: widget.previewTimelineItemForItem,
              resolvedHtmlBodyFor: widget.resolvedHtmlBodyFor,
              resolvedQuotedTextFor: widget.resolvedQuotedTextFor,
              onMessageLinkTap: widget.onMessageLinkTap,
            );
          },
        );
      },
    );
    final panel = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: spacing.m,
          vertical: spacing.m,
        ),
        decoration: BoxDecoration(
          color: colors.card,
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ChatIndexedHeader(
              title: l10n.chatPinnedMessagesTitle,
              onClose: widget.onClose,
              padding: EdgeInsets.zero,
            ),
            SizedBox(height: spacing.m),
            Flexible(fit: FlexFit.loose, child: panelBody),
          ],
        ),
      ),
    );
    return _ChatTopPanelVisibility(visible: showPanel, child: panel);
  }
}

class _PinnedMessageTile extends StatelessWidget {
  const _PinnedMessageTile({
    required this.item,
    required this.chat,
    required this.roomState,
    required this.canTogglePins,
    required this.canShowCalendarTasks,
    required this.canAddToPersonalCalendar,
    required this.canAddToChatCalendar,
    required this.onCopyTaskToPersonalCalendar,
    required this.onCopyCriticalPathToPersonalCalendar,
    required this.locate,
    required this.isHydrating,
    required this.accountJid,
    required this.metadataFor,
    required this.metadataPendingFor,
    required this.attachmentsBlocked,
    required this.isOneTimeAttachmentAllowed,
    required this.shouldAllowAttachment,
    required this.onApproveAttachment,
    required this.previewTimelineItemForItem,
    required this.resolvedHtmlBodyFor,
    required this.resolvedQuotedTextFor,
    required this.onMessageLinkTap,
  });

  final PinnedMessageItem item;
  final chat_models.Chat chat;
  final RoomState? roomState;
  final bool canTogglePins;
  final bool canShowCalendarTasks;
  final bool canAddToPersonalCalendar;
  final bool canAddToChatCalendar;
  final Future<String?> Function(CalendarTask task)?
  onCopyTaskToPersonalCalendar;
  final Future<bool> Function(
    CalendarModel model,
    String pathId,
    Set<String> taskIds,
  )?
  onCopyCriticalPathToPersonalCalendar;
  final T Function<T>() locate;
  final bool isHydrating;
  final String? accountJid;
  final FileMetadataData? Function(String) metadataFor;
  final bool Function(String) metadataPendingFor;
  final bool attachmentsBlocked;
  final bool Function(String stanzaId) isOneTimeAttachmentAllowed;
  final bool Function({required bool isSelf, required chat_models.Chat? chat})
  shouldAllowAttachment;
  final Future<void> Function({
    required Message message,
    required String senderJid,
    required String stanzaId,
    required bool isSelf,
    required bool isEmailChat,
    String? senderEmail,
  })
  onApproveAttachment;
  final ChatTimelineMessageItem? Function(PinnedMessageItem item)
  previewTimelineItemForItem;
  final String? Function(Message message) resolvedHtmlBodyFor;
  final String? Function(Message message) resolvedQuotedTextFor;
  final ValueChanged<String> onMessageLinkTap;

  Message? resolveMessageForPin() {
    final message = item.message;
    if (message != null) {
      return message;
    }
    final chatJid = item.chatJid.trim();
    final stanzaId = item.messageStanzaId.trim();
    if (chatJid.isEmpty || stanzaId.isEmpty) {
      return null;
    }
    return Message(
      stanzaID: stanzaId,
      senderJid: chatJid,
      chatJid: chatJid,
      timestamp: item.pinnedAt,
    );
  }

  bool isSelfMessage({required Message message, required String? accountJid}) {
    if (chat.type == ChatType.groupChat) {
      return roomState?.isSelfSenderJid(
            message.senderJid,
            selfJid: accountJid,
            fallbackSelfNick: chat.myNickname,
          ) ??
          false;
    }
    return message.isFromAuthorizedJid(accountJid);
  }

  String? nickFromSender(String senderJid) =>
      roomState?.senderNick(senderJid) ?? addressResourcePart(senderJid);

  String resolveSenderLabel({
    required BuildContext context,
    required Message? message,
    required bool isSelf,
  }) {
    final l10n = context.l10n;
    final trimmedSelfLabel = l10n.chatSenderYou.trim();
    if (isSelf) {
      return trimmedSelfLabel.isNotEmpty ? trimmedSelfLabel : chat.displayName;
    }
    if (message == null) {
      return chat.displayName;
    }
    final isGroupChat = chat.type == ChatType.groupChat;
    String? label;
    if (isGroupChat) {
      label = nickFromSender(message.senderJid);
    } else {
      final displayName = chat.displayName.trim();
      label = displayName.isNotEmpty ? displayName : null;
    }
    final senderFallback = message.senderJid.trim();
    final fallback = senderFallback.isNotEmpty
        ? senderFallback
        : chat.displayName;
    final hasLabel = label != null && label.isNotEmpty;
    final candidate = hasLabel ? label : fallback;
    final sanitized = sanitizeUnicodeControls(candidate);
    final safeLabel = sanitized.value.trim();
    return safeLabel.isNotEmpty ? safeLabel : fallback;
  }

  String resolveQuotedSenderLabel(BuildContext context, Message quotedMessage) {
    final quotedIsSelf = isSelfMessage(
      message: quotedMessage,
      accountJid: accountJid,
    );
    if (quotedIsSelf) {
      return context.l10n.chatSenderYou;
    }
    return resolveSenderLabel(
      context: context,
      message: quotedMessage,
      isSelf: false,
    );
  }

  String resolveForwardedSenderLabel({
    required BuildContext context,
    required Message? message,
    required bool isSelf,
    required String? forwardedFromJid,
    required String? forwardedSubjectSenderLabel,
  }) {
    final source = forwardedFromJid?.trim();
    if (source != null && source.isNotEmpty) {
      return source;
    }
    final subjectSender = forwardedSubjectSenderLabel?.trim();
    if (subjectSender != null && subjectSender.isNotEmpty) {
      return subjectSender;
    }
    if (isSelf) {
      return context.l10n.chatSenderYou;
    }
    return resolveSenderLabel(
      context: context,
      message: message,
      isSelf: false,
    );
  }

  List<InlineSpan> calendarTaskShareMetadata(
    CalendarTask task,
    AppLocalizations l10n,
    TextStyle detailStyle,
  ) {
    final metadata = <InlineSpan>[];
    final description = task.description?.trim() ?? _emptyText;
    if (description.isNotEmpty) {
      metadata.add(TextSpan(text: description, style: detailStyle));
    }
    final location = task.location?.trim() ?? _emptyText;
    if (location.isNotEmpty) {
      metadata.add(
        TextSpan(text: l10n.calendarCopyLocation(location), style: detailStyle),
      );
    }
    final scheduleText = calendarTaskScheduleText(task, l10n);
    if (scheduleText != null && scheduleText.isNotEmpty) {
      metadata.add(TextSpan(text: scheduleText, style: detailStyle));
    }
    return metadata;
  }

  String? calendarTaskScheduleText(CalendarTask task, AppLocalizations l10n) {
    final scheduled = task.scheduledTime;
    if (scheduled == null) {
      return null;
    }
    final end =
        task.endDate ??
        (task.duration == null ? null : scheduled.add(task.duration!));
    final startText = TimeFormatter.formatFriendlyDateTime(l10n, scheduled);
    if (end == null) {
      return startText;
    }
    final endText = TimeFormatter.formatFriendlyDateTime(l10n, end);
    if (endText == startText) {
      return startText;
    }
    return l10n.commonRangeLabel(startText, endText);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locate = context.read;
    final colors = context.colorScheme;
    final chatTokens = context.chatTheme;
    final spacing = context.spacing;
    final settings = context.watch<SettingsCubit>().state;
    final sourceMessage = item.message;
    final previewTimelineItem = previewTimelineItemForItem(item);
    final importantMessageIds = context
        .select<ImportantMessagesCubit, Set<String>>((cubit) {
          final items = cubit.state.items;
          if (items == null) {
            return const <String>{};
          }
          return items
              .map((entry) => entry.messageReferenceId.trim())
              .where((value) => value.isNotEmpty)
              .toSet();
        });
    final effectiveMessage = previewTimelineItem?.messageModel ?? sourceMessage;
    final previewItemId =
        previewTimelineItem?.id ??
        effectiveMessage?.stanzaID ??
        item.messageStanzaId.trim();
    final isEmailMessage =
        chat.isEmailBacked ||
        chat.defaultTransport.isEmail ||
        previewTimelineItem?.isEmailMessage == true ||
        effectiveMessage?.isEmailBacked == true;
    final rawRenderedText =
        (previewTimelineItem?.renderedText ?? sourceMessage?.plainText)
            ?.trim() ??
        _emptyText;
    final renderedText = isEmailMessage
        ? ChatSubjectCodec.previewBodyText(rawRenderedText).trim()
        : rawRenderedText;
    final attachmentIds =
        previewTimelineItem?.attachmentIds ?? item.attachmentMetadataIds;
    final shareParticipants =
        previewTimelineItem?.shareParticipants ?? const <chat_models.Chat>[];
    final replyParticipants =
        previewTimelineItem?.replyParticipants ?? const <chat_models.Chat>[];
    final quotedMessage = previewTimelineItem?.quotedMessage;
    final reactions =
        previewTimelineItem?.reactions ?? const <ReactionPreview>[];
    final isForwarded = previewTimelineItem?.isForwarded ?? false;
    final forwardedSubjectSenderLabel =
        previewTimelineItem?.forwardedSubjectSenderLabel;
    final forwardedFromJid = previewTimelineItem?.forwardedFromJid;
    final messageError =
        previewTimelineItem?.error ??
        effectiveMessage?.error ??
        MessageError.none;
    final trusted = previewTimelineItem?.trusted ?? effectiveMessage?.trusted;
    final calendarFragment =
        previewTimelineItem?.calendarFragment ??
        effectiveMessage?.calendarFragment;
    final calendarTask =
        previewTimelineItem?.calendarTaskIcs ??
        effectiveMessage?.calendarTaskIcs;
    final bool calendarTaskReadOnly =
        previewTimelineItem?.calendarTaskIcsReadOnly ??
        effectiveMessage?.calendarTaskIcsReadOnly ??
        _calendarTaskIcsReadOnlyFallback;
    final availabilityMessage = previewTimelineItem?.availabilityMessage;
    final CalendarCriticalPathFragment? criticalPathFragment = calendarFragment
        ?.maybeMap(criticalPath: (value) => value, orElse: () => null);
    final String? taskShareText = calendarTask
        ?.toShareText(context.l10n)
        .trim();
    final String? fragmentShareText = calendarFragment == null
        ? null
        : CalendarFragmentFormatter(
            context.l10n,
          ).describe(calendarFragment).trim();
    final bool hideTaskText =
        taskShareText != null &&
        taskShareText.isNotEmpty &&
        taskShareText == renderedText;
    final bool hideFragmentText =
        fragmentShareText != null &&
        fragmentShareText.isNotEmpty &&
        fragmentShareText == renderedText;
    final bool hideAvailabilityText =
        availabilityMessage != null && messageError.isNone;
    final showLoading = sourceMessage == null && isHydrating;
    final messageForPin = resolveMessageForPin();
    final stanzaId = item.messageStanzaId.trim();
    final VoidCallback? onPressed = stanzaId.isEmpty
        ? null
        : () => locate<ChatBloc>().add(ChatPinnedMessageSelected(stanzaId));
    final isSelf = effectiveMessage == null
        ? (previewTimelineItem?.isSelf ?? false)
        : (previewTimelineItem?.isSelf ??
              isSelfMessage(message: effectiveMessage, accountJid: accountJid));
    final senderLabel = resolveSenderLabel(
      context: context,
      message: effectiveMessage,
      isSelf: isSelf,
    );
    final bubbleColor = isSelf ? colors.primary : colors.card;
    final borderColor = isSelf ? Colors.transparent : chatTokens.recvEdge;
    final textColor = isSelf ? colors.primaryForeground : colors.foreground;
    final detailColor = isSelf
        ? colors.primaryForeground
        : colors.mutedForeground;
    final baseTextStyle = context.textTheme.small.copyWith(
      color: textColor,
      fontSize: settings.messageTextSize.fontSize,
      height: 1.3,
    );
    final linkStyle = baseTextStyle.copyWith(
      color: isSelf ? colors.primaryForeground : colors.primary,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    );
    final detailStyle = context.textTheme.muted.copyWith(
      color: detailColor,
      height: 1.0,
      textBaseline: TextBaseline.alphabetic,
    );
    final extraStyle = context.textTheme.muted.copyWith(
      color: detailColor,
      fontStyle: FontStyle.italic,
    );
    final transportIconData = isEmailMessage
        ? LucideIcons.mail
        : LucideIcons.messageCircle;
    final isImportant =
        effectiveMessage?.referenceIds.any(importantMessageIds.contains) ??
        false;
    TextSpan iconDetailSpan(IconData icon, Color color) => TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: detailStyle.copyWith(
        color: color,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
      ),
    );

    final timestamp = (effectiveMessage?.timestamp ?? item.pinnedAt).toLocal();
    final timeLabel =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    final statusIcon = switch (previewTimelineItem?.delivery) {
      ChatTimelineMessageDelivery.none => MessageStatus.none.icon,
      ChatTimelineMessageDelivery.pending => MessageStatus.pending.icon,
      ChatTimelineMessageDelivery.sent => MessageStatus.sent.icon,
      ChatTimelineMessageDelivery.received => MessageStatus.received.icon,
      ChatTimelineMessageDelivery.read => MessageStatus.read.icon,
      ChatTimelineMessageDelivery.failed => MessageStatus.failed.icon,
      null => null,
    };
    final detailSpans = <InlineSpan>[
      TextSpan(text: timeLabel, style: detailStyle),
      iconDetailSpan(transportIconData, detailColor),
      iconDetailSpan(LucideIcons.pin, detailColor),
      if (isImportant) iconDetailSpan(Icons.star_rounded, detailColor),
      if (trusted != null)
        iconDetailSpan(
          trusted.toShieldIcon,
          trusted ? axiGreen : colors.destructive,
        ),
      if (isSelf && statusIcon != null) iconDetailSpan(statusIcon, detailColor),
    ];
    final detailOpticalOffsetFactors = isEmailMessage
        ? const <int, double>{1: 0.08}
        : const <int, double>{};
    final shareMetadataDetails = hideTaskText && calendarTask != null
        ? calendarTaskShareMetadata(calendarTask, context.l10n, detailStyle)
        : _emptyInlineSpans;
    final taskFooterDetails = hideTaskText
        ? <InlineSpan>[...detailSpans, ...shareMetadataDetails]
        : _emptyInlineSpans;
    final fragmentFooterDetails = hideFragmentText
        ? detailSpans
        : _emptyInlineSpans;
    final availabilityFooterDetails = hideAvailabilityText
        ? detailSpans
        : _emptyInlineSpans;
    final showSubjectBanner =
        previewTimelineItem?.showSubject == true &&
        (previewTimelineItem?.subjectLabel?.trim().isNotEmpty == true);
    final subjectLabel =
        previewTimelineItem?.subjectLabel?.trim() ?? _emptyText;
    final isInviteMessage =
        previewTimelineItem?.isInvite ??
        (effectiveMessage?.pseudoMessageType == PseudoMessageType.mucInvite);
    final isInviteRevocationMessage =
        previewTimelineItem?.isInviteRevocation ??
        (effectiveMessage?.pseudoMessageType ==
            PseudoMessageType.mucInviteRevocation);
    final resolvedHtmlBody = effectiveMessage == null
        ? null
        : resolvedHtmlBodyFor(effectiveMessage);
    final normalizedHtmlBody = HtmlContentCodec.normalizeHtml(resolvedHtmlBody);
    final normalizedHtmlText = normalizedHtmlBody == null
        ? null
        : HtmlContentCodec.toPlainText(normalizedHtmlBody).trim();
    final bool shouldRenderTextContent =
        !hideTaskText && !hideFragmentText && !hideAvailabilityText;
    final messageText = renderedText;
    final metadataIdForCaption = attachmentIds.isNotEmpty
        ? attachmentIds.first
        : effectiveMessage?.fileMetadataID;
    final bool hasAttachmentCaption =
        shouldRenderTextContent &&
        messageText.isEmpty &&
        metadataIdForCaption != null &&
        metadataIdForCaption.isNotEmpty;
    final bool hasVisibleEmailText =
        messageText.isNotEmpty || subjectLabel.isNotEmpty;
    final bool shouldPreferRichEmailHtml =
        isEmailMessage &&
        HtmlContentCodec.shouldRenderRichEmailHtml(
          normalizedHtmlBody: normalizedHtmlBody,
          normalizedHtmlText: normalizedHtmlText,
          renderedText: messageText,
        );
    final bool shouldRenderInlineEmailHtmlBody =
        isEmailMessage &&
        shouldRenderTextContent &&
        !hasAttachmentCaption &&
        normalizedHtmlBody != null &&
        (!hasVisibleEmailText || shouldPreferRichEmailHtml);
    final contentChildren = <Widget>[];
    final extraChildren = <Widget>[];
    void addExtra(Widget child) {
      if (extraChildren.isNotEmpty) {
        extraChildren.add(SizedBox(height: spacing.s));
      }
      extraChildren.add(child);
    }

    if (showLoading) {
      contentChildren.add(
        Align(
          alignment: Alignment.centerLeft,
          child: AxiProgressIndicator(color: detailColor),
        ),
      );
    } else if (effectiveMessage == null) {
      contentChildren.add(
        Text(
          l10n.chatPinnedMissingMessage,
          style: context.textTheme.muted.copyWith(color: detailColor),
        ),
      );
    } else {
      if (showSubjectBanner) {
        final textScaler =
            MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
        final subjectPainter = TextPainter(
          text: TextSpan(text: subjectLabel, style: baseTextStyle),
          textDirection: Directionality.of(context),
          textScaler: textScaler,
        )..layout();
        contentChildren.add(Text(subjectLabel, style: baseTextStyle));
        contentChildren.add(
          DecoratedBox(
            decoration: BoxDecoration(color: context.colorScheme.border),
            child: SizedBox(
              height: context.borderSide.width,
              width: subjectPainter.width,
            ),
          ),
        );
        contentChildren.add(SizedBox(height: spacing.xs));
      }
      if (messageError.isNotNone) {
        contentChildren.add(
          Text(
            l10n.chatErrorLabel,
            style: baseTextStyle.copyWith(fontWeight: FontWeight.w600),
          ),
        );
        if (messageText.isNotEmpty) {
          contentChildren.add(
            _ParsedMessageBody(
              contentKey: '${previewItemId}_error',
              text: messageText,
              baseStyle: baseTextStyle,
              linkStyle: linkStyle,
              details: detailSpans,
              detailOpticalOffsetFactors: detailOpticalOffsetFactors,
              onLinkTap: onMessageLinkTap,
              onLinkLongPress: onMessageLinkTap,
            ),
          );
        }
      } else if (isInviteMessage || isInviteRevocationMessage) {
        final inviteActionFallbackLabel =
            context.l10n.chatInviteActionFallbackLabel;
        final inviteLabel =
            previewTimelineItem?.inviteLabel.trim() ??
            effectiveMessage.body?.trim() ??
            _emptyText;
        final inviteActionLabel =
            previewTimelineItem?.inviteActionLabel.trim() ??
            inviteActionFallbackLabel;
        final inviteRoomName =
            previewTimelineItem?.inviteRoomName?.trim() ?? _emptyText;
        final inviteRoom =
            previewTimelineItem?.inviteRoom?.trim() ?? _emptyText;
        final OutlinedBorder inviteCardShape = _attachmentSurfaceShape(
          context: context,
          isSelf: isSelf,
          chainedPrevious: contentChildren.isNotEmpty,
          chainedNext: false,
        );
        contentChildren.add(
          _ParsedMessageBody(
            contentKey: '${previewItemId}_invite',
            text: inviteLabel,
            baseStyle: baseTextStyle,
            linkStyle: linkStyle,
            details: detailSpans,
            detailOpticalOffsetFactors: detailOpticalOffsetFactors,
            onLinkTap: onMessageLinkTap,
            onLinkLongPress: onMessageLinkTap,
          ),
        );
        addExtra(
          _InviteAttachmentCard(
            shape: inviteCardShape,
            enabled: false,
            label: inviteRoomName.isNotEmpty ? inviteRoomName : inviteLabel,
            detailLabel: inviteRoom.isNotEmpty ? inviteRoom : inviteLabel,
            actionLabel: inviteActionLabel,
            onPressed: () {},
          ),
        );
      } else if (hasAttachmentCaption) {
        final metadata = metadataFor(metadataIdForCaption);
        final filename = metadata?.filename.trim() ?? _emptyText;
        final displayFilename = filename.isNotEmpty
            ? filename
            : l10n.chatAttachmentFallbackLabel;
        final sizeBytes = metadata?.sizeBytes;
        final sizeLabel = sizeBytes != null && sizeBytes > 0
            ? formatBytes(sizeBytes, l10n)
            : l10n.chatAttachmentUnknownSize;
        final caption = l10n.chatAttachmentCaption(displayFilename, sizeLabel);
        contentChildren.add(
          DynamicInlineText(
            key: ValueKey(previewItemId),
            text: TextSpan(text: caption, style: baseTextStyle),
            details: detailSpans,
            detailOpticalOffsetFactors: detailOpticalOffsetFactors,
            onLinkTap: onMessageLinkTap,
            onLinkLongPress: onMessageLinkTap,
          ),
        );
      } else if (shouldRenderInlineEmailHtmlBody) {
        final preparedHtmlBody =
            HtmlContentCodec.prepareEmailHtmlForFlutterHtml(
              normalizedHtmlBody,
              allowRemoteImages: settings.autoLoadEmailImages,
            );
        if (preparedHtmlBody.trim().isNotEmpty) {
          contentChildren.add(
            _MessageHtmlBody(
              key: ValueKey(previewItemId),
              html: preparedHtmlBody,
              textStyle: baseTextStyle,
              textColor: textColor,
              linkColor: isSelf ? colors.primaryForeground : colors.primary,
              shouldLoadImages: settings.autoLoadEmailImages,
              onLinkTap: onMessageLinkTap,
            ),
          );
        }
        contentChildren.add(
          Padding(
            padding: EdgeInsets.only(top: spacing.xs),
            child: ChatInlineDetails(
              details: detailSpans,
              detailOpticalOffsetFactors: detailOpticalOffsetFactors,
            ),
          ),
        );
      } else if (shouldRenderTextContent && messageText.isNotEmpty) {
        contentChildren.add(
          _ParsedMessageBody(
            contentKey: previewItemId,
            text: messageText,
            baseStyle: baseTextStyle,
            linkStyle: linkStyle,
            details: detailSpans,
            detailOpticalOffsetFactors: detailOpticalOffsetFactors,
            onLinkTap: onMessageLinkTap,
            onLinkLongPress: onMessageLinkTap,
          ),
        );
      } else if (attachmentIds.isEmpty &&
          calendarTask == null &&
          calendarFragment == null &&
          availabilityMessage == null) {
        contentChildren.add(
          Text(
            l10n.chatPinnedMissingMessage,
            style: context.textTheme.muted.copyWith(color: detailColor),
          ),
        );
      }
      if (effectiveMessage.retracted) {
        if (contentChildren.isNotEmpty) {
          contentChildren.add(SizedBox(height: spacing.xs));
        }
        contentChildren.add(Text(l10n.chatMessageRetracted, style: extraStyle));
      } else if (effectiveMessage.edited) {
        if (contentChildren.isNotEmpty) {
          contentChildren.add(SizedBox(height: spacing.xs));
        }
        contentChildren.add(Text(l10n.chatMessageEdited, style: extraStyle));
      }
    }

    if (availabilityMessage != null) {
      addExtra(
        CalendarAvailabilityMessageCard(
          message: availabilityMessage,
          footerDetails: availabilityFooterDetails,
        ),
      );
    } else if (calendarTask != null) {
      addExtra(
        canShowCalendarTasks
            ? ChatCalendarTaskCard(
                task: calendarTask,
                readOnly: calendarTaskReadOnly,
                requireImportConfirmation: !isSelf,
                canAddToPersonalCalendar: canAddToPersonalCalendar,
                onCopyToPersonalCalendar: onCopyTaskToPersonalCalendar,
                demoQuickAdd:
                    kEnableDemoChats &&
                    chat.defaultTransport.isEmail &&
                    !isSelf,
                footerDetails: taskFooterDetails,
                isShareFragment: true,
              )
            : CalendarFragmentCard(
                fragment: CalendarFragment.task(task: calendarTask),
                footerDetails: taskFooterDetails,
              ),
      );
    }
    if (criticalPathFragment != null) {
      addExtra(
        ChatCalendarCriticalPathCard(
          path: criticalPathFragment.path,
          tasks: criticalPathFragment.tasks,
          footerDetails: fragmentFooterDetails,
          canAddToPersonal: canAddToPersonalCalendar,
          canAddToChat: canAddToChatCalendar,
          onCopyToPersonalCalendar: onCopyCriticalPathToPersonalCalendar,
        ),
      );
    } else if (calendarFragment != null && calendarTask == null) {
      addExtra(
        CalendarFragmentCard(
          fragment: calendarFragment,
          footerDetails: fragmentFooterDetails,
        ),
      );
    }

    if (effectiveMessage != null && attachmentIds.isNotEmpty) {
      final isEmailBacked = chat.isEmailBacked;
      final bool attachmentsBlockedForPin = attachmentsBlocked;
      final allowAttachmentByTrust = shouldAllowAttachment(
        isSelf: isSelf,
        chat: chat,
      );
      final allowAttachmentOnce = attachmentsBlockedForPin
          ? false
          : isOneTimeAttachmentAllowed(effectiveMessage.stanzaID);
      final allowAttachment =
          !attachmentsBlockedForPin &&
          (allowAttachmentByTrust || allowAttachmentOnce);
      final emailDownloadDelegate = isEmailBacked
          ? AttachmentDownloadDelegate(() async {
              await context.read<ChatBloc>().downloadFullEmailMessage(
                effectiveMessage,
              );
              return true;
            })
          : null;
      for (var index = 0; index < attachmentIds.length; index += 1) {
        final attachmentId = attachmentIds[index];
        final downloadDelegate = isEmailBacked
            ? emailDownloadDelegate
            : AttachmentDownloadDelegate(
                () => context.read<ChatBloc>().downloadInboundAttachment(
                  metadataId: attachmentId,
                  stanzaId: effectiveMessage.stanzaID,
                ),
              );
        final metadataReloadDelegate = AttachmentMetadataReloadDelegate(
          () => context.read<ChatBloc>().reloadFileMetadata(attachmentId),
        );
        final hasAttachmentAbove = index > 0 || contentChildren.isNotEmpty;
        final hasAttachmentBelow = index < attachmentIds.length - 1;
        addExtra(
          ChatAttachmentPreview(
            stanzaId: effectiveMessage.stanzaID,
            metadata: metadataFor(attachmentId),
            metadataPending: metadataPendingFor(attachmentId),
            allowed: allowAttachment,
            downloadDelegate: downloadDelegate,
            metadataReloadDelegate: metadataReloadDelegate,
            surfaceShape: _attachmentSurfaceShape(
              context: context,
              isSelf: isSelf,
              chainedPrevious: hasAttachmentAbove,
              chainedNext: hasAttachmentBelow,
            ),
            onAllowPressed: allowAttachment
                ? null
                : attachmentsBlockedForPin
                ? null
                : () => onApproveAttachment(
                    message: effectiveMessage,
                    senderJid: effectiveMessage.senderJid,
                    stanzaId: effectiveMessage.stanzaID,
                    isSelf: isSelf,
                    isEmailChat: isEmailBacked,
                    senderEmail: chat.emailAddress,
                  ),
          ),
        );
      }
    }

    final pinActionBlocked =
        messageForPin != null &&
        messageForPin.awaitsMucReference(
          isGroupChat: chat.type == ChatType.groupChat,
          isEmailBacked: chat.isEmailBacked,
        );
    final pinActionPending =
        messageForPin != null &&
        messageForPin.waitsForOwnMucReference(
          isGroupChat: chat.type == ChatType.groupChat,
          isEmailBacked: chat.isEmailBacked,
          selfJid: accountJid,
          myOccupantJid: roomState?.myOccupantJid,
        );
    final Widget? unpinAction = canTogglePins && messageForPin != null
        ? AxiIconButton.destructive(
            onPressed: pinActionBlocked
                ? null
                : () => locate<ChatBloc>().add(
                    ChatMessagePinRequested(
                      message: messageForPin,
                      pin: false,
                      chat: chat,
                      roomState: roomState,
                    ),
                  ),
            iconData: LucideIcons.pinOff,
            tooltip: l10n.chatUnpinMessage,
            backgroundColor: colors.secondary,
            borderColor: colors.secondary,
            iconSize: context.sizing.menuItemIconSize,
            buttonSize: context.sizing.menuItemHeight,
            tapTargetSize: context.sizing.menuItemHeight,
            loading: pinActionPending,
          )
        : null;
    final showReplyStrip = isEmailMessage && replyParticipants.isNotEmpty;
    final showCompactReactions = !showReplyStrip && reactions.isNotEmpty;
    final showRecipientCutout =
        !showCompactReactions && isEmailMessage && shareParticipants.length > 1;
    final reactionCutoutDepth = spacing.m;
    final reactionCutoutRadius = spacing.m;
    final reactionCutoutMinThickness = spacing.l;
    final reactionStripOffset = Offset(0, -spacing.xxs);
    final reactionCutoutPadding = EdgeInsets.symmetric(
      horizontal: spacing.xs,
      vertical: spacing.xxs,
    );
    final reactionCornerClearance = spacing.s;
    final bubbleBaseRadius = _bubbleBaseRadius(context);
    final combinedReactionCornerClearance =
        _bubbleCornerClearance(bubbleBaseRadius) + reactionCornerClearance;
    final recipientCutoutDepth = spacing.m;
    final recipientCutoutRadius = spacing.m;
    final recipientCutoutPadding = EdgeInsets.fromLTRB(
      spacing.s,
      spacing.xs,
      spacing.s,
      spacing.s,
    );
    final recipientCutoutMinThickness = spacing.xl;
    Widget? reactionOverlay;
    CutoutStyle? reactionStyle;
    if (showReplyStrip) {
      reactionOverlay = _ReplyStrip(participants: replyParticipants);
      reactionStyle = CutoutStyle(
        depth: recipientCutoutDepth,
        cornerRadius: recipientCutoutRadius,
        padding: recipientCutoutPadding,
        offset: Offset.zero,
        minThickness: recipientCutoutMinThickness,
      );
    } else if (showCompactReactions) {
      reactionOverlay = _ReactionStrip(reactions: reactions);
      reactionStyle = CutoutStyle(
        depth: reactionCutoutDepth,
        cornerRadius: reactionCutoutRadius,
        shapeCornerRadius: context.radii.squircle,
        padding: reactionCutoutPadding,
        offset: reactionStripOffset,
        minThickness: reactionCutoutMinThickness,
      );
    }
    Widget? recipientOverlay;
    CutoutStyle? recipientStyle;
    if (showRecipientCutout) {
      recipientOverlay = _RecipientCutoutStrip(recipients: shareParticipants);
      recipientStyle = CutoutStyle(
        depth: recipientCutoutDepth,
        cornerRadius: recipientCutoutRadius,
        padding: recipientCutoutPadding,
        offset: Offset.zero,
        minThickness: recipientCutoutMinThickness,
      );
    }
    final replyPreview = quotedMessage == null
        ? null
        : _QuotedMessagePreview(
            message: quotedMessage,
            senderLabel: resolveQuotedSenderLabel(context, quotedMessage),
            isSelf: isSelf,
          );
    final forwardedPreview = !isForwarded
        ? null
        : _ForwardedPreviewText(
            senderLabel: resolveForwardedSenderLabel(
              context: context,
              message: effectiveMessage,
              isSelf: isSelf,
              forwardedFromJid: forwardedFromJid,
              forwardedSubjectSenderLabel: forwardedSubjectSenderLabel,
            ),
            isSelf: isSelf,
          );
    if (unpinAction != null) {
      if (contentChildren.isNotEmpty) {
        contentChildren.add(SizedBox(height: spacing.s));
      }
      contentChildren.add(
        Align(alignment: Alignment.centerRight, child: unpinAction),
      );
    }
    final bubble = ChatBubbleSurface(
      isSelf: isSelf,
      backgroundColor: bubbleColor,
      borderColor: borderColor,
      borderRadius: _bubbleBorderRadius(
        baseRadius: bubbleBaseRadius,
        isSelf: isSelf,
        chainedPrevious: false,
        chainedNext: false,
        flattenBottom: extraChildren.isNotEmpty,
      ),
      shadowOpacity: 0,
      shadows: const <BoxShadow>[],
      bubbleWidthFraction: 1.0,
      cornerClearance: combinedReactionCornerClearance,
      body: Padding(
        padding: _bubblePadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: contentChildren,
        ),
      ),
      reactionOverlay: reactionOverlay,
      reactionStyle: reactionStyle,
      recipientOverlay: recipientOverlay,
      recipientStyle: recipientStyle,
    );
    final bubblePreview = MouseRegion(
      cursor: onPressed == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: bubble,
      ),
    );
    final previewMaxWidth = context.sizing.dialogMaxWidth;
    final compactReactionMinimumBubbleWidth = showCompactReactions
        ? math.min(
            previewMaxWidth,
            minimumReactionCutoutBubbleWidth(
              context: context,
              reactions: reactions,
              padding: reactionCutoutPadding,
              minThickness: reactionCutoutMinThickness,
              cornerClearance: combinedReactionCornerClearance,
            ),
          )
        : 0.0;
    final bubbleWithPreview = _ReplyPreviewBubbleColumn(
      forwardedPreview: forwardedPreview,
      quotedPreview: replyPreview,
      senderLabel: _SenderLabelBlock(
        primaryLabel: senderLabel,
        secondaryLabel: null,
        isSelf: isSelf,
        leftInset: 0.0,
      ),
      bubble: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: compactReactionMinimumBubbleWidth,
          maxWidth: previewMaxWidth,
        ),
        child: bubblePreview,
      ),
      previewMaxWidth: previewMaxWidth,
      spacing: spacing.s,
      previewSpacing: spacing.xxs,
      alignEnd: isSelf,
    );
    final bubbleColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isSelf
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        bubbleWithPreview,
        if (extraChildren.isNotEmpty) ...[
          SizedBox(height: spacing.s),
          ...extraChildren,
        ],
      ],
    );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.m,
        vertical: spacing.xs,
      ),
      child: Align(
        alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.sizing.dialogMaxWidth),
          child: bubbleColumn,
        ),
      ),
    );
  }
}

class _ChatCalendarScope extends StatelessWidget {
  const _ChatCalendarScope({
    required this.chat,
    required this.calendarAvailable,
    required this.coordinator,
    required this.storage,
    required this.xmppService,
    required this.emailService,
    required this.reminderController,
    required this.availabilityCoordinator,
    required this.child,
  });

  final chat_models.Chat? chat;
  final bool calendarAvailable;
  final ChatCalendarSyncCoordinator? coordinator;
  final Storage? storage;
  final XmppService xmppService;
  final EmailService? emailService;
  final CalendarReminderController reminderController;
  final CalendarAvailabilityShareCoordinator? availabilityCoordinator;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final currentChat = chat;
    final currentCoordinator = coordinator;
    final currentStorage = storage;
    if (!calendarAvailable ||
        currentChat == null ||
        currentCoordinator == null ||
        currentStorage == null) {
      return child;
    }
    return BlocProvider<ChatCalendarBloc>(
      key: ValueKey('chat-calendar-${currentChat.jid}'),
      create: (context) => ChatCalendarBloc(
        chatJid: currentChat.jid,
        chatType: currentChat.type,
        coordinator: currentCoordinator,
        storage: currentStorage,
        xmppService: xmppService,
        emailService: emailService,
        reminderController: reminderController,
        availabilityCoordinator: availabilityCoordinator,
      )..add(const CalendarEvent.started()),
      child: BlocListener<SettingsCubit, SettingsState>(
        listenWhen: (previous, current) =>
            previous.endpointConfig != current.endpointConfig,
        listener: (context, settings) {
          final locate = context.read;
          locate<ChatCalendarBloc>().updateEmailService(
            settings.endpointConfig.smtpEnabled ? locate<EmailService>() : null,
          );
        },
        child: child,
      ),
    );
  }
}

class _ChatCalendarPanel extends StatelessWidget {
  const _ChatCalendarPanel({
    required this.chat,
    required this.calendarAvailable,
  });

  final chat_models.Chat? chat;
  final bool calendarAvailable;

  @override
  Widget build(BuildContext context) {
    final currentChat = chat;
    if (!calendarAvailable || currentChat == null) {
      return const SizedBox.shrink();
    }
    return BlocProvider<CalendarBloc>.value(
      value: context.watch<ChatCalendarBloc>(),
      child: ChatCalendarWidget(chat: currentChat, showHeader: true),
    );
  }
}

class _ChatDetailsOverlay extends StatelessWidget {
  const _ChatDetailsOverlay({
    required this.onAddRecipient,
    required this.loadedEmailImageMessageIds,
    required this.onEmailImagesApproved,
  });

  final ValueChanged<chat_models.Chat> onAddRecipient;
  final Set<String> loadedEmailImageMessageIds;
  final ValueChanged<String> onEmailImagesApproved;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colorScheme.background,
      child: SafeArea(
        top: false,
        child: _ChatSubrouteShell(
          title: context.l10n.chatActionDetails,
          child: ChatMessageDetails(
            onAddRecipient: onAddRecipient,
            loadedEmailImageMessageIds: loadedEmailImageMessageIds,
            onEmailImagesApproved: onEmailImagesApproved,
          ),
        ),
      ),
    );
  }
}

class _ChatSubrouteShell extends StatelessWidget {
  const _ChatSubrouteShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChatIndexedHeader(
          title: title,
          onClose: () {
            context.read<ChatsCubit>().setOpenChatRoute(
              route: ChatRouteIndex.main,
            );
          },
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _ChatIndexedHeader extends StatelessWidget {
  const _ChatIndexedHeader({
    required this.title,
    required this.onClose,
    this.padding,
  });

  final String title;
  final VoidCallback onClose;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Padding(
      padding: padding ?? EdgeInsets.all(spacing.m),
      child: Row(
        children: [
          AxiIconButton.ghost(
            iconData: LucideIcons.x,
            tooltip: context.l10n.commonClose,
            onPressed: onClose,
          ),
          SizedBox(width: spacing.s),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.large,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatSettingsOverlay extends StatelessWidget {
  const _ChatSettingsOverlay({
    required this.state,
    required this.onViewFilterChanged,
    required this.onToggleNotifications,
    required this.onSpamToggle,
    required this.onRenameContact,
    required this.isChatBlocked,
    required this.blocklistEntry,
    required this.blockAddress,
  });

  final ChatState state;
  final ValueChanged<MessageTimelineFilter> onViewFilterChanged;
  final ValueChanged<bool> onToggleNotifications;
  final ValueChanged<bool> onSpamToggle;
  final VoidCallback? onRenameContact;
  final bool isChatBlocked;
  final BlocklistEntry? blocklistEntry;
  final String? blockAddress;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colorScheme.background,
      child: SafeArea(
        top: false,
        child: _ChatSubrouteShell(
          title: context.l10n.chatSettings,
          child: _ChatSettingsButtons(
            state: state,
            onViewFilterChanged: onViewFilterChanged,
            onToggleNotifications: onToggleNotifications,
            onSpamToggle: onSpamToggle,
            onRenameContact: onRenameContact,
            isChatBlocked: isChatBlocked,
            blocklistEntry: blocklistEntry,
            blockAddress: blockAddress,
          ),
        ),
      ),
    );
  }
}

class _ChatGalleryOverlay extends StatelessWidget {
  const _ChatGalleryOverlay({required this.chat});

  final chat_models.Chat? chat;

  @override
  Widget build(BuildContext context) {
    final currentChat = chat;
    if (currentChat == null) {
      return const SizedBox.shrink();
    }
    return BlocProvider(
      create: (context) {
        final endpointConfig = context
            .read<SettingsCubit>()
            .state
            .endpointConfig;
        final emailService = endpointConfig.smtpEnabled
            ? context.read<EmailService>()
            : null;
        return AttachmentGalleryBloc(
          xmppService: context.read<XmppService>(),
          emailService: emailService,
          chatJid: currentChat.jid,
          chatOverride: currentChat,
          showChatLabel: false,
        );
      },
      child: ColoredBox(
        color: context.colorScheme.background,
        child: SafeArea(
          top: false,
          child: _ChatSubrouteShell(
            title: context.l10n.chatAttachmentTooltip,
            child: AttachmentGalleryView(
              chatOverride: currentChat,
              showChatLabel: false,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatImportantOverlay extends StatelessWidget {
  const _ChatImportantOverlay({required this.onMessageSelected});

  final ValueChanged<String> onMessageSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colorScheme.background,
      child: SafeArea(
        top: false,
        child: _ChatSubrouteShell(
          title: context.l10n.chatImportantMessagesTooltip,
          child: ImportantMessagesList(
            onPressed: (item) => onMessageSelected(item.messageReferenceId),
          ),
        ),
      ),
    );
  }
}

class _ChatCalendarOverlay extends StatelessWidget {
  const _ChatCalendarOverlay({
    super.key,
    required this.chat,
    required this.calendarAvailable,
  });

  final chat_models.Chat? chat;
  final bool calendarAvailable;

  @override
  Widget build(BuildContext context) {
    final currentChat = chat;
    if (!calendarAvailable || currentChat == null) {
      return const SizedBox.shrink();
    }
    return ColoredBox(
      color: context.colorScheme.background,
      child: SafeArea(
        top: false,
        child: _ChatCalendarPanel(
          chat: currentChat,
          calendarAvailable: calendarAvailable,
        ),
      ),
    );
  }
}

class _ChatCalendarOverlayVisibility extends StatefulWidget {
  const _ChatCalendarOverlayVisibility({
    required this.visible,
    required this.duration,
    required this.curve,
    required this.useDesktopFade,
    required this.child,
  });

  final bool visible;
  final Duration duration;
  final Curve curve;
  final bool useDesktopFade;
  final Widget child;

  @override
  State<_ChatCalendarOverlayVisibility> createState() =>
      _ChatCalendarOverlayVisibilityState();
}

class _ChatCalendarOverlayVisibilityState
    extends State<_ChatCalendarOverlayVisibility>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller0 = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.visible
        ? _chatCalendarTransitionVisibleValue
        : _chatCalendarTransitionHiddenValue,
  );

  late CurvedAnimation curve0 = CurvedAnimation(
    parent: controller0,
    curve: widget.curve,
    reverseCurve: widget.curve,
  );

  late Animation<double> opacity = curve0;
  late Animation<Offset> slide = Tween<Offset>(
    begin: _chatCalendarSlideOffset,
    end: Offset.zero,
  ).animate(curve0);

  @override
  void didUpdateWidget(_ChatCalendarOverlayVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      controller0.duration = widget.duration;
      syncVisibility();
    }
    if (oldWidget.curve != widget.curve) {
      curve0 = CurvedAnimation(
        parent: controller0,
        curve: widget.curve,
        reverseCurve: widget.curve,
      );
      opacity = curve0;
      slide = Tween<Offset>(
        begin: _chatCalendarSlideOffset,
        end: Offset.zero,
      ).animate(curve0);
    }
    if (oldWidget.visible != widget.visible) {
      syncVisibility();
    }
  }

  void syncVisibility() {
    final double target = widget.visible
        ? _chatCalendarTransitionVisibleValue
        : _chatCalendarTransitionHiddenValue;
    if (widget.duration == Duration.zero) {
      controller0
        ..stop()
        ..value = target;
      return;
    }
    controller0.animateTo(
      target,
      duration: widget.duration,
      curve: Curves.linear,
    );
  }

  @override
  void dispose() {
    controller0.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool visible = widget.visible;
    final Widget transitionChild = widget.useDesktopFade
        ? FadeTransition(opacity: opacity, child: widget.child)
        : SlideTransition(
            position: slide,
            child: FadeScaleTransition(animation: opacity, child: widget.child),
          );
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(excluding: !visible, child: transitionChild),
    );
  }
}

class _AvailabilityTaskDraft {
  const _AvailabilityTaskDraft({
    required this.title,
    required this.start,
    required this.duration,
    this.description,
  });

  final String title;
  final String? description;
  final DateTime start;
  final Duration duration;
}

class _CutoutLayoutResult<T> {
  const _CutoutLayoutResult({
    required this.items,
    required this.overflowed,
    required this.totalWidth,
  });

  final List<T> items;
  final bool overflowed;
  final double totalWidth;
}

@visibleForTesting
({List<ReactionPreview> items, bool overflowed, double totalWidth})
layoutReactionStrip({
  required BuildContext context,
  required List<ReactionPreview> reactions,
  required double maxContentWidth,
}) {
  final layout = _layoutReactionStrip(
    context: context,
    reactions: reactions,
    maxContentWidth: maxContentWidth,
  );
  return (
    items: layout.items,
    overflowed: layout.overflowed,
    totalWidth: layout.totalWidth,
  );
}

@visibleForTesting
double minimumReactionStripContentWidth({
  required BuildContext context,
  required List<ReactionPreview> reactions,
}) {
  if (reactions.isEmpty) return 0.0;
  final textDirection = Directionality.of(context);
  final textScaler =
      MediaQuery.maybeOf(context)?.textScaler ?? TextScaler.noScaling;
  final measurementSlack = context.borderSide.width;
  final firstWidth = measureReactionChipWidth(
    context: context,
    reaction: reactions.first,
    textDirection: textDirection,
    textScaler: textScaler,
  );
  if (reactions.length == 1) {
    return firstWidth + measurementSlack;
  }
  final glyphWidth = measureReactionOverflowGlyphWidth(
    context: context,
    textDirection: textDirection,
    textScaler: textScaler,
  );
  return firstWidth + glyphWidth + measurementSlack;
}

@visibleForTesting
double minimumReactionCutoutBubbleWidth({
  required BuildContext context,
  required List<ReactionPreview> reactions,
  required EdgeInsets padding,
  required double minThickness,
  required double cornerClearance,
}) {
  if (reactions.isEmpty) return 0.0;
  final requiredContentWidth = minimumReactionStripContentWidth(
    context: context,
    reactions: reactions,
  );
  final requiredThickness = math.max(
    minThickness,
    requiredContentWidth + padding.horizontal,
  );
  return requiredThickness + (cornerClearance * 2);
}

_CutoutLayoutResult<ReactionPreview> _layoutReactionStrip({
  required BuildContext context,
  required List<ReactionPreview> reactions,
  required double maxContentWidth,
}) {
  final spacing = context.spacing;
  final reactionChipSpacing = 0.0;
  final reactionOverflowSpacing = spacing.xs;
  if (reactions.isEmpty || maxContentWidth <= 0) {
    return const _CutoutLayoutResult(
      items: <ReactionPreview>[],
      overflowed: false,
      totalWidth: 0,
    );
  }

  final textDirection = Directionality.of(context);
  final mediaQuery = MediaQuery.maybeOf(context);
  final textScaler = mediaQuery == null
      ? TextScaler.noScaling
      : mediaQuery.textScaler;
  final measurementSlack = context.borderSide.width;
  final reactionOverflowGlyphWidth = measureReactionOverflowGlyphWidth(
    context: context,
    textDirection: textDirection,
    textScaler: textScaler,
  );
  final reactionWidths = [
    for (final reaction in reactions)
      measureReactionChipWidth(
        context: context,
        reaction: reaction,
        textDirection: textDirection,
        textScaler: textScaler,
      ),
  ];

  final visible = <ReactionPreview>[];
  double used = 0;

  final limit = maxContentWidth.isFinite
      ? math.max(0.0, maxContentWidth - measurementSlack)
      : maxContentWidth;

  for (var i = 0; i < reactions.length; i++) {
    final reaction = reactions[i];
    final reactionWidth = reactionWidths[i];
    final spacing = visible.isEmpty ? 0 : reactionChipSpacing;
    final addition = spacing + reactionWidth;
    final hasMoreAfter = i < reactions.length - 1;
    final overflowReservation = hasMoreAfter
        ? reactionOverflowGlyphWidth +
              ((visible.length + 1) > 1 ? reactionOverflowSpacing : 0.0)
        : 0.0;
    if (limit.isFinite && used + addition + overflowReservation > limit) {
      break;
    }
    visible.add(reaction);
    used += addition;
  }

  final truncated = visible.length < reactions.length;
  if (visible.isEmpty) {
    final firstWidth = reactionWidths.first;
    final canShowOverflow =
        reactions.length > 1 &&
        (!limit.isFinite || firstWidth + reactionOverflowGlyphWidth <= limit);
    final totalWidth = canShowOverflow
        ? firstWidth + reactionOverflowGlyphWidth
        : firstWidth;
    return _CutoutLayoutResult(
      items: <ReactionPreview>[reactions.first],
      overflowed: canShowOverflow,
      totalWidth: math.min(maxContentWidth, totalWidth),
    );
  }

  return _CutoutLayoutResult(
    items: visible,
    overflowed: truncated,
    totalWidth: math.min(
      maxContentWidth,
      truncated
          ? used +
                (visible.length > 1 ? reactionOverflowSpacing : 0.0) +
                reactionOverflowGlyphWidth
          : used,
    ),
  );
}

double measureReactionChipWidth({
  required BuildContext context,
  required ReactionPreview reaction,
  required TextDirection textDirection,
  required TextScaler textScaler,
}) {
  final spacing = context.spacing;
  final reactionChipPadding = EdgeInsets.symmetric(
    horizontal: 0.0,
    vertical: spacing.xxs,
  );
  final reactionSubscriptPadding = spacing.xs;
  final highlighted = reaction.reactedBySelf;
  final emojiPainter = TextPainter(
    text: TextSpan(
      text: reaction.emoji,
      style: reactionEmojiTextStyle(context, highlighted: highlighted),
    ),
    maxLines: 1,
    textDirection: textDirection,
    textScaler: textScaler,
  )..layout();

  var width = emojiPainter.width + reactionChipPadding.horizontal;

  if (reaction.count > 1) {
    final countPainter = TextPainter(
      text: TextSpan(
        text: reaction.count.toString(),
        style: reactionCountTextStyle(context, highlighted: highlighted),
      ),
      maxLines: 1,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    width =
        emojiPainter.width +
        reactionSubscriptPadding +
        countPainter.width +
        reactionChipPadding.horizontal;
  }

  return width;
}

double measureReactionOverflowGlyphWidth({
  required BuildContext context,
  required TextDirection textDirection,
  required TextScaler textScaler,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: context.l10n.commonEllipsis,
      style: reactionOverflowTextStyle(context),
    ),
    maxLines: 1,
    textDirection: textDirection,
    textScaler: textScaler,
  )..layout();
  return painter.width;
}

_CutoutLayoutResult<chat_models.Chat> _layoutRecipientStrip({
  required BuildContext context,
  required List<chat_models.Chat> recipients,
  required double maxContentWidth,
}) {
  if (recipients.isEmpty || maxContentWidth <= 0) {
    return const _CutoutLayoutResult(
      items: <chat_models.Chat>[],
      overflowed: false,
      totalWidth: 0,
    );
  }

  final spacing = context.spacing;
  final recipientAvatarSize = spacing.l;
  final recipientAvatarOverlap = spacing.s;
  final visible = <chat_models.Chat>[];
  final additions = <double>[];
  double used = 0;

  for (final recipient in recipients) {
    final addition = visible.isEmpty
        ? recipientAvatarSize
        : recipientAvatarSize - recipientAvatarOverlap;
    if (used + addition > maxContentWidth) {
      break;
    }
    visible.add(recipient);
    additions.add(addition);
    used += addition;
  }

  final truncated = visible.length < recipients.length;
  double totalWidth = used;

  if (truncated) {
    var ellipsisWidth = visible.isEmpty
        ? recipientAvatarSize
        : recipientAvatarSize - recipientAvatarOverlap;
    while (visible.isNotEmpty && totalWidth + ellipsisWidth > maxContentWidth) {
      totalWidth -= additions.removeLast();
      visible.removeLast();
      ellipsisWidth = visible.isEmpty
          ? recipientAvatarSize
          : recipientAvatarSize - recipientAvatarOverlap;
    }
    if (visible.isEmpty) {
      totalWidth = math.min(ellipsisWidth, maxContentWidth);
    } else {
      totalWidth = math.min(maxContentWidth, totalWidth + ellipsisWidth);
    }
  }

  return _CutoutLayoutResult(
    items: visible,
    overflowed: truncated,
    totalWidth: totalWidth,
  );
}

_CutoutLayoutResult<String> _layoutTypingStrip({
  required BuildContext context,
  required List<String> participants,
  required double maxContentWidth,
}) {
  if (participants.isEmpty || maxContentWidth <= 0) {
    return const _CutoutLayoutResult(
      items: <String>[],
      overflowed: false,
      totalWidth: 0,
    );
  }
  final spacing = context.spacing;
  final recipientAvatarSize = spacing.l;
  final recipientAvatarOverlap = spacing.s;
  final capped = participants
      .take(_typingIndicatorMaxAvatars + 1)
      .toList(growable: false);
  final visible = <String>[];
  final additions = <double>[];
  double used = 0;

  for (final participant in capped) {
    if (visible.length >= _typingIndicatorMaxAvatars) break;
    final addition = visible.isEmpty
        ? recipientAvatarSize
        : recipientAvatarSize - recipientAvatarOverlap;
    if (used + addition > maxContentWidth) {
      break;
    }
    visible.add(participant);
    additions.add(addition);
    used += addition;
  }

  final truncated = visible.length < participants.length;
  double totalWidth = used;

  if (truncated) {
    var ellipsisWidth = visible.isEmpty
        ? recipientAvatarSize
        : recipientAvatarSize - recipientAvatarOverlap;
    while (visible.isNotEmpty && totalWidth + ellipsisWidth > maxContentWidth) {
      totalWidth -= additions.removeLast();
      visible.removeLast();
      ellipsisWidth = visible.isEmpty
          ? recipientAvatarSize
          : recipientAvatarSize - recipientAvatarOverlap;
    }
    if (visible.isEmpty) {
      totalWidth = math.min(ellipsisWidth, maxContentWidth);
    } else {
      totalWidth = math.min(maxContentWidth, totalWidth + ellipsisWidth);
    }
  }

  return _CutoutLayoutResult(
    items: visible,
    overflowed: truncated,
    totalWidth: totalWidth,
  );
}

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({
    required this.jid,
    required this.size,
    this.avatarPath,
  });

  final String jid;
  final double size;
  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    return HydratedAxiAvatar(jid: jid, size: size, avatarPath: avatarPath);
  }
}

class _ReactionStrip extends StatelessWidget {
  const _ReactionStrip({required this.reactions, this.onReactionTap});

  final List<ReactionPreview> reactions;
  final void Function(String emoji)? onReactionTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.spacing;
        final chipSpacing = 0.0;
        final overflowSpacing = spacing.xs;
        final maxWidth =
            constraints.hasBoundedWidth &&
                constraints.maxWidth.isFinite &&
                constraints.maxWidth > 0
            ? constraints.maxWidth
            : double.infinity;
        final layout = layoutReactionStrip(
          context: context,
          reactions: reactions,
          maxContentWidth: maxWidth,
        );
        final items = layout.items;
        final children = <Widget>[];
        for (var i = 0; i < items.length; i++) {
          if (i != 0) {
            children.add(SizedBox(width: chipSpacing));
          }
          children.add(
            _ReactionChip(
              data: items[i],
              onTap: onReactionTap == null
                  ? null
                  : () => onReactionTap!(items[i].emoji),
            ),
          );
        }
        if (layout.overflowed) {
          if (children.isNotEmpty) {
            children.add(
              SizedBox(width: items.length > 1 ? overflowSpacing : 0.0),
            );
          }
          children.add(const _ReactionOverflowGlyph());
        }
        return Row(mainAxisSize: MainAxisSize.min, children: children);
      },
    );
  }
}

class _ReactionOverflowGlyph extends StatelessWidget {
  const _ReactionOverflowGlyph();

  @override
  Widget build(BuildContext context) {
    return Text(
      context.l10n.commonEllipsis,
      style: reactionOverflowTextStyle(context),
    );
  }
}

TextStyle reactionOverflowTextStyle(BuildContext context) {
  final colors = context.colorScheme;
  return context.textTheme.small
      .copyWith(
        fontWeight: FontWeight.w600,
        color: colors.mutedForeground,
        height: 1,
      )
      .apply(leadingDistribution: TextLeadingDistribution.even);
}

class _ReplyStrip extends StatelessWidget {
  const _ReplyStrip({required this.participants, this.onRecipientTap});

  final List<chat_models.Chat> participants;
  final ValueChanged<chat_models.Chat>? onRecipientTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.spacing;
        final recipientAvatarSize = spacing.l;
        final recipientAvatarOverlap = spacing.s;
        final recipientOverflowGap = spacing.s;
        final maxWidth =
            constraints.hasBoundedWidth &&
                constraints.maxWidth.isFinite &&
                constraints.maxWidth > 0
            ? constraints.maxWidth
            : double.infinity;
        final layout = _layoutRecipientStrip(
          context: context,
          recipients: participants,
          maxContentWidth: maxWidth,
        );
        final visible = layout.items;
        final overflowed = layout.overflowed;
        final children = <Widget>[];
        for (var i = 0; i < visible.length; i++) {
          final chat = visible[i];
          final offset = i * (recipientAvatarSize - recipientAvatarOverlap);
          children.add(
            Positioned(
              left: offset,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: null,
                child: _RecipientAvatarBadge(chat: chat),
              ),
            ),
          );
        }
        if (overflowed) {
          final offset = visible.isEmpty
              ? 0.0
              : visible.length *
                        (recipientAvatarSize - recipientAvatarOverlap) +
                    recipientOverflowGap;
          children.add(
            Positioned(left: offset, child: const _RecipientOverflowAvatar()),
          );
        }
        final baseWidth = layout.totalWidth;
        final totalWidth = overflowed
            ? baseWidth + recipientOverflowGap + recipientAvatarSize
            : math.max(baseWidth, recipientAvatarSize);
        return SizedBox(
          width: totalWidth,
          height: recipientAvatarSize,
          child: Stack(clipBehavior: Clip.none, children: children),
        );
      },
    );
  }
}

class _RecipientCutoutStrip extends StatelessWidget {
  const _RecipientCutoutStrip({required this.recipients});

  final List<chat_models.Chat> recipients;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.spacing;
        final recipientAvatarSize = spacing.l;
        final recipientAvatarOverlap = spacing.s;
        final recipientOverflowGap = spacing.s;
        final maxWidth =
            constraints.hasBoundedWidth &&
                constraints.maxWidth.isFinite &&
                constraints.maxWidth > 0
            ? constraints.maxWidth
            : double.infinity;
        final layout = _layoutRecipientStrip(
          context: context,
          recipients: recipients,
          maxContentWidth: maxWidth,
        );
        final visible = layout.items;
        final overflowed = layout.overflowed;
        final children = <Widget>[];
        for (var i = 0; i < visible.length; i++) {
          final offset = i * (recipientAvatarSize - recipientAvatarOverlap);
          children.add(
            Positioned(
              left: offset,
              child: _RecipientAvatarBadge(chat: visible[i]),
            ),
          );
        }
        if (overflowed) {
          final offset = visible.isEmpty
              ? 0.0
              : visible.length *
                        (recipientAvatarSize - recipientAvatarOverlap) +
                    recipientOverflowGap;
          children.add(
            Positioned(left: offset, child: const _RecipientOverflowAvatar()),
          );
        }
        final baseWidth = layout.totalWidth;
        final totalWidth = overflowed
            ? baseWidth + recipientOverflowGap + recipientAvatarSize
            : math.max(baseWidth, recipientAvatarSize);
        return SizedBox(
          width: totalWidth,
          height: recipientAvatarSize,
          child: Stack(clipBehavior: Clip.none, children: children),
        );
      },
    );
  }
}

class _RecipientAvatarBadge extends StatelessWidget {
  const _RecipientAvatarBadge({required this.chat});

  final chat_models.Chat chat;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final borderWidth = context.borderSide.width;
    final spacing = context.spacing;
    final recipientAvatarSize = spacing.l;
    final shape = SquircleBorder(cornerRadius: context.radii.squircle);
    final avatarPath = (chat.avatarPath ?? chat.contactAvatarPath)?.trim();
    final avatarImagePath = avatarPath?.isNotEmpty == true ? avatarPath : null;
    return SizedBox(
      width: recipientAvatarSize,
      height: recipientAvatarSize,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: colors.card, shape: shape),
        child: Padding(
          padding: EdgeInsets.all(borderWidth),
          child: HydratedAxiAvatar(
            jid: chat.avatarIdentifier,
            colorSeed: chat.avatarColorSeed,
            size: recipientAvatarSize - (borderWidth * 2),
            avatarPath: avatarImagePath,
          ),
        ),
      ),
    );
  }
}

class _RecipientOverflowAvatar extends StatelessWidget {
  const _RecipientOverflowAvatar();

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final recipientAvatarSize = spacing.l;
    return SizedBox(
      width: recipientAvatarSize,
      height: recipientAvatarSize,
      child: Center(
        child: Text(
          l10n.commonEllipsis,
          style: context.textTheme.small
              .copyWith(
                fontWeight: FontWeight.w700,
                color: colors.mutedForeground,
                height: 1,
              )
              .apply(leadingDistribution: TextLeadingDistribution.even),
        ),
      ),
    );
  }
}

class _TypingIndicatorPill extends StatelessWidget {
  const _TypingIndicatorPill({
    required this.participants,
    required this.avatarPaths,
  });

  final List<String> participants;
  final Map<String, String> avatarPaths;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.spacing;
        final avatarStrip = participants.isEmpty
            ? null
            : _TypingAvatarStrip(
                participants: participants,
                avatarPaths: avatarPaths,
              );
        final hasBoundedWidth =
            constraints.hasBoundedWidth && constraints.maxWidth.isFinite;
        final maxWidth = hasBoundedWidth ? constraints.maxWidth : null;
        return ConstrainedBox(
          constraints: maxWidth == null
              ? const BoxConstraints()
              : BoxConstraints(maxWidth: maxWidth),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (avatarStrip != null)
                Flexible(fit: FlexFit.loose, child: avatarStrip),
              if (avatarStrip != null) SizedBox(width: spacing.xs),
              const TypingIndicator(),
            ],
          ),
        );
      },
    );
  }
}

class _ChatTimelineViewport extends StatelessWidget {
  const _ChatTimelineViewport({
    required this.loadingMessages,
    required this.messageListKey,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
    required this.messageList,
    required this.typingVisible,
    required this.typingAvatars,
    required this.typingAvatarPaths,
    required this.quotedMessage,
    required this.quotedSenderLabel,
    required this.quotedIsSelf,
    required this.onClearQuote,
    required this.overlayAnimationDuration,
    this.notices,
    this.banner,
  });

  final bool loadingMessages;
  final Key messageListKey;
  final PointerMoveEventListener onPointerMove;
  final PointerUpEventListener onPointerUp;
  final PointerCancelEventListener onPointerCancel;
  final Widget messageList;
  final bool typingVisible;
  final List<String> typingAvatars;
  final Map<String, String> typingAvatarPaths;
  final Message? quotedMessage;
  final String? quotedSenderLabel;
  final bool quotedIsSelf;
  final VoidCallback onClearQuote;
  final Duration overlayAnimationDuration;
  final Widget? notices;
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    if (loadingMessages) {
      return const Align(
        alignment: Alignment.center,
        child: AxiProgressIndicator(),
      );
    }
    final spacing = context.spacing;
    return KeyedSubtree(
      key: messageListKey,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerMove: onPointerMove,
        onPointerUp: onPointerUp,
        onPointerCancel: onPointerCancel,
        child: Stack(
          fit: StackFit.expand,
          children: [
            messageList,
            if (typingVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: spacing.s,
                child: IgnorePointer(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: spacing.s),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.colorScheme.card,
                          borderRadius: BorderRadius.circular(
                            context.radii.pill,
                          ),
                          border: Border.all(color: context.colorScheme.border),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: spacing.m,
                            vertical: spacing.s,
                          ),
                          child: _TypingIndicatorPill(
                            participants: typingAvatars,
                            avatarPaths: typingAvatarPaths,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ComposerBottomOverlay(
                quotedMessage: quotedMessage,
                quotedSenderLabel: quotedSenderLabel,
                quotedIsSelf: quotedIsSelf,
                onClearQuote: onClearQuote,
                notices: notices,
                banner: banner,
                animationDuration: overlayAnimationDuration,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatComposerBottomPane extends StatelessWidget {
  const _ChatComposerBottomPane({
    required this.maxHeight,
    required this.onSizeChange,
    required this.child,
  });

  final double maxHeight;
  final ValueChanged<Size> onSizeChange;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        primary: false,
        child: _SizeReportingWidget(onSizeChange: onSizeChange, child: child),
      ),
    );
  }
}

class _ChatConversationPane extends StatelessWidget {
  const _ChatConversationPane({
    required this.pinnedPanel,
    required this.timelineViewport,
    required this.bottomPane,
  });

  final Widget pinnedPanel;
  final Widget timelineViewport;
  final Widget bottomPane;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        pinnedPanel,
        Expanded(child: timelineViewport),
        bottomPane,
      ],
    );
  }
}

class _TypingAvatarStrip extends StatelessWidget {
  const _TypingAvatarStrip({
    required this.participants,
    required this.avatarPaths,
  });

  final List<String> participants;
  final Map<String, String> avatarPaths;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.spacing;
        final recipientAvatarSize = spacing.l;
        final recipientAvatarOverlap = spacing.s;
        final recipientOverflowGap = spacing.s;
        final maxWidth =
            constraints.hasBoundedWidth &&
                constraints.maxWidth.isFinite &&
                constraints.maxWidth > 0
            ? constraints.maxWidth
            : double.infinity;
        final layout = _layoutTypingStrip(
          context: context,
          participants: participants,
          maxContentWidth: maxWidth,
        );
        final visible = layout.items;
        final overflowed = layout.overflowed;
        final children = <Widget>[];
        for (var i = 0; i < visible.length; i++) {
          final offset = i * (recipientAvatarSize - recipientAvatarOverlap);
          children.add(
            Positioned(
              left: offset,
              child: _TypingAvatar(
                jid: visible[i],
                avatarPath: avatarPaths[visible[i]],
              ),
            ),
          );
        }
        if (overflowed) {
          final offset = visible.isEmpty
              ? 0.0
              : visible.length *
                        (recipientAvatarSize - recipientAvatarOverlap) +
                    recipientOverflowGap;
          children.add(
            Positioned(left: offset, child: const _RecipientOverflowAvatar()),
          );
        }
        final baseWidth = layout.totalWidth;
        final totalWidth = overflowed
            ? baseWidth + recipientOverflowGap + recipientAvatarSize
            : math.max(baseWidth, recipientAvatarSize);
        return SizedBox(
          width: totalWidth,
          height: recipientAvatarSize,
          child: Stack(clipBehavior: Clip.none, children: children),
        );
      },
    );
  }
}

class _TypingAvatar extends StatelessWidget {
  const _TypingAvatar({required this.jid, this.avatarPath});

  final String jid;
  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    final borderColor = context.colorScheme.card;
    final borderWidth = context.borderSide.width;
    final spacing = context.spacing;
    final recipientAvatarSize = spacing.l;
    final shape = SquircleBorder(cornerRadius: context.radii.squircle);
    return Container(
      width: recipientAvatarSize,
      height: recipientAvatarSize,
      padding: EdgeInsets.all(borderWidth),
      decoration: ShapeDecoration(color: borderColor, shape: shape),
      child: HydratedAxiAvatar(
        jid: jid,
        size: recipientAvatarSize - (borderWidth * 2),
        avatarPath: avatarPath,
      ),
    );
  }
}

class _InviteAttachmentText extends StatelessWidget {
  const _InviteAttachmentText({
    required this.text,
    required this.style,
    required this.maxLines,
    required this.overflow,
  });

  final String text;
  final TextStyle style;
  final int maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final UnicodeSanitizedText sanitized = sanitizeUnicodeControls(text);
    final String candidate = sanitized.value.trim();
    final String resolved = candidate.isNotEmpty ? candidate : text;
    return Text(resolved, maxLines: maxLines, overflow: overflow, style: style);
  }
}

class _InviteAttachmentCard extends StatelessWidget {
  const _InviteAttachmentCard({
    required this.shape,
    required this.enabled,
    required this.label,
    required this.detailLabel,
    required this.actionLabel,
    required this.onPressed,
  });

  final OutlinedBorder shape;
  final bool enabled;
  final String label;
  final String detailLabel;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final padding = EdgeInsets.all(spacing.m);
    final contentSpacing = spacing.s;
    final headerSpacing = spacing.xs;
    final accentWidth = spacing.xxs;
    final leadingInset = sizing.menuItemIconSize + headerSpacing;
    final Color accentColor = enabled ? colors.primary : colors.muted;
    final Color labelColor = enabled
        ? colors.foreground
        : colors.mutedForeground;
    final Color iconColor = enabled ? colors.primary : colors.mutedForeground;
    final String trimmedDetailLabel = detailLabel.trim();
    final bool showDetailLabel =
        trimmedDetailLabel.isNotEmpty && trimmedDetailLabel != label.trim();
    return ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.card,
          shape: shape.copyWith(side: BorderSide(color: colors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: accentWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(color: accentColor),
              ),
            ),
            Expanded(
              child: Padding(
                padding: padding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: contentSpacing,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          LucideIcons.userPlus,
                          size: sizing.menuItemIconSize,
                          color: iconColor,
                        ),
                        SizedBox(width: headerSpacing),
                        Expanded(
                          child: _InviteAttachmentText(
                            text: label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.small.copyWith(
                              fontWeight: FontWeight.w600,
                              color: labelColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (showDetailLabel)
                      Padding(
                        padding: EdgeInsets.only(left: leadingInset),
                        child: _InviteAttachmentText(
                          text: trimmedDetailLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.small.copyWith(
                            color: colors.mutedForeground,
                          ),
                        ),
                      ),
                    if (enabled)
                      Padding(
                        padding: EdgeInsets.only(left: leadingInset),
                        child: SizedBox(
                          width: double.infinity,
                          child: AxiButton.outline(
                            onPressed: onPressed,
                            child: Text(
                              actionLabel,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageExtraGap extends StatelessWidget {
  const _MessageExtraGap({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

class _MessageExtraItem extends StatelessWidget {
  const _MessageExtraItem({
    super.key,
    required this.child,
    required this.shape,
    this.onLongPress,
    this.onSecondaryTapUp,
  });

  final Widget child;
  final ShapeBorder shape;
  final GestureLongPressCallback? onLongPress;
  final GestureTapUpCallback? onSecondaryTapUp;

  @override
  Widget build(BuildContext context) {
    final clippedChild = ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
    if (onLongPress == null && onSecondaryTapUp == null) {
      return clippedChild;
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: onLongPress,
      onSecondaryTapUp: onSecondaryTapUp,
      child: clippedChild,
    );
  }
}

class _MessageExtraShadow extends StatelessWidget {
  const _MessageExtraShadow({
    super.key,
    required this.child,
    required this.shape,
    required this.shadows,
  });

  final Widget child;
  final ShapeBorder shape;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(shape: shape, shadows: shadows),
      child: child,
    );
  }
}

class _MessageExtrasColumn extends StatelessWidget {
  const _MessageExtrasColumn({
    required this.children,
    required this.shadowValue,
    required this.shadows,
    required this.crossAxisAlignment,
  });

  final List<Widget> children;
  final double shadowValue;
  final List<BoxShadow> shadows;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    final List<BoxShadow> resolvedShadows = shadowValue > 0
        ? _scaleShadows(shadows, shadowValue)
        : const <BoxShadow>[];
    final decoratedChildren = children.map((child) {
      if (child is _MessageExtraGap) {
        return child;
      }
      if (child is _MessageExtraItem) {
        return _MessageExtraShadow(
          key: child.key,
          shape: child.shape,
          shadows: resolvedShadows,
          child: child,
        );
      }
      return child;
    }).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: decoratedChildren,
    );
  }
}

class _BubbleRegionRegistry {
  final regions = <String, RenderBox>{};

  Rect? rectFor(String messageId) {
    final renderBox = regions[messageId];
    if (renderBox == null || !renderBox.attached) {
      return null;
    }
    final origin = renderBox.localToGlobal(Offset.zero);
    return origin & renderBox.size;
  }

  void register(String messageId, RenderBox renderBox) {
    regions[messageId] = renderBox;
  }

  void unregister(String messageId, RenderBox renderBox) {
    final current = regions[messageId];
    if (identical(current, renderBox)) {
      regions.remove(messageId);
    }
  }

  void clear() {
    regions.clear();
  }
}

class _MessageBubbleRegion extends SingleChildRenderObjectWidget {
  const _MessageBubbleRegion({
    required this.messageId,
    required this.registry,
    required super.child,
  });

  final String messageId;
  final _BubbleRegionRegistry registry;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMessageBubbleRegion(messageId: messageId, registry: registry);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMessageBubbleRegion renderObject,
  ) {
    renderObject
      ..messageId = messageId
      ..registry = registry;
  }
}

class _RenderMessageBubbleRegion extends RenderProxyBox {
  _RenderMessageBubbleRegion({
    required String messageId,
    required _BubbleRegionRegistry registry,
  }) : messageId0 = messageId,
       registry0 = registry;

  String messageId0;

  set messageId(String value) {
    if (value == messageId0) return;
    registry0.unregister(messageId0, this);
    messageId0 = value;
    registry0.register(messageId0, this);
  }

  _BubbleRegionRegistry registry0;

  set registry(_BubbleRegionRegistry value) {
    if (identical(value, registry0)) return;
    registry0.unregister(messageId0, this);
    registry0 = value;
    registry0.register(messageId0, this);
  }

  void register() {
    registry0.register(messageId0, this);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    register();
  }

  @override
  void detach() {
    registry0.unregister(messageId0, this);
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    register();
  }
}

enum _ComposerNoticeType { error, warning, info }

class _ComposerNotice extends StatelessWidget {
  const _ComposerNotice({
    super.key,
    required this.type,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  final _ComposerNoticeType type;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final actionLabel = this.actionLabel;
    final onAction = this.onAction;
    final (Color background, Color foreground, IconData icon) = switch (type) {
      _ComposerNoticeType.error => (
        colors.destructive,
        colors.destructiveForeground,
        Icons.error_outline,
      ),
      _ComposerNoticeType.warning => (
        colors.warning,
        colors.foreground,
        Icons.warning_amber_rounded,
      ),
      _ComposerNoticeType.info => (
        colors.card,
        colors.foreground,
        Icons.refresh,
      ),
    };

    return _ComposerAttachedBannerSurface(
      backgroundColor: background,
      borderColor: colors.border,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ComposerBannerLeading(
            child: Icon(
              icon,
              size: context.sizing.menuItemIconSize,
              color: foreground,
            ),
          ),
          SizedBox(width: context.spacing.s),
          Expanded(
            child: Text(
              message,
              style: textTheme.p.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            _ComposerBannerTrailing(
              child: AxiButton(
                variant: AxiButtonVariant.ghost,
                size: AxiButtonSize.sm,
                onPressed: onAction,
                child: Text(
                  actionLabel,
                  style: textTheme.p.copyWith(color: foreground),
                ),
              ),
            ),
          if (onDismiss != null)
            _ComposerBannerTrailing(
              child: AxiIconButton.ghost(
                iconData: LucideIcons.x,
                tooltip: context.l10n.commonClose,
                onPressed: onDismiss,
                color: foreground,
                backgroundColor: Colors.transparent,
                iconSize: context.sizing.menuItemIconSize,
                buttonSize: context.sizing.menuItemHeight,
                tapTargetSize: context.sizing.menuItemHeight,
              ),
            ),
        ],
      ),
    );
  }
}

class _ComposerNotices extends StatelessWidget {
  const _ComposerNotices({
    required this.composerError,
    required this.onComposerErrorCleared,
    required this.showAttachmentWarning,
    required this.retryReport,
    required this.retryShareId,
    required this.onFanOutRetry,
  });

  final String? composerError;
  final VoidCallback? onComposerErrorCleared;
  final bool showAttachmentWarning;
  final FanOutSendReport? retryReport;
  final String? retryShareId;
  final VoidCallback? onFanOutRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final notices = <Widget>[];
    final composerError = this.composerError;
    if (composerError != null && composerError.isNotEmpty) {
      notices.add(
        _ComposerNotice(
          type: _ComposerNoticeType.error,
          message: composerError,
          onDismiss: onComposerErrorCleared,
        ),
      );
    }
    if (showAttachmentWarning) {
      notices.add(
        _ComposerNotice(
          type: _ComposerNoticeType.warning,
          message: l10n.chatComposerAttachmentWarning,
        ),
      );
    }
    final report = retryReport;
    final shareId = retryShareId;
    if (report != null && shareId != null) {
      final failedCount = report.statuses
          .where((status) => status.state == FanOutRecipientState.failed)
          .length;
      if (failedCount > 0) {
        final label = l10n.chatFanOutRecipientLabel(failedCount);
        final subjectLabel = report.subject?.trim();
        final failureMessage = subjectLabel?.isNotEmpty == true
            ? l10n.chatFanOutFailureWithSubject(
                subjectLabel!,
                failedCount,
                label,
              )
            : l10n.chatFanOutFailure(failedCount, label);
        notices.add(
          _ComposerNotice(
            type: _ComposerNoticeType.info,
            message: failureMessage,
            actionLabel: onFanOutRetry == null ? null : l10n.chatFanOutRetry,
            onAction: onFanOutRetry,
          ),
        );
      }
    }
    if (notices.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: notices,
    );
  }
}

class _DebugComposerNotices extends StatelessWidget {
  const _DebugComposerNotices();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ComposerNotice(
          type: _ComposerNoticeType.error,
          message: 'Debug failed-send banner',
          onDismiss: () {},
        ),
        _ComposerNotice(
          type: _ComposerNoticeType.warning,
          message: 'Debug attachment warning banner',
        ),
        _ComposerNotice(
          type: _ComposerNoticeType.info,
          message: 'Debug retry/sync banner',
          actionLabel: 'Retry',
          onAction: () {},
        ),
      ],
    );
  }
}

class _DebugComposerOverlayBanner extends StatelessWidget {
  const _DebugComposerOverlayBanner();

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ReadOnlyComposerBanner(),
        SizedBox(height: spacing.s),
        _MessageSelectionToolbar(
          count: 2,
          onClear: () {},
          onCopy: () {},
          onShare: () {},
          shareStatus: RequestStatus.none,
          onForward: () {},
          onAddToCalendar: () {},
        ),
      ],
    );
  }
}

class _ComposerModeTransition extends StatelessWidget {
  const _ComposerModeTransition({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      reverseDuration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            ...previousChildren,
            if (currentChild case final Widget current) current,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        if (duration == Duration.zero) {
          return child;
        }
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final scale = Tween<double>(begin: 0.97, end: 1).animate(curved);
        return FadeTransition(
          opacity: curved,
          child: SizeTransition(
            sizeFactor: curved,
            axisAlignment: 1,
            child: ScaleTransition(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _InlineExpandedDraftComposerSection extends StatelessWidget {
  const _InlineExpandedDraftComposerSection({
    super.key,
    required this.seed,
    required this.locate,
    required this.onUnexpand,
    required this.onClosed,
    required this.onDiscarded,
    required this.onDraftSaved,
  });

  final ComposeDraftSeed seed;
  final T Function<T>() locate;
  final VoidCallback onUnexpand;
  final VoidCallback onClosed;
  final VoidCallback onDiscarded;
  final ValueChanged<int> onDraftSaved;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: !keyboardVisible,
      child: ColoredBox(
        color: colors.background,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.border, width: 1)),
          ),
          child: EmbeddedComposeDraftContent(
            seed: seed,
            locate: locate,
            recipientCountAdjustment: 1,
            subjectTrailing: AxiIconButton.secondary(
              iconData: LucideIcons.minimize2,
              tooltip: context.l10n.draftMinimize,
              semanticLabel: context.l10n.draftMinimize,
              iconSize: context.sizing.inputSuffixIconSize,
              buttonSize: context.sizing.inputSuffixButtonSize,
              tapTargetSize: context.sizing.inputSuffixButtonSize,
              cornerRadius: context.radii.squircleSm,
              onPressed: onUnexpand,
            ),
            onClosed: onClosed,
            onDiscarded: onDiscarded,
            onDraftSaved: onDraftSaved,
          ),
        ),
      ),
    );
  }
}

class _ChatComposerSection extends StatelessWidget {
  const _ChatComposerSection({
    super.key,
    this.enabled = true,
    required this.hintText,
    required this.recipients,
    required this.availableChats,
    required this.latestStatuses,
    required this.visibilityLabel,
    required this.pendingAttachments,
    required this.composerHasText,
    required this.composerMinLines,
    required this.composerMaxLines,
    required this.selfJid,
    required this.selfIdentity,
    required this.subjectController,
    required this.subjectFocusNode,
    required this.textController,
    required this.textFocusNode,
    required this.tapRegionGroup,
    required this.onSubjectSubmitted,
    required this.showExpandDraftAction,
    required this.expandDraftEnabled,
    required this.onExpandDraftPressed,
    required this.onRecipientAdded,
    required this.onRecipientRemoved,
    required this.onRecipientToggled,
    required this.onAttachmentRetry,
    required this.onAttachmentRemove,
    required this.onPendingAttachmentPressed,
    required this.onPendingAttachmentLongPressed,
    required this.pendingAttachmentMenuBuilder,
    required this.buildComposerAccessories,
    required this.sendOnEnter,
    required this.onSend,
    this.composerError,
    this.onComposerErrorCleared,
    this.showAttachmentWarning = false,
    this.retryReport,
    this.retryShareId,
    this.onFanOutRetry,
    this.onTaskDropped,
  });

  final bool enabled;
  final String hintText;
  final List<ComposerRecipient> recipients;
  final List<chat_models.Chat> availableChats;
  final Map<String, FanOutRecipientState> latestStatuses;
  final String? visibilityLabel;
  final List<PendingAttachment> pendingAttachments;
  final bool composerHasText;
  final int composerMinLines;
  final int composerMaxLines;
  final String? selfJid;
  final SelfIdentitySnapshot selfIdentity;
  final TextEditingController subjectController;
  final FocusNode subjectFocusNode;
  final TextEditingController textController;
  final FocusNode textFocusNode;
  final Object tapRegionGroup;
  final VoidCallback onSubjectSubmitted;
  final bool showExpandDraftAction;
  final bool expandDraftEnabled;
  final VoidCallback onExpandDraftPressed;
  final ValueChanged<Contact> onRecipientAdded;
  final ValueChanged<String> onRecipientRemoved;
  final ValueChanged<String> onRecipientToggled;
  final ValueChanged<PendingAttachment> onAttachmentRetry;
  final ValueChanged<String> onAttachmentRemove;
  final ValueChanged<PendingAttachment> onPendingAttachmentPressed;
  final ValueChanged<PendingAttachment>? onPendingAttachmentLongPressed;
  final List<Widget> Function(PendingAttachment pending)?
  pendingAttachmentMenuBuilder;
  final List<ChatComposerAccessory> Function({required bool canSend})
  buildComposerAccessories;
  final bool sendOnEnter;
  final VoidCallback onSend;
  final String? composerError;
  final VoidCallback? onComposerErrorCleared;
  final bool showAttachmentWarning;
  final FanOutSendReport? retryReport;
  final String? retryShareId;
  final VoidCallback? onFanOutRetry;
  final ValueChanged<CalendarDragPayload>? onTaskDropped;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final myJid = selfJid;
    final suggestionAddresses = <String>{
      if (myJid != null && myJid.isNotEmpty) myJid,
    };
    final suggestionDomains = <String>{
      EndpointConfig.defaultDomain,
      if (myJid != null && myJid.isNotEmpty) mox.JID.fromString(myJid).domain,
    };
    final width = MediaQuery.sizeOf(context).width;
    final composerHorizontalInset = spacing.l;
    final desktopComposerHorizontalInset = spacing.l;
    final horizontalPadding = width >= smallScreen
        ? desktopComposerHorizontalInset
        : composerHorizontalInset;
    final cutoutBalanceInset = context.sizing.iconButtonTapTarget / 2;
    final rightPadding = math.max(0.0, horizontalPadding - cutoutBalanceInset);
    final hasQueuedAttachments = pendingAttachments.any(
      (attachment) =>
          attachment.status == PendingAttachmentStatus.queued &&
          !attachment.isPreparing,
    );
    final hasPreparingAttachments = pendingAttachments.any(
      (attachment) => attachment.isPreparing,
    );
    final hasSubjectText = subjectController.text.trim().isNotEmpty;
    final hasRecipients = recipients.includedRecipients.isNotEmpty;
    final sendEnabled =
        enabled &&
        !hasPreparingAttachments &&
        hasRecipients &&
        (composerHasText || hasQueuedAttachments || hasSubjectText);
    final subjectHeader = _SubjectTextField(
      enabled: enabled,
      controller: subjectController,
      focusNode: subjectFocusNode,
      onSubmitted: onSubjectSubmitted,
      showExpandDraftAction: showExpandDraftAction,
      expandDraftEnabled: expandDraftEnabled,
      onExpandDraftPressed: onExpandDraftPressed,
    );
    final showAttachmentTray = pendingAttachments.isNotEmpty;
    final commandSurface = resolveCommandSurface(context);
    final useDesktopMenu = commandSurface == CommandSurface.menu;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    Widget? attachmentTray;
    if (showAttachmentTray) {
      attachmentTray = PendingAttachmentList(
        attachments: pendingAttachments,
        onRetry: onAttachmentRetry,
        onRemove: onAttachmentRemove,
        onPressed: onPendingAttachmentPressed,
        onLongPress: useDesktopMenu ? null : onPendingAttachmentLongPressed,
        contextMenuBuilder: useDesktopMenu
            ? pendingAttachmentMenuBuilder
            : null,
      );
    }
    final composer = SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: !keyboardVisible,
      child: SizedBox(
        width: double.infinity,
        child: ColoredBox(
          color: colors.background,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.border, width: 1)),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                spacing.m,
                rightPadding,
                spacing.s,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (attachmentTray != null) ...[
                    attachmentTray,
                    SizedBox(height: spacing.m),
                  ],
                  _ComposerTaskDropRegion(
                    onTaskDropped: onTaskDropped,
                    child: ChatCutoutComposer(
                      controller: textController,
                      focusNode: textFocusNode,
                      hintText: hintText,
                      minLines: composerMinLines,
                      maxLines: composerMaxLines,
                      semanticsLabel: context.l10n.chatComposerSemantics,
                      onSend: onSend,
                      header: subjectHeader,
                      actions: buildComposerAccessories(canSend: sendEnabled),
                      sendEnabled: sendEnabled,
                      sendOnEnter: sendOnEnter,
                      enabled: enabled,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final locate = context.read;
    final children = <Widget>[];
    children.add(
      BlocSelector<ChatsCubit, ChatsState, List<String>>(
        bloc: locate<ChatsCubit>(),
        selector: (state) => state.recipientAddressSuggestions,
        builder: (context, recipientAddressSuggestions) {
          final rosterItems =
              context.watch<RosterCubit>().state.items ??
              (context.watch<RosterCubit>()[RosterCubit.itemsCacheKey]
                  as List<RosterItem>?) ??
              const <RosterItem>[];
          return RecipientChipsBar(
            recipients: recipients,
            availableChats: availableChats,
            rosterItems: rosterItems,
            databaseSuggestionAddresses: recipientAddressSuggestions,
            selfJid: locate<ChatsCubit>().selfJid,
            selfIdentity: selfIdentity,
            latestStatuses: latestStatuses,
            collapsedByDefault: true,
            suggestionAddresses: suggestionAddresses,
            suggestionDomains: suggestionDomains,
            onRecipientAdded: onRecipientAdded,
            onRecipientRemoved: onRecipientRemoved,
            onRecipientToggled: onRecipientToggled,
            visibilityLabel: visibilityLabel,
            tapRegionGroup: tapRegionGroup,
          );
        },
      ),
    );
    children.add(Opacity(opacity: enabled ? 1.0 : 0.56, child: composer));
    final content = TapRegion(
      groupId: tapRegionGroup,
      onTapUpOutside: (_) {
        if (!textFocusNode.hasFocus && !subjectFocusNode.hasFocus) {
          return;
        }
        textFocusNode.unfocus();
        subjectFocusNode.unfocus();
      },
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
    if (enabled) {
      return content;
    }
    return IgnorePointer(child: content);
  }
}

class _ComposerTaskDropRegion extends StatelessWidget {
  const _ComposerTaskDropRegion({required this.child, this.onTaskDropped});

  final Widget child;
  final ValueChanged<CalendarDragPayload>? onTaskDropped;

  @override
  Widget build(BuildContext context) {
    final onTaskDropped = this.onTaskDropped;
    if (onTaskDropped == null) {
      return child;
    }
    final colors = context.colorScheme;
    return DragTarget<CalendarDragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onTaskDropped(details.data),
      builder: (context, candidate, rejected) {
        final bool hovering = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            border: Border.all(
              color: hovering ? colors.primary : Colors.transparent,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: child,
        );
      },
    );
  }
}

class _SubjectTextField extends StatelessWidget {
  const _SubjectTextField({
    required this.enabled,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.showExpandDraftAction,
    required this.expandDraftEnabled,
    required this.onExpandDraftPressed,
  });

  final bool enabled;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;
  final bool showExpandDraftAction;
  final bool expandDraftEnabled;
  final VoidCallback onExpandDraftPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final subjectStyle = context.textTheme.small.copyWith(
      color: colors.foreground,
    );
    final subjectStrutStyle = StrutStyle.fromTextStyle(
      subjectStyle,
      forceStrutHeight: true,
      height: subjectStyle.height,
      leading: 0,
    );
    const inputDecoration = ShadDecoration(
      color: Colors.transparent,
      border: ShadBorder.none,
      secondaryBorder: ShadBorder.none,
      secondaryFocusedBorder: ShadBorder.none,
      focusedBorder: ShadBorder.none,
      errorBorder: ShadBorder.none,
      secondaryErrorBorder: ShadBorder.none,
      disableSecondaryBorder: true,
    );
    return SizedBox(
      height: sizing.menuItemHeight,
      child: Semantics(
        label: l10n.chatSubjectSemantics,
        textField: true,
        child: Row(
          children: [
            Text(
              '${l10n.chatSubjectHint}:',
              style: context.textTheme.small.copyWith(
                color: colors.mutedForeground,
              ),
            ),
            SizedBox(width: spacing.xs),
            Expanded(
              child: AxiInput(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                readOnly: !enabled,
                showCursor: enabled,
                enableInteractiveSelection: enabled,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: enabled ? (_) => onSubmitted() : null,
                onEditingComplete: enabled ? onSubmitted : null,
                keyboardType: TextInputType.text,
                style: subjectStyle,
                strutStyle: subjectStrutStyle,
                cursorHeight: subjectStyle.fontSize,
                decoration: inputDecoration,
                padding: EdgeInsets.zero,
                inputPadding: EdgeInsets.zero,
                constraints: const BoxConstraints(minHeight: 0),
              ),
            ),
            if (showExpandDraftAction) ...[
              SizedBox(width: spacing.xs),
              AxiIconButton.secondary(
                iconData: LucideIcons.maximize2,
                tooltip: l10n.draftExpand,
                semanticLabel: l10n.draftExpand,
                iconSize: sizing.inputSuffixIconSize,
                buttonSize: sizing.inputSuffixButtonSize,
                tapTargetSize: sizing.inputSuffixButtonSize,
                cornerRadius: context.radii.squircleSm,
                onPressed: enabled && expandDraftEnabled
                    ? onExpandDraftPressed
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyComposerBanner extends StatelessWidget {
  const _ReadOnlyComposerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final titleIndent = context.sizing.menuItemIconSize + spacing.s;
    final textTheme = context.textTheme;
    return _ComposerAttachedBannerSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ComposerBannerLeading(
                child: Icon(
                  LucideIcons.archive,
                  size: context.sizing.menuItemIconSize,
                  color: colors.mutedForeground,
                ),
              ),
              SizedBox(width: spacing.s),
              Expanded(
                child: Text(
                  l10n.chatReadOnly,
                  style: textTheme.p.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.xxs),
          Padding(
            padding: EdgeInsets.only(left: titleIndent),
            child: Text(
              l10n.chatUnarchivePrompt,
              style: textTheme.p.copyWith(color: colors.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomBootstrapComposerBanner extends StatelessWidget {
  const _RoomBootstrapComposerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final titleIndent = context.sizing.menuItemIconSize + spacing.s;
    final textTheme = context.textTheme;
    return _ComposerAttachedBannerSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ComposerBannerLeading(
                child: AxiProgressIndicator(
                  color: colors.foreground,
                  semanticsLabel: l10n.xmppOperationMucJoinStart,
                ),
              ),
              SizedBox(width: spacing.s),
              Expanded(
                child: Text(
                  l10n.xmppOperationMucJoinStart,
                  style: textTheme.p.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.xxs),
          Padding(
            padding: EdgeInsets.only(left: titleIndent),
            child: Text(
              l10n.chatMembersLoadingEllipsis,
              style: textTheme.p.copyWith(color: colors.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomJoinFailureComposerBanner extends StatelessWidget {
  const _RoomJoinFailureComposerBanner({super.key, this.detail});

  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final normalizedDetail = detail?.trim();
    final titleIndent = context.sizing.menuItemIconSize + spacing.s;
    final textTheme = context.textTheme;
    return _ComposerAttachedBannerSurface(
      backgroundColor: Color.alphaBlend(
        colors.destructive.withValues(alpha: 0.08),
        colors.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ComposerBannerLeading(
                child: Icon(
                  LucideIcons.triangleAlert,
                  size: context.sizing.menuItemIconSize,
                  color: colors.destructive,
                ),
              ),
              SizedBox(width: spacing.s),
              Expanded(
                child: Text(
                  l10n.chatInviteJoinFailed,
                  style: textTheme.p.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.destructive,
                  ),
                ),
              ),
            ],
          ),
          if (normalizedDetail?.isNotEmpty == true) ...[
            SizedBox(height: spacing.xxs),
            Padding(
              padding: EdgeInsets.only(left: titleIndent),
              child: Text(
                normalizedDetail!,
                style: textTheme.p.copyWith(color: colors.mutedForeground),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComposerAttachedBannerSurface extends StatelessWidget {
  const _ComposerAttachedBannerSurface({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderColor,
  });

  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    return SizedBox(
      width: double.infinity,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor ?? colors.card,
            border: Border(
              top: BorderSide(color: borderColor ?? colors.border, width: 1),
            ),
          ),
          child: Padding(padding: EdgeInsets.all(spacing.m), child: child),
        ),
      ),
    );
  }
}

class _ComposerBannerLeading extends StatelessWidget {
  const _ComposerBannerLeading({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: context.sizing.menuItemIconSize,
      child: Center(child: child),
    );
  }
}

class _ComposerBannerTrailing extends StatelessWidget {
  const _ComposerBannerTrailing({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class _EmojiPickerAccessory extends StatelessWidget {
  const _EmojiPickerAccessory({
    required this.controller,
    required this.textController,
  });

  final ShadPopoverController controller;
  final TextEditingController textController;

  @override
  Widget build(BuildContext context) {
    return AxiPopover(
      controller: controller,
      child: _ChatComposerIconButton(
        icon: LucideIcons.smile,
        tooltip: context.l10n.chatEmojiPicker,
        onPressed: controller.toggle,
      ),
      popover: (context) => EmojiPicker(
        textEditingController: textController,
        config: Config(
          emojiViewConfig: EmojiViewConfig(
            emojiSizeMax: context.read<Policy>().getMaxEmojiSize(),
          ),
        ),
      ),
    );
  }
}

class _AttachmentAccessoryButton extends StatelessWidget {
  const _AttachmentAccessoryButton({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _ChatComposerIconButton(
      icon: LucideIcons.paperclip,
      tooltip: enabled
          ? l10n.chatAttachmentTooltip
          : l10n.chatComposerFileUploadUnavailable,
      onPressed: enabled ? onPressed : null,
    );
  }
}

class _SendMessageAccessory extends StatelessWidget {
  const _SendMessageAccessory({
    required this.enabled,
    required this.onPressed,
    this.onLongPress,
  });

  final bool enabled;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return _ChatComposerIconButton(
      icon: LucideIcons.send,
      tooltip: context.l10n.chatSendMessageTooltip,
      activeColor: context.colorScheme.primary,
      onPressed: enabled ? onPressed : null,
      onLongPress: onLongPress,
    );
  }
}

class _ChatComposerIconButton extends StatelessWidget {
  const _ChatComposerIconButton({
    required this.icon,
    required this.tooltip,
    this.activeColor,
    this.onPressed,
    this.onLongPress,
  });

  final IconData icon;
  final String tooltip;
  final Color? activeColor;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final iconColor = colors.mutedForeground;
    final sizing = context.sizing;
    return AxiIconButton(
      iconData: icon,
      tooltip: tooltip,
      semanticLabel: tooltip,
      onPressed: onPressed,
      onLongPress: onLongPress,
      color: iconColor,
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: context.borderSide.width,
      cornerRadius: context.radii.squircle,
      iconSize: sizing.iconButtonIconSize,
      buttonSize: sizing.iconButtonSize,
      tapTargetSize: sizing.iconButtonTapTarget,
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.data, this.onTap});

  final ReactionPreview data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = data.reactedBySelf;
    final spacing = context.spacing;
    final chipPadding = EdgeInsets.symmetric(
      horizontal: 0.0,
      vertical: spacing.xxs,
    );
    final subscriptPadding = spacing.xs;
    final emojiStyle = reactionEmojiTextStyle(
      context,
      highlighted: highlighted,
    );
    final countStyle = reactionCountTextStyle(
      context,
      highlighted: highlighted,
    );
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: Padding(
        padding: chipPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.emoji, style: emojiStyle),
            if (data.count > 1)
              Padding(
                padding: EdgeInsets.only(
                  left: subscriptPadding,
                  top: spacing.xxs,
                ),
                child: Text(data.count.toString(), style: countStyle),
              ),
          ],
        ),
      ),
    );
  }
}

TextStyle reactionEmojiTextStyle(
  BuildContext context, {
  required bool highlighted,
}) {
  return context.textTheme.large.copyWith(
    fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
  );
}

TextStyle reactionCountTextStyle(
  BuildContext context, {
  required bool highlighted,
}) {
  final colors = context.colorScheme;
  return context.textTheme.small.copyWith(
    fontSize: (context.textTheme.small.fontSize ?? 10) * 0.9,
    color: highlighted ? colors.primary : colors.foreground,
    fontWeight: FontWeight.w600,
  );
}

class _ComposerOverlayHeadroomSpacer extends StatelessWidget {
  const _ComposerOverlayHeadroomSpacer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: ExcludeSemantics(child: Opacity(opacity: 0, child: child)),
    );
  }
}

class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final borderSide = context.borderSide;
    final line = Expanded(
      child: Container(height: borderSide.width, color: colors.destructive),
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.m, vertical: spacing.s),
      child: Row(
        children: [
          line,
          SizedBox(width: spacing.s),
          Text(
            label,
            style: textTheme.muted.copyWith(color: colors.destructive),
          ),
          SizedBox(width: spacing.s),
          line,
        ],
      ),
    );
  }
}

class _MessageActionBar extends StatelessWidget {
  const _MessageActionBar({
    required this.onReply,
    this.onForward,
    required this.onCopy,
    required this.onShare,
    required this.shareStatus,
    required this.onAddToCalendar,
    required this.onDetails,
    this.replyLoading = false,
    this.onSelect,
    this.onResend,
    this.onEdit,
    this.importantDisabled = false,
    this.onImportantToggle,
    required this.isImportant,
    this.pinDisabled = false,
    this.pinLoading = false,
    this.onPinToggle,
    required this.isPinned,
    this.onRevokeInvite,
  });

  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final RequestStatus shareStatus;
  final VoidCallback onAddToCalendar;
  final VoidCallback onDetails;
  final bool replyLoading;
  final VoidCallback? onSelect;
  final VoidCallback? onResend;
  final VoidCallback? onEdit;
  final bool importantDisabled;
  final VoidCallback? onImportantToggle;
  final bool isImportant;
  final bool pinDisabled;
  final bool pinLoading;
  final VoidCallback? onPinToggle;
  final bool isPinned;
  final VoidCallback? onRevokeInvite;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.of(context).textScaler;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final iconSize = sizing.menuItemIconSize;
    double scaled(double value) => textScaler.scale(value);
    final actions = <Widget>[
      ContextActionButton(
        icon: replyLoading
            ? AxiProgressIndicator(color: context.colorScheme.foreground)
            : Icon(LucideIcons.reply, size: iconSize),
        label: l10n.chatActionReply,
        onPressed: onReply,
      ),
      ContextActionButton(
        icon: Transform.scale(
          scaleX: -1,
          child: Icon(LucideIcons.reply, size: iconSize),
        ),
        label: l10n.chatActionForward,
        onPressed: onForward,
      ),
      if (onResend != null)
        ContextActionButton(
          icon: Icon(LucideIcons.repeat, size: iconSize),
          label: l10n.chatActionResend,
          onPressed: onResend,
        ),
      if (onEdit != null)
        ContextActionButton(
          icon: Icon(LucideIcons.pencilLine, size: iconSize),
          label: l10n.chatActionEdit,
          onPressed: onEdit,
        ),
      if (onRevokeInvite != null)
        ContextActionButton(
          icon: Icon(LucideIcons.ban, size: iconSize),
          label: l10n.chatActionRevoke,
          onPressed: onRevokeInvite,
        ),
      if (onImportantToggle != null || importantDisabled)
        ContextActionButton(
          icon: Icon(
            isImportant ? Icons.star_rounded : Icons.star_outline_rounded,
            size: iconSize,
          ),
          label: isImportant
              ? l10n.chatRemoveMessageImportant
              : l10n.chatMarkMessageImportant,
          onPressed: onImportantToggle,
        ),
      if (onPinToggle != null || pinLoading || pinDisabled)
        ContextActionButton(
          icon: pinLoading
              ? AxiProgressIndicator(color: context.colorScheme.foreground)
              : Icon(
                  isPinned ? LucideIcons.pinOff : LucideIcons.pin,
                  size: iconSize,
                ),
          label: isPinned ? l10n.chatUnpinMessage : l10n.chatPinMessage,
          onPressed: onPinToggle,
        ),
      ContextActionButton(
        icon: Icon(LucideIcons.copy, size: iconSize),
        label: l10n.chatActionCopy,
        onPressed: onCopy,
      ),
      ContextActionButton(
        icon: shareStatus.isLoading
            ? AxiProgressIndicator(color: context.colorScheme.foreground)
            : Icon(LucideIcons.share2, size: iconSize),
        label: l10n.chatActionShare,
        onPressed: shareStatus.isLoading ? null : onShare,
      ),
      ContextActionButton(
        icon: Icon(LucideIcons.calendarPlus, size: iconSize),
        label: l10n.chatActionAddToCalendar,
        onPressed: onAddToCalendar,
      ),
      ContextActionButton(
        icon: Icon(LucideIcons.info, size: iconSize),
        label: l10n.chatActionDetails,
        onPressed: onDetails,
      ),
      if (onSelect != null)
        ContextActionButton(
          icon: Icon(LucideIcons.squareCheck, size: iconSize),
          label: l10n.chatActionSelect,
          onPressed: onSelect,
        ),
    ];
    return Wrap(
      spacing: scaled(spacing.s),
      runSpacing: scaled(spacing.s),
      alignment: WrapAlignment.center,
      children: actions,
    );
  }
}

class _MessageArrivalAnimator extends StatefulWidget {
  const _MessageArrivalAnimator({
    super.key,
    required this.child,
    required this.animate,
    required this.isSelf,
  });

  final Widget child;
  final bool animate;
  final bool isSelf;

  @override
  State<_MessageArrivalAnimator> createState() =>
      _MessageArrivalAnimatorState();
}

class _MessageArrivalAnimatorState extends State<_MessageArrivalAnimator>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller0;
  late final Animation<double> opacity;
  late final Animation<Offset> slide;
  late bool completed;

  @override
  void initState() {
    super.initState();
    completed = !widget.animate;
    controller0 = AnimationController(
      vsync: this,
      duration: _messageArrivalDuration,
    );
    final curve = CurvedAnimation(
      parent: controller0,
      curve: _messageArrivalCurve,
    );
    opacity = curve;
    slide = Tween<Offset>(
      begin: Offset(widget.isSelf ? 0.22 : -0.22, 0.0),
      end: Offset.zero,
    ).animate(curve);
    controller0.addStatusListener(handleStatus);
    if (widget.animate) {
      controller0.forward();
    } else {
      controller0.value = 1;
    }
  }

  @override
  void didUpdateWidget(_MessageArrivalAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate) {
      completed = false;
      controller0
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    controller0.removeStatusListener(handleStatus);
    controller0.dispose();
    super.dispose();
  }

  void handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() {
        completed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (completed) {
      return widget.child;
    }
    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(position: slide, child: widget.child),
    );
  }
}

class _MessageSelectionToolbar extends StatelessWidget {
  const _MessageSelectionToolbar({
    required this.count,
    required this.onClear,
    required this.onCopy,
    required this.onShare,
    required this.shareStatus,
    required this.onForward,
    required this.onAddToCalendar,
    this.showReactions = false,
    this.onReactionSelected,
    this.onReactionPicker,
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final RequestStatus shareStatus;
  final VoidCallback onForward;
  final VoidCallback onAddToCalendar;
  final bool showReactions;
  final ValueChanged<String>? onReactionSelected;
  final VoidCallback? onReactionPicker;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.of(context).textScaler;
    final l10n = context.l10n;
    final onReactionSelected = this.onReactionSelected;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final composerHorizontalInset = spacing.m;
    final iconSize = sizing.menuItemIconSize;
    double scaled(double value) => textScaler.scale(value);
    return SelectionPanelShell(
      includeHorizontalSafeArea: false,
      padding: EdgeInsets.fromLTRB(
        scaled(composerHorizontalInset),
        scaled(spacing.m),
        scaled(composerHorizontalInset),
        scaled(spacing.m),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectionSummaryHeader(count: count, onClear: onClear),
          SizedBox(height: scaled(spacing.m)),
          Wrap(
            spacing: scaled(spacing.s),
            runSpacing: scaled(spacing.s),
            alignment: WrapAlignment.center,
            children: [
              ContextActionButton(
                icon: Icon(LucideIcons.reply, size: iconSize),
                label: l10n.chatActionForward,
                onPressed: onForward,
              ),
              ContextActionButton(
                icon: Icon(LucideIcons.copy, size: iconSize),
                label: l10n.chatActionCopy,
                onPressed: onCopy,
              ),
              ContextActionButton(
                icon: shareStatus.isLoading
                    ? AxiProgressIndicator(
                        color: context.colorScheme.foreground,
                      )
                    : Icon(LucideIcons.share2, size: iconSize),
                label: l10n.chatActionShare,
                onPressed: shareStatus.isLoading ? null : onShare,
              ),
              ContextActionButton(
                icon: Icon(LucideIcons.calendarPlus, size: iconSize),
                label: l10n.chatActionAddToCalendar,
                onPressed: onAddToCalendar,
              ),
            ],
          ),
          if (showReactions && onReactionSelected != null)
            _MultiSelectReactionPanel(
              onEmojiSelected: onReactionSelected,
              onCustomReaction: onReactionPicker,
            ),
        ],
      ),
    );
  }
}

class _MultiSelectReactionPanel extends StatelessWidget {
  const _MultiSelectReactionPanel({
    required this.onEmojiSelected,
    this.onCustomReaction,
  });

  final ValueChanged<String> onEmojiSelected;
  final VoidCallback? onCustomReaction;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: spacing.m),
        Text(context.l10n.chatActionReact, style: context.textTheme.muted),
        SizedBox(height: spacing.s),
        Wrap(
          spacing: spacing.s,
          runSpacing: spacing.s,
          alignment: WrapAlignment.start,
          children: [
            for (final emoji in _reactionQuickChoices)
              _ReactionQuickButton(
                emoji: emoji,
                onPressed: () => onEmojiSelected(emoji),
              ),
          ],
        ),
      ],
    );
  }
}

class _CalendarTextSelectionDialog extends StatefulWidget {
  const _CalendarTextSelectionDialog({required this.initialText});

  final String initialText;

  @override
  State<_CalendarTextSelectionDialog> createState() =>
      _CalendarTextSelectionDialogState();
}

class _CalendarTextSelectionDialogState
    extends State<_CalendarTextSelectionDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String _selection = '';

  @override
  void initState() {
    super.initState();
    final seeded = widget.initialText.trim();
    _controller = TextEditingController(text: seeded);
    _focusNode = FocusNode();
    _selection = seeded;
    _controller.addListener(_handleControllerChanged);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: seeded.length,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _handleControllerChanged();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    final text = _controller.text;
    final selection = _controller.selection;
    final fallback = text.trim();
    var next = fallback;
    if (selection.isValid && !selection.isCollapsed) {
      final start = math.min(selection.baseOffset, selection.extentOffset);
      final end = math.max(selection.baseOffset, selection.extentOffset);
      if (start >= 0 && end <= text.length) {
        next = text.substring(start, end).trim();
      }
    }
    if (_selection == next) return;
    setState(() {
      _selection = next;
    });
  }

  String get _effectiveText {
    final trimmedSelection = _selection.trim();
    if (trimmedSelection.isNotEmpty) return trimmedSelection;
    return _controller.text.trim();
  }

  bool get _canSubmit => _effectiveText.isNotEmpty;

  void _submit() {
    final text = _effectiveText;
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final spacing = context.spacing;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: spacing.l,
        vertical: spacing.m,
      ),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final maxWidth = math.min(
            constraints.maxWidth,
            context.sizing.dialogMaxWidth,
          );
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: AxiModalSurface(
                padding: EdgeInsets.all(spacing.m),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.chatChooseTextToAdd,
                              style: textTheme.h4,
                            ),
                          ),
                          AxiIconButton(
                            iconData: LucideIcons.x,
                            tooltip: l10n.commonClose,
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ],
                      ),
                      SizedBox(height: spacing.s),
                      Text(
                        l10n.chatChooseTextToAddHint,
                        style: textTheme.muted.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                      SizedBox(height: spacing.s),
                      AxiTextInput(
                        controller: _controller,
                        focusNode: _focusNode,
                        minLines: 4,
                        maxLines: 8,
                        keyboardType: TextInputType.multiline,
                        autofocus: true,
                      ),
                      SizedBox(height: spacing.m),
                      Row(
                        children: [
                          AxiButton(
                            variant: AxiButtonVariant.ghost,
                            onPressed: () => Navigator.of(context).maybePop(),
                            child: Text(l10n.commonCancel),
                          ),
                          SizedBox(width: spacing.s),
                          Expanded(
                            child: AxiButton.primary(
                              onPressed: _canSubmit ? _submit : null,
                              child: Text(l10n.chatActionAddToCalendar),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChatSettingsButtons extends StatelessWidget {
  const _ChatSettingsButtons({
    required this.state,
    required this.onViewFilterChanged,
    required this.onToggleNotifications,
    required this.onSpamToggle,
    required this.onRenameContact,
    required this.isChatBlocked,
    required this.blocklistEntry,
    required this.blockAddress,
  });

  final ChatState state;
  final ValueChanged<MessageTimelineFilter> onViewFilterChanged;
  final ValueChanged<bool> onToggleNotifications;
  final ValueChanged<bool> onSpamToggle;
  final VoidCallback? onRenameContact;
  final bool isChatBlocked;
  final BlocklistEntry? blocklistEntry;
  final String? blockAddress;

  @override
  Widget build(BuildContext context) {
    final chat = state.chat;
    if (chat == null) {
      return const SizedBox.expand();
    }
    final AppLocalizations l10n = context.l10n;
    final colors = context.colorScheme;
    final destructiveColor = colors.destructive;
    final BlocklistState blocklistState = context.watch<BlocklistCubit>().state;
    final bool globalSignatureEnabled = context
        .watch<SettingsCubit>()
        .state
        .shareTokenSignatureEnabled;
    final bool chatSignatureEnabled =
        chat.shareSignatureEnabled ?? globalSignatureEnabled;
    final bool signatureActive = globalSignatureEnabled && chatSignatureEnabled;
    final String signatureHint = globalSignatureEnabled
        ? l10n.chatSignatureHintEnabled
        : l10n.chatSignatureHintDisabled;
    final String signatureWarning = l10n.chatSignatureHintWarning;
    final bool showAttachmentToggle = chat.type != ChatType.note;
    final bool canRenameContact =
        chat.type == ChatType.chat && !chat.isAxichatWelcomeThread;
    final bool notificationsMuted = chat.muted;
    final bool isSpamChat = chat.spam;
    final String spamLabel = l10n.chatReportSpam;
    final String? resolvedBlockAddress = blockAddress?.trim();
    final String? resolvedBlockEntryAddress = blocklistEntry?.address.trim();
    final bool hasBlockAddress =
        resolvedBlockAddress != null && resolvedBlockAddress.isNotEmpty;
    final bool hasBlockEntry = blocklistEntry != null;
    final bool showXmppCapabilities = chat.defaultTransport.isXmpp;
    final blockTransport = chat.isEmailBacked
        ? MessageTransport.email
        : chat.defaultTransport;
    final itemPadding = EdgeInsets.all(context.spacing.m);
    final bool blockActionInFlight = switch (blocklistState) {
      BlocklistLoading state =>
        state.jid == null ||
            state.jid == resolvedBlockAddress ||
            state.jid == resolvedBlockEntryAddress,
      _ => false,
    };
    final bool blockSwitchEnabled =
        !blockActionInFlight &&
        (isChatBlocked ? hasBlockEntry : hasBlockAddress);
    final List<Widget> tiles = [
      if (canRenameContact && onRenameContact != null)
        Padding(
          padding: itemPadding,
          child: AxiListButton(
            leading: Icon(
              LucideIcons.pencilLine,
              size: context.sizing.menuItemIconSize,
            ),
            onPressed: onRenameContact,
            child: Text(l10n.chatContactRenameTooltip),
          ),
        ),
      if (showXmppCapabilities)
        Padding(
          padding: itemPadding,
          child: _ChatCapabilitiesSection(
            capabilities: state.xmppCapabilities,
            isGroupChat: chat.type == ChatType.groupChat,
          ),
        ),
      if (showAttachmentToggle)
        Padding(
          padding: itemPadding,
          child: _ChatAttachmentTrustToggle(chat: chat),
        ),
      Padding(
        padding: itemPadding,
        child: _ChatViewFilterControl(
          filter: state.viewFilter,
          onChanged: onViewFilterChanged,
        ),
      ),
      Padding(
        padding: itemPadding,
        child: _ChatSettingsSwitchRow(
          title: l10n.chatMuteNotifications,
          value: notificationsMuted,
          onChanged: (muted) => onToggleNotifications(!muted),
        ),
      ),
      Padding(
        padding: itemPadding,
        child: _ChatNotificationPreviewControl(
          setting: chat.notificationPreviewSetting,
          onChanged: (setting) => context.read<ChatBloc>().add(
            ChatNotificationPreviewSettingChanged(chat: chat, setting: setting),
          ),
        ),
      ),
      if (chat.supportsEmail)
        Padding(
          padding: itemPadding,
          child: _ChatSettingsSwitchRow(
            title: l10n.chatSignatureToggleLabel,
            subtitle: '$signatureHint $signatureWarning',
            value: signatureActive,
            onChanged: globalSignatureEnabled
                ? (enabled) => context.read<ChatBloc>().add(
                    ChatShareSignatureToggled(chat: chat, enabled: enabled),
                  )
                : null,
          ),
        ),
      Padding(
        padding: itemPadding,
        child: _ChatSettingsSwitchRow(
          title: spamLabel,
          titleColor: destructiveColor,
          checkedTrackColor: destructiveColor,
          value: isSpamChat,
          onChanged: onSpamToggle,
        ),
      ),
      Padding(
        padding: itemPadding,
        child: _ChatSettingsSwitchRow(
          title: l10n.blocklistBlock,
          titleColor: destructiveColor,
          checkedTrackColor: destructiveColor,
          value: isChatBlocked,
          onChanged: blockSwitchEnabled
              ? (blocked) {
                  if (blocked == isChatBlocked) {
                    return;
                  }
                  if (blocked) {
                    final address = resolvedBlockAddress;
                    if (address == null || address.isEmpty) {
                      return;
                    }
                    context.read<BlocklistCubit>().block(
                      address: address,
                      transport: blockTransport,
                    );
                    return;
                  }
                  final entry = blocklistEntry;
                  if (entry == null) {
                    return;
                  }
                  context.read<BlocklistCubit>().unblock(entry: entry);
                }
              : null,
        ),
      ),
    ];
    return ListView(padding: EdgeInsets.zero, children: tiles);
  }
}

class _ChatCapabilitiesSection extends StatelessWidget {
  const _ChatCapabilitiesSection({
    required this.capabilities,
    required this.isGroupChat,
  });

  final XmppPeerCapabilities? capabilities;
  final bool isGroupChat;

  String _formatFeatureLabel(String feature) {
    final trimmed = feature.trim();
    if (trimmed.isEmpty) return trimmed;
    final normalized = trimmed
        .replaceAll('urn:xmpp:', '')
        .replaceAll('http://jabber.org/protocol/', '')
        .replaceAll('jabber:iq:', '')
        .replaceAll('urn:ietf:params:xml:ns:', '')
        .replaceAll('/', ' ')
        .replaceAll('#', ' ')
        .replaceAll(':', ' ')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
    final parts = normalized
        .split(RegExp(r'\\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    return parts
        .map((part) {
          final lower = part.toLowerCase();
          if (lower.length <= 3) {
            return lower.toUpperCase();
          }
          if (lower.length == 4 && lower == 'xep') {
            return lower.toUpperCase();
          }
          return lower[0].toUpperCase() + lower.substring(1);
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final capabilitiesResolvedAt = capabilities?.capabilitiesResolvedAt;
    final String subtitle = capabilitiesResolvedAt == null
        ? l10n.commonUnknownLabel
        : l10n.chatSettingsCapabilitiesUpdated(
            TimeFormatter.formatFriendlyDateTime(l10n, capabilitiesResolvedAt),
          );
    final supportsMarkers = capabilities?.supportsMarkers ?? false;
    final supportsReceipts = capabilities?.supportsReceipts ?? false;
    final supportsTypingIndicators =
        capabilities?.supportsFeature(mox.chatStateXmlns) ?? false;
    final supportsReactions =
        capabilities?.supportsFeature(mox.messageReactionsXmlns) ?? false;
    final supportsMam = capabilities?.supportsFeature(mox.mamXmlns) ?? false;
    final supportsMuc =
        isGroupChat && (capabilities?.supportsFeature(mox.mucXmlns) ?? false);
    final List<_CapabilityEntry> entries = [
      if (supportsMarkers || supportsReceipts)
        _CapabilityEntry(
          label: l10n.settingsChatReadReceipts,
          detail: l10n.settingsChatReadReceiptsDescription,
        ),
      if (supportsTypingIndicators)
        _CapabilityEntry(
          label: l10n.settingsTypingIndicators,
          detail: l10n.settingsTypingIndicatorsDescription,
        ),
      if (supportsReactions)
        _CapabilityEntry(
          label: _formatFeatureLabel(mox.messageReactionsXmlns),
          detail: l10n.chatReactionsPrompt,
        ),
      if (supportsMam)
        _CapabilityEntry(label: _formatFeatureLabel(mox.mamXmlns)),
      if (supportsMuc)
        _CapabilityEntry(label: _formatFeatureLabel(mox.mucXmlns)),
      if (supportsMuc) _CapabilityEntry(label: l10n.mucSectionModerators),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.chatSettingsCapabilitiesTitle),
        SizedBox(height: spacing.xs),
        Text(subtitle, style: context.textTheme.muted),
        SizedBox(height: spacing.s),
        if (entries.isEmpty)
          Text(
            l10n.chatSettingsCapabilitiesEmpty,
            style: context.textTheme.muted,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final minTileWidth = math.max(
                sizing.menuMinWidth,
                sizing.menuItemHeight * 6,
              );
              final double spacingWidth = spacing.s;
              final int columns = math.max(
                1,
                (availableWidth / (minTileWidth + spacingWidth)).floor(),
              );
              final double totalSpacing = spacingWidth * (columns - 1);
              final double tileWidth =
                  (availableWidth - totalSpacing) / columns;
              return Wrap(
                spacing: spacingWidth,
                runSpacing: spacingWidth,
                children: entries
                    .map(
                      (entry) => SizedBox(
                        width: tileWidth,
                        child: _CapabilityTile(
                          label: entry.label,
                          detail: entry.detail,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
    );
  }
}

class _CapabilityEntry {
  const _CapabilityEntry({required this.label, this.detail});

  final String label;
  final String? detail;
}

class _CapabilityTile extends StatelessWidget {
  const _CapabilityTile({required this.label, required this.detail});

  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final textTheme = context.textTheme;
    return AxiModalSurface(
      padding: EdgeInsets.all(spacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          if (detail != null) ...[
            SizedBox(height: spacing.xs),
            Text(detail!, style: textTheme.muted),
          ],
        ],
      ),
    );
  }
}

class _ChatSettingsRow extends StatelessWidget {
  const _ChatSettingsRow({
    required this.title,
    this.subtitle,
    this.titleColor,
    required this.trailing,
  });

  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final String? resolvedSubtitle = subtitle;
    final Color? resolvedTitleColor = titleColor;
    final TextStyle mutedStyle = context.textTheme.muted;
    final TextStyle subtitleStyle = mutedStyle;
    final List<Widget> textChildren = [
      Text(
        title,
        style: resolvedTitleColor == null
            ? null
            : TextStyle(color: resolvedTitleColor),
      ),
      if (resolvedSubtitle != null)
        Padding(
          padding: EdgeInsets.only(top: spacing.xs),
          child: Text(resolvedSubtitle, style: subtitleStyle),
        ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: textChildren,
          ),
        ),
        SizedBox(width: spacing.s),
        trailing,
      ],
    );
  }
}

class _ChatSettingsSwitchRow extends StatelessWidget {
  const _ChatSettingsSwitchRow({
    required this.title,
    this.subtitle,
    this.titleColor,
    this.checkedTrackColor,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Color? checkedTrackColor;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return _ChatSettingsRow(
      title: title,
      subtitle: subtitle,
      titleColor: titleColor,
      trailing: ShadSwitch(
        value: value,
        onChanged: onChanged,
        checkedTrackColor: checkedTrackColor,
      ),
    );
  }
}

class _ChatViewFilterControl extends StatelessWidget {
  const _ChatViewFilterControl({required this.filter, required this.onChanged});

  final MessageTimelineFilter filter;
  final ValueChanged<MessageTimelineFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final sizing = context.sizing;
    final messageFilterOptions = _messageFilterOptions(l10n);
    return _ChatSettingsRow(
      title: filter.statusLabel(l10n),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: sizing.menuMaxWidth),
        child: AxiSelect<MessageTimelineFilter>(
          maxWidth: sizing.menuMaxWidth,
          initialValue: filter,
          onChanged: (value) {
            if (value == null) return;
            onChanged(value);
          },
          options: messageFilterOptions
              .map(
                (option) => ShadOption<MessageTimelineFilter>(
                  value: option.filter,
                  child: Text(
                    option.filter.menuLabel(l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          selectedOptionBuilder: (_, value) => Text(
            value.menuLabel(l10n),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _ChatNotificationPreviewControl extends StatelessWidget {
  const _ChatNotificationPreviewControl({
    required this.setting,
    required this.onChanged,
  });

  final NotificationPreviewSetting? setting;
  final ValueChanged<NotificationPreviewSetting?> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final sizing = context.sizing;
    return _ChatSettingsRow(
      title: l10n.settingsNotificationPreviews,
      trailing: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: sizing.menuMaxWidth),
        child: AxiSelect<NotificationPreviewSetting?>(
          maxWidth: sizing.menuMaxWidth,
          initialValue: setting,
          onChanged: (value) {
            onChanged(value);
          },
          options:
              <NotificationPreviewSetting?>[
                    null,
                    ...NotificationPreviewSetting.values,
                  ]
                  .map(
                    (option) => ShadOption<NotificationPreviewSetting?>(
                      value: option,
                      child: Text(
                        option == null
                            ? l10n.chatNotificationPreviewOptionInherit
                            : option.label(
                                showLabel:
                                    l10n.chatNotificationPreviewOptionShow,
                                hideLabel:
                                    l10n.chatNotificationPreviewOptionHide,
                              ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
          selectedOptionBuilder: (_, value) => Text(
            value == null
                ? l10n.chatNotificationPreviewOptionInherit
                : value.label(
                    showLabel: l10n.chatNotificationPreviewOptionShow,
                    hideLabel: l10n.chatNotificationPreviewOptionHide,
                  ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _ChatAttachmentTrustToggle extends StatelessWidget {
  const _ChatAttachmentTrustToggle({required this.chat});

  final chat_models.Chat chat;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled =
        (chat.attachmentAutoDownload ??
                context
                    .watch<SettingsCubit>()
                    .state
                    .defaultChatAttachmentAutoDownload)
            .isAllowed;
    final hint = enabled
        ? l10n.chatAttachmentAutoDownloadHintOn
        : l10n.chatAttachmentAutoDownloadHintOff;
    return _ChatSettingsSwitchRow(
      title: l10n.chatAttachmentAutoDownloadLabel,
      subtitle: hint,
      value: enabled,
      onChanged: (value) => context.read<ChatBloc>().add(
        ChatAttachmentAutoDownloadToggled(chat: chat, enabled: value),
      ),
    );
  }
}

class _ReactionManager extends StatefulWidget {
  const _ReactionManager({
    required this.reactions,
    required this.onToggle,
    required this.onAddCustom,
    this.disabled = false,
    this.disabledLoading = false,
    this.disabledMessage,
  });

  final List<ReactionPreview> reactions;
  final ValueChanged<String> onToggle;
  final VoidCallback onAddCustom;
  final bool disabled;
  final bool disabledLoading;
  final String? disabledMessage;

  @override
  State<_ReactionManager> createState() => _ReactionManagerState();
}

class _ReactionManagerState extends State<_ReactionManager> {
  late List<ReactionPreview> _sorted;
  int _signature = 0;

  @override
  void initState() {
    super.initState();
    _refreshSorted();
  }

  @override
  void didUpdateWidget(covariant _ReactionManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = _reactionsSignature(widget.reactions);
    if (_signature != nextSignature) {
      _refreshSorted(signature: nextSignature);
    }
  }

  void _refreshSorted({int? signature}) {
    final nextSignature = signature ?? _reactionsSignature(widget.reactions);
    _signature = nextSignature;
    _sorted = widget.reactions.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
  }

  int _reactionsSignature(List<ReactionPreview> reactions) {
    var hash = reactions.length;
    for (final reaction in reactions) {
      hash = Object.hash(
        hash,
        reaction.emoji,
        reaction.count,
        reaction.reactedBySelf,
      );
    }
    return hash;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final textTheme = context.textTheme;
    final sorted = _sorted;
    final hasReactions = sorted.isNotEmpty;
    return AxiModalSurface(
      padding: EdgeInsets.all(spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: spacing.s,
        children: [
          if (widget.disabled)
            Row(
              children: [
                if (widget.disabledLoading) ...[
                  AxiProgressIndicator(color: colors.mutedForeground),
                  SizedBox(width: spacing.s),
                ],
                Expanded(
                  child: Text(
                    widget.disabledMessage ??
                        (widget.disabledLoading
                            ? context.l10n.chatMucReferencePending
                            : context.l10n.chatMucReferenceUnavailable),
                    style: textTheme.muted,
                  ),
                ),
              ],
            ),
          if (hasReactions)
            Wrap(
              spacing: spacing.s,
              runSpacing: spacing.s,
              children: [
                for (final reaction in sorted)
                  _ReactionManagerChip(
                    key: ValueKey(reaction.emoji),
                    data: reaction,
                    onToggle: widget.disabled
                        ? null
                        : () => widget.onToggle(reaction.emoji),
                  ),
              ],
            )
          else
            Text(
              context.l10n.chatReactionsNone,
              style: textTheme.small.copyWith(color: colors.mutedForeground),
            ),
          if (!widget.disabled)
            Text(
              hasReactions
                  ? context.l10n.chatReactionsPrompt
                  : context.l10n.chatReactionsPick,
              style: textTheme.muted,
            ),
          Wrap(
            spacing: spacing.s,
            runSpacing: spacing.s,
            children: [
              for (final emoji in _reactionQuickChoices)
                _ReactionQuickButton(
                  emoji: emoji,
                  onPressed: widget.disabled
                      ? null
                      : () => widget.onToggle(emoji),
                ),
              _ReactionAddButton(
                onPressed: widget.disabled ? null : widget.onAddCustom,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReactionManagerChip extends StatelessWidget {
  const _ReactionManagerChip({
    super.key,
    required this.data,
    required this.onToggle,
  });

  final ReactionPreview data;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final highlighted = data.reactedBySelf;
    final background = highlighted
        ? colors.primary.withValues(alpha: 0.14)
        : colors.secondary.withValues(alpha: 0.05);
    final borderColor = highlighted
        ? colors.primary
        : colors.border.withValues(alpha: 0.9);
    final countStyle = context.textTheme.small.copyWith(
      fontWeight: FontWeight.w600,
      color: highlighted ? colors.primary : colors.mutedForeground,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(data.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              Text(data.count.toString(), style: countStyle),
              if (data.reactedBySelf) ...[
                const SizedBox(width: 6),
                Icon(LucideIcons.minus, size: 16, color: colors.primary),
              ],
            ],
          ),
        ),
      ),
    ).withTapBounce();
  }
}

class _ReactionQuickButton extends StatelessWidget {
  const _ReactionQuickButton({required this.emoji, required this.onPressed});

  final String emoji;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AxiButton.secondary(onPressed: onPressed, child: Text(emoji));
  }
}

class _ReactionAddButton extends StatelessWidget {
  const _ReactionAddButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AxiButton.outline(
      onPressed: onPressed,
      leading: Icon(LucideIcons.plus, size: context.sizing.menuItemIconSize),
      child: Text(context.l10n.chatReactionMore),
    );
  }
}

class _QuotedMessagePreview extends StatelessWidget {
  const _QuotedMessagePreview({
    required this.message,
    required this.senderLabel,
    required this.isSelf,
  });

  final Message message;
  final String senderLabel;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final senderLabelTrimmed = senderLabel.trim();
    return Builder(
      builder: (context) {
        final previewText =
            previewTextForMessage(message) ?? context.l10n.chatQuotedNoContent;
        return ReplyingToPreviewText(
          senderLabel: senderLabelTrimmed,
          quoteText: previewText,
          isSelf: isSelf,
        );
      },
    );
  }
}

class _ForwardedPreviewText extends StatelessWidget {
  const _ForwardedPreviewText({
    required this.senderLabel,
    required this.isSelf,
  });

  final String senderLabel;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final textAlign = isSelf ? TextAlign.end : TextAlign.start;
    final colors = context.colorScheme;
    final baseStyle = context.textTheme.small;
    final prefixStyle = context.textTheme.sectionLabelM;
    final senderStyle = baseStyle.copyWith(
      color: colors.mutedForeground,
      fontWeight: FontWeight.w600,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: context.l10n.chatForwardPrefix, style: prefixStyle),
          const TextSpan(text: ' '),
          TextSpan(text: senderLabel, style: senderStyle),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
    );
  }
}

class _ReplyPreviewBubbleColumn extends MultiChildRenderObjectWidget {
  const _ReplyPreviewBubbleColumn({
    required this.forwardedPreview,
    required this.quotedPreview,
    required this.senderLabel,
    required this.bubble,
    required this.previewMaxWidth,
    required this.spacing,
    required this.previewSpacing,
    required this.alignEnd,
  });

  final Widget? forwardedPreview;
  final Widget? quotedPreview;
  final Widget? senderLabel;
  final Widget bubble;
  final double previewMaxWidth;
  final double spacing;
  final double previewSpacing;
  final bool alignEnd;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReplyPreviewBubbleColumn(
        previewMaxWidth: previewMaxWidth,
        spacing: spacing,
        previewSpacing: previewSpacing,
        hasForwardedPreview: forwardedPreview != null,
        hasQuotedPreview: quotedPreview != null,
        hasSenderLabel: senderLabel != null,
        alignEnd: alignEnd,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderReplyPreviewBubbleColumn renderObject,
  ) {
    renderObject
      ..previewMaxWidth = previewMaxWidth
      ..spacing = spacing
      ..previewSpacing = previewSpacing
      ..hasForwardedPreview = forwardedPreview != null
      ..hasQuotedPreview = quotedPreview != null
      ..hasSenderLabel = senderLabel != null
      ..alignEnd = alignEnd;
  }

  @override
  List<Widget> get children => <Widget>[
    ?senderLabel,
    ?forwardedPreview,
    ?quotedPreview,
    bubble,
  ];
}

class _ReplyPreviewBubbleParentData extends ContainerBoxParentData<RenderBox> {
  double? quoteMaxWidth;
}

class _RenderReplyPreviewBubbleColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ReplyPreviewBubbleParentData>,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          _ReplyPreviewBubbleParentData
        > {
  _RenderReplyPreviewBubbleColumn({
    required double previewMaxWidth,
    required double spacing,
    required double previewSpacing,
    required bool hasForwardedPreview,
    required bool hasQuotedPreview,
    required bool hasSenderLabel,
    required bool alignEnd,
  }) : _previewMaxWidth = previewMaxWidth,
       _spacing = spacing,
       _previewSpacing = previewSpacing,
       _hasForwardedPreview = hasForwardedPreview,
       _hasQuotedPreview = hasQuotedPreview,
       _hasSenderLabel = hasSenderLabel,
       _alignEnd = alignEnd;

  double _previewMaxWidth;
  double _spacing;
  double _previewSpacing;
  bool _hasForwardedPreview;
  bool _hasQuotedPreview;
  bool _hasSenderLabel;
  bool _alignEnd;

  double get previewMaxWidth => _previewMaxWidth;

  set previewMaxWidth(double value) {
    if (_previewMaxWidth == value) return;
    _previewMaxWidth = value;
    markNeedsLayout();
  }

  double get spacing => _spacing;

  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  double get previewSpacing => _previewSpacing;

  set previewSpacing(double value) {
    if (_previewSpacing == value) return;
    _previewSpacing = value;
    markNeedsLayout();
  }

  bool get hasForwardedPreview => _hasForwardedPreview;

  set hasForwardedPreview(bool value) {
    if (_hasForwardedPreview == value) return;
    _hasForwardedPreview = value;
    markNeedsLayout();
  }

  bool get hasQuotedPreview => _hasQuotedPreview;

  set hasQuotedPreview(bool value) {
    if (_hasQuotedPreview == value) return;
    _hasQuotedPreview = value;
    markNeedsLayout();
  }

  bool get hasSenderLabel => _hasSenderLabel;

  set hasSenderLabel(bool value) {
    if (_hasSenderLabel == value) return;
    _hasSenderLabel = value;
    markNeedsLayout();
  }

  bool get alignEnd => _alignEnd;

  set alignEnd(bool value) {
    if (_alignEnd == value) return;
    _alignEnd = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ReplyPreviewBubbleParentData) {
      child.parentData = _ReplyPreviewBubbleParentData();
    }
  }

  @override
  void performLayout() {
    final RenderBox? senderLabelChild = hasSenderLabel ? firstChild : null;
    final RenderBox? forwardedPreviewChild = hasForwardedPreview
        ? (hasSenderLabel ? childAfter(senderLabelChild!) : firstChild)
        : null;
    final RenderBox? quotedPreviewChild = hasQuotedPreview
        ? (hasForwardedPreview
              ? childAfter(forwardedPreviewChild!)
              : (hasSenderLabel ? childAfter(senderLabelChild!) : firstChild))
        : null;
    final RenderBox? bubbleChild = lastChild;
    if (bubbleChild == null) {
      size = constraints.smallest;
      return;
    }
    bubbleChild.layout(constraints.loosen(), parentUsesSize: true);
    final bubbleSize = bubbleChild.size;
    final double bubbleWidth = bubbleSize.width;
    var forwardedPreviewHeight = 0.0;
    var forwardedPreviewWidth = 0.0;
    var quotedPreviewHeight = 0.0;
    var quotedPreviewWidth = 0.0;
    var senderLabelHeight = 0.0;
    var senderLabelWidth = 0.0;
    if (senderLabelChild != null) {
      senderLabelChild.layout(constraints.loosen(), parentUsesSize: true);
      senderLabelHeight = senderLabelChild.size.height;
      senderLabelWidth = senderLabelChild.size.width;
    }
    var layoutWidth = bubbleWidth;
    final effectivePreviewMaxWidth = constraints.hasBoundedWidth
        ? math.min(previewMaxWidth, constraints.maxWidth)
        : previewMaxWidth;
    if (forwardedPreviewChild != null) {
      forwardedPreviewChild.layout(
        BoxConstraints(maxWidth: effectivePreviewMaxWidth),
        parentUsesSize: true,
      );
      forwardedPreviewWidth = forwardedPreviewChild.size.width;
      forwardedPreviewHeight = forwardedPreviewChild.size.height;
      layoutWidth = math.max(layoutWidth, forwardedPreviewWidth);
    }
    if (quotedPreviewChild != null) {
      final quotedPreviewParentData =
          quotedPreviewChild.parentData as _ReplyPreviewBubbleParentData;
      quotedPreviewParentData.quoteMaxWidth = bubbleWidth;
      quotedPreviewChild.layout(
        BoxConstraints(maxWidth: effectivePreviewMaxWidth),
        parentUsesSize: true,
      );
      quotedPreviewWidth = quotedPreviewChild.size.width;
      quotedPreviewHeight = quotedPreviewChild.size.height;
      layoutWidth = math.max(layoutWidth, quotedPreviewWidth);
    }
    final bubbleOffsetX = alignEnd ? layoutWidth - bubbleWidth : 0.0;
    if (senderLabelChild != null) {
      final senderLabelParentData =
          senderLabelChild.parentData as _ReplyPreviewBubbleParentData;
      senderLabelParentData.offset = Offset(
        alignEnd ? bubbleOffsetX + bubbleWidth - senderLabelWidth : 0,
        0,
      );
    }
    var currentY = senderLabelHeight;
    if (forwardedPreviewChild != null) {
      final forwardedPreviewParentData =
          forwardedPreviewChild.parentData as _ReplyPreviewBubbleParentData;
      forwardedPreviewParentData.offset = Offset(
        alignEnd ? layoutWidth - forwardedPreviewWidth : 0,
        currentY,
      );
      currentY += forwardedPreviewHeight;
      currentY += quotedPreviewChild != null ? previewSpacing : spacing;
    }
    if (quotedPreviewChild != null) {
      final quotedPreviewParentData =
          quotedPreviewChild.parentData as _ReplyPreviewBubbleParentData;
      quotedPreviewParentData.offset = Offset(
        alignEnd ? layoutWidth - quotedPreviewWidth : 0,
        currentY,
      );
      currentY += quotedPreviewHeight + spacing;
    }
    final bubbleParentData =
        bubbleChild.parentData as _ReplyPreviewBubbleParentData;
    bubbleParentData.offset = Offset(bubbleOffsetX, currentY);
    size = constraints.constrain(
      Size(layoutWidth, bubbleSize.height + currentY),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}

class _ComposerBannerVisibility extends StatefulWidget {
  const _ComposerBannerVisibility({
    required this.child,
    required this.visible,
    required this.animationDuration,
    required this.minimumVisibleDuration,
    required this.slideOffset,
  });

  final Widget? child;
  final bool visible;
  final Duration animationDuration;
  final Duration minimumVisibleDuration;
  final Offset slideOffset;

  @override
  State<_ComposerBannerVisibility> createState() =>
      _ComposerBannerVisibilityState();
}

class _ComposerBannerVisibilityState extends State<_ComposerBannerVisibility> {
  Widget? displayedChild;
  DateTime? shownAt;
  Timer? hideTimer;
  Object switchKey = Object();

  @override
  void initState() {
    super.initState();
    displayedChild = widget.visible ? widget.child : null;
    shownAt = displayedChild == null ? null : DateTime.timestamp();
  }

  @override
  void didUpdateWidget(covariant _ComposerBannerVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncVisibility();
  }

  void _syncVisibility() {
    final nextChild = widget.child;
    if (widget.visible && nextChild != null) {
      hideTimer?.cancel();
      final previousChild = displayedChild;
      final needsNewKey =
          previousChild == null ||
          previousChild.runtimeType != nextChild.runtimeType ||
          previousChild.key != nextChild.key;
      setState(() {
        displayedChild = nextChild;
        if (previousChild == null || needsNewKey) {
          shownAt = DateTime.timestamp();
        }
        if (needsNewKey) {
          switchKey = Object();
        }
      });
      return;
    }
    if (displayedChild == null) {
      return;
    }
    final elapsed = shownAt == null
        ? widget.minimumVisibleDuration
        : DateTime.timestamp().difference(shownAt!);
    final remaining = widget.minimumVisibleDuration - elapsed;
    if (remaining > Duration.zero) {
      hideTimer?.cancel();
      hideTimer = Timer(remaining, _beginHide);
      return;
    }
    _beginHide();
  }

  void _beginHide() {
    hideTimer?.cancel();
    hideTimer = null;
    if (widget.visible || displayedChild == null) {
      return;
    }
    setState(() {
      displayedChild = null;
      shownAt = null;
      switchKey = Object();
    });
  }

  @override
  void dispose() {
    hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentChild = displayedChild == null
        ? const SizedBox.shrink(key: ValueKey<String>('composer-banner-empty'))
        : KeyedSubtree(
            key: ValueKey<Object>(switchKey),
            child: displayedChild!,
          );
    return AnimatedSize(
      duration: widget.animationDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.hardEdge,
      child: AnimatedSwitcher(
        duration: widget.animationDuration,
        reverseDuration: widget.animationDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              ...previousChildren,
              if (currentChild case final Widget current) current,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return ClipRect(
            child: SlideTransition(
              position: Tween<Offset>(
                begin: widget.slideOffset,
                end: Offset.zero,
              ).animate(curved),
              child: SizeTransition(
                sizeFactor: curved,
                axisAlignment: 1.0,
                child: child,
              ),
            ),
          );
        },
        child: currentChild,
      ),
    );
  }
}

class _DebugComposerBannerCycle extends StatefulWidget {
  const _DebugComposerBannerCycle({
    required this.animationDuration,
    required this.interval,
  });

  final Duration animationDuration;
  final Duration interval;

  @override
  State<_DebugComposerBannerCycle> createState() =>
      _DebugComposerBannerCycleState();
}

class _DebugComposerBannerCycleState extends State<_DebugComposerBannerCycle> {
  Timer? cycleTimer;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant _DebugComposerBannerCycle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interval != widget.interval) {
      _restartTimer();
    }
  }

  void _restartTimer() {
    cycleTimer?.cancel();
    if (widget.interval <= Duration.zero) {
      return;
    }
    cycleTimer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      setState(() {
        currentIndex++;
      });
    });
  }

  @override
  void dispose() {
    cycleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final debugMessage = Message(
      stanzaID: 'debug-composer-banner-quote',
      senderJid: 'debug@axi.im',
      chatJid: 'debug@axi.im',
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      body: 'Debug quote preview content.',
    );
    final banners = <Widget>[
      ComposerQuoteBanner(
        key: const ValueKey<String>('debug-quote-banner'),
        senderLabel: 'Debug Sender',
        previewText:
            previewTextForMessage(debugMessage) ??
            context.l10n.chatQuotedNoContent,
        isSelf: false,
        onClear: () {},
      ),
      _ComposerNotice(
        key: const ValueKey<String>('debug-error-banner'),
        type: _ComposerNoticeType.error,
        message: 'Debug failed-send banner',
        onDismiss: () {},
      ),
      _ComposerNotice(
        key: const ValueKey<String>('debug-warning-banner'),
        type: _ComposerNoticeType.warning,
        message: 'Debug attachment warning banner',
      ),
      _ComposerNotice(
        key: const ValueKey<String>('debug-info-banner'),
        type: _ComposerNoticeType.info,
        message: 'Debug retry/sync banner',
        actionLabel: 'Retry',
        onAction: () {},
      ),
      const _ReadOnlyComposerBanner(key: ValueKey<String>('debug-read-only')),
      const _RoomBootstrapComposerBanner(
        key: ValueKey<String>('debug-room-bootstrap'),
      ),
      _RoomJoinFailureComposerBanner(
        key: const ValueKey<String>('debug-room-failure'),
        detail: 'Membership is required to enter this room',
      ),
      _ComposerAttachedBannerSurface(
        key: const ValueKey<String>('debug-email-sync-banner'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ComposerBannerLeading(
              child: Icon(
                LucideIcons.mailWarning,
                size: context.sizing.menuItemIconSize,
                color: colors.destructive,
              ),
            ),
            SizedBox(width: context.spacing.s),
            Expanded(
              child: Text(
                l10n.messageErrorServiceUnavailable,
                style: textTheme.p.copyWith(
                  color: colors.destructive,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
    final banner = banners[currentIndex % banners.length];
    return AnimatedSwitcher(
      duration: widget.animationDuration,
      reverseDuration: widget.animationDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previousChildren,
            if (currentChild case final Widget current) current,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
      child: banner,
    );
  }
}

class _ComposerBottomOverlay extends StatelessWidget {
  const _ComposerBottomOverlay({
    required this.quotedMessage,
    required this.quotedSenderLabel,
    required this.quotedIsSelf,
    required this.onClearQuote,
    required this.animationDuration,
    this.notices,
    this.banner,
  });

  final Message? quotedMessage;
  final String? quotedSenderLabel;
  final bool quotedIsSelf;
  final VoidCallback onClearQuote;
  final Duration animationDuration;
  final Widget? notices;
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    Widget? quoteSection;
    final quotedMessage = this.quotedMessage;
    final quotedSenderLabel = this.quotedSenderLabel;
    if (quotedMessage == null || quotedSenderLabel == null) {
      quoteSection = null;
    } else {
      quoteSection = ComposerQuoteBanner(
        key: ValueKey<String?>(quotedMessage.stanzaID),
        senderLabel: quotedSenderLabel,
        previewText:
            previewTextForMessage(quotedMessage) ??
            context.l10n.chatQuotedNoContent,
        isSelf: quotedIsSelf,
        onClear: onClearQuote,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ComposerBannerVisibility(
          visible: quoteSection != null,
          animationDuration: animationDuration,
          minimumVisibleDuration: motion.composerBannerMinVisibilityDuration,
          slideOffset: motion.composerBannerSlideOffset,
          child: quoteSection,
        ),
        _ComposerBannerVisibility(
          visible: notices != null,
          animationDuration: animationDuration,
          minimumVisibleDuration: motion.composerBannerMinVisibilityDuration,
          slideOffset: motion.composerBannerSlideOffset,
          child: notices,
        ),
        _ComposerBannerVisibility(
          visible: banner != null,
          animationDuration: animationDuration,
          minimumVisibleDuration: motion.composerBannerMinVisibilityDuration,
          slideOffset: motion.composerBannerSlideOffset,
          child: banner,
        ),
      ],
    );
  }
}

class _ParsedMessageBody extends StatefulWidget {
  const _ParsedMessageBody({
    required this.text,
    required this.baseStyle,
    required this.linkStyle,
    required this.details,
    required this.onLinkTap,
    this.detailActions = const <int, DynamicInlineDetailAction>{},
    this.detailOpticalOffsetFactors = const <int, double>{},
    this.onLinkLongPress,
    this.contentKey,
  });

  final String text;
  final TextStyle baseStyle;
  final TextStyle linkStyle;
  final List<InlineSpan> details;
  final Map<int, DynamicInlineDetailAction> detailActions;
  final Map<int, double> detailOpticalOffsetFactors;
  final ValueChanged<String> onLinkTap;
  final ValueChanged<String>? onLinkLongPress;
  final Object? contentKey;

  @override
  State<_ParsedMessageBody> createState() => _ParsedMessageBodyState();
}

class _ParsedMessageBodyState extends State<_ParsedMessageBody> {
  late ParsedMessageText _parsed;
  String? _text;
  TextStyle? _baseStyle;
  TextStyle? _linkStyle;

  @override
  void initState() {
    super.initState();
    _refreshParsedText();
  }

  @override
  void didUpdateWidget(covariant _ParsedMessageBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_text != widget.text ||
        _baseStyle != widget.baseStyle ||
        _linkStyle != widget.linkStyle) {
      _refreshParsedText();
    }
  }

  void _refreshParsedText() {
    _text = widget.text;
    _baseStyle = widget.baseStyle;
    _linkStyle = widget.linkStyle;
    _parsed = parseMessageText(
      text: widget.text,
      baseStyle: widget.baseStyle,
      linkStyle: widget.linkStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    void handleLinkTap(String url) => widget.onLinkTap(url);

    void handleLinkLongPress(String url) {
      final linkLongPress = widget.onLinkLongPress ?? widget.onLinkTap;
      linkLongPress(url);
    }

    final textKey = widget.contentKey == null
        ? null
        : ValueKey(widget.contentKey);
    final inlineText = DynamicInlineText(
      key: textKey,
      text: _parsed.body,
      details: widget.details,
      detailActions: widget.detailActions,
      detailOpticalOffsetFactors: widget.detailOpticalOffsetFactors,
      links: _parsed.links,
      onLinkTap: handleLinkTap,
      onLinkLongPress: handleLinkLongPress,
    );
    return inlineText;
  }
}

class _MessageHtmlBody extends StatefulWidget {
  const _MessageHtmlBody({
    super.key,
    required this.html,
    required this.textStyle,
    required this.textColor,
    required this.linkColor,
    required this.shouldLoadImages,
    required this.onLinkTap,
  });

  final String html;
  final TextStyle textStyle;
  final Color textColor;
  final Color linkColor;
  final bool shouldLoadImages;
  final ValueChanged<String> onLinkTap;

  @override
  State<_MessageHtmlBody> createState() => _MessageHtmlBodyState();
}

class _MessageHtmlBodyState extends State<_MessageHtmlBody> {
  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final fallbackFontSize =
        widget.textStyle.fontSize ??
        textTheme.p.fontSize ??
        textTheme.small.fontSize ??
        context.sizing.menuItemIconSize;
    return html_widget.Html(
      data: widget.html,
      shrinkWrap: true,
      extensions: createEmailHtmlExtensions(
        shouldLoadImages: widget.shouldLoadImages,
      ),
      style: createEmailHtmlStyles(
        fallbackFontSize: fallbackFontSize,
        textColor: widget.textColor,
        linkColor: widget.linkColor,
      ),
      onLinkTap: (url, _, _) {
        if (url == null) {
          return;
        }
        widget.onLinkTap(url);
      },
    );
  }
}

class _MessageHtmlWebViewBody extends StatelessWidget {
  const _MessageHtmlWebViewBody({
    super.key,
    required this.html,
    required this.backgroundColor,
    required this.textColor,
    required this.linkColor,
    required this.shouldLoadImages,
    required this.onLinkTap,
  });

  final String html;
  final Color backgroundColor;
  final Color textColor;
  final Color linkColor;
  final bool shouldLoadImages;
  final ValueChanged<String> onLinkTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    return EmailHtmlWebView.embedded(
      html: html,
      allowRemoteImages: shouldLoadImages,
      minHeight: sizing.attachmentPreviewExtent,
      backgroundColor: backgroundColor,
      textColor: textColor,
      linkColor: linkColor,
      simplifyLayout: true,
      onLinkTap: onLinkTap,
    );
  }
}

class _MessageViewFullAction extends StatelessWidget {
  const _MessageViewFullAction({
    required this.self,
    required this.label,
    required this.onPressed,
  });

  final bool self;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.xs),
      child: Align(
        alignment: self ? Alignment.centerRight : Alignment.centerLeft,
        child: AxiButton.secondary(
          size: AxiButtonSize.sm,
          onPressed: onPressed,
          child: Text(label),
        ),
      ),
    );
  }
}

class GuestChat extends StatefulWidget {
  const GuestChat({super.key});

  @override
  State<GuestChat> createState() => _GuestChatState();
}

class _GuestScriptEntry {
  const _GuestScriptEntry({
    required this.text,
    required this.offset,
    required this.isSelf,
    this.status = MessageStatus.read,
  });

  final String text;
  final Duration offset;
  final bool isSelf;
  final MessageStatus status;
}

class _GuestPreviewMessage {
  const _GuestPreviewMessage({
    required this.id,
    required this.message,
    this.animateEntry = false,
  });

  final String id;
  final ChatMessage message;
  final bool animateEntry;
}

class _GuestChatState extends State<GuestChat> {
  final _emojiPopoverController = ShadPopoverController();
  late final FocusNode _focusNode;
  late final TextEditingController _textController;
  late final ScrollController _scrollController;
  late ChatUser _selfUser;
  late ChatUser _axiUser;
  late List<_GuestPreviewMessage> _messages;
  Locale? _lastLocale;
  var _composerHasText = false;
  bool get _composerHasContent => _composerHasText;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _textController = TextEditingController();
    _scrollController = ScrollController();
    _messages = const <_GuestPreviewMessage>[];
    _textController.addListener(_handleComposerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshLocalizedScript();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _textController
      ..removeListener(_handleComposerChanged)
      ..dispose();
    _scrollController.dispose();
    _emojiPopoverController.dispose();
    super.dispose();
  }

  void _refreshLocalizedScript() {
    final locale = Localizations.localeOf(context);
    if (_lastLocale == locale && _messages.isNotEmpty) {
      return;
    }
    _lastLocale = locale;
    final l10n = context.l10n;
    _selfUser = ChatUser(id: 'me', firstName: l10n.chatSenderYou);
    _axiUser = ChatUser(id: 'axichat', firstName: appDisplayName);
    _messages = _scriptMessagesForLocale(l10n);
  }

  List<_GuestScriptEntry> _previewScript(AppLocalizations l10n) => [
    _GuestScriptEntry(
      text: l10n.chatGuestScriptWelcome,
      offset: const Duration(minutes: 15),
      isSelf: false,
      status: MessageStatus.read,
    ),
    _GuestScriptEntry(
      text: l10n.chatGuestScriptExternalQuestion,
      offset: const Duration(minutes: 12),
      isSelf: true,
      status: MessageStatus.read,
    ),
    _GuestScriptEntry(
      text: l10n.chatGuestScriptExternalAnswer,
      offset: const Duration(minutes: 10),
      isSelf: false,
      status: MessageStatus.read,
    ),
    _GuestScriptEntry(
      text: l10n.chatGuestScriptOfflineQuestion,
      offset: const Duration(minutes: 8),
      isSelf: true,
      status: MessageStatus.read,
    ),
    _GuestScriptEntry(
      text: l10n.chatGuestScriptOfflineAnswer,
      offset: const Duration(minutes: 7),
      isSelf: false,
      status: MessageStatus.read,
    ),
    _GuestScriptEntry(
      text: l10n.chatGuestScriptKeepUpQuestion,
      offset: const Duration(minutes: 5),
      isSelf: true,
      status: MessageStatus.read,
    ),
    _GuestScriptEntry(
      text: l10n.chatGuestScriptKeepUpAnswer,
      offset: const Duration(minutes: 4),
      isSelf: false,
      status: MessageStatus.read,
    ),
    _GuestScriptEntry(
      text: l10n.chatGuestScriptBubbleTip,
      offset: const Duration(minutes: 3),
      isSelf: false,
      status: MessageStatus.read,
    ),
  ];

  List<_GuestPreviewMessage> _scriptMessagesForLocale(AppLocalizations l10n) {
    final now = DateTime.now();
    return _previewScript(l10n).indexed
        .map(
          (indexedEntry) => _GuestPreviewMessage(
            id: 'guest-script-${indexedEntry.$1}',
            message: ChatMessage(
              user: indexedEntry.$2.isSelf ? _selfUser : _axiUser,
              createdAt: now.subtract(indexedEntry.$2.offset),
              text: indexedEntry.$2.text,
              status: indexedEntry.$2.status,
            ),
          ),
        )
        .toList()
      ..sort((a, b) => b.message.createdAt.compareTo(a.message.createdAt));
  }

  void _handleComposerChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText == _composerHasText) return;
    setState(() {
      _composerHasText = hasText;
    });
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final createdAt = DateTime.now();
    final message = _GuestPreviewMessage(
      id: 'guest-message-${createdAt.microsecondsSinceEpoch}',
      animateEntry: true,
      message: ChatMessage(
        user: _selfUser,
        createdAt: createdAt,
        text: text,
        status: MessageStatus.sent,
      ),
    );
    setState(() {
      _messages.insert(0, message);
      _composerHasText = false;
    });
    _textController.clear();
    _focusNode.requestFocus();
    _scrollToLatest();
  }

  Future<void> _scrollToLatest() async {
    if (!_scrollController.hasClients) return;
    final animationDuration = context.read<SettingsCubit>().animationDuration;
    if (animationDuration == Duration.zero) {
      _scrollController.jumpTo(0);
      return;
    }
    await _scrollController.animateTo(
      0,
      duration: animationDuration,
      curve: Curves.easeOutCubic,
    );
  }

  List<ChatComposerAccessory> _composerAccessories({
    required bool canSend,
    required bool attachmentsEnabled,
  }) {
    return [
      ChatComposerAccessory.leading(
        child: _EmojiPickerAccessory(
          controller: _emojiPopoverController,
          textController: _textController,
        ),
      ),
      ChatComposerAccessory.leading(
        child: _AttachmentAccessoryButton(
          enabled: attachmentsEnabled && false,
          onPressed: _showPreviewAttachmentNotice,
        ),
      ),
      ChatComposerAccessory.trailing(
        child: _SendMessageAccessory(enabled: canSend, onPressed: _handleSend),
      ),
    ];
  }

  void _showPreviewAttachmentNotice() {
    if (!mounted) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.chatGuestAttachmentsDisabled),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(left: context.borderSide),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GuestChatHeader(contact: _axiUser),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxBubbleWidth = math.min(
                  context.sizing.dialogMaxWidth,
                  math.max(0.0, constraints.maxWidth - (spacing.m * 2)),
                );
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: EdgeInsets.zero,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final entry = _messages[index];
                    final message = entry.message;
                    final previous = index + 1 < _messages.length
                        ? _messages[index + 1].message
                        : null;
                    final next = index == 0
                        ? null
                        : _messages[index - 1].message;
                    return _GuestMessageBubble(
                      entry: entry,
                      message: message,
                      previous: previous,
                      next: next,
                      selfUserId: _selfUser.id,
                      maxWidth: maxBubbleWidth,
                    );
                  },
                );
              },
            ),
          ),
          _GuestComposerSection(
            controller: _textController,
            focusNode: _focusNode,
            actions: _composerAccessories(
              canSend: _composerHasContent,
              attachmentsEnabled: false,
            ),
            sendEnabled: _composerHasContent,
            onSend: _handleSend,
          ),
        ],
      ),
    );
  }
}

class _GuestChatHeader extends StatelessWidget {
  const _GuestChatHeader({required this.contact});

  final ChatUser contact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final baseTitleStyle = context.textTheme.h4;
    final titleStyle = baseTitleStyle.copyWith(
      fontSize: context.textTheme.large.fontSize,
    );
    final title = contact.firstName?.isNotEmpty == true
        ? contact.firstName!
        : contact.id;
    return SizedBox(
      height: context.sizing.appBarHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          border: Border(bottom: context.borderSide),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.spacing.m),
          child: Row(
            children: [
              AxichatAppIconAvatar(size: context.sizing.iconButtonSize),
              SizedBox(width: context.spacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                    Text(
                      context.l10n.chatGuestSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.small.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestComposerSection extends StatelessWidget {
  const _GuestComposerSection({
    required this.controller,
    required this.focusNode,
    required this.actions,
    required this.sendEnabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<ChatComposerAccessory> actions;
  final bool sendEnabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colorScheme;
    final horizontalPadding = spacing.l;
    final cutoutBalanceInset = context.sizing.iconButtonTapTarget / 2;
    final rightPadding = math.max(0.0, horizontalPadding - cutoutBalanceInset);
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: !keyboardVisible,
      child: SizedBox(
        width: double.infinity,
        child: ColoredBox(
          color: colors.background,
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border(top: context.borderSide)),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                spacing.m,
                rightPadding,
                spacing.s,
              ),
              child: ChatCutoutComposer(
                controller: controller,
                focusNode: focusNode,
                hintText: context.l10n.chatComposerMessageHint,
                semanticsLabel: context.l10n.chatComposerSemantics,
                onSend: onSend,
                actions: actions,
                sendEnabled: sendEnabled,
                sendOnEnter: context
                    .watch<SettingsCubit>()
                    .state
                    .chatSendOnEnter,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestMessageBubble extends StatelessWidget {
  const _GuestMessageBubble({
    required this.entry,
    required this.message,
    required this.previous,
    required this.next,
    required this.selfUserId,
    required this.maxWidth,
  });

  final _GuestPreviewMessage entry;
  final ChatMessage message;
  final ChatMessage? previous;
  final ChatMessage? next;
  final String selfUserId;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final chatTokens = context.chatTheme;
    final spacing = context.spacing;
    final settings = context.watch<SettingsCubit>().state;
    final isSelf = message.user.id == selfUserId;
    final chainedPrev = _chatMessagesShouldChain(message, previous);
    final chainedNext = _chatMessagesShouldChain(message, next);
    final backgroundColor = isSelf ? colors.primary : colors.card;
    final borderColor = isSelf ? Colors.transparent : chatTokens.recvEdge;
    final textColor = isSelf ? colors.primaryForeground : colors.foreground;
    final timestampColor = isSelf
        ? colors.primaryForeground
        : chatTokens.timestamp;
    final bubbleBaseRadius = _bubbleBaseRadius(context);
    final bubbleCornerClearance = _bubbleCornerClearance(bubbleBaseRadius);
    final statusIcon = message.status?.icon;
    final baseStyle = context.textTheme.small.copyWith(
      color: textColor,
      fontSize: settings.messageTextSize.fontSize,
      height: 1.3,
    );
    final linkStyle = baseStyle.copyWith(
      color: isSelf ? colors.primaryForeground : colors.primary,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    );
    final detailStyle = context.textTheme.muted.copyWith(
      color: timestampColor,
      height: 1.0,
      textBaseline: TextBaseline.alphabetic,
    );
    TextSpan iconDetailSpan(IconData icon) => TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: detailStyle.copyWith(
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
      ),
    );
    final timeLabel =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';
    final details = <InlineSpan>[
      TextSpan(text: timeLabel, style: detailStyle),
      iconDetailSpan(LucideIcons.messageCircle),
      if (isSelf && statusIcon != null) iconDetailSpan(statusIcon),
    ];

    final bubble = ChatBubbleSurface(
      isSelf: isSelf,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      borderRadius: _bubbleBorderRadius(
        baseRadius: bubbleBaseRadius,
        isSelf: isSelf,
        chainedPrevious: chainedPrev,
        chainedNext: chainedNext,
      ),
      shadowOpacity: 0,
      shadows: const <BoxShadow>[],
      bubbleWidthFraction: 1.0,
      cornerClearance: bubbleCornerClearance,
      body: Padding(
        padding: _bubblePadding(context),
        child: _ParsedMessageBody(
          contentKey: entry.id,
          text: message.text,
          baseStyle: baseStyle,
          linkStyle: linkStyle,
          details: details,
          onLinkTap: (_) {},
        ),
      ),
    );
    final senderLabel = !chainedPrev
        ? _MessageSenderLabel(
            user: message.user,
            isSelf: isSelf,
            selfLabel: context.l10n.chatSenderYou,
            leftInset: 0.0,
          )
        : null;
    final bubbleStack = _ReplyPreviewBubbleColumn(
      forwardedPreview: null,
      quotedPreview: null,
      senderLabel: senderLabel,
      bubble: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: bubble,
      ),
      previewMaxWidth: maxWidth,
      spacing: spacing.s,
      previewSpacing: spacing.xxs,
      alignEnd: isSelf,
    );
    final animatedBubble = AxiAnimatedSize(
      duration: _bubbleFocusDuration,
      reverseDuration: _bubbleFocusDuration,
      curve: _bubbleFocusCurve,
      alignment: isSelf ? Alignment.topRight : Alignment.topLeft,
      clipBehavior: Clip.none,
      child: bubbleStack,
    );
    final arrival = _MessageArrivalAnimator(
      key: ValueKey('guest-arrival-${entry.id}'),
      animate: entry.animateEntry,
      isSelf: isSelf,
      child: animatedBubble,
    );

    return Padding(
      padding: EdgeInsets.only(
        top: chainedPrev ? spacing.xxs : spacing.s,
        bottom: chainedNext ? spacing.xxs : spacing.m,
        left: spacing.m,
        right: spacing.m,
      ),
      child: Align(
        alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
        child: arrival,
      ),
    );
  }
}

class _MessageSenderLabel extends StatelessWidget {
  const _MessageSenderLabel({
    required this.user,
    required this.isSelf,
    required this.selfLabel,
    required this.leftInset,
  });

  final ChatUser user;
  final bool isSelf;
  final String selfLabel;
  final double leftInset;

  @override
  Widget build(BuildContext context) {
    final String trimmedSelfLabel = selfLabel.trim();
    final UnicodeSanitizedText displayName = sanitizeUnicodeControls(
      user.getFullName().trim(),
    );
    final UnicodeSanitizedText address = sanitizeUnicodeControls(
      user.id.trim(),
    );
    final String safeDisplayName = displayName.value.trim();
    final String safeAddress = address.value.trim();
    if (isSelf) {
      if (trimmedSelfLabel.isEmpty) {
        return const SizedBox.shrink();
      }
      return _SenderLabelBlock(
        primaryLabel: trimmedSelfLabel,
        secondaryLabel: null,
        isSelf: isSelf,
        leftInset: leftInset,
      );
    }
    if (safeDisplayName.isEmpty && safeAddress.isEmpty) {
      return const SizedBox.shrink();
    }
    final String primaryLabel = safeDisplayName.isNotEmpty
        ? safeDisplayName
        : safeAddress;
    return _SenderLabelBlock(
      primaryLabel: primaryLabel,
      secondaryLabel: null,
      isSelf: isSelf,
      leftInset: leftInset,
    );
  }
}

class _SenderLabelBlock extends StatelessWidget {
  const _SenderLabelBlock({
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.isSelf,
    required this.leftInset,
  });

  final String primaryLabel;
  final String? secondaryLabel;
  final bool isSelf;
  final double leftInset;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final textAlign = isSelf ? TextAlign.right : TextAlign.left;
    final crossAxis = isSelf
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final secondaryLabel = this.secondaryLabel?.trim();
    final trimmedPrimaryLabel = primaryLabel.trim();
    if (trimmedPrimaryLabel.isEmpty &&
        (secondaryLabel == null || secondaryLabel.isEmpty)) {
      return const SizedBox.shrink();
    }
    final primaryStyle = context.textTheme.small.copyWith(
      color: colors.mutedForeground,
      fontWeight: FontWeight.w600,
    );
    final secondaryStyle = context.textTheme.muted.copyWith(
      color: colors.mutedForeground,
    );
    final labelChildren = <Widget>[
      if (trimmedPrimaryLabel.isNotEmpty)
        Text(trimmedPrimaryLabel, style: primaryStyle, textAlign: textAlign),
      if (secondaryLabel != null && secondaryLabel.isNotEmpty)
        Text(secondaryLabel, style: secondaryStyle, textAlign: textAlign),
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.s, left: leftInset),
      child: Column(
        spacing: spacing.xxs,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxis,
        children: labelChildren,
      ),
    );
  }
}

class _UnreadBubbleSideIndicator extends StatelessWidget {
  const _UnreadBubbleSideIndicator({
    required this.visible,
    required this.isSelf,
  });

  final bool visible;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final collapseAlignment = isSelf
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final indicatorAlignment = isSelf
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final dotSize = sizing.menuItemIconSize / 2;
    final indicatorExtent = dotSize + spacing.xs;
    return AxiAnimatedSize(
      duration: _bubbleFocusDuration,
      reverseDuration: _bubbleFocusDuration,
      curve: _bubbleFocusCurve,
      alignment: collapseAlignment,
      clipBehavior: Clip.none,
      child: SizedBox(
        width: visible ? indicatorExtent : 0,
        height: dotSize,
        child: Align(
          alignment: indicatorAlignment,
          child: AnimatedOpacity(
            duration: _bubbleFocusDuration,
            curve: _bubbleFocusCurve,
            opacity: visible ? 1 : 0,
            child: SizedBox(
              width: dotSize,
              height: dotSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.destructive,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatTimelineMessageRowView extends StatelessWidget {
  const _ChatTimelineMessageRowView({
    required this.messageId,
    required this.rowKey,
    required this.readOnly,
    required this.self,
    required this.isSingleSelection,
    required this.isEmailMessage,
    required this.showUnreadIndicator,
    required this.messageRowMaxWidth,
    required this.bubblePreviewWidth,
    required this.replyPreviewMaxWidth,
    required this.messageRowAlignment,
    required this.outerPadding,
    required this.bubble,
    required this.senderLabel,
    required this.forwardedPreview,
    required this.quotedPreview,
    required this.attachmentsAligned,
    required this.extrasAligned,
    required this.showExtras,
    required this.bubbleRegionRegistry,
    required this.selectionTapRegionGroup,
    required this.animate,
    required this.onBubbleTap,
    required this.onBubbleSizeChanged,
    this.onTapOutside,
  });

  final String messageId;
  final Key? rowKey;
  final bool readOnly;
  final bool self;
  final bool isSingleSelection;
  final bool isEmailMessage;
  final bool showUnreadIndicator;
  final double messageRowMaxWidth;
  final double bubblePreviewWidth;
  final double replyPreviewMaxWidth;
  final AlignmentGeometry messageRowAlignment;
  final EdgeInsetsGeometry outerPadding;
  final Widget bubble;
  final Widget? senderLabel;
  final Widget? forwardedPreview;
  final Widget? quotedPreview;
  final Widget attachmentsAligned;
  final Widget extrasAligned;
  final bool showExtras;
  final _BubbleRegionRegistry bubbleRegionRegistry;
  final Object selectionTapRegionGroup;
  final bool animate;
  final VoidCallback? onBubbleTap;
  final ValueChanged<Size> onBubbleSizeChanged;
  final TapRegionCallback? onTapOutside;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final messageColumnAlignment = self
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final selectableBubble = MouseRegion(
      cursor: readOnly ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onBubbleTap,
        onLongPress: null,
        onSecondaryTapUp: null,
        child: bubble,
      ),
    );
    final bubbleStack = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [selectableBubble],
    );
    final measuredBubbleStack = isSingleSelection
        ? _SizeReportingWidget(
            onSizeChange: onBubbleSizeChanged,
            child: bubbleStack,
          )
        : bubbleStack;
    final bubbleWithSlack = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: bubblePreviewWidth),
      child: measuredBubbleStack,
    );
    final bubbleWithIndicator = isEmailMessage
        ? Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (self)
                _UnreadBubbleSideIndicator(
                  visible: showUnreadIndicator,
                  isSelf: self,
                ),
              _MessageBubbleRegion(
                messageId: messageId,
                registry: bubbleRegionRegistry,
                child: bubbleWithSlack,
              ),
              if (!self)
                _UnreadBubbleSideIndicator(
                  visible: showUnreadIndicator,
                  isSelf: self,
                ),
            ],
          )
        : bubbleWithSlack;
    final bubbleStackWithReply = _ReplyPreviewBubbleColumn(
      forwardedPreview: forwardedPreview,
      quotedPreview: quotedPreview,
      senderLabel: senderLabel,
      bubble: bubbleWithIndicator,
      previewMaxWidth: replyPreviewMaxWidth,
      spacing: spacing.s,
      previewSpacing: spacing.xxs,
      alignEnd: self,
    );
    final animatedBubbleStackWithReply = AxiAnimatedSize(
      duration: _bubbleFocusDuration,
      reverseDuration: _bubbleFocusDuration,
      curve: _bubbleFocusCurve,
      alignment: self ? Alignment.topRight : Alignment.topLeft,
      clipBehavior: Clip.none,
      child: bubbleStackWithReply,
    );
    final messageBody = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: messageColumnAlignment,
      children: [
        animatedBubbleStackWithReply,
        if (showExtras) extrasAligned,
        attachmentsAligned,
      ],
    );
    final messageArrival = _MessageArrivalAnimator(
      key: ValueKey<String>('arrival-$messageId'),
      animate: animate,
      isSelf: self,
      child: messageBody,
    );
    final selectionRegion = TapRegion(
      groupId: selectionTapRegionGroup,
      onTapOutside: onTapOutside,
      child: messageArrival,
    );
    final alignedMessage = SizedBox(
      width: messageRowMaxWidth,
      child: AnimatedAlign(
        duration: _bubbleFocusDuration,
        curve: _bubbleFocusCurve,
        alignment: messageRowAlignment,
        child: selectionRegion,
      ),
    );
    return KeyedSubtree(
      key: rowKey,
      child: Padding(padding: outerPadding, child: alignedMessage),
    );
  }
}

class _ChatTimelineBubbleView extends StatelessWidget {
  const _ChatTimelineBubbleView({
    required this.self,
    required this.isSelected,
    required this.showBubbleSurface,
    required this.bubbleSurfaceColor,
    required this.bubbleSurfaceBorder,
    required this.bubbleBorderRadius,
    required this.bubbleShadows,
    required this.cornerClearance,
    required this.body,
    required this.textConstraints,
    this.reactionOverlay,
    this.reactionStyle,
    this.recipientOverlay,
    this.recipientStyle,
    this.recipientAnchor = ChatBubbleCutoutAnchor.bottom,
    this.avatarOverlay,
    this.avatarStyle,
    this.avatarAnchor = ChatBubbleCutoutAnchor.left,
    this.selectionOverlay,
    this.selectionStyle,
  });

  final bool self;
  final bool isSelected;
  final bool showBubbleSurface;
  final Color bubbleSurfaceColor;
  final Color bubbleSurfaceBorder;
  final BorderRadius bubbleBorderRadius;
  final List<BoxShadow> bubbleShadows;
  final double cornerClearance;
  final Widget body;
  final BoxConstraints textConstraints;
  final Widget? reactionOverlay;
  final CutoutStyle? reactionStyle;
  final Widget? recipientOverlay;
  final CutoutStyle? recipientStyle;
  final ChatBubbleCutoutAnchor recipientAnchor;
  final Widget? avatarOverlay;
  final CutoutStyle? avatarStyle;
  final ChatBubbleCutoutAnchor avatarAnchor;
  final Widget? selectionOverlay;
  final CutoutStyle? selectionStyle;

  @override
  Widget build(BuildContext context) {
    final bubbleHighlightColor = context.colorScheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: isSelected ? 1.0 : 0.0),
      duration: _bubbleFocusDuration,
      curve: _bubbleFocusCurve,
      child: body,
      builder: (context, shadowValue, child) {
        return ConstrainedBox(
          constraints: textConstraints,
          child: ChatBubbleSurface(
            isSelf: self,
            backgroundColor: bubbleSurfaceColor,
            borderColor: bubbleSurfaceBorder,
            borderRadius: bubbleBorderRadius,
            shadowOpacity: showBubbleSurface ? shadowValue : 0.0,
            shadows: bubbleShadows.isNotEmpty
                ? bubbleShadows
                : _selectedBubbleShadows(bubbleHighlightColor),
            bubbleWidthFraction: 1.0,
            cornerClearance: cornerClearance,
            body: child!,
            reactionOverlay: reactionOverlay,
            reactionStyle: reactionStyle,
            recipientOverlay: recipientOverlay,
            recipientStyle: recipientStyle,
            recipientAnchor: recipientAnchor,
            avatarOverlay: avatarOverlay,
            avatarStyle: avatarStyle,
            avatarAnchor: avatarAnchor,
            selectionOverlay: selectionOverlay,
            selectionStyle: selectionStyle,
            selectionFollowsSelfEdge: false,
          ),
        );
      },
    );
  }
}

class _ChatTimelineMessageSelectionExtras extends StatelessWidget {
  const _ChatTimelineMessageSelectionExtras({
    required this.self,
    required this.isSingleSelection,
    required this.actionBar,
    required this.reactionManager,
    required this.availableWidth,
    required this.selectionExtrasPreferredMaxWidth,
    required this.bubbleMaxWidthForLayout,
    required this.messageRowMaxWidth,
    required this.measuredBubbleWidth,
    required this.attachmentPadding,
    required this.bubbleBottomCutoutPadding,
  });

  final bool self;
  final bool isSingleSelection;
  final Widget actionBar;
  final Widget? reactionManager;
  final double availableWidth;
  final double selectionExtrasPreferredMaxWidth;
  final double bubbleMaxWidthForLayout;
  final double messageRowMaxWidth;
  final double? measuredBubbleWidth;
  final EdgeInsets attachmentPadding;
  final double bubbleBottomCutoutPadding;

  @override
  Widget build(BuildContext context) {
    final clampedMeasuredBubbleWidth = measuredBubbleWidth
        ?.clamp(0.0, bubbleMaxWidthForLayout)
        .toDouble();
    final bubbleIsVisuallyFullWidth =
        isSingleSelection &&
        clampedMeasuredBubbleWidth != null &&
        clampedMeasuredBubbleWidth >=
            bubbleMaxWidthForLayout - context.borderSide.width;
    final legacySelectionExtrasMaxWidth = math.min(
      availableWidth,
      selectionExtrasPreferredMaxWidth,
    );
    final selectionExtrasMaxWidth = math
        .max(
          legacySelectionExtrasMaxWidth,
          bubbleIsVisuallyFullWidth ? bubbleMaxWidthForLayout : 0.0,
        )
        .clamp(0.0, messageRowMaxWidth)
        .toDouble();
    final selectionExtrasChild = Align(
      alignment: self ? Alignment.centerRight : Alignment.centerLeft,
      child: SizedBox(
        width: selectionExtrasMaxWidth,
        child: Padding(
          padding: attachmentPadding.copyWith(
            top: attachmentPadding.top + bubbleBottomCutoutPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              actionBar,
              if (reactionManager != null) const SizedBox(height: 20),
              ?reactionManager,
            ],
          ),
        ),
      ),
    );
    final selectionExtras = IgnorePointer(
      ignoring: !isSingleSelection,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: isSingleSelection ? 1.0 : 0.0),
        duration: _bubbleFocusDuration,
        curve: _bubbleFocusCurve,
        builder: (context, value, child) {
          return ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: value,
              child: Opacity(opacity: value, child: child),
            ),
          );
        },
        child: selectionExtrasChild,
      ),
    );
    return AxiAnimatedSize(
      duration: _bubbleFocusDuration,
      reverseDuration: _bubbleFocusDuration,
      curve: _bubbleFocusCurve,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      child: selectionExtras,
    );
  }
}

class _ChatTimelineMessageExtrasView extends StatelessWidget {
  const _ChatTimelineMessageExtrasView({
    required this.self,
    required this.isSelected,
    required this.bubbleBottomCutoutPadding,
    required this.bubbleContentKey,
    required this.bubbleExtraChildren,
    required this.bubbleExtraConstraints,
    required this.extraShadows,
  });

  final bool self;
  final bool isSelected;
  final double bubbleBottomCutoutPadding;
  final Object bubbleContentKey;
  final List<Widget> bubbleExtraChildren;
  final BoxConstraints bubbleExtraConstraints;
  final List<BoxShadow> extraShadows;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: isSelected ? 1.0 : 0.0),
      duration: _bubbleFocusDuration,
      curve: _bubbleFocusCurve,
      builder: (context, shadowValue, child) {
        final extras = bubbleBottomCutoutPadding > 0
            ? <Widget>[
                _MessageExtraGap(
                  key: ValueKey<String>('$bubbleContentKey-extra-cutout-gap'),
                  height: bubbleBottomCutoutPadding,
                ),
                ...bubbleExtraChildren,
              ]
            : bubbleExtraChildren;
        return ConstrainedBox(
          constraints: bubbleExtraConstraints,
          child: _MessageExtrasColumn(
            shadowValue: shadowValue,
            shadows: extraShadows,
            crossAxisAlignment: self
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: extras,
          ),
        );
      },
    );
  }
}

class _ChatTimelineMessageInteractionView extends StatelessWidget {
  const _ChatTimelineMessageInteractionView({
    required this.currentItem,
    required this.previous,
    required this.next,
    required this.timelineMessageItem,
    required this.state,
    required this.chatEntity,
    required this.roomState,
    required this.currentUserId,
    required this.selfNick,
    required this.selfXmppJid,
    required this.myOccupantJid,
    required this.resolvedDirectChatDisplayName,
    required this.readOnly,
    required this.isGroupChat,
    required this.isEmailChat,
    required this.isWelcomeChat,
    required this.attachmentsBlockedForChat,
    required this.multiSelectActive,
    required this.selectedMessageId,
    required this.canTogglePins,
    required this.availabilityActorId,
    required this.availabilityShareOwnersById,
    required this.availabilityCoordinator,
    required this.normalizedXmppSelfJid,
    required this.normalizedEmailSelfJid,
    required this.personalCalendarAvailable,
    required this.chatCalendarAvailable,
    required this.messageFontSize,
    required this.availableWidth,
    required this.inboundMessageRowMaxWidth,
    required this.outboundMessageRowMaxWidth,
    required this.inboundClampedBubbleWidth,
    required this.outboundClampedBubbleWidth,
    required this.messageRowMaxWidth,
    required this.selectionExtrasPreferredMaxWidth,
    required this.shareRequestStatus,
    required this.bubbleRegionRegistry,
    required this.selectionTapRegionGroup,
    required this.messageKeys,
    required this.bubbleWidthByMessageId,
    required this.shouldAnimateMessage,
    required this.isPinnedMessage,
    required this.isImportantMessage,
    required this.onTapOutsideRequested,
    required this.resolveViewData,
    required this.resolveInteractionData,
    required this.composeBubbleContent,
    required this.onReplyRequested,
    required this.onForwardRequested,
    required this.onCopyRequested,
    required this.onShareRequested,
    required this.onAddToCalendarRequested,
    required this.onDetailsRequested,
    required this.onStartMultiSelectRequested,
    required this.onResendRequested,
    required this.onEditRequested,
    required this.onImportantToggleRequested,
    required this.onPinToggleRequested,
    required this.onRevokeInviteRequested,
    required this.onBubbleTapRequested,
    required this.onToggleMultiSelectRequested,
    required this.onToggleQuickReactionRequested,
    required this.onReactionSelectionRequested,
    required this.onRecipientTap,
    required this.onBubbleSizeChanged,
  });

  final ChatTimelineItem currentItem;
  final ChatTimelineItem? previous;
  final ChatTimelineItem? next;
  final ChatTimelineMessageItem timelineMessageItem;
  final ChatState state;
  final chat_models.Chat? chatEntity;
  final RoomState? roomState;
  final String? currentUserId;
  final String? selfNick;
  final String? selfXmppJid;
  final String? myOccupantJid;
  final String? resolvedDirectChatDisplayName;
  final bool readOnly;
  final bool isGroupChat;
  final bool isEmailChat;
  final bool isWelcomeChat;
  final bool attachmentsBlockedForChat;
  final bool multiSelectActive;
  final String? selectedMessageId;
  final bool canTogglePins;
  final String? availabilityActorId;
  final Map<String, String> availabilityShareOwnersById;
  final CalendarAvailabilityShareCoordinator? availabilityCoordinator;
  final String? normalizedXmppSelfJid;
  final String? normalizedEmailSelfJid;
  final bool personalCalendarAvailable;
  final bool chatCalendarAvailable;
  final double messageFontSize;
  final double availableWidth;
  final double inboundMessageRowMaxWidth;
  final double outboundMessageRowMaxWidth;
  final double inboundClampedBubbleWidth;
  final double outboundClampedBubbleWidth;
  final double messageRowMaxWidth;
  final double selectionExtrasPreferredMaxWidth;
  final RequestStatus shareRequestStatus;
  final _BubbleRegionRegistry bubbleRegionRegistry;
  final Object selectionTapRegionGroup;
  final Map<String, GlobalKey> messageKeys;
  final Map<String, double> bubbleWidthByMessageId;
  final bool Function(Message message) shouldAnimateMessage;
  final bool Function(Message message) isPinnedMessage;
  final bool Function(Message message) isImportantMessage;
  final TapRegionCallback onTapOutsideRequested;
  final ({
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
  Function({
    required BuildContext context,
    required ChatTimelineMessageItem timelineMessageItem,
    required bool isPinned,
    required bool isImportant,
    required double inboundMessageRowMaxWidth,
    required double outboundMessageRowMaxWidth,
    required double messageFontSize,
  })
  resolveViewData;
  final ({
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
  Function({
    required ChatState state,
    required ChatTimelineMessageItem timelineMessageItem,
    required Message messageModel,
    required bool isEmailMessage,
    required bool isEmailChat,
    required bool isGroupChat,
    required String? selfXmppJid,
    required String? myOccupantJid,
  })
  resolveInteractionData;
  final ({
    Object bubbleContentKey,
    List<Widget> bubbleTextChildren,
    List<Widget> bubbleExtraChildren,
  })
  Function({
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
  })
  composeBubbleContent;
  final void Function(Message message) onReplyRequested;
  final Future<void> Function(Message message) onForwardRequested;
  final Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onCopyRequested;
  final Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onShareRequested;
  final Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onAddToCalendarRequested;
  final void Function(String detailId) onDetailsRequested;
  final void Function(Message message) onStartMultiSelectRequested;
  final void Function(Message message, {required chat_models.Chat? chat})
  onResendRequested;
  final Future<void> Function(Message message) onEditRequested;
  final void Function(
    Message message, {
    required bool important,
    required chat_models.Chat? chat,
  })
  onImportantToggleRequested;
  final void Function(
    Message message, {
    required bool pin,
    required chat_models.Chat? chat,
    required RoomState? roomState,
  })
  onPinToggleRequested;
  final void Function(Message message, {String? inviteeJidFallback})
  onRevokeInviteRequested;
  final void Function(Message message, {required bool showUnreadIndicator})
  onBubbleTapRequested;
  final void Function(Message message) onToggleMultiSelectRequested;
  final void Function(Message message, String emoji)
  onToggleQuickReactionRequested;
  final Future<void> Function(Message message) onReactionSelectionRequested;
  final void Function(chat_models.Chat chat) onRecipientTap;
  final void Function(String messageId, Size size) onBubbleSizeChanged;

  @override
  Widget build(BuildContext context) {
    final messageModel = timelineMessageItem.messageModel;
    final isPinned = isPinnedMessage(messageModel);
    final isImportant = isImportantMessage(messageModel);
    final rowKey = messageKeys[messageModel.stanzaID];
    final measuredBubbleWidth = bubbleWidthByMessageId[messageModel.stanzaID];
    final animate = shouldAnimateMessage(messageModel);
    final onTapOutside =
        !multiSelectActive && selectedMessageId == messageModel.stanzaID
        ? onTapOutsideRequested
        : null;
    final (
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
    ) = resolveViewData(
      context: context,
      timelineMessageItem: timelineMessageItem,
      isPinned: isPinned,
      isImportant: isImportant,
      inboundMessageRowMaxWidth: inboundMessageRowMaxWidth,
      outboundMessageRowMaxWidth: outboundMessageRowMaxWidth,
      messageFontSize: messageFontSize,
    );
    final (
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
    ) = resolveInteractionData(
      state: state,
      timelineMessageItem: timelineMessageItem,
      messageModel: messageModel,
      isEmailMessage: isEmailMessage,
      isEmailChat: isEmailChat,
      isGroupChat: isGroupChat,
      selfXmppJid: selfXmppJid,
      myOccupantJid: myOccupantJid,
    );
    final (
      bubbleContentKey: bubbleContentKey,
      bubbleTextChildren: bubbleTextChildren,
      bubbleExtraChildren: bubbleExtraChildren,
    ) = composeBubbleContent(
      context: context,
      state: state,
      detailId: detailId,
      timelineMessageItem: timelineMessageItem,
      messageModel: messageModel,
      messageText: messageText,
      self: self,
      isError: isError,
      isInviteMessage: isInviteMessage,
      isInviteRevocationMessage: isInviteRevocationMessage,
      inviteRevoked: inviteRevoked,
      isEmailMessage: isEmailMessage,
      isEmailChat: isEmailChat,
      isSingleSelection: isSingleSelection,
      isWelcomeChat: isWelcomeChat,
      attachmentsBlockedForChat: attachmentsBlockedForChat,
      showCompactReactions: showCompactReactions,
      showReplyStrip: showReplyStrip,
      showRecipientCutout: showRecipientCutout,
      availabilityActorId: availabilityActorId,
      availabilityShareOwnersById: availabilityShareOwnersById,
      availabilityCoordinator: availabilityCoordinator,
      normalizedXmppSelfJid: normalizedXmppSelfJid,
      normalizedEmailSelfJid: normalizedEmailSelfJid,
      personalCalendarAvailable: personalCalendarAvailable,
      chatCalendarAvailable: chatCalendarAvailable,
      selfXmppJid: selfXmppJid,
      bubbleColor: bubbleColor,
      textColor: textColor,
      baseTextStyle: baseTextStyle,
      linkStyle: linkStyle,
      surfaceDetailStyle: surfaceDetailStyle,
      extraStyle: extraStyle,
      messageDetails: messageDetails,
      surfaceDetails: surfaceDetails,
      detailOpticalOffsetFactors: detailOpticalOffsetFactors,
      attachmentIds: attachmentIds,
    );
    return _ChatTimelineMessageChromeView(
      currentItem: currentItem,
      previous: previous,
      next: next,
      timelineMessageItem: timelineMessageItem,
      messageModel: messageModel,
      chatEntity: chatEntity,
      roomState: roomState,
      currentUserId: currentUserId,
      selfNick: selfNick,
      resolvedDirectChatDisplayName: resolvedDirectChatDisplayName,
      readOnly: readOnly,
      isGroupChat: isGroupChat,
      multiSelectActive: multiSelectActive,
      canTogglePins: canTogglePins,
      shareRequestStatus: shareRequestStatus,
      bubbleRegionRegistry: bubbleRegionRegistry,
      selectionTapRegionGroup: selectionTapRegionGroup,
      rowKey: rowKey,
      measuredBubbleWidth: measuredBubbleWidth,
      animate: animate,
      onTapOutside: onTapOutside,
      availableWidth: availableWidth,
      inboundClampedBubbleWidth: inboundClampedBubbleWidth,
      outboundClampedBubbleWidth: outboundClampedBubbleWidth,
      messageRowMaxWidth: messageRowMaxWidth,
      selectionExtrasPreferredMaxWidth: selectionExtrasPreferredMaxWidth,
      viewData: (
        detailId: detailId,
        self: self,
        bubbleMaxWidth: bubbleMaxWidth,
        bubbleColor: bubbleColor,
        borderColor: borderColor,
        isEmailMessage: isEmailMessage,
        isPinned: isPinned,
        isImportant: isImportant,
      ),
      interactionData: (
        reactions: reactions,
        replyParticipants: replyParticipants,
        recipientCutoutParticipants: recipientCutoutParticipants,
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
      ),
      bubbleContentData: (
        bubbleContentKey: bubbleContentKey,
        bubbleTextChildren: bubbleTextChildren,
        bubbleExtraChildren: bubbleExtraChildren,
      ),
      onReplyRequested: onReplyRequested,
      onForwardRequested: onForwardRequested,
      onCopyRequested: onCopyRequested,
      onShareRequested: onShareRequested,
      onAddToCalendarRequested: onAddToCalendarRequested,
      onDetailsRequested: onDetailsRequested,
      onStartMultiSelectRequested: onStartMultiSelectRequested,
      onResendRequested: onResendRequested,
      onEditRequested: onEditRequested,
      onImportantToggleRequested: onImportantToggleRequested,
      onPinToggleRequested: onPinToggleRequested,
      onRevokeInviteRequested: onRevokeInviteRequested,
      onBubbleTapRequested: onBubbleTapRequested,
      onToggleMultiSelectRequested: onToggleMultiSelectRequested,
      onToggleQuickReactionRequested: onToggleQuickReactionRequested,
      onReactionSelectionRequested: onReactionSelectionRequested,
      onRecipientTap: onRecipientTap,
      onBubbleSizeChanged: onBubbleSizeChanged,
    );
  }
}

class _ChatTimelineMessageChromeView extends StatelessWidget {
  const _ChatTimelineMessageChromeView({
    required this.currentItem,
    required this.previous,
    required this.next,
    required this.timelineMessageItem,
    required this.messageModel,
    required this.chatEntity,
    required this.roomState,
    required this.currentUserId,
    required this.selfNick,
    required this.resolvedDirectChatDisplayName,
    required this.readOnly,
    required this.isGroupChat,
    required this.multiSelectActive,
    required this.canTogglePins,
    required this.shareRequestStatus,
    required this.bubbleRegionRegistry,
    required this.selectionTapRegionGroup,
    required this.rowKey,
    required this.measuredBubbleWidth,
    required this.animate,
    required this.onTapOutside,
    required this.availableWidth,
    required this.inboundClampedBubbleWidth,
    required this.outboundClampedBubbleWidth,
    required this.messageRowMaxWidth,
    required this.selectionExtrasPreferredMaxWidth,
    required this.viewData,
    required this.interactionData,
    required this.bubbleContentData,
    required this.onReplyRequested,
    required this.onForwardRequested,
    required this.onCopyRequested,
    required this.onShareRequested,
    required this.onAddToCalendarRequested,
    required this.onDetailsRequested,
    required this.onStartMultiSelectRequested,
    required this.onResendRequested,
    required this.onEditRequested,
    required this.onImportantToggleRequested,
    required this.onPinToggleRequested,
    required this.onRevokeInviteRequested,
    required this.onBubbleTapRequested,
    required this.onToggleMultiSelectRequested,
    required this.onToggleQuickReactionRequested,
    required this.onReactionSelectionRequested,
    required this.onRecipientTap,
    required this.onBubbleSizeChanged,
  });

  final ChatTimelineItem currentItem;
  final ChatTimelineItem? previous;
  final ChatTimelineItem? next;
  final ChatTimelineMessageItem timelineMessageItem;
  final Message messageModel;
  final chat_models.Chat? chatEntity;
  final RoomState? roomState;
  final String? currentUserId;
  final String? selfNick;
  final String? resolvedDirectChatDisplayName;
  final bool readOnly;
  final bool isGroupChat;
  final bool multiSelectActive;
  final bool canTogglePins;
  final RequestStatus shareRequestStatus;
  final _BubbleRegionRegistry bubbleRegionRegistry;
  final Object selectionTapRegionGroup;
  final Key? rowKey;
  final double? measuredBubbleWidth;
  final bool animate;
  final TapRegionCallback? onTapOutside;
  final double availableWidth;
  final double inboundClampedBubbleWidth;
  final double outboundClampedBubbleWidth;
  final double messageRowMaxWidth;
  final double selectionExtrasPreferredMaxWidth;
  final ({
    String detailId,
    bool self,
    double bubbleMaxWidth,
    Color bubbleColor,
    Color borderColor,
    bool isEmailMessage,
    bool isPinned,
    bool isImportant,
  })
  viewData;
  final ({
    List<ReactionPreview> reactions,
    List<chat_models.Chat> replyParticipants,
    List<chat_models.Chat> recipientCutoutParticipants,
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
  interactionData;
  final ({
    Object bubbleContentKey,
    List<Widget> bubbleTextChildren,
    List<Widget> bubbleExtraChildren,
  })
  bubbleContentData;
  final void Function(Message message) onReplyRequested;
  final Future<void> Function(Message message) onForwardRequested;
  final Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onCopyRequested;
  final Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onShareRequested;
  final Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onAddToCalendarRequested;
  final void Function(String detailId) onDetailsRequested;
  final void Function(Message message) onStartMultiSelectRequested;
  final void Function(Message message, {required chat_models.Chat? chat})
  onResendRequested;
  final Future<void> Function(Message message) onEditRequested;
  final void Function(
    Message message, {
    required bool important,
    required chat_models.Chat? chat,
  })
  onImportantToggleRequested;
  final void Function(
    Message message, {
    required bool pin,
    required chat_models.Chat? chat,
    required RoomState? roomState,
  })
  onPinToggleRequested;
  final void Function(Message message, {String? inviteeJidFallback})
  onRevokeInviteRequested;
  final void Function(Message message, {required bool showUnreadIndicator})
  onBubbleTapRequested;
  final void Function(Message message) onToggleMultiSelectRequested;
  final void Function(Message message, String emoji)
  onToggleQuickReactionRequested;
  final Future<void> Function(Message message) onReactionSelectionRequested;
  final void Function(chat_models.Chat chat) onRecipientTap;
  final void Function(String messageId, Size size) onBubbleSizeChanged;

  @override
  Widget build(BuildContext context) {
    final (
      :detailId,
      self: self,
      :bubbleMaxWidth,
      :bubbleColor,
      :borderColor,
      isEmailMessage: isEmailMessage,
      isPinned: isPinned,
      isImportant: isImportant,
    ) = viewData;
    final (
      :reactions,
      replyParticipants: replyParticipants,
      recipientCutoutParticipants: recipientCutoutParticipants,
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
    ) = interactionData;
    final messageUser = ChatUser(
      id: timelineMessageItem.authorId,
      firstName: timelineMessageItem.authorDisplayName,
      profileImage: timelineMessageItem.authorAvatarPath,
    );
    final messageStatus = switch (timelineMessageItem.delivery) {
      ChatTimelineMessageDelivery.none => MessageStatus.none,
      ChatTimelineMessageDelivery.pending => MessageStatus.pending,
      ChatTimelineMessageDelivery.sent => MessageStatus.sent,
      ChatTimelineMessageDelivery.received => MessageStatus.received,
      ChatTimelineMessageDelivery.read => MessageStatus.read,
      ChatTimelineMessageDelivery.failed => MessageStatus.failed,
    };
    final (
      quotedPreview: replyPreview,
      forwardedPreview: forwardedPreview,
    ) = _resolveTimelineMessagePreviews(
      timelineMessageItem: timelineMessageItem,
      messageModel: messageModel,
      roomState: roomState,
      selfNick: selfNick,
      resolvedDirectChatDisplayName: resolvedDirectChatDisplayName,
      currentUserId: currentUserId,
      isGroupChat: isGroupChat,
      self: self,
      l10n: context.l10n,
    );
    final (
      actionBar: actionBar,
      reactionManager: reactionManager,
      onBubbleTap: onBubbleTap,
    ) = _resolveTimelineMessageChromeActions(
      context: context,
      timelineMessageItem: timelineMessageItem,
      messageModel: messageModel,
      chatEntity: chatEntity,
      roomState: roomState,
      shareRequestStatus: shareRequestStatus,
      readOnly: readOnly,
      self: self,
      multiSelectActive: multiSelectActive,
      canTogglePins: canTogglePins,
      canReact: canReact,
      requiresMucReference: requiresMucReference,
      loadingMucReference: loadingMucReference,
      isSingleSelection: isSingleSelection,
      isInviteMessage: isInviteMessage,
      isInviteRevocationMessage: isInviteRevocationMessage,
      inviteRevoked: inviteRevoked,
      isPinned: isPinned,
      isImportant: isImportant,
      messageStatus: messageStatus,
      detailId: detailId,
      reactions: reactions,
      onReplyRequested: onReplyRequested,
      onForwardRequested: onForwardRequested,
      onCopyRequested: onCopyRequested,
      onShareRequested: onShareRequested,
      onAddToCalendarRequested: onAddToCalendarRequested,
      onDetailsRequested: onDetailsRequested,
      onStartMultiSelectRequested: onStartMultiSelectRequested,
      onResendRequested: onResendRequested,
      onEditRequested: onEditRequested,
      onImportantToggleRequested: onImportantToggleRequested,
      onPinToggleRequested: onPinToggleRequested,
      onRevokeInviteRequested: onRevokeInviteRequested,
      onBubbleTapRequested: onBubbleTapRequested,
      onToggleQuickReactionRequested: onToggleQuickReactionRequested,
      onReactionSelectionRequested: onReactionSelectionRequested,
    );
    return _ChatTimelineMessageShellView(
      currentItem: currentItem,
      previous: previous,
      next: next,
      timelineMessageItem: timelineMessageItem,
      messageModel: messageModel,
      messageUser: messageUser,
      readOnly: readOnly,
      isGroupChat: isGroupChat,
      multiSelectActive: multiSelectActive,
      bubbleRegionRegistry: bubbleRegionRegistry,
      selectionTapRegionGroup: selectionTapRegionGroup,
      rowKey: rowKey,
      measuredBubbleWidth: measuredBubbleWidth,
      animate: animate,
      onTapOutside: onTapOutside,
      availableWidth: availableWidth,
      inboundClampedBubbleWidth: inboundClampedBubbleWidth,
      outboundClampedBubbleWidth: outboundClampedBubbleWidth,
      messageRowMaxWidth: messageRowMaxWidth,
      selectionExtrasPreferredMaxWidth: selectionExtrasPreferredMaxWidth,
      viewData: viewData,
      interactionData: interactionData,
      bubbleContentData: bubbleContentData,
      quotedPreview: replyPreview,
      forwardedPreview: forwardedPreview,
      actionBar: actionBar,
      reactionManager: reactionManager,
      onToggleMultiSelectRequested: onToggleMultiSelectRequested,
      onToggleQuickReactionRequested: onToggleQuickReactionRequested,
      onRecipientTap: onRecipientTap,
      onBubbleTap: onBubbleTap,
      onBubbleSizeChanged: onBubbleSizeChanged,
    );
  }
}

({
  Widget? recipientOverlay,
  CutoutStyle? recipientStyle,
  ChatBubbleCutoutAnchor recipientAnchor,
  Widget? selectionOverlay,
  CutoutStyle? selectionStyle,
  Widget? reactionOverlay,
  CutoutStyle? reactionStyle,
  double reactionBubbleInset,
  double reactionCutoutDepth,
  double reactionCutoutMinThickness,
  EdgeInsets reactionCutoutPadding,
  double reactionCornerClearance,
  double recipientBubbleInset,
  double recipientCutoutDepth,
  double recipientCutoutMinThickness,
  bool selectionOverlayVisible,
  double selectionOuterInset,
  double selectionBubbleVerticalInset,
  double selectionBubbleInboundSpacing,
  double selectionBubbleOutboundSpacing,
  bool hasAvatarSlot,
  double avatarOuterInset,
  double avatarContentInset,
  Widget? avatarOverlay,
  CutoutStyle? avatarStyle,
  ChatBubbleCutoutAnchor avatarAnchor,
})
_resolveTimelineMessageCutoutData({
  required BuildContext context,
  required ChatTimelineMessageItem timelineMessageItem,
  required Message messageModel,
  required bool self,
  required bool isSelected,
  required bool isSingleSelection,
  required bool isEmailMessage,
  required bool isGroupChat,
  required bool multiSelectActive,
  required bool canReact,
  required bool showCompactReactions,
  required bool showReplyStrip,
  required bool showRecipientCutout,
  required List<ReactionPreview> reactions,
  required List<chat_models.Chat> replyParticipants,
  required List<chat_models.Chat> recipientCutoutParticipants,
  required void Function(Message message) onToggleMultiSelectRequested,
  required void Function(Message message, String emoji)
  onToggleQuickReactionRequested,
  required void Function(chat_models.Chat chat) onRecipientTap,
}) {
  final spacing = context.spacing;
  final messageAvatarSize = spacing.l;
  final avatarCutoutDepth = messageAvatarSize / 2;
  final avatarCutoutRadius = avatarCutoutDepth + spacing.xs;
  final avatarOuterInset = avatarCutoutDepth;
  final avatarContentInset = avatarCutoutDepth - spacing.xs;
  final avatarMinThickness = messageAvatarSize;
  final avatarCutoutAlignment = Alignment.centerLeft.x;
  final messageAvatarCornerClearance = 0.0;
  const messageAvatarCutoutPadding = EdgeInsets.zero;
  final reactionBubbleInset = spacing.m;
  final reactionCutoutDepth = spacing.m;
  final reactionCutoutRadius = spacing.m;
  final reactionCutoutMinThickness = spacing.l;
  final reactionStripOffset = Offset(0, -spacing.xxs);
  final reactionCutoutPadding = EdgeInsets.symmetric(
    horizontal: spacing.xs,
    vertical: spacing.xxs,
  );
  final reactionCornerClearance = spacing.s;
  final recipientCutoutDepth = spacing.m;
  final recipientCutoutRadius = spacing.m;
  final recipientCutoutPadding = EdgeInsets.fromLTRB(
    spacing.s,
    spacing.xs,
    spacing.s,
    spacing.s,
  );
  final recipientCutoutMinThickness = spacing.xl;
  final recipientBubbleInset = recipientCutoutDepth;
  final selectionCutoutDepth = spacing.m;
  final selectionCutoutRadius = spacing.m;
  final selectionCutoutPadding = EdgeInsets.fromLTRB(
    spacing.xs,
    spacing.s,
    spacing.xs,
    spacing.s,
  );
  final selectionCutoutOffset = Offset(-(spacing.xs), 0);
  final selectionCutoutThickness = SelectionIndicator.size + spacing.s;
  final selectionBubbleInteriorInset = selectionCutoutDepth + spacing.s;
  final selectionBubbleVerticalInset = spacing.xs;
  final selectionOuterInset =
      selectionCutoutDepth + (SelectionIndicator.size / 2);
  final selectionIndicatorInset = spacing.xxs;
  final selectionBubbleInboundExtraGap = spacing.xs;
  final selectionBubbleOutboundExtraGap = spacing.s;
  final selectionBubbleOutboundSpacingBoost = spacing.s;
  final selectionBubbleInboundSpacing =
      selectionBubbleInteriorInset + selectionBubbleInboundExtraGap;
  final selectionBubbleOutboundSpacing =
      selectionBubbleInteriorInset +
      selectionBubbleOutboundExtraGap +
      selectionBubbleOutboundSpacingBoost;
  final requiresAvatarHeadroom = isGroupChat && !isEmailMessage && !self;
  final hasAvatarSlot = requiresAvatarHeadroom;
  Widget? recipientOverlay;
  CutoutStyle? recipientStyle;
  var recipientAnchor = ChatBubbleCutoutAnchor.bottom;
  if (showRecipientCutout) {
    recipientOverlay = _RecipientCutoutStrip(
      recipients: recipientCutoutParticipants,
    );
    recipientStyle = CutoutStyle(
      depth: recipientCutoutDepth,
      cornerRadius: recipientCutoutRadius,
      padding: recipientCutoutPadding,
      offset: Offset.zero,
      minThickness: recipientCutoutMinThickness,
    );
  }
  Widget? selectionOverlay;
  CutoutStyle? selectionStyle;
  if (multiSelectActive) {
    selectionOverlay = Padding(
      padding: EdgeInsets.only(left: selectionIndicatorInset),
      child: SelectionIndicator(
        visible: true,
        selected: isSingleSelection,
        onPressed: () => onToggleMultiSelectRequested(messageModel),
      ),
    );
    selectionStyle = CutoutStyle(
      depth: selectionCutoutDepth,
      cornerRadius: selectionCutoutRadius,
      padding: selectionCutoutPadding,
      offset: selectionCutoutOffset,
      minThickness: selectionCutoutThickness,
      cornerClearance: 0.0,
    );
  }
  final reactionOverlay = showReplyStrip
      ? _ReplyStrip(
          participants: replyParticipants,
          onRecipientTap: onRecipientTap,
        )
      : showCompactReactions
      ? _ReactionStrip(
          reactions: reactions,
          onReactionTap: canReact
              ? (emoji) => onToggleQuickReactionRequested(messageModel, emoji)
              : null,
        )
      : null;
  final reactionStyle = showReplyStrip
      ? CutoutStyle(
          depth: recipientCutoutDepth,
          cornerRadius: recipientCutoutRadius,
          padding: recipientCutoutPadding,
          offset: Offset.zero,
          minThickness: recipientCutoutMinThickness,
        )
      : showCompactReactions
      ? CutoutStyle(
          depth: reactionCutoutDepth,
          cornerRadius: reactionCutoutRadius,
          shapeCornerRadius: context.radii.squircle,
          padding: reactionCutoutPadding,
          offset: reactionStripOffset,
          minThickness: reactionCutoutMinThickness,
        )
      : null;
  final (
    avatarOverlay: avatarOverlay,
    avatarStyle: avatarStyle,
    avatarAnchor: avatarAnchor,
  ) = resolveTimelineMessageAvatarCutout(
    context: context,
    requiresAvatarHeadroom: requiresAvatarHeadroom,
    timelineMessageItem: timelineMessageItem,
    messageAvatarSize: messageAvatarSize,
    avatarCutoutDepth: avatarCutoutDepth,
    avatarCutoutRadius: avatarCutoutRadius,
    avatarMinThickness: avatarMinThickness,
    messageAvatarCornerClearance: messageAvatarCornerClearance,
    messageAvatarCutoutPadding: messageAvatarCutoutPadding,
    avatarCutoutAlignment: avatarCutoutAlignment,
  );
  return (
    recipientOverlay: recipientOverlay,
    recipientStyle: recipientStyle,
    recipientAnchor: recipientAnchor,
    selectionOverlay: selectionOverlay,
    selectionStyle: selectionStyle,
    reactionOverlay: reactionOverlay,
    reactionStyle: reactionStyle,
    reactionBubbleInset: reactionBubbleInset,
    reactionCutoutDepth: reactionCutoutDepth,
    reactionCutoutMinThickness: reactionCutoutMinThickness,
    reactionCutoutPadding: reactionCutoutPadding,
    reactionCornerClearance: reactionCornerClearance,
    recipientBubbleInset: recipientBubbleInset,
    recipientCutoutDepth: recipientCutoutDepth,
    recipientCutoutMinThickness: recipientCutoutMinThickness,
    selectionOverlayVisible: selectionOverlay != null,
    selectionOuterInset: selectionOuterInset,
    selectionBubbleVerticalInset: selectionBubbleVerticalInset,
    selectionBubbleInboundSpacing: selectionBubbleInboundSpacing,
    selectionBubbleOutboundSpacing: selectionBubbleOutboundSpacing,
    hasAvatarSlot: hasAvatarSlot,
    avatarOuterInset: avatarOuterInset,
    avatarContentInset: avatarContentInset,
    avatarOverlay: avatarOverlay,
    avatarStyle: avatarStyle,
    avatarAnchor: avatarAnchor,
  );
}

({
  EdgeInsetsGeometry bubblePadding,
  BorderRadius bubbleBorderRadius,
  double bubbleMaxWidthForLayout,
  BoxConstraints bubbleTextConstraints,
  BoxConstraints bubbleExtraConstraints,
  EdgeInsets outerPadding,
  double bubbleBottomCutoutPadding,
  List<BoxShadow> bubbleShadows,
  double combinedReactionCornerClearance,
})
_resolveTimelineMessageBubbleLayout({
  required BuildContext context,
  required ChatTimelineItem currentItem,
  required ChatTimelineItem? previous,
  required ChatTimelineItem? next,
  required bool self,
  required bool isSelected,
  required bool isSingleSelection,
  required bool showCompactReactions,
  required bool showReplyStrip,
  required bool showRecipientCutout,
  required bool hasAvatarSlot,
  required double avatarOuterInset,
  required double avatarContentInset,
  required double bubbleMaxWidth,
  required double inboundClampedBubbleWidth,
  required double outboundClampedBubbleWidth,
  required double messageRowMaxWidth,
  required List<Widget> bubbleTextChildren,
  required List<Widget> bubbleExtraChildren,
  required List<ReactionPreview> reactions,
  required bool selectionOverlayVisible,
  required double selectionOuterInset,
  required double selectionBubbleVerticalInset,
  required double selectionBubbleInboundSpacing,
  required double selectionBubbleOutboundSpacing,
  required double reactionBubbleInset,
  required double reactionCutoutDepth,
  required double reactionCutoutMinThickness,
  required EdgeInsets reactionCutoutPadding,
  required double reactionCornerClearance,
  required double recipientBubbleInset,
  required double recipientCutoutDepth,
}) {
  final spacing = context.spacing;
  final bubbleBaseRadius = _bubbleBaseRadius(context);
  final bubbleCornerClearance = _bubbleCornerClearance(bubbleBaseRadius);
  EdgeInsetsGeometry bubblePadding = _bubblePadding(context);
  var bubbleBottomInset = 0.0;
  if (showCompactReactions) {
    bubbleBottomInset = reactionBubbleInset;
  }
  if (showReplyStrip || showRecipientCutout) {
    bubbleBottomInset = math.max(bubbleBottomInset, recipientBubbleInset);
  }
  if (bubbleBottomInset > 0) {
    bubblePadding = bubblePadding.add(
      EdgeInsets.only(bottom: bubbleBottomInset),
    );
  }
  if (selectionOverlayVisible) {
    bubblePadding = bubblePadding.add(
      EdgeInsets.only(
        left: self ? selectionBubbleOutboundSpacing : 0,
        right: self ? 0 : selectionBubbleInboundSpacing,
      ),
    );
    bubblePadding = bubblePadding.add(
      EdgeInsets.symmetric(vertical: selectionBubbleVerticalInset),
    );
  }
  if (hasAvatarSlot) {
    bubblePadding = bubblePadding.add(
      EdgeInsets.only(left: avatarContentInset + spacing.xxs),
    );
  }
  final hasBubbleExtras = bubbleExtraChildren.any(
    (child) => child is _MessageExtraItem,
  );
  final chainedPrev = _chatTimelineItemsShouldChain(currentItem, previous);
  final chainedNext = _chatTimelineItemsShouldChain(currentItem, next);
  final bubbleBorderRadius = _bubbleBorderRadius(
    baseRadius: bubbleBaseRadius,
    isSelf: self,
    chainedPrevious: chainedPrev,
    chainedNext: chainedNext,
    isSelected: isSelected,
    flattenBottom: hasBubbleExtras,
  );
  final selectionAllowance = selectionOverlayVisible
      ? selectionOuterInset
      : 0.0;
  final cappedBubbleWidth = math.min(
    bubbleMaxWidth,
    (self ? outboundClampedBubbleWidth : inboundClampedBubbleWidth) +
        selectionAllowance,
  );
  final expandedBubbleWidth = math.max(
    cappedBubbleWidth,
    math.max(0.0, messageRowMaxWidth - selectionAllowance),
  );
  final bubbleMaxWidthForLayout = isSingleSelection
      ? expandedBubbleWidth
      : cappedBubbleWidth;
  final combinedReactionCornerClearance =
      bubbleCornerClearance + reactionCornerClearance;
  final compactReactionMinimumBubbleWidth = showCompactReactions
      ? math.min(
          bubbleMaxWidthForLayout,
          minimumReactionCutoutBubbleWidth(
            context: context,
            reactions: reactions,
            padding: reactionCutoutPadding,
            minThickness: reactionCutoutMinThickness,
            cornerClearance: combinedReactionCornerClearance,
          ),
        )
      : 0.0;
  final bubbleTextConstraints = BoxConstraints(
    minWidth: compactReactionMinimumBubbleWidth,
    maxWidth: bubbleMaxWidthForLayout,
  );
  final bubbleExtraConstraints = BoxConstraints(maxWidth: cappedBubbleWidth);
  final nextIsTailSpacer = next is ChatTimelineTailSpacerItem;
  final isLatestBubble = next == null || nextIsTailSpacer;
  final baseOuterBottom = isLatestBubble ? spacing.m : spacing.xxs;
  var extraOuterBottom = 0.0;
  if (showCompactReactions) {
    extraOuterBottom = math.max(extraOuterBottom, reactionCutoutDepth);
  }
  if (showReplyStrip || showRecipientCutout) {
    extraOuterBottom = math.max(extraOuterBottom, recipientCutoutDepth);
  }
  final extraOuterLeft = hasAvatarSlot ? avatarOuterInset : 0.0;
  final outerPadding = EdgeInsets.only(
    top: spacing.xxs,
    bottom: baseOuterBottom + extraOuterBottom,
    left: spacing.s + extraOuterLeft,
    right: spacing.s,
  );
  final reactionBottomInset = showCompactReactions ? reactionCutoutDepth : 0.0;
  final recipientBottomInset = (showReplyStrip || showRecipientCutout)
      ? recipientCutoutDepth
      : 0.0;
  final bubbleBottomCutoutPadding = math.max(
    reactionBottomInset,
    recipientBottomInset,
  );
  final bubbleShadows = _selectedBubbleShadows(context.colorScheme.primary);
  return (
    bubblePadding: bubblePadding,
    bubbleBorderRadius: bubbleBorderRadius,
    bubbleMaxWidthForLayout: bubbleMaxWidthForLayout,
    bubbleTextConstraints: bubbleTextConstraints,
    bubbleExtraConstraints: bubbleExtraConstraints,
    outerPadding: outerPadding,
    bubbleBottomCutoutPadding: bubbleBottomCutoutPadding,
    bubbleShadows: bubbleShadows,
    combinedReactionCornerClearance: combinedReactionCornerClearance,
  );
}

({
  Widget bubbleContent,
  bool showBubbleSurface,
  Color bubbleSurfaceColor,
  Color bubbleSurfaceBorder,
})
_resolveTimelineMessageBubbleContent({
  required BuildContext context,
  required List<Widget> bubbleTextChildren,
  required EdgeInsetsGeometry bubblePadding,
  required BoxConstraints bubbleTextConstraints,
  required bool showCompactReactions,
  required bool showReplyStrip,
  required bool showRecipientCutout,
  required double reactionCutoutDepth,
  required double recipientCutoutDepth,
  required Color bubbleColor,
  required Color borderColor,
}) {
  final spacing = context.spacing;
  final hasBubbleText = bubbleTextChildren.isNotEmpty;
  final hasBubbleCutout =
      showCompactReactions || showReplyStrip || showRecipientCutout;
  final bubbleAnchorHeight = hasBubbleText || !hasBubbleCutout
      ? 0.0
      : math.max(
          showCompactReactions ? reactionCutoutDepth : 0.0,
          (showReplyStrip || showRecipientCutout) ? recipientCutoutDepth : 0.0,
        );
  final showBubbleSurface = hasBubbleText;
  final bubbleSurfaceColor = showBubbleSurface
      ? bubbleColor
      : Colors.transparent;
  final bubbleSurfaceBorder = showBubbleSurface
      ? borderColor
      : Colors.transparent;
  final bubbleContent = hasBubbleText
      ? Padding(
          padding: bubblePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: spacing.xs,
            children: bubbleTextChildren,
          ),
        )
      : bubbleAnchorHeight > 0
      ? SizedBox(
          width: bubbleTextConstraints.maxWidth,
          height: bubbleAnchorHeight,
        )
      : const SizedBox.shrink();
  return (
    bubbleContent: bubbleContent,
    showBubbleSurface: showBubbleSurface,
    bubbleSurfaceColor: bubbleSurfaceColor,
    bubbleSurfaceBorder: bubbleSurfaceBorder,
  );
}

({
  Widget bubble,
  EdgeInsets outerPadding,
  double bubbleMaxWidthForLayout,
  double bubbleBottomCutoutPadding,
  BoxConstraints bubbleExtraConstraints,
  List<BoxShadow> bubbleShadows,
  bool hasAvatarSlot,
  double avatarContentInset,
})
_resolveTimelineMessageShellData({
  required BuildContext context,
  required ChatTimelineItem currentItem,
  required ChatTimelineItem? previous,
  required ChatTimelineItem? next,
  required ChatTimelineMessageItem timelineMessageItem,
  required Message messageModel,
  required ({
    String detailId,
    bool self,
    double bubbleMaxWidth,
    Color bubbleColor,
    Color borderColor,
    bool isEmailMessage,
    bool isPinned,
    bool isImportant,
  })
  viewData,
  required ({
    List<ReactionPreview> reactions,
    List<chat_models.Chat> replyParticipants,
    List<chat_models.Chat> recipientCutoutParticipants,
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
  interactionData,
  required bool isGroupChat,
  required bool multiSelectActive,
  required double inboundClampedBubbleWidth,
  required double outboundClampedBubbleWidth,
  required double messageRowMaxWidth,
  required ({
    Object bubbleContentKey,
    List<Widget> bubbleTextChildren,
    List<Widget> bubbleExtraChildren,
  })
  bubbleContentData,
  required void Function(Message message) onToggleMultiSelectRequested,
  required void Function(Message message, String emoji)
  onToggleQuickReactionRequested,
  required void Function(chat_models.Chat chat) onRecipientTap,
}) {
  final self = viewData.self;
  final cutoutData = _resolveTimelineMessageCutoutData(
    context: context,
    timelineMessageItem: timelineMessageItem,
    messageModel: messageModel,
    self: self,
    isSelected: interactionData.isSelected,
    isSingleSelection: interactionData.isSingleSelection,
    isEmailMessage: viewData.isEmailMessage,
    isGroupChat: isGroupChat,
    multiSelectActive: multiSelectActive,
    canReact: interactionData.canReact,
    showCompactReactions: interactionData.showCompactReactions,
    showReplyStrip: interactionData.showReplyStrip,
    showRecipientCutout: interactionData.showRecipientCutout,
    reactions: interactionData.reactions,
    replyParticipants: interactionData.replyParticipants,
    recipientCutoutParticipants: interactionData.recipientCutoutParticipants,
    onToggleMultiSelectRequested: onToggleMultiSelectRequested,
    onToggleQuickReactionRequested: onToggleQuickReactionRequested,
    onRecipientTap: onRecipientTap,
  );
  final hasAvatarSlot =
      cutoutData.hasAvatarSlot &&
      !_chatTimelineItemsShouldChain(currentItem, previous);
  final (
    bubblePadding: bubblePadding,
    bubbleBorderRadius: bubbleBorderRadius,
    bubbleMaxWidthForLayout: bubbleMaxWidthForLayout,
    bubbleTextConstraints: bubbleTextConstraints,
    bubbleExtraConstraints: bubbleExtraConstraints,
    outerPadding: outerPadding,
    bubbleBottomCutoutPadding: bubbleBottomCutoutPadding,
    bubbleShadows: bubbleShadows,
    combinedReactionCornerClearance: combinedReactionCornerClearance,
  ) = _resolveTimelineMessageBubbleLayout(
    context: context,
    currentItem: currentItem,
    previous: previous,
    next: next,
    self: self,
    isSelected: interactionData.isSelected,
    isSingleSelection: interactionData.isSingleSelection,
    showCompactReactions: interactionData.showCompactReactions,
    showReplyStrip: interactionData.showReplyStrip,
    showRecipientCutout: interactionData.showRecipientCutout,
    hasAvatarSlot: hasAvatarSlot,
    avatarOuterInset: cutoutData.avatarOuterInset,
    avatarContentInset: cutoutData.avatarContentInset,
    bubbleMaxWidth: viewData.bubbleMaxWidth,
    inboundClampedBubbleWidth: inboundClampedBubbleWidth,
    outboundClampedBubbleWidth: outboundClampedBubbleWidth,
    messageRowMaxWidth: messageRowMaxWidth,
    bubbleTextChildren: bubbleContentData.bubbleTextChildren,
    bubbleExtraChildren: bubbleContentData.bubbleExtraChildren,
    reactions: interactionData.reactions,
    selectionOverlayVisible: cutoutData.selectionOverlayVisible,
    selectionOuterInset: cutoutData.selectionOuterInset,
    selectionBubbleVerticalInset: cutoutData.selectionBubbleVerticalInset,
    selectionBubbleInboundSpacing: cutoutData.selectionBubbleInboundSpacing,
    selectionBubbleOutboundSpacing: cutoutData.selectionBubbleOutboundSpacing,
    reactionBubbleInset: cutoutData.reactionBubbleInset,
    reactionCutoutDepth: cutoutData.reactionCutoutDepth,
    reactionCutoutMinThickness: cutoutData.reactionCutoutMinThickness,
    reactionCutoutPadding: cutoutData.reactionCutoutPadding,
    reactionCornerClearance: cutoutData.reactionCornerClearance,
    recipientBubbleInset: cutoutData.recipientBubbleInset,
    recipientCutoutDepth: cutoutData.recipientCutoutDepth,
  );
  final (
    bubbleContent: bubbleContent,
    showBubbleSurface: showBubbleSurface,
    bubbleSurfaceColor: bubbleSurfaceColor,
    bubbleSurfaceBorder: bubbleSurfaceBorder,
  ) = _resolveTimelineMessageBubbleContent(
    context: context,
    bubbleTextChildren: bubbleContentData.bubbleTextChildren,
    bubblePadding: bubblePadding,
    bubbleTextConstraints: bubbleTextConstraints,
    showCompactReactions: interactionData.showCompactReactions,
    showReplyStrip: interactionData.showReplyStrip,
    showRecipientCutout: interactionData.showRecipientCutout,
    reactionCutoutDepth: cutoutData.reactionCutoutDepth,
    recipientCutoutDepth: cutoutData.recipientCutoutDepth,
    bubbleColor: viewData.bubbleColor,
    borderColor: viewData.borderColor,
  );
  final bubble = _ChatTimelineBubbleView(
    self: self,
    isSelected: interactionData.isSelected,
    showBubbleSurface: showBubbleSurface,
    bubbleSurfaceColor: bubbleSurfaceColor,
    bubbleSurfaceBorder: bubbleSurfaceBorder,
    bubbleBorderRadius: bubbleBorderRadius,
    bubbleShadows: bubbleShadows,
    cornerClearance: combinedReactionCornerClearance,
    body: bubbleContent,
    textConstraints: bubbleTextConstraints,
    reactionOverlay: cutoutData.reactionOverlay,
    reactionStyle: cutoutData.reactionStyle,
    recipientOverlay: cutoutData.recipientOverlay,
    recipientStyle: cutoutData.recipientStyle,
    recipientAnchor: cutoutData.recipientAnchor,
    avatarOverlay: cutoutData.avatarOverlay,
    avatarStyle: cutoutData.avatarStyle,
    avatarAnchor: cutoutData.avatarAnchor,
    selectionOverlay: cutoutData.selectionOverlay,
    selectionStyle: cutoutData.selectionStyle,
  );
  return (
    bubble: bubble,
    outerPadding: outerPadding,
    bubbleMaxWidthForLayout: bubbleMaxWidthForLayout,
    bubbleBottomCutoutPadding: bubbleBottomCutoutPadding,
    bubbleExtraConstraints: bubbleExtraConstraints,
    bubbleShadows: bubbleShadows,
    hasAvatarSlot: hasAvatarSlot,
    avatarContentInset: cutoutData.avatarContentInset,
  );
}

({Widget? quotedPreview, Widget? forwardedPreview})
_resolveTimelineMessagePreviews({
  required ChatTimelineMessageItem timelineMessageItem,
  required Message messageModel,
  required RoomState? roomState,
  required String? selfNick,
  required String? resolvedDirectChatDisplayName,
  required String? currentUserId,
  required bool isGroupChat,
  required bool self,
  required AppLocalizations l10n,
}) {
  final quotedPreview = _timelineQuotedPreview(
    quotedMessage: timelineMessageItem.quotedMessage,
    isGroupChat: isGroupChat,
    roomState: roomState,
    fallbackSelfNick: selfNick,
    currentUserId: currentUserId,
    chatDisplayName: resolvedDirectChatDisplayName,
    l10n: l10n,
    isSelfBubble: self,
  );
  final forwardedPreview = _timelineForwardedPreview(
    isForwarded: timelineMessageItem.isForwarded,
    forwardedFromJid: timelineMessageItem.forwardedFromJid,
    forwardedSubjectSenderLabel:
        timelineMessageItem.forwardedSubjectSenderLabel,
    fallbackSenderJid: messageModel.senderJid,
    fallbackIsSelf: self,
    isGroupChat: isGroupChat,
    roomState: roomState,
    currentUserId: currentUserId,
    l10n: l10n,
    isSelfBubble: self,
  );
  return (quotedPreview: quotedPreview, forwardedPreview: forwardedPreview);
}

({
  VoidCallback? onReply,
  VoidCallback? onForward,
  VoidCallback onCopy,
  VoidCallback onShare,
  VoidCallback onAddToCalendar,
  VoidCallback onDetails,
  VoidCallback? onSelect,
  VoidCallback? onResend,
  VoidCallback? onEdit,
  VoidCallback? onPinToggle,
  VoidCallback? onImportantToggle,
  VoidCallback? onRevokeInvite,
  VoidCallback? onBubbleTap,
  VoidCallback onAddReaction,
  void Function(String emoji) onToggleReaction,
  bool canShowReactionManager,
  bool reactionManagerDisabled,
  bool importantDisabled,
  bool pinDisabled,
  bool pinLoading,
  bool replyLoading,
})
_resolveTimelineMessageActionCallbacks({
  required ChatTimelineMessageItem timelineMessageItem,
  required Message messageModel,
  required chat_models.Chat? chatEntity,
  required RoomState? roomState,
  required bool readOnly,
  required bool self,
  required bool multiSelectActive,
  required bool canTogglePins,
  required bool canReact,
  required bool requiresMucReference,
  required bool loadingMucReference,
  required bool isSingleSelection,
  required bool isInviteMessage,
  required bool isInviteRevocationMessage,
  required bool inviteRevoked,
  required bool isPinned,
  required bool isImportant,
  required MessageStatus messageStatus,
  required String detailId,
  required void Function(Message message) onReplyRequested,
  required Future<void> Function(Message message) onForwardRequested,
  required Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onCopyRequested,
  required Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onShareRequested,
  required Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onAddToCalendarRequested,
  required void Function(String detailId) onDetailsRequested,
  required void Function(Message message) onStartMultiSelectRequested,
  required void Function(Message message, {required chat_models.Chat? chat})
  onResendRequested,
  required Future<void> Function(Message message) onEditRequested,
  required void Function(
    Message message, {
    required bool important,
    required chat_models.Chat? chat,
  })
  onImportantToggleRequested,
  required void Function(
    Message message, {
    required bool pin,
    required chat_models.Chat? chat,
    required RoomState? roomState,
  })
  onPinToggleRequested,
  required void Function(Message message, {String? inviteeJidFallback})
  onRevokeInviteRequested,
  required void Function(Message message, {required bool showUnreadIndicator})
  onBubbleTapRequested,
  required void Function(Message message, String emoji)
  onToggleQuickReactionRequested,
  required Future<void> Function(Message message) onReactionSelectionRequested,
}) {
  final includeSelectAction = !multiSelectActive;
  final canRetry = messageStatus == MessageStatus.failed;
  final canShowReactionManager = canReact && isSingleSelection;
  final reactionManagerDisabled =
      canShowReactionManager && requiresMucReference;
  final pinDisabled = requiresMucReference && canTogglePins;
  final pinLoading = loadingMucReference && canTogglePins;
  final rowText = timelineMessageItem.rowText;

  VoidCallback? onReply;
  if (!requiresMucReference) {
    onReply = () => onReplyRequested(messageModel);
  }

  VoidCallback? onForward;
  if (!(isInviteMessage || inviteRevoked || isInviteRevocationMessage)) {
    onForward = () => unawaited(onForwardRequested(messageModel));
  }

  void onCopy() =>
      unawaited(onCopyRequested(fallbackText: rowText, model: messageModel));

  void onShare() =>
      unawaited(onShareRequested(fallbackText: rowText, model: messageModel));

  void onAddToCalendar() => unawaited(
    onAddToCalendarRequested(fallbackText: rowText, model: messageModel),
  );

  void onDetails() => onDetailsRequested(detailId);

  VoidCallback? onSelect;
  if (includeSelectAction) {
    onSelect = () => onStartMultiSelectRequested(messageModel);
  }

  VoidCallback? onResend;
  VoidCallback? onEdit;
  if (canRetry) {
    onResend = () => onResendRequested(messageModel, chat: chatEntity);
    onEdit = () => unawaited(onEditRequested(messageModel));
  }

  VoidCallback? onPinToggle;
  if (canTogglePins && !requiresMucReference) {
    onPinToggle = () => onPinToggleRequested(
      messageModel,
      pin: !isPinned,
      chat: chatEntity,
      roomState: roomState,
    );
  }

  VoidCallback? onImportantToggle;
  if (!requiresMucReference) {
    onImportantToggle = () => onImportantToggleRequested(
      messageModel,
      important: !isImportant,
      chat: chatEntity,
    );
  }

  VoidCallback? onRevokeInvite;
  if (isInviteMessage && self) {
    onRevokeInvite = () => onRevokeInviteRequested(
      messageModel,
      inviteeJidFallback: chatEntity?.jid,
    );
  }

  VoidCallback? onBubbleTap;
  if (!readOnly) {
    onBubbleTap = () => onBubbleTapRequested(
      messageModel,
      showUnreadIndicator: timelineMessageItem.showUnreadIndicator,
    );
  }

  void onAddReaction() => unawaited(onReactionSelectionRequested(messageModel));
  void onToggleReaction(String emoji) =>
      onToggleQuickReactionRequested(messageModel, emoji);

  return (
    onReply: onReply,
    onForward: onForward,
    onCopy: onCopy,
    onShare: onShare,
    onAddToCalendar: onAddToCalendar,
    onDetails: onDetails,
    onSelect: onSelect,
    onResend: onResend,
    onEdit: onEdit,
    onPinToggle: onPinToggle,
    onImportantToggle: onImportantToggle,
    onRevokeInvite: onRevokeInvite,
    onBubbleTap: onBubbleTap,
    onAddReaction: onAddReaction,
    onToggleReaction: onToggleReaction,
    canShowReactionManager: canShowReactionManager,
    reactionManagerDisabled: reactionManagerDisabled,
    importantDisabled: requiresMucReference,
    pinDisabled: pinDisabled,
    pinLoading: pinLoading,
    replyLoading: loadingMucReference,
  );
}

({Widget actionBar, Widget? reactionManager, VoidCallback? onBubbleTap})
_resolveTimelineMessageChromeActions({
  required BuildContext context,
  required ChatTimelineMessageItem timelineMessageItem,
  required Message messageModel,
  required chat_models.Chat? chatEntity,
  required RoomState? roomState,
  required RequestStatus shareRequestStatus,
  required bool readOnly,
  required bool self,
  required bool multiSelectActive,
  required bool canTogglePins,
  required bool canReact,
  required bool requiresMucReference,
  required bool loadingMucReference,
  required bool isSingleSelection,
  required bool isInviteMessage,
  required bool isInviteRevocationMessage,
  required bool inviteRevoked,
  required bool isPinned,
  required bool isImportant,
  required MessageStatus messageStatus,
  required String detailId,
  required List<ReactionPreview> reactions,
  required void Function(Message message) onReplyRequested,
  required Future<void> Function(Message message) onForwardRequested,
  required Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onCopyRequested,
  required Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onShareRequested,
  required Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onAddToCalendarRequested,
  required void Function(String detailId) onDetailsRequested,
  required void Function(Message message) onStartMultiSelectRequested,
  required void Function(Message message, {required chat_models.Chat? chat})
  onResendRequested,
  required Future<void> Function(Message message) onEditRequested,
  required void Function(
    Message message, {
    required bool important,
    required chat_models.Chat? chat,
  })
  onImportantToggleRequested,
  required void Function(
    Message message, {
    required bool pin,
    required chat_models.Chat? chat,
    required RoomState? roomState,
  })
  onPinToggleRequested,
  required void Function(Message message, {String? inviteeJidFallback})
  onRevokeInviteRequested,
  required void Function(Message message, {required bool showUnreadIndicator})
  onBubbleTapRequested,
  required void Function(Message message, String emoji)
  onToggleQuickReactionRequested,
  required Future<void> Function(Message message) onReactionSelectionRequested,
}) {
  final l10n = context.l10n;
  final callbacks = _resolveTimelineMessageActionCallbacks(
    timelineMessageItem: timelineMessageItem,
    messageModel: messageModel,
    chatEntity: chatEntity,
    roomState: roomState,
    readOnly: readOnly,
    self: self,
    multiSelectActive: multiSelectActive,
    canTogglePins: canTogglePins,
    canReact: canReact,
    requiresMucReference: requiresMucReference,
    loadingMucReference: loadingMucReference,
    isSingleSelection: isSingleSelection,
    isInviteMessage: isInviteMessage,
    isInviteRevocationMessage: isInviteRevocationMessage,
    inviteRevoked: inviteRevoked,
    isPinned: isPinned,
    isImportant: isImportant,
    messageStatus: messageStatus,
    detailId: detailId,
    onReplyRequested: onReplyRequested,
    onForwardRequested: onForwardRequested,
    onCopyRequested: onCopyRequested,
    onShareRequested: onShareRequested,
    onAddToCalendarRequested: onAddToCalendarRequested,
    onDetailsRequested: onDetailsRequested,
    onStartMultiSelectRequested: onStartMultiSelectRequested,
    onResendRequested: onResendRequested,
    onEditRequested: onEditRequested,
    onImportantToggleRequested: onImportantToggleRequested,
    onPinToggleRequested: onPinToggleRequested,
    onRevokeInviteRequested: onRevokeInviteRequested,
    onBubbleTapRequested: onBubbleTapRequested,
    onToggleQuickReactionRequested: onToggleQuickReactionRequested,
    onReactionSelectionRequested: onReactionSelectionRequested,
  );
  final actionBar = _MessageActionBar(
    onReply: callbacks.onReply,
    onForward: callbacks.onForward,
    onCopy: callbacks.onCopy,
    onShare: callbacks.onShare,
    shareStatus: shareRequestStatus,
    onAddToCalendar: callbacks.onAddToCalendar,
    onDetails: callbacks.onDetails,
    replyLoading: callbacks.replyLoading,
    onSelect: callbacks.onSelect,
    onResend: callbacks.onResend,
    onEdit: callbacks.onEdit,
    importantDisabled: callbacks.importantDisabled,
    onImportantToggle: callbacks.onImportantToggle,
    isImportant: isImportant,
    pinDisabled: callbacks.pinDisabled,
    pinLoading: callbacks.pinLoading,
    onPinToggle: callbacks.onPinToggle,
    isPinned: isPinned,
    onRevokeInvite: callbacks.onRevokeInvite,
  );
  final reactionManager = callbacks.canShowReactionManager
      ? _ReactionManager(
          reactions: reactions,
          disabled: callbacks.reactionManagerDisabled,
          disabledLoading: loadingMucReference,
          onToggle: callbacks.onToggleReaction,
          onAddCustom: callbacks.onAddReaction,
          disabledMessage: loadingMucReference
              ? l10n.chatMucReferencePending
              : l10n.chatMucReferenceUnavailable,
        )
      : null;
  return (
    actionBar: actionBar,
    reactionManager: reactionManager,
    onBubbleTap: callbacks.onBubbleTap,
  );
}

({Widget attachmentsAligned, Widget extrasAligned, Widget? senderLabel})
_resolveTimelineMessageRowDecorations({
  required BuildContext context,
  required ChatTimelineItem currentItem,
  required ChatTimelineItem? previous,
  required ChatUser messageUser,
  required bool self,
  required bool isSelected,
  required bool isSingleSelection,
  required bool canReact,
  required bool showRecipientCutout,
  required double availableWidth,
  required double selectionExtrasPreferredMaxWidth,
  required double messageRowMaxWidth,
  required double bubbleMaxWidthForLayout,
  required double? measuredBubbleWidth,
  required double bubbleBottomCutoutPadding,
  required Object bubbleContentKey,
  required List<Widget> bubbleExtraChildren,
  required BoxConstraints bubbleExtraConstraints,
  required List<BoxShadow> bubbleShadows,
  required bool hasAvatarSlot,
  required double avatarContentInset,
  required Widget actionBar,
  required Widget? reactionManager,
}) {
  final spacing = context.spacing;
  final recipientHeadroom = showRecipientCutout ? spacing.m : 0.0;
  final attachmentTopPadding =
      (isSingleSelection ? spacing.s : spacing.m) + recipientHeadroom;
  final attachmentBottomPadding =
      spacing.xl + ((canReact && isSingleSelection) ? spacing.m : 0);
  final attachmentPadding = EdgeInsets.only(
    top: attachmentTopPadding,
    bottom: attachmentBottomPadding,
    left: spacing.m,
    right: spacing.m,
  );
  final attachmentsAligned = _ChatTimelineMessageSelectionExtras(
    self: self,
    isSingleSelection: isSingleSelection,
    actionBar: actionBar,
    reactionManager: reactionManager,
    availableWidth: availableWidth,
    selectionExtrasPreferredMaxWidth: selectionExtrasPreferredMaxWidth,
    bubbleMaxWidthForLayout: bubbleMaxWidthForLayout,
    messageRowMaxWidth: messageRowMaxWidth,
    measuredBubbleWidth: measuredBubbleWidth,
    attachmentPadding: attachmentPadding,
    bubbleBottomCutoutPadding: bubbleBottomCutoutPadding,
  );
  final extrasAligned = bubbleExtraChildren.isEmpty
      ? const SizedBox.shrink()
      : _ChatTimelineMessageExtrasView(
          self: self,
          isSelected: isSelected,
          bubbleBottomCutoutPadding: bubbleBottomCutoutPadding,
          bubbleContentKey: bubbleContentKey,
          bubbleExtraChildren: bubbleExtraChildren,
          bubbleExtraConstraints: bubbleExtraConstraints,
          extraShadows: bubbleShadows,
        );
  final senderLabel = _senderLabelForTimelineMessage(
    context: context,
    shouldShow: !_chatTimelineItemsShouldChain(currentItem, previous),
    isSelfBubble: self,
    hasAvatarSlot: hasAvatarSlot,
    avatarContentInset: avatarContentInset,
    user: messageUser,
    selfLabel: context.l10n.chatSenderYou,
  );
  return (
    attachmentsAligned: attachmentsAligned,
    extrasAligned: extrasAligned,
    senderLabel: senderLabel,
  );
}

class _ChatTimelineMessageShellView extends StatelessWidget {
  const _ChatTimelineMessageShellView({
    required this.currentItem,
    required this.previous,
    required this.next,
    required this.timelineMessageItem,
    required this.messageModel,
    required this.messageUser,
    required this.readOnly,
    required this.isGroupChat,
    required this.multiSelectActive,
    required this.bubbleRegionRegistry,
    required this.selectionTapRegionGroup,
    required this.rowKey,
    required this.measuredBubbleWidth,
    required this.animate,
    required this.onTapOutside,
    required this.availableWidth,
    required this.inboundClampedBubbleWidth,
    required this.outboundClampedBubbleWidth,
    required this.messageRowMaxWidth,
    required this.selectionExtrasPreferredMaxWidth,
    required this.viewData,
    required this.interactionData,
    required this.bubbleContentData,
    required this.quotedPreview,
    required this.forwardedPreview,
    required this.actionBar,
    required this.reactionManager,
    required this.onToggleMultiSelectRequested,
    required this.onToggleQuickReactionRequested,
    required this.onRecipientTap,
    required this.onBubbleTap,
    required this.onBubbleSizeChanged,
  });

  final ChatTimelineItem currentItem;
  final ChatTimelineItem? previous;
  final ChatTimelineItem? next;
  final ChatTimelineMessageItem timelineMessageItem;
  final Message messageModel;
  final ChatUser messageUser;
  final bool readOnly;
  final bool isGroupChat;
  final bool multiSelectActive;
  final _BubbleRegionRegistry bubbleRegionRegistry;
  final Object selectionTapRegionGroup;
  final Key? rowKey;
  final double? measuredBubbleWidth;
  final bool animate;
  final TapRegionCallback? onTapOutside;
  final double availableWidth;
  final double inboundClampedBubbleWidth;
  final double outboundClampedBubbleWidth;
  final double messageRowMaxWidth;
  final double selectionExtrasPreferredMaxWidth;
  final ({
    String detailId,
    bool self,
    double bubbleMaxWidth,
    Color bubbleColor,
    Color borderColor,
    bool isEmailMessage,
    bool isPinned,
    bool isImportant,
  })
  viewData;
  final ({
    List<ReactionPreview> reactions,
    List<chat_models.Chat> replyParticipants,
    List<chat_models.Chat> recipientCutoutParticipants,
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
  interactionData;
  final ({
    Object bubbleContentKey,
    List<Widget> bubbleTextChildren,
    List<Widget> bubbleExtraChildren,
  })
  bubbleContentData;
  final Widget? quotedPreview;
  final Widget? forwardedPreview;
  final Widget actionBar;
  final Widget? reactionManager;
  final void Function(Message message) onToggleMultiSelectRequested;
  final void Function(Message message, String emoji)
  onToggleQuickReactionRequested;
  final void Function(chat_models.Chat chat) onRecipientTap;
  final VoidCallback? onBubbleTap;
  final void Function(String messageId, Size size) onBubbleSizeChanged;

  @override
  Widget build(BuildContext context) {
    final self = viewData.self;
    final shellData = _resolveTimelineMessageShellData(
      context: context,
      currentItem: currentItem,
      previous: previous,
      next: next,
      timelineMessageItem: timelineMessageItem,
      messageModel: messageModel,
      viewData: viewData,
      interactionData: interactionData,
      isGroupChat: isGroupChat,
      multiSelectActive: multiSelectActive,
      inboundClampedBubbleWidth: inboundClampedBubbleWidth,
      outboundClampedBubbleWidth: outboundClampedBubbleWidth,
      messageRowMaxWidth: messageRowMaxWidth,
      bubbleContentData: bubbleContentData,
      onToggleMultiSelectRequested: onToggleMultiSelectRequested,
      onToggleQuickReactionRequested: onToggleQuickReactionRequested,
      onRecipientTap: onRecipientTap,
    );
    return _ChatTimelineMessageDecorationsView(
      currentItem: currentItem,
      previous: previous,
      timelineMessageItem: timelineMessageItem,
      messageModel: messageModel,
      messageUser: messageUser,
      readOnly: readOnly,
      self: self,
      isSelected: interactionData.isSelected,
      isSingleSelection: interactionData.isSingleSelection,
      isEmailMessage: viewData.isEmailMessage,
      canReact: interactionData.canReact,
      showRecipientCutout: interactionData.showRecipientCutout,
      messageRowMaxWidth: messageRowMaxWidth,
      availableWidth: availableWidth,
      selectionExtrasPreferredMaxWidth: selectionExtrasPreferredMaxWidth,
      measuredBubbleWidth: measuredBubbleWidth,
      bubbleContentData: bubbleContentData,
      shellData: shellData,
      quotedPreview: quotedPreview,
      forwardedPreview: forwardedPreview,
      actionBar: actionBar,
      reactionManager: reactionManager,
      bubbleRegionRegistry: bubbleRegionRegistry,
      selectionTapRegionGroup: selectionTapRegionGroup,
      rowKey: rowKey,
      animate: animate,
      onBubbleTap: onBubbleTap,
      onTapOutside: onTapOutside,
      onBubbleSizeChanged: onBubbleSizeChanged,
    );
  }
}

class _ChatTimelineMessageDecorationsView extends StatelessWidget {
  const _ChatTimelineMessageDecorationsView({
    required this.currentItem,
    required this.previous,
    required this.timelineMessageItem,
    required this.messageModel,
    required this.messageUser,
    required this.readOnly,
    required this.self,
    required this.isSelected,
    required this.isSingleSelection,
    required this.isEmailMessage,
    required this.canReact,
    required this.showRecipientCutout,
    required this.messageRowMaxWidth,
    required this.availableWidth,
    required this.selectionExtrasPreferredMaxWidth,
    required this.measuredBubbleWidth,
    required this.bubbleContentData,
    required this.shellData,
    required this.quotedPreview,
    required this.forwardedPreview,
    required this.actionBar,
    required this.reactionManager,
    required this.bubbleRegionRegistry,
    required this.selectionTapRegionGroup,
    required this.rowKey,
    required this.animate,
    required this.onBubbleTap,
    required this.onTapOutside,
    required this.onBubbleSizeChanged,
  });

  final ChatTimelineItem currentItem;
  final ChatTimelineItem? previous;
  final ChatTimelineMessageItem timelineMessageItem;
  final Message messageModel;
  final ChatUser messageUser;
  final bool readOnly;
  final bool self;
  final bool isSelected;
  final bool isSingleSelection;
  final bool isEmailMessage;
  final bool canReact;
  final bool showRecipientCutout;
  final double messageRowMaxWidth;
  final double availableWidth;
  final double selectionExtrasPreferredMaxWidth;
  final double? measuredBubbleWidth;
  final ({
    Object bubbleContentKey,
    List<Widget> bubbleTextChildren,
    List<Widget> bubbleExtraChildren,
  })
  bubbleContentData;
  final ({
    Widget bubble,
    EdgeInsets outerPadding,
    double bubbleMaxWidthForLayout,
    double bubbleBottomCutoutPadding,
    BoxConstraints bubbleExtraConstraints,
    List<BoxShadow> bubbleShadows,
    bool hasAvatarSlot,
    double avatarContentInset,
  })
  shellData;
  final Widget? quotedPreview;
  final Widget? forwardedPreview;
  final Widget actionBar;
  final Widget? reactionManager;
  final _BubbleRegionRegistry bubbleRegionRegistry;
  final Object selectionTapRegionGroup;
  final Key? rowKey;
  final bool animate;
  final VoidCallback? onBubbleTap;
  final TapRegionCallback? onTapOutside;
  final void Function(String messageId, Size size) onBubbleSizeChanged;

  @override
  Widget build(BuildContext context) {
    final (
      attachmentsAligned: attachments,
      extrasAligned: extrasAligned,
      senderLabel: senderLabel,
    ) = _resolveTimelineMessageRowDecorations(
      context: context,
      currentItem: currentItem,
      previous: previous,
      messageUser: messageUser,
      self: self,
      isSelected: isSelected,
      isSingleSelection: isSingleSelection,
      canReact: canReact,
      showRecipientCutout: showRecipientCutout,
      availableWidth: availableWidth,
      selectionExtrasPreferredMaxWidth: selectionExtrasPreferredMaxWidth,
      messageRowMaxWidth: messageRowMaxWidth,
      bubbleMaxWidthForLayout: shellData.bubbleMaxWidthForLayout,
      measuredBubbleWidth: measuredBubbleWidth,
      bubbleBottomCutoutPadding: shellData.bubbleBottomCutoutPadding,
      bubbleContentKey: bubbleContentData.bubbleContentKey,
      bubbleExtraChildren: bubbleContentData.bubbleExtraChildren,
      bubbleExtraConstraints: shellData.bubbleExtraConstraints,
      bubbleShadows: shellData.bubbleShadows,
      hasAvatarSlot: shellData.hasAvatarSlot,
      avatarContentInset: shellData.avatarContentInset,
      actionBar: actionBar,
      reactionManager: reactionManager,
    );
    return _ChatTimelineMessageRowView(
      messageId: messageModel.stanzaID,
      rowKey: rowKey,
      readOnly: readOnly,
      self: self,
      isSingleSelection: isSingleSelection,
      isEmailMessage: isEmailMessage,
      showUnreadIndicator: timelineMessageItem.showUnreadIndicator,
      messageRowMaxWidth: messageRowMaxWidth,
      bubblePreviewWidth: shellData.bubbleMaxWidthForLayout,
      replyPreviewMaxWidth: messageRowMaxWidth,
      messageRowAlignment: self ? Alignment.centerRight : Alignment.centerLeft,
      outerPadding: shellData.outerPadding,
      bubble: shellData.bubble,
      senderLabel: senderLabel,
      forwardedPreview: forwardedPreview,
      quotedPreview: quotedPreview,
      attachmentsAligned: attachments,
      extrasAligned: extrasAligned,
      showExtras: bubbleContentData.bubbleExtraChildren.isNotEmpty,
      bubbleRegionRegistry: bubbleRegionRegistry,
      selectionTapRegionGroup: selectionTapRegionGroup,
      animate: animate,
      onBubbleTap: onBubbleTap,
      onBubbleSizeChanged: (size) =>
          onBubbleSizeChanged(messageModel.stanzaID, size),
      onTapOutside: onTapOutside,
    );
  }
}

class _ChatMessageList extends StatefulWidget {
  const _ChatMessageList({
    required this.items,
    required this.itemBuilder,
    required this.messageListOptions,
    required this.scrollToBottomOptions,
    this.readOnly = false,
  });

  final List<ChatTimelineItem> items;
  final Widget Function(
    ChatTimelineItem item,
    ChatTimelineItem? previous,
    ChatTimelineItem? next,
  )
  itemBuilder;
  final MessageListOptions messageListOptions;
  final ScrollToBottomOptions scrollToBottomOptions;
  final bool readOnly;

  @override
  State<_ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListRow extends StatelessWidget {
  const _ChatMessageListRow({
    required this.item,
    required this.previousItem,
    required this.nextItem,
    required this.itemBuilder,
    required this.messageListOptions,
  });

  final ChatTimelineItem item;
  final ChatTimelineItem? previousItem;
  final ChatTimelineItem? nextItem;
  final Widget Function(
    ChatTimelineItem item,
    ChatTimelineItem? previous,
    ChatTimelineItem? next,
  )
  itemBuilder;
  final MessageListOptions messageListOptions;

  @override
  Widget build(BuildContext context) {
    final isAfterDateSeparator = _shouldShowChatTimelineDateSeparator(
      previousItem,
      item,
      messageListOptions,
    );
    return Column(
      children: [
        if (isAfterDateSeparator)
          messageListOptions.dateSeparatorBuilder != null
              ? messageListOptions.dateSeparatorBuilder!(item.createdAt)
              : DefaultDateSeparator(
                  date: item.createdAt,
                  messageListOptions: messageListOptions,
                ),
        itemBuilder(item, previousItem, nextItem),
      ],
    );
  }
}

class _ChatMessageListState extends State<_ChatMessageList> {
  bool _scrollToBottomVisible = false;
  bool _isLoadingMore = false;
  int? _loadEarlierStartingCount;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    final controller =
        widget.messageListOptions.scrollController ?? ScrollController();
    _scrollController = controller..addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    if (widget.messageListOptions.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final itemBuilder = widget.itemBuilder;
    final messageListOptions = widget.messageListOptions;
    final scrollToBottomOptions = widget.scrollToBottomOptions;
    const double loadEarlierTopInset = 8.0;
    final shouldShowLoadEarlierSpinner =
        _isLoadingMore &&
        (_loadEarlierStartingCount == null ||
            items.length <= _loadEarlierStartingCount!);
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView.builder(
                physics: messageListOptions.scrollPhysics,
                padding: EdgeInsets.zero,
                controller: _scrollController,
                reverse: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final ChatTimelineItem? previousItem =
                      index < items.length - 1 ? items[index + 1] : null;
                  final ChatTimelineItem? nextItem = index > 0
                      ? items[index - 1]
                      : null;
                  return _ChatMessageListRow(
                    item: items[index],
                    previousItem: previousItem,
                    nextItem: nextItem,
                    itemBuilder: itemBuilder,
                    messageListOptions: messageListOptions,
                  );
                },
              ),
            ),
            if (messageListOptions.chatFooterBuilder != null)
              messageListOptions.chatFooterBuilder!,
          ],
        ),
        if (shouldShowLoadEarlierSpinner)
          Positioned(
            top: loadEarlierTopInset,
            right: 0,
            left: 0,
            child:
                messageListOptions.loadEarlierBuilder ??
                const Center(
                  child: SizedBox(child: CircularProgressIndicator()),
                ),
          ),
        if (!scrollToBottomOptions.disabled && _scrollToBottomVisible)
          scrollToBottomOptions.scrollToBottomBuilder != null
              ? scrollToBottomOptions.scrollToBottomBuilder!(_scrollController)
              : DefaultScrollToBottom(
                  scrollController: _scrollController,
                  readOnly: widget.readOnly,
                  backgroundColor: context.colorScheme.background,
                  textColor: context.colorScheme.primary,
                ),
      ],
    );
  }

  Future<void> _handleScroll() async {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange &&
        widget.messageListOptions.onLoadEarlier != null &&
        !_isLoadingMore) {
      setState(() {
        _isLoadingMore = true;
        _loadEarlierStartingCount = widget.items.length;
      });
      _showScrollToBottom();
      await widget.messageListOptions.onLoadEarlier!();
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingMore = false;
        _loadEarlierStartingCount = null;
      });
      return;
    }
    const double scrollToBottomThreshold = 200.0;
    if (_scrollController.offset > scrollToBottomThreshold) {
      _showScrollToBottom();
    } else {
      _hideScrollToBottom();
    }
  }

  void _showScrollToBottom() {
    if (_scrollToBottomVisible) return;
    setState(() {
      _scrollToBottomVisible = true;
    });
  }

  void _hideScrollToBottom() {
    if (!_scrollToBottomVisible) return;
    setState(() {
      _scrollToBottomVisible = false;
    });
  }
}

bool _shouldShowChatTimelineDateSeparator(
  ChatTimelineItem? previousItem,
  ChatTimelineItem item,
  MessageListOptions messageListOptions,
) {
  if (!messageListOptions.showDateSeparator) {
    return false;
  }
  if (previousItem == null) {
    return true;
  }
  switch (messageListOptions.separatorFrequency) {
    case SeparatorFrequency.days:
      final previousDate = DateTime(
        previousItem.createdAt.year,
        previousItem.createdAt.month,
        previousItem.createdAt.day,
      );
      final messageDate = DateTime(
        item.createdAt.year,
        item.createdAt.month,
        item.createdAt.day,
      );
      return previousDate.difference(messageDate).inDays.abs() > 0;
    case SeparatorFrequency.hours:
      final previousDate = DateTime(
        previousItem.createdAt.year,
        previousItem.createdAt.month,
        previousItem.createdAt.day,
        previousItem.createdAt.hour,
      );
      final messageDate = DateTime(
        item.createdAt.year,
        item.createdAt.month,
        item.createdAt.day,
        item.createdAt.hour,
      );
      return previousDate.difference(messageDate).inHours.abs() > 0;
  }
}

class _ForwardRecipientSheet extends StatefulWidget {
  const _ForwardRecipientSheet({required this.availableChats});

  final List<chat_models.Chat> availableChats;

  @override
  State<_ForwardRecipientSheet> createState() => _ForwardRecipientSheetState();
}

class _ForwardRecipientSheetState extends State<_ForwardRecipientSheet> {
  List<ComposerRecipient> _recipients = const [];

  Contact? get _selectedTarget {
    for (final recipient in _recipients) {
      final target = recipient.target;
      if (recipient.isIncluded) {
        return target;
      }
    }
    return null;
  }

  bool get _canSend => _selectedTarget != null;

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
    setState(() {
      _recipients = <ComposerRecipient>[ComposerRecipient(target: target)];
    });
  }

  void _handleRecipientRemoved(String key) {
    if (!mounted) return;
    setState(() {
      _recipients = _recipients
          .where((recipient) => recipient.key != key)
          .toList(growable: false);
    });
  }

  void _handleRecipientToggled(String key) {
    if (!mounted) return;
    setState(() {
      _recipients = _recipients
          .map(
            (recipient) =>
                recipient.key == key ? recipient.toggledIncluded() : recipient,
          )
          .toList(growable: false);
    });
  }

  void _handleSend() {
    final Contact? selected = _selectedTarget;
    if (selected == null) return;
    Navigator.of(context).pop(selected);
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final locate = context.read;
    final iconSize = context.sizing.iconButtonIconSize;
    final sectionSpacing = spacing.m;
    final contentPadding = EdgeInsets.symmetric(horizontal: spacing.m);
    final profileJid = context.watch<ProfileCubit>().state.jid;
    final trimmedProfileJid = profileJid.trim();
    final String? selfJid = trimmedProfileJid.isNotEmpty
        ? trimmedProfileJid
        : null;
    final selfIdentity = SelfIdentitySnapshot(
      selfJid: selfJid,
      avatarPath: context.watch<ProfileCubit>().state.avatarPath,
      avatarLoading: context.watch<ProfileCubit>().state.avatarHydrating,
    );
    final header = AxiSheetHeader(
      title: Text(l10n.chatForwardDialogTitle),
      onClose: () => Navigator.of(context).maybePop(),
    );
    return AxiSheetScaffold.scroll(
      header: header,
      bodyPadding: EdgeInsets.zero,
      children: [
        BlocSelector<ChatsCubit, ChatsState, List<String>>(
          bloc: locate<ChatsCubit>(),
          selector: (state) => state.recipientAddressSuggestions,
          builder: (context, recipientAddressSuggestions) {
            final rosterItems =
                context.watch<RosterCubit>().state.items ??
                (context.watch<RosterCubit>()[RosterCubit.itemsCacheKey]
                    as List<RosterItem>?) ??
                const <RosterItem>[];
            return RecipientChipsBar(
              recipients: _recipients,
              availableChats: widget.availableChats,
              rosterItems: rosterItems,
              databaseSuggestionAddresses: recipientAddressSuggestions,
              selfJid: locate<ChatsCubit>().selfJid,
              selfIdentity: selfIdentity,
              latestStatuses: const {},
              collapsedByDefault: false,
              allowAddressTargets: true,
              showSuggestionsWhenEmpty: true,
              horizontalPadding: 0,
              onRecipientAdded: _handleRecipientAdded,
              onRecipientRemoved: _handleRecipientRemoved,
              onRecipientToggled: _handleRecipientToggled,
            );
          },
        ),
        SizedBox(height: sectionSpacing),
        Padding(
          padding: contentPadding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AxiButton.outline(
                onPressed: () => closeSheetWithKeyboardDismiss(
                  context,
                  () => Navigator.of(context).maybePop(),
                ),
                child: Text(l10n.commonCancel),
              ),
              SizedBox(width: spacing.s),
              AxiButton.primary(
                onPressed: _canSend ? _handleSend : null,
                leading: Icon(LucideIcons.send, size: iconSize),
                child: Text(l10n.commonSend),
              ),
            ],
          ),
        ),
        SizedBox(height: sectionSpacing),
      ],
    );
  }
}
