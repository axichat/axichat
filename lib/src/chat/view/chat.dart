// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:animations/animations.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/attachments/bloc/attachment_gallery_cubit.dart';
import 'package:axichat/src/attachments/view/attachment_gallery_view.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/blocklist/models/blocklist_entry.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/chat_calendar_bloc.dart';
import 'package:axichat/src/calendar/models/calendar_availability_message.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/calendar_task_ics_message.dart';
import 'package:axichat/src/calendar/reminders/calendar_reminder_controller.dart';
import 'package:axichat/src/calendar/storage/chat_calendar_storage.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_coordinator.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_sync_coordinator.dart';
import 'package:axichat/src/calendar/utils/calendar_fragment_policy.dart';
import 'package:axichat/src/calendar/utils/location_autocomplete.dart';
import 'package:axichat/src/calendar/utils/task_share_formatter.dart';
import 'package:axichat/src/calendar/view/chat_calendar_widget.dart';
import 'package:axichat/src/calendar/view/models/calendar_drag_payload.dart';
import 'package:axichat/src/calendar/view/quick_add_modal.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/bloc/chat_search_cubit.dart';
import 'package:axichat/src/chat/models/pending_attachment.dart';
import 'package:axichat/src/chat/models/pinned_message_item.dart';
import 'package:axichat/src/chat/util/chat_subject_codec.dart';
import 'package:axichat/src/chat/view/attachment_approval_dialog.dart';
import 'package:axichat/src/chat/view/chat_alert.dart';
import 'package:axichat/src/chat/view/chat_attachment_preview.dart';
import 'package:axichat/src/chat/view/chat_bubble_surface.dart';
import 'package:axichat/src/chat/view/chat_cutout_composer.dart';
import 'package:axichat/src/chat/view/chat_message_details.dart';
import 'package:axichat/src/chat/view/message_text_parser.dart';
import 'package:axichat/src/chat/view/pending_attachment_list.dart';
import 'package:axichat/src/chat/view/recipient_chips_bar.dart';
import 'package:axichat/src/chat/view/widgets/calendar_availability_card.dart';
import 'package:axichat/src/chat/view/widgets/calendar_availability_request_sheet.dart';
import 'package:axichat/src/chat/view/widgets/calendar_fragment_card.dart';
import 'package:axichat/src/chat/view/widgets/chat_calendar_critical_path_card.dart';
import 'package:axichat/src/chat/view/widgets/chat_calendar_task_card.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/widgets/contact_rename_dialog.dart';
import 'package:axichat/src/chats/view/widgets/selection_panel_shell.dart';
import 'package:axichat/src/chats/view/widgets/transport_aware_avatar.dart';
import 'package:axichat/src/common/bool_tool.dart';
import 'package:axichat/src/common/file_type_detector.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/policy.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/unicode_safety.dart';
import 'package:axichat/src/common/url_safety.dart';
import 'package:axichat/src/common/ui/context_action_button.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/email/util/delta_jids.dart';
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
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_html/flutter_html.dart' as html_widget;
import 'package:axichat/src/chat/view/widgets/email_image_extension.dart';
import 'package:flutter/rendering.dart' show PipelineOwner, RenderProxyBox;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

enum _ChatRoute {
  main,
  search,
  details,
  settings,
  gallery,
  calendar,
}

extension on _ChatRoute {
  bool get isMain => this == _ChatRoute.main;

  bool get isSearch => this == _ChatRoute.search;

  bool get isDetails => this == _ChatRoute.details;

  bool get isSettings => this == _ChatRoute.settings;

  bool get isGallery => this == _ChatRoute.gallery;

  bool get isCalendar => this == _ChatRoute.calendar;

  bool get allowsChatInteraction => isMain || isSearch;
}

const _bubblePadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
const _bubbleRadius = 18.0;
const double _senderLabelBottomSpacing = 6.0;
const double _senderLabelSecondarySpacing = 2.0;
const double _senderLabelNoInset = 0.0;
const String _senderLabelAddressPrefix = 'JID: ';
const _reactionBubbleInset = 12.0;
const _reactionCutoutDepth = 14.0;
const List<BlocklistEntry> _emptyBlocklistEntries = <BlocklistEntry>[];
const _reactionCutoutMinThickness = 28.0;
const _reactionCutoutRadius = 16.0;
const _reactionStripOffset = Offset(0, -2);
const _reactionCutoutPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
const _reactionChipPadding = EdgeInsets.symmetric(horizontal: 0.2, vertical: 2);
const _reactionChipSpacing = 0.6;
const _reactionOverflowSpacing = 4.0;
const _reactionSubscriptPadding = 3.0;
const _reactionCornerClearance = 12.0;
const _cutoutMaxWidthFraction = 1.0;
const _compactBubbleWidthFraction = 0.7;
const _regularBubbleWidthFraction = 0.7;
const _reactionOverflowGlyphWidth = 18.0;
const String _chatCalendarPanelKeyPrefix = 'chat-calendar-';
const String _chatPinnedPanelKeyPrefix = 'chat-pins-';
const String _chatPanelKeyFallback = '';
const _recipientCutoutDepth = 16.0;
const _recipientCutoutRadius = 18.0;
const _recipientCutoutPadding = EdgeInsets.fromLTRB(10, 4, 10, 6);
const _recipientCutoutOffset = Offset.zero;
const _recipientAvatarSize = 28.0;
const _recipientAvatarOverlap = 10.0;
const _recipientCutoutMinThickness = 48.0;
const _selectionCutoutDepth = 17.0;
const _selectionCutoutRadius = 16.0;
const _selectionCutoutPadding = EdgeInsets.fromLTRB(4, 4.5, 4, 4.5);
const _selectionCutoutOffset = Offset(-3, 0);
const _selectionCutoutThickness = SelectionIndicator.size + 9.0;
const _selectionCutoutCornerClearance = 0.0;
const _selectionBubbleInteriorInset = _selectionCutoutDepth + 6.0;
const _selectionBubbleVerticalInset = 4.0;
const _selectionOuterInset =
    _selectionCutoutDepth + (SelectionIndicator.size / 2);
const _selectionIndicatorInset =
    2.0; // Keeps the 28px indicator centered within the selection cutout.
const int _chatBaseActionCount = 3;
const _chatHeaderActionSpacing = 2.0;
const double _chatAppBarLeadingInset = 12.0;
const double _chatAppBarLeadingSpacing = 4.0;
const double _chatAppBarActionsPadding = 8.0;
const double _chatAppBarAvatarSize = 40.0;
const double _chatAppBarAvatarSpacing = 8.0;
const double _chatAppBarTitleMinWidth = 220.0;
const double _chatAppBarTitleMaxWidth = 420.0;
const double _chatAppBarTitleWidthScale = 0.45;
const double _chatAppBarCollapsedLeadingWidth = 0.0;
const double _chatAppBarRenameIconSize = 16.0;
const double _unknownSenderCardPadding = 12.0;
const double _unknownSenderIconSize = 18.0;
const double _unknownSenderTextSpacing = 8.0;
const double _unknownSenderActionSpacing = 8.0;
const _chatSettingsSelectMinWidth = 220.0;
const _chatSettingsFieldSpacing = 8.0;
const _chatSettingsLabelSpacing = 4.0;
const _chatSettingsItemPadding = EdgeInsets.all(12.0);
const _messageActionIconSize = 16.0;
const _pinnedListLoadingIndicatorSize = 28.0;
const int _pinnedBadgeHiddenCount = 0;
const int _pinnedBadgeMaxDisplayCount = 99;
const String _pinnedBadgeOverflowLabel = '99+';
const double _pinnedBadgeIconScale = 0.6;
const double _pinnedBadgeFallbackIconSize =
    AxiIconButton.kDefaultSize * _pinnedBadgeIconScale;
const double _pinnedBadgeSizeScale = 0.55;
const double _pinnedBadgeInsetScale = 0.08;
const double _pinnedBadgeBorderWidth = 1.0;
const String _calendarFragmentShareDeniedMessage =
    'Calendar cards are disabled for your role in this room.';
const String _calendarFragmentPropertyKey = 'calendarFragment';
const String _calendarTaskIcsPropertyKey = 'calendarTaskIcs';
const String _calendarTaskIcsReadOnlyPropertyKey = 'calendarTaskIcsReadOnly';
const String _calendarAvailabilityPropertyKey = 'calendarAvailability';
const bool _calendarTaskIcsReadOnlyFallback =
    CalendarTaskIcsMessage.defaultReadOnly;
const String _availabilityRequestAccountMissingMessage =
    'Availability requests are unavailable right now.';
const String _availabilityRequestEmailUnsupportedMessage =
    'Availability is unavailable for email chats.';
const String _availabilityRequestInvalidRangeMessage =
    'Availability request time is invalid.';
const String _availabilityRequestCalendarUnavailableMessage =
    'Calendar is unavailable.';
const String _availabilityRequestChatCalendarUnavailableMessage =
    'Chat calendar is unavailable.';
const String _availabilityRequestTaskTitleFallback = 'Requested time';
const Uuid _availabilityResponseIdGenerator = Uuid();
const String _composerShareSeparator = '\n\n';
const String _emptyText = '';
const String _jidResourceSeparator = '/';
const List<InlineSpan> _emptyInlineSpans = <InlineSpan>[];
const _selectionExtrasMaxWidth = 500.0;
const _messageAvatarSize = 36.0;
const _messageRowAvatarReservation = 32.0;
const _messageAvatarCutoutDepth = _messageAvatarSize / 2;
const _messageAvatarCutoutRadius = _messageAvatarCutoutDepth + 4.0;
const _messageAvatarCutoutPadding = EdgeInsets.zero;
const _messageAvatarCutoutMinThickness = _messageAvatarSize;
const _messageAvatarCutoutAlignment = -1.0;
const _messageAvatarCornerClearance = 0.0;
const _messageAvatarOuterInset = _messageAvatarCutoutDepth;
const _messageAvatarContentInset = _messageAvatarCutoutDepth - 4.0;
const _selectionBubbleInboundExtraGap = 4.0;
const _selectionBubbleOutboundExtraGap = 8.0;
const _selectionBubbleOutboundSpacingBoost = 6.0;
const _selectionBubbleInboundSpacing =
    _selectionBubbleInteriorInset + _selectionBubbleInboundExtraGap;
const _selectionBubbleOutboundSpacing = _selectionBubbleInteriorInset +
    _selectionBubbleOutboundExtraGap +
    _selectionBubbleOutboundSpacingBoost;
const _recipientBubbleInset = _recipientCutoutDepth;
const _recipientOverflowGap = 6.0;
const _bubbleFocusDuration = Duration(milliseconds: 620);
const _bubbleFocusCurve = Curves.easeOutCubic;
const _bubbleSizeSnapDuration = Duration(milliseconds: 1);
const _messageArrivalDuration = Duration(milliseconds: 420);
const _messageArrivalCurve = Curves.easeOutCubic;
const Curve _chatOverlayFadeCurve = Curves.easeOutCubic;
const Offset _chatCalendarSlideOffset = Offset(0.0, 0.04);
const _chatHorizontalPadding = 16.0;
const _chatPinnedPanelHorizontalPadding = _chatHorizontalPadding;
const _chatPinnedPanelVerticalPadding = 12.0;
const _chatPinnedPanelHeaderSpacing = 12.0;
const _chatPinnedPanelEmptyStatePadding = 12.0;
const _chatPinnedPanelMinHeight = 0.0;
const int _pinnedSenderMaxLines = 1;
const _selectionAutoscrollSlop = 4.0;
const _selectionAutoscrollReboundCurve = Curves.easeOutCubic;
const _selectionAutoscrollReboundDuration = Duration(milliseconds: 260);
const _selectionAttachmentBaseGap = 16.0;
const _selectionAttachmentSelectedGap = 8.0;
const _attachmentPreviewSpacing = 8.0;
const double _inviteAttachmentCornerRadius = 20.0;
const double _inviteAttachmentPaddingValue = 12.0;
const _inviteAttachmentPadding = EdgeInsets.all(_inviteAttachmentPaddingValue);
const double _inviteAttachmentIconWidth = 42.0;
const double _inviteAttachmentIconHeight = 46.0;
const double _inviteAttachmentIconSize = 20.0;
const double _inviteAttachmentIconCornerRadius = 12.0;
const double _inviteAttachmentIconBackgroundAlpha = 0.15;
const double _inviteAttachmentRowSpacing = 12.0;
const double _inviteAttachmentDetailSpacing = 4.0;
const int _inviteAttachmentLabelMaxLines = 1;
const TextOverflow _inviteAttachmentLabelOverflow = TextOverflow.ellipsis;
const double _inviteAttachmentActionSpacing = 8.0;
const int _inviteAttachmentActionButtonCount = 1;
const double _inviteAttachmentActionRowMinWidth =
    (AxiIconButton.kTapTargetSize * _inviteAttachmentActionButtonCount) +
        (_inviteAttachmentActionSpacing *
            (_inviteAttachmentActionButtonCount - 1));
const double _inviteAttachmentInlineActionsMinWidth =
    _inviteAttachmentIconWidth +
        (_inviteAttachmentRowSpacing * 2) +
        _inviteAttachmentActionRowMinWidth;
const _selectionExtrasViewportGap = 50.0;
const _reactionManagerRadius = 18.0;
const _reactionManagerQuickSpacing = 8.0;
const _reactionManagerPadding = EdgeInsets.symmetric(
  horizontal: 14,
  vertical: 12,
);
const _reactionManagerShadowGap = 16.0;
const _selectionHeadroomTolerance = 1.0;
// ignore: unused_element
const _selectionDismissMoveAllowance = 36.0;
// ignore: unused_element
const _selectionDismissTapAllowance = 48.0;
final _selectionSpacerTimestamp =
    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
const _reactionQuickChoices = [
  '👍',
  '❤️',
  '😂',
  '😮',
  '😢',
  '🙏',
  '🔥',
  '👏',
];
const _selectionSpacerMessageId = '__selection_spacer__';
const _emptyStateMessageId = '__empty_state__';
const _chatScrollStoragePrefix = 'chat-scroll-offset-';
const _recipientVisibilityCcLabel = 'CC';
const _recipientVisibilityBccLabel = 'BCC';
const _composerHorizontalInset = _chatHorizontalPadding + 4.0;
const _desktopComposerHorizontalInset = _composerHorizontalInset + 4.0;
const _guestDesktopHorizontalPadding = _chatHorizontalPadding + 6.0;
const _messageListTailSpacer = 36.0;
const _messageLoadingSpinnerSize = 16.0;
const _messageLoadingStrokeWidth = 2.0;
const _subjectFieldHeight = 24.0;
const _subjectDividerPadding = 2.0;
const _subjectDividerThickness = 1.0;
const _messageListHorizontalPadding = 12.0;
const _typingIndicatorBottomInset = 8.0;
const _typingIndicatorRadius = 999.0;
const _typingIndicatorPadding =
    EdgeInsets.symmetric(horizontal: 12, vertical: 8);
const _messageFallbackOuterPadding =
    EdgeInsets.symmetric(horizontal: _chatHorizontalPadding, vertical: 4);
const _messageFallbackInnerPadding = _typingIndicatorPadding;
const _typingIndicatorMaxAvatars = 7;
const _typingAvatarBorderWidth = 1.6;
const _typingAvatarSpacing = 4.0;
const _dashChatPlaceholderText = ' ';

class _MessageFilterOption {
  const _MessageFilterOption(this.filter, this.label);

  final MessageTimelineFilter filter;
  final String label;
}

class _CalendarTaskShare {
  const _CalendarTaskShare({
    required this.task,
    required this.text,
  });

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
    context.read<ChatSearchCubit?>()?.updateQuery(_controller.text);
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
        final messageFilterOptions = _messageFilterOptions(l10n);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: context.colorScheme.card,
            border: Border(
              bottom: BorderSide(color: context.colorScheme.border),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AxiTextInput(
                      controller: _controller,
                      focusNode: _focusNode,
                      placeholder: Text(l10n.chatSearchMessages),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AxiIconButton(
                    iconData: LucideIcons.x,
                    tooltip: l10n.commonClear,
                    onPressed: _controller.text.isEmpty
                        ? null
                        : () {
                            _controller.clear();
                          },
                  ),
                  const SizedBox(width: 8),
                  ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    onPressed: () =>
                        context.read<ChatSearchCubit?>()?.setActive(false),
                    child: Text(l10n.commonCancel),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ShadSelect<SearchSortOrder>(
                      initialValue: state.sort,
                      onChanged: (value) {
                        if (value == null) return;
                        context.read<ChatSearchCubit?>()?.updateSort(value);
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: ShadSelect<MessageTimelineFilter>(
                      initialValue: state.filter,
                      onChanged: (value) {
                        if (value == null) return;
                        context.read<ChatSearchCubit?>()?.updateFilter(value);
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
                            .firstWhere(
                              (option) => option.filter == value,
                            )
                            .label,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ShadSelect<String>(
                      initialValue: state.subjectFilter ?? '',
                      onChanged: (value) {
                        context.read<ChatSearchCubit?>()?.updateSubjectFilter(
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
                  const SizedBox(width: 12),
                  ShadSwitch(
                    value: state.excludeSubject,
                    onChanged: (value) => context
                        .read<ChatSearchCubit?>()
                        ?.toggleExcludeSubject(value),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.chatSearchExcludeSubject,
                    style: context.textTheme.muted,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final trimmedQuery = state.query.trim();
                  final hasSubject = state.subjectFilter?.isNotEmpty == true;
                  final queryEmpty = trimmedQuery.isEmpty && !hasSubject;
                  Widget? statusChild;
                  if (state.error != null) {
                    statusChild = Text(
                      state.error ?? l10n.chatSearchFailed,
                      style: TextStyle(
                        color: context.colorScheme.destructive,
                      ),
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
        if (chat == null || chat.type != ChatType.chat || chat.spam) {
          return const SizedBox.shrink();
        }
        return BlocBuilder<RosterCubit, RosterState>(
          buildWhen: (_, current) => current is RosterAvailable,
          builder: (context, rosterState) {
            final cached = rosterState is RosterAvailable
                ? rosterState.items
                : context.read<RosterCubit>()['items'] as List<RosterItem>?;
            final rosterItems = cached ?? const <RosterItem>[];
            final rosterEntry = rosterItems
                .where((entry) => entry.jid == chat.remoteJid)
                .singleOrNull;
            final inRoster =
                rosterEntry != null && !rosterEntry.subscription.isNone;
            final hasContactRecord =
                chat.contactID?.trim().isNotEmpty == true ||
                    chat.contactDisplayName?.trim().isNotEmpty == true;
            final isEmailChat = chat.isEmailBacked;
            final showBanner = (isEmailChat && !hasContactRecord) ||
                (!isEmailChat && !inRoster);
            if (!showBanner) {
              return const SizedBox.shrink();
            }
            EmailService? emailService;
            try {
              emailService = RepositoryProvider.of<EmailService>(
                context,
                listen: false,
              );
            } on Exception {
              emailService = null;
            }
            final canAddContact = !isEmailChat || emailService != null;
            final l10n = context.l10n;
            final actions = <Widget>[
              if (onAddContact != null && canAddContact)
                ContextActionButton(
                  icon: const Icon(
                    LucideIcons.userPlus,
                    size: _unknownSenderIconSize,
                  ),
                  label: l10n.rosterAddTitle,
                  onPressed: () => unawaited(onAddContact!.call()),
                ),
              if (onReportSpam != null)
                ContextActionButton(
                  icon: const Icon(
                    LucideIcons.shieldAlert,
                    size: _unknownSenderIconSize,
                  ),
                  label: l10n.chatReportSpam,
                  onPressed: () => unawaited(onReportSpam!.call()),
                  destructive: true,
                ),
            ];
            return ListItemPadding(
              child: ShadCard(
                padding: const EdgeInsets.all(_unknownSenderCardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.userX,
                          size: _unknownSenderIconSize,
                          color: context.colorScheme.destructive,
                        ),
                        const SizedBox(width: _unknownSenderTextSpacing),
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
                    const SizedBox(height: _unknownSenderTextSpacing),
                    Text(
                      l10n.chatAttachmentBlockedDescription,
                      style: context.textTheme.muted,
                    ),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: _unknownSenderActionSpacing),
                      Wrap(
                        spacing: _unknownSenderActionSpacing,
                        runSpacing: _unknownSenderActionSpacing,
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

BorderRadius _bubbleBorderRadius({
  required bool isSelf,
  required bool chainedPrevious,
  required bool chainedNext,
  bool isSelected = false,
}) {
  if (isSelected) {
    return const BorderRadius.all(Radius.circular(_bubbleRadius));
  }
  const radius = Radius.circular(_bubbleRadius);
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
  return BorderRadius.only(
    topLeft: topLeading,
    topRight: topTrailing,
    bottomLeft: bottomLeading,
    bottomRight: bottomTrailing,
  );
}

bool _chatMessagesShouldChain(
  ChatMessage current,
  ChatMessage? neighbor,
) {
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

ChatCalendarSyncCoordinator? _maybeReadChatCalendarCoordinator(
  BuildContext context,
) {
  try {
    return RepositoryProvider.of<ChatCalendarSyncCoordinator>(
      context,
      listen: false,
    );
  } on FlutterError {
    return null;
  }
}

CalendarAvailabilityShareCoordinator? _maybeReadAvailabilityShareCoordinator(
  BuildContext context,
) {
  try {
    return RepositoryProvider.of<CalendarAvailabilityShareCoordinator>(
      context,
      listen: false,
    );
  } on FlutterError {
    return null;
  }
}

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
    required this.onChangeNickname,
    required this.onLeaveRoom,
    required this.onClose,
  });

  final ValueChanged<String> onInvite;
  final void Function(String occupantId, MucModerationAction action) onAction;
  final ValueChanged<String> onChangeNickname;
  final VoidCallback onLeaveRoom;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final l10n = context.l10n;
        final roomState = state.roomState;
        if (roomState == null) {
          final colors = context.colorScheme;
          final textTheme = context.textTheme;
          return SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AxiProgressIndicator(
                    dimension: 24,
                    color: colors.foreground,
                    semanticsLabel: l10n.chatMembersLoading,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.chatMembersLoadingEllipsis,
                    style:
                        textTheme.muted.copyWith(color: colors.mutedForeground),
                  ),
                ],
              ),
            ),
          );
        }
        return RoomMembersSheet(
          roomState: roomState,
          canInvite: roomState.myAffiliation.isOwner ||
              roomState.myAffiliation.isAdmin ||
              roomState.myRole.isModerator,
          onInvite: onInvite,
          onAction: onAction,
          roomAvatarPath: state.chat?.avatarPath,
          onChangeNickname: onChangeNickname,
          onLeaveRoom: onLeaveRoom,
          currentNickname: roomState.occupants[roomState.myOccupantId]?.nick,
          onClose: onClose,
          useSurface: false,
        );
      },
    );
  }
}

class _ChatState extends State<Chat> {
  late final ShadPopoverController _emojiPopoverController;
  late final FocusNode _focusNode;
  late final TextEditingController _textController;
  late final TextEditingController _subjectController;
  late final FocusNode _subjectFocusNode;
  late final FocusNode _attachmentButtonFocusNode;
  late final ScrollController _scrollController;
  bool _composerHasText = false;
  String _lastSubjectValue = '';
  ChatCalendarBloc? _chatCalendarBloc;
  String? _chatCalendarJid;
  ChatCalendarSyncCoordinator? _fallbackChatCalendarCoordinator;
  final _oneTimeAllowedAttachmentStanzaIds = <String>{};
  final _fileMetadataStreamEntries = <String, _FileMetadataStreamEntry>{};
  final _animatedMessageIds = <String>{};
  var _hydratedAnimatedMessages = false;
  var _chatOpenedAt = DateTime.now();
  static final RegExp _axiDomainPattern =
      RegExp(r'@(?:[\\w-]+\\.)*axi\\.im$', caseSensitive: false);
  static final Map<String, double> _scrollOffsetCache = {};
  String? _lastScrollStorageKey;

  var _chatRoute = _ChatRoute.main;
  var _previousChatRoute = _ChatRoute.main;
  bool _pinnedPanelVisible = false;
  String? _selectedMessageId;
  final _multiSelectedMessageIds = <String>{};
  final _selectedMessageSnapshots = <String, Message>{};
  final _messageKeys = <String, GlobalKey>{};
  final _bubbleRegionRegistry = _BubbleRegionRegistry();
  final _messageListKey = GlobalKey();
  GlobalKey? _activeSelectionExtrasKey;
  GlobalKey? _reactionManagerKey;
  final _selectionActionButtonKeys = <GlobalKey>[];
  double _selectionSpacerBaseHeight = 0;
  double _selectionSpacerHeight = 0;
  double _selectionControlsHeight = 0;
  double _bottomSectionHeight = 0.0;
  bool _selectionAutoscrollActive = false;
  bool _selectionAutoscrollScheduled = false;
  bool _selectionAutoscrollInProgress = false;
  double _selectionAutoscrollAccumulated = 0.0;
  bool _selectionControlsMeasurementPending = false;
  var _sendingAttachment = false;
  Offset? _selectionDismissOrigin;
  int? _selectionDismissPointer;
  var _selectionDismissMoved = false;
  static const CalendarFragmentPolicy _calendarFragmentPolicy =
      CalendarFragmentPolicy();
  static const CalendarFragmentFormatter _calendarFragmentFormatter =
      CalendarFragmentFormatter();
  CalendarTask? _pendingCalendarTaskIcs;
  String? _pendingCalendarSeedText;

  bool get _multiSelectActive => _multiSelectedMessageIds.isNotEmpty;

  bool get _anySelectionActive =>
      _selectedMessageId != null || _multiSelectActive;

  void _typingListener() {
    final text = _textController.text;
    final hasText = text.isNotEmpty;
    final trimmedHasText = text.trim().isNotEmpty;
    if (_composerHasText != trimmedHasText && mounted) {
      setState(() {
        _composerHasText = trimmedHasText;
      });
    }
    if (hasText && _anySelectionActive) {
      _clearAllSelections();
    }
    _maybeClearPendingCalendarTaskIcs(text);
    if (!context.read<SettingsCubit>().state.indicateTyping) return;
    if (!hasText) return;
    context.read<ChatBloc>().add(const ChatTypingStarted());
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

  void _disposeChatCalendarBloc() {
    final bloc = _chatCalendarBloc;
    if (bloc == null) {
      return;
    }
    bloc.close();
    _chatCalendarBloc = null;
    _chatCalendarJid = null;
  }

  ChatCalendarSyncCoordinator? _resolveChatCalendarCoordinator({
    required CalendarStorageManager storageManager,
    required XmppService xmppService,
  }) {
    final coordinator = _maybeReadChatCalendarCoordinator(context);
    if (coordinator != null) {
      return coordinator;
    }
    final storage = storageManager.authStorage;
    if (storage == null) {
      return null;
    }
    final fallback = _fallbackChatCalendarCoordinator;
    if (fallback != null) {
      return fallback;
    }
    return _fallbackChatCalendarCoordinator = ChatCalendarSyncCoordinator(
      storage: ChatCalendarStorage(storage: storage),
      sendMessage: ({
        required String jid,
        required CalendarSyncOutbound outbound,
        required ChatType chatType,
      }) async {
        await xmppService.sendCalendarSyncMessage(
          jid: jid,
          outbound: outbound,
          chatType: chatType,
        );
      },
      sendSnapshotFile: xmppService.uploadCalendarSnapshot,
    );
  }

  ChatCalendarBloc? _resolveChatCalendarBloc({
    required chat_models.Chat? chat,
    required bool calendarAvailable,
    required ChatCalendarSyncCoordinator? coordinator,
  }) {
    final resolvedChat = chat;
    if (!calendarAvailable || resolvedChat == null) {
      _disposeChatCalendarBloc();
      return null;
    }
    if (_chatCalendarBloc != null && _chatCalendarJid == resolvedChat.jid) {
      return _chatCalendarBloc;
    }
    _disposeChatCalendarBloc();
    final storageManager = context.read<CalendarStorageManager>();
    final storage = storageManager.authStorage;
    final resolvedCoordinator = coordinator;
    if (storage == null || resolvedCoordinator == null) {
      return null;
    }
    final reminderController = context.read<CalendarReminderController>();
    final availabilityCoordinator = _maybeReadAvailabilityShareCoordinator(
      context,
    );
    final bloc = ChatCalendarBloc(
      chatJid: resolvedChat.jid,
      chatType: resolvedChat.type,
      coordinator: resolvedCoordinator,
      storage: storage,
      reminderController: reminderController,
      availabilityCoordinator: availabilityCoordinator,
    )..add(const CalendarEvent.started());
    _chatCalendarBloc = bloc;
    _chatCalendarJid = resolvedChat.jid;
    return bloc;
  }

  void _appendTaskShareText(
    CalendarTask task, {
    String? shareText,
  }) {
    final String resolvedShareText = shareText ?? task.toShareText();
    final String existing = _textController.text;
    final String separator =
        existing.trim().isEmpty ? _emptyText : _composerShareSeparator;
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
    final String shareText = task.toShareText().trim();
    if (shareText.isEmpty) {
      return null;
    }
    final bool canShareIcs = decision.canWrite ||
        context.read<ChatBloc>().state.chat!.defaultTransport.isEmail;
    if (!canShareIcs) {
      _showSnackbar(_calendarFragmentShareDeniedMessage);
      return _CalendarTaskShare(
        task: null,
        text: shareText,
      );
    }
    return _CalendarTaskShare(
      task: task,
      text: shareText,
    );
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
      _appendTaskShareText(
        payload.snapshot,
        shareText: share.text,
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _pendingCalendarTaskIcs = share.task;
      _pendingCalendarSeedText = share.text;
    });
    _appendTaskShareText(
      payload.snapshot,
      shareText: share.text,
    );
  }

  Future<void> _handleAvailabilityRequest(
    CalendarAvailabilityShare share,
    String? requesterJid,
  ) async {
    if (context.read<ChatBloc>().state.chat?.defaultTransport.isEmail == true) {
      _showSnackbar(_availabilityRequestEmailUnsupportedMessage);
      return;
    }
    final trimmedJid = requesterJid?.trim();
    if (trimmedJid == null || trimmedJid.isEmpty) {
      _showSnackbar(_availabilityRequestAccountMissingMessage);
      return;
    }
    final request = await showCalendarAvailabilityRequestSheet(
      context: context,
      share: share,
      requesterJid: trimmedJid,
    );
    if (!mounted || request == null) {
      return;
    }
    context.read<ChatBloc>().add(
          ChatAvailabilityMessageSent(
            message: CalendarAvailabilityMessage.request(request: request),
          ),
        );
  }

  Future<void> _handleAvailabilityAccept(
    CalendarAvailabilityRequest request, {
    required bool canAddToPersonalCalendar,
    required bool canAddToChatCalendar,
  }) async {
    if (context.read<ChatBloc>().state.chat?.defaultTransport.isEmail == true) {
      _showSnackbar(_availabilityRequestEmailUnsupportedMessage);
      return;
    }
    if (!canAddToPersonalCalendar && !canAddToChatCalendar) {
      _showSnackbar(_availabilityRequestCalendarUnavailableMessage);
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
      _showSnackbar(_availabilityRequestInvalidRangeMessage);
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
            message: CalendarAvailabilityMessage.response(response: response),
          ),
        );
  }

  void _handleAvailabilityDecline(CalendarAvailabilityRequest request) {
    if (context.read<ChatBloc>().state.chat?.defaultTransport.isEmail == true) {
      _showSnackbar(_availabilityRequestEmailUnsupportedMessage);
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
            message: CalendarAvailabilityMessage.response(response: response),
          ),
        );
  }

  void _addAvailabilityTaskToPersonalCalendar(
    _AvailabilityTaskDraft draft,
  ) {
    final storageManager = context.read<CalendarStorageManager>();
    if (!storageManager.isAuthStorageReady) {
      _showSnackbar(_availabilityRequestCalendarUnavailableMessage);
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
    if (context.read<ChatBloc>().state.chat == null ||
        !context.read<ChatBloc>().state.chat!.supportsChatCalendar) {
      _showSnackbar(_availabilityRequestChatCalendarUnavailableMessage);
      return;
    }
    final coordinator = _maybeReadChatCalendarCoordinator(context);
    if (coordinator == null) {
      _showSnackbar(_availabilityRequestChatCalendarUnavailableMessage);
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
      _showSnackbar(_availabilityRequestChatCalendarUnavailableMessage);
    }
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
        ? _availabilityRequestTaskTitleFallback
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
    final suffix =
        chatJid() == null || chatJid()!.isEmpty ? 'unknown' : chatJid()!;
    return '$_chatScrollStoragePrefix$suffix';
  }

  double _restoreScrollOffset({String? key}) {
    final storageKey = key ?? _scrollStorageKey;
    final cached = _scrollOffsetCache[storageKey];
    if (cached != null) return cached;
    final bucket = PageStorage.maybeOf(context);
    if (bucket == null) return 0;
    final restored = bucket.readState(
      context,
      identifier: storageKey,
    );
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
      bucket.writeState(
        context,
        offset,
        identifier: storageKey,
      );
    }
  }

  void _handleScrollChanged() => _persistScrollOffset();

  void _restoreScrollOffsetForCurrentChat() {
    final target = _restoreScrollOffset();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (!position.hasPixels) return;
      final maxExtent = position.maxScrollExtent;
      final clamped = target.clamp(0.0, math.max(0.0, maxExtent)).toDouble();
      if (position.pixels != clamped) {
        _scrollController.jumpTo(clamped);
      }
    });
  }

  String? _nickFromSender(String senderJid) {
    final slashIndex = senderJid.indexOf('/');
    if (slashIndex == -1 || slashIndex + 1 >= senderJid.length) {
      return null;
    }
    final nick = senderJid.substring(slashIndex + 1).trim();
    return nick.isEmpty ? null : nick;
  }

  String? _bareJid(String? jid) {
    if (jid == null || jid.isEmpty) return null;
    try {
      return mox.JID.fromString(jid).toBare().toString();
    } on Exception {
      return jid;
    }
  }

  String? _normalizeBareJid(String? jid) {
    final bare = _bareJid(jid)?.trim();
    if (bare == null || bare.isEmpty) return null;
    return bare.toLowerCase();
  }

  String? _normalizeOccupantId(String? jid) {
    final trimmed = jid?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    try {
      final parsed = mox.JID.fromString(trimmed);
      final bare = parsed.toBare().toString().toLowerCase();
      final resource = parsed.resource.trim();
      if (resource.isEmpty) {
        return bare;
      }
      return '$bare$_jidResourceSeparator${resource.toLowerCase()}';
    } on Exception {
      return trimmed.toLowerCase();
    }
  }

  bool _isMucOccupantSender({
    required String senderJid,
    required String? chatJid,
  }) {
    final senderBare = _normalizeBareJid(senderJid);
    final chatBare = _normalizeBareJid(chatJid);
    if (senderBare == null || chatBare == null) {
      return false;
    }
    final String? nick = _nickFromSender(senderJid);
    if (nick == null) {
      return false;
    }
    return senderBare == chatBare;
  }

  Occupant? _resolveOccupantForSender({
    required String senderJid,
    required RoomState? roomState,
  }) {
    if (roomState == null) {
      return null;
    }
    final Occupant? direct = roomState.occupants[senderJid];
    if (direct != null) {
      return direct;
    }
    final String? nick = _nickFromSender(senderJid);
    if (nick == null) {
      return null;
    }
    for (final occupant in roomState.occupants.values) {
      if (occupant.nick == nick) {
        return occupant;
      }
    }
    return null;
  }

  bool _availabilitySenderMatchesClaim({
    required String senderJid,
    required String? chatJid,
    required String claimedJid,
    required RoomState? roomState,
  }) {
    final String trimmedClaimed = claimedJid.trim();
    if (trimmedClaimed.isEmpty) {
      return false;
    }
    final bool isMucSender = _isMucOccupantSender(
      senderJid: senderJid,
      chatJid: chatJid,
    );
    if (!isMucSender) {
      return _normalizeBareJid(senderJid) == _normalizeBareJid(trimmedClaimed);
    }
    final String? normalizedSender = _normalizeOccupantId(senderJid);
    final String? normalizedClaimed = _normalizeOccupantId(trimmedClaimed);
    if (normalizedSender != null && normalizedSender == normalizedClaimed) {
      return true;
    }
    final Occupant? occupant = _resolveOccupantForSender(
      senderJid: senderJid,
      roomState: roomState,
    );
    final String? realJid = occupant?.realJid;
    if (realJid == null) {
      return false;
    }
    return _normalizeBareJid(realJid) == _normalizeBareJid(trimmedClaimed);
  }

  String? _availabilityActorId({
    required chat_models.Chat? chat,
    required String? currentUserId,
    required RoomState? roomState,
  }) {
    final String? trimmedCurrent = currentUserId?.trim();
    if (chat?.type != ChatType.groupChat) {
      return trimmedCurrent?.isEmpty == true ? null : trimmedCurrent;
    }
    final String? occupantId = roomState?.myOccupantId?.trim();
    if (occupantId != null && occupantId.isNotEmpty) {
      return occupantId;
    }
    return null;
  }

  CalendarAvailabilityMessage? _validatedAvailabilityMessage({
    required Message message,
    required RoomState? roomState,
    required Map<String, String> shareOwnersById,
    required CalendarAvailabilityShareCoordinator? availabilityCoordinator,
  }) {
    final CalendarAvailabilityMessage? raw =
        message.calendarAvailabilityMessage;
    if (raw == null) {
      return null;
    }
    final String senderJid = message.senderJid;
    final String chatJid = message.chatJid;
    final bool isValid = raw.map(
      share: (value) => _availabilitySenderMatchesClaim(
        senderJid: senderJid,
        chatJid: chatJid,
        claimedJid: value.share.overlay.owner,
        roomState: roomState,
      ),
      request: (value) {
        final CalendarAvailabilityRequest request = value.request;
        final bool senderMatches = _availabilitySenderMatchesClaim(
          senderJid: senderJid,
          chatJid: chatJid,
          claimedJid: request.requesterJid,
          roomState: roomState,
        );
        if (!senderMatches) {
          return false;
        }
        final String? claimedOwner = request.ownerJid?.trim();
        if (claimedOwner == null || claimedOwner.isEmpty) {
          return true;
        }
        final String? knownOwner = shareOwnersById[request.shareId] ??
            availabilityCoordinator?.ownerJidForShare(request.shareId);
        if (knownOwner == null || knownOwner.trim().isEmpty) {
          return true;
        }
        return _availabilitySenderMatchesClaim(
          senderJid: claimedOwner,
          chatJid: chatJid,
          claimedJid: knownOwner,
          roomState: roomState,
        );
      },
      response: (value) {
        final CalendarAvailabilityResponse response = value.response;
        final String? ownerJid = shareOwnersById[response.shareId] ??
            availabilityCoordinator?.ownerJidForShare(response.shareId);
        if (ownerJid == null || ownerJid.trim().isEmpty) {
          return true;
        }
        return _availabilitySenderMatchesClaim(
          senderJid: senderJid,
          chatJid: chatJid,
          claimedJid: ownerJid,
          roomState: roomState,
        );
      },
    );
    return isValid ? raw : null;
  }

  bool _isSameOccupantId(String? first, String? second) {
    final normalizedFirst = _normalizeOccupantId(first);
    final normalizedSecond = _normalizeOccupantId(second);
    if (normalizedFirst == null || normalizedSecond == null) {
      return false;
    }
    return normalizedFirst == normalizedSecond;
  }

  bool _isQuotedMessageFromSelf({
    required Message quotedMessage,
    required bool isGroupChat,
    required String? myOccupantId,
    required String? currentUserId,
  }) {
    if (isGroupChat && myOccupantId != null) {
      if (_isSameOccupantId(quotedMessage.senderJid, myOccupantId)) {
        return true;
      }
      final quotedOccupantId = quotedMessage.occupantID;
      if (quotedOccupantId != null && quotedOccupantId.isNotEmpty) {
        return _isSameOccupantId(quotedOccupantId, myOccupantId);
      }
    }
    return _bareJid(quotedMessage.senderJid) == _bareJid(currentUserId);
  }

  void _toggleSettingsPanel() {
    if (!mounted) return;
    if (_chatRoute.isSettings) {
      _setChatRoute(_ChatRoute.main);
      return;
    }
    _setChatRoute(_ChatRoute.settings);
  }

  void _setViewFilter(MessageTimelineFilter filter) {
    context.read<ChatBloc>().add(ChatViewFilterChanged(filter: filter));
  }

  void _toggleNotifications(bool enable) {
    context.read<ChatBloc>().add(ChatMuted(!enable));
  }

  void _showMembers() {
    final navigator = Navigator.of(context);
    final locate = context.read;
    final screenWidth = MediaQuery.of(context).size.width;
    const drawerMaxWidth = 420.0;
    const drawerWidthFraction = 0.9;
    final drawerWidth =
        math.min(screenWidth * drawerWidthFraction, drawerMaxWidth);
    showGeneralDialog(
      context: context,
      useRootNavigator: false,
      barrierDismissible: true,
      barrierLabel: context.l10n.chatRoomMembers,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: baseAnimationDuration,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: drawerWidth,
            child: Material(
              color: context.colorScheme.background,
              elevation: 12,
              child: MultiBlocProvider(
                providers: [
                  BlocProvider.value(value: locate<ChatBloc>()),
                  BlocProvider.value(value: locate<RosterCubit>()),
                ],
                child: Builder(
                  builder: (dialogContext) => _RoomMembersDrawerContent(
                    onInvite: (jid) =>
                        locate<ChatBloc>().add(ChatInviteRequested(jid)),
                    onAction: (occupantId, action) => locate<ChatBloc>().add(
                      ChatModerationActionRequested(
                        occupantId: occupantId,
                        action: action,
                      ),
                    ),
                    onChangeNickname: (nick) => locate<ChatBloc>()
                        .add(ChatNicknameChangeRequested(nick)),
                    onLeaveRoom: () =>
                        locate<ChatBloc>().add(const ChatLeaveRoomRequested()),
                    onClose: navigator.pop,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _promptContactRename() async {
    if (context.read<ChatBloc>().state.chat == null ||
        context.read<ChatBloc>().state.chat?.type != ChatType.chat) {
      return;
    }
    final l10n = context.l10n;
    final result = await showContactRenameDialog(
      context: context,
      initialValue: context.read<ChatBloc>().state.chat!.displayName,
    );
    if (!mounted || result == null) return;
    context.read<ChatBloc>().add(
          ChatContactRenameRequested(
            result,
            successMessage: l10n.chatContactRenameSuccess,
            failureMessage: l10n.chatContactRenameFailure,
          ),
        );
  }

  Future<void> _handleSpamToggle({required bool sendToSpam}) async {
    if (context.read<ChatBloc>().state.chat == null ||
        context.read<ChatBloc>().state.chat?.jid == null) {
      return;
    }
    final xmppService = context.read<XmppService>();
    final l10n = context.l10n;
    try {
      await xmppService.setSpamStatus(
        jid: context.read<ChatBloc>().state.chat!.jid,
        spam: sendToSpam,
      );
    } on Exception {
      if (mounted) {
        _showSnackbar(l10n.chatSpamUpdateFailed);
      }
      return;
    }
    if (!mounted) return;
    final toastMessage = sendToSpam
        ? l10n.chatSpamSent(context.read<ChatBloc>().state.chat!.displayName)
        : l10n.chatSpamRestored(
            context.read<ChatBloc>().state.chat!.displayName,
          );
    ShadToaster.maybeOf(context)?.show(
      FeedbackToast.info(
        title: sendToSpam
            ? l10n.chatSpamReportedTitle
            : l10n.chatSpamRestoredTitle,
        message: toastMessage,
      ),
    );
  }

  Future<void> _handleAddContact() async {
    if (context.read<ChatBloc>().state.chat == null) return;
    if (context.read<ChatBloc>().state.chat!.remoteJid.trim().isEmpty) {
      return;
    }
    final l10n = context.l10n;
    final showToast = ShadToaster.maybeOf(context)?.show;
    final rosterTitle = context
                .read<ChatBloc>()
                .state
                .chat!
                .contactDisplayName
                ?.trim()
                .isNotEmpty ==
            true
        ? context.read<ChatBloc>().state.chat!.contactDisplayName!.trim()
        : context.read<ChatBloc>().state.chat!.title;
    try {
      if (context.read<ChatBloc>().state.chat!.isEmailBacked) {
        EmailService? emailService;
        try {
          emailService = RepositoryProvider.of<EmailService>(
            context,
            listen: false,
          );
        } on Exception {
          emailService = null;
        }
        if (emailService == null) return;
        await emailService.ensureChatForAddress(
          address: context.read<ChatBloc>().state.chat!.remoteJid.trim(),
          displayName: rosterTitle,
        );
      } else {
        await context.read<XmppService>().addToRoster(
              jid: context.read<ChatBloc>().state.chat!.remoteJid.trim(),
              title: rosterTitle.isNotEmpty ? rosterTitle : null,
            );
      }
    } on Exception {
      if (!mounted) return;
      showToast?.call(
        FeedbackToast.error(
          title: l10n.rosterAddTitle,
        ),
      );
      return;
    }
    if (!mounted) return;
    showToast?.call(
      FeedbackToast.success(
        title: l10n.rosterAddTitle,
      ),
    );
  }

  void _handleSubjectChanged() {
    final text = _subjectController.text;
    if (_lastSubjectValue == text) {
      return;
    }
    _lastSubjectValue = text;
    context.read<ChatBloc>().add(ChatSubjectChanged(text));
  }

  void _hydrateAnimatedMessages(List<Message> messages) {
    final openedAt = _chatOpenedAt;
    _animatedMessageIds
      ..clear()
      ..addAll(
        messages
            .where(
              (message) =>
                  message.timestamp == null ||
                  !message.timestamp!.isAfter(openedAt),
            )
            .map((message) => message.stanzaID)
            .whereType<String>()
            .where((id) => id.isNotEmpty),
      );
    _hydratedAnimatedMessages = true;
  }

  bool _shouldAnimateMessage(Message message) {
    final messageId = message.stanzaID;
    if (messageId.isEmpty ||
        messageId == _selectionSpacerMessageId ||
        messageId == _emptyStateMessageId) {
      return false;
    }
    final timestamp = message.timestamp;
    if (timestamp == null || !timestamp.isAfter(_chatOpenedAt)) {
      _animatedMessageIds.add(messageId);
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

  _FileMetadataStreamEntry _metadataEntryFor(String id) {
    return _fileMetadataStreamEntries.putIfAbsent(
      id,
      () {
        final entry = _FileMetadataStreamEntry();
        entry.attach(context.read<XmppService>().fileMetadataStream(id));
        return entry;
      },
    );
  }

  Stream<FileMetadataData?> _metadataStreamFor(String id) {
    return _metadataEntryFor(id).stream;
  }

  FileMetadataData? _metadataInitialFor(String id) {
    return _metadataEntryFor(id).latestOrNull;
  }

  bool _isEmailOnlyAddress(String? value) {
    if (value == null) return false;
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    if (!normalized.contains('@')) {
      return false;
    }
    return !_axiDomainPattern.hasMatch(normalized);
  }

  bool _hasEmailAttachmentTarget({
    required chat_models.Chat chat,
    required List<ComposerRecipient> recipients,
  }) {
    if (chat.defaultTransport.isEmail) {
      return true;
    }
    for (final recipient in recipients) {
      final targetChat = recipient.target.chat;
      if (targetChat != null && targetChat.defaultTransport.isEmail) {
        return true;
      }
      if (_isEmailOnlyAddress(recipient.target.address)) {
        return true;
      }
    }
    return false;
  }

  List<BlocklistEntry> _resolveBlocklistEntries() {
    final List<BlocklistEntry>? cachedEntries =
        switch (context.watch<BlocklistCubit?>()?.state) {
      BlocklistAvailable state => state.items ??
          context.watch<BlocklistCubit?>()?[blocklistItemsCacheKey]
              as List<BlocklistEntry>?,
      _ => context.watch<BlocklistCubit?>()?[blocklistItemsCacheKey]
          as List<BlocklistEntry>?,
    };
    return cachedEntries ?? _emptyBlocklistEntries;
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
    final transport = chat.defaultTransport;
    if (transport.isEmail) {
      final String? address = chat.emailAddress?.trim();
      final String candidate =
          address?.isNotEmpty == true ? address! : chat.remoteJid.trim();
      if (candidate.isEmpty) {
        return null;
      }
      final String normalizedCandidate = candidate.toLowerCase();
      for (final entry in entries) {
        if (!entry.transport.isEmail) {
          continue;
        }
        if (entry.address.trim().toLowerCase() == normalizedCandidate) {
          return entry;
        }
      }
      return null;
    }
    final String? chatBareJid = _normalizeBareJid(chat.remoteJid);
    if (chatBareJid == null || chatBareJid.isEmpty) {
      return null;
    }
    for (final entry in entries) {
      if (!entry.transport.isXmpp) {
        continue;
      }
      final String? entryBareJid = _normalizeBareJid(entry.address);
      if (entryBareJid != null && entryBareJid == chatBareJid) {
        return entry;
      }
    }
    return null;
  }

  String? _resolveChatBlockAddress({required chat_models.Chat chat}) {
    if (chat.defaultTransport.isEmail) {
      final String? address = chat.emailAddress?.trim();
      final String candidate =
          address?.isNotEmpty == true ? address! : chat.remoteJid.trim();
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
    final resolvedChat = chat;
    if (resolvedChat == null) return false;
    return resolvedChat.attachmentAutoDownload.isAllowed;
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
    final displaySender =
        senderEmail?.isNotEmpty == true ? senderEmail! : senderJid;
    final canTrustChat = !isSelf && context.read<ChatBloc>().state.chat != null;
    final showAutoTrustToggle = canTrustChat;
    final autoTrustLabel = l10n.attachmentGalleryChatTrustLabel;
    final autoTrustHint = l10n.attachmentGalleryChatTrustHint;
    final decision = await showShadDialog<AttachmentApprovalDecision>(
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

    final emailService = RepositoryProvider.of<EmailService?>(context);
    if (decision.alwaysAllow && canTrustChat) {
      context
          .read<ChatBloc>()
          .add(const ChatAttachmentAutoDownloadToggled(true));
    }
    if (isEmailChat) {
      if (emailService != null) {
        await emailService.downloadFullMessage(message);
      }
    }

    if (mounted) {
      setState(() {
        _oneTimeAllowedAttachmentStanzaIds.add(stanzaId.trim());
      });
    }
  }

  Future<void> _handleLinkTap(String url) async {
    if (!mounted) return;
    final l10n = context.l10n;
    final report = assessLinkSafety(
      raw: url,
      kind: LinkSafetyKind.message,
    );
    if (report == null || !report.isSafe) {
      _showSnackbar(l10n.chatInvalidLink(url.trim()));
      return;
    }
    final hostLabel = formatLinkSchemeHostLabel(report);
    final baseMessage = report.needsWarning
        ? l10n.chatOpenLinkWarningMessage(
            report.displayUri,
            hostLabel,
          )
        : l10n.chatOpenLinkMessage(
            report.displayUri,
            hostLabel,
          );
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
      await Clipboard.setData(
        ClipboardData(text: report.displayUri),
      );
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
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Future<void> _handleSendMessage() async {
    final rawText = _textController.text.trim();
    final seedText = _pendingCalendarSeedText;
    final String resolvedText =
        rawText.isNotEmpty ? rawText : (seedText ?? _emptyText);
    final pendingAttachments =
        context.read<ChatBloc>().state.pendingAttachments;
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
    final hasSubject = _subjectController.text.trim().isNotEmpty;
    final canSend = !hasPreparingAttachments &&
        (resolvedText.isNotEmpty || hasQueuedAttachments || hasSubject);
    if (!canSend) return;
    final confirmed = await _confirmMediaMetadataIfNeeded(queuedAttachments);
    if (!confirmed || !mounted) return;
    context.read<ChatBloc>().add(
          ChatMessageSent(
            text: resolvedText,
            calendarTaskIcs: _pendingCalendarTaskIcs,
            calendarTaskIcsReadOnly: _calendarTaskIcsReadOnlyFallback,
          ),
        );
    if (resolvedText.isNotEmpty) {
      _textController.clear();
    }
    if (_pendingCalendarTaskIcs != null || _pendingCalendarSeedText != null) {
      if (!mounted) return;
      setState(() {
        _pendingCalendarTaskIcs = null;
        _pendingCalendarSeedText = null;
      });
    }
    _focusNode.requestFocus();
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
    final action = await showAdaptiveBottomSheet<String>(
      context: context,
      showDragHandle: true,
      dialogMaxWidth: 420,
      surfacePadding: EdgeInsets.zero,
      builder: (sheetContext) {
        final colors = sheetContext.colorScheme;
        return AxiSheetScaffold.scroll(
          header: AxiSheetHeader(
            title: Text(sheetContext.l10n.commonActions),
            onClose: () => Navigator.of(sheetContext).maybePop(),
          ),
          children: [
            ListTile(
              leading: Icon(LucideIcons.save, color: colors.primary),
              title: Text(sheetContext.l10n.chatSaveAsDraft),
              onTap: () => Navigator.of(sheetContext).pop('save'),
            ),
          ],
        );
      },
    );
    if (!mounted || action != 'save') return;
    await _saveComposerAsDraft();
  }

  Future<void> _saveComposerAsDraft() async {
    final l10n = context.l10n;
    if (context.read<ChatBloc>().state.chat == null ||
        context.read<DraftCubit?>() == null) {
      _showSnackbar(l10n.chatDraftUnavailable);
      return;
    }
    final body = _textController.text;
    final subject = _subjectController.text;
    final trimmedBody = body.trim();
    final trimmedSubject = subject.trim();
    final attachments = context
        .read<ChatBloc>()
        .state
        .pendingAttachments
        .map((pending) => pending.attachment)
        .toList();
    final hasContent = trimmedBody.isNotEmpty ||
        trimmedSubject.isNotEmpty ||
        attachments.isNotEmpty;
    if (!hasContent) {
      _showSnackbar(l10n.chatDraftMissingContent);
      return;
    }
    final recipients = _resolveDraftRecipients(
      chat: context.read<ChatBloc>().state.chat!,
      recipients: context.read<ChatBloc>().state.recipients,
    );
    try {
      await context.read<DraftCubit>().saveDraft(
            id: null,
            jids: recipients,
            body: body,
            subject: trimmedSubject.isEmpty ? null : subject,
            attachments: attachments,
          );
      if (!mounted) return;
      _showSnackbar(l10n.chatDraftSaved);
    } catch (_) {
      if (!mounted) return;
      _showSnackbar(l10n.chatDraftSaveFailed);
    }
  }

  Future<void> _stashComposerDraftIfDirty() async {
    if (context.read<ChatBloc>().state.chat == null ||
        context.read<DraftCubit?>() == null) {
      return;
    }
    final body = _textController.text;
    final subject = _subjectController.text;
    final trimmedBody = body.trim();
    final trimmedSubject = subject.trim();
    final attachments = context
        .read<ChatBloc>()
        .state
        .pendingAttachments
        .map((pending) => pending.attachment)
        .toList();
    final recipients = _resolveDraftRecipients(
      chat: context.read<ChatBloc>().state.chat!,
      recipients: context.read<ChatBloc>().state.recipients,
    );
    final hasRecipientChanges = recipients.length > 1 ||
        (recipients.isNotEmpty &&
            recipients.first != context.read<ChatBloc>().state.chat!.jid);
    final hasContent = trimmedBody.isNotEmpty ||
        trimmedSubject.isNotEmpty ||
        attachments.isNotEmpty ||
        hasRecipientChanges;
    if (!hasContent) {
      return;
    }
    try {
      await context.read<DraftCubit>().saveDraft(
            id: null,
            jids: recipients,
            body: body,
            subject: trimmedSubject.isEmpty ? null : subject,
            attachments: attachments,
          );
    } catch (_) {
      // Ignore best-effort auto-save failures.
    }
  }

  List<String> _resolveDraftRecipients({
    required chat_models.Chat chat,
    required List<ComposerRecipient> recipients,
  }) {
    if (recipients.isEmpty) {
      return [chat.jid];
    }
    final resolved = <String>{};
    for (final recipient in recipients) {
      if (!recipient.included) continue;
      final chatJid = recipient.target.chat?.jid;
      final address = recipient.target.address;
      if (chatJid != null && chatJid.isNotEmpty) {
        resolved.add(chatJid);
      } else if (address != null && address.isNotEmpty) {
        resolved.add(address);
      }
    }
    if (resolved.isEmpty) {
      return [chat.jid];
    }
    return resolved.toList();
  }

  Future<void> _handleEditMessage(Message message) async {
    await _stashComposerDraftIfDirty();
    if (!mounted) return;
    context.read<ChatBloc>().add(ChatMessageEditRequested(message));
  }

  List<ChatComposerAccessory> _composerAccessories({
    required bool canSend,
    required bool attachmentsEnabled,
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
              onPressed: _handleAttachmentPressed,
            ),
          ),
        ),
      ),
      ChatComposerAccessory.trailing(
        child: FocusTraversalOrder(
          order: const NumericFocusOrder(4),
          child: _SendMessageAccessory(
            enabled: canSend,
            onPressed: _handleSendMessage,
            onLongPress: widget.readOnly ? null : _handleSendButtonLongPress,
          ),
        ),
      ),
    ];
    return accessories;
  }

  Future<void> _handleAttachmentPressed() async {
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
      final attachments = <EmailAttachment>[];
      var hasInvalidPath = false;
      for (final file in result.files) {
        final path = file.path;
        if (path == null) {
          hasInvalidPath = true;
          continue;
        }
        final String fileName =
            file.name.isNotEmpty ? file.name : path.split('/').last;
        final String? resolvedMimeType = await resolveMimeTypeFromPath(
          path: path,
          fileName: fileName,
        );
        attachments.add(
          EmailAttachment(
            path: path,
            fileName: fileName,
            sizeBytes: file.size > 0 ? file.size : 0,
            mimeType: resolvedMimeType,
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
      for (final attachment in attachments) {
        context.read<ChatBloc>().add(ChatAttachmentPicked(attachment));
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

  void _handlePendingAttachmentPressed(PendingAttachment pending) {
    if (!mounted) return;
    final commandSurface = resolveCommandSurface(context);
    if (commandSurface == CommandSurface.menu) {
      if (pending.attachment.isImage) {
        _showAttachmentPreview(pending);
      }
      return;
    }
    if (pending.attachment.isImage) {
      _showAttachmentPreview(pending);
    } else {
      _showPendingAttachmentActions(pending);
    }
  }

  void _handlePendingAttachmentLongPressed(PendingAttachment pending) {
    if (!mounted) return;
    _showPendingAttachmentActions(pending);
  }

  List<Widget> _pendingAttachmentMenuItems(PendingAttachment pending) {
    final l10n = context.l10n;
    final items = <Widget>[];
    if (pending.attachment.isImage) {
      items.add(
        ShadContextMenuItem(
          leading: const Icon(LucideIcons.eye),
          onPressed: () => _showAttachmentPreview(pending),
          child: Text(l10n.chatAttachmentView),
        ),
      );
    }
    if (pending.status == PendingAttachmentStatus.failed) {
      items.add(
        ShadContextMenuItem(
          leading: const Icon(LucideIcons.refreshCw),
          onPressed: () => context
              .read<ChatBloc>()
              .add(ChatAttachmentRetryRequested(pending.id)),
          child: Text(l10n.chatAttachmentRetry),
        ),
      );
    }
    items.add(
      ShadContextMenuItem(
        leading: const Icon(LucideIcons.trash),
        onPressed: () => context
            .read<ChatBloc>()
            .add(ChatPendingAttachmentRemoved(pending.id)),
        child: Text(l10n.chatAttachmentRemove),
      ),
    );
    return items;
  }

  Future<void> _showAttachmentPreview(PendingAttachment pending) async {
    if (!mounted) return;
    final l10n = context.l10n;
    final attachment = pending.attachment;
    final file = File(attachment.path);
    if (!await file.exists()) {
      _showSnackbar(l10n.chatAttachmentInaccessible);
      return;
    }
    final FileTypeReport report = await inspectFileType(
      file: file,
      declaredMimeType: attachment.mimeType,
      fileName: attachment.fileName,
    );
    if (!mounted) return;
    final bool useDeclaredFallback = !report.hasReliableDetection;
    final bool isImage = report.isDetectedImage ||
        (useDeclaredFallback && report.isDeclaredImage);
    if (!isImage) {
      _showSnackbar(l10n.chatAttachmentUnavailable);
      return;
    }
    final intrinsicSize = await _resolveAttachmentSize(attachment);
    if (!mounted) return;
    await showShadDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _AttachmentPreviewDialog(
          attachment: attachment,
          intrinsicSize: intrinsicSize,
          l10n: l10n,
        );
      },
    );
  }

  Future<Size?> _resolveAttachmentSize(EmailAttachment attachment) async {
    final width = attachment.width;
    final height = attachment.height;
    if (width != null && height != null && width > 0 && height > 0) {
      return Size(width.toDouble(), height.toDouble());
    }
    final file = File(attachment.path);
    if (!await file.exists()) return null;
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      codec.dispose();
      try {
        return Size(
          image.width.toDouble(),
          image.height.toDouble(),
        );
      } finally {
        image.dispose();
      }
    } on Exception {
      return null;
    }
  }

  Future<void> _showPendingAttachmentActions(PendingAttachment pending) async {
    if (!mounted) return;
    final l10n = context.l10n;
    final locate = context.read;
    await showAdaptiveBottomSheet<void>(
      context: context,
      showDragHandle: true,
      dialogMaxWidth: 520,
      surfacePadding: EdgeInsets.zero,
      builder: (sheetContext) {
        final attachment = pending.attachment;
        final sizeLabel = formatBytes(attachment.sizeBytes);
        final colors = Theme.of(sheetContext).colorScheme;
        return BlocProvider.value(
          value: locate<ChatBloc>(),
          child: Builder(
            builder: (context) {
              return AxiSheetScaffold.scroll(
                header: AxiSheetHeader(
                  title: Text(l10n.chatAttachmentTooltip),
                  onClose: () => Navigator.of(sheetContext).maybePop(),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                ),
                bodyPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
                      leading: const Icon(LucideIcons.eye),
                      title: Text(l10n.chatAttachmentView),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _showAttachmentPreview(pending);
                      },
                    ),
                  if (pending.status == PendingAttachmentStatus.failed)
                    ListTile(
                      leading: const Icon(LucideIcons.refreshCw),
                      title: Text(l10n.chatAttachmentRetry),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        context.read<ChatBloc>().add(
                              ChatAttachmentRetryRequested(pending.id),
                            );
                      },
                    ),
                  ListTile(
                    leading: const Icon(LucideIcons.trash),
                    title: Text(l10n.chatAttachmentRemove),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      context.read<ChatBloc>().add(
                            ChatPendingAttachmentRemoved(pending.id),
                          );
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ignore: unused_element
  void _maybeDismissSelection(Offset globalPosition) {
    final selectedId = _selectedMessageId;
    if (selectedId == null) return;
    final hitRegions = <Rect>[];
    void collect(GlobalKey? key, {double padding = 12.0}) {
      final rect = _globalRectForKey(key);
      if (rect != null) {
        hitRegions.add(rect.inflate(padding));
      }
    }

    final bubbleRect = _bubbleRegionRegistry.rectFor(selectedId);
    if (bubbleRect != null) {
      hitRegions.add(bubbleRect.inflate(12));
    }
    for (final key in _selectionActionButtonKeys) {
      collect(key, padding: 0);
    }
    collect(_reactionManagerKey, padding: 4);

    if (hitRegions.isEmpty) {
      _clearMessageSelection();
      return;
    }
    final tappedInside =
        hitRegions.any((rect) => rect.contains(globalPosition));
    if (!tappedInside) {
      _clearMessageSelection();
    }
  }

  Rect? _globalRectForKey(GlobalKey? key) {
    final context = key?.currentContext;
    if (context == null) return null;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) return null;
    final origin = renderBox.localToGlobal(Offset.zero);
    return origin & renderBox.size;
  }

  void _toggleMessageSelection(Message message) {
    if (widget.readOnly) return;
    final messageId = message.stanzaID;
    if (_multiSelectActive) {
      _toggleMultiSelectMessage(message);
      return;
    }
    if (_selectedMessageId == messageId) {
      _clearMessageSelection();
    } else {
      _selectMessage(messageId);
    }
  }

  void _clearMessageSelection() {
    if (_selectedMessageId == null) return;
    unawaited(_reboundSelectionScroll());
    setState(() {
      _selectedMessageId = null;
      _activeSelectionExtrasKey = null;
      _reactionManagerKey = null;
      _selectionSpacerHeight = 0;
      _selectionActionButtonKeys.clear();
      _selectionControlsHeight = 0;
      _selectionControlsMeasurementPending = false;
      _selectionAutoscrollActive = false;
      _selectionAutoscrollScheduled = false;
      _selectionAutoscrollInProgress = false;
      _selectionAutoscrollAccumulated = 0.0;
    });
  }

  void _startMultiSelect(Message message) {
    final messageId = message.stanzaID;
    if (widget.readOnly) return;
    if (_multiSelectedMessageIds.length == 1 &&
        _multiSelectedMessageIds.contains(messageId) &&
        _selectedMessageId == null) {
      return;
    }
    _clearMessageSelection();
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

  void _clearMultiSelection() {
    if (_multiSelectedMessageIds.isEmpty) return;
    setState(() {
      _multiSelectedMessageIds.clear();
      _selectedMessageSnapshots.clear();
    });
  }

  void _clearAllSelections() {
    _clearMessageSelection();
    _clearMultiSelection();
  }

  void _pruneMessageSelection(Set<String> availableIds) {
    if (!_multiSelectActive) return;
    final missing = _multiSelectedMessageIds
        .where(
          (id) =>
              !availableIds.contains(id) &&
              !_selectedMessageSnapshots.containsKey(id),
        )
        .toList();
    if (missing.isEmpty) return;
    final missingSet = missing.toSet();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _multiSelectedMessageIds.removeWhere(missingSet.contains);
      });
    });
  }

  List<Message> _collectSelectedMessages(List<Message> orderedMessages) {
    if (_multiSelectedMessageIds.isEmpty) return const [];
    final selected = <Message>[];
    final resolvedIds = <String>{};
    for (final message in orderedMessages) {
      final id = message.stanzaID;
      if (_multiSelectedMessageIds.contains(id)) {
        selected.add(message);
        resolvedIds.add(id);
        _selectedMessageSnapshots[id] = message;
      }
    }
    if (selected.length == _multiSelectedMessageIds.length) {
      return selected;
    }
    final missingIds = <String>[];
    for (final id in _multiSelectedMessageIds) {
      if (resolvedIds.contains(id)) continue;
      final snapshot = _selectedMessageSnapshots[id];
      if (snapshot != null) {
        selected.add(snapshot);
      } else {
        missingIds.add(id);
      }
    }
    if (missingIds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _multiSelectedMessageIds.removeWhere(missingIds.contains);
        });
      });
    }
    return selected;
  }

  void _selectMessage(String messageId) {
    if (_selectedMessageId == messageId) return;
    if (_scrollController.hasClients) {
      _updateSelectionSpacerBase(_scrollController.position.viewportDimension);
    }
    _selectionAutoscrollAccumulated = 0.0;
    setState(() {
      _selectedMessageId = messageId;
      _activeSelectionExtrasKey = null;
      _reactionManagerKey = null;
      final baseHeadroom =
          _selectionSpacerBaseHeight > _selectionHeadroomTolerance
              ? _selectionSpacerBaseHeight
              : _selectionExtrasViewportGap;
      _selectionSpacerHeight =
          baseHeadroom > _selectionHeadroomTolerance ? baseHeadroom : 0.0;
      _selectionActionButtonKeys.clear();
      _selectionAutoscrollActive = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _primeSelectionHeadroomIfNeeded();
      await _scrollSelectedMessageIntoView(messageId);
      _scheduleSelectionAutoscroll();
    });
  }

  Future<void> _scrollSelectedMessageIntoView(String messageId) async {
    final key = _messageKeys[messageId];
    final context = key?.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      alignment: 0.35,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      duration: _bubbleFocusDuration,
      curve: _bubbleFocusCurve,
    );
  }

  Future<void> _scrollSelectionExtrasIntoView() async {
    if (_selectionAutoscrollInProgress) return;
    _selectionAutoscrollInProgress = true;
    try {
      if (!_selectionAutoscrollActive || _selectedMessageId == null) return;
      await _waitForPostFrame();
      if (!_selectionAutoscrollActive ||
          _selectedMessageId == null ||
          !_scrollController.hasClients) {
        return;
      }
      final initialGapDelta = _selectionGapDelta();
      if (initialGapDelta == null) return;
      if (initialGapDelta.abs() <= _selectionHeadroomTolerance) {
        _selectionAutoscrollActive = false;
        return;
      }
      var gapDelta = _selectionGapDelta();
      if (gapDelta == null) return;
      var shortfall = _scrollShortfallForGap(gapDelta);
      if (shortfall > _selectionHeadroomTolerance) {
        _extendSpacerBy(shortfall);
        await _waitForPostFrame();
        if (!_selectionAutoscrollActive ||
            _selectedMessageId == null ||
            !_scrollController.hasClients) {
          return;
        }
        gapDelta = _selectionGapDelta();
        if (gapDelta == null) return;
        shortfall = _scrollShortfallForGap(gapDelta);
        if (shortfall > _selectionHeadroomTolerance) {
          _extendSpacerBy(shortfall);
          await _waitForPostFrame();
          gapDelta = _selectionGapDelta();
          if (gapDelta == null) return;
        }
      }
      if (gapDelta.abs() <= _selectionHeadroomTolerance) {
        _selectionAutoscrollActive = false;
        _selectionAutoscrollScheduled = false;
        await _settleResidualSelectionGap();
        return;
      }
      final outcome = await _shiftSelectionBy(gapDelta);
      if (outcome != _SelectionShiftOutcome.awaitingHeadroom) {
        _selectionAutoscrollActive = false;
        _selectionAutoscrollScheduled = false;
        await _settleResidualSelectionGap();
      }
    } finally {
      _selectionAutoscrollInProgress = false;
    }
  }

  double _axisDirectionSign(AxisDirection direction) {
    switch (direction) {
      case AxisDirection.up:
      case AxisDirection.left:
        return 1.0;
      case AxisDirection.down:
      case AxisDirection.right:
        return -1.0;
    }
  }

  Future<_SelectionShiftOutcome> _shiftSelectionBy(double gapDelta) async {
    if (!_scrollController.hasClients ||
        !_selectionAutoscrollActive ||
        _selectedMessageId == null) {
      return _SelectionShiftOutcome.satisfied;
    }
    if (gapDelta.abs() <= _selectionHeadroomTolerance) {
      return _SelectionShiftOutcome.satisfied;
    }
    final position = _scrollController.position;
    final directionSign = _axisDirectionSign(position.axisDirection);
    final scrollDelta = gapDelta * directionSign;
    final start = position.pixels;
    final rawTarget = start + scrollDelta;
    final minExtent = position.minScrollExtent.toDouble();
    final maxExtent = position.maxScrollExtent.toDouble();
    if (rawTarget > maxExtent + _selectionHeadroomTolerance ||
        rawTarget < minExtent - _selectionHeadroomTolerance) {
      return _SelectionShiftOutcome.awaitingHeadroom;
    }
    final target = rawTarget.clamp(minExtent, maxExtent);
    if ((position.pixels - target).abs() < _selectionAutoscrollSlop) {
      return _SelectionShiftOutcome.satisfied;
    }
    await position.animateTo(
      target,
      duration: _bubbleFocusDuration,
      curve: _bubbleFocusCurve,
    );
    _selectionAutoscrollAccumulated += (target - start);
    return _SelectionShiftOutcome.animated;
  }

  double? _selectionGapDelta() {
    final reactionContext = _reactionManagerKey?.currentContext ??
        _activeSelectionExtrasKey?.currentContext;
    final inputContext = _focusNode.context;
    if (reactionContext == null || inputContext == null) {
      return null;
    }
    if (!(reactionContext.mounted && inputContext.mounted)) {
      return null;
    }
    final reactionBox = reactionContext.findRenderObject() as RenderBox?;
    final inputBox = inputContext.findRenderObject() as RenderBox?;
    if (reactionBox == null || inputBox == null) {
      return null;
    }
    if (!(reactionBox.attached && inputBox.attached)) {
      return null;
    }
    final reactionOrigin = reactionBox.localToGlobal(Offset.zero);
    final reactionBottom = reactionOrigin.dy + reactionBox.size.height;
    final inputOrigin = inputBox.localToGlobal(Offset.zero);
    final inputTop = inputOrigin.dy;
    final currentGap = inputTop - reactionBottom;
    final gapDelta = currentGap - _selectionExtrasViewportGap;
    if (gapDelta.abs() <= _selectionHeadroomTolerance) {
      return 0;
    }
    return gapDelta;
  }

  Future<void> _waitForPostFrame() async {
    if (!mounted) return;
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    await completer.future;
  }

  void _scheduleSelectionAutoscroll() {
    if (!_selectionAutoscrollActive ||
        !mounted ||
        _selectionAutoscrollScheduled) {
      return;
    }
    _selectionAutoscrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectionAutoscrollScheduled = false;
      if (!mounted || !_selectionAutoscrollActive) {
        return;
      }
      _scrollSelectionExtrasIntoView();
    });
  }

  double _scrollShortfallForGap(double gapDelta) {
    final position = _scrollController.position;
    final directionSign = _axisDirectionSign(position.axisDirection);
    final scrollDelta = gapDelta * directionSign;
    final rawTarget = position.pixels + scrollDelta;
    if (rawTarget > position.maxScrollExtent + _selectionHeadroomTolerance) {
      return rawTarget - position.maxScrollExtent;
    }
    if (rawTarget < position.minScrollExtent - _selectionHeadroomTolerance) {
      return position.minScrollExtent - rawTarget;
    }
    return 0;
  }

  void _extendSpacerBy(double amount) {
    final additional = math.max(amount, 0.0);
    if (additional <= _selectionHeadroomTolerance) return;
    setState(() {
      _selectionSpacerHeight =
          math.max(_selectionSpacerHeight, _selectionSpacerBaseHeight) +
              additional;
    });
  }

  Future<void> _reboundSelectionScroll() async {
    if (!_scrollController.hasClients) return;
    final accumulated = _selectionAutoscrollAccumulated;
    _selectionAutoscrollAccumulated = 0.0;
    if (accumulated.abs() < 0.5) return;
    final position = _scrollController.position;
    final target = (position.pixels - accumulated).clamp(
      position.minScrollExtent.toDouble(),
      position.maxScrollExtent.toDouble(),
    );
    if ((position.pixels - target).abs() < (_selectionAutoscrollSlop / 2)) {
      position.jumpTo(target);
      return;
    }
    await position.animateTo(
      target,
      duration: _selectionAutoscrollReboundDuration,
      curve: _selectionAutoscrollReboundCurve,
    );
  }

  Future<void> _settleResidualSelectionGap() async {
    if (!_scrollController.hasClients || _selectedMessageId == null) return;
    await _waitForPostFrame();
    final residual = _selectionGapDelta();
    if (residual == null ||
        residual.abs() <= _selectionAutoscrollSlop ||
        !_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final directionSign = _axisDirectionSign(position.axisDirection);
    final target = (position.pixels + (residual * directionSign)).clamp(
      position.minScrollExtent.toDouble(),
      position.maxScrollExtent.toDouble(),
    );
    if ((position.pixels - target).abs() < (_selectionAutoscrollSlop / 2)) {
      final delta = target - position.pixels;
      position.jumpTo(target);
      _selectionAutoscrollAccumulated += delta;
      return;
    }
    final start = position.pixels;
    await position.animateTo(
      target,
      duration: _bubbleFocusDuration ~/ 2,
      curve: _bubbleFocusCurve,
    );
    _selectionAutoscrollAccumulated += (target - start);
  }

  void _requestSelectionControlsMeasurement() {
    if (_selectionControlsMeasurementPending || !mounted) return;
    if (_selectedMessageId == null) return;
    _selectionControlsMeasurementPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectionControlsMeasurementPending = false;
      if (!mounted || _selectedMessageId == null) return;
      _captureSelectionControlsHeight();
    });
  }

  void _captureSelectionControlsHeight() {
    final extrasContext = _activeSelectionExtrasKey?.currentContext;
    if (extrasContext == null) return;
    final renderBox = extrasContext.findRenderObject() as RenderBox?;
    if (renderBox == null ||
        !renderBox.attached ||
        !renderBox.hasSize ||
        renderBox.size.isEmpty) {
      return;
    }
    final height = renderBox.size.height;
    if ((height - _selectionControlsHeight).abs() <
        _selectionHeadroomTolerance) {
      return;
    }
    setState(() {
      _selectionControlsHeight = height;
    });
    if (_scrollController.hasClients) {
      _updateSelectionSpacerBase(_scrollController.position.viewportDimension);
    }
  }

  void _captureBaseSelectionHeadroom() {
    if (!mounted) return;
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _captureBaseSelectionHeadroom();
      });
      return;
    }
    final viewportExtent = _scrollController.position.viewportDimension;
    _updateSelectionSpacerBase(viewportExtent);
  }

  void _updateSelectionSpacerBase(double viewportExtent) {
    if (viewportExtent <= _selectionHeadroomTolerance) {
      return;
    }
    final hasMeasuredControls =
        _selectionControlsHeight > _selectionHeadroomTolerance;
    final desired = math
        .max(
          _selectionExtrasViewportGap,
          hasMeasuredControls
              ? _selectionControlsHeight + _selectionExtrasViewportGap
              : _selectionExtrasViewportGap,
        )
        .clamp(0.0, viewportExtent);
    final baseChanged = (_selectionSpacerBaseHeight - desired).abs() >
        _selectionHeadroomTolerance;
    final shouldSyncSpacer = _selectedMessageId != null &&
        (_selectionSpacerHeight - desired).abs() > _selectionHeadroomTolerance;
    if (!baseChanged && !shouldSyncSpacer) {
      return;
    }
    setState(() {
      if (baseChanged) {
        _selectionSpacerBaseHeight = desired;
      }
      if (_selectedMessageId != null) {
        _selectionSpacerHeight = desired;
      }
    });
  }

  Future<void> _primeSelectionHeadroomIfNeeded() async {
    if (!_scrollController.hasClients) {
      await _waitForPostFrame();
      if (!mounted || _selectedMessageId == null) return;
      return _primeSelectionHeadroomIfNeeded();
    }
    final position = _scrollController.position;
    final viewportExtent = position.viewportDimension;
    if (viewportExtent <= _selectionHeadroomTolerance) {
      await _waitForPostFrame();
      if (!mounted || _selectedMessageId == null) return;
      return _primeSelectionHeadroomIfNeeded();
    }
    _updateSelectionSpacerBase(viewportExtent);
    await _waitForPostFrame();
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
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScrollChanged);
    _subjectFocusNode.onKeyEvent = _handleSubjectKeyEvent;
    _focusNode.onKeyEvent = _handleComposerKeyEvent;
    _textController.addListener(_typingListener);
    _subjectController.addListener(_handleSubjectChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureBaseSelectionHeadroom();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentKey = _scrollStorageKey;
    if (_lastScrollStorageKey == null) {
      _lastScrollStorageKey = currentKey;
      _restoreScrollOffsetForCurrentChat();
      _syncChatCalendarRoute();
      return;
    }
    if (_lastScrollStorageKey != currentKey) {
      _persistScrollOffset(key: _lastScrollStorageKey);
      _lastScrollStorageKey = currentKey;
      _restoreScrollOffsetForCurrentChat();
    }
    _syncChatCalendarRoute();
  }

  @override
  void dispose() {
    _persistScrollOffset(key: _lastScrollStorageKey, skipPageStorage: true);
    for (final entry in _fileMetadataStreamEntries.values) {
      entry.dispose();
    }
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
    _disposeChatCalendarBloc();
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
        final showToast = ShadToaster.maybeOf(context)?.show;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) => _maybeDismissSelection(details.globalPosition),
          child: MultiBlocListener(
            listeners: [
              BlocListener<ChatSearchCubit, ChatSearchState>(
                listenWhen: (previous, current) =>
                    previous.active != current.active,
                listener: (_, searchState) {
                  if (!mounted) return;
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
                    previous.openChatCalendar != current.openChatCalendar,
                listener: (_, chatsState) {
                  if (!mounted) return;
                  if (chatsState.openChatCalendar) {
                    if (!_chatRoute.isCalendar) {
                      _showChatCalendarRoute();
                    }
                    return;
                  }
                  if (_chatRoute.isCalendar) {
                    _returnToMainRoute();
                  }
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
                  final toastWidget = switch (toast.variant) {
                    ChatToastVariant.destructive => FeedbackToast.error(
                        title: l10n.toastWhoopsTitle,
                        message: toast.message,
                      ),
                    ChatToastVariant.warning => FeedbackToast.warning(
                        title: l10n.toastHeadsUpTitle,
                        message: toast.message,
                      ),
                    ChatToastVariant.info => FeedbackToast.success(
                        title: l10n.toastAllSetTitle,
                        message: toast.message,
                      ),
                  };
                  show(toastWidget);
                },
              ),
              BlocListener<ChatBloc, ChatState>(
                listenWhen: (previous, current) =>
                    current.emailSubjectHydrationId != 0 &&
                    previous.emailSubjectHydrationId !=
                        current.emailSubjectHydrationId,
                listener: (context, state) {
                  final subject = state.emailSubjectHydrationText ?? '';
                  _subjectController
                    ..text = subject
                    ..selection =
                        TextSelection.collapsed(offset: subject.length);
                  _lastSubjectValue = subject;
                  if (subject.isNotEmpty && !_subjectFocusNode.hasFocus) {
                    _subjectFocusNode.requestFocus();
                  }
                },
              ),
              BlocListener<ChatBloc, ChatState>(
                listenWhen: (previous, current) =>
                    previous.chat?.jid != current.chat?.jid,
                listener: (_, state) {
                  _animatedMessageIds.clear();
                  _hydratedAnimatedMessages = false;
                  _chatOpenedAt = DateTime.now();
                  if (state.messagesLoaded) {
                    _hydrateAnimatedMessages(state.items);
                  }
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
            ],
            child: BlocConsumer<ChatBloc, ChatState>(
              listenWhen: (previous, current) {
                if (current.composerHydrationId == 0) return false;
                return previous.composerHydrationId !=
                    current.composerHydrationId;
              },
              listener: (context, state) {
                final text = state.composerHydrationText ?? '';
                _textController
                  ..text = text
                  ..selection = TextSelection.collapsed(offset: text.length);
                _composerHasText = text.trim().isNotEmpty;
                if (!_focusNode.hasFocus) {
                  _focusNode.requestFocus();
                }
              },
              builder: (context, state) {
                ProfileState? profileState() =>
                    context.watch<ProfileCubit?>()?.state;
                ChatsState? chatsState() => context.watch<ChatsCubit?>()?.state;
                final readOnly = widget.readOnly;
                final emailService = RepositoryProvider.of<EmailService?>(
                  context,
                  listen: false,
                );
                final xmppService = context.read<XmppService>();
                final emailSelfJid = emailService?.selfSenderJid;
                final String? resolvedEmailSelfJid =
                    emailSelfJid.resolveDeltaPlaceholderJid();
                final xmppSelfJid = xmppService.myJid;
                final chatEntity = state.chat;
                final List<BlocklistEntry> blocklistEntries =
                    _resolveBlocklistEntries();
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
                final String? resolvedProfileJid = profileState()?.jid.trim();
                final String? selfXmppJid =
                    resolvedProfileJid?.isNotEmpty == true
                        ? resolvedProfileJid
                        : xmppSelfJid;
                final String? normalizedXmppSelfJid =
                    _normalizeBareJid(selfXmppJid);
                final String? normalizedEmailSelfJid =
                    _normalizeBareJid(resolvedEmailSelfJid);
                final String? normalizedChatJid =
                    _normalizeBareJid(chatEntity?.remoteJid);
                final bool isSelfChat = normalizedChatJid != null &&
                    ((normalizedXmppSelfJid != null &&
                            normalizedChatJid == normalizedXmppSelfJid) ||
                        (normalizedEmailSelfJid != null &&
                            normalizedChatJid == normalizedEmailSelfJid));
                final String? selfAvatarPath =
                    profileState()?.avatarPath?.trim();
                final bool hasSelfAvatarPath =
                    selfAvatarPath?.isNotEmpty == true;
                final myOccupantId = state.roomState?.myOccupantId;
                final myOccupant = myOccupantId == null
                    ? null
                    : state.roomState?.occupants[myOccupantId];
                final String? availabilityActorId = _availabilityActorId(
                  chat: chatEntity,
                  currentUserId: currentUserId,
                  roomState: state.roomState,
                );
                final shareContexts = state.shareContexts;
                final shareReplies = state.shareReplies;
                final recipients = state.recipients;
                final pendingAttachments = state.pendingAttachments;
                final canSendEmailAttachments = emailService != null &&
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
                final rosterItems = (context.watch<RosterCubit>().cache['items']
                        as List<RosterItem>?) ??
                    const <RosterItem>[];
                final rosterAvatarPathsByJid = <String, String>{};
                for (final item in rosterItems) {
                  final path = item.avatarPath?.trim();
                  if (path == null || path.isEmpty) continue;
                  rosterAvatarPathsByJid[item.jid.toLowerCase()] = path;
                }
                final chatAvatarPathsByJid = <String, String>{};
                for (final chat
                    in chatsState()?.items ?? const <chat_models.Chat>[]) {
                  final path =
                      (chat.avatarPath ?? chat.contactAvatarPath)?.trim();
                  if (path == null || path.isEmpty) continue;
                  final normalizedJid = chat.jid.trim().toLowerCase();
                  if (normalizedJid.isNotEmpty) {
                    chatAvatarPathsByJid[normalizedJid] = path;
                  }
                  final normalizedRemoteJid =
                      chat.remoteJid.trim().toLowerCase();
                  if (normalizedRemoteJid.isNotEmpty) {
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
                if (normalizedSelfJids.isNotEmpty && hasSelfAvatarPath) {
                  final resolvedSelfAvatarPath = selfAvatarPath;
                  if (resolvedSelfAvatarPath != null &&
                      resolvedSelfAvatarPath.isNotEmpty) {
                    for (final selfJid in normalizedSelfJids) {
                      rosterAvatarPathsByJid.putIfAbsent(
                        selfJid,
                        () => resolvedSelfAvatarPath,
                      );
                      chatAvatarPathsByJid.putIfAbsent(
                        selfJid,
                        () => resolvedSelfAvatarPath,
                      );
                    }
                  }
                }
                String? avatarPathForBareJid(String jid) {
                  final normalized = jid.trim().toLowerCase();
                  if (normalized.isEmpty) return null;
                  return rosterAvatarPathsByJid[normalized] ??
                      chatAvatarPathsByJid[normalized];
                }

                String? avatarPathForTypingParticipant(String participant) {
                  final trimmed = participant.trim();
                  if (trimmed.isEmpty) return null;
                  final slashIndex = trimmed.indexOf('/');
                  if (slashIndex == -1) {
                    return avatarPathForBareJid(trimmed);
                  }
                  final bareParticipant =
                      trimmed.substring(0, slashIndex).trim().toLowerCase();
                  final roomJid = chatEntity?.jid.trim().toLowerCase();
                  final isRoomParticipant =
                      roomJid != null && bareParticipant == roomJid;
                  if (!isRoomParticipant) {
                    return avatarPathForBareJid(
                      trimmed.substring(0, slashIndex),
                    );
                  }
                  final roomState = state.roomState;
                  if (roomState == null) return null;
                  final nick = trimmed.substring(slashIndex + 1).trim();
                  if (nick.isEmpty) return null;

                  Occupant? occupant = roomState.occupants[trimmed];
                  if (occupant == null) {
                    for (final candidate in roomState.occupants.values) {
                      if (candidate.nick == nick) {
                        occupant = candidate;
                        break;
                      }
                    }
                  }

                  final realJid = occupant?.realJid?.trim();
                  if (realJid == null || realJid.isEmpty) return null;
                  final realSlashIndex = realJid.indexOf('/');
                  final bareRealJid = realSlashIndex == -1
                      ? realJid
                      : realJid.substring(0, realSlashIndex);
                  return avatarPathForBareJid(bareRealJid);
                }

                final storageManager = context.watch<CalendarStorageManager>();
                final chatCalendarCoordinator = _resolveChatCalendarCoordinator(
                  storageManager: storageManager,
                  xmppService: xmppService,
                );
                final bool personalCalendarAvailable =
                    storageManager.isAuthStorageReady;
                final bool supportsChatCalendar =
                    chatEntity?.supportsChatCalendar ?? false;
                final bool chatCalendarReady =
                    storageManager.isAuthStorageReady &&
                        chatCalendarCoordinator != null;
                final bool chatCalendarEnabled =
                    supportsChatCalendar && chatCalendarReady;
                final ChatCalendarBloc? chatCalendarBloc =
                    _resolveChatCalendarBloc(
                  chat: chatEntity,
                  calendarAvailable: chatCalendarEnabled,
                  coordinator: chatCalendarCoordinator,
                );
                final bool chatCalendarAvailable =
                    chatCalendarEnabled && chatCalendarBloc != null;
                final List<String> chatCalendarParticipants =
                    supportsChatCalendar
                        ? _resolveChatCalendarParticipants(
                            chat: chatEntity,
                            roomState: state.roomState,
                            currentUserId: currentUserId,
                          )
                        : const <String>[];
                final chatCalendarAvatarPaths = <String, String>{};
                for (final participant in chatCalendarParticipants) {
                  final path = avatarPathForTypingParticipant(participant);
                  if (path == null || path.isEmpty) {
                    continue;
                  }
                  chatCalendarAvatarPaths[participant] = path;
                }

                final retryEntry = _lastReportEntryWhere(
                  fanOutReports.entries,
                  (entry) => entry.value.hasFailures,
                );
                final retryReport = retryEntry?.value;
                final retryShareId = retryEntry?.key;
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
                  if (!_chatRoute.isMain || openChatCalendar) {
                    _returnToMainRoute();
                    return false;
                  }
                  final targetJid = state.chat?.jid;
                  final hasDraftText = _textController.text.isNotEmpty;
                  if (hasDraftText && !isDefaultEmail && targetJid != null) {
                    context.read<DraftCubit?>()?.saveDraft(
                          id: null,
                          jids: [targetJid],
                          body: _textController.text,
                        );
                  }
                  return true;
                }

                final selfUserId = isGroupChat && myOccupantId != null
                    ? myOccupantId
                    : currentUserId;
                final user = ChatUser(
                  id: selfUserId,
                  firstName: (isGroupChat ? myOccupant?.nick : null) ??
                      profileState()?.username ??
                      '',
                );
                final spacerUser = ChatUser(
                  id: _selectionSpacerMessageId,
                  firstName: '',
                );
                final bool canShowSettings = !readOnly && jid != null;
                final bool isSettingsRoute =
                    canShowSettings && _chatRoute.isSettings;
                final isEmailBacked = chatEntity?.isEmailBacked ?? false;
                final canManagePins = !isGroupChat ||
                    isEmailBacked ||
                    (state.roomState?.myAffiliation.canManagePins ?? false);
                final canTogglePins = !readOnly && canManagePins;
                final int pinnedCount = state.pinnedMessages.length;
                const IconData pinnedIcon = LucideIcons.pin;
                final bool showingChatCalendar =
                    openChatCalendar || _chatRoute.isCalendar;
                final List<AppBarActionItem> leadingActions =
                    <AppBarActionItem>[
                  if (!readOnly)
                    AppBarActionItem(
                      label: context.l10n.commonClose,
                      iconData: LucideIcons.x,
                      usePrimary: false,
                      onPressed: () {
                        if (!prepareChatExit()) return;
                        unawaited(
                          context.read<ChatsCubit>().closeAllChats(),
                        );
                      },
                    ),
                  if (!readOnly && openStack.length > 1)
                    AppBarActionItem(
                      label: context.l10n.chatBack,
                      iconData: LucideIcons.arrowLeft,
                      usePrimary: false,
                      onPressed: () {
                        if (!prepareChatExit()) return;
                        unawaited(
                          context.read<ChatsCubit>().popChat(),
                        );
                      },
                    ),
                  if (!readOnly && forwardStack.isNotEmpty)
                    AppBarActionItem(
                      label: context.l10n.chatMessageOpenChat,
                      iconData: LucideIcons.arrowRight,
                      usePrimary: false,
                      onPressed: () {
                        if (!prepareChatExit()) return;
                        unawaited(
                          context.read<ChatsCubit>().restoreChat(),
                        );
                      },
                    ),
                ];
                final int leadingActionCount = leadingActions.length;
                final int chatActionCount = _chatBaseActionCount +
                    (isGroupChat ? 1 : 0) +
                    (chatCalendarAvailable ? 1 : 0) +
                    (canShowSettings ? 1 : 0);
                final scaffold = LayoutBuilder(
                  builder: (context, constraints) {
                    final double appBarWidth = constraints.maxWidth;
                    final double leadingWidthExpanded = leadingActionCount == 0
                        ? _chatAppBarCollapsedLeadingWidth
                        : _chatAppBarLeadingInset +
                            (AxiIconButton.kTapTargetSize *
                                leadingActionCount) +
                            (_chatAppBarLeadingSpacing *
                                math.max(0, leadingActionCount - 1));
                    final double chatActionsWidth = chatActionCount == 0
                        ? 0
                        : (AxiIconButton.kTapTargetSize * chatActionCount) +
                            (_chatHeaderActionSpacing *
                                math.max(0, chatActionCount - 1));
                    const double titleReserveWidth = _chatAppBarAvatarSize +
                        _chatAppBarAvatarSpacing +
                        _chatAppBarTitleMinWidth;
                    const double actionsPaddingWidth =
                        _chatAppBarActionsPadding * 2;
                    final bool collapseAppBarActions = leadingActionCount > 0 &&
                        appBarWidth <
                            leadingWidthExpanded +
                                chatActionsWidth +
                                titleReserveWidth +
                                actionsPaddingWidth;
                    final double leadingWidth =
                        collapseAppBarActions || leadingActionCount == 0
                            ? _chatAppBarCollapsedLeadingWidth
                            : leadingWidthExpanded;
                    return Scaffold(
                      backgroundColor: context.colorScheme.background,
                      appBar: AppBar(
                        scrolledUnderElevation: 0,
                        forceMaterialTransparency: true,
                        automaticallyImplyLeading: false,
                        shape: Border(
                          bottom: BorderSide(color: context.colorScheme.border),
                        ),
                        actionsPadding: const EdgeInsets.symmetric(
                          horizontal: _chatAppBarActionsPadding,
                        ),
                        leadingWidth: leadingWidth,
                        leading: readOnly ||
                                collapseAppBarActions ||
                                leadingActionCount == 0
                            ? null
                            : Padding(
                                padding: const EdgeInsets.only(
                                  left: _chatAppBarLeadingInset,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: AppBarActions(
                                    actions: leadingActions,
                                    spacing: _chatAppBarLeadingSpacing,
                                    overflowBreakpoint: 0,
                                    availableWidth: leadingWidthExpanded,
                                  ),
                                ),
                              ),
                        title: jid == null
                            ? const SizedBox.shrink()
                            : BlocBuilder<RosterCubit, RosterState>(
                                buildWhen: (_, current) =>
                                    current is RosterAvailable,
                                builder: (context, rosterState) {
                                  final cached = rosterState is RosterAvailable
                                      ? rosterState.items
                                      : context.read<RosterCubit>()['items']
                                          as List<RosterItem>?;
                                  final rosterItems =
                                      cached ?? const <RosterItem>[];
                                  final item = rosterItems
                                      .where((entry) => entry.jid == jid)
                                      .singleOrNull;
                                  final canRenameContact = !readOnly &&
                                      chatEntity != null &&
                                      chatEntity.type == ChatType.chat;
                                  final statusLabel =
                                      item?.status?.trim() ?? '';
                                  final presence = item?.presence;
                                  final subscription = item?.subscription;
                                  final double titleMaxWidth =
                                      appBarWidth * _chatAppBarTitleWidthScale;
                                  final double clampedTitleWidth =
                                      titleMaxWidth.clamp(
                                    _chatAppBarTitleMinWidth,
                                    _chatAppBarTitleMaxWidth,
                                  );
                                  final baseTitleStyle = Theme.of(context)
                                          .appBarTheme
                                          .titleTextStyle ??
                                      context.textTheme.h4;
                                  final titleStyle = baseTitleStyle.copyWith(
                                    fontSize: context.textTheme.large.fontSize,
                                  );
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TransportAwareAvatar(
                                        chat: chatEntity!,
                                        size: _chatAppBarAvatarSize,
                                        badgeOffset: const Offset(-6, -4),
                                        presence: presence,
                                        status: statusLabel,
                                        subscription: subscription,
                                      ),
                                      const SizedBox(
                                        width: _chatAppBarAvatarSpacing,
                                      ),
                                      Flexible(
                                        fit: FlexFit.loose,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: clampedTitleWidth,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Flexible(
                                                    fit: FlexFit.loose,
                                                    child: Text(
                                                      state.chat?.displayName ??
                                                          '',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: titleStyle,
                                                    ),
                                                  ),
                                                  if (canRenameContact)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsetsDirectional
                                                              .only(start: 6),
                                                      child: AxiTooltip(
                                                        builder: (context) =>
                                                            Text(
                                                          context.l10n
                                                              .chatContactRenameTooltip,
                                                        ),
                                                        child: ShadIconButton
                                                            .ghost(
                                                          onPressed:
                                                              _promptContactRename,
                                                          icon: Icon(
                                                            LucideIcons
                                                                .pencilLine,
                                                            size:
                                                                _chatAppBarRenameIconSize,
                                                            color: context
                                                                .colorScheme
                                                                .mutedForeground,
                                                          ),
                                                          decoration:
                                                              const ShadDecoration(
                                                            secondaryBorder:
                                                                ShadBorder.none,
                                                            secondaryFocusedBorder:
                                                                ShadBorder.none,
                                                          ),
                                                        ).withTapBounce(),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              if (statusLabel.isNotEmpty)
                                                Text(
                                                  statusLabel,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style:
                                                      context.textTheme.muted,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                        actions: [
                          if (jid != null)
                            BlocSelector<ChatSearchCubit, ChatSearchState,
                                bool>(
                              selector: (state) => state.active,
                              builder: (context, searchActive) {
                                final l10n = context.l10n;
                                final List<AppBarActionItem> chatActions =
                                    <AppBarActionItem>[
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
                                    onPressed: () => context
                                        .read<ChatSearchCubit>()
                                        .toggleActive(),
                                  ),
                                  AppBarActionItem(
                                    label: l10n.chatAttachmentTooltip,
                                    iconData: LucideIcons.image,
                                    onPressed: _openChatAttachments,
                                  ),
                                  AppBarActionItem(
                                    label: _pinnedPanelVisible
                                        ? l10n.commonClose
                                        : l10n.chatPinnedMessagesTooltip,
                                    iconData: pinnedIcon,
                                    icon: _PinnedBadgeIcon(
                                      iconData: pinnedIcon,
                                      count: pinnedCount,
                                    ),
                                    onPressed: _togglePinnedMessages,
                                  ),
                                  if (chatCalendarAvailable)
                                    AppBarActionItem(
                                      label: showingChatCalendar
                                          ? l10n.commonClose
                                          : l10n.homeRailCalendar,
                                      iconData: LucideIcons.calendarClock,
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
                                      onPressed: _toggleSettingsPanel,
                                    ),
                                ];
                                final List<AppBarActionItem> combinedActions =
                                    collapseAppBarActions
                                        ? <AppBarActionItem>[
                                            ...leadingActions,
                                            ...chatActions,
                                          ]
                                        : chatActions;
                                return AppBarActions(
                                  actions: combinedActions,
                                  spacing: _chatHeaderActionSpacing,
                                  overflowBreakpoint: 0,
                                  availableWidth: appBarWidth,
                                  forceCollapsed:
                                      collapseAppBarActions ? true : null,
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
                              const ChatAlert(),
                              _UnknownSenderBanner(
                                readOnly: readOnly,
                                isSelfChat: isSelfChat,
                                onAddContact: _handleAddContact,
                                onReportSpam: () => _handleSpamToggle(
                                  sendToSpam: true,
                                ),
                              ),
                              Expanded(
                                child: IgnorePointer(
                                  ignoring: !_chatRoute.allowsChatInteraction,
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final rawContentWidth =
                                          math.max(0.0, constraints.maxWidth);
                                      final availableWidth = math.max(
                                        0.0,
                                        rawContentWidth -
                                            (_messageListHorizontalPadding * 2),
                                      );
                                      final isCompact =
                                          availableWidth < smallScreen;
                                      final pinnedPanelMaxHeight = math.max(
                                        _chatPinnedPanelMinHeight,
                                        constraints.maxHeight -
                                            _bottomSectionHeight,
                                      );
                                      final messageById = {
                                        for (final item in state.items)
                                          item.stanzaID: item,
                                      };
                                      final pinnedStanzaIds = state
                                          .pinnedMessages
                                          .map((item) => item.messageStanzaId)
                                          .toSet();
                                      if (searchFiltering) {
                                        for (final item in searchResults) {
                                          messageById[item.stanzaID] = item;
                                        }
                                      }
                                      _pruneMessageSelection(
                                        messageById.keys.toSet(),
                                      );
                                      final activeItems = searchFiltering
                                          ? searchResults
                                          : state.items;
                                      final attachmentsByMessageId = state
                                          .attachmentMetadataIdsByMessageId;
                                      final groupLeaderByMessageId = state
                                          .attachmentGroupLeaderByMessageId;
                                      const emptyAttachments = <String>[];
                                      String messageKey(Message message) =>
                                          message.id ?? message.stanzaID;
                                      bool isGroupedNonLeader(Message message) {
                                        final messageId = message.id;
                                        if (messageId == null ||
                                            messageId.isEmpty) {
                                          return false;
                                        }
                                        final leaderId =
                                            groupLeaderByMessageId[messageId];
                                        return leaderId != null &&
                                            leaderId != messageId;
                                      }

                                      List<String> attachmentsForMessage(
                                        Message message,
                                      ) {
                                        final key = messageKey(message);
                                        return attachmentsByMessageId[key] ??
                                            emptyAttachments;
                                      }

                                      final displayItems = activeItems
                                          .where(
                                            (message) =>
                                                !isGroupedNonLeader(message),
                                          )
                                          .toList();
                                      final filteredItems =
                                          displayItems.where((message) {
                                        final hasHtml = message
                                                .normalizedHtmlBody
                                                ?.isNotEmpty ==
                                            true;
                                        final attachments =
                                            attachmentsForMessage(message);
                                        return message.body != null ||
                                            hasHtml ||
                                            message.error.isNotNone ||
                                            attachments.isNotEmpty;
                                      }).toList();
                                      final availabilityCoordinator =
                                          _maybeReadAvailabilityShareCoordinator(
                                        context,
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
                                            final bool isValid =
                                                _availabilitySenderMatchesClaim(
                                              senderJid: item.senderJid,
                                              chatJid: item.chatJid,
                                              claimedJid: owner,
                                              roomState: state.roomState,
                                            );
                                            if (isValid) {
                                              availabilityShareOwnersById[
                                                  value.share.id] = owner;
                                            }
                                          },
                                          orElse: () {},
                                        );
                                      }
                                      final isEmailChat = state
                                              .chat?.defaultTransport.isEmail ==
                                          true;
                                      final loadingMessages =
                                          !state.messagesLoaded;
                                      final selectedMessages =
                                          _collectSelectedMessages(
                                              filteredItems);
                                      if (_multiSelectActive &&
                                          selectedMessages.isEmpty) {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          if (!mounted) return;
                                          _clearMultiSelection();
                                        });
                                      }
                                      final selectionActive =
                                          _selectedMessageId != null;
                                      final selectionSpacerVisibleHeight =
                                          selectionActive
                                              ? math.max(
                                                  _messageListTailSpacer,
                                                  _selectionSpacerHeight,
                                                )
                                              : _messageListTailSpacer;
                                      final baseBubbleMaxWidth = availableWidth *
                                          (isCompact
                                              ? _compactBubbleWidthFraction
                                              : _regularBubbleWidthFraction);
                                      final inboundAvatarReservation =
                                          isGroupChat
                                              ? _messageRowAvatarReservation
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
                                      final inboundMessageRowMaxWidth =
                                          math.min(
                                        availableWidth -
                                            inboundAvatarReservation,
                                        inboundClampedBubbleWidth +
                                            _selectionOuterInset,
                                      );
                                      final outboundMessageRowMaxWidth =
                                          math.min(
                                        availableWidth,
                                        outboundClampedBubbleWidth +
                                            _selectionOuterInset,
                                      );
                                      final messageRowMaxWidth =
                                          rawContentWidth;
                                      final selectionExtrasMaxWidth = math.min(
                                        availableWidth,
                                        _selectionExtrasMaxWidth,
                                      );
                                      final dashMessages = <ChatMessage>[];
                                      final shownSubjectShares = <String>{};
                                      final revokedInviteTokens = <String>{
                                        for (final invite
                                            in filteredItems.where(
                                          (m) =>
                                              m.pseudoMessageType ==
                                              PseudoMessageType
                                                  .mucInviteRevocation,
                                        ))
                                          if (invite.pseudoMessageData
                                                  ?.containsKey('token') ==
                                              true)
                                            invite.pseudoMessageData?['token']
                                                as String
                                      };
                                      for (var index = 0;
                                          index < filteredItems.length;
                                          index++) {
                                        final e = filteredItems[index];
                                        final senderBare =
                                            _bareJid(e.senderJid);
                                        final normalizedSenderBare =
                                            _normalizeBareJid(e.senderJid);
                                        final isSelfXmpp = senderBare != null &&
                                            senderBare ==
                                                _bareJid(profileState()?.jid);
                                        final isSelfEmail = senderBare !=
                                                null &&
                                            resolvedEmailSelfJid != null &&
                                            senderBare ==
                                                _bareJid(resolvedEmailSelfJid);
                                        final bool isDeltaPlaceholderSender =
                                            normalizedSenderBare != null &&
                                                normalizedSenderBare
                                                    .isDeltaPlaceholderJid;
                                        final isMucSelf = isGroupChat &&
                                            (_isSameOccupantId(
                                                  e.senderJid,
                                                  myOccupantId,
                                                ) ||
                                                _isSameOccupantId(
                                                  e.occupantID,
                                                  myOccupantId,
                                                ));
                                        final isSelf = isSelfXmpp ||
                                            isSelfEmail ||
                                            isMucSelf ||
                                            isDeltaPlaceholderSender;
                                        final occupantId = isGroupChat
                                            ? (isSelf ? user.id : e.senderJid)
                                            : null;
                                        final occupant = !isGroupChat
                                            ? null
                                            : state.roomState
                                                ?.occupants[occupantId];
                                        final isEmailMessage =
                                            e.deltaMsgId != null;
                                        final fallbackNick =
                                            _nickFromSender(e.senderJid) ??
                                                state.chat?.title ??
                                                '';
                                        final author = ChatUser(
                                          id: isGroupChat
                                              ? occupantId!
                                              : (isSelf
                                                  ? user.id
                                                  : e.senderJid),
                                          firstName: isSelf
                                              ? user.firstName
                                              : (occupant?.nick ??
                                                  fallbackNick),
                                        );
                                        final quotedMessage = e.quoting == null
                                            ? null
                                            : messageById[e.quoting!];
                                        final shareContext =
                                            shareContexts[e.stanzaID];
                                        final bannerParticipants =
                                            List<chat_models.Chat>.of(
                                          _participantsForBanner(
                                            shareContext,
                                            state.chat?.jid,
                                            currentUserId,
                                          ),
                                        );
                                        bool showSubjectHeader = false;
                                        String? subjectLabel;
                                        String bodyText = e.body ?? '';
                                        final inviteToken =
                                            e.pseudoMessageData?['token']
                                                as String?;
                                        final inviteRoom =
                                            e.pseudoMessageData?['roomJid']
                                                as String?;
                                        final inviteRoomName =
                                            (e.pseudoMessageData?['roomName']
                                                    as String?)
                                                ?.trim();
                                        final invitee =
                                            e.pseudoMessageData?['invitee']
                                                as String?;
                                        final isInvite = e.pseudoMessageType ==
                                            PseudoMessageType.mucInvite;
                                        final isInviteRevocation =
                                            e.pseudoMessageType ==
                                                PseudoMessageType
                                                    .mucInviteRevocation;
                                        const unknownRoomFallbackLabel =
                                            'group chat';
                                        final resolvedInviteRoomName =
                                            inviteRoomName?.isNotEmpty == true
                                                ? inviteRoomName!
                                                : unknownRoomFallbackLabel;
                                        const inviteBodyLabel =
                                            'You have been invited to a group chat';
                                        const inviteRevokedBodyLabel =
                                            'Invite revoked';
                                        final inviteLabel = isInvite
                                            ? inviteBodyLabel
                                            : inviteRevokedBodyLabel;
                                        final inviteActionLabel =
                                            "Join '$resolvedInviteRoomName'";
                                        final inviteRevoked =
                                            inviteToken != null &&
                                                revokedInviteTokens
                                                    .contains(inviteToken);
                                        if (shareContext?.subject
                                                ?.trim()
                                                .isNotEmpty ==
                                            true) {
                                          subjectLabel =
                                              shareContext!.subject!.trim();
                                          if (shownSubjectShares
                                              .add(shareContext.shareId)) {
                                            showSubjectHeader = true;
                                          }
                                        } else {
                                          final split =
                                              ChatSubjectCodec.splitXmppBody(
                                            e.body,
                                          );
                                          subjectLabel = split.subject;
                                          bodyText = split.body;
                                        }
                                        if (!showSubjectHeader &&
                                            shareContext == null &&
                                            subjectLabel?.isNotEmpty == true) {
                                          showSubjectHeader = true;
                                        }
                                        final subjectText =
                                            subjectLabel?.trim() ?? '';
                                        final bodyTextTrimmed = bodyText.trim();
                                        final isSubjectOnlyBody =
                                            showSubjectHeader &&
                                                subjectText.isNotEmpty &&
                                                bodyTextTrimmed == subjectText;
                                        final displayedBody =
                                            isSubjectOnlyBody ? '' : bodyText;
                                        final errorLabel = e.error.asString;
                                        MessageStatus statusFor(Message e) {
                                          if (e.error.isNotNone) {
                                            return MessageStatus.failed;
                                          }
                                          if (isEmailChat) {
                                            if (e.received || e.displayed) {
                                              return MessageStatus.received;
                                            }
                                            if (e.acked) {
                                              return MessageStatus.sent;
                                            }
                                            return MessageStatus.pending;
                                          }
                                          if (e.displayed) {
                                            return MessageStatus.read;
                                          }
                                          if (e.received) {
                                            return MessageStatus.received;
                                          }
                                          if (e.acked) {
                                            return MessageStatus.sent;
                                          }
                                          return MessageStatus.pending;
                                        }

                                        final shouldReplaceInviteBody =
                                            isInvite || isInviteRevocation;
                                        final renderedText = shouldReplaceInviteBody
                                            ? inviteLabel
                                            : e.error.isNotNone
                                                ? '$errorLabel${bodyText.isNotEmpty ? ': "$bodyTextTrimmed"' : ''}'
                                                : displayedBody;
                                        final attachmentIds =
                                            attachmentsForMessage(e);
                                        final hasAttachment =
                                            attachmentIds.isNotEmpty;
                                        final hasRenderableSubjectHeader =
                                            showSubjectHeader &&
                                                subjectText.isNotEmpty;
                                        final shouldForceDashText = renderedText
                                                .trim()
                                                .isEmpty &&
                                            (hasAttachment ||
                                                hasRenderableSubjectHeader ||
                                                e.retracted ||
                                                e.edited);
                                        final CalendarAvailabilityMessage?
                                            validatedAvailabilityMessage =
                                            _validatedAvailabilityMessage(
                                          message: e,
                                          roomState: state.roomState,
                                          shareOwnersById:
                                              availabilityShareOwnersById,
                                          availabilityCoordinator:
                                              availabilityCoordinator,
                                        );
                                        dashMessages.add(
                                          ChatMessage(
                                            user: author,
                                            createdAt: e.timestamp!.toLocal(),
                                            text: shouldForceDashText
                                                ? _dashChatPlaceholderText
                                                : renderedText,
                                            status: statusFor(e),
                                            customProperties: {
                                              'id': e.stanzaID,
                                              'body': bodyText,
                                              'renderedText': renderedText,
                                              'attachmentIds': attachmentIds,
                                              'edited': e.edited,
                                              'retracted': e.retracted,
                                              'error': e.error,
                                              'encrypted': e
                                                  .encryptionProtocol.isNotNone,
                                              'trust': e.trust,
                                              'trusted': e.trusted,
                                              'isSelf': isSelf,
                                              'model': e,
                                              _calendarFragmentPropertyKey:
                                                  e.calendarFragment,
                                              _calendarTaskIcsPropertyKey:
                                                  e.calendarTaskIcs,
                                              _calendarTaskIcsReadOnlyPropertyKey:
                                                  e.calendarTaskIcsReadOnly,
                                              _calendarAvailabilityPropertyKey:
                                                  validatedAvailabilityMessage,
                                              'quoted': quotedMessage,
                                              'reactions': e.reactionsPreview,
                                              'shareContext': shareContext,
                                              'shareParticipants':
                                                  bannerParticipants,
                                              'replyParticipants':
                                                  shareReplies[e.stanzaID],
                                              'showSubject': showSubjectHeader,
                                              'subjectLabel': subjectLabel,
                                              'isEmailMessage': isEmailMessage,
                                              'inviteRoom': inviteRoom,
                                              'inviteRoomName': inviteRoomName,
                                              'inviteToken': inviteToken,
                                              'inviteRevoked': inviteRevoked,
                                              'invitee': invitee,
                                              'isInvite': isInvite,
                                              'isInviteRevocation':
                                                  isInviteRevocation,
                                              'inviteLabel': inviteLabel,
                                              'inviteActionLabel':
                                                  inviteActionLabel,
                                            },
                                          ),
                                        );
                                      }
                                      final emptyStateLabel = searchFiltering
                                          ? context.l10n.chatEmptySearch
                                          : context.l10n.chatEmptyMessages;
                                      if (!loadingMessages &&
                                          filteredItems.isEmpty) {
                                        dashMessages.add(
                                          ChatMessage(
                                            user: spacerUser,
                                            createdAt:
                                                _selectionSpacerTimestamp,
                                            text: ' ',
                                            customProperties: {
                                              'id': _emptyStateMessageId,
                                              'emptyState': true,
                                              'emptyLabel': emptyStateLabel,
                                            },
                                          ),
                                        );
                                      }
                                      dashMessages.add(
                                        ChatMessage(
                                          user: spacerUser,
                                          createdAt: _selectionSpacerTimestamp,
                                          text: ' ',
                                          customProperties: const {
                                            'id': _selectionSpacerMessageId,
                                            'selectionSpacer': true,
                                          },
                                        ),
                                      );
                                      late final MessageListOptions
                                          dashMessageListOptions;
                                      dashMessageListOptions =
                                          MessageListOptions(
                                        scrollController: _scrollController,
                                        scrollPhysics: _selectionAutoscrollActive
                                            ? const AlwaysScrollableScrollPhysics(
                                                parent: ClampingScrollPhysics(),
                                              )
                                            : const AlwaysScrollableScrollPhysics(
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
                                        onLoadEarlier: searchFiltering ||
                                                state.items.length %
                                                        ChatBloc
                                                            .messageBatchSize !=
                                                    0
                                            ? null
                                            : () async => context
                                                .read<ChatBloc>()
                                                .add(const ChatLoadEarlier()),
                                        loadEarlierBuilder: Container(
                                          padding: const EdgeInsets.all(12.0),
                                          alignment: Alignment.center,
                                          child: CircularProgressIndicator(
                                            color: context.colorScheme.primary,
                                          ),
                                        ),
                                      );
                                      final composerHintText = isDefaultEmail
                                          ? context.l10n.chatComposerEmailHint
                                          : context
                                              .l10n.chatComposerMessageHint;
                                      Widget quoteSection;
                                      final quoting = state.quoting;
                                      if (quoting == null) {
                                        quoteSection = const SizedBox.shrink();
                                      } else {
                                        quoteSection = Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          child: _QuoteBanner(
                                            key: ValueKey<String?>(
                                                quoting.stanzaID),
                                            message: quoting,
                                            isSelf: _isQuotedMessageFromSelf(
                                              quotedMessage: quoting,
                                              isGroupChat: isGroupChat,
                                              myOccupantId: myOccupantId,
                                              currentUserId: currentUserId,
                                            ),
                                            onClear: () => context
                                                .read<ChatBloc>()
                                                .add(const ChatQuoteCleared()),
                                          ),
                                        );
                                      }
                                      quoteSection = AnimatedSize(
                                        duration: _bubbleFocusDuration,
                                        curve: _bubbleFocusCurve,
                                        alignment: Alignment.topCenter,
                                        child: quoteSection,
                                      );
                                      final remoteTyping =
                                          state.chat?.chatState?.name ==
                                              'composing';
                                      final demoTypingAvatars =
                                          _demoTypingParticipants(state);
                                      final fallbackTypingJid =
                                          state.chat?.contactJid ??
                                              state.chat?.jid;
                                      final typingAvatars = demoTypingAvatars
                                              .isNotEmpty
                                          ? demoTypingAvatars
                                          : state.typingParticipants.isNotEmpty
                                              ? state.typingParticipants
                                              : remoteTyping &&
                                                      fallbackTypingJid !=
                                                          null &&
                                                      fallbackTypingJid
                                                          .isNotEmpty
                                                  ? [fallbackTypingJid]
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
                                              remoteTyping ||
                                              typingAvatars.isNotEmpty ||
                                              demoTypingAvatars.isNotEmpty;
                                      final bottomSection =
                                          _SizeReportingWidget(
                                        onSizeChange:
                                            _updateBottomSectionHeight,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            quoteSection,
                                            if (_multiSelectActive &&
                                                selectedMessages.isNotEmpty)
                                              () {
                                                final targets =
                                                    List<Message>.of(
                                                  selectedMessages,
                                                  growable: false,
                                                );
                                                final canReact = !isEmailChat;
                                                return _MessageSelectionToolbar(
                                                  count: targets.length,
                                                  onClear: _clearMultiSelection,
                                                  onCopy: () =>
                                                      _copySelectedMessages(
                                                    List<Message>.of(targets),
                                                  ),
                                                  onShare: () =>
                                                      _shareSelectedMessages(
                                                    List<Message>.of(targets),
                                                  ),
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
                                                            List<Message>.of(
                                                              targets,
                                                            ),
                                                          )
                                                      : null,
                                                );
                                              }()
                                            else
                                              () {
                                                if (widget.readOnly) {
                                                  _ensureRecipientBarHeightCleared();
                                                  return const _ReadOnlyComposerBanner();
                                                }
                                                final visibilityLabel =
                                                    _recipientVisibilityLabel(
                                                  chat: state.chat,
                                                  recipients: recipients,
                                                );
                                                return _ChatComposerSection(
                                                  hintText: composerHintText,
                                                  recipients: recipients,
                                                  availableChats:
                                                      availableChats,
                                                  latestStatuses:
                                                      latestStatuses,
                                                  visibilityLabel:
                                                      visibilityLabel,
                                                  pendingAttachments:
                                                      pendingAttachments,
                                                  composerHasText:
                                                      _composerHasText,
                                                  composerError:
                                                      state.composerError,
                                                  showAttachmentWarning:
                                                      showAttachmentWarning,
                                                  retryReport: retryReport,
                                                  retryShareId: retryShareId,
                                                  subjectController:
                                                      _subjectController,
                                                  subjectFocusNode:
                                                      _subjectFocusNode,
                                                  textController:
                                                      _textController,
                                                  textFocusNode: _focusNode,
                                                  onSubjectSubmitted: () =>
                                                      _focusNode.requestFocus(),
                                                  onRecipientAdded: (target) =>
                                                      context
                                                          .read<ChatBloc>()
                                                          .add(
                                                            ChatComposerRecipientAdded(
                                                              target,
                                                            ),
                                                          ),
                                                  onRecipientRemoved: (key) =>
                                                      context
                                                          .read<ChatBloc>()
                                                          .add(
                                                            ChatComposerRecipientRemoved(
                                                              key,
                                                            ),
                                                          ),
                                                  onRecipientToggled: (key) =>
                                                      context
                                                          .read<ChatBloc>()
                                                          .add(
                                                            ChatComposerRecipientToggled(
                                                              key,
                                                            ),
                                                          ),
                                                  onAttachmentRetry: (id) =>
                                                      context
                                                          .read<ChatBloc>()
                                                          .add(
                                                            ChatAttachmentRetryRequested(
                                                              id,
                                                            ),
                                                          ),
                                                  onAttachmentRemove: (id) =>
                                                      context
                                                          .read<ChatBloc>()
                                                          .add(
                                                            ChatPendingAttachmentRemoved(
                                                              id,
                                                            ),
                                                          ),
                                                  onPendingAttachmentPressed:
                                                      _handlePendingAttachmentPressed,
                                                  onPendingAttachmentLongPressed:
                                                      _handlePendingAttachmentLongPressed,
                                                  pendingAttachmentMenuBuilder:
                                                      _pendingAttachmentMenuItems,
                                                  buildComposerAccessories: (
                                                          {required bool
                                                              canSend}) =>
                                                      _composerAccessories(
                                                    canSend: canSend,
                                                    attachmentsEnabled:
                                                        attachmentsEnabled,
                                                  ),
                                                  onTaskDropped:
                                                      _handleTaskDrop,
                                                  onSend: _handleSendMessage,
                                                );
                                              }(),
                                          ],
                                        ),
                                      );
                                      return Column(
                                        children: [
                                          _ChatPinnedMessagesPanel(
                                            key: ValueKey(
                                              '$_chatPinnedPanelKeyPrefix${chatEntity?.jid ?? _chatPanelKeyFallback}',
                                            ),
                                            chat: chatEntity,
                                            visible: _pinnedPanelVisible,
                                            maxHeight: pinnedPanelMaxHeight,
                                            pinnedMessages:
                                                state.pinnedMessages,
                                            pinnedMessagesLoaded:
                                                state.pinnedMessagesLoaded,
                                            pinnedMessagesHydrating:
                                                state.pinnedMessagesHydrating,
                                            onClose: _closePinnedMessages,
                                            canTogglePins: canTogglePins,
                                            canShowCalendarTasks:
                                                chatCalendarBloc != null,
                                            roomState: state.roomState,
                                            metadataStreamFor:
                                                _metadataStreamFor,
                                            metadataInitialFor:
                                                _metadataInitialFor,
                                            attachmentsBlocked:
                                                attachmentsBlockedForChat,
                                            isOneTimeAttachmentAllowed:
                                                _isOneTimeAttachmentAllowed,
                                            shouldAllowAttachment:
                                                _shouldAllowAttachment,
                                            onApproveAttachment:
                                                _approveAttachment,
                                          ),
                                          Expanded(
                                            child: KeyedSubtree(
                                              key: _messageListKey,
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  MediaQuery.removePadding(
                                                    context: context,
                                                    removeLeft: true,
                                                    removeRight: true,
                                                    child: DashChat(
                                                      currentUser: user,
                                                      onSend: widget.readOnly
                                                          ? (_) {}
                                                          : (_) =>
                                                              _handleSendMessage(),
                                                      messages: dashMessages,
                                                      typingUsers: const [],
                                                      messageOptions:
                                                          MessageOptions(
                                                        showOtherUsersAvatar:
                                                            false,
                                                        showCurrentUserAvatar:
                                                            false,
                                                        showOtherUsersName:
                                                            false,
                                                        borderRadius: 0,
                                                        maxWidth:
                                                            messageRowMaxWidth,
                                                        messagePadding:
                                                            EdgeInsets.zero,
                                                        spaceWhenAvatarIsHidden:
                                                            0,
                                                        currentUserContainerColor:
                                                            Colors.transparent,
                                                        containerColor:
                                                            Colors.transparent,
                                                        messageTextBuilder:
                                                            (message, previous,
                                                                next) {
                                                          final colors = context
                                                              .colorScheme;
                                                          final chatTokens =
                                                              context.chatTheme;
                                                          final l10n =
                                                              context.l10n;
                                                          final isSelectionSpacer =
                                                              message.customProperties?[
                                                                      'selectionSpacer'] ==
                                                                  true;
                                                          if (isSelectionSpacer) {
                                                            final spacerHeight =
                                                                selectionSpacerVisibleHeight;
                                                            return _SelectionHeadroomSpacer(
                                                              height:
                                                                  spacerHeight,
                                                            );
                                                          }
                                                          final bannerParticipants = (message
                                                                          .customProperties?[
                                                                      'shareParticipants']
                                                                  as List<
                                                                      chat_models
                                                                      .Chat>?) ??
                                                              const <chat_models
                                                                  .Chat>[];
                                                          final recipientCutoutParticipants =
                                                              bannerParticipants;
                                                          final extraStyle =
                                                              context.textTheme
                                                                  .muted
                                                                  .copyWith(
                                                            fontStyle: FontStyle
                                                                .italic,
                                                          );
                                                          final isEmptyState =
                                                              message.customProperties?[
                                                                      'emptyState'] ==
                                                                  true;
                                                          if (isEmptyState) {
                                                            final emptyLabel = message
                                                                            .customProperties?[
                                                                        'emptyLabel']
                                                                    as String? ??
                                                                context.l10n
                                                                    .chatEmptyMessages;
                                                            return Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                vertical: 24,
                                                                horizontal:
                                                                    _chatHorizontalPadding,
                                                              ),
                                                              child: Center(
                                                                child: Text(
                                                                  emptyLabel,
                                                                  style: context
                                                                      .textTheme
                                                                      .muted,
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                          final self = message
                                                                          .customProperties?[
                                                                      'isSelf']
                                                                  as bool? ??
                                                              (message.user
                                                                      .id ==
                                                                  profileState()
                                                                      ?.jid);
                                                          final bubbleMaxWidth = self
                                                              ? outboundMessageRowMaxWidth
                                                              : inboundMessageRowMaxWidth;
                                                          final error = message
                                                                      .customProperties?[
                                                                  'error']
                                                              as MessageError?;
                                                          final isError = error
                                                                  ?.isNotNone ??
                                                              false;
                                                          final bubbleColor =
                                                              isError
                                                                  ? colors
                                                                      .destructive
                                                                  : self
                                                                      ? colors
                                                                          .primary
                                                                      : colors
                                                                          .card;
                                                          final borderColor =
                                                              self || isError
                                                                  ? Colors
                                                                      .transparent
                                                                  : chatTokens
                                                                      .recvEdge;
                                                          final textColor =
                                                              isError
                                                                  ? colors
                                                                      .destructiveForeground
                                                                  : self
                                                                      ? colors
                                                                          .primaryForeground
                                                                      : colors
                                                                          .foreground;
                                                          final timestampColor =
                                                              chatTokens
                                                                  .timestamp;
                                                          final chainedPrev =
                                                              _chatMessagesShouldChain(
                                                            message,
                                                            previous,
                                                          );
                                                          final chainedNext =
                                                              _chatMessagesShouldChain(
                                                            message,
                                                            next,
                                                          );
                                                          final baseTextStyle =
                                                              context.textTheme
                                                                  .small
                                                                  .copyWith(
                                                            color: textColor,
                                                            height: 1.3,
                                                          );
                                                          final linkStyle =
                                                              baseTextStyle
                                                                  .copyWith(
                                                            color: self
                                                                ? colors
                                                                    .primaryForeground
                                                                : colors
                                                                    .primary,
                                                            decoration:
                                                                TextDecoration
                                                                    .underline,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          );
                                                          final parsedText =
                                                              parseMessageText(
                                                            text: (message.customProperties?[
                                                                        'renderedText']
                                                                    as String?) ??
                                                                message.text,
                                                            baseStyle:
                                                                baseTextStyle,
                                                            linkStyle:
                                                                linkStyle,
                                                          );
                                                          final timeColor = isError
                                                              ? textColor
                                                              : self
                                                                  ? colors.primaryForeground
                                                                  : timestampColor;
                                                          final detailStyle =
                                                              context.textTheme
                                                                  .muted
                                                                  .copyWith(
                                                            color: timeColor,
                                                            fontSize: 11.0,
                                                            height: 1.0,
                                                            textBaseline:
                                                                TextBaseline
                                                                    .alphabetic,
                                                          );
                                                          final messageId = message
                                                                  .customProperties?[
                                                              'id'] as String?;
                                                          final isEmailMessage = (message
                                                                          .customProperties?[
                                                                      'isEmailMessage']
                                                                  as bool?) ??
                                                              (messageId !=
                                                                      null &&
                                                                  messageById[messageId]
                                                                          ?.deltaMsgId !=
                                                                      null);
                                                          final transportIconData =
                                                              isEmailMessage
                                                                  ? LucideIcons
                                                                      .mail
                                                                  : LucideIcons
                                                                      .messageCircle;
                                                          TextSpan
                                                              iconDetailSpan(
                                                            IconData icon,
                                                            Color color,
                                                          ) =>
                                                                  TextSpan(
                                                                    text: String
                                                                        .fromCharCode(
                                                                      icon.codePoint,
                                                                    ),
                                                                    style: detailStyle
                                                                        .copyWith(
                                                                      color:
                                                                          color,
                                                                      fontFamily:
                                                                          icon.fontFamily,
                                                                      package: icon
                                                                          .fontPackage,
                                                                    ),
                                                                  );
                                                          final time = TextSpan(
                                                            text:
                                                                '${message.createdAt.hour.toString().padLeft(2, '0')}:'
                                                                '${message.createdAt.minute.toString().padLeft(2, '0')}',
                                                            style: detailStyle,
                                                          );
                                                          final statusIcon =
                                                              message
                                                                  .status?.icon;
                                                          final status =
                                                              statusIcon == null
                                                                  ? null
                                                                  : iconDetailSpan(
                                                                      statusIcon,
                                                                      self
                                                                          ? colors
                                                                              .primaryForeground
                                                                          : timestampColor,
                                                                    );
                                                          final transportDetail =
                                                              iconDetailSpan(
                                                            transportIconData,
                                                            timeColor,
                                                          );
                                                          final trusted = message
                                                                  .customProperties![
                                                              'trusted'] as bool?;
                                                          final messageModel = (message
                                                                          .customProperties?[
                                                                      'model']
                                                                  as Message?) ??
                                                              (messageId == null
                                                                  ? null
                                                                  : messageById[
                                                                      messageId]);
                                                          if (messageModel ==
                                                              null) {
                                                            final fallbackText =
                                                                message.text
                                                                    .trim();
                                                            final resolvedFallback =
                                                                fallbackText
                                                                        .isNotEmpty
                                                                    ? fallbackText
                                                                    : l10n
                                                                        .chatAttachmentUnavailable;
                                                            return Padding(
                                                              padding:
                                                                  _messageFallbackOuterPadding,
                                                              child: Align(
                                                                alignment: self
                                                                    ? Alignment
                                                                        .centerRight
                                                                    : Alignment
                                                                        .centerLeft,
                                                                child:
                                                                    ConstrainedBox(
                                                                  constraints:
                                                                      BoxConstraints(
                                                                    maxWidth:
                                                                        bubbleMaxWidth,
                                                                  ),
                                                                  child:
                                                                      DecoratedBox(
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color:
                                                                          bubbleColor,
                                                                      borderRadius:
                                                                          _bubbleBorderRadius(
                                                                        isSelf:
                                                                            self,
                                                                        chainedPrevious:
                                                                            chainedPrev,
                                                                        chainedNext:
                                                                            chainedNext,
                                                                      ),
                                                                      border: borderColor ==
                                                                              Colors.transparent
                                                                          ? null
                                                                          : Border.all(
                                                                              color: borderColor,
                                                                            ),
                                                                    ),
                                                                    child:
                                                                        Padding(
                                                                      padding:
                                                                          _messageFallbackInnerPadding,
                                                                      child:
                                                                          Text(
                                                                        resolvedFallback,
                                                                        style:
                                                                            baseTextStyle,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                          final CalendarFragment?
                                                              rawFragment =
                                                              message.customProperties?[
                                                                      _calendarFragmentPropertyKey]
                                                                  as CalendarFragment?;
                                                          final CalendarFragment?
                                                              displayFragment =
                                                              rawFragment;
                                                          final CalendarTask?
                                                              calendarTaskIcs =
                                                              message.customProperties?[
                                                                      _calendarTaskIcsPropertyKey]
                                                                  as CalendarTask?;
                                                          final bool
                                                              calendarTaskIcsReadOnly =
                                                              (message.customProperties?[
                                                                          _calendarTaskIcsReadOnlyPropertyKey]
                                                                      as bool?) ??
                                                                  _calendarTaskIcsReadOnlyFallback;
                                                          final CalendarAvailabilityMessage?
                                                              availabilityMessage =
                                                              message.customProperties?[
                                                                      _calendarAvailabilityPropertyKey]
                                                                  as CalendarAvailabilityMessage?;
                                                          final verification =
                                                              trusted == null
                                                                  ? null
                                                                  : iconDetailSpan(
                                                                      trusted
                                                                          .toShieldIcon,
                                                                      trusted
                                                                          ? axiGreen
                                                                          : colors
                                                                              .destructive,
                                                                    );
                                                          final quotedModel = (message
                                                                          .customProperties?[
                                                                      'quoted']
                                                                  as Message?) ??
                                                              (messageModel
                                                                          .quoting ==
                                                                      null
                                                                  ? null
                                                                  : messageById[
                                                                      messageModel
                                                                          .quoting!]);
                                                          final reactions = (message
                                                                          .customProperties?[
                                                                      'reactions']
                                                                  as List<
                                                                      ReactionPreview>?) ??
                                                              const <ReactionPreview>[];
                                                          final replyParticipants = (message
                                                                          .customProperties?[
                                                                      'replyParticipants']
                                                                  as List<
                                                                      chat_models
                                                                      .Chat>?) ??
                                                              const <chat_models
                                                                  .Chat>[];
                                                          final attachmentIds =
                                                              (message.customProperties?[
                                                                          'attachmentIds']
                                                                      as List<
                                                                          String>?) ??
                                                                  const <String>[];
                                                          final showReplyStrip =
                                                              isEmailMessage &&
                                                                  replyParticipants
                                                                      .isNotEmpty;
                                                          final canReact =
                                                              !isEmailChat;
                                                          final isSingleSelection =
                                                              !_multiSelectActive &&
                                                                  _selectedMessageId ==
                                                                      messageModel
                                                                          .stanzaID;
                                                          final isMultiSelection =
                                                              _multiSelectActive &&
                                                                  _multiSelectedMessageIds
                                                                      .contains(
                                                                          messageModel
                                                                              .stanzaID);
                                                          final isSelected =
                                                              isSingleSelection ||
                                                                  isMultiSelection;
                                                          final showReactionManager =
                                                              canReact &&
                                                                  isSingleSelection;
                                                          final showCompactReactions =
                                                              !showReplyStrip &&
                                                                  reactions
                                                                      .isNotEmpty &&
                                                                  !showReactionManager;
                                                          final isInviteMessage = (message
                                                                          .customProperties?[
                                                                      'isInvite']
                                                                  as bool?) ??
                                                              (messageModel
                                                                      .pseudoMessageType ==
                                                                  PseudoMessageType
                                                                      .mucInvite);
                                                          final isInviteRevocationMessage = (message
                                                                          .customProperties?[
                                                                      'isInviteRevocation']
                                                                  as bool?) ??
                                                              (messageModel
                                                                      .pseudoMessageType ==
                                                                  PseudoMessageType
                                                                      .mucInviteRevocation);
                                                          final inviteRevoked =
                                                              (message.customProperties?[
                                                                          'inviteRevoked']
                                                                      as bool?) ??
                                                                  false;
                                                          final showRecipientCutout =
                                                              !showCompactReactions &&
                                                                  isEmailChat &&
                                                                  recipientCutoutParticipants
                                                                          .length >
                                                                      1;
                                                          Widget?
                                                              recipientOverlay;
                                                          CutoutStyle?
                                                              recipientStyle;
                                                          var recipientAnchor =
                                                              ChatBubbleCutoutAnchor
                                                                  .bottom;
                                                          Widget? avatarOverlay;
                                                          CutoutStyle?
                                                              avatarStyle;
                                                          var avatarAnchor =
                                                              ChatBubbleCutoutAnchor
                                                                  .left;
                                                          if (showRecipientCutout) {
                                                            recipientOverlay =
                                                                _RecipientCutoutStrip(
                                                              recipients:
                                                                  recipientCutoutParticipants,
                                                            );
                                                            recipientStyle =
                                                                const CutoutStyle(
                                                              depth:
                                                                  _recipientCutoutDepth,
                                                              cornerRadius:
                                                                  _recipientCutoutRadius,
                                                              padding:
                                                                  _recipientCutoutPadding,
                                                              offset:
                                                                  _recipientCutoutOffset,
                                                              minThickness:
                                                                  _recipientCutoutMinThickness,
                                                            );
                                                          }
                                                          Widget?
                                                              selectionOverlay;
                                                          CutoutStyle?
                                                              selectionStyle;
                                                          if (_multiSelectActive) {
                                                            final indicator =
                                                                SelectionIndicator(
                                                              visible: true,
                                                              selected:
                                                                  isMultiSelection,
                                                              onPressed: () =>
                                                                  _toggleMultiSelectMessage(
                                                                messageModel,
                                                              ),
                                                            );
                                                            selectionOverlay =
                                                                Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .only(
                                                                left:
                                                                    _selectionIndicatorInset,
                                                              ),
                                                              child: indicator,
                                                            );
                                                            selectionStyle =
                                                                const CutoutStyle(
                                                              depth:
                                                                  _selectionCutoutDepth,
                                                              cornerRadius:
                                                                  _selectionCutoutRadius,
                                                              padding:
                                                                  _selectionCutoutPadding,
                                                              offset:
                                                                  _selectionCutoutOffset,
                                                              minThickness:
                                                                  _selectionCutoutThickness,
                                                              cornerClearance:
                                                                  _selectionCutoutCornerClearance,
                                                            );
                                                          }
                                                          final bubbleContentKey =
                                                              message.customProperties?[
                                                                      'id'] ??
                                                                  '${message.user.id}-${message.createdAt.microsecondsSinceEpoch}';
                                                          final bubbleChildren =
                                                              <Widget>[];
                                                          if (quotedModel !=
                                                              null) {
                                                            bubbleChildren.add(
                                                              _QuotedMessagePreview(
                                                                message:
                                                                    quotedModel,
                                                                isSelf:
                                                                    _isQuotedMessageFromSelf(
                                                                  quotedMessage:
                                                                      quotedModel,
                                                                  isGroupChat:
                                                                      isGroupChat,
                                                                  myOccupantId:
                                                                      myOccupantId,
                                                                  currentUserId:
                                                                      currentUserId,
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                          if (isError) {
                                                            bubbleChildren
                                                                .addAll([
                                                              Text(
                                                                l10n.chatErrorLabel,
                                                                style: context
                                                                    .textTheme
                                                                    .small
                                                                    .copyWith(
                                                                  color:
                                                                      textColor,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                              DynamicInlineText(
                                                                key: ValueKey(
                                                                  bubbleContentKey,
                                                                ),
                                                                text: parsedText
                                                                    .body,
                                                                details: [time],
                                                                links:
                                                                    parsedText
                                                                        .links,
                                                                onLinkTap:
                                                                    _handleLinkTap,
                                                                onLinkLongPress:
                                                                    _handleLinkTap,
                                                              ),
                                                            ]);
                                                          } else if (isInviteMessage ||
                                                              isInviteRevocationMessage) {
                                                            const String
                                                                inviteActionFallbackLabel =
                                                                'Join';
                                                            final String
                                                                inviteLabel =
                                                                (message.customProperties?[
                                                                            'inviteLabel']
                                                                        as String?) ??
                                                                    message
                                                                        .text;
                                                            final String
                                                                inviteActionLabel =
                                                                (message.customProperties?[
                                                                            'inviteActionLabel']
                                                                        as String?) ??
                                                                    inviteActionFallbackLabel;
                                                            final String
                                                                inviteRoomName =
                                                                (message.customProperties?['inviteRoomName']
                                                                            as String?)
                                                                        ?.trim() ??
                                                                    '';
                                                            final String
                                                                inviteRoom =
                                                                (message.customProperties?['inviteRoom']
                                                                            as String?)
                                                                        ?.trim() ??
                                                                    '';
                                                            final bool
                                                                inviteActionEnabled =
                                                                !inviteRevoked &&
                                                                    !isInviteRevocationMessage;
                                                            final String
                                                                inviteCardLabel =
                                                                inviteRoomName
                                                                        .isNotEmpty
                                                                    ? inviteRoomName
                                                                    : inviteRoom
                                                                            .isNotEmpty
                                                                        ? inviteRoom
                                                                        : inviteLabel;
                                                            final String
                                                                inviteCardDetail =
                                                                inviteActionEnabled
                                                                    ? inviteActionLabel
                                                                    : inviteLabel;
                                                            bubbleChildren.add(
                                                              DynamicInlineText(
                                                                key: ValueKey(
                                                                  bubbleContentKey,
                                                                ),
                                                                text: TextSpan(
                                                                  text:
                                                                      inviteLabel,
                                                                  style:
                                                                      baseTextStyle,
                                                                ),
                                                                details: [time],
                                                                onLinkTap:
                                                                    _handleLinkTap,
                                                                onLinkLongPress:
                                                                    _handleLinkTap,
                                                              ),
                                                            );
                                                            bubbleChildren.add(
                                                              const SizedBox(
                                                                height:
                                                                    _attachmentPreviewSpacing,
                                                              ),
                                                            );
                                                            bubbleChildren.add(
                                                              _InviteAttachmentCard(
                                                                enabled:
                                                                    inviteActionEnabled,
                                                                label:
                                                                    inviteCardLabel,
                                                                detailLabel:
                                                                    inviteCardDetail,
                                                                actionLabel:
                                                                    inviteActionLabel,
                                                                onPressed: () =>
                                                                    _handleInviteTap(
                                                                  messageModel,
                                                                ),
                                                              ),
                                                            );
                                                          } else {
                                                            final subjectLabel =
                                                                (message.customProperties?[
                                                                        'subjectLabel']
                                                                    as String?);
                                                            final showSubjectBanner =
                                                                (message.customProperties?['showSubject']
                                                                            as bool?) ==
                                                                        true &&
                                                                    subjectLabel !=
                                                                        null;
                                                            if (showSubjectBanner) {
                                                              final String
                                                                  subjectText =
                                                                  subjectLabel;
                                                              final textTheme =
                                                                  Theme.of(
                                                                          context)
                                                                      .textTheme;
                                                              final baseSubjectStyle = textTheme
                                                                      .titleSmall ??
                                                                  textTheme
                                                                      .bodyMedium ??
                                                                  textTheme
                                                                      .bodyLarge ??
                                                                  context
                                                                      .textTheme
                                                                      .lead;
                                                              final subjectStyle =
                                                                  baseSubjectStyle
                                                                      .copyWith(
                                                                color:
                                                                    textColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                height: 1.2,
                                                              );
                                                              final subjectPainter =
                                                                  TextPainter(
                                                                text: TextSpan(
                                                                  text:
                                                                      subjectText,
                                                                  style:
                                                                      subjectStyle,
                                                                ),
                                                                textDirection:
                                                                    Directionality
                                                                        .of(
                                                                  context,
                                                                ),
                                                                textScaler: MediaQuery
                                                                        .maybeTextScalerOf(
                                                                      context,
                                                                    ) ??
                                                                    TextScaler
                                                                        .noScaling,
                                                              )..layout();
                                                              bubbleChildren
                                                                  .add(
                                                                Text(
                                                                  subjectText,
                                                                  style:
                                                                      subjectStyle,
                                                                ),
                                                              );
                                                              bubbleChildren
                                                                  .add(
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .symmetric(
                                                                    vertical:
                                                                        _subjectDividerPadding,
                                                                  ),
                                                                  child:
                                                                      DecoratedBox(
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: context
                                                                          .colorScheme
                                                                          .border,
                                                                    ),
                                                                    child:
                                                                        SizedBox(
                                                                      height:
                                                                          _subjectDividerThickness,
                                                                      width: subjectPainter
                                                                          .width,
                                                                    ),
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                            final rawRenderedText =
                                                                (message.customProperties?[
                                                                            'renderedText']
                                                                        as String?) ??
                                                                    message
                                                                        .text;
                                                            final String
                                                                trimmedRenderedText =
                                                                rawRenderedText
                                                                    .trim();
                                                            final String?
                                                                normalizedHtmlBody =
                                                                HtmlContentCodec
                                                                    .normalizeHtml(
                                                              messageModel
                                                                  .htmlBody,
                                                            );
                                                            final String?
                                                                normalizedHtmlText =
                                                                normalizedHtmlBody ==
                                                                        null
                                                                    ? null
                                                                    : HtmlContentCodec
                                                                        .toPlainText(
                                                                        normalizedHtmlBody,
                                                                      ).trim();
                                                            final bool
                                                                isPlainTextHtml =
                                                                normalizedHtmlBody !=
                                                                        null &&
                                                                    HtmlContentCodec
                                                                        .isPlainTextHtml(
                                                                      normalizedHtmlBody,
                                                                    );
                                                            final bool shouldPreferPlainTextHtml = isPlainTextHtml ||
                                                                (isEmailChat &&
                                                                    self &&
                                                                    normalizedHtmlBody !=
                                                                        null &&
                                                                    normalizedHtmlText
                                                                            ?.isNotEmpty ==
                                                                        true &&
                                                                    trimmedRenderedText
                                                                        .isNotEmpty &&
                                                                    normalizedHtmlText ==
                                                                        trimmedRenderedText);
                                                            final String?
                                                                taskShareText =
                                                                calendarTaskIcs
                                                                    ?.toShareText()
                                                                    .trim();
                                                            final String?
                                                                fragmentFallbackText =
                                                                displayFragment ==
                                                                        null
                                                                    ? null
                                                                    : _calendarFragmentFormatter
                                                                        .describe(
                                                                          displayFragment,
                                                                        )
                                                                        .trim();
                                                            final bool hideFragmentText = fragmentFallbackText !=
                                                                    null &&
                                                                fragmentFallbackText
                                                                    .isNotEmpty &&
                                                                fragmentFallbackText ==
                                                                    trimmedRenderedText;
                                                            final bool
                                                                hideAvailabilityText =
                                                                availabilityMessage !=
                                                                        null &&
                                                                    messageModel
                                                                        .error
                                                                        .isNone;
                                                            final bool
                                                                hideTaskText =
                                                                taskShareText != null &&
                                                                    taskShareText
                                                                        .isNotEmpty &&
                                                                    taskShareText ==
                                                                        trimmedRenderedText;
                                                            final List<
                                                                    InlineSpan>
                                                                fragmentDetails =
                                                                <InlineSpan>[
                                                              time,
                                                              transportDetail,
                                                              if (self &&
                                                                  status !=
                                                                      null)
                                                                status,
                                                              if (verification !=
                                                                  null)
                                                                verification,
                                                            ];
                                                            final List<
                                                                    InlineSpan>
                                                                fragmentFooterDetails =
                                                                hideFragmentText
                                                                    ? fragmentDetails
                                                                    : _emptyInlineSpans;
                                                            final List<
                                                                    InlineSpan>
                                                                availabilityFooterDetails =
                                                                hideAvailabilityText
                                                                    ? fragmentDetails
                                                                    : _emptyInlineSpans;
                                                            final List<
                                                                    InlineSpan>
                                                                taskFooterDetails =
                                                                hideTaskText
                                                                    ? fragmentDetails
                                                                    : _emptyInlineSpans;
                                                            VoidCallback?
                                                                availabilityOnRequest;
                                                            VoidCallback?
                                                                availabilityOnAccept;
                                                            VoidCallback?
                                                                availabilityOnDecline;
                                                            if (availabilityMessage !=
                                                                null) {
                                                              availabilityMessage
                                                                  .map(
                                                                share: (value) {
                                                                  final bool
                                                                      isOwner =
                                                                      availabilityActorId !=
                                                                              null &&
                                                                          _availabilitySenderMatchesClaim(
                                                                            senderJid:
                                                                                availabilityActorId,
                                                                            chatJid:
                                                                                chatEntity?.jid,
                                                                            claimedJid:
                                                                                value.share.overlay.owner,
                                                                            roomState:
                                                                                state.roomState,
                                                                          );
                                                                  if (!isOwner) {
                                                                    final actorId =
                                                                        availabilityActorId;
                                                                    if (actorId !=
                                                                        null) {
                                                                      availabilityOnRequest =
                                                                          () =>
                                                                              _handleAvailabilityRequest(
                                                                                value.share,
                                                                                actorId,
                                                                              );
                                                                    }
                                                                  }
                                                                },
                                                                request:
                                                                    (value) {
                                                                  final requestOwnerJid = value
                                                                      .request
                                                                      .ownerJid
                                                                      ?.trim();
                                                                  final String? ownerJid = requestOwnerJid ==
                                                                              null ||
                                                                          requestOwnerJid
                                                                              .isEmpty
                                                                      ? availabilityShareOwnersById[value
                                                                              .request
                                                                              .shareId] ??
                                                                          availabilityCoordinator
                                                                              ?.ownerJidForShare(
                                                                            value.request.shareId,
                                                                          )
                                                                      : requestOwnerJid;
                                                                  bool isOwner =
                                                                      false;
                                                                  if (ownerJid !=
                                                                          null &&
                                                                      ownerJid
                                                                          .trim()
                                                                          .isNotEmpty &&
                                                                      availabilityActorId !=
                                                                          null) {
                                                                    isOwner =
                                                                        _availabilitySenderMatchesClaim(
                                                                      senderJid:
                                                                          availabilityActorId,
                                                                      chatJid:
                                                                          chatEntity
                                                                              ?.jid,
                                                                      claimedJid:
                                                                          ownerJid,
                                                                      roomState:
                                                                          state
                                                                              .roomState,
                                                                    );
                                                                  } else if (chatEntity
                                                                          ?.type ==
                                                                      ChatType
                                                                          .chat) {
                                                                    final currentActor =
                                                                        availabilityActorId;
                                                                    if (currentActor !=
                                                                        null) {
                                                                      isOwner =
                                                                          !_availabilitySenderMatchesClaim(
                                                                        senderJid:
                                                                            currentActor,
                                                                        chatJid:
                                                                            chatEntity?.jid,
                                                                        claimedJid: value
                                                                            .request
                                                                            .requesterJid,
                                                                        roomState:
                                                                            state.roomState,
                                                                      );
                                                                    }
                                                                  }
                                                                  if (isOwner) {
                                                                    availabilityOnAccept =
                                                                        () =>
                                                                            _handleAvailabilityAccept(
                                                                              value.request,
                                                                              canAddToPersonalCalendar: personalCalendarAvailable,
                                                                              canAddToChatCalendar: chatCalendarAvailable,
                                                                            );
                                                                    availabilityOnDecline =
                                                                        () =>
                                                                            _handleAvailabilityDecline(
                                                                              value.request,
                                                                            );
                                                                  }
                                                                },
                                                                response:
                                                                    (_) {},
                                                              );
                                                            }
                                                            if (availabilityMessage !=
                                                                null) {
                                                              bubbleChildren
                                                                  .add(
                                                                CalendarAvailabilityMessageCard(
                                                                  message:
                                                                      availabilityMessage,
                                                                  footerDetails:
                                                                      availabilityFooterDetails,
                                                                  onRequest:
                                                                      availabilityOnRequest,
                                                                  onAccept:
                                                                      availabilityOnAccept,
                                                                  onDecline:
                                                                      availabilityOnDecline,
                                                                ),
                                                              );
                                                            } else if (calendarTaskIcs !=
                                                                null) {
                                                              bubbleChildren
                                                                  .add(
                                                                chatCalendarBloc ==
                                                                        null
                                                                    ? CalendarFragmentCard(
                                                                        fragment:
                                                                            CalendarFragment.task(
                                                                          task:
                                                                              calendarTaskIcs,
                                                                        ),
                                                                        footerDetails:
                                                                            taskFooterDetails,
                                                                      )
                                                                    : ChatCalendarTaskCard(
                                                                        task:
                                                                            calendarTaskIcs,
                                                                        readOnly:
                                                                            calendarTaskIcsReadOnly,
                                                                        requireImportConfirmation:
                                                                            !self,
                                                                        footerDetails:
                                                                            taskFooterDetails,
                                                                      ),
                                                              );
                                                            } else if (displayFragment !=
                                                                null) {
                                                              final Widget
                                                                  fragmentCard =
                                                                  displayFragment
                                                                      .maybeMap(
                                                                criticalPath:
                                                                    (value) =>
                                                                        ChatCalendarCriticalPathCard(
                                                                  path: value
                                                                      .path,
                                                                  tasks: value
                                                                      .tasks,
                                                                  footerDetails:
                                                                      fragmentFooterDetails,
                                                                ),
                                                                orElse: () =>
                                                                    CalendarFragmentCard(
                                                                  fragment:
                                                                      displayFragment,
                                                                  footerDetails:
                                                                      fragmentFooterDetails,
                                                                ),
                                                              );
                                                              bubbleChildren
                                                                  .add(
                                                                fragmentCard,
                                                              );
                                                            }
                                                            final String?
                                                                metadataIdForCaption =
                                                                attachmentIds
                                                                        .isNotEmpty
                                                                    ? attachmentIds
                                                                        .first
                                                                    : messageModel
                                                                        .fileMetadataID;
                                                            final bool
                                                                shouldRenderTextContent =
                                                                !hideFragmentText &&
                                                                    !hideAvailabilityText &&
                                                                    !hideTaskText;
                                                            final bool
                                                                hasAttachmentCaption =
                                                                shouldRenderTextContent &&
                                                                    trimmedRenderedText
                                                                        .isEmpty &&
                                                                    metadataIdForCaption !=
                                                                        null &&
                                                                    metadataIdForCaption
                                                                        .isNotEmpty;
                                                            if (hasAttachmentCaption) {
                                                              final resolvedMetadataId =
                                                                  metadataIdForCaption;
                                                              bubbleChildren
                                                                  .add(
                                                                StreamBuilder<
                                                                    FileMetadataData?>(
                                                                  stream:
                                                                      _metadataStreamFor(
                                                                    resolvedMetadataId,
                                                                  ),
                                                                  initialData:
                                                                      _metadataInitialFor(
                                                                    resolvedMetadataId,
                                                                  ),
                                                                  builder: (context,
                                                                      snapshot) {
                                                                    const captionPrefix =
                                                                        '📎 ';
                                                                    const fallbackFilename =
                                                                        'Attachment';
                                                                    final metadata =
                                                                        snapshot
                                                                            .data;
                                                                    final filename =
                                                                        metadata?.filename.trim() ??
                                                                            '';
                                                                    final resolvedFilename = filename
                                                                            .isNotEmpty
                                                                        ? filename
                                                                        : fallbackFilename;
                                                                    final sizeBytes =
                                                                        metadata
                                                                            ?.sizeBytes;
                                                                    final sizeLabel = sizeBytes !=
                                                                                null &&
                                                                            sizeBytes >
                                                                                0
                                                                        ? formatBytes(
                                                                            sizeBytes,
                                                                          )
                                                                        : l10n
                                                                            .chatAttachmentUnknownSize;
                                                                    final caption =
                                                                        '$captionPrefix$resolvedFilename ($sizeLabel)';
                                                                    return DynamicInlineText(
                                                                      key: ValueKey(
                                                                          bubbleContentKey),
                                                                      text:
                                                                          TextSpan(
                                                                        text:
                                                                            caption,
                                                                        style:
                                                                            baseTextStyle,
                                                                      ),
                                                                      details: [
                                                                        time,
                                                                        transportDetail,
                                                                        if (self &&
                                                                            status !=
                                                                                null)
                                                                          status,
                                                                        if (verification !=
                                                                            null)
                                                                          verification,
                                                                      ],
                                                                      onLinkTap:
                                                                          _handleLinkTap,
                                                                      onLinkLongPress:
                                                                          _handleLinkTap,
                                                                    );
                                                                  },
                                                                ),
                                                              );
                                                            } else if (normalizedHtmlBody !=
                                                                    null &&
                                                                shouldRenderTextContent &&
                                                                !shouldPreferPlainTextHtml) {
                                                              // Render HTML email content
                                                              final shouldLoadImages = context
                                                                      .read<
                                                                          SettingsCubit>()
                                                                      .state
                                                                      .autoLoadEmailImages ||
                                                                  state
                                                                      .loadedImageMessageIds
                                                                      .contains(
                                                                    messageModel
                                                                        .id,
                                                                  );
                                                              bubbleChildren
                                                                  .add(
                                                                html_widget
                                                                    .Html(
                                                                  key: ValueKey(
                                                                      bubbleContentKey),
                                                                  data: HtmlContentCodec
                                                                      .sanitizeHtml(
                                                                    normalizedHtmlBody,
                                                                  ),
                                                                  extensions: [
                                                                    createEmailImageExtension(
                                                                      shouldLoad:
                                                                          shouldLoadImages,
                                                                      onLoadRequested: messageModel.id ==
                                                                              null
                                                                          ? null
                                                                          : () {
                                                                              context.read<ChatBloc>().add(
                                                                                    ChatEmailImagesLoaded(messageModel.id!),
                                                                                  );
                                                                            },
                                                                    ),
                                                                  ],
                                                                  style: {
                                                                    'body':
                                                                        html_widget
                                                                            .Style(
                                                                      margin: html_widget
                                                                          .Margins
                                                                          .zero,
                                                                      padding: html_widget
                                                                          .HtmlPaddings
                                                                          .zero,
                                                                      color:
                                                                          textColor,
                                                                      fontSize:
                                                                          html_widget
                                                                              .FontSize(
                                                                        baseTextStyle.fontSize ??
                                                                            14.0,
                                                                      ),
                                                                    ),
                                                                    'a': html_widget
                                                                        .Style(
                                                                      color: self
                                                                          ? colors
                                                                              .primaryForeground
                                                                          : colors
                                                                              .primary,
                                                                      textDecoration:
                                                                          TextDecoration
                                                                              .underline,
                                                                    ),
                                                                  },
                                                                  onLinkTap:
                                                                      (url, _,
                                                                          __) {
                                                                    if (url !=
                                                                        null) {
                                                                      _handleLinkTap(
                                                                          url);
                                                                    }
                                                                  },
                                                                ),
                                                              );
                                                              // Add details row below HTML content
                                                              bubbleChildren
                                                                  .add(
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .only(
                                                                          top:
                                                                              4),
                                                                  child:
                                                                      Text.rich(
                                                                    TextSpan(
                                                                      children: [
                                                                        time,
                                                                        const TextSpan(
                                                                            text:
                                                                                ' '),
                                                                        transportDetail,
                                                                        if (self &&
                                                                            status !=
                                                                                null) ...[
                                                                          const TextSpan(
                                                                              text: ' '),
                                                                          status,
                                                                        ],
                                                                        if (verification !=
                                                                            null) ...[
                                                                          const TextSpan(
                                                                              text: ' '),
                                                                          verification,
                                                                        ],
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              );
                                                            } else if (shouldRenderTextContent) {
                                                              bubbleChildren
                                                                  .add(
                                                                DynamicInlineText(
                                                                  key: ValueKey(
                                                                      bubbleContentKey),
                                                                  text:
                                                                      parsedText
                                                                          .body,
                                                                  details: [
                                                                    time,
                                                                    transportDetail,
                                                                    if (self &&
                                                                        status !=
                                                                            null)
                                                                      status,
                                                                    if (verification !=
                                                                        null)
                                                                      verification,
                                                                  ],
                                                                  links:
                                                                      parsedText
                                                                          .links,
                                                                  onLinkTap:
                                                                      _handleLinkTap,
                                                                  onLinkLongPress:
                                                                      _handleLinkTap,
                                                                ),
                                                              );
                                                            }
                                                            if (message.customProperties?[
                                                                    'retracted'] ??
                                                                false) {
                                                              bubbleChildren
                                                                  .add(
                                                                Text(
                                                                  l10n.chatMessageRetracted,
                                                                  style:
                                                                      extraStyle,
                                                                ),
                                                              );
                                                            } else if (message
                                                                        .customProperties?[
                                                                    'edited'] ??
                                                                false) {
                                                              bubbleChildren
                                                                  .add(
                                                                Text(
                                                                  l10n.chatMessageEdited,
                                                                  style:
                                                                      extraStyle,
                                                                ),
                                                              );
                                                            }
                                                          }
                                                          if (attachmentIds
                                                              .isNotEmpty) {
                                                            if (bubbleChildren
                                                                .isNotEmpty) {
                                                              bubbleChildren
                                                                  .add(
                                                                const SizedBox(
                                                                  height:
                                                                      _attachmentPreviewSpacing,
                                                                ),
                                                              );
                                                            }
                                                            final allowAttachmentByTrust =
                                                                _shouldAllowAttachment(
                                                              isSelf: self,
                                                              chat: state.chat,
                                                            );
                                                            final allowAttachmentOnce =
                                                                attachmentsBlockedForChat
                                                                    ? false
                                                                    : _isOneTimeAttachmentAllowed(
                                                                        messageModel
                                                                            .stanzaID,
                                                                      );
                                                            final allowAttachment =
                                                                !attachmentsBlockedForChat &&
                                                                    (allowAttachmentByTrust ||
                                                                        allowAttachmentOnce);
                                                            final autoDownloadSettings = context
                                                                .watch<
                                                                    SettingsCubit>()
                                                                .state
                                                                .attachmentAutoDownloadSettings;
                                                            final chatAutoDownloadAllowed = state
                                                                    .chat
                                                                    ?.attachmentAutoDownload
                                                                    .isAllowed ??
                                                                false;
                                                            final autoDownloadAllowed =
                                                                allowAttachment &&
                                                                    chatAutoDownloadAllowed;
                                                            final emailService =
                                                                RepositoryProvider
                                                                    .of<EmailService?>(
                                                                        context);
                                                            final emailDownloadDelegate =
                                                                isEmailChat &&
                                                                        emailService !=
                                                                            null
                                                                    ? AttachmentDownloadDelegate(
                                                                        () => emailService
                                                                            .downloadFullMessage(
                                                                          messageModel,
                                                                        ),
                                                                      )
                                                                    : null;
                                                            final autoDownloadUserInitiated =
                                                                allowAttachmentOnce;
                                                            for (var index = 0;
                                                                index <
                                                                    attachmentIds
                                                                        .length;
                                                                index += 1) {
                                                              final attachmentId =
                                                                  attachmentIds[
                                                                      index];
                                                              if (index > 0) {
                                                                bubbleChildren
                                                                    .add(
                                                                  const SizedBox(
                                                                    height:
                                                                        _attachmentPreviewSpacing,
                                                                  ),
                                                                );
                                                              }
                                                              bubbleChildren
                                                                  .add(
                                                                ChatAttachmentPreview(
                                                                  stanzaId:
                                                                      messageModel
                                                                          .stanzaID,
                                                                  metadataStream:
                                                                      _metadataStreamFor(
                                                                          attachmentId),
                                                                  initialMetadata:
                                                                      _metadataInitialFor(
                                                                          attachmentId),
                                                                  allowed:
                                                                      allowAttachment,
                                                                  autoDownloadSettings:
                                                                      autoDownloadSettings,
                                                                  autoDownloadAllowed:
                                                                      autoDownloadAllowed,
                                                                  autoDownloadUserInitiated:
                                                                      autoDownloadUserInitiated,
                                                                  downloadDelegate:
                                                                      emailDownloadDelegate,
                                                                  onAllowPressed: allowAttachment
                                                                      ? null
                                                                      : attachmentsBlockedForChat
                                                                          ? null
                                                                          : () => _approveAttachment(
                                                                                message: messageModel,
                                                                                senderJid: messageModel.senderJid,
                                                                                stanzaId: messageModel.stanzaID,
                                                                                isSelf: self,
                                                                                isEmailChat: isEmailChat,
                                                                                senderEmail: state.chat?.emailAddress,
                                                                              ),
                                                                ),
                                                              );
                                                            }
                                                          }
                                                          var bubbleBottomInset =
                                                              0.0;
                                                          if (showCompactReactions) {
                                                            bubbleBottomInset =
                                                                _reactionBubbleInset;
                                                          }
                                                          if (showReplyStrip) {
                                                            bubbleBottomInset =
                                                                math.max(
                                                              bubbleBottomInset,
                                                              _recipientBubbleInset,
                                                            );
                                                          }
                                                          if (showRecipientCutout) {
                                                            bubbleBottomInset =
                                                                math.max(
                                                              bubbleBottomInset,
                                                              _recipientBubbleInset,
                                                            );
                                                          }
                                                          final isRenderableBubble =
                                                              !(isSelectionSpacer ||
                                                                  isEmptyState);
                                                          final requiresAvatarHeadroom =
                                                              isGroupChat &&
                                                                  isRenderableBubble &&
                                                                  !self;
                                                          final hasAvatarSlot =
                                                              requiresAvatarHeadroom &&
                                                                  !chainedPrev;
                                                          EdgeInsetsGeometry
                                                              bubblePadding =
                                                              _bubblePadding;
                                                          if (bubbleBottomInset >
                                                              0) {
                                                            bubblePadding =
                                                                bubblePadding
                                                                    .add(
                                                              EdgeInsets.only(
                                                                bottom:
                                                                    bubbleBottomInset,
                                                              ),
                                                            );
                                                          }
                                                          if (selectionOverlay !=
                                                              null) {
                                                            bubblePadding =
                                                                bubblePadding
                                                                    .add(
                                                              EdgeInsets.only(
                                                                left: self
                                                                    ? _selectionBubbleOutboundSpacing
                                                                    : 0,
                                                                right: self
                                                                    ? 0
                                                                    : _selectionBubbleInboundSpacing,
                                                              ),
                                                            );
                                                            bubblePadding =
                                                                bubblePadding
                                                                    .add(
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                vertical:
                                                                    _selectionBubbleVerticalInset,
                                                              ),
                                                            );
                                                          }
                                                          if (hasAvatarSlot) {
                                                            bubblePadding =
                                                                bubblePadding
                                                                    .add(
                                                              const EdgeInsets
                                                                  .only(
                                                                left:
                                                                    _messageAvatarContentInset,
                                                              ),
                                                            );
                                                          }
                                                          final bubbleBorderRadius =
                                                              _bubbleBorderRadius(
                                                            isSelf: self,
                                                            chainedPrevious:
                                                                chainedPrev,
                                                            chainedNext:
                                                                chainedNext,
                                                            isSelected:
                                                                isSelected,
                                                          );
                                                          final selectionAllowance =
                                                              selectionOverlay !=
                                                                      null
                                                                  ? _selectionOuterInset
                                                                  : 0.0;
                                                          final cappedBubbleWidth =
                                                              math.min(
                                                            bubbleMaxWidth,
                                                            (self
                                                                    ? outboundClampedBubbleWidth
                                                                    : inboundClampedBubbleWidth) +
                                                                selectionAllowance,
                                                          );
                                                          final bubbleConstraints =
                                                              BoxConstraints(
                                                            maxWidth:
                                                                cappedBubbleWidth,
                                                          );
                                                          final bubbleHighlightColor =
                                                              context
                                                                  .colorScheme
                                                                  .primary;
                                                          final bubbleContent =
                                                              Padding(
                                                            padding:
                                                                bubblePadding,
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              spacing: 4,
                                                              children:
                                                                  bubbleChildren,
                                                            ),
                                                          );
                                                          final nextIsTailSpacer =
                                                              next?.customProperties?[
                                                                      'selectionSpacer'] ==
                                                                  true;
                                                          final isLatestBubble =
                                                              isRenderableBubble &&
                                                                  (next ==
                                                                          null ||
                                                                      nextIsTailSpacer);
                                                          final baseOuterBottom =
                                                              isLatestBubble
                                                                  ? 12.0
                                                                  : 2.0;
                                                          var extraOuterBottom =
                                                              0.0;
                                                          if (showCompactReactions) {
                                                            extraOuterBottom =
                                                                math.max(
                                                              extraOuterBottom,
                                                              _reactionCutoutDepth,
                                                            );
                                                          }
                                                          if (showReplyStrip) {
                                                            extraOuterBottom =
                                                                math.max(
                                                              extraOuterBottom,
                                                              _recipientCutoutDepth,
                                                            );
                                                          }
                                                          if (showRecipientCutout) {
                                                            extraOuterBottom =
                                                                math.max(
                                                              extraOuterBottom,
                                                              _recipientCutoutDepth,
                                                            );
                                                          }
                                                          double
                                                              extraOuterLeft =
                                                              0;
                                                          double
                                                              extraOuterRight =
                                                              0;
                                                          if (hasAvatarSlot) {
                                                            final occupantIdCandidate =
                                                                messageModel
                                                                    .occupantID
                                                                    ?.trim();
                                                            final occupantId = occupantIdCandidate !=
                                                                        null &&
                                                                    occupantIdCandidate
                                                                        .isNotEmpty
                                                                ? occupantIdCandidate
                                                                : messageModel
                                                                    .senderJid;
                                                            final occupant = state
                                                                    .roomState
                                                                    ?.occupants[
                                                                occupantId];
                                                            final realJid =
                                                                occupant
                                                                    ?.realJid
                                                                    ?.trim();
                                                            final bareRealJid = realJid ==
                                                                        null ||
                                                                    realJid
                                                                        .isEmpty
                                                                ? null
                                                                : realJid
                                                                        .contains(
                                                                    '/',
                                                                  )
                                                                    ? realJid
                                                                        .split(
                                                                          '/',
                                                                        )
                                                                        .first
                                                                    : realJid;
                                                            final normalizedBareRealJid =
                                                                bareRealJid
                                                                    ?.toLowerCase();
                                                            final senderJid =
                                                                messageModel
                                                                    .senderJid
                                                                    .trim();
                                                            final senderBareJid =
                                                                senderJid
                                                                        .contains(
                                                              '/',
                                                            )
                                                                    ? senderJid
                                                                        .split(
                                                                          '/',
                                                                        )
                                                                        .first
                                                                    : senderJid;
                                                            final normalizedSenderBareJid =
                                                                senderBareJid
                                                                    .toLowerCase();
                                                            final isRoomChat =
                                                                state.roomState !=
                                                                    null;
                                                            final avatarLookupJid = (normalizedBareRealJid !=
                                                                        null &&
                                                                    normalizedBareRealJid
                                                                        .isNotEmpty)
                                                                ? normalizedBareRealJid
                                                                : !isRoomChat &&
                                                                        normalizedSenderBareJid
                                                                            .isNotEmpty
                                                                    ? normalizedSenderBareJid
                                                                    : null;
                                                            final messageAvatarPath =
                                                                avatarLookupJid ==
                                                                        null
                                                                    ? null
                                                                    : rosterAvatarPathsByJid[
                                                                            avatarLookupJid] ??
                                                                        chatAvatarPathsByJid[
                                                                            avatarLookupJid];
                                                            avatarOverlay =
                                                                _MessageAvatar(
                                                              jid: messageModel
                                                                  .senderJid,
                                                              size:
                                                                  _messageAvatarSize,
                                                              avatarPath:
                                                                  messageAvatarPath,
                                                            );
                                                            avatarStyle =
                                                                const CutoutStyle(
                                                              depth:
                                                                  _messageAvatarCutoutDepth,
                                                              cornerRadius:
                                                                  _messageAvatarCutoutRadius,
                                                              padding:
                                                                  _messageAvatarCutoutPadding,
                                                              offset:
                                                                  Offset.zero,
                                                              minThickness:
                                                                  _messageAvatarCutoutMinThickness,
                                                              cornerClearance:
                                                                  _messageAvatarCornerClearance,
                                                              alignment:
                                                                  _messageAvatarCutoutAlignment,
                                                            );
                                                            avatarAnchor =
                                                                ChatBubbleCutoutAnchor
                                                                    .left;
                                                          }
                                                          extraOuterLeft =
                                                              requiresAvatarHeadroom
                                                                  ? _messageAvatarOuterInset
                                                                  : 0;
                                                          final outerPadding =
                                                              EdgeInsets.only(
                                                            top: 2,
                                                            bottom: baseOuterBottom +
                                                                extraOuterBottom,
                                                            left: _messageListHorizontalPadding +
                                                                extraOuterLeft,
                                                            right: _messageListHorizontalPadding +
                                                                extraOuterRight,
                                                          );
                                                          final bubble =
                                                              TweenAnimationBuilder<
                                                                  double>(
                                                            tween:
                                                                Tween<double>(
                                                              begin: 0,
                                                              end: isSelected
                                                                  ? 1.0
                                                                  : 0.0,
                                                            ),
                                                            duration:
                                                                _bubbleFocusDuration,
                                                            curve:
                                                                _bubbleFocusCurve,
                                                            child:
                                                                bubbleContent,
                                                            builder: (
                                                              context,
                                                              shadowValue,
                                                              child,
                                                            ) {
                                                              final bubbleSurface =
                                                                  ChatBubbleSurface(
                                                                isSelf: self,
                                                                backgroundColor:
                                                                    bubbleColor,
                                                                borderColor:
                                                                    borderColor,
                                                                borderRadius:
                                                                    bubbleBorderRadius,
                                                                shadowOpacity:
                                                                    shadowValue,
                                                                shadows:
                                                                    _selectedBubbleShadows(
                                                                  bubbleHighlightColor,
                                                                ),
                                                                bubbleWidthFraction:
                                                                    _cutoutMaxWidthFraction,
                                                                cornerClearance:
                                                                    _bubbleRadius +
                                                                        _reactionCornerClearance,
                                                                body: child!,
                                                                reactionOverlay: showReplyStrip
                                                                    ? _ReplyStrip(
                                                                        participants:
                                                                            replyParticipants,
                                                                        onRecipientTap:
                                                                            (chat) {
                                                                          final chatsCubit =
                                                                              context.read<ChatsCubit?>();
                                                                          if (chatsCubit !=
                                                                              null) {
                                                                            unawaited(
                                                                              chatsCubit.pushChat(jid: chat.jid),
                                                                            );
                                                                          }
                                                                        },
                                                                      )
                                                                    : showCompactReactions
                                                                        ? _ReactionStrip(
                                                                            reactions:
                                                                                reactions,
                                                                            onReactionTap: canReact
                                                                                ? (emoji) => _toggleQuickReaction(
                                                                                      messageModel,
                                                                                      emoji,
                                                                                    )
                                                                                : null,
                                                                          )
                                                                        : null,
                                                                reactionStyle: showReplyStrip
                                                                    ? const CutoutStyle(
                                                                        depth:
                                                                            _recipientCutoutDepth,
                                                                        cornerRadius:
                                                                            _recipientCutoutRadius,
                                                                        padding:
                                                                            _recipientCutoutPadding,
                                                                        offset:
                                                                            _recipientCutoutOffset,
                                                                        minThickness:
                                                                            _recipientCutoutMinThickness,
                                                                      )
                                                                    : showCompactReactions
                                                                        ? const CutoutStyle(
                                                                            depth:
                                                                                _reactionCutoutDepth,
                                                                            cornerRadius:
                                                                                _reactionCutoutRadius,
                                                                            padding:
                                                                                _reactionCutoutPadding,
                                                                            offset:
                                                                                _reactionStripOffset,
                                                                            minThickness:
                                                                                _reactionCutoutMinThickness,
                                                                          )
                                                                        : null,
                                                                recipientOverlay:
                                                                    recipientOverlay,
                                                                recipientStyle:
                                                                    recipientStyle,
                                                                recipientAnchor:
                                                                    recipientAnchor,
                                                                avatarOverlay:
                                                                    avatarOverlay,
                                                                avatarStyle:
                                                                    avatarStyle,
                                                                avatarAnchor:
                                                                    avatarAnchor,
                                                                selectionOverlay:
                                                                    selectionOverlay,
                                                                selectionStyle:
                                                                    selectionStyle,
                                                                selectionFollowsSelfEdge:
                                                                    false,
                                                              );
                                                              return _MessageBubbleRegion(
                                                                messageId:
                                                                    messageModel
                                                                        .stanzaID,
                                                                registry:
                                                                    _bubbleRegionRegistry,
                                                                child:
                                                                    bubbleSurface,
                                                              );
                                                            },
                                                          );
                                                          final baseAlignment = self
                                                              ? Alignment
                                                                  .centerRight
                                                              : Alignment
                                                                  .centerLeft;
                                                          final shadowedBubble =
                                                              ConstrainedBox(
                                                            constraints:
                                                                bubbleConstraints,
                                                            child: bubble,
                                                          );
                                                          final alignedBubble =
                                                              Align(
                                                            alignment:
                                                                baseAlignment,
                                                            child:
                                                                shadowedBubble,
                                                          );
                                                          final canResend =
                                                              message.status ==
                                                                  MessageStatus
                                                                      .failed;
                                                          final canEdit =
                                                              message.status ==
                                                                  MessageStatus
                                                                      .failed;
                                                          final includeSelectAction =
                                                              !_multiSelectActive;
                                                          final isPinned =
                                                              pinnedStanzaIds
                                                                  .contains(
                                                            messageModel
                                                                .stanzaID,
                                                          );
                                                          final pinActionCount =
                                                              canTogglePins
                                                                  ? 1
                                                                  : 0;
                                                          List<GlobalKey>?
                                                              actionButtonKeys;
                                                          if (isSingleSelection) {
                                                            const baseActionCount =
                                                                6;
                                                            final actionCount =
                                                                baseActionCount +
                                                                    pinActionCount +
                                                                    (canResend
                                                                        ? 1
                                                                        : 0) +
                                                                    (canEdit
                                                                        ? 1
                                                                        : 0) +
                                                                    (includeSelectAction
                                                                        ? 1
                                                                        : 0);
                                                            actionButtonKeys =
                                                                List.generate(
                                                                    actionCount,
                                                                    (_) =>
                                                                        GlobalKey());
                                                            _selectionActionButtonKeys
                                                              ..clear()
                                                              ..addAll(
                                                                  actionButtonKeys);
                                                          } else if (_selectedMessageId ==
                                                              messageModel
                                                                  .stanzaID) {
                                                            _selectionActionButtonKeys
                                                                .clear();
                                                          }
                                                          void onReply() {
                                                            context
                                                                .read<
                                                                    ChatBloc>()
                                                                .add(
                                                                  ChatQuoteRequested(
                                                                    messageModel,
                                                                  ),
                                                                );
                                                            _focusNode
                                                                .requestFocus();
                                                            _clearAllSelections();
                                                          }

                                                          VoidCallback?
                                                              onForward;
                                                          if (!(isInviteMessage ||
                                                              inviteRevoked ||
                                                              isInviteRevocationMessage)) {
                                                            onForward = () =>
                                                                _handleForward(
                                                                  messageModel,
                                                                );
                                                          }
                                                          void onCopy() =>
                                                              _copyMessage(
                                                                dashMessage:
                                                                    message,
                                                                model:
                                                                    messageModel,
                                                              );
                                                          void onShare() =>
                                                              _shareMessage(
                                                                dashMessage:
                                                                    message,
                                                                model:
                                                                    messageModel,
                                                              );
                                                          void onAddToCalendar() =>
                                                              _handleAddToCalendar(
                                                                dashMessage:
                                                                    message,
                                                                model:
                                                                    messageModel,
                                                              );
                                                          void onDetails() =>
                                                              _showMessageDetails(
                                                                  message);
                                                          VoidCallback?
                                                              onSelect;
                                                          if (includeSelectAction) {
                                                            onSelect = () =>
                                                                _startMultiSelect(
                                                                  messageModel,
                                                                );
                                                          }
                                                          VoidCallback?
                                                              onResend;
                                                          if (canResend) {
                                                            onResend = () =>
                                                                context
                                                                    .read<
                                                                        ChatBloc>()
                                                                    .add(
                                                                      ChatMessageResendRequested(
                                                                        messageModel,
                                                                      ),
                                                                    );
                                                          }
                                                          VoidCallback? onEdit;
                                                          if (canEdit) {
                                                            onEdit =
                                                                () => unawaited(
                                                                      _handleEditMessage(
                                                                        messageModel,
                                                                      ),
                                                                    );
                                                          }
                                                          VoidCallback?
                                                              onPinToggle;
                                                          if (canTogglePins) {
                                                            onPinToggle = () =>
                                                                context
                                                                    .read<
                                                                        ChatBloc>()
                                                                    .add(
                                                                      ChatMessagePinRequested(
                                                                        message:
                                                                            messageModel,
                                                                        pin:
                                                                            !isPinned,
                                                                      ),
                                                                    );
                                                          }
                                                          VoidCallback?
                                                              onRevokeInvite;
                                                          if (isInviteMessage &&
                                                              self) {
                                                            onRevokeInvite =
                                                                () => context
                                                                    .read<
                                                                        ChatBloc>()
                                                                    .add(
                                                                      ChatInviteRevocationRequested(
                                                                        messageModel,
                                                                      ),
                                                                    );
                                                          }

                                                          final actionBar =
                                                              _MessageActionBar(
                                                            onReply: onReply,
                                                            onForward:
                                                                onForward,
                                                            onCopy: onCopy,
                                                            onShare: onShare,
                                                            onAddToCalendar:
                                                                onAddToCalendar,
                                                            onDetails:
                                                                onDetails,
                                                            onSelect: onSelect,
                                                            onResend: onResend,
                                                            onEdit: onEdit,
                                                            onPinToggle:
                                                                onPinToggle,
                                                            isPinned: isPinned,
                                                            hitRegionKeys:
                                                                actionButtonKeys,
                                                            onRevokeInvite:
                                                                onRevokeInvite,
                                                          );
                                                          if (isSingleSelection) {
                                                            _activeSelectionExtrasKey ??=
                                                                GlobalKey();
                                                            _scheduleSelectionAutoscroll();
                                                            _requestSelectionControlsMeasurement();
                                                          } else if (_activeSelectionExtrasKey !=
                                                                  null &&
                                                              _selectedMessageId ==
                                                                  messageModel
                                                                      .stanzaID) {
                                                            _activeSelectionExtrasKey =
                                                                null;
                                                          }
                                                          final attachmentsKey =
                                                              isSingleSelection
                                                                  ? _activeSelectionExtrasKey
                                                                  : null;
                                                          final recipientHeadroom =
                                                              showRecipientCutout
                                                                  ? _recipientCutoutDepth
                                                                  : 0.0;
                                                          final attachmentTopPadding =
                                                              (isSingleSelection
                                                                      ? _selectionAttachmentSelectedGap
                                                                      : _selectionAttachmentBaseGap) +
                                                                  recipientHeadroom;
                                                          final attachmentBottomPadding =
                                                              _selectionExtrasViewportGap +
                                                                  (showReactionManager
                                                                      ? _reactionManagerShadowGap
                                                                      : 0);
                                                          final attachmentPadding =
                                                              EdgeInsets.only(
                                                            top:
                                                                attachmentTopPadding,
                                                            bottom:
                                                                attachmentBottomPadding,
                                                            left:
                                                                _chatHorizontalPadding,
                                                            right:
                                                                _chatHorizontalPadding,
                                                          );
                                                          final reactionManager =
                                                              showReactionManager
                                                                  ? KeyedSubtree(
                                                                      key: _reactionManagerKey ??=
                                                                          GlobalKey(),
                                                                      child:
                                                                          _ReactionManager(
                                                                        reactions:
                                                                            reactions,
                                                                        onToggle:
                                                                            (emoji) =>
                                                                                _toggleQuickReaction(
                                                                          messageModel,
                                                                          emoji,
                                                                        ),
                                                                        onAddCustom:
                                                                            () =>
                                                                                _handleReactionSelection(
                                                                          messageModel,
                                                                        ),
                                                                      ),
                                                                    )
                                                                  : null;
                                                          final selectionExtrasKey =
                                                              ValueKey(
                                                            'selection-extras-${messageModel.stanzaID}-${isSingleSelection ? 'open' : 'closed'}',
                                                          );
                                                          final selectionExtras =
                                                              isSingleSelection
                                                                  ? KeyedSubtree(
                                                                      key:
                                                                          selectionExtrasKey,
                                                                      child:
                                                                          KeyedSubtree(
                                                                        key:
                                                                            attachmentsKey,
                                                                        child:
                                                                            Align(
                                                                          alignment: self
                                                                              ? Alignment.centerRight
                                                                              : Alignment.centerLeft,
                                                                          child:
                                                                              SizedBox(
                                                                            width:
                                                                                selectionExtrasMaxWidth,
                                                                            child:
                                                                                Padding(
                                                                              padding: attachmentPadding,
                                                                              child: Column(
                                                                                mainAxisSize: MainAxisSize.min,
                                                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                                                children: [
                                                                                  actionBar,
                                                                                  if (reactionManager != null)
                                                                                    const SizedBox(
                                                                                      height: 20,
                                                                                    ),
                                                                                  if (reactionManager != null) reactionManager,
                                                                                ],
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    )
                                                                  : KeyedSubtree(
                                                                      key:
                                                                          selectionExtrasKey,
                                                                      child: const SizedBox
                                                                          .shrink(),
                                                                    );
                                                          final attachments =
                                                              AnimatedSwitcher(
                                                            duration:
                                                                _bubbleFocusDuration,
                                                            reverseDuration:
                                                                _bubbleFocusDuration,
                                                            switchInCurve:
                                                                _bubbleFocusCurve,
                                                            switchOutCurve:
                                                                Curves
                                                                    .easeInCubic,
                                                            layoutBuilder: (
                                                              currentChild,
                                                              previousChildren,
                                                            ) {
                                                              return Stack(
                                                                clipBehavior:
                                                                    Clip.none,
                                                                alignment:
                                                                    Alignment
                                                                        .topCenter,
                                                                children: [
                                                                  ...previousChildren,
                                                                  if (currentChild !=
                                                                      null)
                                                                    currentChild,
                                                                ],
                                                              );
                                                            },
                                                            transitionBuilder:
                                                                (child,
                                                                    animation) {
                                                              final curvedAnimation =
                                                                  CurvedAnimation(
                                                                parent:
                                                                    animation,
                                                                curve:
                                                                    _bubbleFocusCurve,
                                                                reverseCurve: Curves
                                                                    .easeInCubic,
                                                              );
                                                              final slideAnimation =
                                                                  Tween<Offset>(
                                                                begin:
                                                                    const Offset(
                                                                        0,
                                                                        -0.18),
                                                                end:
                                                                    Offset.zero,
                                                              ).animate(
                                                                curvedAnimation,
                                                              );
                                                              return ClipRect(
                                                                child:
                                                                    FadeTransition(
                                                                  opacity:
                                                                      curvedAnimation,
                                                                  child:
                                                                      SizeTransition(
                                                                    sizeFactor:
                                                                        curvedAnimation,
                                                                    axisAlignment:
                                                                        -1,
                                                                    child:
                                                                        SlideTransition(
                                                                      position:
                                                                          slideAnimation,
                                                                      child:
                                                                          child,
                                                                    ),
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                            child:
                                                                selectionExtras,
                                                          );
                                                          final messageRowAlignment =
                                                              self
                                                                  ? Alignment
                                                                      .centerRight
                                                                  : Alignment
                                                                      .centerLeft;
                                                          final attachmentsAligned =
                                                              SizedBox(
                                                            width:
                                                                messageRowMaxWidth,
                                                            child: Align(
                                                              alignment:
                                                                  messageRowAlignment,
                                                              child:
                                                                  attachments,
                                                            ),
                                                          );
                                                          final messageKey =
                                                              _messageKeys
                                                                  .putIfAbsent(
                                                            messageModel
                                                                .stanzaID,
                                                            () => GlobalKey(),
                                                          );
                                                          final bubbleDisplay =
                                                              isRenderableBubble
                                                                  ? _MessageArrivalAnimator(
                                                                      key:
                                                                          ValueKey(
                                                                        'arrival-${messageModel.stanzaID}',
                                                                      ),
                                                                      animate:
                                                                          _shouldAnimateMessage(
                                                                        messageModel,
                                                                      ),
                                                                      isSelf:
                                                                          self,
                                                                      child:
                                                                          alignedBubble,
                                                                    )
                                                                  : alignedBubble;
                                                          final isDesktopPlatform =
                                                              EnvScope.maybeOf(
                                                                          context)
                                                                      ?.isDesktopPlatform ??
                                                                  false;
                                                          final selectableBubble =
                                                              GestureDetector(
                                                            behavior:
                                                                HitTestBehavior
                                                                    .translucent,
                                                            onTap: () {
                                                              if (_multiSelectActive) {
                                                                return;
                                                              }
                                                              if (isSingleSelection) {
                                                                _clearMessageSelection();
                                                              }
                                                            },
                                                            onLongPress: widget
                                                                        .readOnly ||
                                                                    isDesktopPlatform
                                                                ? null
                                                                : () =>
                                                                    _toggleMessageSelection(
                                                                      messageModel,
                                                                    ),
                                                            onSecondaryTapUp:
                                                                isDesktopPlatform &&
                                                                        !widget
                                                                            .readOnly
                                                                    ? (_) =>
                                                                        _toggleMessageSelection(
                                                                          messageModel,
                                                                        )
                                                                    : null,
                                                            child:
                                                                bubbleDisplay,
                                                          );
                                                          final bubbleStack =
                                                              Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .center,
                                                            children: [
                                                              selectableBubble,
                                                            ],
                                                          );
                                                          final shouldShowSenderLabel =
                                                              isRenderableBubble &&
                                                                  !_chatMessagesShouldChain(
                                                                    message,
                                                                    previous,
                                                                  );
                                                          Widget
                                                              bubbleWithSlack =
                                                              bubbleStack;
                                                          if (shouldShowSenderLabel) {
                                                            final double
                                                                senderLabelLeftInset =
                                                                !self &&
                                                                        hasAvatarSlot
                                                                    ? _messageAvatarContentInset +
                                                                        _bubblePadding
                                                                            .left
                                                                    : _senderLabelNoInset;
                                                            bubbleWithSlack =
                                                                Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              crossAxisAlignment: self
                                                                  ? CrossAxisAlignment
                                                                      .end
                                                                  : CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                _MessageSenderLabel(
                                                                  user: message
                                                                      .user,
                                                                  isSelf: self,
                                                                  selfLabel: l10n
                                                                      .chatSenderYou,
                                                                  leftInset:
                                                                      senderLabelLeftInset,
                                                                ),
                                                                bubbleStack,
                                                              ],
                                                            );
                                                          }
                                                          bubbleWithSlack =
                                                              ConstrainedBox(
                                                            constraints:
                                                                BoxConstraints(
                                                              maxWidth:
                                                                  bubbleMaxWidth,
                                                            ),
                                                            child:
                                                                bubbleWithSlack,
                                                          );
                                                          bubbleWithSlack =
                                                              Align(
                                                            alignment: self
                                                                ? Alignment
                                                                    .centerRight
                                                                : Alignment
                                                                    .centerLeft,
                                                            child:
                                                                bubbleWithSlack,
                                                          );
                                                          final messageBody =
                                                              Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .center,
                                                            children: [
                                                              bubbleWithSlack,
                                                              attachmentsAligned,
                                                            ],
                                                          );
                                                          final bubbleResizeDuration =
                                                              isSingleSelection
                                                                  ? _bubbleFocusDuration
                                                                  : _bubbleSizeSnapDuration;
                                                          final bubbleResizeCurve =
                                                              isSingleSelection
                                                                  ? _bubbleFocusCurve
                                                                  : Curves
                                                                      .linear;
                                                          final Widget
                                                              animatedMessage =
                                                              AxiAnimatedSize(
                                                            duration:
                                                                bubbleResizeDuration,
                                                            reverseDuration:
                                                                bubbleResizeDuration,
                                                            curve:
                                                                bubbleResizeCurve,
                                                            alignment: Alignment
                                                                .topCenter,
                                                            clipBehavior:
                                                                Clip.none,
                                                            child: messageBody,
                                                          );
                                                          final alignedMessage =
                                                              SizedBox(
                                                            width:
                                                                messageRowMaxWidth,
                                                            child:
                                                                AnimatedAlign(
                                                              duration:
                                                                  _bubbleFocusDuration,
                                                              curve:
                                                                  _bubbleFocusCurve,
                                                              alignment:
                                                                  messageRowAlignment,
                                                              child:
                                                                  animatedMessage,
                                                            ),
                                                          );
                                                          return KeyedSubtree(
                                                            key: messageKey,
                                                            child: Padding(
                                                              padding:
                                                                  outerPadding,
                                                              child:
                                                                  alignedMessage,
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                      messageListOptions:
                                                          dashMessageListOptions,
                                                      readOnly: true,
                                                    ),
                                                  ),
                                                  if (_selectedMessageId !=
                                                      null)
                                                    Positioned.fill(
                                                      child: Listener(
                                                        behavior:
                                                            HitTestBehavior
                                                                .translucent,
                                                        onPointerDown: (event) {
                                                          _selectionDismissPointer =
                                                              event.pointer;
                                                          _selectionDismissOrigin =
                                                              event.position;
                                                          _selectionDismissMoved =
                                                              false;
                                                        },
                                                        onPointerMove: (event) {
                                                          final origin =
                                                              _selectionDismissOrigin;
                                                          if (origin == null ||
                                                              _selectionDismissMoved) {
                                                            return;
                                                          }
                                                          final delta =
                                                              (event.position -
                                                                      origin)
                                                                  .distance;
                                                          if (delta >
                                                              kTouchSlop) {
                                                            _selectionDismissMoved =
                                                                true;
                                                          }
                                                        },
                                                        onPointerCancel:
                                                            (event) {
                                                          _selectionDismissPointer =
                                                              null;
                                                          _selectionDismissOrigin =
                                                              null;
                                                          _selectionDismissMoved =
                                                              false;
                                                        },
                                                        onPointerUp: (event) {
                                                          final active =
                                                              _selectionDismissPointer;
                                                          if (active !=
                                                                  event
                                                                      .pointer ||
                                                              _selectionDismissMoved) {
                                                            return;
                                                          }
                                                          _selectionDismissPointer =
                                                              null;
                                                          _selectionDismissOrigin =
                                                              null;
                                                          _selectionDismissMoved =
                                                              false;
                                                          scheduleMicrotask(() {
                                                            if (!mounted) {
                                                              return;
                                                            }
                                                            _maybeDismissSelection(
                                                              event.position,
                                                            );
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                  if (loadingMessages)
                                                    IgnorePointer(
                                                      child: Align(
                                                        alignment:
                                                            Alignment.center,
                                                        child: SizedBox(
                                                          width:
                                                              _messageLoadingSpinnerSize,
                                                          height:
                                                              _messageLoadingSpinnerSize,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth:
                                                                _messageLoadingStrokeWidth,
                                                            color: context
                                                                .colorScheme
                                                                .primary,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (typingVisible)
                                                    Positioned(
                                                      left: 0,
                                                      right: 0,
                                                      bottom:
                                                          _typingIndicatorBottomInset,
                                                      child: IgnorePointer(
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal:
                                                                _messageListHorizontalPadding,
                                                          ),
                                                          child: Align(
                                                            alignment: Alignment
                                                                .bottomCenter,
                                                            child: DecoratedBox(
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: context
                                                                    .colorScheme
                                                                    .card,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                  _typingIndicatorRadius,
                                                                ),
                                                                border:
                                                                    Border.all(
                                                                  color: context
                                                                      .colorScheme
                                                                      .border,
                                                                ),
                                                              ),
                                                              child: Padding(
                                                                padding:
                                                                    _typingIndicatorPadding,
                                                                child:
                                                                    _TypingIndicatorPill(
                                                                  participants:
                                                                      typingAvatars,
                                                                  avatarPaths:
                                                                      typingAvatarPaths,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          bottomSection,
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          );
                          final Widget overlayChild = switch (_chatRoute) {
                            _ChatRoute.main => const SizedBox.expand(),
                            _ChatRoute.search => const _ChatSearchOverlay(
                                panel: _ChatSearchPanel(),
                              ),
                            _ChatRoute.details => const _ChatDetailsOverlay(),
                            _ChatRoute.settings => _ChatSettingsOverlay(
                                state: state,
                                onViewFilterChanged: _setViewFilter,
                                onToggleNotifications: _toggleNotifications,
                                onSpamToggle: (sendToSpam) => _handleSpamToggle(
                                  sendToSpam: sendToSpam,
                                ),
                                isChatBlocked: isChatBlocked,
                                blocklistEntry: chatBlocklistEntry,
                                blockAddress: blockAddress,
                              ),
                            _ChatRoute.gallery => _ChatGalleryOverlay(
                                chat: chatEntity,
                              ),
                            _ChatRoute.calendar => _ChatCalendarOverlay(
                                key: ValueKey(
                                  '$_chatCalendarPanelKeyPrefix${chatEntity?.jid ?? _chatPanelKeyFallback}',
                                ),
                                chat: chatEntity,
                                calendarAvailable: chatCalendarAvailable,
                                participants: chatCalendarParticipants,
                                avatarPaths: chatCalendarAvatarPaths,
                                calendarBloc: chatCalendarBloc,
                              ),
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
                          final Widget overlayStack = PageTransitionSwitcher(
                            reverse: isLeavingToMain,
                            duration: context
                                .watch<SettingsCubit>()
                                .animationDuration,
                            layoutBuilder: (entries) => Stack(
                              fit: StackFit.expand,
                              children: entries,
                            ),
                            transitionBuilder: (
                              child,
                              primaryAnimation,
                              secondaryAnimation,
                            ) {
                              final bool isExiting = child.key != chatRouteKey;
                              final Animation<double> enterAnimation =
                                  CurvedAnimation(
                                parent: primaryAnimation,
                                curve: _chatOverlayFadeCurve,
                              );
                              final Animation<double> exitAnimation =
                                  CurvedAnimation(
                                parent: isLeavingToMain
                                    ? primaryAnimation
                                    : secondaryAnimation,
                                curve: _chatOverlayFadeCurve,
                              );
                              if (isExiting) {
                                final Widget exiting = isOverlaySwap
                                    ? child
                                    : FadeTransition(
                                        opacity: exitAnimation,
                                        child: child,
                                      );
                                return TickerMode(
                                  enabled: false,
                                  child: IgnorePointer(
                                    ignoring: true,
                                    child: ExcludeSemantics(
                                      excluding: true,
                                      child: exiting,
                                    ),
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
                              return TickerMode(
                                enabled: !isExiting,
                                child: IgnorePointer(
                                  ignoring: isExiting,
                                  child: ExcludeSemantics(
                                    excluding: isExiting,
                                    child: entering,
                                  ),
                                ),
                              );
                            },
                            child: KeyedSubtree(
                              key: chatRouteKey,
                              child: overlayChild,
                            ),
                          );
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              chatMainBody,
                              overlayStack,
                            ],
                          );
                        },
                      ),
                    );
                  },
                );
                final Widget content = chatCalendarBloc == null
                    ? scaffold
                    : BlocProvider<ChatCalendarBloc>.value(
                        value: chatCalendarBloc,
                        child: scaffold,
                      );
                return Container(
                  decoration: BoxDecoration(
                    color: context.colorScheme.background,
                    border: Border(
                      left: BorderSide(color: context.colorScheme.border),
                    ),
                  ),
                  child: content,
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<String?> _pickEmoji() async {
    if (!mounted) return null;
    return showAdaptiveBottomSheet<String>(
      context: context,
      dialogMaxWidth: 420,
      surfacePadding: EdgeInsets.zero,
      builder: (sheetContext) {
        final picker = SizedBox(
          height: 320,
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

  Future<void> _handleReactionSelection(Message message) async {
    final selected = await _pickEmoji();
    if (!mounted || selected == null || selected.isEmpty) return;
    _toggleQuickReaction(message, selected);
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

  bool _shouldPromptEmailForwarding({
    required chat_models.Chat target,
    required List<Message> messages,
  }) {
    if (!target.supportsEmail) {
      return false;
    }
    return messages.any((message) => message.deltaMsgId != null);
  }

  Future<EmailForwardingMode?> _resolveForwardingMode({
    required chat_models.Chat target,
    required List<Message> messages,
  }) async {
    if (!_shouldPromptEmailForwarding(
      target: target,
      messages: messages,
    )) {
      return EmailForwardingMode.original;
    }
    if (!mounted) return null;
    return _showEmailForwardDialog();
  }

  Future<EmailForwardingMode?> _showEmailForwardDialog() async {
    final l10n = context.l10n;
    return showShadDialog<EmailForwardingMode>(
      context: context,
      builder: (dialogContext) => ShadDialog(
        title: Text(
          l10n.chatForwardEmailWarningTitle,
          style: dialogContext.modalHeaderTextStyle,
        ),
        actions: [
          ShadButton.ghost(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ).withTapBounce(),
          ShadButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(EmailForwardingMode.safe),
            child: Text(l10n.chatForwardEmailOptionSafe),
          ).withTapBounce(),
          ShadButton.destructive(
            onPressed: () =>
                Navigator.of(dialogContext).pop(EmailForwardingMode.original),
            child: Text(l10n.chatForwardEmailOptionOriginal),
          ).withTapBounce(),
        ],
        child: Text(l10n.chatForwardEmailWarningMessage),
      ),
    );
  }

  Future<void> _handleForward(Message message) async {
    _clearAllSelections();
    final target = await _selectForwardTarget();
    if (!mounted || target == null) return;
    final forwardingMode = await _resolveForwardingMode(
      target: target,
      messages: [message],
    );
    if (!mounted || forwardingMode == null) return;
    context.read<ChatBloc>().add(
          ChatMessageForwardRequested(
            message: message,
            target: target,
            forwardingMode: forwardingMode,
          ),
        );
  }

  Future<void> _handleInviteTap(Message message) async {
    final l10n = context.l10n;
    final data = message.pseudoMessageData ?? const {};
    final roomJid = data['roomJid'] as String?;
    final roomName = (data['roomName'] as String?)?.trim();
    final invitee = data['invitee'] as String?;
    if (roomJid == null) return;
    final myJid = context.read<XmppService>().myJid;
    final roomState = context.read<XmppService>().roomStateFor(roomJid);
    if (roomState?.myOccupantId != null) {
      _showSnackbar(l10n.chatInviteAlreadyInRoom);
      return;
    }
    if (invitee != null &&
        myJid != null &&
        mox.JID.fromString(invitee).toBare().toString() !=
            mox.JID.fromString(myJid).toBare().toString()) {
      _showSnackbar(l10n.chatInviteWrongAccount);
      return;
    }
    const unknownRoomFallbackLabel = 'group chat';
    final resolvedRoomName =
        roomName?.isNotEmpty == true ? roomName! : unknownRoomFallbackLabel;
    const inviteConfirmTitle = 'Accept invite?';
    final inviteConfirmMessage = "Join '$resolvedRoomName'?";
    const inviteConfirmLabel = 'Accept';
    final accepted = await confirm(
      context,
      title: inviteConfirmTitle,
      message: inviteConfirmMessage,
      confirmLabel: inviteConfirmLabel,
      destructiveConfirm: false,
    );
    if (!mounted || accepted != true) return;
    context.read<ChatBloc>().add(ChatInviteJoinRequested(message));
    if (context.read<ChatsCubit?>() != null) {
      await context.read<ChatsCubit>().openChat(jid: roomJid);
    }
  }

  Future<void> _shareMessage({
    required ChatMessage dashMessage,
    required Message model,
  }) async {
    final l10n = context.l10n;
    final content = _plainTextForMessage(
      dashMessage: dashMessage,
      model: model,
    ).trim();
    if (content.isEmpty) {
      _showSnackbar(l10n.chatShareNoText);
      return;
    }
    await Share.share(
      content,
      subject: l10n.chatShareSubjectPrefix(
        context.read<ChatBloc>().state.chat?.title ??
            l10n.chatShareFallbackSubject,
      ),
    );
    _clearAllSelections();
  }

  Future<void> _copyMessage({
    required ChatMessage dashMessage,
    required Message model,
  }) async {
    final copiedText = _plainTextForMessage(
      dashMessage: dashMessage,
      model: model,
    );
    if (copiedText.isEmpty) return;
    await Clipboard.setData(
      ClipboardData(text: copiedText),
    );
    _clearAllSelections();
  }

  Future<void> _handleAddToCalendar({
    required ChatMessage dashMessage,
    required Message model,
  }) async {
    final l10n = context.l10n;
    _clearAllSelections();
    final seededText = _plainTextForMessage(
      dashMessage: dashMessage,
      model: model,
    ).trim();
    if (seededText.isEmpty) {
      _showSnackbar(l10n.chatCalendarNoText);
      return;
    }
    if (context.read<CalendarBloc?>() == null) {
      _showSnackbar(l10n.chatCalendarUnavailable);
      return;
    }
    final calendarText = await _pickCalendarSeed(seededText);
    if (!mounted || calendarText == null) {
      return;
    }

    final locationHelper = LocationAutocompleteHelper.fromState(
        context.read<CalendarBloc>().state);

    await showQuickAddModal(
      context: context,
      prefilledText: calendarText,
      locationHelper: locationHelper,
      locate: context.read,
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

  Future<String?> _pickCalendarSeed(String seededText) async {
    final trimmed = seededText.trim();
    if (trimmed.isEmpty) return null;
    final selection = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _CalendarTextSelectionDialog(
        initialText: trimmed,
      ),
    );
    if (!mounted) return null;
    if (selection == null) return null;
    final normalized = selection.trim();
    return normalized.isEmpty ? null : normalized;
  }

  String _displayTextForMessage(Message message) {
    final body = message.plainText.trim();
    if (message.error.isNotNone) {
      final label = message.error.asString;
      return body.isEmpty ? label : '$label: "$body"';
    }
    return body;
  }

  String _plainTextForMessage({
    required ChatMessage dashMessage,
    required Message model,
  }) {
    final plainText = model.plainText.trim();
    if (plainText.isNotEmpty) return plainText;
    return dashMessage.text.trim();
  }

  String? _recipientVisibilityLabel({
    required chat_models.Chat? chat,
    required List<ComposerRecipient> recipients,
  }) {
    if (chat == null) return null;
    final included =
        recipients.where((recipient) => recipient.included).toList();
    if (included.length <= 1) return null;
    final hasEmailRecipient = included.any((recipient) {
      final targetChat = recipient.target.chat;
      if (targetChat != null) {
        return targetChat.supportsEmail;
      }
      final address = recipient.target.address;
      return address != null && address.trim().isNotEmpty;
    });
    if (!hasEmailRecipient) return null;
    final shouldFanOut = _shouldFanOutRecipients(
      chat: chat,
      recipients: included,
    );
    return shouldFanOut
        ? _recipientVisibilityBccLabel
        : _recipientVisibilityCcLabel;
  }

  bool _shouldFanOutRecipients({
    required chat_models.Chat chat,
    required List<ComposerRecipient> recipients,
  }) {
    if (recipients.isEmpty) return false;
    if (recipients.length == 1) {
      final targetChat = recipients.single.target.chat;
      if (targetChat != null && targetChat.jid == chat.jid) {
        return false;
      }
    }
    return true;
  }

  String _joinedMessageText(List<Message> messages) {
    final buffer = StringBuffer();
    for (final message in messages) {
      final text = _displayTextForMessage(message);
      if (text.isEmpty) continue;
      if (buffer.isNotEmpty) buffer.write('\n\n');
      buffer.write(text);
    }
    return buffer.toString();
  }

  Future<void> _copySelectedMessages(List<Message> messages) async {
    final l10n = context.l10n;
    final joined = _joinedMessageText(messages);
    if (joined.isEmpty) {
      _showSnackbar(l10n.chatCopyNoText);
      return;
    }
    await Clipboard.setData(ClipboardData(text: joined));
    _clearMultiSelection();
  }

  Future<void> _shareSelectedMessages(List<Message> messages) async {
    final l10n = context.l10n;
    final joined = _joinedMessageText(messages).trim();
    if (joined.isEmpty) {
      _showSnackbar(l10n.chatShareSelectedNoText);
      return;
    }
    await Share.share(
      joined,
      subject: l10n.chatShareSubjectPrefix(
        context.read<ChatBloc>().state.chat?.title ??
            l10n.chatShareFallbackSubject,
      ),
    );
    _clearMultiSelection();
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
    final forwardingMode = await _resolveForwardingMode(
      target: target,
      messages: candidates,
    );
    if (!mounted || forwardingMode == null) return;
    for (final message in candidates) {
      context.read<ChatBloc>().add(
            ChatMessageForwardRequested(
              message: message,
              target: target,
              forwardingMode: forwardingMode,
            ),
          );
    }
    _clearMultiSelection();
  }

  Future<void> _addSelectedToCalendar(List<Message> messages) async {
    final l10n = context.l10n;
    final joined = _joinedMessageText(messages).trim();
    if (joined.isEmpty) {
      _showSnackbar(l10n.chatAddToCalendarNoText);
      return;
    }
    if (context.read<CalendarBloc?>() == null) {
      _showSnackbar(l10n.chatCalendarUnavailable);
      return;
    }
    final calendarText = await _pickCalendarSeed(joined);
    if (!mounted || calendarText == null) {
      return;
    }
    final locationHelper = LocationAutocompleteHelper.fromState(
        context.read<CalendarBloc>().state);
    await showQuickAddModal(
      context: context,
      prefilledText: calendarText,
      locationHelper: locationHelper,
      locate: context.read,
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

  void _showMessageDetails(ChatMessage message) {
    final detailId = message.customProperties?['id'];
    if (detailId == null) return;
    context.read<ChatBloc>().add(ChatMessageFocused(detailId));
    _setChatRoute(_ChatRoute.details);
  }

  void _syncChatCalendarRoute() {
    final bool openChatCalendar =
        context.read<ChatsCubit?>()?.state.openChatCalendar ?? false;
    if (openChatCalendar && !_chatRoute.isCalendar) {
      _showChatCalendarRoute();
      return;
    }
    if (!openChatCalendar && _chatRoute.isCalendar) {
      _returnToMainRoute();
    }
  }

  void _setChatRoute(_ChatRoute nextRoute) {
    if (!mounted) return;
    setState(() {
      _previousChatRoute = _chatRoute;
      _chatRoute = nextRoute;
      _pinnedPanelVisible = false;
      if (_focusNode.hasFocus) {
        _focusNode.unfocus();
      }
    });
    if (!nextRoute.isDetails) {
      if (context.read<SettingsCubit>().animationDuration == Duration.zero) {
        context.read<ChatBloc>().add(const ChatMessageFocused(null));
      } else {
        Future.delayed(
          context.read<SettingsCubit>().animationDuration,
          () {
            if (!mounted || _chatRoute.isDetails) return;
            context.read<ChatBloc>().add(const ChatMessageFocused(null));
          },
        );
      }
    }
    if (!nextRoute.isSearch) {
      context.read<ChatSearchCubit?>()?.setActive(false);
    }
    context.read<ChatsCubit>().setChatCalendarOpen(open: nextRoute.isCalendar);
  }

  void _returnToMainRoute() {
    _setChatRoute(_ChatRoute.main);
  }

  void _openChatSearch() {
    if (!mounted) return;
    if (_chatRoute.isSearch) {
      return;
    }
    _setChatRoute(_ChatRoute.search);
  }

  void _showChatCalendarRoute() {
    _setChatRoute(_ChatRoute.calendar);
  }

  void _openChatCalendar() {
    _setChatRoute(_ChatRoute.calendar);
  }

  void _openChatAttachments() {
    if (!mounted) return;
    final chat = context.read<ChatBloc>().state.chat;
    if (chat == null) return;
    if (_chatRoute.isGallery) {
      _setChatRoute(_ChatRoute.main);
      return;
    }
    _setChatRoute(_ChatRoute.gallery);
  }

  void _togglePinnedMessages() {
    if (!mounted) return;
    final bool isChatCalendarOpen =
        context.read<ChatsCubit>().state.openChatCalendar;
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

  List<String> _resolveChatCalendarParticipants({
    required chat_models.Chat? chat,
    required RoomState? roomState,
    required String? currentUserId,
  }) {
    if (chat == null) {
      return const <String>[];
    }
    final participants = <String>[];
    final seen = <String>{};
    void addParticipant(String? value) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        return;
      }
      final normalized = trimmed.toLowerCase();
      if (seen.contains(normalized)) {
        return;
      }
      seen.add(normalized);
      participants.add(trimmed);
    }

    if (chat.type == ChatType.groupChat) {
      final room = roomState;
      if (room != null) {
        final eligible = <Occupant>[
          ...room.owners,
          ...room.admins,
          ...room.members,
        ];
        for (final occupant in eligible) {
          final realJid = occupant.realJid?.trim();
          addParticipant(
            realJid?.isNotEmpty == true ? realJid : occupant.occupantId,
          );
        }
      }
      addParticipant(currentUserId);
      return participants;
    }

    addParticipant(currentUserId);
    addParticipant(chat.remoteJid);
    return participants;
  }

  Future<chat_models.Chat?> _selectForwardTarget() async {
    if (!mounted) return null;
    final l10n = context.l10n;
    final options =
        (context.read<ChatsCubit?>()?.state.items ?? const <chat_models.Chat>[])
            .where((chat) => chat.jid != context.read<ChatBloc>().jid)
            .cast<chat_models.Chat>()
            .toList(growable: false);
    if (options.isEmpty) return null;
    return showDialog<chat_models.Chat>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 420,
            minWidth: 320,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.chatForwardDialogTitle,
                    style: context.textTheme.large.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final chat = options[index];
                    return ListTile(
                      title: Text(chat.displayName),
                      subtitle: chat.lastMessage == null
                          ? null
                          : Text(
                              chat.lastMessage!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.muted,
                            ),
                      onTap: () => Navigator.of(context).pop(chat),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleQuickReaction(Message message, String emoji) {
    context.read<ChatBloc>().add(
          ChatMessageReactionToggled(
            message: message,
            emoji: emoji,
          ),
        );
  }

  Map<String, FanOutRecipientState> _latestRecipientStatuses(
    ChatState state,
  ) {
    if (state.fanOutReports.isEmpty) {
      return const {};
    }
    final lastEntry = state.fanOutReports.entries.last.value;
    final statuses = <String, FanOutRecipientState>{};
    for (final status in lastEntry.statuses) {
      statuses[status.chat.jid] = status.state;
      final emailKey = status.chat.emailAddress?.trim().toLowerCase();
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

class _PinnedBadgeIcon extends StatelessWidget {
  const _PinnedBadgeIcon({
    required this.iconData,
    required this.count,
  });

  final IconData iconData;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final double iconSize =
        context.iconTheme.size ?? _pinnedBadgeFallbackIconSize;
    final double badgeSize = iconSize * _pinnedBadgeSizeScale;
    final double badgeInset = iconSize * _pinnedBadgeInsetScale;
    final Icon icon = Icon(
      iconData,
      size: iconSize,
      color: colors.primary,
    );
    if (count <= _pinnedBadgeHiddenCount) {
      return icon;
    }

    final String label = count > _pinnedBadgeMaxDisplayCount
        ? _pinnedBadgeOverflowLabel
        : count.toString();
    final Widget badge = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        shape: BoxShape.circle,
        border: Border.all(
          color: colors.primary,
          width: _pinnedBadgeBorderWidth,
        ),
      ),
      child: SizedBox(
        width: badgeSize,
        height: badgeSize,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: context.textTheme.small.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Center(child: icon),
          Positioned(
            top: badgeInset,
            right: badgeInset,
            child: badge,
          ),
        ],
      ),
    );
  }
}

class _ChatPinnedMessagesPanel extends StatefulWidget {
  const _ChatPinnedMessagesPanel({
    super.key,
    required this.chat,
    required this.visible,
    required this.maxHeight,
    required this.pinnedMessages,
    required this.pinnedMessagesLoaded,
    required this.pinnedMessagesHydrating,
    required this.onClose,
    required this.canTogglePins,
    required this.canShowCalendarTasks,
    required this.roomState,
    required this.metadataStreamFor,
    required this.metadataInitialFor,
    required this.attachmentsBlocked,
    required this.isOneTimeAttachmentAllowed,
    required this.shouldAllowAttachment,
    required this.onApproveAttachment,
  });

  final chat_models.Chat? chat;
  final bool visible;
  final double maxHeight;
  final List<PinnedMessageItem> pinnedMessages;
  final bool pinnedMessagesLoaded;
  final bool pinnedMessagesHydrating;
  final VoidCallback onClose;
  final bool canTogglePins;
  final bool canShowCalendarTasks;
  final RoomState? roomState;
  final Stream<FileMetadataData?> Function(String) metadataStreamFor;
  final FileMetadataData? Function(String) metadataInitialFor;
  final bool attachmentsBlocked;
  final bool Function(String stanzaId) isOneTimeAttachmentAllowed;
  final bool Function({
    required bool isSelf,
    required chat_models.Chat? chat,
  }) shouldAllowAttachment;
  final Future<void> Function({
    required Message message,
    required String senderJid,
    required String stanzaId,
    required bool isSelf,
    required bool isEmailChat,
    String? senderEmail,
  }) onApproveAttachment;

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
    final resolvedChat = widget.chat;
    if (resolvedChat == null) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final showPanel =
        widget.visible && widget.maxHeight > _chatPinnedPanelMinHeight;
    final showLoading = showPanel && !widget.pinnedMessagesLoaded;
    final Widget panelBody = showLoading
        ? Padding(
            padding: const EdgeInsets.symmetric(
              vertical: _chatPinnedPanelEmptyStatePadding,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AxiProgressIndicator(
                  dimension: _pinnedListLoadingIndicatorSize,
                  color: colors.mutedForeground,
                ),
              ],
            ),
          )
        : widget.pinnedMessages.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: _chatPinnedPanelEmptyStatePadding,
                ),
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
              )
            : ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                primary: false,
                physics: const ClampingScrollPhysics(),
                itemCount: widget.pinnedMessages.length,
                separatorBuilder: (_, __) => const AxiListDivider(),
                itemBuilder: (context, index) {
                  final item = widget.pinnedMessages[index];
                  return _PinnedMessageTile(
                    item: item,
                    chat: resolvedChat,
                    roomState: widget.roomState,
                    canTogglePins: widget.canTogglePins,
                    canShowCalendarTasks: widget.canShowCalendarTasks,
                    isHydrating: widget.pinnedMessagesHydrating,
                    metadataStreamFor: widget.metadataStreamFor,
                    metadataInitialFor: widget.metadataInitialFor,
                    attachmentsBlocked: widget.attachmentsBlocked,
                    isOneTimeAttachmentAllowed:
                        widget.isOneTimeAttachmentAllowed,
                    shouldAllowAttachment: widget.shouldAllowAttachment,
                    onApproveAttachment: widget.onApproveAttachment,
                  );
                },
              );
    final panel = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: _chatPinnedPanelHorizontalPadding,
          vertical: _chatPinnedPanelVerticalPadding,
        ),
        decoration: BoxDecoration(
          color: colors.card,
          border: Border(
            bottom: BorderSide(color: colors.border),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.chatPinnedMessagesTitle,
                    style: context.textTheme.large,
                  ),
                ),
                AxiIconButton(
                  iconData: LucideIcons.x,
                  tooltip: l10n.commonClose,
                  onPressed: widget.onClose,
                ),
              ],
            ),
            const SizedBox(height: _chatPinnedPanelHeaderSpacing),
            Flexible(
              fit: FlexFit.loose,
              child: panelBody,
            ),
          ],
        ),
      ),
    );
    return AnimatedCrossFade(
      duration: context.watch<SettingsCubit>().animationDuration,
      reverseDuration: context.watch<SettingsCubit>().animationDuration,
      sizeCurve: Curves.easeInOutCubic,
      crossFadeState:
          showPanel ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstChild: const SizedBox.shrink(),
      secondChild: panel,
    );
  }
}

class _PinnedMessageTile extends StatelessWidget {
  const _PinnedMessageTile({
    required this.item,
    required this.chat,
    required this.roomState,
    required this.canTogglePins,
    required this.canShowCalendarTasks,
    required this.isHydrating,
    required this.metadataStreamFor,
    required this.metadataInitialFor,
    required this.attachmentsBlocked,
    required this.isOneTimeAttachmentAllowed,
    required this.shouldAllowAttachment,
    required this.onApproveAttachment,
  });

  final PinnedMessageItem item;
  final chat_models.Chat chat;
  final RoomState? roomState;
  final bool canTogglePins;
  final bool canShowCalendarTasks;
  final bool isHydrating;
  final Stream<FileMetadataData?> Function(String) metadataStreamFor;
  final FileMetadataData? Function(String) metadataInitialFor;
  final bool attachmentsBlocked;
  final bool Function(String stanzaId) isOneTimeAttachmentAllowed;
  final bool Function({
    required bool isSelf,
    required chat_models.Chat? chat,
  }) shouldAllowAttachment;
  final Future<void> Function({
    required Message message,
    required String senderJid,
    required String stanzaId,
    required bool isSelf,
    required bool isEmailChat,
    String? senderEmail,
  }) onApproveAttachment;

  Message? _resolveMessageForPin() {
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

  bool _isSelfMessage({
    required Message message,
    required String? accountJid,
  }) {
    if (chat.type == ChatType.groupChat) {
      final myOccupantId = roomState?.myOccupantId;
      final occupantId = message.occupantID;
      if (myOccupantId == null || occupantId == null) {
        return false;
      }
      return myOccupantId == occupantId;
    }
    final resolvedAccountJid = accountJid?.trim();
    if (resolvedAccountJid == null || resolvedAccountJid.isEmpty) {
      return false;
    }
    try {
      return message.authorized(mox.JID.fromString(resolvedAccountJid));
    } on Exception {
      return false;
    }
  }

  String? _nickFromSender(String senderJid) {
    final slashIndex = senderJid.indexOf(_jidResourceSeparator);
    if (slashIndex == -1 || slashIndex + 1 >= senderJid.length) {
      return null;
    }
    final nick = senderJid.substring(slashIndex + 1).trim();
    return nick.isEmpty ? null : nick;
  }

  Occupant? _resolveOccupantForMessage(Message message) {
    final resolvedRoomState = roomState;
    if (resolvedRoomState == null) {
      return null;
    }
    final occupantId = message.occupantID?.trim();
    if (occupantId != null && occupantId.isNotEmpty) {
      final occupant = resolvedRoomState.occupants[occupantId];
      if (occupant != null) {
        return occupant;
      }
    }
    final direct = resolvedRoomState.occupants[message.senderJid];
    if (direct != null) {
      return direct;
    }
    final nick = _nickFromSender(message.senderJid);
    if (nick == null) {
      return null;
    }
    for (final occupant in resolvedRoomState.occupants.values) {
      if (occupant.nick == nick) {
        return occupant;
      }
    }
    return null;
  }

  String _resolveSenderLabel({
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
      final occupant = _resolveOccupantForMessage(message);
      final String? occupantNick = occupant?.nick;
      final String? trimmedNick = occupantNick?.trim();
      final bool hasNick = trimmedNick != null && trimmedNick.isNotEmpty;
      label = hasNick ? trimmedNick : _nickFromSender(message.senderJid);
    } else {
      final displayName = chat.displayName.trim();
      label = displayName.isNotEmpty ? displayName : null;
    }
    final senderFallback = message.senderJid.trim();
    final fallback =
        senderFallback.isNotEmpty ? senderFallback : chat.displayName;
    final hasLabel = label != null && label.isNotEmpty;
    final candidate = hasLabel ? label : fallback;
    final sanitized = sanitizeUnicodeControls(candidate);
    final safeLabel = sanitized.value.trim();
    return safeLabel.isNotEmpty ? safeLabel : fallback;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final message = item.message;
    final messageText = message?.plainText.trim();
    final hasMessageText = messageText?.isNotEmpty == true;
    final CalendarTask? calendarTask = message?.calendarTaskIcs;
    final bool hasCalendarTask = calendarTask != null;
    final String? taskShareText = calendarTask?.toShareText().trim();
    final bool hideTaskText = taskShareText != null &&
        taskShareText.isNotEmpty &&
        taskShareText == messageText;
    final CalendarFragment? calendarFragment = message?.calendarFragment;
    final CalendarCriticalPathFragment? criticalPathFragment =
        calendarFragment?.maybeMap(
      criticalPath: (value) => value,
      orElse: () => null,
    );
    final bool hasCriticalPath = criticalPathFragment != null;
    final String? criticalPathShareText = hasCriticalPath
        ? const CalendarFragmentFormatter().describe(calendarFragment!).trim()
        : null;
    final bool hideCriticalPathText = criticalPathShareText != null &&
        criticalPathShareText.isNotEmpty &&
        criticalPathShareText == messageText;
    final attachmentIds = item.attachmentMetadataIds;
    final hasAttachments = message != null && attachmentIds.isNotEmpty;
    final showMessageText =
        hasMessageText && !hideTaskText && !hideCriticalPathText;
    final showLoading = message == null && isHydrating;
    final showMissing = !showLoading &&
        !showMessageText &&
        !hasAttachments &&
        !hasCalendarTask &&
        !hasCriticalPath;
    final messageStyle = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: colors.foreground);
    final messageWidget = showLoading
        ? Align(
            alignment: Alignment.centerLeft,
            child: AxiProgressIndicator(
              dimension: _messageActionIconSize,
              color: colors.mutedForeground,
            ),
          )
        : showMessageText
            ? Text(
                messageText ?? _emptyText,
                style: messageStyle,
              )
            : showMissing
                ? Text(
                    l10n.chatPinnedMissingMessage,
                    style: context.textTheme.muted.copyWith(
                      color: colors.mutedForeground,
                    ),
                  )
                : null;
    final messageForPin = _resolveMessageForPin();
    final unpinButton = canTogglePins && messageForPin != null
        ? AxiTooltip(
            builder: (context) => Text(l10n.chatUnpinMessage),
            child: ShadIconButton.ghost(
              onPressed: () => context.read<ChatBloc>().add(
                    ChatMessagePinRequested(
                      message: messageForPin,
                      pin: false,
                    ),
                  ),
              icon: Icon(
                LucideIcons.pinOff,
                size: _messageActionIconSize,
                color: colors.mutedForeground,
              ),
              decoration: const ShadDecoration(
                secondaryBorder: ShadBorder.none,
                secondaryFocusedBorder: ShadBorder.none,
              ),
            ).withTapBounce(),
          )
        : null;
    final accountJid = context.read<XmppService>().myJid?.toString();
    final isSelf = message == null
        ? false
        : _isSelfMessage(
            message: message,
            accountJid: accountJid,
          );
    final senderLabel = _resolveSenderLabel(
      context: context,
      message: message,
      isSelf: isSelf,
    );
    final senderLabelStyle = context.textTheme.small.copyWith(
      color: colors.mutedForeground,
      fontWeight: FontWeight.w600,
    );
    final contentChildren = <Widget>[
      Row(
        children: [
          Expanded(
            child: Text(
              senderLabel,
              maxLines: _pinnedSenderMaxLines,
              overflow: TextOverflow.ellipsis,
              style: senderLabelStyle,
            ),
          ),
          if (unpinButton != null) unpinButton,
        ],
      ),
      if (messageWidget != null) ...[
        const SizedBox(height: _senderLabelBottomSpacing),
        messageWidget,
      ],
    ];
    if (hasCalendarTask) {
      final bool taskReadOnly =
          message?.calendarTaskIcsReadOnly ?? _calendarTaskIcsReadOnlyFallback;
      contentChildren.add(const SizedBox(height: _attachmentPreviewSpacing));
      contentChildren.add(
        canShowCalendarTasks
            ? ChatCalendarTaskCard(
                task: calendarTask,
                readOnly: taskReadOnly,
                requireImportConfirmation: !isSelf,
                footerDetails: _emptyInlineSpans,
              )
            : CalendarFragmentCard(
                fragment: CalendarFragment.task(task: calendarTask),
                footerDetails: _emptyInlineSpans,
              ),
      );
    }
    final resolvedCriticalPath = criticalPathFragment;
    if (resolvedCriticalPath != null) {
      contentChildren.add(const SizedBox(height: _attachmentPreviewSpacing));
      contentChildren.add(
        ChatCalendarCriticalPathCard(
          path: resolvedCriticalPath.path,
          tasks: resolvedCriticalPath.tasks,
          footerDetails: _emptyInlineSpans,
        ),
      );
    }
    if (hasAttachments) {
      contentChildren.add(const SizedBox(height: _attachmentPreviewSpacing));
      final isEmailBacked = chat.isEmailBacked;
      final bool attachmentsBlockedForPin = attachmentsBlocked;
      final allowAttachmentByTrust = shouldAllowAttachment(
        isSelf: isSelf,
        chat: chat,
      );
      final allowAttachmentOnce = attachmentsBlockedForPin
          ? false
          : isOneTimeAttachmentAllowed(message.stanzaID);
      final allowAttachment = !attachmentsBlockedForPin &&
          (allowAttachmentByTrust || allowAttachmentOnce);
      final autoDownloadSettings =
          context.watch<SettingsCubit>().state.attachmentAutoDownloadSettings;
      final chatAutoDownloadAllowed = chat.attachmentAutoDownload.isAllowed;
      final autoDownloadAllowed = allowAttachment && chatAutoDownloadAllowed;
      final emailService = RepositoryProvider.of<EmailService?>(context);
      final emailDownloadDelegate = isEmailBacked && emailService != null
          ? AttachmentDownloadDelegate(
              () => emailService.downloadFullMessage(message),
            )
          : null;
      final autoDownloadUserInitiated = allowAttachmentOnce;
      for (var index = 0; index < attachmentIds.length; index += 1) {
        final attachmentId = attachmentIds[index];
        if (index > 0) {
          contentChildren.add(
            const SizedBox(height: _attachmentPreviewSpacing),
          );
        }
        contentChildren.add(
          ChatAttachmentPreview(
            stanzaId: message.stanzaID,
            metadataStream: metadataStreamFor(attachmentId),
            initialMetadata: metadataInitialFor(attachmentId),
            allowed: allowAttachment,
            autoDownloadSettings: autoDownloadSettings,
            autoDownloadAllowed: autoDownloadAllowed,
            autoDownloadUserInitiated: autoDownloadUserInitiated,
            downloadDelegate: emailDownloadDelegate,
            onAllowPressed: allowAttachment
                ? null
                : attachmentsBlockedForPin
                    ? null
                    : () => onApproveAttachment(
                          message: message,
                          senderJid: message.senderJid,
                          stanzaId: message.stanzaID,
                          isSelf: isSelf,
                          isEmailChat: isEmailBacked,
                          senderEmail: chat.emailAddress,
                        ),
          ),
        );
      }
    }
    return ListItemPadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: contentChildren,
      ),
    );
  }
}

class _ChatCalendarPanel extends StatelessWidget {
  const _ChatCalendarPanel({
    required this.chat,
    required this.calendarAvailable,
    required this.participants,
    required this.avatarPaths,
    required this.calendarBloc,
  });

  final chat_models.Chat? chat;
  final bool calendarAvailable;
  final List<String> participants;
  final Map<String, String> avatarPaths;
  final ChatCalendarBloc? calendarBloc;

  @override
  Widget build(BuildContext context) {
    final resolvedChat = chat;
    final resolvedBloc = calendarBloc;
    if (!calendarAvailable || resolvedChat == null || resolvedBloc == null) {
      return const SizedBox.shrink();
    }
    return MultiBlocProvider(
      providers: [
        BlocProvider<ChatCalendarBloc>.value(
          value: resolvedBloc,
        ),
        BlocProvider<CalendarBloc>.value(
          value: resolvedBloc,
        ),
      ],
      child: ChatCalendarWidget(
        chat: resolvedChat,
        participants: participants,
        avatarPaths: avatarPaths,
        showHeader: true,
        showBackButton: false,
      ),
    );
  }
}

class _ChatDetailsOverlay extends StatelessWidget {
  const _ChatDetailsOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colorScheme.background,
      child: const SafeArea(
        top: false,
        child: ChatMessageDetails(),
      ),
    );
  }
}

class _ChatSearchOverlay extends StatelessWidget {
  const _ChatSearchOverlay({
    required this.panel,
  });

  final Widget panel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        panel,
        const Expanded(
          child: IgnorePointer(
            child: SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _ChatSettingsOverlay extends StatelessWidget {
  const _ChatSettingsOverlay({
    required this.state,
    required this.onViewFilterChanged,
    required this.onToggleNotifications,
    required this.onSpamToggle,
    required this.isChatBlocked,
    required this.blocklistEntry,
    required this.blockAddress,
  });

  final ChatState state;
  final ValueChanged<MessageTimelineFilter> onViewFilterChanged;
  final ValueChanged<bool> onToggleNotifications;
  final ValueChanged<bool> onSpamToggle;
  final bool isChatBlocked;
  final BlocklistEntry? blocklistEntry;
  final String? blockAddress;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colorScheme.background,
      child: SafeArea(
        top: false,
        child: _ChatSettingsButtons(
          state: state,
          onViewFilterChanged: onViewFilterChanged,
          onToggleNotifications: onToggleNotifications,
          onSpamToggle: onSpamToggle,
          isChatBlocked: isChatBlocked,
          blocklistEntry: blocklistEntry,
          blockAddress: blockAddress,
        ),
      ),
    );
  }
}

class _ChatGalleryOverlay extends StatelessWidget {
  const _ChatGalleryOverlay({
    required this.chat,
  });

  final chat_models.Chat? chat;

  @override
  Widget build(BuildContext context) {
    final resolvedChat = chat;
    if (resolvedChat == null) {
      return const SizedBox.shrink();
    }
    return BlocProvider(
      create: (context) => AttachmentGalleryCubit(
        xmppService: context.read<XmppService>(),
        chatJid: resolvedChat.jid,
      ),
      child: ColoredBox(
        color: context.colorScheme.background,
        child: SafeArea(
          top: false,
          child: AttachmentGalleryView(
            chatOverride: resolvedChat,
            showChatLabel: false,
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
    required this.participants,
    required this.avatarPaths,
    required this.calendarBloc,
  });

  final chat_models.Chat? chat;
  final bool calendarAvailable;
  final List<String> participants;
  final Map<String, String> avatarPaths;
  final ChatCalendarBloc? calendarBloc;

  @override
  Widget build(BuildContext context) {
    final resolvedChat = chat;
    final resolvedBloc = calendarBloc;
    if (!calendarAvailable || resolvedChat == null || resolvedBloc == null) {
      return const SizedBox.shrink();
    }
    return ColoredBox(
      color: context.colorScheme.background,
      child: SafeArea(
        top: false,
        child: _ChatCalendarPanel(
          chat: resolvedChat,
          calendarAvailable: calendarAvailable,
          participants: participants,
          avatarPaths: avatarPaths,
          calendarBloc: resolvedBloc,
        ),
      ),
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

final class _FileMetadataStreamEntry {
  final StreamController<FileMetadataData?> _controller =
      StreamController<FileMetadataData?>.broadcast();
  StreamSubscription<FileMetadataData?>? _subscription;
  var _hasValue = false;
  FileMetadataData? _latest;
  Object? _lastError;
  StackTrace? _lastStackTrace;

  late final Stream<FileMetadataData?> stream = Stream.multi(
    (multi) {
      if (_lastError != null) {
        multi.addError(_lastError!, _lastStackTrace);
      } else if (_hasValue) {
        multi.add(_latest);
      }
      final subscription = _controller.stream.listen(
        multi.add,
        onError: (Object error, StackTrace stackTrace) =>
            multi.addError(error, stackTrace),
      );
      multi.onCancel = subscription.cancel;
    },
  );

  FileMetadataData? get latestOrNull => _hasValue ? _latest : null;

  void attach(Stream<FileMetadataData?> source) {
    if (_subscription != null) return;
    _subscription = source.listen(
      (value) {
        _latest = value;
        _hasValue = true;
        _controller.add(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        _lastError = error;
        _lastStackTrace = stackTrace;
        _controller.addError(error, stackTrace);
      },
    );
  }

  void dispose() {
    final subscription = _subscription;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    unawaited(_controller.close());
  }
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

_CutoutLayoutResult<ReactionPreview> _layoutReactionStrip({
  required BuildContext context,
  required List<ReactionPreview> reactions,
  required double maxContentWidth,
}) {
  if (reactions.isEmpty || maxContentWidth <= 0) {
    return const _CutoutLayoutResult(
      items: <ReactionPreview>[],
      overflowed: false,
      totalWidth: 0,
    );
  }

  final textDirection = Directionality.of(context);
  final mediaQuery = MediaQuery.maybeOf(context);
  final textScaler =
      mediaQuery == null ? TextScaler.noScaling : mediaQuery.textScaler;

  final visible = <ReactionPreview>[];
  final additions = <double>[];
  double used = 0;

  final limit = maxContentWidth.isFinite
      ? math.max(0.0, maxContentWidth - 1)
      : maxContentWidth;

  for (final reaction in reactions) {
    final spacing = visible.isEmpty ? 0 : _reactionChipSpacing;
    final addition = spacing +
        _measureReactionChipWidth(
          context: context,
          reaction: reaction,
          textDirection: textDirection,
          textScaler: textScaler,
        );
    if (limit.isFinite && used + addition > limit) {
      break;
    }
    visible.add(reaction);
    additions.add(addition);
    used += addition;
  }

  final truncated = visible.length < reactions.length;
  double totalWidth = used;

  if (truncated) {
    var spacing = visible.isEmpty ? 0 : _reactionChipSpacing;
    const glyphWidth = _reactionOverflowGlyphWidth;
    while (visible.isNotEmpty &&
        limit.isFinite &&
        totalWidth + spacing + glyphWidth > limit) {
      totalWidth -= additions.removeLast();
      visible.removeLast();
      spacing = visible.isEmpty ? 0 : _reactionChipSpacing;
    }
    if (visible.isEmpty) {
      totalWidth = math.min(glyphWidth, maxContentWidth);
    } else {
      totalWidth = math.min(maxContentWidth, totalWidth + spacing + glyphWidth);
    }
  } else {
    totalWidth = math.min(maxContentWidth, totalWidth);
  }

  return _CutoutLayoutResult(
    items: visible,
    overflowed: truncated,
    totalWidth: totalWidth,
  );
}

double _measureReactionChipWidth({
  required BuildContext context,
  required ReactionPreview reaction,
  required TextDirection textDirection,
  required TextScaler textScaler,
}) {
  final emojiPainter = TextPainter(
    text: TextSpan(
      text: reaction.emoji,
      style:
          _reactionEmojiTextStyle(context, highlighted: reaction.reactedBySelf),
    ),
    maxLines: 1,
    textDirection: textDirection,
    textScaler: textScaler,
  )..layout();

  var width = emojiPainter.width + _reactionChipPadding.horizontal;

  if (reaction.count > 1) {
    final countPainter = TextPainter(
      text: TextSpan(
        text: reaction.count.toString(),
        style: _reactionCountTextStyle(
          context,
          highlighted: reaction.reactedBySelf,
        ),
      ),
      maxLines: 1,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    width = math.max(
      width,
      emojiPainter.width +
          countPainter.width * 0.8 +
          _reactionSubscriptPadding +
          _reactionChipPadding.horizontal,
    );
  }

  return width;
}

_CutoutLayoutResult<chat_models.Chat> _layoutRecipientStrip(
  List<chat_models.Chat> recipients,
  double maxContentWidth,
) {
  if (recipients.isEmpty || maxContentWidth <= 0) {
    return const _CutoutLayoutResult(
      items: <chat_models.Chat>[],
      overflowed: false,
      totalWidth: 0,
    );
  }

  final visible = <chat_models.Chat>[];
  final additions = <double>[];
  double used = 0;

  for (final recipient in recipients) {
    final addition = visible.isEmpty
        ? _recipientAvatarSize
        : _recipientAvatarSize - _recipientAvatarOverlap;
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
        ? _recipientAvatarSize
        : _recipientAvatarSize - _recipientAvatarOverlap;
    while (visible.isNotEmpty && totalWidth + ellipsisWidth > maxContentWidth) {
      totalWidth -= additions.removeLast();
      visible.removeLast();
      ellipsisWidth = visible.isEmpty
          ? _recipientAvatarSize
          : _recipientAvatarSize - _recipientAvatarOverlap;
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

_CutoutLayoutResult<String> _layoutTypingStrip(
  List<String> participants,
  double maxContentWidth,
) {
  if (participants.isEmpty || maxContentWidth <= 0) {
    return const _CutoutLayoutResult(
      items: <String>[],
      overflowed: false,
      totalWidth: 0,
    );
  }
  final capped =
      participants.take(_typingIndicatorMaxAvatars + 1).toList(growable: false);
  final visible = <String>[];
  final additions = <double>[];
  double used = 0;

  for (final participant in capped) {
    if (visible.length >= _typingIndicatorMaxAvatars) break;
    final addition = visible.isEmpty
        ? _recipientAvatarSize
        : _recipientAvatarSize - _recipientAvatarOverlap;
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
        ? _recipientAvatarSize
        : _recipientAvatarSize - _recipientAvatarOverlap;
    while (visible.isNotEmpty && totalWidth + ellipsisWidth > maxContentWidth) {
      totalWidth -= additions.removeLast();
      visible.removeLast();
      ellipsisWidth = visible.isEmpty
          ? _recipientAvatarSize
          : _recipientAvatarSize - _recipientAvatarOverlap;
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
    return AxiAvatar(
      jid: jid,
      size: size,
      avatarPath: avatarPath,
    );
  }
}

class _ReactionStrip extends StatelessWidget {
  const _ReactionStrip({
    required this.reactions,
    this.onReactionTap,
  });

  final List<ReactionPreview> reactions;
  final void Function(String emoji)? onReactionTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.hasBoundedWidth &&
                constraints.maxWidth.isFinite &&
                constraints.maxWidth > 0
            ? constraints.maxWidth
            : double.infinity;
        final layout = _layoutReactionStrip(
          context: context,
          reactions: reactions,
          maxContentWidth: maxWidth,
        );
        final items = layout.items;
        final children = <Widget>[];
        for (var i = 0; i < items.length; i++) {
          if (i != 0) {
            children.add(const SizedBox(width: _reactionChipSpacing));
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
            children.add(const SizedBox(width: _reactionOverflowSpacing));
          }
          children.add(const _ReactionOverflowGlyph());
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: children,
        );
      },
    );
  }
}

class _ReactionOverflowGlyph extends StatelessWidget {
  const _ReactionOverflowGlyph();

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return SizedBox(
      width: _reactionOverflowGlyphWidth,
      height: 18,
      child: Center(
        child: Text(
          '…',
          style: context.textTheme.small
              .copyWith(
                fontWeight: FontWeight.w600,
                color: colors.mutedForeground,
                height: 1,
              )
              .apply(leadingDistribution: TextLeadingDistribution.even),
        ),
      ),
    );
  }
}

class _ReplyStrip extends StatelessWidget {
  const _ReplyStrip({
    required this.participants,
    this.onRecipientTap,
  });

  final List<chat_models.Chat> participants;
  final ValueChanged<chat_models.Chat>? onRecipientTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.hasBoundedWidth &&
                constraints.maxWidth.isFinite &&
                constraints.maxWidth > 0
            ? constraints.maxWidth
            : double.infinity;
        final layout = _layoutRecipientStrip(participants, maxWidth);
        final visible = layout.items;
        final overflowed = layout.overflowed;
        final children = <Widget>[];
        for (var i = 0; i < visible.length; i++) {
          final chat = visible[i];
          final offset = i * (_recipientAvatarSize - _recipientAvatarOverlap);
          children.add(
            Positioned(
              left: offset,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap:
                    onRecipientTap == null ? null : () => onRecipientTap!(chat),
                child: _RecipientAvatarBadge(chat: chat),
              ),
            ),
          );
        }
        if (overflowed) {
          final offset = visible.isEmpty
              ? 0.0
              : visible.length *
                      (_recipientAvatarSize - _recipientAvatarOverlap) +
                  _recipientOverflowGap;
          children.add(
            Positioned(
              left: offset,
              child: const _RecipientOverflowAvatar(),
            ),
          );
        }
        final baseWidth = layout.totalWidth;
        final totalWidth = overflowed
            ? baseWidth + _recipientOverflowGap + _recipientAvatarSize
            : math.max(baseWidth, _recipientAvatarSize);
        return SizedBox(
          width: totalWidth,
          height: _recipientAvatarSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: children,
          ),
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
        final maxWidth = constraints.hasBoundedWidth &&
                constraints.maxWidth.isFinite &&
                constraints.maxWidth > 0
            ? constraints.maxWidth
            : double.infinity;
        final layout = _layoutRecipientStrip(recipients, maxWidth);
        final visible = layout.items;
        final overflowed = layout.overflowed;
        final children = <Widget>[];
        for (var i = 0; i < visible.length; i++) {
          final offset = i * (_recipientAvatarSize - _recipientAvatarOverlap);
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
                      (_recipientAvatarSize - _recipientAvatarOverlap) +
                  _recipientOverflowGap;
          children.add(
            Positioned(
              left: offset,
              child: const _RecipientOverflowAvatar(),
            ),
          );
        }
        final baseWidth = layout.totalWidth;
        final totalWidth = overflowed
            ? baseWidth + _recipientOverflowGap + _recipientAvatarSize
            : math.max(baseWidth, _recipientAvatarSize);
        return SizedBox(
          width: totalWidth,
          height: _recipientAvatarSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: children,
          ),
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
    const borderWidth = 1.6;
    final avatarPath = (chat.avatarPath ?? chat.contactAvatarPath)?.trim();
    final resolvedAvatarPath =
        avatarPath?.isNotEmpty == true ? avatarPath : null;
    return Container(
      width: _recipientAvatarSize,
      height: _recipientAvatarSize,
      padding: const EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        color: colors.card,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: AxiAvatar(
          jid: chat.avatarIdentifier,
          size: _recipientAvatarSize - (borderWidth * 2),
          shape: AxiAvatarShape.circle,
          avatarPath: resolvedAvatarPath,
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
    return SizedBox(
      width: _recipientAvatarSize,
      height: _recipientAvatarSize,
      child: Center(
        child: Text(
          '…',
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
                Flexible(
                  fit: FlexFit.loose,
                  child: avatarStrip,
                ),
              if (avatarStrip != null)
                const SizedBox(width: _typingAvatarSpacing),
              const TypingIndicator(),
            ],
          ),
        );
      },
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
        final maxWidth = constraints.hasBoundedWidth &&
                constraints.maxWidth.isFinite &&
                constraints.maxWidth > 0
            ? constraints.maxWidth
            : double.infinity;
        final layout = _layoutTypingStrip(participants, maxWidth);
        final visible = layout.items;
        final overflowed = layout.overflowed;
        final children = <Widget>[];
        for (var i = 0; i < visible.length; i++) {
          final offset = i * (_recipientAvatarSize - _recipientAvatarOverlap);
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
                      (_recipientAvatarSize - _recipientAvatarOverlap) +
                  _recipientOverflowGap;
          children.add(
            Positioned(
              left: offset,
              child: const _RecipientOverflowAvatar(),
            ),
          );
        }
        final baseWidth = layout.totalWidth;
        final totalWidth = overflowed
            ? baseWidth + _recipientOverflowGap + _recipientAvatarSize
            : math.max(baseWidth, _recipientAvatarSize);
        return SizedBox(
          width: totalWidth,
          height: _recipientAvatarSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: children,
          ),
        );
      },
    );
  }
}

class _TypingAvatar extends StatelessWidget {
  const _TypingAvatar({
    required this.jid,
    this.avatarPath,
  });

  final String jid;
  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    final borderColor = context.colorScheme.card;
    return Container(
      width: _recipientAvatarSize,
      height: _recipientAvatarSize,
      padding: const EdgeInsets.all(_typingAvatarBorderWidth),
      decoration: BoxDecoration(
        color: borderColor,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: AxiAvatar(
          jid: jid,
          size: _recipientAvatarSize - (_typingAvatarBorderWidth * 2),
          avatarPath: avatarPath,
        ),
      ),
    );
  }
}

class _InviteAttachmentText extends StatelessWidget {
  const _InviteAttachmentText({
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final UnicodeSanitizedText sanitized = sanitizeUnicodeControls(text);
    final String candidate = sanitized.value.trim();
    final String resolved = candidate.isNotEmpty ? candidate : text;
    return Text(
      resolved,
      maxLines: _inviteAttachmentLabelMaxLines,
      overflow: _inviteAttachmentLabelOverflow,
      style: style,
    );
  }
}

class _InviteAttachmentCard extends StatelessWidget {
  const _InviteAttachmentCard({
    required this.enabled,
    required this.label,
    required this.detailLabel,
    required this.actionLabel,
    required this.onPressed,
  });

  final bool enabled;
  final String label;
  final String detailLabel;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final Color labelColor =
        enabled ? colors.foreground : colors.mutedForeground;
    final Color iconColor =
        enabled ? colors.foreground : colors.mutedForeground;
    final String trimmedDetailLabel = detailLabel.trim();
    final bool showDetailLabel = trimmedDetailLabel.isNotEmpty;
    final Widget attachmentIcon = DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.muted
            .withValues(alpha: _inviteAttachmentIconBackgroundAlpha),
        shape: SquircleBorder(
          cornerRadius: _inviteAttachmentIconCornerRadius,
          side: BorderSide(color: colors.border),
        ),
      ),
      child: SizedBox(
        width: _inviteAttachmentIconWidth,
        height: _inviteAttachmentIconHeight,
        child: Center(
          child: Icon(
            LucideIcons.userPlus,
            size: _inviteAttachmentIconSize,
            color: iconColor,
          ),
        ),
      ),
    );
    final Widget attachmentDetails = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _inviteAttachmentDetailSpacing,
      children: [
        _InviteAttachmentText(
          text: label,
          style: context.textTheme.small.copyWith(
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        ),
        if (showDetailLabel)
          _InviteAttachmentText(
            text: trimmedDetailLabel,
            style: context.textTheme.small.copyWith(
              color: colors.mutedForeground,
            ),
          ),
      ],
    );
    final Widget actionButton = AxiIconButton(
      iconData: LucideIcons.check,
      tooltip: actionLabel,
      onPressed: enabled ? onPressed : null,
      color: iconColor,
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.card,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(_inviteAttachmentCornerRadius),
          side: BorderSide(color: colors.border),
        ),
      ),
      child: Padding(
        padding: _inviteAttachmentPadding,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool stackActions =
                constraints.maxWidth < _inviteAttachmentInlineActionsMinWidth;
            if (stackActions) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      attachmentIcon,
                      const SizedBox(width: _inviteAttachmentRowSpacing),
                      Expanded(child: attachmentDetails),
                    ],
                  ),
                  const SizedBox(height: _inviteAttachmentActionSpacing),
                  Align(
                    alignment: Alignment.centerRight,
                    child: actionButton,
                  ),
                ],
              );
            }
            return Row(
              children: [
                attachmentIcon,
                const SizedBox(width: _inviteAttachmentRowSpacing),
                Expanded(child: attachmentDetails),
                const SizedBox(width: _inviteAttachmentRowSpacing),
                Flexible(
                  fit: FlexFit.loose,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: actionButton,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BubbleRegionRegistry {
  final _regions = <String, RenderBox>{};

  Rect? rectFor(String messageId) {
    final renderBox = _regions[messageId];
    if (renderBox == null || !renderBox.attached) {
      return null;
    }
    final origin = renderBox.localToGlobal(Offset.zero);
    return origin & renderBox.size;
  }

  void register(String messageId, RenderBox renderBox) {
    _regions[messageId] = renderBox;
  }

  void unregister(String messageId, RenderBox renderBox) {
    final current = _regions[messageId];
    if (identical(current, renderBox)) {
      _regions.remove(messageId);
    }
  }

  void clear() {
    _regions.clear();
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
      _RenderMessageBubbleRegion(
        messageId: messageId,
        registry: registry,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMessageBubbleRegion renderObject,
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
  })  : _messageId = messageId,
        _registry = registry;

  String _messageId;

  set messageId(String value) {
    if (value == _messageId) return;
    _registry.unregister(_messageId, this);
    _messageId = value;
    _registry.register(_messageId, this);
  }

  _BubbleRegionRegistry _registry;

  set registry(_BubbleRegionRegistry value) {
    if (identical(value, _registry)) return;
    _registry.unregister(_messageId, this);
    _registry = value;
    _registry.register(_messageId, this);
  }

  void _register() {
    _registry.register(_messageId, this);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _register();
  }

  @override
  void detach() {
    _registry.unregister(_messageId, this);
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    _register();
  }
}

enum _ComposerNoticeType { error, warning, info }

class _ComposerNotice extends StatelessWidget {
  const _ComposerNotice({
    required this.type,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final _ComposerNoticeType type;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (Color background, Color foreground, IconData icon) = switch (type) {
      _ComposerNoticeType.error => (
          colors.errorContainer,
          colors.onErrorContainer,
          Icons.error_outline,
        ),
      _ComposerNoticeType.warning => (
          colors.secondaryContainer,
          colors.onSecondaryContainer,
          Icons.warning_amber_rounded,
        ),
      _ComposerNoticeType.info => (
          colors.surfaceContainerHighest,
          colors.onSurface,
          Icons.refresh,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: foreground),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

class _ChatComposerSection extends StatelessWidget {
  const _ChatComposerSection({
    required this.hintText,
    required this.recipients,
    required this.availableChats,
    required this.latestStatuses,
    required this.visibilityLabel,
    required this.pendingAttachments,
    required this.composerHasText,
    required this.subjectController,
    required this.subjectFocusNode,
    required this.textController,
    required this.textFocusNode,
    required this.onSubjectSubmitted,
    required this.onRecipientAdded,
    required this.onRecipientRemoved,
    required this.onRecipientToggled,
    required this.onAttachmentRetry,
    required this.onAttachmentRemove,
    required this.onPendingAttachmentPressed,
    required this.onPendingAttachmentLongPressed,
    required this.pendingAttachmentMenuBuilder,
    required this.buildComposerAccessories,
    required this.onSend,
    this.composerError,
    this.showAttachmentWarning = false,
    this.retryReport,
    this.retryShareId,
    this.onTaskDropped,
  });

  final String hintText;
  final List<ComposerRecipient> recipients;
  final List<chat_models.Chat> availableChats;
  final Map<String, FanOutRecipientState> latestStatuses;
  final String? visibilityLabel;
  final List<PendingAttachment> pendingAttachments;
  final bool composerHasText;
  final TextEditingController subjectController;
  final FocusNode subjectFocusNode;
  final TextEditingController textController;
  final FocusNode textFocusNode;
  final VoidCallback onSubjectSubmitted;
  final ValueChanged<FanOutTarget> onRecipientAdded;
  final ValueChanged<String> onRecipientRemoved;
  final ValueChanged<String> onRecipientToggled;
  final ValueChanged<String> onAttachmentRetry;
  final ValueChanged<String> onAttachmentRemove;
  final ValueChanged<PendingAttachment> onPendingAttachmentPressed;
  final ValueChanged<PendingAttachment>? onPendingAttachmentLongPressed;
  final List<Widget> Function(PendingAttachment pending)?
      pendingAttachmentMenuBuilder;
  final List<ChatComposerAccessory> Function({required bool canSend})
      buildComposerAccessories;
  final VoidCallback onSend;
  final String? composerError;
  final bool showAttachmentWarning;
  final FanOutSendReport? retryReport;
  final String? retryShareId;
  final ValueChanged<CalendarDragPayload>? onTaskDropped;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final xmppService = context.read<XmppService>();
    final myJid = xmppService.myJid;
    final suggestionAddresses = <String>{
      if (myJid != null && myJid.isNotEmpty) myJid,
    };
    final suggestionDomains = <String>{
      EndpointConfig.defaultDomain,
      if (myJid != null && myJid.isNotEmpty) mox.JID.fromString(myJid).domain,
    };
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width >= smallScreen
        ? _desktopComposerHorizontalInset
        : _composerHorizontalInset;
    final hasQueuedAttachments = pendingAttachments.any(
      (attachment) =>
          attachment.status == PendingAttachmentStatus.queued &&
          !attachment.isPreparing,
    );
    final hasPreparingAttachments =
        pendingAttachments.any((attachment) => attachment.isPreparing);
    final hasSubjectText = subjectController.text.trim().isNotEmpty;
    final sendEnabled = !hasPreparingAttachments &&
        (composerHasText || hasQueuedAttachments || hasSubjectText);
    final subjectHeader = _SubjectTextField(
      controller: subjectController,
      focusNode: subjectFocusNode,
      onSubmitted: onSubjectSubmitted,
    );
    final Widget header = subjectHeader;
    final showAttachmentTray = pendingAttachments.isNotEmpty;
    final commandSurface = resolveCommandSurface(context);
    final useDesktopMenu = commandSurface == CommandSurface.menu;
    Widget? attachmentTray;
    if (showAttachmentTray) {
      attachmentTray = PendingAttachmentList(
        attachments: pendingAttachments,
        onRetry: onAttachmentRetry,
        onRemove: onAttachmentRemove,
        onPressed: onPendingAttachmentPressed,
        onLongPress: useDesktopMenu ? null : onPendingAttachmentLongPressed,
        contextMenuBuilder:
            useDesktopMenu ? pendingAttachmentMenuBuilder : null,
      );
    }
    final composer = SafeArea(
      top: false,
      left: false,
      right: false,
      child: SizedBox(
        width: double.infinity,
        child: ColoredBox(
          color: colors.background,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colors.border, width: 1),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                18,
                horizontalPadding,
                10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (attachmentTray != null) ...[
                    attachmentTray,
                    const SizedBox(height: 12),
                  ],
                  _ComposerTaskDropRegion(
                    onTaskDropped: onTaskDropped,
                    child: ChatCutoutComposer(
                      controller: textController,
                      focusNode: textFocusNode,
                      hintText: hintText,
                      semanticsLabel: context.l10n.chatComposerSemantics,
                      onSend: onSend,
                      header: header,
                      actions: buildComposerAccessories(
                        canSend: sendEnabled,
                      ),
                      sendEnabled: sendEnabled,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final notices = <Widget>[];
    if (composerError != null && composerError!.isNotEmpty) {
      notices.add(
        _ComposerNotice(
          type: _ComposerNoticeType.error,
          message: composerError!,
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
        final hasSubjectLabel = subjectLabel?.isNotEmpty == true;
        final failureMessage = hasSubjectLabel
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
            actionLabel: l10n.chatFanOutRetry,
            onAction: () =>
                context.read<ChatBloc>().add(ChatFanOutRetryRequested(shareId)),
          ),
        );
      }
    }
    final children = <Widget>[];
    if (notices.isNotEmpty) {
      for (var i = 0; i < notices.length; i++) {
        children.add(notices[i]);
        if (i != notices.length - 1) {
          children.add(const SizedBox(height: 8));
        }
      }
      children.add(const SizedBox(height: 12));
    }
    children.add(
      RecipientChipsBar(
        recipients: recipients,
        availableChats: availableChats,
        latestStatuses: latestStatuses,
        collapsedByDefault: true,
        suggestionAddresses: suggestionAddresses,
        suggestionDomains: suggestionDomains,
        onRecipientAdded: onRecipientAdded,
        onRecipientRemoved: onRecipientRemoved,
        onRecipientToggled: onRecipientToggled,
        visibilityLabel: visibilityLabel,
      ),
    );
    children.add(composer);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _ComposerTaskDropRegion extends StatelessWidget {
  const _ComposerTaskDropRegion({
    required this.child,
    this.onTaskDropped,
  });

  final Widget child;
  final ValueChanged<CalendarDragPayload>? onTaskDropped;

  @override
  Widget build(BuildContext context) {
    if (onTaskDropped == null) {
      return child;
    }
    final colors = context.colorScheme;
    return DragTarget<CalendarDragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onTaskDropped?.call(details.data),
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
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final subjectStyle = context.textTheme.p.copyWith(
      fontSize: 14,
      height: 1.05,
      fontWeight: FontWeight.w600,
      color: colors.foreground,
    );
    return SizedBox(
      height: _subjectFieldHeight,
      child: Semantics(
        label: l10n.chatSubjectSemantics,
        textField: true,
        child: AxiTextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => onSubmitted(),
          onEditingComplete: onSubmitted,
          style: subjectStyle,
          decoration: InputDecoration(
            hintText: l10n.chatSubjectHint,
            hintStyle: context.textTheme.muted.copyWith(
              color: colors.mutedForeground.withValues(alpha: 0.9),
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isCollapsed: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyComposerBanner extends StatelessWidget {
  const _ReadOnlyComposerBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: ColoredBox(
        color: colors.background,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: colors.border, width: 1),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _composerHorizontalInset,
              18,
              _composerHorizontalInset,
              18,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.archive,
                  size: 18,
                  color: colors.mutedForeground,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.chatReadOnly,
                        style: context.textTheme.small.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.chatUnarchivePrompt,
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
      ),
    );
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
    return ShadPopover(
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
    return _ChatComposerIconButton(
      icon: LucideIcons.paperclip,
      tooltip: context.l10n.chatAttachmentTooltip,
      onPressed: enabled ? onPressed : null,
    );
  }
}

class _AttachmentPreviewDialog extends StatelessWidget {
  const _AttachmentPreviewDialog({
    required this.attachment,
    required this.intrinsicSize,
    required this.l10n,
  });

  final EmailAttachment attachment;
  final Size? intrinsicSize;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final maxWidth = (mediaSize.width - 96).clamp(240.0, mediaSize.width);
    final maxHeight = (mediaSize.height - 160).clamp(240.0, mediaSize.height);
    final targetSize = _fitWithinBounds(
      intrinsicSize: intrinsicSize,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    final colors = context.colorScheme;
    final radius = BorderRadius.circular(18);
    final borderSide = BorderSide(color: colors.border);

    return ShadDialog(
      padding: const EdgeInsets.all(12),
      gap: 12,
      closeIcon: const SizedBox.shrink(),
      constraints: BoxConstraints(
        maxWidth: targetSize.width + 24,
        maxHeight: targetSize.height + 24,
      ),
      child: Stack(
        children: [
          Center(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: colors.card,
                shape: ContinuousRectangleBorder(
                  borderRadius: radius,
                  side: borderSide,
                ),
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: SizedBox(
                  width: targetSize.width,
                  height: targetSize.height,
                  child: InteractiveViewer(
                    maxScale: 4,
                    child: Image.file(
                      File(attachment.path),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: ShadButton.ghost(
              size: ShadButtonSize.sm,
              onPressed: () => Navigator.of(context).pop(),
              child: const Icon(LucideIcons.x, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Size _fitWithinBounds({
    required Size? intrinsicSize,
    required double maxWidth,
    required double maxHeight,
  }) {
    final cappedWidth = math.max(0.0, maxWidth);
    final cappedHeight = math.max(0.0, maxHeight);
    if (intrinsicSize == null ||
        intrinsicSize.width <= 0 ||
        intrinsicSize.height <= 0) {
      final width = math.min(cappedWidth, 360.0);
      final height = math.min(cappedHeight, width * 0.75);
      return Size(width, height);
    }
    final aspectRatio = intrinsicSize.width / intrinsicSize.height;
    var width = math.min(intrinsicSize.width, cappedWidth);
    var height = width / aspectRatio;
    if (height > cappedHeight && cappedHeight > 0) {
      height = cappedHeight;
      width = height * aspectRatio;
    }
    return Size(width, height);
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
    final textScaler = MediaQuery.of(context).textScaler;
    double scaled(double value) => textScaler.scale(value);
    final iconColor = onPressed == null
        ? colors.mutedForeground
        : (activeColor ?? colors.foreground);
    final minButtonExtent = scaled(42);
    final cornerRadius = scaled(14);
    return AxiIconButton(
      iconData: icon,
      tooltip: tooltip,
      semanticLabel: tooltip,
      onPressed: onPressed,
      onLongPress: onLongPress,
      color: iconColor,
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: scaled(1.4),
      cornerRadius: cornerRadius,
      buttonSize: minButtonExtent,
      tapTargetSize: minButtonExtent,
      iconSize: scaled(22),
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
    final emojiStyle =
        _reactionEmojiTextStyle(context, highlighted: highlighted);
    final countStyle =
        _reactionCountTextStyle(context, highlighted: highlighted);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: Padding(
        padding: _reactionChipPadding,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Text(
              data.emoji,
              style: emojiStyle,
            ),
            if (data.count > 1)
              Positioned(
                right: -_reactionSubscriptPadding,
                bottom: -_reactionSubscriptPadding,
                child: Text(
                  data.count.toString(),
                  style: countStyle.copyWith(
                    fontSize: (countStyle.fontSize ?? 10) * 0.9,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

TextStyle _reactionEmojiTextStyle(
  BuildContext context, {
  required bool highlighted,
}) {
  final base = Theme.of(context).textTheme.bodyMedium ??
      const TextStyle(fontSize: 16, fontWeight: FontWeight.w500);
  return base.copyWith(
    fontSize: 16,
    fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
  );
}

TextStyle _reactionCountTextStyle(
  BuildContext context, {
  required bool highlighted,
}) {
  final colors = context.colorScheme;
  return context.textTheme.small.copyWith(
    color: highlighted ? colors.primary : colors.foreground,
    fontWeight: FontWeight.w600,
  );
}

class _SelectionHeadroomSpacer extends StatelessWidget {
  const _SelectionHeadroomSpacer({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final clampedHeight = math.max(0.0, height);
    return IgnorePointer(
      ignoring: true,
      child: AnimatedSize(
        duration: _bubbleFocusDuration,
        curve: _bubbleFocusCurve,
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        child: SizedBox(height: clampedHeight),
      ),
    );
  }
}

enum _SelectionShiftOutcome {
  satisfied,
  animated,
  awaitingHeadroom,
}

class _MessageActionBar extends StatelessWidget {
  const _MessageActionBar({
    required this.onReply,
    this.onForward,
    required this.onCopy,
    required this.onShare,
    required this.onAddToCalendar,
    required this.onDetails,
    this.onSelect,
    this.onResend,
    this.onEdit,
    this.onPinToggle,
    required this.isPinned,
    this.hitRegionKeys,
    this.onRevokeInvite,
  });

  final VoidCallback onReply;
  final VoidCallback? onForward;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onAddToCalendar;
  final VoidCallback onDetails;
  final VoidCallback? onSelect;
  final VoidCallback? onResend;
  final VoidCallback? onEdit;
  final VoidCallback? onPinToggle;
  final bool isPinned;
  final List<GlobalKey>? hitRegionKeys;
  final VoidCallback? onRevokeInvite;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.of(context).textScaler;
    final l10n = context.l10n;
    double scaled(double value) => textScaler.scale(value);
    var keyIndex = 0;
    GlobalKey? nextKey() {
      if (hitRegionKeys == null) return null;
      if (keyIndex >= hitRegionKeys!.length) return null;
      return hitRegionKeys![keyIndex++];
    }

    final actions = <Widget>[
      ContextActionButton(
        key: nextKey(),
        icon: const Icon(LucideIcons.reply, size: _messageActionIconSize),
        label: l10n.chatActionReply,
        onPressed: onReply,
      ),
      ContextActionButton(
        key: nextKey(),
        icon: Transform.scale(
          scaleX: -1,
          child: const Icon(LucideIcons.reply, size: _messageActionIconSize),
        ),
        label: l10n.chatActionForward,
        onPressed: onForward,
      ),
      if (onResend != null)
        ContextActionButton(
          key: nextKey(),
          icon: const Icon(LucideIcons.repeat, size: _messageActionIconSize),
          label: l10n.chatActionResend,
          onPressed: onResend!,
        ),
      if (onEdit != null)
        ContextActionButton(
          key: nextKey(),
          icon:
              const Icon(LucideIcons.pencilLine, size: _messageActionIconSize),
          label: l10n.chatActionEdit,
          onPressed: onEdit!,
        ),
      if (onRevokeInvite != null)
        ContextActionButton(
          key: nextKey(),
          icon: const Icon(LucideIcons.ban, size: _messageActionIconSize),
          label: l10n.chatActionRevoke,
          onPressed: onRevokeInvite!,
        ),
      if (onPinToggle != null)
        ContextActionButton(
          key: nextKey(),
          icon: Icon(
            isPinned ? LucideIcons.pinOff : LucideIcons.pin,
            size: _messageActionIconSize,
          ),
          label: isPinned ? l10n.chatUnpinMessage : l10n.chatPinMessage,
          onPressed: onPinToggle!,
        ),
      ContextActionButton(
        key: nextKey(),
        icon: const Icon(LucideIcons.copy, size: _messageActionIconSize),
        label: l10n.chatActionCopy,
        onPressed: onCopy,
      ),
      ContextActionButton(
        key: nextKey(),
        icon: const Icon(LucideIcons.share2, size: _messageActionIconSize),
        label: l10n.chatActionShare,
        onPressed: onShare,
      ),
      ContextActionButton(
        key: nextKey(),
        icon:
            const Icon(LucideIcons.calendarPlus, size: _messageActionIconSize),
        label: l10n.chatActionAddToCalendar,
        onPressed: onAddToCalendar,
      ),
      ContextActionButton(
        key: nextKey(),
        icon: const Icon(LucideIcons.info, size: _messageActionIconSize),
        label: l10n.chatActionDetails,
        onPressed: onDetails,
      ),
    ];
    if (onSelect != null) {
      actions.add(
        ContextActionButton(
          key: nextKey(),
          icon:
              const Icon(LucideIcons.squareCheck, size: _messageActionIconSize),
          label: l10n.chatActionSelect,
          onPressed: onSelect,
        ),
      );
    }
    return Wrap(
      spacing: scaled(8),
      runSpacing: scaled(8),
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
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  late bool _completed;

  @override
  void initState() {
    super.initState();
    _completed = !widget.animate;
    _controller = AnimationController(
      vsync: this,
      duration: _messageArrivalDuration,
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: _messageArrivalCurve,
    );
    _opacity = curve;
    _slide = Tween<Offset>(
      begin: Offset(widget.isSelf ? 0.22 : -0.22, 0.0),
      end: Offset.zero,
    ).animate(curve);
    _controller.addStatusListener(_handleStatus);
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _MessageArrivalAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate) {
      _completed = false;
      _controller
        ..value = 0
        ..forward();
    } else if (!widget.animate && !_completed) {
      _controller.value = 1;
      _completed = true;
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleStatus);
    _controller.dispose();
    super.dispose();
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() {
        _completed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_completed) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

class _MessageSelectionToolbar extends StatelessWidget {
  const _MessageSelectionToolbar({
    required this.count,
    required this.onClear,
    required this.onCopy,
    required this.onShare,
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
  final VoidCallback onForward;
  final VoidCallback onAddToCalendar;
  final bool showReactions;
  final ValueChanged<String>? onReactionSelected;
  final VoidCallback? onReactionPicker;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.of(context).textScaler;
    final l10n = context.l10n;
    double scaled(double value) => textScaler.scale(value);
    return SelectionPanelShell(
      includeHorizontalSafeArea: false,
      padding: EdgeInsets.fromLTRB(
        scaled(_composerHorizontalInset),
        scaled(18),
        scaled(_composerHorizontalInset),
        scaled(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectionSummaryHeader(
            count: count,
            onClear: onClear,
          ),
          SizedBox(height: scaled(12)),
          Wrap(
            spacing: scaled(8),
            runSpacing: scaled(8),
            alignment: WrapAlignment.center,
            children: [
              ContextActionButton(
                icon: const Icon(LucideIcons.reply, size: 16),
                label: l10n.chatActionForward,
                onPressed: onForward,
              ),
              ContextActionButton(
                icon: const Icon(LucideIcons.copy, size: 16),
                label: l10n.chatActionCopy,
                onPressed: onCopy,
              ),
              ContextActionButton(
                icon: const Icon(LucideIcons.share2, size: 16),
                label: l10n.chatActionShare,
                onPressed: onShare,
              ),
              ContextActionButton(
                icon: const Icon(LucideIcons.calendarPlus, size: 16),
                label: l10n.chatActionAddToCalendar,
                onPressed: onAddToCalendar,
              ),
            ],
          ),
          if (showReactions && onReactionSelected != null)
            _MultiSelectReactionPanel(
              onEmojiSelected: onReactionSelected!,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Text(
          context.l10n.chatActionReact,
          style: context.textTheme.muted,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: _reactionManagerQuickSpacing,
          runSpacing: _reactionManagerQuickSpacing,
          alignment: WrapAlignment.start,
          children: [
            for (final emoji in _reactionQuickChoices)
              _ReactionQuickButton(
                emoji: emoji,
                onPressed: () => onEmojiSelected(emoji),
              ),
            if (onCustomReaction != null)
              _ReactionAddButton(onPressed: onCustomReaction!),
          ],
        ),
      ],
    );
  }
}

class _CalendarTextSelectionDialog extends StatefulWidget {
  const _CalendarTextSelectionDialog({
    required this.initialText,
  });

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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final maxWidth = math.min(constraints.maxWidth, 720.0);
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: AxiModalSurface(
                padding: const EdgeInsets.all(20),
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
                      const SizedBox(height: 8),
                      Text(
                        'Select a portion of the message to send to the calendar or edit it first.',
                        style: textTheme.muted.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AxiTextInput(
                        controller: _controller,
                        focusNode: _focusNode,
                        minLines: 4,
                        maxLines: 8,
                        keyboardType: TextInputType.multiline,
                        autofocus: true,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ShadButton.ghost(
                            onPressed: () => Navigator.of(context).maybePop(),
                            child: Text(l10n.commonCancel),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ShadButton(
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
    required this.isChatBlocked,
    required this.blocklistEntry,
    required this.blockAddress,
  });

  final ChatState state;
  final ValueChanged<MessageTimelineFilter> onViewFilterChanged;
  final ValueChanged<bool> onToggleNotifications;
  final ValueChanged<bool> onSpamToggle;
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
    final SettingsState settingsState = context.watch<SettingsCubit>().state;
    final BlocklistState? blocklistState =
        context.watch<BlocklistCubit?>()?.state;
    final bool globalSignatureEnabled =
        settingsState.shareTokenSignatureEnabled;
    final bool chatSignatureEnabled = chat.shareSignatureEnabled;
    final bool signatureActive = globalSignatureEnabled && chatSignatureEnabled;
    final String signatureHint = globalSignatureEnabled
        ? l10n.chatSignatureHintEnabled
        : l10n.chatSignatureHintDisabled;
    final String signatureWarning = l10n.chatSignatureHintWarning;
    final bool showAttachmentToggle = chat.type != ChatType.note;
    final bool notificationsMuted = chat.muted;
    final bool isSpamChat = chat.spam;
    final String spamLabel = l10n.chatReportSpam;
    final String? resolvedBlockAddress = blockAddress?.trim();
    final String? resolvedBlockEntryAddress = blocklistEntry?.address.trim();
    final bool hasBlockAddress =
        resolvedBlockAddress != null && resolvedBlockAddress.isNotEmpty;
    final bool hasBlockEntry = blocklistEntry != null;
    final bool blocklistAvailable = blocklistState != null;
    final bool blockActionInFlight = switch (blocklistState) {
      BlocklistLoading state => state.jid == null ||
          state.jid == resolvedBlockAddress ||
          state.jid == resolvedBlockEntryAddress,
      _ => false,
    };
    final bool blockSwitchEnabled = blocklistAvailable &&
        !blockActionInFlight &&
        (isChatBlocked ? hasBlockEntry : hasBlockAddress);
    final List<Widget> tiles = [
      if (showAttachmentToggle)
        Padding(
          padding: _chatSettingsItemPadding,
          child: _ChatAttachmentTrustToggle(chat: chat),
        ),
      Padding(
        padding: _chatSettingsItemPadding,
        child: _ChatViewFilterControl(
          filter: state.viewFilter,
          onChanged: onViewFilterChanged,
        ),
      ),
      Padding(
        padding: _chatSettingsItemPadding,
        child: _ChatSettingsSwitchRow(
          title: l10n.chatMuteNotifications,
          value: notificationsMuted,
          onChanged: (muted) => onToggleNotifications(!muted),
        ),
      ),
      Padding(
        padding: _chatSettingsItemPadding,
        child: _ChatNotificationPreviewControl(
          setting: chat.notificationPreviewSetting,
          onChanged: (setting) => context.read<ChatBloc>().add(
                ChatNotificationPreviewSettingChanged(setting),
              ),
        ),
      ),
      if (chat.supportsEmail)
        Padding(
          padding: _chatSettingsItemPadding,
          child: _ChatSettingsSwitchRow(
            title: l10n.chatSignatureToggleLabel,
            subtitle: '$signatureHint $signatureWarning',
            value: signatureActive,
            onChanged: globalSignatureEnabled
                ? (enabled) => context
                    .read<ChatBloc>()
                    .add(ChatShareSignatureToggled(enabled))
                : null,
          ),
        ),
      Padding(
        padding: _chatSettingsItemPadding,
        child: _ChatSettingsSwitchRow(
          title: spamLabel,
          titleColor: destructiveColor,
          checkedTrackColor: destructiveColor,
          value: isSpamChat,
          onChanged: onSpamToggle,
        ),
      ),
      Padding(
        padding: _chatSettingsItemPadding,
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
                    context.read<BlocklistCubit?>()?.block(
                          address: address,
                        );
                    return;
                  }
                  final entry = blocklistEntry;
                  if (entry == null) {
                    return;
                  }
                  context.read<BlocklistCubit?>()?.unblock(entry: entry);
                }
              : null,
        ),
      ),
    ];
    return ListView(
      padding: EdgeInsets.zero,
      children: tiles,
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
          padding: const EdgeInsets.only(top: _chatSettingsLabelSpacing),
          child: Text(
            resolvedSubtitle,
            style: subtitleStyle,
          ),
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
        const SizedBox(width: _chatSettingsFieldSpacing),
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
  const _ChatViewFilterControl({
    required this.filter,
    required this.onChanged,
  });

  final MessageTimelineFilter filter;
  final ValueChanged<MessageTimelineFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final messageFilterOptions = _messageFilterOptions(l10n);
    return _ChatSettingsRow(
      title: filter.statusLabel(l10n),
      trailing: SizedBox(
        width: _chatSettingsSelectMinWidth,
        child: ShadSelect<MessageTimelineFilter>(
          initialValue: filter,
          onChanged: (value) {
            if (value == null) return;
            onChanged(value);
          },
          options: messageFilterOptions
              .map(
                (option) => ShadOption<MessageTimelineFilter>(
                  value: option.filter,
                  child: Text(option.filter.menuLabel(l10n)),
                ),
              )
              .toList(),
          selectedOptionBuilder: (_, value) => Text(
            value.menuLabel(l10n),
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

  final NotificationPreviewSetting setting;
  final ValueChanged<NotificationPreviewSetting> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return _ChatSettingsRow(
      title: l10n.settingsNotificationPreviews,
      trailing: SizedBox(
        width: _chatSettingsSelectMinWidth,
        child: ShadSelect<NotificationPreviewSetting>(
          initialValue: setting,
          onChanged: (value) {
            if (value == null) return;
            onChanged(value);
          },
          options: NotificationPreviewSetting.values
              .map(
                (option) => ShadOption<NotificationPreviewSetting>(
                  value: option,
                  child: Text(
                    option.label(l10n),
                  ),
                ),
              )
              .toList(),
          selectedOptionBuilder: (_, value) => Text(
            value.label(l10n),
          ),
        ),
      ),
    );
  }
}

extension NotificationPreviewSettingLabels on NotificationPreviewSetting {
  String label(AppLocalizations l10n) => switch (this) {
        NotificationPreviewSetting.inherit =>
          l10n.chatNotificationPreviewOptionInherit,
        NotificationPreviewSetting.show =>
          l10n.chatNotificationPreviewOptionShow,
        NotificationPreviewSetting.hide =>
          l10n.chatNotificationPreviewOptionHide,
      };
}

class _ChatAttachmentTrustToggle extends StatelessWidget {
  const _ChatAttachmentTrustToggle({
    required this.chat,
  });

  final chat_models.Chat chat;

  @override
  Widget build(BuildContext context) {
    const label = 'Automatically download attachments in this chat';
    const hintOn = 'Attachments in this chat will download automatically.';
    const hintOff = 'Attachments are blocked until you approve them.';

    final enabled = chat.attachmentAutoDownload.isAllowed;
    final hint = enabled ? hintOn : hintOff;
    return _ChatSettingsSwitchRow(
      title: label,
      subtitle: hint,
      value: enabled,
      onChanged: (value) => context
          .read<ChatBloc>()
          .add(ChatAttachmentAutoDownloadToggled(value)),
    );
  }
}

class _ReactionManager extends StatelessWidget {
  const _ReactionManager({
    required this.reactions,
    required this.onToggle,
    required this.onAddCustom,
  });

  final List<ReactionPreview> reactions;
  final ValueChanged<String> onToggle;
  final VoidCallback onAddCustom;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final sorted = reactions.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    final hasReactions = sorted.isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(_reactionManagerRadius),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: _reactionManagerPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            if (hasReactions)
              Wrap(
                spacing: _reactionManagerQuickSpacing,
                runSpacing: _reactionManagerQuickSpacing,
                children: [
                  for (final reaction in sorted)
                    _ReactionManagerChip(
                      key: ValueKey(reaction.emoji),
                      data: reaction,
                      onToggle: () => onToggle(reaction.emoji),
                    ),
                ],
              )
            else
              Text(
                context.l10n.chatReactionsNone,
                style: textTheme.small.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
            Text(
              hasReactions
                  ? context.l10n.chatReactionsPrompt
                  : context.l10n.chatReactionsPick,
              style: textTheme.muted,
            ),
            Wrap(
              spacing: _reactionManagerQuickSpacing,
              runSpacing: _reactionManagerQuickSpacing,
              children: [
                for (final emoji in _reactionQuickChoices)
                  _ReactionQuickButton(
                    emoji: emoji,
                    onPressed: () => onToggle(emoji),
                  ),
                _ReactionAddButton(onPressed: onAddCustom),
              ],
            ),
          ],
        ),
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
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final highlighted = data.reactedBySelf;
    final background = highlighted
        ? colors.primary.withValues(alpha: 0.14)
        : colors.secondary.withValues(alpha: 0.05);
    final borderColor =
        highlighted ? colors.primary : colors.border.withValues(alpha: 0.9);
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
              Text(
                data.emoji,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 6),
              Text(
                data.count.toString(),
                style: countStyle,
              ),
              if (data.reactedBySelf) ...[
                const SizedBox(width: 6),
                Icon(
                  LucideIcons.minus,
                  size: 16,
                  color: colors.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    ).withTapBounce();
  }
}

class _ReactionQuickButton extends StatelessWidget {
  const _ReactionQuickButton({
    required this.emoji,
    required this.onPressed,
  });

  final String emoji;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.secondary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colors.border.withValues(alpha: 0.9),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
    ).withTapBounce();
  }
}

class _ReactionAddButton extends StatelessWidget {
  const _ReactionAddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return ShadButton.outline(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.plus,
            size: 16,
            color: colors.primary,
          ),
          const SizedBox(width: 6),
          Text(context.l10n.chatReactionMore),
        ],
      ),
    ).withTapBounce();
  }
}

class _QuotedMessagePreview extends StatelessWidget {
  const _QuotedMessagePreview({
    required this.message,
    required this.isSelf,
  });

  final Message message;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: colors.primary, width: 3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 2,
          children: [
            Text(
              isSelf ? context.l10n.chatSenderYou : message.senderJid,
              style: context.textTheme.small.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Builder(
              builder: (context) {
                final split = ChatSubjectCodec.splitXmppBody(message.body);
                final previewText =
                    split.body.isNotEmpty ? split.body : split.subject;
                return Text(
                  previewText ?? context.l10n.chatQuotedNoContent,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.small,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteBanner extends StatelessWidget {
  const _QuoteBanner({
    super.key,
    required this.message,
    required this.isSelf,
    required this.onClear,
  });

  final Message message;
  final bool isSelf;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  context.l10n.chatReplyingTo,
                  style: context.textTheme.small.copyWith(
                    color: colors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isSelf ? context.l10n.chatSenderYou : message.senderJid,
                  style: context.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Builder(
                  builder: (context) {
                    final split = ChatSubjectCodec.splitXmppBody(
                      message.body,
                    );
                    final previewText =
                        split.body.isNotEmpty ? split.body : split.subject;
                    return Text(
                      previewText ?? context.l10n.chatQuotedNoContent,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.small,
                    );
                  },
                ),
              ],
            ),
          ),
          AxiIconButton(
            iconData: LucideIcons.x,
            tooltip: context.l10n.chatCancelReply,
            onPressed: onClear,
            color: colors.mutedForeground,
            backgroundColor: colors.card,
            borderColor: colors.border,
          ),
        ],
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

class _GuestChatState extends State<GuestChat> {
  static const double _guestHeaderSpacing = 12;
  static const double _guestStatusIconSize = 13;
  static const double _guestBubbleTopSpacing = 8;
  static const double _guestBubbleBottomSpacing = 12;

  final _emojiPopoverController = ShadPopoverController();
  late final FocusNode _focusNode;
  late final TextEditingController _textController;
  late final ScrollController _scrollController;
  late ChatUser _selfUser;
  late ChatUser _axiUser;
  late List<ChatMessage> _messages;
  Locale? _lastLocale;
  var _composerHasText = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _textController = TextEditingController();
    _scrollController = ScrollController();
    _messages = const <ChatMessage>[];
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
    _messages = _buildScriptMessages(l10n);
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
      ];

  List<ChatMessage> _buildScriptMessages(AppLocalizations l10n) {
    final now = DateTime.now();
    return _previewScript(l10n)
        .map(
          (entry) => ChatMessage(
            user: entry.isSelf ? _selfUser : _axiUser,
            createdAt: now.subtract(entry.offset),
            text: entry.text,
            status: entry.status,
          ),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void _handleComposerChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText == _composerHasText) return;
    setState(() {
      _composerHasText = hasText;
    });
  }

  double _bubbleMaxWidth(double maxWidth) {
    final isCompact = maxWidth < smallScreen;
    final fraction = isCompact ? 0.8 : 0.7;
    return math.min(maxWidth * fraction, maxWidth);
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final message = ChatMessage(
      user: _selfUser,
      createdAt: DateTime.now(),
      text: text,
      status: MessageStatus.sent,
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
    await _scrollController.animateTo(
      0,
      duration: baseAnimationDuration,
      curve: Curves.easeOut,
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
        child: _SendMessageAccessory(
          enabled: canSend,
          onPressed: _handleSend,
        ),
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
    final size = MediaQuery.sizeOf(context);
    final isDesktopWidth = size.width >= smallScreen;
    final guestHorizontalPadding = isDesktopWidth
        ? _guestDesktopHorizontalPadding
        : _chatHorizontalPadding;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.colorScheme.background,
        border: Border(
          left: BorderSide(color: context.colorScheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GuestChatHeader(
            contact: _axiUser,
            spacing: _guestHeaderSpacing,
            horizontalPadding: guestHorizontalPadding,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxBubbleWidth = _bubbleMaxWidth(constraints.maxWidth);
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: EdgeInsets.zero,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final previous = index + 1 < _messages.length
                        ? _messages[index + 1]
                        : null;
                    final next = index == 0 ? null : _messages[index - 1];
                    return _GuestMessageBubble(
                      message: message,
                      previous: previous,
                      next: next,
                      selfUserId: _selfUser.id,
                      maxWidth: maxBubbleWidth,
                      topSpacing: _guestBubbleTopSpacing,
                      bottomSpacing: _guestBubbleBottomSpacing,
                      statusIconSize: _guestStatusIconSize,
                      horizontalPadding: guestHorizontalPadding,
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.colorScheme.background,
                border: Border(
                  top: BorderSide(color: context.colorScheme.border),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  guestHorizontalPadding,
                  12,
                  guestHorizontalPadding,
                  0,
                ),
                child: ChatCutoutComposer(
                  controller: _textController,
                  focusNode: _focusNode,
                  hintText: context.l10n.chatComposerMessageHint,
                  onSend: _handleSend,
                  actions: _composerAccessories(
                    canSend: _composerHasText,
                    attachmentsEnabled: false,
                  ),
                  sendEnabled: _composerHasText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestChatHeader extends StatelessWidget {
  const _GuestChatHeader({
    required this.contact,
    required this.spacing,
    required this.horizontalPadding,
  });

  final ChatUser contact;
  final double spacing;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final title =
        contact.firstName?.isNotEmpty == true ? contact.firstName! : contact.id;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          bottom: BorderSide(color: colors.border),
        ),
      ),
      child: Row(
        children: [
          AxiAvatar(jid: contact.id),
          SizedBox(width: spacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: context.textTheme.h4.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.chatGuestSubtitle,
                  style: context.textTheme.small.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestMessageBubble extends StatelessWidget {
  const _GuestMessageBubble({
    required this.message,
    required this.previous,
    required this.next,
    required this.selfUserId,
    required this.maxWidth,
    required this.topSpacing,
    required this.bottomSpacing,
    required this.statusIconSize,
    required this.horizontalPadding,
  });

  final ChatMessage message;
  final ChatMessage? previous;
  final ChatMessage? next;
  final String selfUserId;
  final double maxWidth;
  final double topSpacing;
  final double bottomSpacing;
  final double statusIconSize;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final chatTokens = context.chatTheme;
    final isSelf = message.user.id == selfUserId;
    final chainedPrev = _chatMessagesShouldChain(message, previous);
    final chainedNext = _chatMessagesShouldChain(message, next);
    final backgroundColor = isSelf ? colors.primary : colors.card;
    final borderColor = isSelf ? Colors.transparent : chatTokens.recvEdge;
    final textColor = isSelf ? colors.primaryForeground : colors.foreground;
    final timestampColor =
        isSelf ? colors.primaryForeground : chatTokens.timestamp;
    final statusIcon = message.status?.icon;
    final timeLabel =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';
    final inlineText = DynamicInlineText(
      key: ValueKey(message.createdAt.microsecondsSinceEpoch),
      text: TextSpan(
        text: message.text,
        style: context.textTheme.small.copyWith(
          color: textColor,
          height: 1.3,
        ),
      ),
      details: [
        TextSpan(
          text: timeLabel,
          style: context.textTheme.muted.copyWith(
            color: timestampColor,
            fontSize: statusIconSize,
          ),
        ),
        if (isSelf && statusIcon != null)
          TextSpan(
            text: String.fromCharCode(statusIcon.codePoint),
            style: TextStyle(
              color: timestampColor,
              fontSize: statusIconSize,
              fontFamily: statusIcon.fontFamily,
              package: statusIcon.fontPackage,
            ),
          ),
      ],
    );

    final bubble = ChatBubbleSurface(
      isSelf: isSelf,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      borderRadius: _bubbleBorderRadius(
        isSelf: isSelf,
        chainedPrevious: chainedPrev,
        chainedNext: chainedNext,
      ),
      shadowOpacity: 0,
      shadows: _selectedBubbleShadows(colors.primary),
      bubbleWidthFraction: _cutoutMaxWidthFraction,
      cornerClearance: _bubbleRadius,
      body: Padding(
        padding: _bubblePadding,
        child: inlineText,
      ),
    );
    final showSenderLabel = !chainedPrev;
    Widget bubbleWithLabel = bubble;
    if (showSenderLabel) {
      bubbleWithLabel = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          _MessageSenderLabel(
            user: message.user,
            isSelf: isSelf,
            selfLabel: context.l10n.chatSenderYou,
            leftInset: _senderLabelNoInset,
          ),
          bubble,
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        top: chainedPrev ? 2 : topSpacing,
        bottom: chainedNext ? 4 : bottomSpacing,
        left: horizontalPadding,
        right: horizontalPadding,
      ),
      child: Align(
        alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: bubbleWithLabel,
        ),
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
    final String primaryLabel =
        safeDisplayName.isNotEmpty ? safeDisplayName : safeAddress;
    final String normalizedPrimary = primaryLabel.toLowerCase();
    final String normalizedAddress = safeAddress.toLowerCase();
    final bool showSecondary =
        safeAddress.isNotEmpty && normalizedPrimary != normalizedAddress;
    final String? secondaryLabel =
        showSecondary ? '$_senderLabelAddressPrefix$safeAddress' : null;
    return _SenderLabelBlock(
      primaryLabel: primaryLabel,
      secondaryLabel: secondaryLabel,
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
    final textAlign = isSelf ? TextAlign.right : TextAlign.left;
    final crossAxis =
        isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final primaryStyle = context.textTheme.small.copyWith(
      color: colors.mutedForeground,
      fontWeight: FontWeight.w600,
    );
    final secondaryStyle = context.textTheme.muted.copyWith(
      color: colors.mutedForeground,
    );
    return Padding(
      padding: EdgeInsets.only(
        bottom: _senderLabelBottomSpacing,
        left: leftInset,
      ),
      child: Column(
        spacing: _senderLabelSecondarySpacing,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxis,
        children: [
          Text(
            primaryLabel,
            style: primaryStyle,
            textAlign: textAlign,
          ),
          if (secondaryLabel != null)
            Text(
              secondaryLabel!,
              style: secondaryStyle,
              textAlign: textAlign,
            ),
        ],
      ),
    );
  }
}
