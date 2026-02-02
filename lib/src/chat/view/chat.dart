// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:animations/animations.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/attachments/bloc/attachment_gallery_bloc.dart';
import 'package:axichat/src/attachments/view/attachment_gallery_view.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/blocklist/models/blocklist_entry.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/chat_calendar_bloc.dart';
import 'package:axichat/src/calendar/models/calendar_availability_message.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/calendar_task_ics_message.dart';
import 'package:axichat/src/calendar/reminders/calendar_reminder_controller.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/calendar/storage/chat_calendar_storage.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_coordinator.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_sync_coordinator.dart';
import 'package:axichat/src/calendar/utils/calendar_fragment_policy.dart';
import 'package:axichat/src/calendar/utils/location_autocomplete.dart';
import 'package:axichat/src/calendar/utils/task_share_formatter.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/chat_calendar_widget.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
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
import 'package:axichat/src/chat/view/widgets/calendar_availability_viewer.dart';
import 'package:axichat/src/chat/view/widgets/calendar_fragment_card.dart';
import 'package:axichat/src/chat/view/widgets/chat_calendar_critical_path_card.dart';
import 'package:axichat/src/chat/view/widgets/chat_calendar_task_card.dart';
import 'package:axichat/src/chat/view/widgets/email_image_extension.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/widgets/contact_rename_dialog.dart';
import 'package:axichat/src/chats/view/widgets/selection_panel_shell.dart';
import 'package:axichat/src/chats/view/widgets/transport_aware_avatar.dart';
import 'package:axichat/src/common/bool_tool.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/file_type_detector.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/message_error_l10n.dart';
import 'package:axichat/src/common/policy.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/context_action_button.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/common/unicode_safety.dart';
import 'package:axichat/src/common/url_safety.dart';
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
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide ConnectionState;
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
import 'package:flutter_html/flutter_html.dart' as html_widget;
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

EdgeInsets _bubblePadding(BuildContext context) => EdgeInsets.symmetric(
      horizontal: context.spacing.s,
      vertical: context.spacing.s,
    );
const _bubbleRadius = 18.0;
const _reactionBubbleInset = 12.0;
const _reactionCutoutDepth = 14.0;
const List<BlocklistEntry> _emptyBlocklistEntries = <BlocklistEntry>[];
const _reactionCutoutMinThickness = 28.0;
const _reactionCutoutRadius = 16.0;
const _reactionStripOffset = Offset(0, -2);
EdgeInsets _reactionCutoutPadding(BuildContext context) => EdgeInsets.symmetric(
      horizontal: context.spacing.m,
      vertical: context.spacing.xxs,
    );
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
const double _chatAppBarAvatarSpacing = 8.0;
const double _chatAppBarTitleMinWidth = 220.0;
const double _chatAppBarTitleMaxWidth = 420.0;
const double _chatAppBarTitleWidthScale = 0.45;
const double _chatAppBarCollapsedLeadingWidth = 0.0;
const double _unknownSenderCardPadding = 12.0;
const double _unknownSenderIconSize = 18.0;
const double _unknownSenderTextSpacing = 8.0;
const double _unknownSenderActionSpacing = 8.0;
const _chatSettingsSelectMinWidth = 220.0;
const _chatSettingsFieldSpacing = 8.0;
const _chatSettingsLabelSpacing = 4.0;
const _messageActionIconSize = 16.0;
const int _pinnedBadgeHiddenCount = 0;
const int _pinnedBadgeMaxDisplayCount = 99;
const double _pinnedBadgeIconScale = 0.6;
const double _pinnedBadgeFallbackIconSize =
    AxiIconButton.kDefaultSize * _pinnedBadgeIconScale;
const double _pinnedBadgeInsetScale = 0.08;
const String _calendarFragmentPropertyKey = 'calendarFragment';
const String _calendarTaskIcsPropertyKey = 'calendarTaskIcs';
const String _calendarTaskIcsReadOnlyPropertyKey = 'calendarTaskIcsReadOnly';
const String _calendarAvailabilityPropertyKey = 'calendarAvailability';
const bool _calendarTaskIcsReadOnlyFallback =
    CalendarTaskIcsMessage.defaultReadOnly;
const Uuid _availabilityResponseIdGenerator = Uuid();
const String _composerShareSeparator = '\n\n';
const String _emptyText = '';
const List<InlineSpan> _emptyInlineSpans = <InlineSpan>[];
const _selectionExtrasMaxWidth = 500.0;
const _messageAvatarSize = 36.0;
const _messageRowAvatarReservation = 32.0;
const _messageAvatarCutoutPadding = EdgeInsets.zero;
const _messageAvatarCutoutAlignment = -1.0;
const _messageAvatarCornerClearance = 0.0;
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
const double _chatCalendarTransitionVisibleValue = 1.0;
const double _chatCalendarTransitionHiddenValue = 0.0;
const _chatHorizontalPadding = 16.0;
const _chatPinnedPanelHorizontalPadding = _chatHorizontalPadding;
const _chatPinnedPanelVerticalPadding = 12.0;
const _chatPinnedPanelHeaderSpacing = 12.0;
const _chatPinnedPanelEmptyStatePadding = 12.0;
const _chatPinnedPanelMinHeight = 0.0;
const int _pinnedSenderMaxLines = 1;
const _selectionAttachmentBaseGap = 16.0;
const _selectionAttachmentSelectedGap = 8.0;
const double _attachmentSurfaceCornerRadius = _bubbleRadius;
const double _calendarMessageCardCornerRadius = 18.0;
const OutlinedBorder _attachmentSurfaceShadowShape = ContinuousRectangleBorder(
  borderRadius: BorderRadius.all(
    Radius.circular(_attachmentSurfaceCornerRadius),
  ),
);
const ShapeBorder _calendarMessageCardShadowShape = ContinuousRectangleBorder(
  borderRadius: BorderRadius.all(
    Radius.circular(_calendarMessageCardCornerRadius),
  ),
);
const ShapeBorder _calendarTaskShadowShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(calendarEventRadius)),
);
const _selectionExtrasViewportGap = 50.0;
final _selectionSpacerTimestamp = DateTime.fromMillisecondsSinceEpoch(
  0,
  isUtc: true,
);
const _reactionQuickChoices = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '👏'];
const _selectionSpacerMessageId = '__selection_spacer__';
const _emptyStateMessageId = '__empty_state__';
const _unreadDividerMessageId = '__unread_divider__';
const _chatScrollStoragePrefix = 'chat-scroll-offset-';
const _composerHorizontalInset = _chatHorizontalPadding + 4.0;
const _desktopComposerHorizontalInset = _composerHorizontalInset + 4.0;
const _composerNoticeHorizontalInset = 4.0;
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
const _typingIndicatorPadding = EdgeInsets.symmetric(
  horizontal: 12,
  vertical: 8,
);
const _messageFallbackOuterPadding = EdgeInsets.symmetric(
  horizontal: _chatHorizontalPadding,
  vertical: 4,
);
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
                  const SizedBox(width: 12),
                  ShadSwitch(
                    value: state.excludeSubject,
                    onChanged: (value) => context
                        .read<ChatSearchCubit>()
                        .toggleExcludeSubject(value),
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
          buildWhen: (previous, current) => previous.items != current.items,
          builder: (context, rosterState) {
            final rosterItems = rosterState.items ?? const <RosterItem>[];
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
            final canAddContact = !isEmailChat || state.emailServiceAvailable;
            final l10n = context.l10n;
            final actions = <Widget>[
              if (onAddContact != null && canAddContact)
                ContextActionButton(
                  icon: const Icon(
                    LucideIcons.userPlus,
                    size: _unknownSenderIconSize,
                  ),
                  label: l10n.rosterAddTitle,
                  onPressed: () async {
                    await onAddContact!();
                  },
                ),
              if (onReportSpam != null)
                ContextActionButton(
                  icon: const Icon(
                    LucideIcons.shieldAlert,
                    size: _unknownSenderIconSize,
                  ),
                  label: l10n.chatReportSpam,
                  onPressed: () async {
                    await onReportSpam!();
                  },
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
  final radius = Radius.circular(spacing.m + spacing.xxs);
  if (!chainedPrevious && !chainedNext) {
    return ContinuousRectangleBorder(
      borderRadius: BorderRadius.all(radius),
    );
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

ChatCalendarSyncCoordinator? _readChatCalendarCoordinator(
  BuildContext context, {
  required bool calendarAvailable,
}) =>
    calendarAvailable ? context.read<ChatCalendarSyncCoordinator>() : null;

CalendarAvailabilityShareCoordinator? _readAvailabilityShareCoordinator(
  BuildContext context, {
  required bool calendarAvailable,
}) =>
    calendarAvailable
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
          useSurface: true,
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
  late ScrollController _scrollController;
  bool _composerHasText = false;
  bool get _composerHasContent =>
      _composerHasText || _pendingCalendarTaskIcs != null;
  String _lastSubjectValue = '';
  bool _subjectChangeSuppressed = false;
  List<ComposerRecipient> _recipients = const [];
  String? _recipientsChatJid;
  ChatCalendarBloc? _chatCalendarBloc;
  String? _chatCalendarJid;
  ChatCalendarSyncCoordinator? _fallbackChatCalendarCoordinator;
  final _oneTimeAllowedAttachmentStanzaIds = <String>{};
  final _loadedEmailImageMessageIds = <String>{};
  final _fileMetadataStreamEntries = <String, _FileMetadataStreamEntry>{};
  final _animatedMessageIds = <String>{};
  var _hydratedAnimatedMessages = false;
  var _chatOpenedAt = DateTime.now();
  static final Map<String, double> _scrollOffsetCache = {};
  String? _lastScrollStorageKey;

  var _chatRoute = ChatRouteIndex.main;
  var _previousChatRoute = ChatRouteIndex.main;
  LocalHistoryEntry? _chatRouteHistoryEntry;
  bool _pinnedPanelVisible = false;
  String? _selectedMessageId;
  final _multiSelectedMessageIds = <String>{};
  final _selectedMessageSnapshots = <String, Message>{};
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
  final _bubbleRegionRegistry = _BubbleRegionRegistry();
  final _messageListKey = GlobalKey();
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

  void _typingListener() {
    final text = _textController.text;
    final hasText = text.isNotEmpty;
    final trimmedHasText = text.trim().isNotEmpty;
    if (_composerHasText != trimmedHasText && mounted) {
      setState(() {
        _composerHasText = trimmedHasText;
      });
    }
    _maybeClearPendingCalendarTaskIcs(text);
    if (!context.read<SettingsCubit>().state.indicateTyping) return;
    if (!hasText) return;
    context.read<ChatBloc>().add(const ChatTypingStarted());
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
          target: FanOutTarget.chat(
            chat: chat,
            shareSignatureEnabled: chat.shareSignatureEnabled ??
                context.read<SettingsCubit>().state.shareTokenSignatureEnabled,
          ),
          included: true,
          pinned: true,
        ),
      ];
    }
    if (!mounted) return;
    setState(() {});
  }

  void _handleRecipientAdded(FanOutTarget target) {
    final address = target.address?.trim();
    if (target.chat == null &&
        target.transport == null &&
        address != null &&
        address.isNotEmpty) {
      _resolveAddressTransport(address).then((transport) {
        if (!mounted || transport == null) return;
        final resolved = FanOutTarget.address(
          address: address,
          displayName: target.displayName,
          shareSignatureEnabled: target.shareSignatureEnabled,
          transport: transport,
        );
        _applyRecipient(resolved);
      });
      return;
    }
    _applyRecipient(target);
  }

  void _applyRecipient(FanOutTarget target) {
    final index = _recipients.indexWhere((recipient) {
      return recipient.key == target.key;
    });
    if (index >= 0) {
      final recipient = _recipients[index];
      final updated = List<ComposerRecipient>.from(_recipients)
        ..[index] = recipient.copyWith(target: target, included: true);
      setState(() {
        _recipients = updated;
      });
      return;
    }
    setState(() {
      _recipients = [
        ..._recipients,
        ComposerRecipient(target: target, included: true),
      ];
    });
  }

  Future<MessageTransport?> _resolveAddressTransport(String address) async {
    final endpointConfig = context.read<SettingsCubit>().state.endpointConfig;
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
    final updated = _recipients.where((recipient) {
      return recipient.key != key || recipient.pinned;
    }).toList(growable: false);
    if (updated.length == _recipients.length) return;
    setState(() {
      _recipients = updated;
    });
  }

  void _handleRecipientToggled(String key) {
    final index = _recipients.indexWhere((recipient) {
      return recipient.key == key;
    });
    if (index == -1) return;
    final current = _recipients[index];
    if (current.pinned) return;
    final updated = List<ComposerRecipient>.from(_recipients)
      ..[index] = current.copyWith(included: !current.included);
    setState(() {
      _recipients = updated;
    });
  }

  void _handleRecipientAddedFromChat(chat_models.Chat chat) {
    _handleRecipientAdded(
      FanOutTarget.chat(
        chat: chat,
        shareSignatureEnabled: chat.shareSignatureEnabled ??
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
      sendMessage: ({
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
      sendSnapshotFile: (file) =>
          locate<ChatBloc>().uploadCalendarSnapshot(file),
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
    final xmppService = context.read<XmppService>();
    final endpointConfig = context.read<SettingsCubit>().state.endpointConfig;
    final emailService =
        endpointConfig.enableSmtp ? context.read<EmailService>() : null;
    final availabilityCoordinator = _readAvailabilityShareCoordinator(
      context,
      calendarAvailable: storageManager.isAuthStorageReady,
    );
    final bloc = ChatCalendarBloc(
      chatJid: resolvedChat.jid,
      chatType: resolvedChat.type,
      coordinator: resolvedCoordinator,
      storage: storage,
      xmppService: xmppService,
      emailService: emailService,
      reminderController: reminderController,
      availabilityCoordinator: availabilityCoordinator,
    )..add(const CalendarEvent.started());
    _chatCalendarBloc = bloc;
    _chatCalendarJid = resolvedChat.jid;
    return bloc;
  }

  void _appendTaskShareText(CalendarTask task, {String? shareText}) {
    final String resolvedShareText =
        shareText ?? task.toShareText(context.l10n);
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
    final String shareText = task.toShareText(context.l10n).trim();
    final bool canShareIcs = decision.canWrite ||
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
      metadata.add(TextSpan(
        text: l10n.calendarCopyLocation(location),
        style: detailStyle,
      ));
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
    final DateTime? end = task.endDate ??
        (task.duration == null ? null : scheduled.add(task.duration!));
    final String startText =
        TimeFormatter.formatFriendlyDateTime(l10n, scheduled);
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
    if (context.read<ChatBloc>().state.chat?.defaultTransport.isEmail == true) {
      _showSnackbar(
          context.l10n.chatAvailabilityRequestEmailUnsupportedMessage);
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
    if (context.read<ChatBloc>().state.chat?.defaultTransport.isEmail == true) {
      _showSnackbar(
          context.l10n.chatAvailabilityRequestEmailUnsupportedMessage);
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
            message: CalendarAvailabilityMessage.response(response: response),
          ),
        );
  }

  void _handleAvailabilityDecline(CalendarAvailabilityRequest request) {
    if (context.read<ChatBloc>().state.chat?.defaultTransport.isEmail == true) {
      _showSnackbar(
          context.l10n.chatAvailabilityRequestEmailUnsupportedMessage);
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
      _showSnackbar(
        l10n.chatAvailabilityRequestChatCalendarUnavailableMessage,
      );
      return;
    }
    final storageManager = context.read<CalendarStorageManager>();
    final coordinator = _readChatCalendarCoordinator(
      context,
      calendarAvailable: storageManager.isAuthStorageReady,
    );
    if (coordinator == null) {
      _showSnackbar(
        l10n.chatAvailabilityRequestChatCalendarUnavailableMessage,
      );
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
      _showSnackbar(
        l10n.chatAvailabilityRequestChatCalendarUnavailableMessage,
      );
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
    return addressResourcePart(senderJid);
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

  String? _normalizeOccupantId(String? jid) {
    return normalizedOccupantId(jid);
  }

  bool _isMucOccupantSender({
    required String senderJid,
    required String? chatJid,
  }) {
    final senderBare = normalizedAddressKey(senderJid);
    final chatBare = normalizedAddressKey(chatJid);
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
      return normalizedAddressKey(senderJid) ==
          normalizedAddressKey(trimmedClaimed);
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
    return normalizedAddressKey(realJid) ==
        normalizedAddressKey(trimmedClaimed);
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

  bool _isMucSelfMessage({
    required String senderJid,
    required String? occupantId,
    required String? myOccupantId,
    required String? selfNick,
  }) {
    final normalizedSelf = _normalizeOccupantId(myOccupantId);
    if (normalizedSelf != null) {
      final normalizedSender = _normalizeOccupantId(senderJid);
      if (normalizedSender != null && normalizedSender == normalizedSelf) {
        return true;
      }
      final normalizedOccupant = _normalizeOccupantId(occupantId);
      if (normalizedOccupant != null && normalizedOccupant == normalizedSelf) {
        return true;
      }
    }
    final trimmedSelfNick = selfNick?.trim();
    if (trimmedSelfNick == null || trimmedSelfNick.isEmpty) {
      return false;
    }
    final senderNick = _nickFromSender(senderJid);
    if (senderNick == null || senderNick.isEmpty) {
      return false;
    }
    return senderNick == trimmedSelfNick;
  }

  bool _isQuotedMessageFromSelf({
    required Message quotedMessage,
    required bool isGroupChat,
    required String? myOccupantId,
    required String? selfNick,
    required String? currentUserId,
  }) {
    if (isGroupChat) {
      return _isMucSelfMessage(
        senderJid: quotedMessage.senderJid,
        occupantId: quotedMessage.occupantID,
        myOccupantId: myOccupantId,
        selfNick: selfNick,
      );
    }
    return bareAddress(quotedMessage.senderJid) == bareAddress(currentUserId);
  }

  void _toggleSettingsPanel() {
    if (!mounted) return;
    if (_chatRoute.isSettings) {
      _setChatRoute(ChatRouteIndex.main);
      return;
    }
    _setChatRoute(ChatRouteIndex.settings);
  }

  void _setViewFilter(MessageTimelineFilter filter) {
    context.read<ChatBloc>().add(ChatViewFilterChanged(filter: filter));
  }

  void _toggleNotifications(bool enable) {
    context.read<ChatBloc>().add(ChatMuted(!enable));
  }

  void _showMembers({bool refreshMembership = true}) {
    final locate = context.read;
    if (refreshMembership) {
      locate<ChatBloc>().add(const ChatRoomMembersOpened());
    }
    final navigator = Navigator.of(context);
    final spacing = context.spacing;
    final sizing = context.sizing;
    final Duration animationDuration =
        locate<SettingsCubit>().animationDuration;
    final colors = context.colorScheme;
    final motion = context.motion;
    final scrimColor = colors.foreground.withValues(
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
          child: Padding(
            padding: EdgeInsetsDirectional.only(start: spacing.m),
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
                      value: locate<ChatBloc>(),
                      child: Builder(
                        builder: (dialogContext) => _RoomMembersDrawerContent(
                          onInvite: (jid) =>
                              locate<ChatBloc>().add(ChatInviteRequested(jid)),
                          onAction: (occupantId, action) =>
                              locate<ChatBloc>().add(
                            ChatModerationActionRequested(
                              occupantId: occupantId,
                              action: action,
                            ),
                          ),
                          onChangeNickname: (nick) => locate<ChatBloc>().add(
                            ChatNicknameChangeRequested(nick),
                          ),
                          onLeaveRoom: () => locate<ChatBloc>().add(
                            const ChatLeaveRoomRequested(),
                          ),
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
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeScaleTransition(animation: animation, child: child),
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
    final l10n = context.l10n;
    final chatTitle = context.read<ChatBloc>().state.chat!.displayName;
    context.read<ChatBloc>().add(
          ChatSpamStatusRequested(
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
    if (context.read<ChatBloc>().state.chat == null) return;
    if (context.read<ChatBloc>().state.chat!.remoteJid.trim().isEmpty) {
      return;
    }
    final l10n = context.l10n;
    context.read<ChatBloc>().add(
          ChatContactAddRequested(
            successTitle: l10n.rosterAddTitle,
            failureTitle: l10n.rosterAddTitle,
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
    return _fileMetadataStreamEntries.putIfAbsent(id, () {
      final entry = _FileMetadataStreamEntry();
      entry.attach(context.read<ChatBloc>().fileMetadataStreamFor(id));
      return entry;
    });
  }

  Stream<FileMetadataData?> _metadataStreamFor(String id) {
    return _metadataEntryFor(id).stream;
  }

  FileMetadataData? _metadataInitialFor(String id) {
    return _metadataEntryFor(id).latestOrNull;
  }

  bool _hasEmailAttachmentTarget({
    required chat_models.Chat chat,
    required List<ComposerRecipient> recipients,
  }) {
    if (chat.defaultTransport.isEmail) {
      return true;
    }
    for (final recipient in recipients) {
      final transport =
          recipient.target.chat?.defaultTransport ?? recipient.target.transport;
      if (transport?.isEmail ?? false) {
        return true;
      }
    }
    return false;
  }

  List<BlocklistEntry> _resolveBlocklistEntries() {
    final blocklistCubit = context.watch<BlocklistCubit>();
    final List<BlocklistEntry>? cachedEntries = switch (blocklistCubit.state) {
      BlocklistAvailable state => state.items ??
          blocklistCubit[BlocklistCubit.blocklistItemsCacheKey]
              as List<BlocklistEntry>?,
      _ => blocklistCubit[BlocklistCubit.blocklistItemsCacheKey]
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
      final String? normalizedCandidate = normalizedAddressValue(candidate);
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
    return (resolvedChat.attachmentAutoDownload ??
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
    final displaySender =
        senderEmail?.isNotEmpty == true ? senderEmail! : senderJid;
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
      context.read<ChatBloc>().add(
            const ChatAttachmentAutoDownloadToggled(true),
          );
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
    final bool hasSubject = _subjectController.text.trim().isNotEmpty;
    final bool hasCalendarTask = _pendingCalendarTaskIcs != null;
    final canSend = !hasPreparingAttachments &&
        (resolvedText.isNotEmpty ||
            hasQueuedAttachments ||
            hasSubject ||
            hasCalendarTask);
    if (!canSend) return;
    final confirmed = await _confirmMediaMetadataIfNeeded(queuedAttachments);
    if (!confirmed || !mounted) return;
    context.read<ChatBloc>().add(
          ChatMessageSent(
            text: resolvedText,
            recipients: _recipients,
            calendarTaskIcs: _pendingCalendarTaskIcs,
            calendarTaskIcsReadOnly: _calendarTaskIcsReadOnlyFallback,
          ),
        );
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
      dialogMaxWidth: context.sizing.dialogMaxWidth,
      surfacePadding: EdgeInsets.zero,
      builder: (sheetContext) {
        return AxiSheetScaffold.scroll(
          header: AxiSheetHeader(
            title: Text(sheetContext.l10n.commonActions),
            onClose: () => Navigator.of(sheetContext).maybePop(),
          ),
          children: [
            AxiListButton(
              leading: Icon(
                LucideIcons.save,
                color: sheetContext.colorScheme.primary,
              ),
              onPressed: () => Navigator.of(sheetContext).pop('save'),
              child: Text(sheetContext.l10n.chatSaveAsDraft),
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
    if (context.read<ChatBloc>().state.chat == null) {
      _showSnackbar(l10n.chatDraftUnavailable);
      return;
    }
    final body = _textController.text;
    final subject = _subjectController.text;
    final trimmedSubject = subject.trim();
    final attachments = context
        .read<ChatBloc>()
        .state
        .pendingAttachments
        .map((pending) => pending.attachment)
        .toList();
    final recipients = _resolveDraftRecipients(
      chat: context.read<ChatBloc>().state.chat!,
      recipients: _recipients,
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
        attachments.add(
          EmailAttachment(
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
      for (final attachment in attachments) {
        context.read<ChatBloc>().add(
              ChatAttachmentPicked(
                attachment: attachment,
                recipients: _recipients,
              ),
            );
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
          onPressed: () => context.read<ChatBloc>().add(
                ChatAttachmentRetryRequested(
                  attachmentId: pending.id,
                  recipients: _recipients,
                ),
              ),
          child: Text(l10n.chatAttachmentRetry),
        ),
      );
    }
    items.add(
      ShadContextMenuItem(
        leading: const Icon(LucideIcons.trash),
        onPressed: () => context.read<ChatBloc>().add(
              ChatPendingAttachmentRemoved(pending.id),
            ),
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
    await showFadeScaleDialog<void>(
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

  Future<void> _showHtmlPreview({
    required String html,
    required bool shouldLoadImages,
    required VoidCallback? onLoadRequested,
  }) async {
    if (!mounted) return;
    await showFadeScaleDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _HtmlPreviewDialog(
          html: html,
          shouldLoadImages: shouldLoadImages,
          onLoadRequested: onLoadRequested,
          onLinkTap: _handleLinkTap,
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
    const maxDecodeBytes = 16 * 1024 * 1024;
    final sizeBytes = attachment.sizeBytes;
    if (sizeBytes > maxDecodeBytes) {
      return null;
    }
    final file = File(attachment.path);
    if (!await file.exists()) return null;
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > maxDecodeBytes) {
        return null;
      }
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      codec.dispose();
      try {
        return Size(image.width.toDouble(), image.height.toDouble());
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
      dialogMaxWidth: context.sizing.dialogMaxWidth,
      surfacePadding: EdgeInsets.zero,
      builder: (sheetContext) {
        final attachment = pending.attachment;
        final sizeLabel = formatBytes(attachment.sizeBytes, l10n);
        final colors = sheetContext.colorScheme;
        final spacing = sheetContext.spacing;
        return BlocProvider.value(
          value: locate<ChatBloc>(),
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
                        context.read<ChatBloc>().add(
                              ChatAttachmentRetryRequested(
                                attachmentId: pending.id,
                                recipients: _recipients,
                              ),
                            );
                      },
                      child: Text(l10n.chatAttachmentRetry),
                    ),
                  AxiListButton(
                    leading: const Icon(LucideIcons.trash),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.read<ChatBloc>().add(
                            ChatPendingAttachmentRemoved(pending.id),
                          );
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
      final resolvedSelfAvatarPath = selfAvatarPath!;
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
    final sameItems = identical(items, _cachedItems);
    final sameQuoted = identical(quotedMessagesById, _cachedQuotedMessagesById);
    final sameSearch = identical(searchResults, _cachedSearchResults);
    final sameSearchFiltering = searchFiltering == _cachedSearchFiltering;
    final sameAttachments =
        identical(attachmentsByMessageId, _cachedAttachmentsByMessageId);
    final sameGroupLeaders =
        identical(groupLeaderByMessageId, _cachedGroupLeaderByMessageId);
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

    final filteredItems = displayItems.where((message) {
      final hasHtml = message.normalizedHtmlBody?.isNotEmpty == true;
      final attachments = attachmentsForMessage(message);
      return message.body != null ||
          hasHtml ||
          message.error.isNotNone ||
          attachments.isNotEmpty;
    }).toList(growable: false);
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
    final resolvedIds = <String>{};
    for (final message in orderedMessages) {
      final id = message.stanzaID;
      if (_multiSelectedMessageIds.contains(id)) {
        selected.add(message);
        resolvedIds.add(id);
      }
    }
    if (selected.length == _multiSelectedMessageIds.length) {
      return selected;
    }
    for (final id in _multiSelectedMessageIds) {
      if (resolvedIds.contains(id)) continue;
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
    _syncSelectionCaches(
      context.read<ChatBloc>().state,
      notify: false,
    );
    _subjectFocusNode.onKeyEvent = _handleSubjectKeyEvent;
    _focusNode.onKeyEvent = _handleComposerKeyEvent;
    _textController.addListener(_typingListener);
    _subjectController.addListener(_handleSubjectChanged);
    final chat = context.read<ChatBloc>().state.chat;
    _recipientsChatJid = chat?.jid;
    final settings = context.read<SettingsCubit>().state;
    if (chat != null) {
      _recipients = [
        ComposerRecipient(
          target: FanOutTarget.chat(
            chat: chat,
            shareSignatureEnabled: chat.shareSignatureEnabled ??
                settings.shareTokenSignatureEnabled,
          ),
          included: true,
          pinned: true,
        ),
      ];
    }
    context
        .read<ChatBloc>()
        .add(ChatSettingsUpdated(_settingsSnapshotFromState(settings)));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentKey = _scrollStorageKey;
    if (_lastScrollStorageKey == null) {
      _lastScrollStorageKey = currentKey;
      _restoreScrollOffsetForCurrentChat();
      _syncChatRoute();
      _updateChatRouteHistoryEntry();
      return;
    }
    if (_lastScrollStorageKey != currentKey) {
      _persistScrollOffset(key: _lastScrollStorageKey);
      _lastScrollStorageKey = currentKey;
      _restoreScrollOffsetForCurrentChat();
    }
    _syncChatRoute();
    _updateChatRouteHistoryEntry();
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
        final resolvedProfileJid = profileJid.trim();
        final String? selfJid =
            resolvedProfileJid.isNotEmpty ? resolvedProfileJid : null;
        final selfIdentity = SelfIdentitySnapshot(
          selfJid: selfJid,
          avatarPath: context.watch<ProfileCubit>().state.avatarPath,
        );
        final showToast = ShadToaster.maybeOf(context)?.show;
        return MultiBlocListener(
          listeners: [
            BlocListener<SettingsCubit, SettingsState>(
              listenWhen: (previous, current) =>
                  previous.language != current.language ||
                  previous.chatReadReceipts != current.chatReadReceipts ||
                  previous.emailReadReceipts != current.emailReadReceipts ||
                  previous.shareTokenSignatureEnabled !=
                      current.shareTokenSignatureEnabled,
              listener: (context, settings) {
                context
                    .read<ChatBloc>()
                    .add(ChatSettingsUpdated(_settingsSnapshotFromState(
                      settings,
                    )));
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
                  extraMessages:
                      searchState.active ? searchState.results : const [],
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
              listener: (_, chatsState) {
                if (!mounted) return;
                final nextRoute = chatsState.openChatRoute;
                if (_chatRoute == nextRoute) return;
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
                final resolvedTitle = toast.title ??
                    switch (toast.variant) {
                      ChatToastVariant.destructive => l10n.toastWhoopsTitle,
                      ChatToastVariant.warning => l10n.toastHeadsUpTitle,
                      ChatToastVariant.info => l10n.toastAllSetTitle,
                    };
                final toastWidget = switch (toast.variant) {
                  ChatToastVariant.destructive => FeedbackToast.error(
                      title: resolvedTitle,
                      message: toast.message,
                      actionLabel: actionLabel,
                      onAction: onAction,
                    ),
                  ChatToastVariant.warning => FeedbackToast.warning(
                      title: resolvedTitle,
                      message: toast.message,
                      actionLabel: actionLabel,
                      onAction: onAction,
                    ),
                  ChatToastVariant.info => FeedbackToast.success(
                      title: resolvedTitle,
                      message: toast.message,
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
            BlocListener<ChatBloc, ChatState>(
              listenWhen: (previous, current) =>
                  current.composerClearId != 0 &&
                  previous.composerClearId != current.composerClearId,
              listener: (_, __) {
                _textController.clear();
                _composerHasText = false;
                if (_pendingCalendarTaskIcs != null ||
                    _pendingCalendarSeedText != null) {
                  setState(() {
                    _pendingCalendarTaskIcs = null;
                    _pendingCalendarSeedText = null;
                  });
                }
                _focusNode.requestFocus();
              },
            ),
            BlocListener<ChatBloc, ChatState>(
              listenWhen: (previous, current) =>
                  current.emailSubjectHydrationId != 0 &&
                  previous.emailSubjectHydrationId !=
                      current.emailSubjectHydrationId,
              listener: (context, state) {
                final subject = state.emailSubjectHydrationText ?? '';
                _subjectChangeSuppressed = true;
                _subjectController
                  ..text = subject
                  ..selection = TextSelection.collapsed(
                    offset: subject.length,
                  );
                _lastSubjectValue = subject;
                _subjectChangeSuppressed = false;
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
                _resetRecipientsForChat(state.chat);
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
            BlocListener<ChatBloc, ChatState>(
              listenWhen: (previous, current) =>
                  previous.items != current.items ||
                  previous.quotedMessagesById != current.quotedMessagesById,
              listener: (context, state) {
                final searchState = context.read<ChatSearchCubit>().state;
                _syncSelectionCaches(
                  state,
                  extraMessages:
                      searchState.active ? searchState.results : const [],
                );
              },
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
                  context.watch<ProfileCubit>().state;
              ChatsState? chatsState() => context.watch<ChatsCubit>().state;
              final readOnly = widget.readOnly;
              final emailSelfJid = state.emailSelfJid;
              final String? resolvedEmailSelfJid =
                  emailSelfJid.resolveDeltaPlaceholderJid();
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
              final String? selfXmppJid = resolvedProfileJid?.isNotEmpty == true
                  ? resolvedProfileJid
                  : null;
              final String? accountJidForPins = isDefaultEmail
                  ? (resolvedEmailSelfJid ?? selfXmppJid)
                  : (selfXmppJid ?? resolvedEmailSelfJid);
              final String? normalizedXmppSelfJid =
                  normalizedAddressKey(selfXmppJid);
              final String? normalizedEmailSelfJid =
                  normalizedAddressKey(resolvedEmailSelfJid);
              final String? normalizedChatJid =
                  normalizedAddressKey(chatEntity?.remoteJid);
              final bool isSelfChat = normalizedChatJid != null &&
                  ((normalizedXmppSelfJid != null &&
                          normalizedChatJid == normalizedXmppSelfJid) ||
                      (normalizedEmailSelfJid != null &&
                          normalizedChatJid == normalizedEmailSelfJid));
              final String? selfAvatarPath = profileState()?.avatarPath?.trim();
              final myOccupantId = state.roomState?.myOccupantId;
              final myOccupant = myOccupantId == null
                  ? null
                  : state.roomState?.occupants[myOccupantId];
              final selfNick =
                  (myOccupant?.nick ?? chatEntity?.myNickname)?.trim();
              final String? availabilityActorId = _availabilityActorId(
                chat: chatEntity,
                currentUserId: currentUserId,
                roomState: state.roomState,
              );
              final shareContexts = state.shareContexts;
              final shareReplies = state.shareReplies;
              final recipients = _recipients;
              final pendingAttachments = state.pendingAttachments;
              final canSendEmailAttachments = state.emailServiceAvailable &&
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
              final rosterItems = context.watch<RosterCubit>().state.items ??
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
                final roomState = state.roomState;
                if (roomState == null) return null;
                final parsed = parseJid(trimmed);
                final nick = parsed?.resource.trim() ?? '';
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
                final bareRealJid = bareAddress(realJid) ?? realJid;
                return avatarPathForBareJid(bareRealJid);
              }

              final storageManager = context.watch<CalendarStorageManager>();
              final chatCalendarCoordinator = _resolveChatCalendarCoordinator(
                storageManager: storageManager,
              );
              final bool demoEmailCalendarEnabled = kEnableDemoChats &&
                  (chatEntity?.defaultTransport.isEmail ?? false);
              final storage = storageManager.authStorage;
              final ChatCalendarSyncCoordinator? demoEmailCoordinator =
                  demoEmailCalendarEnabled && storage != null
                      ? ChatCalendarSyncCoordinator(
                          storage: ChatCalendarStorage(storage: storage),
                          sendMessage: ({
                            required String jid,
                            required CalendarSyncOutbound outbound,
                            required ChatType chatType,
                          }) async {},
                        )
                      : null;
              final bool personalCalendarAvailable =
                  storageManager.isAuthStorageReady;
              final CalendarBloc? personalCalendarBloc =
                  personalCalendarAvailable
                      ? context.read<CalendarBloc>()
                      : null;
              final bool supportsChatCalendar =
                  chatEntity?.supportsChatCalendar ?? false;
              final bool chatCalendarReady =
                  storageManager.isAuthStorageReady &&
                      chatCalendarCoordinator != null;
              final bool demoEmailCalendarReady = demoEmailCoordinator != null;
              final bool chatCalendarEnabled =
                  (supportsChatCalendar && chatCalendarReady) ||
                      demoEmailCalendarReady;
              final ChatCalendarBloc? chatCalendarBloc =
                  _resolveChatCalendarBloc(
                chat: chatEntity,
                calendarAvailable: chatCalendarEnabled,
                coordinator: supportsChatCalendar
                    ? chatCalendarCoordinator
                    : demoEmailCoordinator,
              );
              final bool chatCalendarAvailable =
                  chatCalendarEnabled && chatCalendarBloc != null;
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
              final AppBarActionItem? closeAction = readOnly
                  ? null
                  : AppBarActionItem(
                      label: context.l10n.commonClose,
                      iconData: LucideIcons.x,
                      onPressed: () {
                        if (!prepareChatExit()) return;
                        final chatsCubit = context.read<ChatsCubit>();
                        chatsCubit.closeAllChats();
                      },
                    );
              final List<AppBarActionItem> navigationActions =
                  <AppBarActionItem>[
                if (!readOnly && openStack.length > 1)
                  AppBarActionItem(
                    label: context.l10n.chatBack,
                    iconData: LucideIcons.arrowLeft,
                    onPressed: () {
                      if (!prepareChatExit()) return;
                      final chatsCubit = context.read<ChatsCubit>();
                      chatsCubit.popChat();
                    },
                  ),
                if (!readOnly && forwardStack.isNotEmpty)
                  AppBarActionItem(
                    label: context.l10n.chatMessageOpenChat,
                    iconData: LucideIcons.arrowRight,
                    onPressed: () {
                      if (!prepareChatExit()) return;
                      final chatsCubit = context.read<ChatsCubit>();
                      chatsCubit.restoreChat();
                    },
                  ),
              ];
              final List<AppBarActionItem> leadingActions = <AppBarActionItem>[
                if (closeAction != null) closeAction,
                ...navigationActions,
              ];
              final int leadingActionCount = leadingActions.length;
              final int chatActionCount = _chatBaseActionCount +
                  (isGroupChat ? 1 : 0) +
                  (chatCalendarAvailable ? 1 : 0) +
                  (canShowSettings ? 1 : 0);
              final scaffold = LayoutBuilder(
                builder: (context, constraints) {
                  final double appBarWidth = constraints.maxWidth;
                  const double avatarTitleSpacingOffset = 4.0;
                  const double avatarTitleSpacing =
                      _chatAppBarAvatarSpacing + avatarTitleSpacingOffset;
                  final double leadingWidthExpanded = leadingActionCount == 0
                      ? _chatAppBarCollapsedLeadingWidth
                      : _chatAppBarLeadingInset +
                          (AxiIconButton.kTapTargetSize * leadingActionCount) +
                          (_chatAppBarLeadingSpacing *
                              math.max(0, leadingActionCount - 1));
                  final double chatActionsWidth = chatActionCount == 0
                      ? 0
                      : (AxiIconButton.kTapTargetSize * chatActionCount) +
                          (_chatHeaderActionSpacing *
                              math.max(0, chatActionCount - 1));
                  final double titleReserveWidth =
                      context.sizing.iconButtonSize +
                          avatarTitleSpacing +
                          _chatAppBarTitleMinWidth;
                  const double actionsPaddingWidth =
                      _chatAppBarActionsPadding * 2;
                  final bool collapseAppBarActions = leadingActionCount > 0 &&
                      appBarWidth <
                          leadingWidthExpanded +
                              chatActionsWidth +
                              titleReserveWidth +
                              actionsPaddingWidth;
                  final List<AppBarActionItem> visibleLeadingActions =
                      collapseAppBarActions
                          ? <AppBarActionItem>[
                              if (closeAction != null) closeAction,
                            ]
                          : leadingActions;
                  final int visibleLeadingActionCount =
                      visibleLeadingActions.length;
                  final double leadingWidth = visibleLeadingActionCount == 0
                      ? _chatAppBarCollapsedLeadingWidth
                      : _chatAppBarLeadingInset +
                          (AxiIconButton.kTapTargetSize *
                              visibleLeadingActionCount) +
                          (_chatAppBarLeadingSpacing *
                              math.max(0, visibleLeadingActionCount - 1));
                  return Scaffold(
                    backgroundColor: context.colorScheme.background,
                    appBar: AppBar(
                      scrolledUnderElevation: 0,
                      forceMaterialTransparency: true,
                      automaticallyImplyLeading: false,
                      centerTitle: false,
                      shape: Border(
                        bottom: BorderSide(color: context.colorScheme.border),
                      ),
                      actionsPadding: const EdgeInsets.symmetric(
                        horizontal: _chatAppBarActionsPadding,
                      ),
                      leadingWidth: leadingWidth,
                      leading: visibleLeadingActionCount == 0
                          ? null
                          : Padding(
                              padding: const EdgeInsets.only(
                                left: _chatAppBarLeadingInset,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: AppBarActions(
                                  actions: visibleLeadingActions,
                                  spacing: _chatAppBarLeadingSpacing,
                                  overflowBreakpoint: 0,
                                  availableWidth: leadingWidth,
                                ),
                              ),
                            ),
                      title: jid == null
                          ? const SizedBox.shrink()
                          : BlocBuilder<RosterCubit, RosterState>(
                              buildWhen: (previous, current) =>
                                  previous.items != current.items,
                              builder: (context, rosterState) {
                                final rosterItems =
                                    rosterState.items ?? const <RosterItem>[];
                                final item = rosterItems
                                    .where((entry) => entry.jid == jid)
                                    .singleOrNull;
                                final canRenameContact = !readOnly &&
                                    chatEntity != null &&
                                    chatEntity.type == ChatType.chat;
                                final statusLabel = item?.status?.trim() ?? '';
                                final addressLabel = jid.trim();
                                const addressStatusSeparator = ' · ';
                                final secondaryLabel = statusLabel.isNotEmpty
                                    ? '$addressLabel$addressStatusSeparator$statusLabel'
                                    : addressLabel;
                                final presence = item?.presence;
                                final subscription = item?.subscription;
                                final avatarTooltip = isGroupChat
                                    ? context.l10n.chatRoomMembers
                                    : null;
                                final spacing = context.spacing;
                                Widget avatar = TransportAwareAvatar(
                                  chat: chatEntity!,
                                  selfIdentity: selfIdentity,
                                  size: context.sizing.iconButtonSize,
                                  badgeOffset: Offset(-spacing.xs, -spacing.xs),
                                  presence: presence,
                                  status: statusLabel,
                                  subscription: subscription,
                                );
                                if (avatarTooltip != null) {
                                  avatar = AxiTooltip(
                                    builder: (context) => Text(avatarTooltip),
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
                                final double titleMaxWidth =
                                    appBarWidth * _chatAppBarTitleWidthScale;
                                final double clampedTitleWidth =
                                    titleMaxWidth.clamp(
                                  _chatAppBarTitleMinWidth,
                                  _chatAppBarTitleMaxWidth,
                                );
                                final baseTitleStyle = context.textTheme.h4;
                                final titleStyle = baseTitleStyle.copyWith(
                                  fontSize: context.textTheme.large.fontSize,
                                );
                                final TextStyle subtitleStyle =
                                    context.textTheme.muted;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    avatar,
                                    SizedBox(width: spacing.m),
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
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Flexible(
                                                  fit: FlexFit.loose,
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        state.chat
                                                                ?.displayName ??
                                                            '',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: titleStyle,
                                                      ),
                                                      if (secondaryLabel
                                                          .isNotEmpty)
                                                        SelectableText(
                                                          secondaryLabel,
                                                          maxLines: 1,
                                                          style: subtitleStyle,
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                if (canRenameContact)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsetsDirectional
                                                            .only(
                                                      start: 6,
                                                    ),
                                                    child: AxiTooltip(
                                                      builder: (context) =>
                                                          Text(
                                                        context.l10n
                                                            .chatContactRenameTooltip,
                                                      ),
                                                      child:
                                                          AxiIconButton.ghost(
                                                        onPressed:
                                                            _promptContactRename,
                                                        iconData: LucideIcons
                                                            .pencilLine,
                                                        iconSize: context.sizing
                                                            .menuItemIconSize,
                                                      ),
                                                    ),
                                                  ),
                                              ],
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
                          BlocSelector<ChatSearchCubit, ChatSearchState, bool>(
                            selector: (state) => state.active,
                            builder: (context, searchActive) {
                              final l10n = context.l10n;
                              final colors = context.colorScheme;
                              final bool isPinnedPanelVisible =
                                  _pinnedPanelVisible;
                              final Color pinnedIconColor = isPinnedPanelVisible
                                  ? colors.primary
                                  : colors.foreground;
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
                                  AppBarActionItem(
                                    label: showingChatCalendar
                                        ? l10n.commonClose
                                        : l10n.homeRailCalendar,
                                    iconData: LucideIcons.calendarClock,
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
                              onReportSpam: () =>
                                  _handleSpamToggle(sendToSpam: true),
                            ),
                            Expanded(
                              child: IgnorePointer(
                                ignoring: !_chatRoute.allowsChatInteraction,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final rawContentWidth = math.max(
                                      0.0,
                                      constraints.maxWidth,
                                    );
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
                                    final pinnedStanzaIds = state.pinnedMessages
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
                                    String messageKey(Message message) =>
                                        message.id ?? message.stanzaID;

                                    List<String> attachmentsForMessage(
                                      Message message,
                                    ) {
                                      final key = messageKey(message);
                                      return attachmentsByMessageId[key] ??
                                          emptyAttachments;
                                    }

                                    final filteredItems = _cachedFilteredItems;
                                    final availabilityCoordinator =
                                        _readAvailabilityShareCoordinator(
                                      context,
                                      calendarAvailable: chatCalendarAvailable,
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
                                    final isEmailChat =
                                        state.chat?.defaultTransport.isEmail ==
                                            true;
                                    final loadingMessages =
                                        !state.messagesLoaded;
                                    final selectedMessages =
                                        _collectSelectedMessages(
                                      filteredItems,
                                    );
                                    if (_multiSelectActive &&
                                        selectedMessages.isEmpty) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        if (!mounted) return;
                                        _clearMultiSelection();
                                      });
                                    }
                                    const selectionSpacerVisibleHeight =
                                        _messageListTailSpacer;
                                    final baseBubbleMaxWidth = availableWidth *
                                        (isCompact
                                            ? _compactBubbleWidthFraction
                                            : _regularBubbleWidthFraction);
                                    final inboundAvatarReservation = isGroupChat
                                        ? _messageRowAvatarReservation
                                        : 0.0;
                                    final inboundClampedBubbleWidth =
                                        baseBubbleMaxWidth.clamp(
                                      0.0,
                                      availableWidth - inboundAvatarReservation,
                                    );
                                    final outboundClampedBubbleWidth =
                                        baseBubbleMaxWidth.clamp(
                                      0.0,
                                      availableWidth,
                                    );
                                    final inboundMessageRowMaxWidth = math.min(
                                      availableWidth - inboundAvatarReservation,
                                      inboundClampedBubbleWidth +
                                          _selectionOuterInset,
                                    );
                                    final outboundMessageRowMaxWidth = math.min(
                                      availableWidth,
                                      outboundClampedBubbleWidth +
                                          _selectionOuterInset,
                                    );
                                    final messageRowMaxWidth = rawContentWidth;
                                    final selectionExtrasMaxWidth = math.min(
                                      availableWidth,
                                      _selectionExtrasMaxWidth,
                                    );
                                    final dashMessages = <ChatMessage>[];
                                    final unreadBoundaryId =
                                        state.unreadBoundaryStanzaId;
                                    var unreadDividerInserted = false;
                                    final shownSubjectShares = <String>{};
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
                                    for (var index = 0;
                                        index < filteredItems.length;
                                        index++) {
                                      final e = filteredItems[index];
                                      final senderBare =
                                          bareAddress(e.senderJid);
                                      final normalizedSenderBare =
                                          normalizedAddressKey(
                                        e.senderJid,
                                      );
                                      final isSelfXmpp = senderBare != null &&
                                          senderBare ==
                                              bareAddress(
                                                profileState()?.jid,
                                              );
                                      final isSelfEmail = senderBare != null &&
                                          resolvedEmailSelfJid != null &&
                                          senderBare ==
                                              bareAddress(
                                                resolvedEmailSelfJid,
                                              );
                                      final bool isDeltaPlaceholderSender =
                                          normalizedSenderBare != null &&
                                              normalizedSenderBare
                                                  .isDeltaPlaceholderJid;
                                      final isMucSelf = isGroupChat &&
                                          _isMucSelfMessage(
                                            senderJid: e.senderJid,
                                            occupantId: e.occupantID,
                                            myOccupantId: myOccupantId,
                                            selfNick: selfNick,
                                          );
                                      final isSelf = isSelfXmpp ||
                                          isSelfEmail ||
                                          isMucSelf ||
                                          isDeltaPlaceholderSender;
                                      final occupantId = isGroupChat
                                          ? (isSelf
                                              ? myOccupantId
                                              : e.senderJid)
                                          : null;
                                      final occupant = !isGroupChat
                                          ? null
                                          : state
                                              .roomState?.occupants[occupantId];
                                      final isEmailMessage =
                                          e.deltaMsgId != null;
                                      final fallbackNick =
                                          _nickFromSender(e.senderJid) ??
                                              state.chat?.title ??
                                              '';
                                      final authorLabel = (isSelf
                                              ? user.firstName
                                              : (occupant?.nick ??
                                                  fallbackNick)) ??
                                          '';
                                      final authorId =
                                          isSelf ? user.id : e.senderJid;
                                      final author = ChatUser(
                                        id: authorId,
                                        firstName: authorLabel,
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
                                      final isInviteRevocation = e
                                              .pseudoMessageType ==
                                          PseudoMessageType.mucInviteRevocation;
                                      final unknownRoomFallbackLabel = context
                                          .l10n.chatInviteRoomFallbackLabel;
                                      final resolvedInviteRoomName =
                                          inviteRoomName?.isNotEmpty == true
                                              ? inviteRoomName!
                                              : unknownRoomFallbackLabel;
                                      final inviteBodyLabel =
                                          context.l10n.chatInviteBodyLabel;
                                      final inviteRevokedBodyLabel =
                                          context.l10n.chatInviteRevokedLabel;
                                      final inviteLabel = isInvite
                                          ? inviteBodyLabel
                                          : inviteRevokedBodyLabel;
                                      final inviteActionLabel =
                                          context.l10n.chatInviteActionLabel(
                                        resolvedInviteRoomName,
                                      );
                                      final inviteRevoked =
                                          inviteToken != null &&
                                              revokedInviteTokens.contains(
                                                inviteToken,
                                              );
                                      if (shareContext?.subject
                                              ?.trim()
                                              .isNotEmpty ==
                                          true) {
                                        subjectLabel =
                                            shareContext!.subject!.trim();
                                        if (shownSubjectShares.add(
                                          shareContext.shareId,
                                        )) {
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
                                      final errorLabel =
                                          e.error.label(context.l10n);
                                      final xmppCapabilities =
                                          state.xmppCapabilities;
                                      final supportsMarkers = isEmailChat ||
                                          xmppCapabilities?.supportsMarkers ==
                                              true;
                                      final supportsReceipts = isEmailChat ||
                                          xmppCapabilities?.supportsReceipts ==
                                              true;
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
                                        if (e.displayed && supportsMarkers) {
                                          return MessageStatus.read;
                                        }
                                        if (e.received &&
                                            (supportsMarkers ||
                                                supportsReceipts)) {
                                          return MessageStatus.received;
                                        }
                                        if (e.acked) {
                                          return MessageStatus.sent;
                                        }
                                        return MessageStatus.pending;
                                      }

                                      final shouldReplaceInviteBody =
                                          isInvite || isInviteRevocation;
                                      final renderedText =
                                          shouldReplaceInviteBody
                                              ? inviteLabel
                                              : e.error.isNotNone
                                                  ? bodyText.isNotEmpty
                                                      ? context.l10n
                                                          .chatMessageErrorWithBody(
                                                          errorLabel,
                                                          bodyTextTrimmed,
                                                        )
                                                      : errorLabel
                                                  : displayedBody;
                                      final attachmentIds =
                                          attachmentsForMessage(e);
                                      final hasAttachment =
                                          attachmentIds.isNotEmpty;
                                      final hasRenderableSubjectHeader =
                                          showSubjectHeader &&
                                              subjectText.isNotEmpty;
                                      final shouldForceDashText =
                                          renderedText.trim().isEmpty &&
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
                                            'encrypted':
                                                e.encryptionProtocol.isNotNone,
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
                                      if (!unreadDividerInserted &&
                                          unreadBoundaryId != null &&
                                          e.stanzaID == unreadBoundaryId) {
                                        unreadDividerInserted = true;
                                        dashMessages.add(
                                          ChatMessage(
                                            user: spacerUser,
                                            createdAt: e.timestamp!.toLocal(),
                                            text: ' ',
                                            customProperties: const {
                                              'id': _unreadDividerMessageId,
                                              'unreadDivider': true,
                                            },
                                          ),
                                        );
                                      }
                                    }
                                    final emptyStateLabel = searchFiltering
                                        ? context.l10n.chatEmptySearch
                                        : context.l10n.chatEmptyMessages;
                                    if (!loadingMessages &&
                                        filteredItems.isEmpty) {
                                      dashMessages.add(
                                        ChatMessage(
                                          user: spacerUser,
                                          createdAt: _selectionSpacerTimestamp,
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
                                      onLoadEarlier: searchFiltering ||
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
                                    final composerHintText = isDefaultEmail
                                        ? context.l10n.chatComposerEmailHint
                                        : context.l10n.chatComposerMessageHint;
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
                                            quoting.stanzaID,
                                          ),
                                          message: quoting,
                                          isSelf: _isQuotedMessageFromSelf(
                                            quotedMessage: quoting,
                                            isGroupChat: isGroupChat,
                                            myOccupantId: myOccupantId,
                                            selfNick: selfNick,
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
                                                    fallbackTypingJid != null &&
                                                    fallbackTypingJid.isNotEmpty
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
                                    final bottomSection = _SizeReportingWidget(
                                      onSizeChange: _updateBottomSectionHeight,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          quoteSection,
                                          if (_multiSelectActive &&
                                              selectedMessages.isNotEmpty)
                                            () {
                                              final targets = List<Message>.of(
                                                selectedMessages,
                                                growable: false,
                                              );
                                              final canReact = !isEmailChat &&
                                                  (state.xmppCapabilities
                                                          ?.features
                                                          .contains(
                                                        mox.messageReactionsXmlns,
                                                      ) ??
                                                      false);
                                              return _MessageSelectionToolbar(
                                                count: targets.length,
                                                onClear: _clearMultiSelection,
                                                onCopy: () =>
                                                    _copySelectedMessages(
                                                  List<Message>.of(
                                                    targets,
                                                  ),
                                                ),
                                                onShare: () =>
                                                    _shareSelectedMessages(
                                                  List<Message>.of(
                                                    targets,
                                                  ),
                                                ),
                                                shareStatus:
                                                    _shareRequestStatus,
                                                onForward: () =>
                                                    _forwardSelectedMessages(
                                                  List<Message>.of(
                                                    targets,
                                                  ),
                                                ),
                                                onAddToCalendar: () =>
                                                    _addSelectedToCalendar(
                                                  List<Message>.of(
                                                    targets,
                                                  ),
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
                                                availableChats: availableChats,
                                                latestStatuses: latestStatuses,
                                                visibilityLabel:
                                                    visibilityLabel,
                                                pendingAttachments:
                                                    pendingAttachments,
                                                composerHasText:
                                                    _composerHasContent,
                                                selfJid: selfXmppJid,
                                                selfIdentity: selfIdentity,
                                                composerError:
                                                    state.composerError,
                                                onComposerErrorCleared: () =>
                                                    context
                                                        .read<ChatBloc>()
                                                        .add(
                                                          const ChatComposerErrorCleared(),
                                                        ),
                                                showAttachmentWarning:
                                                    showAttachmentWarning,
                                                retryReport: retryReport,
                                                retryShareId: retryShareId,
                                                subjectController:
                                                    _subjectController,
                                                subjectFocusNode:
                                                    _subjectFocusNode,
                                                textController: _textController,
                                                textFocusNode: _focusNode,
                                                tapRegionGroup:
                                                    _composerTapRegionGroup,
                                                onSubjectSubmitted: () =>
                                                    _focusNode.requestFocus(),
                                                onRecipientAdded:
                                                    _handleRecipientAdded,
                                                onRecipientRemoved:
                                                    _handleRecipientRemoved,
                                                onRecipientToggled:
                                                    _handleRecipientToggled,
                                                onAttachmentRetry: (id) =>
                                                    context
                                                        .read<ChatBloc>()
                                                        .add(
                                                          ChatAttachmentRetryRequested(
                                                            attachmentId: id,
                                                            recipients:
                                                                _recipients,
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
                                                buildComposerAccessories: ({
                                                  required bool canSend,
                                                }) =>
                                                    _composerAccessories(
                                                  canSend: canSend,
                                                  attachmentsEnabled:
                                                      attachmentsEnabled,
                                                ),
                                                onTaskDropped: _handleTaskDrop,
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
                                          accountJid: accountJidForPins,
                                          pinnedMessages: state.pinnedMessages,
                                          pinnedMessagesLoaded:
                                              state.pinnedMessagesLoaded,
                                          pinnedMessagesHydrating:
                                              state.pinnedMessagesHydrating,
                                          onClose: _closePinnedMessages,
                                          canTogglePins: canTogglePins,
                                          canShowCalendarTasks:
                                              chatCalendarBloc != null,
                                          personalCalendarBloc:
                                              personalCalendarBloc,
                                          chatCalendarBloc: chatCalendarBloc,
                                          roomState: state.roomState,
                                          metadataStreamFor: _metadataStreamFor,
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
                                            child: Listener(
                                              behavior:
                                                  HitTestBehavior.translucent,
                                              onPointerMove:
                                                  _handleOutsideTapMove,
                                              onPointerUp: _handleOutsideTapUp,
                                              onPointerCancel:
                                                  _handleOutsideTapCancel,
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  MediaQuery.removePadding(
                                                    context: context,
                                                    removeLeft: true,
                                                    removeRight: true,
                                                    child: _ChatMessageList(
                                                      currentUser: user,
                                                      messages: dashMessages,
                                                      typingUsers: const [],
                                                      quickReplyOptions:
                                                          const QuickReplyOptions(),
                                                      scrollToBottomOptions:
                                                          const ScrollToBottomOptions(),
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
                                                            const spacerHeight =
                                                                selectionSpacerVisibleHeight;
                                                            return const _SelectionHeadroomSpacer(
                                                              height:
                                                                  spacerHeight,
                                                            );
                                                          }
                                                          final isUnreadDivider =
                                                              message.customProperties?[
                                                                      'unreadDivider'] ==
                                                                  true;
                                                          if (isUnreadDivider) {
                                                            return _UnreadDivider(
                                                              label: l10n
                                                                  .chatUnreadDividerLabel,
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
                                                          final detailColor =
                                                              textColor;
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
                                                          final bubbleBaseRadius =
                                                              context.radius;
                                                          final bubbleCornerClearance =
                                                              _bubbleCornerClearance(
                                                            bubbleBaseRadius,
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
                                                          final messageText =
                                                              (message.customProperties?[
                                                                          'renderedText']
                                                                      as String?) ??
                                                                  message.text;
                                                          final timeColor =
                                                              detailColor;
                                                          final detailStyle =
                                                              context.textTheme
                                                                  .small
                                                                  .copyWith(
                                                            color: timeColor,
                                                            fontSize: 11.0,
                                                            height: 1.0,
                                                            textBaseline:
                                                                TextBaseline
                                                                    .alphabetic,
                                                          );
                                                          final surfaceDetailColor =
                                                              colors.foreground;
                                                          final surfaceDetailStyle =
                                                              detailStyle
                                                                  .copyWith(
                                                            color:
                                                                surfaceDetailColor,
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
                                                            Color color, {
                                                            required TextStyle
                                                                baseStyle,
                                                          }) =>
                                                                  TextSpan(
                                                                    text: String
                                                                        .fromCharCode(
                                                                      icon.codePoint,
                                                                    ),
                                                                    style: baseStyle
                                                                        .copyWith(
                                                                      color:
                                                                          color,
                                                                      fontFamily:
                                                                          icon.fontFamily,
                                                                      package: icon
                                                                          .fontPackage,
                                                                    ),
                                                                  );
                                                          final timeLabel =
                                                              '${message.createdAt.hour.toString().padLeft(2, '0')}:'
                                                              '${message.createdAt.minute.toString().padLeft(2, '0')}';
                                                          final time = TextSpan(
                                                            text: timeLabel,
                                                            style: detailStyle,
                                                          );
                                                          final surfaceTime =
                                                              TextSpan(
                                                            text: timeLabel,
                                                            style:
                                                                surfaceDetailStyle,
                                                          );
                                                          final statusIcon =
                                                              message
                                                                  .status?.icon;
                                                          final status =
                                                              statusIcon == null
                                                                  ? null
                                                                  : iconDetailSpan(
                                                                      statusIcon,
                                                                      detailColor,
                                                                      baseStyle:
                                                                          detailStyle,
                                                                    );
                                                          final surfaceStatus =
                                                              statusIcon == null
                                                                  ? null
                                                                  : iconDetailSpan(
                                                                      statusIcon,
                                                                      surfaceDetailColor,
                                                                      baseStyle:
                                                                          surfaceDetailStyle,
                                                                    );
                                                          final transportDetail =
                                                              iconDetailSpan(
                                                            transportIconData,
                                                            detailColor,
                                                            baseStyle:
                                                                detailStyle,
                                                          );
                                                          final surfaceTransportDetail =
                                                              iconDetailSpan(
                                                            transportIconData,
                                                            surfaceDetailColor,
                                                            baseStyle:
                                                                surfaceDetailStyle,
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
                                                            final fallbackBorderRadius =
                                                                _bubbleBorderRadius(
                                                              baseRadius:
                                                                  bubbleBaseRadius,
                                                              isSelf: self,
                                                              chainedPrevious:
                                                                  chainedPrev,
                                                              chainedNext:
                                                                  chainedNext,
                                                            );
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
                                                                        ShapeDecoration(
                                                                      color:
                                                                          bubbleColor,
                                                                      shape:
                                                                          SquircleBorder(
                                                                        borderRadius:
                                                                            fallbackBorderRadius,
                                                                        side: borderColor.a ==
                                                                                0
                                                                            ? BorderSide.none
                                                                            : context.borderSide.copyWith(
                                                                                color: borderColor,
                                                                              ),
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
                                                                      baseStyle:
                                                                          detailStyle,
                                                                    );
                                                          final surfaceVerification =
                                                              trusted == null
                                                                  ? null
                                                                  : iconDetailSpan(
                                                                      trusted
                                                                          .toShieldIcon,
                                                                      trusted
                                                                          ? axiGreen
                                                                          : colors
                                                                              .destructive,
                                                                      baseStyle:
                                                                          surfaceDetailStyle,
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
                                                              !isEmailChat &&
                                                                  (state.xmppCapabilities
                                                                          ?.features
                                                                          .contains(
                                                                        mox.messageReactionsXmlns,
                                                                      ) ??
                                                                      false);
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
                                                                        .stanzaID,
                                                                  );
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
                                                          final isDesktopPlatform =
                                                              EnvScope.maybeOf(
                                                                    context,
                                                                  )?.isDesktopPlatform ??
                                                                  false;
                                                          final bubbleTextChildren =
                                                              <Widget>[];
                                                          final bubbleExtraChildren =
                                                              <Widget>[];
                                                          bool hasHtmlBubble =
                                                              false;
                                                          final extraSpacing =
                                                              context
                                                                  .spacing.xs;
                                                          void addExtra(
                                                            Widget child, {
                                                            required ShapeBorder
                                                                shape,
                                                            double? spacing,
                                                          }) {
                                                            final resolvedSpacing =
                                                                spacing ??
                                                                    extraSpacing;
                                                            final Widget
                                                                extraChild =
                                                                _MessageExtraItem(
                                                              shape: shape,
                                                              onLongPress: widget
                                                                          .readOnly ||
                                                                      isDesktopPlatform
                                                                  ? null
                                                                  : () {
                                                                      _toggleMessageSelection(
                                                                        messageModel,
                                                                      );
                                                                    },
                                                              onSecondaryTapUp:
                                                                  isDesktopPlatform &&
                                                                          !widget
                                                                              .readOnly
                                                                      ? (_) {
                                                                          _toggleMessageSelection(
                                                                            messageModel,
                                                                          );
                                                                        }
                                                                      : null,
                                                              child: child,
                                                            );
                                                            if (bubbleExtraChildren
                                                                .isNotEmpty) {
                                                              bubbleExtraChildren
                                                                ..add(
                                                                  _MessageExtraGap(
                                                                    height:
                                                                        resolvedSpacing,
                                                                  ),
                                                                )
                                                                ..add(
                                                                  extraChild,
                                                                );
                                                              return;
                                                            }
                                                            if (bubbleTextChildren
                                                                    .isNotEmpty &&
                                                                resolvedSpacing >
                                                                    0) {
                                                              bubbleExtraChildren
                                                                  .add(
                                                                _MessageExtraGap(
                                                                  height:
                                                                      resolvedSpacing,
                                                                ),
                                                              );
                                                            }
                                                            bubbleExtraChildren
                                                                .add(
                                                              extraChild,
                                                            );
                                                          }

                                                          if (isError) {
                                                            bubbleTextChildren
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
                                                              _ParsedMessageBody(
                                                                contentKey:
                                                                    bubbleContentKey,
                                                                text:
                                                                    messageText,
                                                                baseStyle:
                                                                    baseTextStyle,
                                                                linkStyle:
                                                                    linkStyle,
                                                                details: [
                                                                  time,
                                                                ],
                                                                onLinkTap:
                                                                    _handleLinkTap,
                                                                onLinkLongPress:
                                                                    _handleLinkTap,
                                                              ),
                                                            ]);
                                                          } else if (isInviteMessage ||
                                                              isInviteRevocationMessage) {
                                                            final String
                                                                inviteActionFallbackLabel =
                                                                context.l10n
                                                                    .chatInviteActionFallbackLabel;
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
                                                            bubbleTextChildren
                                                                .add(
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
                                                            addExtra(
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
                                                                  roomState: state
                                                                      .roomState,
                                                                  selfJid:
                                                                      selfXmppJid,
                                                                ),
                                                              ),
                                                              shape:
                                                                  ContinuousRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .all(
                                                                  Radius
                                                                      .circular(
                                                                    context.spacing
                                                                            .m +
                                                                        context
                                                                            .spacing
                                                                            .xs,
                                                                  ),
                                                                ),
                                                              ),
                                                              spacing: context
                                                                  .spacing.s,
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
                                                                  context
                                                                      .textTheme;
                                                              final baseSubjectStyle =
                                                                  textTheme
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
                                                              bubbleTextChildren
                                                                  .add(
                                                                Text(
                                                                  subjectText,
                                                                  style:
                                                                      subjectStyle,
                                                                ),
                                                              );
                                                              bubbleTextChildren
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
                                                                    ?.toShareText(
                                                                      context
                                                                          .l10n,
                                                                    )
                                                                    .trim();
                                                            final String?
                                                                fragmentFallbackText =
                                                                displayFragment ==
                                                                        null
                                                                    ? null
                                                                    : CalendarFragmentFormatter(
                                                                        context
                                                                            .l10n,
                                                                      )
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
                                                                taskShareText !=
                                                                        null &&
                                                                    taskShareText ==
                                                                        trimmedRenderedText;
                                                            final List<
                                                                    InlineSpan>
                                                                surfaceDetails =
                                                                <InlineSpan>[
                                                              surfaceTime,
                                                              surfaceTransportDetail,
                                                              if (self &&
                                                                  surfaceStatus !=
                                                                      null)
                                                                surfaceStatus,
                                                              if (surfaceVerification !=
                                                                  null)
                                                                surfaceVerification,
                                                            ];
                                                            final List<
                                                                    InlineSpan>
                                                                shareMetadataDetails =
                                                                hideTaskText &&
                                                                        calendarTaskIcs !=
                                                                            null
                                                                    ? _calendarTaskShareMetadata(
                                                                        calendarTaskIcs,
                                                                        context
                                                                            .l10n,
                                                                        surfaceDetailStyle,
                                                                      )
                                                                    : _emptyInlineSpans;
                                                            final List<
                                                                    InlineSpan>
                                                                fragmentFooterDetails =
                                                                hideFragmentText
                                                                    ? surfaceDetails
                                                                    : _emptyInlineSpans;
                                                            final List<
                                                                    InlineSpan>
                                                                availabilityFooterDetails =
                                                                hideAvailabilityText
                                                                    ? surfaceDetails
                                                                    : _emptyInlineSpans;
                                                            final List<
                                                                    InlineSpan>
                                                                taskFooterDetails =
                                                                hideTaskText
                                                                    ? <InlineSpan>[
                                                                        ...surfaceDetails,
                                                                        ...shareMetadataDetails,
                                                                      ]
                                                                    : _emptyInlineSpans;
                                                            CalendarAvailabilityShare?
                                                                availabilityShare;
                                                            String?
                                                                availabilityShareRequesterJid;
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
                                                                  final String?
                                                                      requesterJid =
                                                                      isOwner
                                                                          ? null
                                                                          : availabilityActorId;
                                                                  availabilityShare =
                                                                      value
                                                                          .share;
                                                                  availabilityShareRequesterJid =
                                                                      requesterJid;
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
                                                              addExtra(
                                                                Builder(
                                                                  builder:
                                                                      (context) {
                                                                    final CalendarAvailabilityShare?
                                                                        resolvedShare =
                                                                        availabilityShare;
                                                                    final String?
                                                                        resolvedRequesterJid =
                                                                        availabilityShareRequesterJid;
                                                                    final String?
                                                                        resolvedOwnerLabel =
                                                                        _resolveAvailabilityOwnerLabel(
                                                                      ownerJid: resolvedShare
                                                                          ?.overlay
                                                                          .owner,
                                                                      normalizedXmppSelfJid:
                                                                          normalizedXmppSelfJid,
                                                                      normalizedEmailSelfJid:
                                                                          normalizedEmailSelfJid,
                                                                      selfLabel: context
                                                                          .l10n
                                                                          .chatSenderYou,
                                                                    );
                                                                    final String?
                                                                        resolvedChatLabel =
                                                                        chatEntity
                                                                            ?.displayName;
                                                                    final VoidCallback?
                                                                        resolvedOnOpen =
                                                                        resolvedShare ==
                                                                                null
                                                                            ? null
                                                                            : () =>
                                                                                _openAvailabilityShareViewer(
                                                                                  share: resolvedShare,
                                                                                  requesterJid: resolvedRequesterJid,
                                                                                  chatCalendarAvailable: chatCalendarAvailable,
                                                                                  locate: context.read,
                                                                                  ownerLabel: resolvedOwnerLabel,
                                                                                  chatLabel: resolvedChatLabel,
                                                                                );
                                                                    return CalendarAvailabilityMessageCard(
                                                                      message:
                                                                          availabilityMessage,
                                                                      footerDetails:
                                                                          availabilityFooterDetails,
                                                                      onOpen:
                                                                          resolvedOnOpen,
                                                                      onAccept:
                                                                          availabilityOnAccept,
                                                                      onDecline:
                                                                          availabilityOnDecline,
                                                                    );
                                                                  },
                                                                ),
                                                                shape:
                                                                    _calendarMessageCardShadowShape,
                                                              );
                                                            } else if (calendarTaskIcs !=
                                                                null) {
                                                              final ShapeBorder
                                                                  calendarTaskShape =
                                                                  chatCalendarBloc ==
                                                                          null
                                                                      ? _calendarMessageCardShadowShape
                                                                      : _calendarTaskShadowShape;
                                                              addExtra(
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
                                                                            (calendarTaskIcsReadOnly && !self) ||
                                                                                demoEmailCalendarEnabled,
                                                                        requireImportConfirmation:
                                                                            !self,
                                                                        allowChatCopy:
                                                                            !demoEmailCalendarEnabled,
                                                                        demoQuickAdd:
                                                                            demoEmailCalendarEnabled &&
                                                                                !self,
                                                                        footerDetails:
                                                                            taskFooterDetails,
                                                                        isShareFragment:
                                                                            true,
                                                                      ),
                                                                shape:
                                                                    calendarTaskShape,
                                                              );
                                                            } else if (displayFragment !=
                                                                null) {
                                                              final Widget
                                                                  fragmentCard =
                                                                  displayFragment
                                                                      .maybeMap(
                                                                criticalPath: (
                                                                  value,
                                                                ) =>
                                                                    ChatCalendarCriticalPathCard(
                                                                  path: value
                                                                      .path,
                                                                  tasks: value
                                                                      .tasks,
                                                                  footerDetails:
                                                                      fragmentFooterDetails,
                                                                  personalBloc:
                                                                      personalCalendarBloc,
                                                                  chatBloc:
                                                                      chatCalendarBloc,
                                                                ),
                                                                orElse: () =>
                                                                    CalendarFragmentCard(
                                                                  fragment:
                                                                      displayFragment,
                                                                  footerDetails:
                                                                      fragmentFooterDetails,
                                                                ),
                                                              );
                                                              addExtra(
                                                                fragmentCard,
                                                                shape:
                                                                    _calendarMessageCardShadowShape,
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
                                                              bubbleTextChildren
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
                                                                  builder: (
                                                                    context,
                                                                    snapshot,
                                                                  ) {
                                                                    final l10n =
                                                                        context
                                                                            .l10n;
                                                                    final metadata =
                                                                        snapshot
                                                                            .data;
                                                                    final filename =
                                                                        metadata?.filename.trim() ??
                                                                            '';
                                                                    final resolvedFilename = filename
                                                                            .isNotEmpty
                                                                        ? filename
                                                                        : l10n
                                                                            .chatAttachmentFallbackLabel;
                                                                    final sizeBytes =
                                                                        metadata
                                                                            ?.sizeBytes;
                                                                    final sizeLabel = sizeBytes !=
                                                                                null &&
                                                                            sizeBytes >
                                                                                0
                                                                        ? formatBytes(
                                                                            sizeBytes,
                                                                            l10n,
                                                                          )
                                                                        : l10n
                                                                            .chatAttachmentUnknownSize;
                                                                    final caption =
                                                                        l10n.chatAttachmentCaption(
                                                                      resolvedFilename,
                                                                      sizeLabel,
                                                                    );
                                                                    return DynamicInlineText(
                                                                      key:
                                                                          ValueKey(
                                                                        bubbleContentKey,
                                                                      ),
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
                                                              hasHtmlBubble =
                                                                  true;
                                                              final shouldLoadImages = context
                                                                      .watch<
                                                                          SettingsCubit>()
                                                                      .state
                                                                      .autoLoadEmailImages ||
                                                                  (messageModel
                                                                              .id !=
                                                                          null &&
                                                                      _loadedEmailImageMessageIds
                                                                          .contains(
                                                                        messageModel
                                                                            .id,
                                                                      ));
                                                              bubbleTextChildren
                                                                  .add(
                                                                _MessageHtmlBody(
                                                                  key: ValueKey(
                                                                    bubbleContentKey,
                                                                  ),
                                                                  html:
                                                                      normalizedHtmlBody,
                                                                  textStyle:
                                                                      baseTextStyle,
                                                                  textColor:
                                                                      textColor,
                                                                  linkColor: self
                                                                      ? colors
                                                                          .primaryForeground
                                                                      : colors
                                                                          .primary,
                                                                  shouldLoadImages:
                                                                      shouldLoadImages,
                                                                  onLoadRequested:
                                                                      messageModel.id ==
                                                                              null
                                                                          ? null
                                                                          : () =>
                                                                              _handleEmailImagesApproved(
                                                                                messageModel.id!,
                                                                              ),
                                                                  onLinkTap:
                                                                      _handleLinkTap,
                                                                  onTap: () =>
                                                                      _showHtmlPreview(
                                                                    html:
                                                                        normalizedHtmlBody,
                                                                    shouldLoadImages:
                                                                        shouldLoadImages,
                                                                    onLoadRequested: messageModel.id ==
                                                                            null
                                                                        ? null
                                                                        : () =>
                                                                            _handleEmailImagesApproved(
                                                                              messageModel.id!,
                                                                            ),
                                                                  ),
                                                                ),
                                                              );
                                                              // Add details row below HTML content
                                                              bubbleTextChildren
                                                                  .add(
                                                                Padding(
                                                                  padding:
                                                                      EdgeInsets
                                                                          .only(
                                                                    top: context
                                                                        .spacing
                                                                        .xs,
                                                                  ),
                                                                  child:
                                                                      Text.rich(
                                                                    TextSpan(
                                                                      children: [
                                                                        time,
                                                                        const TextSpan(
                                                                          text:
                                                                              ' ',
                                                                        ),
                                                                        transportDetail,
                                                                        if (self &&
                                                                            status !=
                                                                                null) ...[
                                                                          const TextSpan(
                                                                            text:
                                                                                ' ',
                                                                          ),
                                                                          status,
                                                                        ],
                                                                        if (verification !=
                                                                            null) ...[
                                                                          const TextSpan(
                                                                            text:
                                                                                ' ',
                                                                          ),
                                                                          verification,
                                                                        ],
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              );
                                                            } else if (shouldRenderTextContent) {
                                                              bubbleTextChildren
                                                                  .add(
                                                                _ParsedMessageBody(
                                                                  contentKey:
                                                                      bubbleContentKey,
                                                                  text:
                                                                      messageText,
                                                                  baseStyle:
                                                                      baseTextStyle,
                                                                  linkStyle:
                                                                      linkStyle,
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
                                                                ),
                                                              );
                                                            }
                                                            if (message.customProperties?[
                                                                    'retracted'] ??
                                                                false) {
                                                              bubbleTextChildren
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
                                                              bubbleTextChildren
                                                                  .add(
                                                                Text(
                                                                  l10n.chatMessageEdited,
                                                                  style:
                                                                      extraStyle,
                                                                ),
                                                              );
                                                            }
                                                          }
                                                          final bool
                                                              hasBubbleText =
                                                              bubbleTextChildren
                                                                  .isNotEmpty;
                                                          if (attachmentIds
                                                              .isNotEmpty) {
                                                            final bool
                                                                hasBubbleAnchor =
                                                                hasBubbleText ||
                                                                    showCompactReactions ||
                                                                    showReplyStrip ||
                                                                    showRecipientCutout;
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
                                                            final emailDownloadDelegate =
                                                                isEmailChat
                                                                    ? AttachmentDownloadDelegate(
                                                                        () async {
                                                                          await context
                                                                              .read<ChatBloc>()
                                                                              .downloadFullEmailMessage(
                                                                                messageModel,
                                                                              );
                                                                          return true;
                                                                        },
                                                                      )
                                                                    : null;
                                                            for (var index = 0;
                                                                index <
                                                                    attachmentIds
                                                                        .length;
                                                                index += 1) {
                                                              final attachmentId =
                                                                  attachmentIds[
                                                                      index];
                                                              final downloadDelegate =
                                                                  isEmailChat
                                                                      ? emailDownloadDelegate
                                                                      : AttachmentDownloadDelegate(
                                                                          () => context
                                                                              .read<ChatBloc>()
                                                                              .downloadInboundAttachment(
                                                                                metadataId: attachmentId,
                                                                                stanzaId: messageModel.stanzaID,
                                                                              ),
                                                                        );
                                                              final metadataReloadDelegate =
                                                                  AttachmentMetadataReloadDelegate(
                                                                () => context
                                                                    .read<
                                                                        ChatBloc>()
                                                                    .reloadFileMetadata(
                                                                      attachmentId,
                                                                    ),
                                                              );
                                                              final bool
                                                                  hasAttachmentAbove =
                                                                  index > 0 ||
                                                                      hasBubbleAnchor;
                                                              final bool
                                                                  hasAttachmentBelow =
                                                                  index <
                                                                      attachmentIds
                                                                              .length -
                                                                          1;
                                                              final OutlinedBorder
                                                                  attachmentShape =
                                                                  _attachmentSurfaceShape(
                                                                context: context,
                                                                isSelf: self,
                                                                chainedPrevious:
                                                                    hasAttachmentAbove,
                                                                chainedNext:
                                                                    hasAttachmentBelow,
                                                              );
                                                              addExtra(
                                                                ChatAttachmentPreview(
                                                                  stanzaId:
                                                                      messageModel
                                                                          .stanzaID,
                                                                  metadataStream:
                                                                      _metadataStreamFor(
                                                                    attachmentId,
                                                                  ),
                                                                  initialMetadata:
                                                                      _metadataInitialFor(
                                                                    attachmentId,
                                                                  ),
                                                                  allowed:
                                                                      allowAttachment,
                                                                  downloadDelegate:
                                                                      downloadDelegate,
                                                                  metadataReloadDelegate:
                                                                      metadataReloadDelegate,
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
                                                                  surfaceShape:
                                                                      attachmentShape,
                                                                ),
                                                                shape:
                                                                    attachmentShape,
                                                                spacing: context
                                                                    .spacing.s,
                                                              );
                                                            }
                                                          }
                                                          var bubbleBottomInset =
                                                              0.0;
                                                          if (showCompactReactions) {
                                                            bubbleBottomInset =
                                                                reactionBubbleInset;
                                                          }
                                                          if (showReplyStrip) {
                                                            bubbleBottomInset =
                                                                math.max(
                                                              bubbleBottomInset,
                                                              recipientBubbleInset,
                                                            );
                                                          }
                                                          if (showRecipientCutout) {
                                                            bubbleBottomInset =
                                                                math.max(
                                                              bubbleBottomInset,
                                                              recipientBubbleInset,
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
                                                          final spacing =
                                                              context.spacing;
                                                          final messageAvatarSize =
                                                              spacing.l +
                                                                  spacing.xs;
                                                          final avatarCutoutDepth =
                                                              messageAvatarSize /
                                                                  2;
                                                          final avatarCutoutRadius =
                                                              avatarCutoutDepth +
                                                                  spacing.xs;
                                                          final avatarOuterInset =
                                                              avatarCutoutDepth;
                                                          final avatarContentInset =
                                                              avatarCutoutDepth -
                                                                  spacing.xs;
                                                          final avatarMinThickness =
                                                              messageAvatarSize;
                                                          final avatarCutoutAlignment =
                                                              Alignment
                                                                  .centerLeft
                                                                  .x;
                                                          final messageAvatarCornerClearance =
                                                              spacing.xxs * 0;
                                                          final messageAvatarCutoutPadding =
                                                              EdgeInsets.zero;
                                                          final reactionBubbleInset =
                                                              spacing.s +
                                                                  spacing.xs;
                                                          final reactionCutoutDepth =
                                                              spacing.s +
                                                                  spacing.xs +
                                                                  spacing.xxs;
                                                          final reactionCutoutRadius =
                                                              spacing.m;
                                                          final reactionCutoutMinThickness =
                                                              spacing.m +
                                                                  spacing.s +
                                                                  spacing.xs;
                                                          final reactionStripOffset =
                                                              Offset(
                                                            0,
                                                            -spacing.xxs,
                                                          );
                                                          final reactionCutoutPadding =
                                                              EdgeInsets
                                                                  .symmetric(
                                                            horizontal:
                                                                spacing.m,
                                                            vertical:
                                                                spacing.xxs,
                                                          );
                                                          final reactionCornerClearance =
                                                              spacing.s +
                                                                  spacing.xs;
                                                          final recipientCutoutDepth =
                                                              spacing.m;
                                                          final recipientCutoutRadius =
                                                              spacing.m +
                                                                  spacing.xxs;
                                                          final recipientCutoutPadding =
                                                              EdgeInsets
                                                                  .fromLTRB(
                                                            spacing.s +
                                                                spacing.xxs,
                                                            spacing.xs,
                                                            spacing.s +
                                                                spacing.xxs,
                                                            spacing.xs +
                                                                spacing.xxs,
                                                          );
                                                          final recipientCutoutMinThickness =
                                                              spacing.l +
                                                                  spacing.m;
                                                          final recipientBubbleInset =
                                                              recipientCutoutDepth;
                                                          final selectionCutoutDepth =
                                                              spacing.m +
                                                                  (spacing.xxs /
                                                                      2);
                                                          final selectionCutoutRadius =
                                                              spacing.m;
                                                          final selectionCutoutPadding =
                                                              EdgeInsets
                                                                  .fromLTRB(
                                                            spacing.xs,
                                                            spacing.xs +
                                                                (spacing.xxs /
                                                                    4),
                                                            spacing.xs,
                                                            spacing.xs +
                                                                (spacing.xxs /
                                                                    4),
                                                          );
                                                          final selectionCutoutOffset =
                                                              Offset(
                                                            -(spacing.xxs +
                                                                (spacing.xxs /
                                                                    2)),
                                                            0,
                                                          );
                                                          final selectionCutoutThickness =
                                                              SelectionIndicator
                                                                      .size +
                                                                  spacing.s +
                                                                  (spacing.xxs /
                                                                      2);
                                                          final selectionBubbleInteriorInset =
                                                              selectionCutoutDepth +
                                                                  spacing.xs +
                                                                  spacing.xxs;
                                                          final selectionBubbleVerticalInset =
                                                              spacing.xs;
                                                          final selectionOuterInset =
                                                              selectionCutoutDepth +
                                                                  (SelectionIndicator
                                                                          .size /
                                                                      2);
                                                          final selectionIndicatorInset =
                                                              spacing.xxs;
                                                          final selectionBubbleInboundExtraGap =
                                                              spacing.xs;
                                                          final selectionBubbleOutboundExtraGap =
                                                              spacing.s;
                                                          final selectionBubbleOutboundSpacingBoost =
                                                              spacing.xs +
                                                                  spacing.xxs;
                                                          final selectionBubbleInboundSpacing =
                                                              selectionBubbleInteriorInset +
                                                                  selectionBubbleInboundExtraGap;
                                                          final selectionBubbleOutboundSpacing =
                                                              selectionBubbleInteriorInset +
                                                                  selectionBubbleOutboundExtraGap +
                                                                  selectionBubbleOutboundSpacingBoost;
                                                          EdgeInsetsGeometry
                                                              bubblePadding =
                                                              _bubblePadding(
                                                            context,
                                                          );
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
                                                                    ? selectionBubbleOutboundSpacing
                                                                    : 0,
                                                                right: self
                                                                    ? 0
                                                                    : selectionBubbleInboundSpacing,
                                                              ),
                                                            );
                                                            bubblePadding =
                                                                bubblePadding
                                                                    .add(
                                                              EdgeInsets
                                                                  .symmetric(
                                                                vertical:
                                                                    selectionBubbleVerticalInset,
                                                              ),
                                                            );
                                                          }
                                                          if (hasAvatarSlot) {
                                                            bubblePadding =
                                                                bubblePadding
                                                                    .add(
                                                              EdgeInsets.only(
                                                                left:
                                                                    avatarContentInset +
                                                                        spacing
                                                                            .xxs,
                                                              ),
                                                            );
                                                          }
                                                          final bool
                                                              hasAttachmentExtras =
                                                              attachmentIds
                                                                  .isNotEmpty;
                                                          final bubbleBorderRadius =
                                                              _bubbleBorderRadius(
                                                            baseRadius:
                                                                bubbleBaseRadius,
                                                            isSelf: self,
                                                            chainedPrevious:
                                                                chainedPrev,
                                                            chainedNext:
                                                                chainedNext,
                                                            isSelected:
                                                                isSelected,
                                                            flattenBottom:
                                                                hasAttachmentExtras,
                                                          );
                                                          final selectionAllowance =
                                                              selectionOverlay !=
                                                                      null
                                                                  ? selectionOuterInset
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
                                                          final bool
                                                              hasBubbleCutout =
                                                              showCompactReactions ||
                                                                  showReplyStrip ||
                                                                  showRecipientCutout;
                                                          final double
                                                              bubbleAnchorHeight =
                                                              hasBubbleText ||
                                                                      !hasBubbleCutout
                                                                  ? 0.0
                                                                  : math.max(
                                                                      showCompactReactions
                                                                          ? reactionCutoutDepth
                                                                          : 0.0,
                                                                      (showReplyStrip ||
                                                                              showRecipientCutout)
                                                                          ? recipientCutoutDepth
                                                                          : 0.0,
                                                                    );
                                                          final bool
                                                              showBubbleSurface =
                                                              hasBubbleText &&
                                                                  !hasHtmlBubble;
                                                          final Color
                                                              bubbleSurfaceColor =
                                                              showBubbleSurface
                                                                  ? bubbleColor
                                                                  : Colors
                                                                      .transparent;
                                                          final Color
                                                              bubbleSurfaceBorder =
                                                              showBubbleSurface
                                                                  ? borderColor
                                                                  : Colors
                                                                      .transparent;
                                                          final bubbleContent =
                                                              hasBubbleText
                                                                  ? Padding(
                                                                      padding:
                                                                          bubblePadding,
                                                                      child:
                                                                          Column(
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        spacing: context
                                                                            .spacing
                                                                            .xs,
                                                                        children:
                                                                            bubbleTextChildren,
                                                                      ),
                                                                    )
                                                                  : bubbleAnchorHeight >
                                                                          0
                                                                      ? SizedBox(
                                                                          width:
                                                                              bubbleConstraints.maxWidth,
                                                                          height:
                                                                              bubbleAnchorHeight,
                                                                        )
                                                                      : const SizedBox
                                                                          .shrink();
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
                                                                  messageAvatarSize,
                                                              avatarPath:
                                                                  messageAvatarPath,
                                                            );
                                                            avatarStyle =
                                                                CutoutStyle(
                                                              depth:
                                                                  avatarCutoutDepth,
                                                              cornerRadius:
                                                                  avatarCutoutRadius,
                                                              shapeCornerRadius:
                                                                  context.radii
                                                                      .squircle,
                                                              padding:
                                                                  messageAvatarCutoutPadding,
                                                              offset:
                                                                  Offset.zero,
                                                              minThickness:
                                                                  avatarMinThickness,
                                                              cornerClearance:
                                                                  messageAvatarCornerClearance,
                                                              alignment:
                                                                  avatarCutoutAlignment,
                                                            );
                                                            avatarAnchor =
                                                                ChatBubbleCutoutAnchor
                                                                    .left;
                                                          }
                                                          extraOuterLeft =
                                                              requiresAvatarHeadroom
                                                                  ? avatarOuterInset
                                                                  : 0;
                                                          final messageListHorizontalPadding =
                                                              spacing.s +
                                                                  spacing.xs;
                                                          final outerPadding =
                                                              EdgeInsets.only(
                                                            top: spacing.xxs,
                                                            bottom: baseOuterBottom +
                                                                extraOuterBottom,
                                                            left: messageListHorizontalPadding +
                                                                extraOuterLeft,
                                                            right: messageListHorizontalPadding +
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
                                                                    bubbleSurfaceColor,
                                                                borderColor:
                                                                    bubbleSurfaceBorder,
                                                                borderRadius:
                                                                    bubbleBorderRadius,
                                                                shadowOpacity:
                                                                    showBubbleSurface
                                                                        ? shadowValue
                                                                        : 0.0,
                                                                shadows:
                                                                    _selectedBubbleShadows(
                                                                  bubbleHighlightColor,
                                                                ),
                                                                bubbleWidthFraction:
                                                                    1.0,
                                                                cornerClearance:
                                                                    bubbleCornerClearance +
                                                                        reactionCornerClearance,
                                                                body: child!,
                                                                reactionOverlay: showReplyStrip
                                                                    ? _ReplyStrip(
                                                                        participants:
                                                                            replyParticipants,
                                                                        onRecipientTap:
                                                                            (
                                                                          chat,
                                                                        ) {
                                                                          context
                                                                              .read<ChatsCubit>()
                                                                              .pushChat(
                                                                                jid: chat.jid,
                                                                              );
                                                                        },
                                                                      )
                                                                    : showCompactReactions
                                                                        ? _ReactionStrip(
                                                                            reactions:
                                                                                reactions,
                                                                            onReactionTap: canReact
                                                                                ? (
                                                                                    emoji,
                                                                                  ) =>
                                                                                    _toggleQuickReaction(
                                                                                      messageModel,
                                                                                      emoji,
                                                                                    )
                                                                                : null,
                                                                          )
                                                                        : null,
                                                                reactionStyle: showReplyStrip
                                                                    ? CutoutStyle(
                                                                        depth:
                                                                            recipientCutoutDepth,
                                                                        cornerRadius:
                                                                            recipientCutoutRadius,
                                                                        padding:
                                                                            recipientCutoutPadding,
                                                                        offset:
                                                                            Offset.zero,
                                                                        minThickness:
                                                                            recipientCutoutMinThickness,
                                                                      )
                                                                    : showCompactReactions
                                                                        ? CutoutStyle(
                                                                            depth:
                                                                                reactionCutoutDepth,
                                                                            cornerRadius:
                                                                                reactionCutoutRadius,
                                                                            padding:
                                                                                reactionCutoutPadding,
                                                                            offset:
                                                                                reactionStripOffset,
                                                                            minThickness:
                                                                                reactionCutoutMinThickness,
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
                                                              return bubbleSurface;
                                                            },
                                                          );
                                                          final shadowedBubble =
                                                              ConstrainedBox(
                                                            constraints:
                                                                bubbleConstraints,
                                                            child: bubble,
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
                                                                message,
                                                              );
                                                          VoidCallback?
                                                              onSelect;
                                                          if (includeSelectAction) {
                                                            onSelect = () {
                                                              _startMultiSelect(
                                                                messageModel,
                                                              );
                                                            };
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
                                                            onEdit = () async {
                                                              await _handleEditMessage(
                                                                messageModel,
                                                              );
                                                            };
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

                                                          final Widget
                                                              actionBar =
                                                              _MessageActionBar(
                                                            onReply: onReply,
                                                            onForward:
                                                                onForward,
                                                            onCopy: onCopy,
                                                            onShare: onShare,
                                                            shareStatus:
                                                                _shareRequestStatus,
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
                                                            onRevokeInvite:
                                                                onRevokeInvite,
                                                          );
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
                                                                      ? context
                                                                          .spacing
                                                                          .m
                                                                      : 0);
                                                          final reactionBottomInset =
                                                              showCompactReactions
                                                                  ? _reactionCutoutDepth
                                                                  : 0.0;
                                                          final recipientBottomInset =
                                                              (showReplyStrip ||
                                                                      showRecipientCutout)
                                                                  ? _recipientCutoutDepth
                                                                  : 0.0;
                                                          final bubbleBottomCutoutPadding =
                                                              math.max(
                                                            reactionBottomInset,
                                                            recipientBottomInset,
                                                          );
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
                                                                  ? _ReactionManager(
                                                                      reactions:
                                                                          reactions,
                                                                      onToggle: (
                                                                        emoji,
                                                                      ) =>
                                                                          _toggleQuickReaction(
                                                                        messageModel,
                                                                        emoji,
                                                                      ),
                                                                      onAddCustom:
                                                                          () =>
                                                                              _handleReactionSelection(
                                                                        messageModel,
                                                                      ),
                                                                    )
                                                                  : null;
                                                          final selectionExtrasChild =
                                                              Align(
                                                            alignment: self
                                                                ? Alignment
                                                                    .centerRight
                                                                : Alignment
                                                                    .centerLeft,
                                                            child: SizedBox(
                                                              width:
                                                                  selectionExtrasMaxWidth,
                                                              child: Padding(
                                                                padding:
                                                                    attachmentPadding
                                                                        .copyWith(
                                                                  top: attachmentTopPadding +
                                                                      bubbleBottomCutoutPadding,
                                                                ),
                                                                child: Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    actionBar,
                                                                    if (reactionManager !=
                                                                        null)
                                                                      const SizedBox(
                                                                        height:
                                                                            20,
                                                                      ),
                                                                    if (reactionManager !=
                                                                        null)
                                                                      reactionManager,
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                          final selectionExtras =
                                                              IgnorePointer(
                                                            ignoring:
                                                                !isSingleSelection,
                                                            child:
                                                                TweenAnimationBuilder<
                                                                    double>(
                                                              tween:
                                                                  Tween<double>(
                                                                begin: 0,
                                                                end:
                                                                    isSingleSelection
                                                                        ? 1.0
                                                                        : 0.0,
                                                              ),
                                                              duration:
                                                                  _bubbleFocusDuration,
                                                              curve:
                                                                  _bubbleFocusCurve,
                                                              builder: (
                                                                context,
                                                                value,
                                                                child,
                                                              ) {
                                                                return ClipRect(
                                                                  child: Align(
                                                                    alignment:
                                                                        Alignment
                                                                            .topCenter,
                                                                    heightFactor:
                                                                        value,
                                                                    child:
                                                                        Opacity(
                                                                      opacity:
                                                                          value,
                                                                      child:
                                                                          child,
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                              child:
                                                                  selectionExtrasChild,
                                                            ),
                                                          );
                                                          final attachments =
                                                              AxiAnimatedSize(
                                                            duration:
                                                                _bubbleFocusDuration,
                                                            reverseDuration:
                                                                _bubbleFocusDuration,
                                                            curve:
                                                                _bubbleFocusCurve,
                                                            alignment: Alignment
                                                                .topCenter,
                                                            clipBehavior:
                                                                Clip.none,
                                                            child:
                                                                selectionExtras,
                                                          );
                                                          final messageRowAlignment =
                                                              self
                                                                  ? Alignment
                                                                      .centerRight
                                                                  : Alignment
                                                                      .centerLeft;
                                                          final messageColumnAlignment = self
                                                              ? CrossAxisAlignment
                                                                  .end
                                                              : CrossAxisAlignment
                                                                  .start;
                                                          final Widget?
                                                              replyPreview =
                                                              quotedModel ==
                                                                      null
                                                                  ? null
                                                                  : () {
                                                                      final quotedIsSelf =
                                                                          _isQuotedMessageFromSelf(
                                                                        quotedMessage:
                                                                            quotedModel,
                                                                        isGroupChat:
                                                                            isGroupChat,
                                                                        myOccupantId:
                                                                            myOccupantId,
                                                                        selfNick:
                                                                            selfNick,
                                                                        currentUserId:
                                                                            currentUserId,
                                                                      );
                                                                      final quotedSenderLabel = quotedIsSelf
                                                                          ? l10n.chatSenderYou
                                                                          : () {
                                                                              if (!isGroupChat) {
                                                                                return quotedModel.senderJid;
                                                                              }
                                                                              final occupantId = quotedModel.occupantID?.trim() ?? '';
                                                                              final occupant = occupantId.isNotEmpty ? state.roomState?.occupants[occupantId] : state.roomState?.occupants[quotedModel.senderJid];
                                                                              final nick = occupant?.nick.trim() ?? _nickFromSender(quotedModel.senderJid);
                                                                              final resolved = nick?.trim() ?? '';
                                                                              return resolved.isNotEmpty ? resolved : quotedModel.senderJid;
                                                                            }();
                                                                      return _QuotedMessagePreview(
                                                                        message:
                                                                            quotedModel,
                                                                        senderLabel:
                                                                            quotedSenderLabel,
                                                                        isSelf:
                                                                            self,
                                                                      );
                                                                    }();
                                                          final attachmentsAligned =
                                                              attachments;
                                                          final extraShadows =
                                                              _selectedBubbleShadows(
                                                            bubbleHighlightColor,
                                                          );
                                                          final Widget
                                                              extrasAligned =
                                                              bubbleExtraChildren
                                                                      .isEmpty
                                                                  ? const SizedBox
                                                                      .shrink()
                                                                  : TweenAnimationBuilder<
                                                                      double>(
                                                                      tween: Tween<
                                                                          double>(
                                                                        begin:
                                                                            0,
                                                                        end: isSelected
                                                                            ? 1.0
                                                                            : 0.0,
                                                                      ),
                                                                      duration:
                                                                          _bubbleFocusDuration,
                                                                      curve:
                                                                          _bubbleFocusCurve,
                                                                      builder: (
                                                                        context,
                                                                        shadowValue,
                                                                        child,
                                                                      ) {
                                                                        final extras = bubbleBottomCutoutPadding >
                                                                                0
                                                                            ? <Widget>[
                                                                                _MessageExtraGap(
                                                                                  height: bubbleBottomCutoutPadding,
                                                                                ),
                                                                                ...bubbleExtraChildren,
                                                                              ]
                                                                            : bubbleExtraChildren;
                                                                        return ConstrainedBox(
                                                                          constraints:
                                                                              bubbleConstraints,
                                                                          child:
                                                                              _MessageExtrasColumn(
                                                                            shadowValue:
                                                                                shadowValue,
                                                                            shadows:
                                                                                extraShadows,
                                                                            crossAxisAlignment: self
                                                                                ? CrossAxisAlignment.end
                                                                                : CrossAxisAlignment.start,
                                                                            children:
                                                                                extras,
                                                                          ),
                                                                        );
                                                                      },
                                                                    );
                                                          final messageKey =
                                                              _messageKeys[
                                                                  messageModel
                                                                      .stanzaID];
                                                          final bubbleDisplay =
                                                              shadowedBubble;
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
                                                                : () {
                                                                    _toggleMessageSelection(
                                                                      messageModel,
                                                                    );
                                                                  },
                                                            onSecondaryTapUp:
                                                                isDesktopPlatform &&
                                                                        !widget
                                                                            .readOnly
                                                                    ? (_) {
                                                                        _toggleMessageSelection(
                                                                          messageModel,
                                                                        );
                                                                      }
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
                                                          Widget? senderLabel;
                                                          if (shouldShowSenderLabel) {
                                                            final double
                                                                senderLabelLeftInset =
                                                                !self &&
                                                                        hasAvatarSlot
                                                                    ? avatarContentInset +
                                                                        _bubblePadding(
                                                                          context,
                                                                        ).left +
                                                                        spacing
                                                                            .xxs
                                                                    : 0.0;
                                                            senderLabel =
                                                                _MessageSenderLabel(
                                                              user:
                                                                  message.user,
                                                              isSelf: self,
                                                              selfLabel: l10n
                                                                  .chatSenderYou,
                                                              leftInset:
                                                                  senderLabelLeftInset,
                                                            );
                                                          }
                                                          final bubbleWithSlack =
                                                              ConstrainedBox(
                                                            constraints:
                                                                BoxConstraints(
                                                              maxWidth:
                                                                  bubbleMaxWidth,
                                                            ),
                                                            child: bubbleStack,
                                                          );
                                                          final Widget
                                                              bubbleStackWithReply =
                                                              _ReplyPreviewBubbleColumn(
                                                            preview:
                                                                replyPreview,
                                                            senderLabel:
                                                                senderLabel,
                                                            bubble:
                                                                bubbleWithSlack,
                                                            spacing:
                                                                calendarInsetLg,
                                                            alignEnd: self,
                                                          );
                                                          final messageBody =
                                                              Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            crossAxisAlignment:
                                                                messageColumnAlignment,
                                                            children: [
                                                              bubbleStackWithReply,
                                                              if (bubbleExtraChildren
                                                                  .isNotEmpty)
                                                                extrasAligned,
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
                                                          final Widget
                                                              messageRegion =
                                                              _MessageBubbleRegion(
                                                            messageId:
                                                                messageModel
                                                                    .stanzaID,
                                                            registry:
                                                                _bubbleRegionRegistry,
                                                            child:
                                                                animatedMessage,
                                                          );
                                                          final Widget
                                                              messageArrival =
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
                                                                          messageRegion,
                                                                    )
                                                                  : messageRegion;
                                                          final Widget
                                                              selectionRegion =
                                                              isSingleSelection
                                                                  ? TapRegion(
                                                                      groupId:
                                                                          _selectionTapRegionGroup,
                                                                      onTapOutside:
                                                                          _armOutsideTapDismiss,
                                                                      child:
                                                                          messageArrival,
                                                                    )
                                                                  : messageArrival;
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
                                                                  selectionRegion,
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
                        final Widget calendarOverlay = _ChatCalendarOverlay(
                          key: ValueKey(
                            '$_chatCalendarPanelKeyPrefix${chatEntity?.jid ?? _chatPanelKeyFallback}',
                          ),
                          chat: chatEntity,
                          calendarAvailable: chatCalendarAvailable,
                          calendarBloc: chatCalendarBloc,
                        );
                        final Widget overlayChild = switch (_chatRoute) {
                          ChatRouteIndex.main => const SizedBox.expand(),
                          ChatRouteIndex.search => const _ChatSearchOverlay(
                              panel: _ChatSearchPanel(),
                            ),
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
                              isChatBlocked: isChatBlocked,
                              blocklistEntry: chatBlocklistEntry,
                              blockAddress: blockAddress,
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
                        final Duration overlayDuration = isDesktopPlatform &&
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
              final Widget content = chatCalendarBloc == null
                  ? scaffold
                  : BlocProvider<ChatCalendarBloc>.value(
                      value: chatCalendarBloc,
                      child: scaffold,
                    );
              final colors = context.colorScheme;
              return Container(
                decoration: BoxDecoration(
                  color: colors.background,
                  border: Border(
                    left: context.borderSide,
                  ),
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
    if (!_shouldPromptEmailForwarding(target: target, messages: messages)) {
      return EmailForwardingMode.original;
    }
    if (!mounted) return null;
    return _showEmailForwardDialog();
  }

  Future<EmailForwardingMode?> _showEmailForwardDialog() async {
    final l10n = context.l10n;
    return showFadeScaleDialog<EmailForwardingMode>(
      context: context,
      builder: (dialogContext) => ShadDialog(
        constraints:
            BoxConstraints(maxWidth: dialogContext.sizing.dialogMaxWidth),
        title: Text(
          l10n.chatForwardEmailWarningTitle,
          style: dialogContext.modalHeaderTextStyle,
        ),
        actions: [
          AxiButton(
            variant: AxiButtonVariant.ghost,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          AxiButton.primary(
            onPressed: () =>
                Navigator.of(dialogContext).pop(EmailForwardingMode.safe),
            child: Text(l10n.chatForwardEmailOptionSafe),
          ),
          AxiButton(
            variant: AxiButtonVariant.destructive,
            onPressed: () =>
                Navigator.of(dialogContext).pop(EmailForwardingMode.original),
            child: Text(l10n.chatForwardEmailOptionOriginal),
          ),
        ],
        child: Text(l10n.chatForwardEmailWarningMessage),
      ),
    );
  }

  Future<void> _handleForward(Message message) async {
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
    if (roomState?.myOccupantId != null) {
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
    final resolvedRoomName =
        roomName?.isNotEmpty == true ? roomName! : unknownRoomFallbackLabel;
    final accepted = await confirm(
      context,
      title: l10n.chatInviteConfirmTitle,
      message: l10n.chatInviteConfirmMessage(resolvedRoomName),
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
    required ChatMessage dashMessage,
    required Message model,
  }) async {
    await _runShareAction(() async {
      final l10n = context.l10n;
      final content = plainTextForMessage(
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
    });
  }

  Future<void> _copyMessage({
    required ChatMessage dashMessage,
    required Message model,
  }) async {
    final successMessage = context.l10n.chatCopySuccessMessage;
    final copiedText = plainTextForMessage(
      dashMessage: dashMessage,
      model: model,
    );
    if (copiedText.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: copiedText));
    if (!mounted) return;
    FeedbackSystem.showSuccess(context, successMessage);
  }

  Future<void> _handleAddToCalendar({
    required ChatMessage dashMessage,
    required Message model,
  }) async {
    final l10n = context.l10n;
    final calendarAvailable =
        context.read<CalendarStorageManager>().isAuthStorageReady;
    const bool demoEmailQuickAdd = kEnableDemoChats;
    if (demoEmailQuickAdd) {
      if (!calendarAvailable) {
        _showSnackbar(l10n.chatCalendarUnavailable);
        return;
      }
      final calendarBloc = context.read<CalendarBloc>();
      final DateTime baseDate = demoNow();
      final DateTime scheduledTime = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day + 1,
        13,
      );
      const Duration duration = Duration(hours: 1);
      const String title = 'hang out';
      calendarBloc.add(
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
      dashMessage: dashMessage,
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
    final shouldFanOut = shouldFanOutRecipients(
      chat: chat,
      recipients: included,
    );
    final l10n = context.l10n;
    return shouldFanOut
        ? l10n.chatRecipientVisibilityBccLabel
        : l10n.chatRecipientVisibilityCcLabel;
  }

  bool shouldFanOutRecipients({
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
      await Share.share(
        joined,
        subject: l10n.chatShareSubjectPrefix(
          context.read<ChatBloc>().state.chat?.title ??
              l10n.chatShareFallbackSubject,
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
  }

  Future<void> _addSelectedToCalendar(List<Message> messages) async {
    final l10n = context.l10n;
    final calendarAvailable =
        context.read<CalendarStorageManager>().isAuthStorageReady;
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
    _setChatRoute(ChatRouteIndex.details);
  }

  void _syncChatRoute() {
    final nextRoute = context.read<ChatsCubit>().state.openChatRoute;
    if (nextRoute == _chatRoute) {
      return;
    }
    _setChatRoute(nextRoute);
  }

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
    final entry = LocalHistoryEntry(
      onRemove: _handleChatRouteHistoryRemoved,
    );
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

  Future<chat_models.Chat?> _selectForwardTarget() async {
    if (!mounted) return null;
    final options =
        (context.read<ChatsCubit>().state.items ?? const <chat_models.Chat>[])
            .where((chat) => chat.jid != context.read<ChatBloc>().jid)
            .cast<chat_models.Chat>()
            .toList(growable: false);
    if (options.isEmpty) return null;
    return showAdaptiveBottomSheet<chat_models.Chat>(
      context: context,
      isScrollControlled: true,
      surfacePadding: EdgeInsets.zero,
      builder: (sheetContext) => _ForwardRecipientSheet(
        availableChats: options,
      ),
    );
  }

  void _toggleQuickReaction(Message message, String emoji) {
    context.read<ChatBloc>().add(
          ChatMessageReactionToggled(message: message, emoji: emoji),
        );
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
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final double iconSize =
        context.iconTheme.size ?? _pinnedBadgeFallbackIconSize;
    final double badgeInset =
        math.max(spacing.xxs, iconSize * _pinnedBadgeInsetScale);
    final Icon icon = Icon(iconData, size: iconSize, color: iconColor);
    if (count <= _pinnedBadgeHiddenCount) {
      return icon;
    }

    final String label = count > _pinnedBadgeMaxDisplayCount
        ? l10n.commonBadgeOverflowLabel
        : count.toString();
    final Widget badge = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        style: context.textTheme.p.copyWith(
          color: colors.destructive,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                right: spacing.xs,
                top: spacing.xxs,
              ),
              child: Center(child: icon),
            ),
          ),
          Positioned(
            top: badgeInset,
            right: badgeInset,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: colors.background,
                shape: RoundedSuperellipseBorder(borderRadius: context.radius),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.xs,
                  vertical: spacing.xxs,
                ),
                child: badge,
              ),
            ),
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
    required this.accountJid,
    required this.pinnedMessages,
    required this.pinnedMessagesLoaded,
    required this.pinnedMessagesHydrating,
    required this.onClose,
    required this.canTogglePins,
    required this.canShowCalendarTasks,
    required this.personalCalendarBloc,
    required this.chatCalendarBloc,
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
  final String? accountJid;
  final List<PinnedMessageItem> pinnedMessages;
  final bool pinnedMessagesLoaded;
  final bool pinnedMessagesHydrating;
  final VoidCallback onClose;
  final bool canTogglePins;
  final bool canShowCalendarTasks;
  final CalendarBloc? personalCalendarBloc;
  final ChatCalendarBloc? chatCalendarBloc;
  final RoomState? roomState;
  final Stream<FileMetadataData?> Function(String) metadataStreamFor;
  final FileMetadataData? Function(String) metadataInitialFor;
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
                    personalCalendarBloc: widget.personalCalendarBloc,
                    chatCalendarBloc: widget.chatCalendarBloc,
                    isHydrating: widget.pinnedMessagesHydrating,
                    accountJid: widget.accountJid,
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
          border: Border(bottom: BorderSide(color: colors.border)),
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
            Flexible(fit: FlexFit.loose, child: panelBody),
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
    required this.personalCalendarBloc,
    required this.chatCalendarBloc,
    required this.isHydrating,
    required this.accountJid,
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
  final CalendarBloc? personalCalendarBloc;
  final ChatCalendarBloc? chatCalendarBloc;
  final bool isHydrating;
  final String? accountJid;
  final Stream<FileMetadataData?> Function(String) metadataStreamFor;
  final FileMetadataData? Function(String) metadataInitialFor;
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
  }) onApproveAttachment;

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
      final myOccupantId = roomState?.myOccupantId;
      final selfNick = (myOccupantId == null
              ? null
              : roomState?.occupants[myOccupantId]?.nick) ??
          chat.myNickname;
      final normalizedSelf = normalizeOccupantId(myOccupantId);
      if (normalizedSelf != null) {
        final normalizedSender = normalizeOccupantId(message.senderJid);
        if (normalizedSender != null && normalizedSender == normalizedSelf) {
          return true;
        }
        final normalizedOccupant = normalizeOccupantId(message.occupantID);
        if (normalizedOccupant != null &&
            normalizedOccupant == normalizedSelf) {
          return true;
        }
      }
      final trimmedSelfNick = selfNick?.trim();
      if (trimmedSelfNick == null || trimmedSelfNick.isEmpty) {
        return false;
      }
      final senderNick = nickFromSender(message.senderJid);
      if (senderNick == null || senderNick.isEmpty) {
        return false;
      }
      return senderNick == trimmedSelfNick;
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

  String? nickFromSender(String senderJid) {
    return addressResourcePart(senderJid);
  }

  String? normalizeOccupantId(String? jid) {
    return normalizedOccupantId(jid);
  }

  Occupant? resolveOccupantForMessage(Message message) {
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
    final nick = nickFromSender(message.senderJid);
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
      final occupant = resolveOccupantForMessage(message);
      final String? occupantNick = occupant?.nick;
      final String? trimmedNick = occupantNick?.trim();
      final bool hasNick = trimmedNick != null && trimmedNick.isNotEmpty;
      label = hasNick ? trimmedNick : nickFromSender(message.senderJid);
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
    final String? taskShareText =
        calendarTask?.toShareText(context.l10n).trim();
    final bool hideTaskText = taskShareText != null &&
        taskShareText.isNotEmpty &&
        taskShareText == messageText;
    final CalendarFragment? calendarFragment = message?.calendarFragment;
    final CalendarCriticalPathFragment? criticalPathFragment = calendarFragment
        ?.maybeMap(criticalPath: (value) => value, orElse: () => null);
    final bool hasCriticalPath = criticalPathFragment != null;
    final String? criticalPathShareText = hasCriticalPath
        ? CalendarFragmentFormatter(context.l10n)
            .describe(calendarFragment!)
            .trim()
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
    final messageStyle = context.textTheme.p.copyWith(color: colors.foreground);
    final messageWidget = showLoading
        ? Align(
            alignment: Alignment.centerLeft,
            child: AxiProgressIndicator(
              color: colors.mutedForeground,
            ),
          )
        : showMessageText
            ? Text(messageText ?? _emptyText, style: messageStyle)
            : showMissing
                ? Text(
                    l10n.chatPinnedMissingMessage,
                    style: context.textTheme.muted.copyWith(
                      color: colors.mutedForeground,
                    ),
                  )
                : null;
    final messageForPin = resolveMessageForPin();
    final unpinButton = canTogglePins && messageForPin != null
        ? AxiTooltip(
            builder: (context) => Text(l10n.chatUnpinMessage),
            child: AxiIconButton.ghost(
              onPressed: () => context.read<ChatBloc>().add(
                    ChatMessagePinRequested(message: messageForPin, pin: false),
                  ),
              iconData: LucideIcons.pinOff,
              iconSize: context.sizing.menuItemIconSize,
            ),
          )
        : null;
    final isSelf = message == null
        ? false
        : isSelfMessage(message: message, accountJid: accountJid);
    final senderLabel = resolveSenderLabel(
      context: context,
      message: message,
      isSelf: isSelf,
    );
    final spacing = context.spacing;
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
        SizedBox(height: spacing.xs + spacing.xxs),
        messageWidget,
      ],
    ];
    if (hasCalendarTask) {
      final bool taskReadOnly =
          message?.calendarTaskIcsReadOnly ?? _calendarTaskIcsReadOnlyFallback;
      contentChildren.add(SizedBox(height: spacing.s));
      contentChildren.add(
        canShowCalendarTasks
            ? ChatCalendarTaskCard(
                task: calendarTask,
                readOnly: taskReadOnly,
                requireImportConfirmation: !isSelf,
                demoQuickAdd: kEnableDemoChats &&
                    chat.defaultTransport.isEmail &&
                    !isSelf,
                footerDetails: _emptyInlineSpans,
                isShareFragment: true,
              )
            : CalendarFragmentCard(
                fragment: CalendarFragment.task(task: calendarTask),
                footerDetails: _emptyInlineSpans,
              ),
      );
    }
    final resolvedCriticalPath = criticalPathFragment;
    if (resolvedCriticalPath != null) {
      contentChildren.add(SizedBox(height: spacing.s));
      contentChildren.add(
        ChatCalendarCriticalPathCard(
          path: resolvedCriticalPath.path,
          tasks: resolvedCriticalPath.tasks,
          footerDetails: _emptyInlineSpans,
          personalBloc: personalCalendarBloc,
          chatBloc: chatCalendarBloc,
        ),
      );
    }
    if (hasAttachments) {
      contentChildren.add(SizedBox(height: spacing.s));
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
      final emailDownloadDelegate = isEmailBacked
          ? AttachmentDownloadDelegate(
              () async {
                await context
                    .read<ChatBloc>()
                    .downloadFullEmailMessage(message);
                return true;
              },
            )
          : null;
      for (var index = 0; index < attachmentIds.length; index += 1) {
        final attachmentId = attachmentIds[index];
        final downloadDelegate = isEmailBacked
            ? emailDownloadDelegate
            : AttachmentDownloadDelegate(
                () => context.read<ChatBloc>().downloadInboundAttachment(
                      metadataId: attachmentId,
                      stanzaId: message.stanzaID,
                    ),
              );
        final metadataReloadDelegate = AttachmentMetadataReloadDelegate(
          () => context.read<ChatBloc>().reloadFileMetadata(attachmentId),
        );
        if (index > 0) {
          contentChildren.add(SizedBox(height: spacing.s));
        }
        contentChildren.add(
          ChatAttachmentPreview(
            stanzaId: message.stanzaID,
            metadataStream: metadataStreamFor(attachmentId),
            initialMetadata: metadataInitialFor(attachmentId),
            allowed: allowAttachment,
            downloadDelegate: downloadDelegate,
            metadataReloadDelegate: metadataReloadDelegate,
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
    required this.calendarBloc,
  });

  final chat_models.Chat? chat;
  final bool calendarAvailable;
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
        BlocProvider<ChatCalendarBloc>.value(value: resolvedBloc),
        BlocProvider<CalendarBloc>.value(value: resolvedBloc),
      ],
      child: ChatCalendarWidget(
        chat: resolvedChat,
        showHeader: true,
        showBackButton: false,
      ),
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
        child: ChatMessageDetails(
          onAddRecipient: onAddRecipient,
          loadedEmailImageMessageIds: loadedEmailImageMessageIds,
          onEmailImagesApproved: onEmailImagesApproved,
        ),
      ),
    );
  }
}

class _ChatSearchOverlay extends StatelessWidget {
  const _ChatSearchOverlay({required this.panel});

  final Widget panel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        panel,
        const Expanded(child: IgnorePointer(child: SizedBox.expand())),
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
  const _ChatGalleryOverlay({required this.chat});

  final chat_models.Chat? chat;

  @override
  Widget build(BuildContext context) {
    final resolvedChat = chat;
    if (resolvedChat == null) {
      return const SizedBox.shrink();
    }
    return BlocProvider(
      create: (context) {
        final endpointConfig =
            context.read<SettingsCubit>().state.endpointConfig;
        final emailService =
            endpointConfig.enableSmtp ? context.read<EmailService>() : null;
        return AttachmentGalleryBloc(
          xmppService: context.read<XmppService>(),
          emailService: emailService,
          chatJid: resolvedChat.jid,
          chatOverride: resolvedChat,
          showChatLabel: false,
        );
      },
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
    required this.calendarBloc,
  });

  final chat_models.Chat? chat;
  final bool calendarAvailable;
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
          calendarBloc: resolvedBloc,
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
            child: FadeScaleTransition(
              animation: opacity,
              child: widget.child,
            ),
          );
    return TickerMode(
      enabled: visible,
      child: IgnorePointer(
        ignoring: !visible,
        child: ExcludeSemantics(excluding: !visible, child: transitionChild),
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
  final StreamController<FileMetadataData?> controller0 =
      StreamController<FileMetadataData?>.broadcast();
  StreamSubscription<FileMetadataData?>? subscription;
  var hasValue = false;
  FileMetadataData? latest;
  Object? lastError;
  StackTrace? lastStackTrace;

  late final Stream<FileMetadataData?> stream = Stream.multi((multi) {
    if (lastError != null) {
      multi.addError(lastError!, lastStackTrace);
    } else if (hasValue) {
      multi.add(latest);
    }
    final subscription = controller0.stream.listen(
      multi.add,
      onError: (Object error, StackTrace stackTrace) =>
          multi.addError(error, stackTrace),
    );
    multi.onCancel = subscription.cancel;
  });

  FileMetadataData? get latestOrNull => hasValue ? latest : null;

  void attach(Stream<FileMetadataData?> source) {
    if (subscription != null) return;
    subscription = source.listen(
      (value) {
        latest = value;
        hasValue = true;
        controller0.add(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        controller0.addError(error, stackTrace);
      },
    );
  }

  void dispose() {
    subscription?.cancel();
    controller0.close();
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
  const reactionChipSpacing = 0.6;
  const reactionOverflowGlyphWidth = 18.0;
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
    final spacing = visible.isEmpty ? 0 : reactionChipSpacing;
    final addition = spacing +
        measureReactionChipWidth(
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
    var spacing = visible.isEmpty ? 0 : reactionChipSpacing;
    const glyphWidth = reactionOverflowGlyphWidth;
    while (visible.isNotEmpty &&
        limit.isFinite &&
        totalWidth + spacing + glyphWidth > limit) {
      totalWidth -= additions.removeLast();
      visible.removeLast();
      spacing = visible.isEmpty ? 0 : reactionChipSpacing;
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

double measureReactionChipWidth({
  required BuildContext context,
  required ReactionPreview reaction,
  required TextDirection textDirection,
  required TextScaler textScaler,
}) {
  const reactionChipPadding =
      EdgeInsets.symmetric(horizontal: 0.2, vertical: 2);
  const reactionSubscriptPadding = 3.0;
  final emojiPainter = TextPainter(
    text: TextSpan(
      text: reaction.emoji,
      style: reactionEmojiTextStyle(
        context,
        highlighted: reaction.reactedBySelf,
      ),
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
        style: reactionCountTextStyle(
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
          reactionSubscriptPadding +
          reactionChipPadding.horizontal,
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
    return AxiAvatar(jid: jid, size: size, avatarPath: avatarPath);
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
              onTap: null,
            ),
          );
        }
        if (layout.overflowed) {
          if (children.isNotEmpty) {
            children.add(const SizedBox(width: _reactionOverflowSpacing));
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
    final colors = context.colorScheme;
    final l10n = context.l10n;
    return SizedBox(
      width: _reactionOverflowGlyphWidth,
      height: 18,
      child: Center(
        child: Text(
          l10n.commonEllipsis,
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
  const _ReplyStrip({required this.participants, this.onRecipientTap});

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
                      (_recipientAvatarSize - _recipientAvatarOverlap) +
                  _recipientOverflowGap;
          children.add(
            Positioned(left: offset, child: const _RecipientOverflowAvatar()),
          );
        }
        final baseWidth = layout.totalWidth;
        final totalWidth = overflowed
            ? baseWidth + _recipientOverflowGap + _recipientAvatarSize
            : math.max(baseWidth, _recipientAvatarSize);
        return SizedBox(
          width: totalWidth,
          height: _recipientAvatarSize,
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
            Positioned(left: offset, child: const _RecipientOverflowAvatar()),
          );
        }
        final baseWidth = layout.totalWidth;
        final totalWidth = overflowed
            ? baseWidth + _recipientOverflowGap + _recipientAvatarSize
            : math.max(baseWidth, _recipientAvatarSize);
        return SizedBox(
          width: totalWidth,
          height: _recipientAvatarSize,
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
    const borderWidth = 1.6;
    final shape = SquircleBorder(cornerRadius: context.radii.squircle);
    final avatarPath = (chat.avatarPath ?? chat.contactAvatarPath)?.trim();
    final resolvedAvatarPath =
        avatarPath?.isNotEmpty == true ? avatarPath : null;
    return SizedBox(
      width: _recipientAvatarSize,
      height: _recipientAvatarSize,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: colors.card, shape: shape),
        child: Padding(
          padding: const EdgeInsets.all(borderWidth),
          child: AxiAvatar(
            jid: chat.avatarIdentifier,
            size: _recipientAvatarSize - (borderWidth * 2),
            avatarPath: resolvedAvatarPath,
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
    return SizedBox(
      width: _recipientAvatarSize,
      height: _recipientAvatarSize,
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
            Positioned(left: offset, child: const _RecipientOverflowAvatar()),
          );
        }
        final baseWidth = layout.totalWidth;
        final totalWidth = overflowed
            ? baseWidth + _recipientOverflowGap + _recipientAvatarSize
            : math.max(baseWidth, _recipientAvatarSize);
        return SizedBox(
          width: totalWidth,
          height: _recipientAvatarSize,
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
    final shape = SquircleBorder(cornerRadius: context.radii.squircle);
    return Container(
      width: _recipientAvatarSize,
      height: _recipientAvatarSize,
      padding: const EdgeInsets.all(_typingAvatarBorderWidth),
      decoration: ShapeDecoration(color: borderColor, shape: shape),
      child: AxiAvatar(
        jid: jid,
        size: _recipientAvatarSize - (_typingAvatarBorderWidth * 2),
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
    return Text(
      resolved,
      maxLines: maxLines,
      overflow: overflow,
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
    final spacing = context.spacing;
    const labelMaxLines = 1;
    const labelOverflow = TextOverflow.ellipsis;
    const iconBackgroundAlpha = 0.15;
    const actionButtonCount = 1;
    final iconCornerRadius = spacing.s + spacing.xs;
    final cardCornerRadius = spacing.m + spacing.xs;
    final padding = EdgeInsets.all(spacing.s + spacing.xs);
    final rowSpacing = spacing.s + spacing.xs;
    final detailSpacing = spacing.xs;
    final actionSpacing = spacing.s;
    final iconSize = spacing.m + spacing.xs;
    final iconWidth = spacing.l + spacing.s + spacing.xxs;
    final iconHeight = spacing.l + spacing.s + spacing.xs + spacing.xxs;
    final actionRowMinWidth =
        (AxiIconButton.kTapTargetSize * actionButtonCount) +
            (actionSpacing * (actionButtonCount - 1));
    final inlineActionsMinWidth =
        iconWidth + (rowSpacing * 2) + actionRowMinWidth;
    final Color labelColor =
        enabled ? colors.foreground : colors.mutedForeground;
    final Color iconColor =
        enabled ? colors.foreground : colors.mutedForeground;
    final String trimmedDetailLabel = detailLabel.trim();
    final bool showDetailLabel = trimmedDetailLabel.isNotEmpty;
    final Widget attachmentIcon = DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.muted.withValues(alpha: iconBackgroundAlpha),
        shape: SquircleBorder(
          cornerRadius: iconCornerRadius,
          side: BorderSide(color: colors.border),
        ),
      ),
      child: SizedBox(
        width: iconWidth,
        height: iconHeight,
        child: Center(
          child: Icon(
            LucideIcons.userPlus,
            size: iconSize,
            color: iconColor,
          ),
        ),
      ),
    );
    final Widget attachmentDetails = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: detailSpacing,
      children: [
        _InviteAttachmentText(
          text: label,
          maxLines: labelMaxLines,
          overflow: labelOverflow,
          style: context.textTheme.small.copyWith(
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        ),
        if (showDetailLabel)
          _InviteAttachmentText(
            text: trimmedDetailLabel,
            maxLines: labelMaxLines,
            overflow: labelOverflow,
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
          borderRadius: BorderRadius.circular(cardCornerRadius),
          side: BorderSide(color: colors.border),
        ),
      ),
      child: Padding(
        padding: padding,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool stackActions =
                constraints.maxWidth < inlineActionsMinWidth;
            if (stackActions) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      attachmentIcon,
                      SizedBox(width: rowSpacing),
                      Expanded(child: attachmentDetails),
                    ],
                  ),
                  SizedBox(height: actionSpacing),
                  Align(alignment: Alignment.centerRight, child: actionButton),
                ],
              );
            }
            return Row(
              children: [
                attachmentIcon,
                SizedBox(width: rowSpacing),
                Expanded(child: attachmentDetails),
                SizedBox(width: rowSpacing),
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

class _MessageExtraGap extends StatelessWidget {
  const _MessageExtraGap({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

class _MessageExtraItem extends StatelessWidget {
  const _MessageExtraItem({
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
    required this.child,
    required this.shape,
    required this.shadows,
  });

  final Widget child;
  final ShapeBorder shape;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    if (shadows.isEmpty) {
      return child;
    }
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
    final bool showShadow = shadowValue > 0;
    final List<BoxShadow> resolvedShadows =
        showShadow ? _scaleShadows(shadows, shadowValue) : const <BoxShadow>[];
    final decoratedChildren = children.map((child) {
      if (child is _MessageExtraGap || !showShadow) {
        return child;
      }
      if (child is _MessageExtraItem) {
        return _MessageExtraShadow(
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
  })  : messageId0 = messageId,
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
    final spacing = context.spacing;
    final sizing = context.sizing;
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

    return AxiModalSurface(
      backgroundColor: background,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.m,
        vertical: spacing.s,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: sizing.menuItemIconSize,
            color: foreground,
          ),
          SizedBox(width: spacing.s),
          Expanded(
            child: Text(
              message,
              style: context.textTheme.small.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            AxiButton(
              variant: AxiButtonVariant.ghost,
              onPressed: onAction,
              child: Text(
                actionLabel,
                style: context.textTheme.small.copyWith(color: foreground),
              ),
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
    required this.selfJid,
    required this.selfIdentity,
    required this.subjectController,
    required this.subjectFocusNode,
    required this.textController,
    required this.textFocusNode,
    required this.tapRegionGroup,
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
    this.onComposerErrorCleared,
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
  final String? selfJid;
  final SelfIdentitySnapshot selfIdentity;
  final TextEditingController subjectController;
  final FocusNode subjectFocusNode;
  final TextEditingController textController;
  final FocusNode textFocusNode;
  final Object tapRegionGroup;
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
  final VoidCallback? onComposerErrorCleared;
  final bool showAttachmentWarning;
  final FanOutSendReport? retryReport;
  final String? retryShareId;
  final ValueChanged<CalendarDragPayload>? onTaskDropped;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final myJid = selfJid;
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
    final hasPreparingAttachments = pendingAttachments.any(
      (attachment) => attachment.isPreparing,
    );
    final hasSubjectText = subjectController.text.trim().isNotEmpty;
    final hasRecipients = recipients.any((recipient) => recipient.included);
    final sendEnabled = !hasPreparingAttachments &&
        hasRecipients &&
        (composerHasText || hasQueuedAttachments || hasSubjectText);
    final composerError = this.composerError;
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
              border: Border(top: BorderSide(color: colors.border, width: 1)),
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
                      actions: buildComposerAccessories(canSend: sendEnabled),
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
    final locate = context.read;
    final notices = <Widget>[];
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
      final noticePadding = EdgeInsets.symmetric(
        horizontal: horizontalPadding + _composerNoticeHorizontalInset,
      );
      for (var i = 0; i < notices.length; i++) {
        children.add(Padding(padding: noticePadding, child: notices[i]));
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
        rosterItems:
            context.watch<RosterCubit>().state.items ?? const <RosterItem>[],
        recipientSuggestionsStream:
            locate<ChatsCubit>().recipientAddressSuggestionsStream(),
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
      ),
    );
    children.add(composer);
    return TapRegion(
      groupId: tapRegionGroup,
      onTapOutside: (_) {
        if (!textFocusNode.hasFocus && !subjectFocusNode.hasFocus) {
          return;
        }
        textFocusNode.unfocus();
        subjectFocusNode.unfocus();
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
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
            border: Border(top: BorderSide(color: colors.border, width: 1)),
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

class _HtmlPreviewDialog extends StatefulWidget {
  const _HtmlPreviewDialog({
    required this.html,
    required this.shouldLoadImages,
    required this.onLoadRequested,
    required this.onLinkTap,
  });

  final String html;
  final bool shouldLoadImages;
  final VoidCallback? onLoadRequested;
  final ValueChanged<String> onLinkTap;

  @override
  State<_HtmlPreviewDialog> createState() => _HtmlPreviewDialogState();
}

class _HtmlPreviewDialogState extends State<_HtmlPreviewDialog> {
  late bool _shouldLoadImages = widget.shouldLoadImages;

  @override
  void didUpdateWidget(covariant _HtmlPreviewDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shouldLoadImages != widget.shouldLoadImages) {
      _shouldLoadImages = widget.shouldLoadImages;
    }
  }

  void _handleLoadRequested() {
    if (!_shouldLoadImages) {
      setState(() {
        _shouldLoadImages = true;
      });
    }
    widget.onLoadRequested?.call();
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final spacing = context.spacing;
    final widthInset = spacing.xl + spacing.l;
    final heightInset = spacing.xxl + spacing.l;
    final maxWidth = math.max(0.0, mediaSize.width - widthInset);
    final maxHeight = math.max(0.0, mediaSize.height - heightInset);
    final colors = context.colorScheme;
    final radius = context.radius;
    final borderSide = context.borderSide;
    final textStyle = context.textTheme.p.copyWith(color: colors.foreground);
    return ShadDialog(
      padding: EdgeInsets.all(spacing.s),
      gap: spacing.s,
      closeIcon: const SizedBox.shrink(),
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
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
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                  ),
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(spacing.m),
                      child: _MessageHtmlBody(
                        html: widget.html,
                        textStyle: textStyle,
                        textColor: colors.foreground,
                        linkColor: colors.primary,
                        shouldLoadImages: _shouldLoadImages,
                        onLoadRequested: widget.onLoadRequested == null
                            ? null
                            : _handleLoadRequested,
                        onLinkTap: widget.onLinkTap,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: spacing.xs,
            right: spacing.xs,
            child: AxiIconButton.ghost(
              onPressed: () => Navigator.of(context).pop(),
              iconData: LucideIcons.x,
            ),
          ),
        ],
      ),
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
    final spacing = context.spacing;
    final sizing = context.sizing;
    final widthInset = spacing.xl + spacing.l;
    final heightInset = spacing.xxl + spacing.l;
    final minPreviewExtent = spacing.xxl + spacing.xl + spacing.l;
    final maxWidth =
        (mediaSize.width - widthInset).clamp(minPreviewExtent, mediaSize.width);
    final maxHeight = (mediaSize.height - heightInset)
        .clamp(minPreviewExtent, mediaSize.height);
    final targetSize = fitWithinBounds(
      intrinsicSize: intrinsicSize,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    final colors = context.colorScheme;
    final radius = context.radius;
    final borderSide = context.borderSide;
    final chromeInset = spacing.m + spacing.s;

    return ShadDialog(
      padding: EdgeInsets.all(spacing.s),
      gap: spacing.s,
      closeIcon: const SizedBox.shrink(),
      constraints: BoxConstraints(
        maxWidth: targetSize.width + chromeInset,
        maxHeight: targetSize.height + chromeInset,
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
                    maxScale: sizing.mediaPreviewMaxScale,
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
            top: spacing.xs,
            right: spacing.xs,
            child: AxiIconButton.ghost(
              onPressed: () => Navigator.of(context).pop(),
              iconData: LucideIcons.x,
            ),
          ),
        ],
      ),
    );
  }

  Size fitWithinBounds({
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
        padding: _reactionChipPadding,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Text(data.emoji, style: emojiStyle),
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
      child: Container(
        height: borderSide.width,
        color: colors.primary,
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.m,
        vertical: spacing.s,
      ),
      child: Row(
        children: [
          line,
          SizedBox(width: spacing.s),
          Text(
            label,
            style: textTheme.muted.copyWith(color: colors.primary),
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
    this.onSelect,
    this.onResend,
    this.onEdit,
    this.onPinToggle,
    required this.isPinned,
    this.onRevokeInvite,
  });

  final VoidCallback onReply;
  final VoidCallback? onForward;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final RequestStatus shareStatus;
  final VoidCallback onAddToCalendar;
  final VoidCallback onDetails;
  final VoidCallback? onSelect;
  final VoidCallback? onResend;
  final VoidCallback? onEdit;
  final VoidCallback? onPinToggle;
  final bool isPinned;
  final VoidCallback? onRevokeInvite;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.of(context).textScaler;
    final l10n = context.l10n;
    double scaled(double value) => textScaler.scale(value);
    final actions = <Widget>[
      ContextActionButton(
        icon: const Icon(LucideIcons.reply, size: _messageActionIconSize),
        label: l10n.chatActionReply,
        onPressed: onReply,
      ),
      ContextActionButton(
        icon: Transform.scale(
          scaleX: -1,
          child: const Icon(LucideIcons.reply, size: _messageActionIconSize),
        ),
        label: l10n.chatActionForward,
        onPressed: onForward,
      ),
      ContextActionButton(
        icon: const Icon(LucideIcons.copy, size: _messageActionIconSize),
        label: l10n.chatActionCopy,
        onPressed: onCopy,
      ),
      ContextActionButton(
        icon: shareStatus.isLoading
            ? AxiProgressIndicator(
                color: context.colorScheme.foreground,
              )
            : const Icon(LucideIcons.share2, size: _messageActionIconSize),
        label: l10n.chatActionShare,
        onPressed: shareStatus.isLoading ? null : onShare,
      ),
      ContextActionButton(
        icon: const Icon(
          LucideIcons.calendarPlus,
          size: _messageActionIconSize,
        ),
        label: l10n.chatActionAddToCalendar,
        onPressed: onAddToCalendar,
      ),
      ContextActionButton(
        icon: const Icon(LucideIcons.info, size: _messageActionIconSize),
        label: l10n.chatActionDetails,
        onPressed: onDetails,
      ),
    ];
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
    } else if (!widget.animate && !completed) {
      controller0.value = 1;
      completed = true;
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
          SelectionSummaryHeader(count: count, onClear: onClear),
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
                icon: shareStatus.isLoading
                    ? AxiProgressIndicator(
                        color: context.colorScheme.foreground,
                      )
                    : const Icon(LucideIcons.share2, size: 16),
                label: l10n.chatActionShare,
                onPressed: shareStatus.isLoading ? null : onShare,
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
          final maxWidth =
              math.min(constraints.maxWidth, context.sizing.dialogMaxWidth);
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
    final BlocklistState blocklistState = context.watch<BlocklistCubit>().state;
    final bool globalSignatureEnabled =
        context.watch<SettingsCubit>().state.shareTokenSignatureEnabled;
    final bool chatSignatureEnabled =
        chat.shareSignatureEnabled ?? globalSignatureEnabled;
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
    final bool showXmppCapabilities = chat.defaultTransport.isXmpp;
    final itemPadding = EdgeInsets.all(context.spacing.m);
    final bool blockActionInFlight = switch (blocklistState) {
      BlocklistLoading state => state.jid == null ||
          state.jid == resolvedBlockAddress ||
          state.jid == resolvedBlockEntryAddress,
      _ => false,
    };
    final bool blockSwitchEnabled = !blockActionInFlight &&
        (isChatBlocked ? hasBlockEntry : hasBlockAddress);
    final List<Widget> tiles = [
      if (showXmppCapabilities)
        Padding(
          padding: itemPadding,
          child: _ChatCapabilitiesSection(
            capabilities: state.xmppCapabilities,
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
                ChatNotificationPreviewSettingChanged(setting),
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
                      ChatShareSignatureToggled(enabled),
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
                          transport: chat.defaultTransport,
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
  const _ChatCapabilitiesSection({required this.capabilities});

  final XmppPeerCapabilities? capabilities;

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
    return parts.map((part) {
      final lower = part.toLowerCase();
      if (lower.length <= 3) {
        return lower.toUpperCase();
      }
      if (lower.length == 4 && lower == 'xep') {
        return lower.toUpperCase();
      }
      return lower[0].toUpperCase() + lower.substring(1);
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final textTheme = context.textTheme;
    final sizing = context.sizing;
    final resolvedAt = capabilities?.resolvedAt;
    final String subtitle = resolvedAt == null
        ? l10n.commonUnknownLabel
        : l10n.chatSettingsCapabilitiesUpdated(
            TimeFormatter.formatFriendlyDateTime(l10n, resolvedAt),
          );
    final features = capabilities?.features ?? const <String>[];
    final List<_CapabilityEntry> entries = features
        .map(
          (feature) => _CapabilityEntry(
            label: _formatFeatureLabel(feature),
            raw: feature,
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.chatSettingsCapabilitiesTitle),
        SizedBox(height: spacing.xs),
        Text(subtitle, style: textTheme.muted),
        SizedBox(height: spacing.s),
        if (entries.isEmpty)
          Text(
            l10n.chatSettingsCapabilitiesEmpty,
            style: textTheme.muted,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final minTileWidth = sizing.menuMinWidth;
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
                          raw: entry.raw,
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
  const _CapabilityEntry({
    required this.label,
    required this.raw,
  });

  final String label;
  final String raw;
}

class _CapabilityTile extends StatelessWidget {
  const _CapabilityTile({
    required this.label,
    required this.raw,
  });

  final String label;
  final String raw;

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
          SizedBox(height: spacing.xs),
          Text(raw, style: textTheme.muted),
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
  const _ChatViewFilterControl({required this.filter, required this.onChanged});

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
        child: AxiSelect<MessageTimelineFilter>(
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
          selectedOptionBuilder: (_, value) => Text(value.menuLabel(l10n)),
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
    return _ChatSettingsRow(
      title: l10n.settingsNotificationPreviews,
      trailing: SizedBox(
        width: _chatSettingsSelectMinWidth,
        child: AxiSelect<NotificationPreviewSetting?>(
          initialValue: setting,
          onChanged: (value) {
            onChanged(value);
          },
          options: <NotificationPreviewSetting?>[
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
                            showLabel: l10n.chatNotificationPreviewOptionShow,
                            hideLabel: l10n.chatNotificationPreviewOptionHide,
                          ),
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
    final enabled = (chat.attachmentAutoDownload ??
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
            ChatAttachmentAutoDownloadToggled(value),
          ),
    );
  }
}

class _ReactionManager extends StatefulWidget {
  const _ReactionManager({
    required this.reactions,
    required this.onToggle,
    required this.onAddCustom,
  });

  final List<ReactionPreview> reactions;
  final ValueChanged<String> onToggle;
  final VoidCallback onAddCustom;

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
    final resolved = signature ?? _reactionsSignature(widget.reactions);
    _signature = resolved;
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
          if (hasReactions)
            Wrap(
              spacing: spacing.s,
              runSpacing: spacing.s,
              children: [
                for (final reaction in sorted)
                  _ReactionManagerChip(
                    key: ValueKey(reaction.emoji),
                    data: reaction,
                    onToggle: () => widget.onToggle(reaction.emoji),
                  ),
              ],
            )
          else
            Text(
              context.l10n.chatReactionsNone,
              style: textTheme.small.copyWith(color: colors.mutedForeground),
            ),
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
                  onPressed: () => widget.onToggle(emoji),
                ),
              _ReactionAddButton(onPressed: widget.onAddCustom),
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
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AxiButton.secondary(
      onPressed: onPressed,
      child: Text(emoji),
    );
  }
}

class _ReactionAddButton extends StatelessWidget {
  const _ReactionAddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AxiButton.outline(
      onPressed: onPressed,
      leading: Icon(
        LucideIcons.plus,
        size: context.sizing.menuItemIconSize,
      ),
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
    final resolvedSenderLabel = senderLabel.trim();
    return Builder(
      builder: (context) {
        final split = ChatSubjectCodec.splitXmppBody(message.body);
        final subject = split.subject?.trim();
        final body = split.body.trim();
        final previewParts = <String>[];
        if (subject?.isNotEmpty == true) {
          previewParts.add(subject!);
        }
        if (body.isNotEmpty) {
          previewParts.add(body);
        }
        final previewText = previewParts.isNotEmpty
            ? previewParts.join(' — ')
            : context.l10n.chatQuotedNoContent;
        final quotedPreview = '"$previewText"';
        return _ReplyingToPreviewText(
          senderLabel: resolvedSenderLabel,
          quotedPreview: quotedPreview,
          isSelf: isSelf,
        );
      },
    );
  }
}

class _ReplyingToPreviewText extends StatelessWidget {
  const _ReplyingToPreviewText({
    required this.senderLabel,
    required this.quotedPreview,
    required this.isSelf,
  });

  final String senderLabel;
  final String quotedPreview;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final baseStyle = context.textTheme.small;
    final mutedStyle = baseStyle.copyWith(color: colors.mutedForeground);
    final prefixStyle = context.textTheme.sectionLabelM;
    final replyPrefix = context.l10n.chatReplyingTo;
    final senderSpan = TextSpan(
      text: senderLabel,
      style: mutedStyle.copyWith(fontWeight: FontWeight.w600),
    );
    final headerPrefixSpan = TextSpan(
      text: replyPrefix.toUpperCase(),
      style: prefixStyle,
    );
    final headerWithNameSpan = TextSpan(
      children: [
        headerPrefixSpan,
        const TextSpan(text: ' '),
        senderSpan,
      ],
    );
    final quoteSpan = TextSpan(text: quotedPreview, style: baseStyle);
    final textAlign = isSelf ? TextAlign.end : TextAlign.start;
    final crossAxisAlignment =
        isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler =
            MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
        final headerPainter = TextPainter(
          text: headerWithNameSpan,
          textDirection: Directionality.of(context),
          textScaler: textScaler,
        )..layout(maxWidth: constraints.maxWidth);
        final headerFits = headerPainter.computeLineMetrics().length <= 1;
        if (!headerFits) {
          final inlineQuoteSpan = TextSpan(
            children: [
              senderSpan,
              const TextSpan(text: ' '),
              quoteSpan,
            ],
          );
          return Column(
            crossAxisAlignment: crossAxisAlignment,
            spacing: 2,
            children: [
              Text(
                replyPrefix,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: textAlign,
                style: mutedStyle,
              ),
              Text.rich(
                inlineQuoteSpan,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: textAlign,
              ),
            ],
          );
        }
        final inlinePainter = TextPainter(
          text: TextSpan(
            children: [
              headerWithNameSpan,
              const TextSpan(text: ' '),
              quoteSpan,
            ],
          ),
          textDirection: Directionality.of(context),
          textScaler: textScaler,
        )..layout(maxWidth: constraints.maxWidth);
        final canInline = inlinePainter.computeLineMetrics().length <= 1;
        if (canInline) {
          return Text.rich(
            TextSpan(
              children: [
                headerWithNameSpan,
                const TextSpan(text: ' '),
                quoteSpan,
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
          );
        }
        return Column(
          crossAxisAlignment: crossAxisAlignment,
          spacing: 2,
          children: [
            Text.rich(
              headerWithNameSpan,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: textAlign,
            ),
            Text(
              quotedPreview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: textAlign,
              style: baseStyle,
            ),
          ],
        );
      },
    );
  }
}

class _ReplyPreviewBubbleColumn extends MultiChildRenderObjectWidget {
  const _ReplyPreviewBubbleColumn({
    required this.preview,
    required this.senderLabel,
    required this.bubble,
    required this.spacing,
    required this.alignEnd,
  });

  final Widget? preview;
  final Widget? senderLabel;
  final Widget bubble;
  final double spacing;
  final bool alignEnd;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReplyPreviewBubbleColumn(
        spacing: spacing,
        hasPreview: preview != null,
        hasSenderLabel: senderLabel != null,
        alignEnd: alignEnd,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderReplyPreviewBubbleColumn renderObject,
  ) {
    renderObject
      ..spacing = spacing
      ..hasPreview = preview != null
      ..hasSenderLabel = senderLabel != null
      ..alignEnd = alignEnd;
  }

  @override
  List<Widget> get children => <Widget>[
        if (senderLabel != null) senderLabel!,
        if (preview != null) preview!,
        bubble,
      ];
}

class _ReplyPreviewBubbleParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderReplyPreviewBubbleColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ReplyPreviewBubbleParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox,
            _ReplyPreviewBubbleParentData> {
  _RenderReplyPreviewBubbleColumn({
    required double spacing,
    required bool hasPreview,
    required bool hasSenderLabel,
    required bool alignEnd,
  })  : _spacing = spacing,
        _hasPreview = hasPreview,
        _hasSenderLabel = hasSenderLabel,
        _alignEnd = alignEnd;

  double _spacing;
  bool _hasPreview;
  bool _hasSenderLabel;
  bool _alignEnd;

  double get spacing => _spacing;

  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  bool get hasPreview => _hasPreview;

  set hasPreview(bool value) {
    if (_hasPreview == value) return;
    _hasPreview = value;
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
    final RenderBox? previewChild = hasPreview
        ? (hasSenderLabel ? childAfter(senderLabelChild!) : firstChild)
        : null;
    final RenderBox? bubbleChild = lastChild;
    if (bubbleChild == null) {
      size = constraints.smallest;
      return;
    }
    bubbleChild.layout(constraints.loosen(), parentUsesSize: true);
    final bubbleSize = bubbleChild.size;
    final double bubbleWidth = bubbleSize.width;
    var previewHeight = 0.0;
    var senderLabelHeight = 0.0;
    var senderLabelWidth = 0.0;
    if (senderLabelChild != null) {
      senderLabelChild.layout(
        constraints.loosen(),
        parentUsesSize: true,
      );
      senderLabelHeight = senderLabelChild.size.height;
      senderLabelWidth = senderLabelChild.size.width;
    }
    final layoutWidth = math.max(bubbleWidth, senderLabelWidth);
    if (senderLabelChild != null) {
      final senderLabelParentData =
          senderLabelChild.parentData as _ReplyPreviewBubbleParentData;
      senderLabelParentData.offset = Offset(
        alignEnd ? layoutWidth - senderLabelWidth : 0,
        0,
      );
    }
    if (previewChild != null) {
      previewChild.layout(
        BoxConstraints.tightFor(width: bubbleWidth),
        parentUsesSize: true,
      );
      previewHeight = previewChild.size.height + spacing;
      final previewParentData =
          previewChild.parentData as _ReplyPreviewBubbleParentData;
      previewParentData.offset = Offset(
        alignEnd ? layoutWidth - bubbleWidth : 0,
        senderLabelHeight,
      );
    }
    final bubbleParentData =
        bubbleChild.parentData as _ReplyPreviewBubbleParentData;
    bubbleParentData.offset = Offset(
      alignEnd ? layoutWidth - bubbleWidth : 0,
      previewHeight + senderLabelHeight,
    );
    size = constraints.constrain(
      Size(
        layoutWidth,
        bubbleSize.height + previewHeight + senderLabelHeight,
      ),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
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
            child: Builder(
              builder: (context) {
                final split = ChatSubjectCodec.splitXmppBody(message.body);
                final subject = split.subject?.trim();
                final body = split.body.trim();
                final previewParts = <String>[];
                if (subject?.isNotEmpty == true) {
                  previewParts.add(subject!);
                }
                if (body.isNotEmpty) {
                  previewParts.add(body);
                }
                final previewText = previewParts.isNotEmpty
                    ? previewParts.join(' — ')
                    : context.l10n.chatQuotedNoContent;
                final quotedPreview = '"$previewText"';
                return _ReplyingToPreviewText(
                  senderLabel:
                      isSelf ? context.l10n.chatSenderYou : message.senderJid,
                  quotedPreview: quotedPreview,
                  isSelf: isSelf,
                );
              },
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

class _ParsedMessageBody extends StatefulWidget {
  const _ParsedMessageBody({
    required this.text,
    required this.baseStyle,
    required this.linkStyle,
    required this.details,
    required this.onLinkTap,
    this.onLinkLongPress,
    this.contentKey,
  });

  final String text;
  final TextStyle baseStyle;
  final TextStyle linkStyle;
  final List<InlineSpan> details;
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
    final linkLongPress = widget.onLinkLongPress ?? widget.onLinkTap;
    final textKey =
        widget.contentKey == null ? null : ValueKey(widget.contentKey);
    return DynamicInlineText(
      key: textKey,
      text: _parsed.body,
      details: widget.details,
      links: _parsed.links,
      onLinkTap: widget.onLinkTap,
      onLinkLongPress: linkLongPress,
    );
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
    this.onLoadRequested,
    this.onTap,
  });

  final String html;
  final TextStyle textStyle;
  final Color textColor;
  final Color linkColor;
  final bool shouldLoadImages;
  final ValueChanged<String> onLinkTap;
  final VoidCallback? onLoadRequested;
  final VoidCallback? onTap;

  @override
  State<_MessageHtmlBody> createState() => _MessageHtmlBodyState();
}

class _MessageHtmlBodyState extends State<_MessageHtmlBody> {
  String? _sanitizedHtml;
  String? _rawHtml;

  @override
  void initState() {
    super.initState();
    _refreshSanitizedHtml();
  }

  @override
  void didUpdateWidget(covariant _MessageHtmlBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _refreshSanitizedHtml();
    }
  }

  void _refreshSanitizedHtml() {
    _rawHtml = widget.html;
    _sanitizedHtml = HtmlContentCodec.sanitizeHtml(widget.html);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final fallbackFontSize = widget.textStyle.fontSize ??
        textTheme.p.fontSize ??
        textTheme.small.fontSize ??
        context.sizing.menuItemIconSize;
    final htmlBody = html_widget.Html(
      data: _sanitizedHtml ?? _rawHtml ?? '',
      extensions: [
        createEmailImageExtension(
          shouldLoad: widget.shouldLoadImages,
          onLoadRequested: widget.onLoadRequested,
        ),
      ],
      style: {
        'body': html_widget.Style(
          margin: html_widget.Margins.zero,
          padding: html_widget.HtmlPaddings.zero,
          color: widget.textColor,
          fontSize: html_widget.FontSize(fallbackFontSize),
        ),
        'a': html_widget.Style(
          color: widget.linkColor,
          textDecoration: TextDecoration.underline,
        ),
      },
      onLinkTap: (url, _, __) {
        if (url == null) return;
        widget.onLinkTap(url);
      },
    );
    final onTap = widget.onTap;
    if (onTap == null) {
      return htmlBody;
    }
    final shape = RoundedSuperellipseBorder(borderRadius: context.radius);
    return ShadFocusable(
      canRequestFocus: true,
      builder: (context, focused, child) => child ?? const SizedBox.shrink(),
      child: ShadGestureDetector(
        cursor: SystemMouseCursors.click,
        hoverStrategies: mobileHoverStrategies,
        onTap: onTap,
        child: AxiTapBounce(
          enabled: true,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: Colors.transparent,
              shape: shape,
            ),
            child: htmlBody,
          ),
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
  bool get _composerHasContent => _composerHasText;

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
      ];

  List<ChatMessage> _scriptMessagesForLocale(AppLocalizations l10n) {
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
    final size = MediaQuery.sizeOf(context);
    final isDesktopWidth = size.width >= smallScreen;
    final guestHorizontalPadding = isDesktopWidth
        ? _guestDesktopHorizontalPadding
        : _chatHorizontalPadding;
    final colors = context.colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(left: BorderSide(color: colors.border)),
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
                    canSend: _composerHasContent,
                    attachmentsEnabled: false,
                  ),
                  sendEnabled: _composerHasContent,
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
    final baseTitleStyle = context.textTheme.h4;
    final titleStyle = baseTitleStyle.copyWith(
      fontSize: context.textTheme.large.fontSize,
    );
    final title =
        contact.firstName?.isNotEmpty == true ? contact.firstName! : contact.id;
    return SizedBox(
      height: kToolbarHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          border: Border(bottom: context.borderSide),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            children: [
              _GuestChatAppIconAvatar(
                size: context.sizing.iconButtonSize,
              ),
              SizedBox(width: spacing),
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

class _GuestChatAppIconAvatar extends StatelessWidget {
  const _GuestChatAppIconAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    const String guestChatAppIconAssetPath = 'assets/icons/app_icon_source.png';
    final shape = SquircleBorder(cornerRadius: context.radii.squircle);
    return SizedBox.square(
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: Image.asset(
          guestChatAppIconAssetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
        ),
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
    final bubbleBaseRadius = context.radius;
    final bubbleCornerClearance = _bubbleCornerClearance(bubbleBaseRadius);
    final statusIcon = message.status?.icon;
    final timeLabel =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';
    final inlineText = DynamicInlineText(
      key: ValueKey(message.createdAt.microsecondsSinceEpoch),
      text: TextSpan(
        text: message.text,
        style: context.textTheme.small.copyWith(color: textColor, height: 1.3),
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
        baseRadius: bubbleBaseRadius,
        isSelf: isSelf,
        chainedPrevious: chainedPrev,
        chainedNext: chainedNext,
      ),
      shadowOpacity: 0,
      shadows: _selectedBubbleShadows(colors.primary),
      bubbleWidthFraction: _cutoutMaxWidthFraction,
      cornerClearance: bubbleCornerClearance,
      body: Padding(
        padding: _bubblePadding(context),
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
            leftInset: 0.0,
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
    final crossAxis =
        isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final secondaryLabel = this.secondaryLabel?.trim();
    final primaryStyle = context.textTheme.small.copyWith(
      color: colors.mutedForeground,
      fontWeight: FontWeight.w600,
    );
    final secondaryStyle = context.textTheme.muted.copyWith(
      color: colors.mutedForeground,
    );
    return Padding(
      padding: EdgeInsets.only(
        bottom: spacing.xs + spacing.xxs,
        left: leftInset,
      ),
      child: Column(
        spacing: spacing.xxs,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxis,
        children: [
          Text(primaryLabel, style: primaryStyle, textAlign: textAlign),
          if (secondaryLabel != null && secondaryLabel.isNotEmpty)
            Text(
              secondaryLabel,
              style: secondaryStyle,
              textAlign: textAlign,
            ),
        ],
      ),
    );
  }
}

class _ChatMessageList extends StatefulWidget {
  const _ChatMessageList({
    required this.currentUser,
    required this.messages,
    required this.messageOptions,
    required this.messageListOptions,
    required this.quickReplyOptions,
    required this.scrollToBottomOptions,
    this.typingUsers,
    this.readOnly = false,
  });

  final ChatUser currentUser;
  final List<ChatMessage> messages;
  final MessageOptions messageOptions;
  final MessageListOptions messageListOptions;
  final QuickReplyOptions quickReplyOptions;
  final ScrollToBottomOptions scrollToBottomOptions;
  final List<ChatUser>? typingUsers;
  final bool readOnly;

  @override
  State<_ChatMessageList> createState() => _ChatMessageListState();
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
    final messages = widget.messages;
    final messageOptions = widget.messageOptions;
    final messageListOptions = widget.messageListOptions;
    final quickReplyOptions = widget.quickReplyOptions;
    final scrollToBottomOptions = widget.scrollToBottomOptions;
    final typingUsers = widget.typingUsers;
    const double loadEarlierTopInset = 8.0;
    final shouldShowLoadEarlierSpinner = _isLoadingMore &&
        (_loadEarlierStartingCount == null ||
            messages.length <= _loadEarlierStartingCount!);
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView.builder(
                physics: messageListOptions.scrollPhysics,
                padding: widget.readOnly ? null : EdgeInsets.zero,
                controller: _scrollController,
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final ChatMessage? previousMessage =
                      index < messages.length - 1 ? messages[index + 1] : null;
                  final ChatMessage? nextMessage =
                      index > 0 ? messages[index - 1] : null;
                  final message = messages[index];
                  final isAfterDateSeparator = _shouldShowDateSeparator(
                    previousMessage,
                    message,
                    messageListOptions,
                  );
                  var isBeforeDateSeparator = false;
                  if (nextMessage != null) {
                    isBeforeDateSeparator = _shouldShowDateSeparator(
                      message,
                      nextMessage,
                      messageListOptions,
                    );
                  }
                  return Column(
                    children: [
                      if (isAfterDateSeparator)
                        messageListOptions.dateSeparatorBuilder != null
                            ? messageListOptions.dateSeparatorBuilder!(
                                message.createdAt,
                              )
                            : DefaultDateSeparator(
                                date: message.createdAt,
                                messageListOptions: messageListOptions,
                              ),
                      if (messageOptions.messageRowBuilder != null)
                        messageOptions.messageRowBuilder!(
                          message,
                          previousMessage,
                          nextMessage,
                          isAfterDateSeparator,
                          isBeforeDateSeparator,
                        )
                      else
                        MessageRow(
                          message: message,
                          nextMessage: nextMessage,
                          previousMessage: previousMessage,
                          currentUser: widget.currentUser,
                          isAfterDateSeparator: isAfterDateSeparator,
                          isBeforeDateSeparator: isBeforeDateSeparator,
                          messageOptions: messageOptions,
                        ),
                    ],
                  );
                },
              ),
            ),
            if (typingUsers != null && typingUsers.isNotEmpty)
              ...typingUsers.map((user) {
                if (messageListOptions.typingBuilder != null) {
                  return messageListOptions.typingBuilder!(user);
                }
                return DefaultTypingBuilder(user: user);
              }),
            if (messageListOptions.showFooterBeforeQuickReplies &&
                messageListOptions.chatFooterBuilder != null)
              messageListOptions.chatFooterBuilder!,
            if (messages.isNotEmpty &&
                messages.first.quickReplies != null &&
                messages.first.quickReplies!.isNotEmpty &&
                messages.first.user.id != widget.currentUser.id)
              QuickReplies(
                quickReplies: messages.first.quickReplies!,
                quickReplyOptions: quickReplyOptions,
              ),
            if (!messageListOptions.showFooterBeforeQuickReplies &&
                messageListOptions.chatFooterBuilder != null)
              messageListOptions.chatFooterBuilder!,
          ],
        ),
        if (shouldShowLoadEarlierSpinner)
          Positioned(
            top: loadEarlierTopInset,
            right: 0,
            left: 0,
            child: messageListOptions.loadEarlierBuilder ??
                const Center(
                  child: SizedBox(
                    child: CircularProgressIndicator(),
                  ),
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

  bool _shouldShowDateSeparator(
    ChatMessage? previousMessage,
    ChatMessage message,
    MessageListOptions messageListOptions,
  ) {
    if (!messageListOptions.showDateSeparator) {
      return false;
    }
    if (previousMessage == null) {
      return true;
    }
    switch (messageListOptions.separatorFrequency) {
      case SeparatorFrequency.days:
        final previousDate = DateTime(
          previousMessage.createdAt.year,
          previousMessage.createdAt.month,
          previousMessage.createdAt.day,
        );
        final messageDate = DateTime(
          message.createdAt.year,
          message.createdAt.month,
          message.createdAt.day,
        );
        return previousDate.difference(messageDate).inDays.abs() > 0;
      case SeparatorFrequency.hours:
        final previousDate = DateTime(
          previousMessage.createdAt.year,
          previousMessage.createdAt.month,
          previousMessage.createdAt.day,
          previousMessage.createdAt.hour,
        );
        final messageDate = DateTime(
          message.createdAt.year,
          message.createdAt.month,
          message.createdAt.day,
          message.createdAt.hour,
        );
        return previousDate.difference(messageDate).inHours.abs() > 0;
    }
  }

  Future<void> _handleScroll() async {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange &&
        widget.messageListOptions.onLoadEarlier != null &&
        !_isLoadingMore) {
      setState(() {
        _isLoadingMore = true;
        _loadEarlierStartingCount = widget.messages.length;
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

class _ForwardRecipientSheet extends StatefulWidget {
  const _ForwardRecipientSheet({
    required this.availableChats,
  });

  final List<chat_models.Chat> availableChats;

  @override
  State<_ForwardRecipientSheet> createState() => _ForwardRecipientSheetState();
}

class _ForwardRecipientSheetState extends State<_ForwardRecipientSheet> {
  List<ComposerRecipient> _recipients = const [];

  chat_models.Chat? get _selectedChat {
    for (final recipient in _recipients) {
      final chat = recipient.target.chat;
      if (recipient.included && chat != null) {
        return chat;
      }
    }
    return null;
  }

  bool get _canSend => _selectedChat != null;

  void _handleRecipientAdded(FanOutTarget target) {
    final chat_models.Chat? chat = target.chat;
    if (chat == null) return;
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
            (recipient) => recipient.key == key
                ? recipient.copyWith(included: !recipient.included)
                : recipient,
          )
          .toList(growable: false);
    });
  }

  void _handleSend() {
    final chat_models.Chat? selected = _selectedChat;
    if (selected == null) return;
    Navigator.of(context).pop(selected);
  }

  Future<void> _handleClose() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) return;
    Navigator.of(context).maybePop();
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
    final resolvedProfileJid = profileJid.trim();
    final String? selfJid =
        resolvedProfileJid.isNotEmpty ? resolvedProfileJid : null;
    final selfIdentity = SelfIdentitySnapshot(
      selfJid: selfJid,
      avatarPath: context.watch<ProfileCubit>().state.avatarPath,
    );
    final header = AxiSheetHeader(
      title: Text(l10n.chatForwardDialogTitle),
      onClose: _handleClose,
    );
    return AxiSheetScaffold.scroll(
      header: header,
      bodyPadding: EdgeInsets.zero,
      children: [
        RecipientChipsBar(
          recipients: _recipients,
          availableChats: widget.availableChats,
          rosterItems:
              context.watch<RosterCubit>().state.items ?? const <RosterItem>[],
          recipientSuggestionsStream:
              locate<ChatsCubit>().recipientAddressSuggestionsStream(),
          selfJid: locate<ChatsCubit>().selfJid,
          selfIdentity: selfIdentity,
          latestStatuses: const {},
          collapsedByDefault: false,
          allowAddressTargets: false,
          showSuggestionsWhenEmpty: true,
          horizontalPadding: 0,
          onRecipientAdded: _handleRecipientAdded,
          onRecipientRemoved: _handleRecipientRemoved,
          onRecipientToggled: _handleRecipientToggled,
        ),
        SizedBox(height: sectionSpacing),
        Padding(
          padding: contentPadding,
          child: Align(
            alignment: Alignment.centerRight,
            child: AxiButton.primary(
              onPressed: _canSend ? _handleSend : null,
              leading: Icon(LucideIcons.send, size: iconSize),
              child: Text(l10n.commonSend),
            ),
          ),
        ),
        SizedBox(height: sectionSpacing),
      ],
    );
  }
}
