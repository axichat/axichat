import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/location_autocomplete.dart';
import 'package:axichat/src/calendar/utils/task_share_formatter.dart';
import 'package:axichat/src/calendar/view/models/calendar_drag_payload.dart';
import 'package:axichat/src/calendar/view/quick_add_modal.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/bloc/chat_search_cubit.dart';
import 'package:axichat/src/chat/models/pending_attachment.dart';
import 'package:axichat/src/chat/util/chat_subject_codec.dart';
import 'package:axichat/src/chat/view/chat_alert.dart';
import 'package:axichat/src/chat/view/chat_attachment_preview.dart';
import 'package:axichat/src/chat/view/chat_bubble_surface.dart';
import 'package:axichat/src/chat/view/chat_cutout_composer.dart';
import 'package:axichat/src/chat/view/chat_message_details.dart';
import 'package:axichat/src/chat/view/message_text_parser.dart';
import 'package:axichat/src/chat/view/pending_attachment_list.dart';
import 'package:axichat/src/chat/view/recipient_chips_bar.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/widgets/contact_rename_dialog.dart';
import 'package:axichat/src/chats/view/widgets/selection_panel_shell.dart';
import 'package:axichat/src/chats/view/widgets/transport_aware_avatar.dart';
import 'package:axichat/src/common/bool_tool.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/policy.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/context_action_button.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
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
import 'package:flutter/rendering.dart' show PipelineOwner, RenderProxyBox;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mime/mime.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
  details,
}

const _bubblePadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
const _bubbleRadius = 18.0;
const _reactionBubbleInset = 12.0;
const _reactionCutoutDepth = 14.0;
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
const _chatHorizontalPadding = 16.0;
const _selectionAutoscrollSlop = 4.0;
const _selectionAutoscrollReboundCurve = Curves.easeOutCubic;
const _selectionAutoscrollReboundDuration = Duration(milliseconds: 260);
const _selectionAttachmentBaseGap = 16.0;
const _selectionAttachmentSelectedGap = 8.0;
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
const _typingIndicatorMaxAvatars = 7;
const _typingAvatarBorderWidth = 1.6;
const _typingAvatarSpacing = 4.0;

class _MessageFilterOption {
  const _MessageFilterOption(this.filter, this.label);

  final MessageTimelineFilter filter;
  final String label;
}

List<_MessageFilterOption> _messageFilterOptions(AppLocalizations l10n) => [
      _MessageFilterOption(
        MessageTimelineFilter.directOnly,
        l10n.chatFilterDirectOnly,
      ),
      _MessageFilterOption(
        MessageTimelineFilter.allWithContact,
        l10n.chatFilterAllWithContact,
      ),
    ];

String _sortLabel(SearchSortOrder order, AppLocalizations l10n) =>
    switch (order) {
      SearchSortOrder.newestFirst => l10n.chatSearchSortNewestFirst,
      SearchSortOrder.oldestFirst => l10n.chatSearchSortOldestFirst,
    };

class _ChatSearchToggleButton extends StatelessWidget {
  const _ChatSearchToggleButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatSearchCubit, ChatSearchState>(
      builder: (context, state) {
        final l10n = context.l10n;
        return AxiIconButton(
          iconData: state.active ? LucideIcons.x : LucideIcons.search,
          tooltip:
              state.active ? l10n.chatSearchClose : l10n.chatSearchMessages,
          onPressed: () => context.read<ChatSearchCubit>().toggleActive(),
        );
      },
    );
  }
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
        return AnimatedCrossFade(
          duration: context.watch<SettingsCubit>().animationDuration,
          reverseDuration: context.watch<SettingsCubit>().animationDuration,
          sizeCurve: Curves.easeInOutCubic,
          crossFadeState: state.active
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
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
                      child: ShadInput(
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
          ),
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
  final _approvedAttachmentSenders = <String>{};
  final _fileMetadataStreamEntries = <String, _FileMetadataStreamEntry>{};
  final _animatedMessageIds = <String>{};
  var _hydratedAnimatedMessages = false;
  var _chatOpenedAt = DateTime.now();
  static final Map<String, double> _scrollOffsetCache = {};
  String? _lastScrollStorageKey;

  var _chatRoute = _ChatRoute.main;
  var _settingsPanelExpanded = false;
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
  bool _selectionAutoscrollActive = false;
  bool _selectionAutoscrollScheduled = false;
  bool _selectionAutoscrollInProgress = false;
  double _selectionAutoscrollAccumulated = 0.0;
  bool _selectionControlsMeasurementPending = false;
  var _sendingAttachment = false;
  Offset? _selectionDismissOrigin;
  int? _selectionDismissPointer;
  var _selectionDismissMoved = false;

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
    if (!context.read<SettingsCubit>().state.indicateTyping) return;
    if (!hasText) return;
    context.read<ChatBloc>().add(const ChatTypingStarted());
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

  void _appendTaskShareText(CalendarTask task) {
    final String shareText = task.toShareText();
    final String existing = _textController.text;
    final String separator = existing.trim().isEmpty ? '' : '\n\n';
    final String nextText = '$existing$separator$shareText';
    _textController.value = _textController.value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
      composing: TextRange.empty,
    );
    _focusNode.requestFocus();
  }

  void _handleTaskDrop(CalendarDragPayload payload) {
    _appendTaskShareText(payload.snapshot);
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
    final jid = context.read<ChatBloc>().jid;
    final suffix = jid == null || jid.isEmpty ? 'unknown' : jid;
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

  bool _isQuotedMessageFromSelf({
    required Message quotedMessage,
    required bool isGroupChat,
    required String? myOccupantId,
    required String? currentUserId,
  }) {
    if (isGroupChat && myOccupantId != null) {
      if (quotedMessage.senderJid == myOccupantId) {
        return true;
      }
      final quotedOccupantId = quotedMessage.occupantID;
      if (quotedOccupantId != null && quotedOccupantId.isNotEmpty) {
        return quotedOccupantId == myOccupantId;
      }
    }
    return _bareJid(quotedMessage.senderJid) == _bareJid(currentUserId);
  }

  void _toggleSettingsPanel() {
    final nextExpanded = !_settingsPanelExpanded;
    if (nextExpanded) {
      context.read<ChatSearchCubit?>()?.setActive(false);
    }
    setState(() {
      _settingsPanelExpanded = nextExpanded;
    });
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
    final jid = context.read<ChatBloc>().state.chat?.jid;
    if (context.read<ChatBloc>().state.chat == null || jid == null) return;
    final xmppService = context.read<XmppService>();
    final emailService = RepositoryProvider.of<EmailService?>(context);
    final l10n = context.l10n;
    try {
      await xmppService.toggleChatSpam(jid: jid, spam: sendToSpam);
      if (!mounted) return;
      final address = context.read<ChatBloc>().state.chat?.emailAddress?.trim();
      if (context.read<ChatBloc>().state.chat?.transport.isEmail == true &&
          address?.isNotEmpty == true) {
        if (sendToSpam) {
          await emailService?.spam.mark(address!);
        } else {
          await emailService?.spam.unmark(address!);
        }
      }
    } on Exception {
      if (mounted) {
        _showSnackbar(l10n.chatSpamUpdateFailed);
      }
      return;
    }
    if (!mounted) return;
    final contactName = context.read<ChatBloc>().state.chat!.displayName;
    final toastMessage = sendToSpam
        ? l10n.chatSpamSent(contactName)
        : l10n.chatSpamRestored(contactName);
    ShadToaster.maybeOf(context)?.show(
      FeedbackToast.info(
        title: sendToSpam
            ? l10n.chatSpamReportedTitle
            : l10n.chatSpamRestoredTitle,
        message: toastMessage,
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

  bool _shouldAllowAttachment({
    required String senderJid,
    required bool isSelf,
    required Set<String> knownContacts,
    required bool isEmailChat,
  }) {
    if (isSelf) return true;
    if (isEmailChat) return true;
    if (_approvedAttachmentSenders.contains(senderJid)) return true;
    if (knownContacts.contains(senderJid)) return true;
    return false;
  }

  Future<void> _approveAttachment({
    required String senderJid,
    String? senderEmail,
  }) async {
    if (!mounted) return;
    final l10n = context.l10n;
    final displaySender =
        senderEmail?.isNotEmpty == true ? senderEmail! : senderJid;
    final confirmed = await confirm(
      context,
      title: l10n.chatAttachmentConfirmTitle,
      message: l10n.chatAttachmentConfirmMessage(displaySender),
      confirmLabel: l10n.chatAttachmentConfirmButton,
      destructiveConfirm: false,
    );
    if (confirmed == true && mounted) {
      setState(() {
        _approvedAttachmentSenders.add(senderJid);
      });
    }
  }

  Future<void> _handleLinkTap(String url) async {
    if (!mounted) return;
    final l10n = context.l10n;
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    final host = uri?.host.isNotEmpty == true ? uri!.host : trimmed;
    final approved = await confirm(
      context,
      title: l10n.chatOpenLinkTitle,
      message: l10n.chatOpenLinkMessage(trimmed, host),
      confirmLabel: l10n.chatOpenLinkConfirm,
      destructiveConfirm: false,
    );
    if (approved != true) return;
    if (uri == null) {
      _showSnackbar(l10n.chatInvalidLink(trimmed));
      return;
    }
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      _showSnackbar(l10n.chatUnableToOpenHost(host));
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

  void _handleSendMessage() {
    final text = _textController.text.trim();
    final bool hasPreparingAttachments =
        context.read<ChatBloc>().state.pendingAttachments.any(
              (attachment) => attachment.isPreparing,
            );
    final bool hasQueuedAttachments =
        context.read<ChatBloc>().state.pendingAttachments.any(
              (attachment) =>
                  attachment.status == PendingAttachmentStatus.queued,
            );
    final hasSubject = _subjectController.text.trim().isNotEmpty;
    final canSend = !hasPreparingAttachments &&
        (text.isNotEmpty || hasQueuedAttachments || hasSubject);
    if (!canSend) return;
    context.read<ChatBloc>().add(ChatMessageSent(text: text));
    if (text.isNotEmpty) {
      _textController.clear();
    }
    _focusNode.requestFocus();
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
            title: const Text('Actions'),
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
        allowMultiple: false,
        withReadStream: false,
      );
      if (result == null || result.files.isEmpty || !mounted) {
        return;
      }
      final file = result.files.single;
      final path = file.path;
      if (path == null) {
        _showSnackbar(l10n.chatAttachmentInaccessible);
        return;
      }
      final size = file.size > 0 ? file.size : await File(path).length();
      final mimeType = lookupMimeType(file.name) ?? lookupMimeType(path);
      final caption = _textController.text.trim();
      final attachment = EmailAttachment(
        path: path,
        fileName: file.name.isNotEmpty ? file.name : path.split('/').last,
        sizeBytes: size,
        mimeType: mimeType,
        caption: caption.isEmpty ? null : caption,
      );
      if (!mounted) return;
      context.read<ChatBloc>().add(ChatAttachmentPicked(attachment));
      if (caption.isNotEmpty) {
        _textController.clear();
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
      return;
    }
    if (_lastScrollStorageKey != currentKey) {
      _persistScrollOffset(key: _lastScrollStorageKey);
      _lastScrollStorageKey = currentKey;
      _restoreScrollOffsetForCurrentChat();
    }
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
        if (searchState.active && _settingsPanelExpanded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_settingsPanelExpanded) return;
            setState(() {
              _settingsPanelExpanded = false;
            });
          });
        }
        final showToast = ShadToaster.maybeOf(context)?.show;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) => _maybeDismissSelection(details.globalPosition),
          child: MultiBlocListener(
            listeners: [
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
                final profile = context.watch<ProfileCubit?>()?.state;
                final readOnly = widget.readOnly;
                final emailService = RepositoryProvider.of<EmailService?>(
                  context,
                  listen: false,
                );
                final emailSelfJid = emailService?.selfSenderJid;
                final chatEntity = state.chat;
                final jid = chatEntity?.jid;
                final isDefaultEmail =
                    chatEntity?.defaultTransport.isEmail ?? false;
                final currentUserId = isDefaultEmail
                    ? (emailSelfJid ?? profile?.jid ?? '')
                    : (profile?.jid ?? emailSelfJid ?? '');
                final myOccupantId = state.roomState?.myOccupantId;
                final myOccupant = myOccupantId == null
                    ? null
                    : state.roomState?.occupants[myOccupantId];
                final shareContexts = state.shareContexts;
                final shareReplies = state.shareReplies;
                final recipients = state.recipients;
                final pendingAttachments = state.pendingAttachments;
                final latestStatuses = _latestRecipientStatuses(state);
                final fanOutReports = state.fanOutReports;
                final warningEntry = fanOutReports.entries.isEmpty
                    ? null
                    : fanOutReports.entries.last;
                final showAttachmentWarning =
                    warningEntry?.value.attachmentWarning ?? false;
                final chatsState = context.watch<ChatsCubit?>()?.state;
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
                    in chatsState?.items ?? const <chat_models.Chat>[]) {
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

                final retryEntry = _lastReportEntryWhere(
                  fanOutReports.entries,
                  (entry) => entry.value.hasFailures,
                );
                final retryReport = retryEntry?.value;
                final retryShareId = retryEntry?.key;
                final availableChats =
                    (chatsState?.items ?? const <chat_models.Chat>[])
                        .where((chat) => chat.jid != chatEntity?.jid)
                        .toList();
                final openStack = chatsState?.openStack ?? const <String>[];
                final forwardStack =
                    chatsState?.forwardStack ?? const <String>[];
                bool prepareChatExit() {
                  if (_chatRoute != _ChatRoute.main) {
                    context
                        .read<ChatBloc>()
                        .add(const ChatMessageFocused(null));
                    setState(() {
                      _chatRoute = _ChatRoute.main;
                      _settingsPanelExpanded = false;
                    });
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
                  if (_settingsPanelExpanded) {
                    setState(() {
                      _settingsPanelExpanded = false;
                    });
                  }
                  return true;
                }

                final isGroupChat = chatEntity?.type == ChatType.groupChat;
                final selfUserId = isGroupChat && myOccupantId != null
                    ? myOccupantId
                    : currentUserId;
                final user = ChatUser(
                  id: selfUserId,
                  firstName: (isGroupChat ? myOccupant?.nick : null) ??
                      profile?.username ??
                      '',
                );
                final spacerUser = ChatUser(
                  id: _selectionSpacerMessageId,
                  firstName: '',
                );
                final showSettingsPanel = _settingsPanelExpanded &&
                    !readOnly &&
                    jid != null &&
                    _chatRoute == _ChatRoute.main;
                return Container(
                  decoration: BoxDecoration(
                    color: context.colorScheme.background,
                    border: Border(
                      left: BorderSide(color: context.colorScheme.border),
                    ),
                  ),
                  child: Scaffold(
                    backgroundColor: context.colorScheme.background,
                    appBar: AppBar(
                      scrolledUnderElevation: 0,
                      forceMaterialTransparency: true,
                      shape: Border(
                          bottom:
                              BorderSide(color: context.colorScheme.border)),
                      actionsPadding:
                          const EdgeInsets.symmetric(horizontal: 8.0),
                      leadingWidth: readOnly
                          ? 0
                          : ((AxiIconButton.kDefaultSize + 8) *
                                  ((openStack.length > 1 ? 1 : 0) +
                                      (forwardStack.isNotEmpty ? 1 : 0) +
                                      1)) +
                              12,
                      leading: readOnly
                          ? null
                          : Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: AxiIconButton.kDefaultSize,
                                      height: AxiIconButton.kDefaultSize,
                                      child: AxiIconButton(
                                        iconData: LucideIcons.x,
                                        tooltip: context.l10n.commonClose,
                                        color: context.colorScheme.foreground,
                                        borderColor: context.colorScheme.border,
                                        onPressed: () {
                                          if (!prepareChatExit()) return;
                                          unawaited(
                                            context
                                                .read<ChatsCubit>()
                                                .closeAllChats(),
                                          );
                                        },
                                      ),
                                    ),
                                    if ((openStack.length > 1 ||
                                            forwardStack.isNotEmpty) &&
                                        !readOnly)
                                      const SizedBox(width: 8),
                                    if (openStack.length > 1)
                                      SizedBox(
                                        width: AxiIconButton.kDefaultSize,
                                        height: AxiIconButton.kDefaultSize,
                                        child: AxiIconButton(
                                          iconData: LucideIcons.arrowLeft,
                                          tooltip: context.l10n.chatBack,
                                          color: context.colorScheme.foreground,
                                          borderColor:
                                              context.colorScheme.border,
                                          onPressed: () {
                                            if (!prepareChatExit()) return;
                                            unawaited(
                                              context
                                                  .read<ChatsCubit>()
                                                  .popChat(),
                                            );
                                          },
                                        ),
                                      ),
                                    if (openStack.length > 1 &&
                                        forwardStack.isNotEmpty)
                                      const SizedBox(width: 8),
                                    if (forwardStack.isNotEmpty)
                                      SizedBox(
                                        width: AxiIconButton.kDefaultSize,
                                        height: AxiIconButton.kDefaultSize,
                                        child: AxiIconButton(
                                          iconData: LucideIcons.arrowRight,
                                          tooltip:
                                              context.l10n.chatMessageOpenChat,
                                          color: context.colorScheme.foreground,
                                          borderColor:
                                              context.colorScheme.border,
                                          onPressed: () {
                                            if (!prepareChatExit()) return;
                                            unawaited(
                                              context
                                                  .read<ChatsCubit>()
                                                  .restoreChat(),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
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
                                final statusLabel = item?.status?.trim() ?? '';
                                final presence = item?.presence;
                                final subscription = item?.subscription;
                                const double minTitleWidth = 220;
                                const double maxTitleWidth = 420;
                                final double titleMaxWidth = MediaQuery.sizeOf(
                                      context,
                                    ).width *
                                    0.45;
                                final double clampedTitleWidth = titleMaxWidth
                                    .clamp(minTitleWidth, maxTitleWidth);
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
                                      size: 40,
                                      badgeOffset: const Offset(-6, -4),
                                      presence: presence,
                                      status: statusLabel,
                                      subscription: subscription,
                                    ),
                                    const SizedBox(width: 8),
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
                                                      child:
                                                          ShadIconButton.ghost(
                                                        onPressed:
                                                            _promptContactRename,
                                                        icon: Icon(
                                                          LucideIcons
                                                              .pencilLine,
                                                          size: 18,
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
                                                overflow: TextOverflow.ellipsis,
                                                style: context.textTheme.muted,
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
                        if (jid != null && _chatRoute == _ChatRoute.main) ...[
                          if (isGroupChat)
                            AxiIconButton(
                              iconData: LucideIcons.users,
                              tooltip: context.l10n.chatRoomMembers,
                              onPressed: _showMembers,
                            ),
                          const _ChatSearchToggleButton(),
                          if (!readOnly) ...[
                            const SizedBox(width: 4),
                            AxiIconButton(
                              iconData: showSettingsPanel
                                  ? LucideIcons.x
                                  : LucideIcons.settings,
                              tooltip: showSettingsPanel
                                  ? context.l10n.chatCloseSettings
                                  : context.l10n.chatSettings,
                              onPressed: _toggleSettingsPanel,
                            ),
                          ],
                        ] else
                          const SizedBox.shrink(),
                      ],
                    ),
                    body: Column(
                      children: [
                        _ChatSettingsPanel(
                          visible: showSettingsPanel,
                          child: _ChatSettingsButtons(
                            state: state,
                            onViewFilterChanged: _setViewFilter,
                            onToggleNotifications: _toggleNotifications,
                            onSpamToggle: (sendToSpam) =>
                                _handleSpamToggle(sendToSpam: sendToSpam),
                          ),
                        ),
                        const ChatAlert(),
                        const _ChatSearchPanel(),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: context
                                .watch<SettingsCubit>()
                                .animationDuration,
                            reverseDuration: context
                                .watch<SettingsCubit>()
                                .animationDuration,
                            switchInCurve: Curves.easeIn,
                            switchOutCurve: Curves.easeOut,
                            child: IndexedStack(
                              key: ValueKey(_chatRoute.index),
                              index: _chatRoute.index,
                              children: [
                                LayoutBuilder(
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
                                    final messageById = {
                                      for (final item in state.items)
                                        item.stanzaID: item,
                                    };
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
                                    final filteredItems = activeItems
                                        .where(
                                          (message) =>
                                              message.body != null ||
                                              message.error.isNotNone ||
                                              message.fileMetadataID
                                                      ?.isNotEmpty ==
                                                  true,
                                        )
                                        .toList();
                                    final isEmailChat =
                                        state.chat?.defaultTransport.isEmail ==
                                            true;
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
                                              as String
                                    };
                                    for (var index = 0;
                                        index < filteredItems.length;
                                        index++) {
                                      final e = filteredItems[index];
                                      final senderBare = _bareJid(e.senderJid);
                                      final isSelfXmpp = senderBare != null &&
                                          senderBare == _bareJid(profile?.jid);
                                      final isSelfEmail = senderBare != null &&
                                          emailSelfJid != null &&
                                          senderBare == _bareJid(emailSelfJid);
                                      final isMucSelf = isGroupChat &&
                                          e.senderJid ==
                                              state.roomState?.myOccupantId;
                                      final isSelf = isSelfXmpp ||
                                          isSelfEmail ||
                                          isMucSelf;
                                      final occupantId = isGroupChat
                                          ? (isSelf ? user.id : e.senderJid)
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
                                      final author = ChatUser(
                                        id: isGroupChat
                                            ? occupantId!
                                            : (isSelf ? user.id : e.senderJid),
                                        firstName: isSelf
                                            ? user.firstName
                                            : (occupant?.nick ?? fallbackNick),
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
                                        if (e.acked) return MessageStatus.sent;
                                        return MessageStatus.pending;
                                      }

                                      final shouldReplaceInviteBody =
                                          isInvite || isInviteRevocation;
                                      final renderedText = shouldReplaceInviteBody
                                          ? inviteLabel
                                          : e.error.isNotNone
                                              ? '$errorLabel${bodyText.isNotEmpty ? ': "$bodyTextTrimmed"' : ''}'
                                              : displayedBody;
                                      dashMessages.add(
                                        ChatMessage(
                                          user: author,
                                          createdAt: e.timestamp!.toLocal(),
                                          text: renderedText,
                                          status: statusFor(e),
                                          customProperties: {
                                            'id': e.stanzaID,
                                            'body': bodyText,
                                            'fileMetadataID': e.fileMetadataID,
                                            'edited': e.edited,
                                            'retracted': e.retracted,
                                            'error': e.error,
                                            'encrypted':
                                                e.encryptionProtocol.isNotNone,
                                            'trust': e.trust,
                                            'trusted': e.trusted,
                                            'isSelf': isSelf,
                                            'model': e,
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
                                    return Column(
                                      children: [
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
                                                      showOtherUsersName: false,
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
                                                        final colors =
                                                            context.colorScheme;
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
                                                        final bannerParticipants =
                                                            (message.customProperties?[
                                                                        'shareParticipants']
                                                                    as List<
                                                                        chat_models
                                                                        .Chat>?) ??
                                                                const <chat_models
                                                                    .Chat>[];
                                                        final recipientCutoutParticipants =
                                                            bannerParticipants;
                                                        final extraStyle =
                                                            context
                                                                .textTheme.muted
                                                                .copyWith(
                                                          fontStyle:
                                                              FontStyle.italic,
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
                                                        final self =
                                                            message.customProperties?[
                                                                        'isSelf']
                                                                    as bool? ??
                                                                (message.user
                                                                        .id ==
                                                                    profile
                                                                        ?.jid);
                                                        final bubbleMaxWidth = self
                                                            ? outboundMessageRowMaxWidth
                                                            : inboundMessageRowMaxWidth;
                                                        final error =
                                                            message.customProperties?[
                                                                    'error']
                                                                as MessageError?;
                                                        final isError =
                                                            error?.isNotNone ??
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
                                                            context
                                                                .textTheme.small
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
                                                              : colors.primary,
                                                          decoration:
                                                              TextDecoration
                                                                  .underline,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        );
                                                        final parsedText =
                                                            parseMessageText(
                                                          text: message.text,
                                                          baseStyle:
                                                              baseTextStyle,
                                                          linkStyle: linkStyle,
                                                        );
                                                        final timeColor = isError
                                                            ? textColor
                                                            : self
                                                                ? colors.primaryForeground
                                                                : timestampColor;
                                                        final detailStyle =
                                                            context
                                                                .textTheme.muted
                                                                .copyWith(
                                                          color: timeColor,
                                                          fontSize: 11.0,
                                                          height: 1.0,
                                                          textBaseline:
                                                              TextBaseline
                                                                  .alphabetic,
                                                        );
                                                        final isEmailMessage = (message
                                                                        .customProperties?[
                                                                    'isEmailMessage']
                                                                as bool?) ??
                                                            ((message.customProperties?['id']
                                                                            as String?)
                                                                        case final id?
                                                                    ? messageById[id]
                                                                            ?.deltaMsgId !=
                                                                        null
                                                                    : false);
                                                        final transportIconData =
                                                            isEmailMessage
                                                                ? LucideIcons
                                                                    .mail
                                                                : LucideIcons
                                                                    .messageCircle;
                                                        TextSpan iconDetailSpan(
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
                                                                color: color,
                                                                fontFamily: icon
                                                                    .fontFamily,
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
                                                        final messageId = message
                                                            .customProperties?['id']
                                                            as String?;
                                                        final messageModel = (message
                                                                    .customProperties?[
                                                                'model'] as Message?) ??
                                                            (messageId == null
                                                                ? null
                                                                : messageById[
                                                                    messageId]);
                                                        if (messageModel == null) {
                                                          final fallbackText =
                                                              message.text.trim();
                                                          final resolvedFallback =
                                                              fallbackText.isNotEmpty
                                                                  ? fallbackText
                                                                  : l10n
                                                                      .chatAttachmentUnavailable;
                                                          return Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              horizontal:
                                                                  _chatHorizontalPadding,
                                                              vertical: 4,
                                                            ),
                                                            child: Align(
                                                              alignment: Alignment
                                                                  .centerLeft,
                                                              child: ConstrainedBox(
                                                                constraints:
                                                                    BoxConstraints(
                                                                  maxWidth:
                                                                      inboundMessageRowMaxWidth,
                                                                ),
                                                                child:
                                                                    DecoratedBox(
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: colors
                                                                        .card,
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(
                                                                      18,
                                                                    ),
                                                                    border: Border
                                                                        .all(
                                                                      color: chatTokens
                                                                          .recvEdge,
                                                                    ),
                                                                  ),
                                                                  child: Padding(
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          8,
                                                                    ),
                                                                    child: Text(
                                                                      resolvedFallback,
                                                                      style: context
                                                                          .textTheme
                                                                          .small,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        }
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
                                                        final quotedModel =
                                                            (message.customProperties?[
                                                                    'quoted']
                                                                as Message?) ??
                                                            (messageModel.quoting ==
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
                                                        final replyParticipants =
                                                            (message.customProperties?[
                                                                        'replyParticipants']
                                                                    as List<
                                                                        chat_models
                                                                        .Chat>?) ??
                                                                const <chat_models
                                                                    .Chat>[];
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
                                                              links: parsedText
                                                                  .links,
                                                              onLinkTap:
                                                                  _handleLinkTap,
                                                            ),
                                                          ]);
                                                        } else if (isInviteMessage ||
                                                            isInviteRevocationMessage) {
                                                          final inviteLabel =
                                                              (message.customProperties?[
                                                                          'inviteLabel']
                                                                      as String?) ??
                                                                  message.text;
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
                                                            ),
                                                          );
                                                          bubbleChildren.add(
                                                            const SizedBox(
                                                              height: 8,
                                                            ),
                                                          );
                                                          bubbleChildren.add(
                                                            _InviteActionCard(
                                                              enabled:
                                                                  !inviteRevoked &&
                                                                      !isInviteRevocationMessage,
                                                              backgroundColor:
                                                                  bubbleColor,
                                                              borderColor:
                                                                  colors.border,
                                                              foregroundColor:
                                                                  textColor,
                                                              mutedForegroundColor:
                                                                  timestampColor,
                                                              label: (message.customProperties?[
                                                                          'inviteActionLabel']
                                                                      as String?) ??
                                                                  'Join',
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
                                                              (message.customProperties?[
                                                                              'showSubject']
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
                                                              color: textColor,
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
                                                            bubbleChildren.add(
                                                              Text(
                                                                subjectText,
                                                                style:
                                                                    subjectStyle,
                                                              ),
                                                            );
                                                            bubbleChildren.add(
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
                                                          bubbleChildren.add(
                                                            DynamicInlineText(
                                                              key: ValueKey(
                                                                  bubbleContentKey),
                                                              text: parsedText
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
                                                              links: parsedText
                                                                  .links,
                                                              onLinkTap:
                                                                  _handleLinkTap,
                                                            ),
                                                          );
                                                          if (message.customProperties?[
                                                                  'retracted'] ??
                                                              false) {
                                                            bubbleChildren.add(
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
                                                            bubbleChildren.add(
                                                              Text(
                                                                l10n.chatMessageEdited,
                                                                style:
                                                                    extraStyle,
                                                              ),
                                                            );
                                                          }
                                                        }
                                                        final metadataId =
                                                            messageModel
                                                                .fileMetadataID;
                                                        if (metadataId !=
                                                                null &&
                                                            metadataId
                                                                .isNotEmpty) {
                                                          if (bubbleChildren
                                                              .isNotEmpty) {
                                                            bubbleChildren.add(
                                                              const SizedBox(
                                                                  height: 8),
                                                            );
                                                          }
                                                          final allowAttachment =
                                                              _shouldAllowAttachment(
                                                            senderJid:
                                                                messageModel
                                                                    .senderJid,
                                                            isSelf: self,
                                                            knownContacts: context
                                                                .watch<
                                                                    RosterCubit>()
                                                                .contacts,
                                                            isEmailChat:
                                                                isEmailChat,
                                                          );
                                                          bubbleChildren.add(
                                                            ChatAttachmentPreview(
                                                              stanzaId:
                                                                  messageModel
                                                                      .stanzaID,
                                                              metadataStream:
                                                                  _metadataStreamFor(
                                                                metadataId,
                                                              ),
                                                              initialMetadata:
                                                                  _metadataInitialFor(
                                                                metadataId,
                                                              ),
                                                              allowed:
                                                                  allowAttachment,
                                                              onAllowPressed:
                                                                  allowAttachment
                                                                      ? null
                                                                      : () =>
                                                                          _approveAttachment(
                                                                            senderJid:
                                                                                messageModel.senderJid,
                                                                            senderEmail:
                                                                                state.chat?.emailAddress,
                                                                          ),
                                                            ),
                                                          );
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
                                                              bubblePadding.add(
                                                            EdgeInsets.only(
                                                              bottom:
                                                                  bubbleBottomInset,
                                                            ),
                                                          );
                                                        }
                                                        if (selectionOverlay !=
                                                            null) {
                                                          bubblePadding =
                                                              bubblePadding.add(
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
                                                              bubblePadding.add(
                                                            const EdgeInsets
                                                                .symmetric(
                                                              vertical:
                                                                  _selectionBubbleVerticalInset,
                                                            ),
                                                          );
                                                        }
                                                        if (hasAvatarSlot) {
                                                          bubblePadding =
                                                              bubblePadding.add(
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
                                                            context.colorScheme
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
                                                                (next == null ||
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
                                                        double extraOuterLeft =
                                                            0;
                                                        double extraOuterRight =
                                                            0;
                                                        if (hasAvatarSlot) {
                                                          final occupantIdCandidate =
                                                              messageModel
                                                                  .occupantID
                                                                  ?.trim();
                                                          final occupantId =
                                                              occupantIdCandidate !=
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
                                                              occupant?.realJid
                                                                  ?.trim();
                                                          final bareRealJid =
                                                              realJid == null ||
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
                                                            offset: Offset.zero,
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
                                                          left:
                                                              _messageListHorizontalPadding +
                                                                  extraOuterLeft,
                                                          right:
                                                              _messageListHorizontalPadding +
                                                                  extraOuterRight,
                                                        );
                                                        final bubble =
                                                            TweenAnimationBuilder<
                                                                double>(
                                                          tween: Tween<double>(
                                                            begin: 0,
                                                            end: isSelected
                                                                ? 1.0
                                                                : 0.0,
                                                          ),
                                                          duration:
                                                              _bubbleFocusDuration,
                                                          curve:
                                                              _bubbleFocusCurve,
                                                          child: bubbleContent,
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
                                                        final baseAlignment =
                                                            self
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
                                                          child: shadowedBubble,
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
                                                        List<GlobalKey>?
                                                            actionButtonKeys;
                                                        if (isSingleSelection) {
                                                          const baseActionCount =
                                                              6;
                                                          final actionCount =
                                                              baseActionCount +
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
                                                              .read<ChatBloc>()
                                                              .add(
                                                                ChatQuoteRequested(
                                                                  messageModel,
                                                                ),
                                                              );
                                                          _focusNode
                                                              .requestFocus();
                                                          _clearAllSelections();
                                                        }

                                                        VoidCallback? onForward;
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
                                                        VoidCallback? onSelect;
                                                        if (includeSelectAction) {
                                                          onSelect = () =>
                                                              _startMultiSelect(
                                                                messageModel,
                                                              );
                                                        }
                                                        VoidCallback? onResend;
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
                                                            onRevokeInvite;
                                                        if (isInviteMessage &&
                                                            self) {
                                                          onRevokeInvite = () =>
                                                              context
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
                                                          onForward: onForward,
                                                          onCopy: onCopy,
                                                          onShare: onShare,
                                                          onAddToCalendar:
                                                              onAddToCalendar,
                                                          onDetails: onDetails,
                                                          onSelect: onSelect,
                                                          onResend: onResend,
                                                          onEdit: onEdit,
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
                                                                            padding:
                                                                                attachmentPadding,
                                                                            child:
                                                                                Column(
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
                                                          switchOutCurve: Curves
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
                                                              parent: animation,
                                                              curve:
                                                                  _bubbleFocusCurve,
                                                              reverseCurve: Curves
                                                                  .easeInCubic,
                                                            );
                                                            final slideAnimation =
                                                                Tween<Offset>(
                                                              begin:
                                                                  const Offset(
                                                                      0, -0.18),
                                                              end: Offset.zero,
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
                                                            child: attachments,
                                                          ),
                                                        );
                                                        final messageKey =
                                                            _messageKeys
                                                                .putIfAbsent(
                                                          messageModel.stanzaID,
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
                                                          child: bubbleDisplay,
                                                        );
                                                        final bubbleStack =
                                                            Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
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
                                                        final fullName = message
                                                            .user
                                                            .getFullName()
                                                            .trim();
                                                        final displayName = self
                                                            ? l10n.chatSenderYou
                                                            : (fullName.isEmpty
                                                                ? message
                                                                    .user.id
                                                                : fullName);
                                                        Widget bubbleWithSlack =
                                                            bubbleStack;
                                                        if (shouldShowSenderLabel &&
                                                            displayName
                                                                .isNotEmpty) {
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
                                                              Padding(
                                                                padding:
                                                                    EdgeInsets
                                                                        .only(
                                                                  bottom: 6,
                                                                  left: (!self &&
                                                                          hasAvatarSlot)
                                                                      ? _messageAvatarContentInset +
                                                                          _bubblePadding
                                                                              .left
                                                                      : 0,
                                                                ),
                                                                child: Text(
                                                                  displayName,
                                                                  style: context
                                                                      .textTheme
                                                                      .small
                                                                      .copyWith(
                                                                    color: colors
                                                                        .mutedForeground,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                  textAlign: self
                                                                      ? TextAlign
                                                                          .right
                                                                      : TextAlign
                                                                          .left,
                                                                ),
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
                                                        bubbleWithSlack = Align(
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
                                                              MainAxisSize.min,
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
                                                                : Curves.linear;
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
                                                          child: AnimatedAlign(
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
                                                if (_selectedMessageId != null)
                                                  Positioned.fill(
                                                    child: Listener(
                                                      behavior: HitTestBehavior
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
                                                      onPointerCancel: (event) {
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
                                                                event.pointer ||
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
                                                          if (!mounted) return;
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
                                        quoteSection,
                                        if (_multiSelectActive &&
                                            selectedMessages.isNotEmpty)
                                          () {
                                            final targets = List<Message>.of(
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
                                            return _ChatComposerSection(
                                              hintText: composerHintText,
                                              recipients: recipients,
                                              availableChats: availableChats,
                                              latestStatuses: latestStatuses,
                                              pendingAttachments:
                                                  pendingAttachments,
                                              composerHasText: _composerHasText,
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
                                              textController: _textController,
                                              textFocusNode: _focusNode,
                                              onSubjectSubmitted: () =>
                                                  _focusNode.requestFocus(),
                                              onRecipientAdded: (target) =>
                                                  context.read<ChatBloc>().add(
                                                        ChatComposerRecipientAdded(
                                                          target,
                                                        ),
                                                      ),
                                              onRecipientRemoved: (key) =>
                                                  context.read<ChatBloc>().add(
                                                        ChatComposerRecipientRemoved(
                                                          key,
                                                        ),
                                                      ),
                                              onRecipientToggled: (key) =>
                                                  context.read<ChatBloc>().add(
                                                        ChatComposerRecipientToggled(
                                                          key,
                                                        ),
                                                      ),
                                              onAttachmentRetry: (id) =>
                                                  context.read<ChatBloc>().add(
                                                        ChatAttachmentRetryRequested(
                                                          id,
                                                        ),
                                                      ),
                                              onAttachmentRemove: (id) =>
                                                  context.read<ChatBloc>().add(
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
                                              buildComposerAccessories:
                                                  ({required bool canSend}) =>
                                                      _composerAccessories(
                                                canSend: canSend,
                                                attachmentsEnabled: state
                                                    .supportsHttpFileUpload,
                                              ),
                                              onTaskDropped: _handleTaskDrop,
                                              onSend: _handleSendMessage,
                                            );
                                          }(),
                                      ],
                                    );
                                  },
                                ),
                                const ChatMessageDetails(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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

  Future<void> _handleForward(Message message) async {
    _clearAllSelections();
    final target = await _selectForwardTarget();
    if (!mounted || target == null) return;
    context.read<ChatBloc>().add(
          ChatMessageForwardRequested(
            message: message,
            target: target,
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
    final content = (model.body ?? dashMessage.text).trim();
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
    final copiedText = model.body ?? dashMessage.text;
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
    final seededText = (model.body ?? dashMessage.text).trim();
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
                startHour: task.startHour,
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
    final body = (message.body ?? '').trim();
    if (message.error.isNotNone) {
      final label = message.error.asString;
      return body.isEmpty ? label : '$label: "$body"';
    }
    return body;
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
    for (final message in candidates) {
      context.read<ChatBloc>().add(
            ChatMessageForwardRequested(
              message: message,
              target: target,
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
                startHour: task.startHour,
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
    setState(() {
      _chatRoute = _ChatRoute.details;
      _settingsPanelExpanded = false;
      if (_focusNode.hasFocus) {
        _focusNode.unfocus();
      }
    });
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

class _InviteActionCard extends StatelessWidget {
  const _InviteActionCard({
    required this.enabled,
    required this.backgroundColor,
    required this.borderColor,
    required this.foregroundColor,
    required this.mutedForegroundColor,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;
  final Color mutedForegroundColor;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const inviteActionTooltip = 'Accept invite';
    const horizontalPadding = 10.0;
    const verticalPadding = 8.0;
    const leadingSize = 34.0;
    const leadingIconSize = 18.0;
    const gap = 0.0;
    const actionGap = 32.0;
    const cornerRadius = 20.0;
    final resolvedTextColor = enabled ? foregroundColor : mutedForegroundColor;
    final actionBackground = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.1),
      backgroundColor,
    );
    return IntrinsicWidth(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: actionBackground,
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(cornerRadius),
            side: BorderSide(color: borderColor),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: leadingSize,
                height: leadingSize,
                child: Center(
                  child: Icon(
                    LucideIcons.userPlus,
                    size: leadingIconSize,
                    color: resolvedTextColor,
                  ),
                ),
              ),
              const SizedBox(width: gap),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: resolvedTextColor,
                ),
              ),
              const SizedBox(width: actionGap),
              AxiIconButton(
                iconData: LucideIcons.check,
                tooltip: inviteActionTooltip,
                onPressed: enabled ? onPressed : null,
                color: resolvedTextColor,
                backgroundColor: actionBackground,
                borderColor: borderColor,
                buttonSize: 34,
                tapTargetSize: 34,
                cornerRadius: 14,
              ),
            ],
          ),
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
                      header: subjectHeader,
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
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.sentences,
          cursorColor: colors.primary,
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
        icon: const Icon(LucideIcons.reply, size: 16),
        label: l10n.chatActionReply,
        onPressed: onReply,
      ),
      ContextActionButton(
        key: nextKey(),
        icon: Transform.scale(
          scaleX: -1,
          child: const Icon(LucideIcons.reply, size: 16),
        ),
        label: l10n.chatActionForward,
        onPressed: onForward,
      ),
      if (onResend != null)
        ContextActionButton(
          key: nextKey(),
          icon: const Icon(LucideIcons.repeat, size: 16),
          label: l10n.chatActionResend,
          onPressed: onResend!,
        ),
      if (onEdit != null)
        ContextActionButton(
          key: nextKey(),
          icon: const Icon(LucideIcons.pencilLine, size: 16),
          label: l10n.chatActionEdit,
          onPressed: onEdit!,
        ),
      if (onRevokeInvite != null)
        ContextActionButton(
          key: nextKey(),
          icon: const Icon(LucideIcons.ban, size: 16),
          label: l10n.chatActionRevoke,
          onPressed: onRevokeInvite!,
        ),
      ContextActionButton(
        key: nextKey(),
        icon: const Icon(LucideIcons.copy, size: 16),
        label: l10n.chatActionCopy,
        onPressed: onCopy,
      ),
      ContextActionButton(
        key: nextKey(),
        icon: const Icon(LucideIcons.share2, size: 16),
        label: l10n.chatActionShare,
        onPressed: onShare,
      ),
      ContextActionButton(
        key: nextKey(),
        icon: const Icon(LucideIcons.calendarPlus, size: 16),
        label: l10n.chatActionAddToCalendar,
        onPressed: onAddToCalendar,
      ),
      ContextActionButton(
        key: nextKey(),
        icon: const Icon(LucideIcons.info, size: 16),
        label: l10n.chatActionDetails,
        onPressed: onDetails,
      ),
    ];
    if (onSelect != null) {
      actions.add(
        ContextActionButton(
          key: nextKey(),
          icon: const Icon(LucideIcons.squareCheck, size: 16),
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
                              'Choose text to add',
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
                      ShadInput(
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

class _ChatSettingsPanel extends StatelessWidget {
  const _ChatSettingsPanel({
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final panel = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(
          bottom: BorderSide(color: colors.border),
        ),
      ),
      child: child,
    );
    return AnimatedCrossFade(
      duration: context.watch<SettingsCubit>().animationDuration,
      reverseDuration: context.watch<SettingsCubit>().animationDuration,
      sizeCurve: Curves.easeInOutCubic,
      crossFadeState:
          visible ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstChild: const SizedBox.shrink(),
      secondChild: panel,
    );
  }
}

class _ChatSettingsButtons extends StatelessWidget {
  const _ChatSettingsButtons({
    required this.state,
    required this.onViewFilterChanged,
    required this.onToggleNotifications,
    required this.onSpamToggle,
  });

  final ChatState state;
  final ValueChanged<MessageTimelineFilter> onViewFilterChanged;
  final ValueChanged<bool> onToggleNotifications;
  final ValueChanged<bool> onSpamToggle;

  @override
  Widget build(BuildContext context) {
    final chat = state.chat;
    if (chat == null) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final textScaler = MediaQuery.of(context).textScaler;
    final iconSize = textScaler.scale(16);
    final showDirectOnly = state.viewFilter == MessageTimelineFilter.directOnly;
    final notificationsEnabled = !chat.muted;
    final isSpamChat = chat.spam;
    final globalSignatureEnabled =
        context.watch<SettingsCubit>().state.shareTokenSignatureEnabled;
    final chatSignatureEnabled = chat.shareSignatureEnabled;
    final signatureActive = globalSignatureEnabled && chatSignatureEnabled;
    final signatureHint = globalSignatureEnabled
        ? l10n.chatSignatureHintEnabled
        : l10n.chatSignatureHintDisabled;
    final signatureWarning = l10n.chatSignatureHintWarning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            ContextActionButton(
              icon: Icon(
                showDirectOnly ? LucideIcons.user : LucideIcons.users,
                size: iconSize,
              ),
              label: showDirectOnly
                  ? l10n.chatShowingDirectOnly
                  : l10n.chatShowingAll,
              onPressed: () => onViewFilterChanged(
                showDirectOnly
                    ? MessageTimelineFilter.allWithContact
                    : MessageTimelineFilter.directOnly,
              ),
            ),
            ContextActionButton(
              icon: Icon(
                notificationsEnabled ? LucideIcons.bellOff : LucideIcons.bell,
                size: iconSize,
              ),
              label: notificationsEnabled
                  ? l10n.chatMuteNotifications
                  : l10n.chatEnableNotifications,
              onPressed: () => onToggleNotifications(!notificationsEnabled),
            ),
            ContextActionButton(
              icon: Icon(
                isSpamChat ? LucideIcons.inbox : LucideIcons.flag,
                size: iconSize,
              ),
              label: isSpamChat ? l10n.chatMoveToInbox : l10n.chatReportSpam,
              destructive: !isSpamChat,
              onPressed: () => onSpamToggle(!isSpamChat),
            ),
            _BlockActionButton(
              jid: chat.jid,
              emailAddress: chat.emailAddress,
              useEmailBlocking: chat.defaultTransport.isEmail,
            ),
          ],
        ),
        if (chat.supportsEmail) ...[
          const SizedBox(height: 12),
          ShadSwitch(
            label: Text(l10n.chatSignatureToggleLabel),
            sublabel: Text(
              '$signatureHint $signatureWarning',
              style: context.textTheme.muted,
            ),
            value: signatureActive,
            onChanged: globalSignatureEnabled
                ? (enabled) => context
                    .read<ChatBloc>()
                    .add(ChatShareSignatureToggled(enabled))
                : null,
          ),
        ],
      ],
    );
  }
}

class _BlockActionButton extends StatelessWidget {
  const _BlockActionButton({
    required this.jid,
    required this.useEmailBlocking,
    this.emailAddress,
  });

  final String jid;
  final bool useEmailBlocking;
  final String? emailAddress;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.of(context).textScaler;
    double scaled(double value) => textScaler.scale(value);
    final iconSize = scaled(16);
    final icon = Icon(LucideIcons.userX, size: iconSize);
    if (useEmailBlocking) {
      final emailService = RepositoryProvider.of<EmailService?>(context);
      final address = emailAddress?.trim();
      if (emailService == null || address?.isNotEmpty != true) {
        return ContextActionButton(
          icon: icon,
          label: context.l10n.chatBlockAction,
          destructive: true,
          onPressed: null,
        );
      }
      final EmailService service = emailService;
      final target = address!;
      return ContextActionButton(
        icon: icon,
        label: context.l10n.chatBlockAction,
        destructive: true,
        onPressed: () async {
          await service.blocking.block(target);
        },
      );
    }
    return BlocSelector<BlocklistCubit, BlocklistState, bool>(
      selector: (state) =>
          state is BlocklistLoading && (state.jid == null || state.jid == jid),
      builder: (context, disabled) {
        return ContextActionButton(
          icon: icon,
          label: context.l10n.chatBlockAction,
          destructive: true,
          onPressed: disabled
              ? null
              : () {
                  context.read<BlocklistCubit?>()?.block(jid: jid);
                },
        );
      },
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
    final fullName = message.user.getFullName().trim();
    final displayName = isSelf
        ? context.l10n.chatSenderYou
        : (fullName.isEmpty ? message.user.id : fullName);
    Widget bubbleWithLabel = bubble;
    if (showSenderLabel && displayName.isNotEmpty) {
      bubbleWithLabel = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              displayName,
              style: context.textTheme.small.copyWith(
                color: colors.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
              textAlign: isSelf ? TextAlign.right : TextAlign.left,
            ),
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
