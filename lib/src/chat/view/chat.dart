import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/location_autocomplete.dart';
import 'package:axichat/src/calendar/view/quick_add_modal.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/bloc/chat_search_cubit.dart';
import 'package:axichat/src/chat/models/pending_attachment.dart';
import 'package:axichat/src/chat/view/chat_alert.dart';
import 'package:axichat/src/chat/view/chat_attachment_preview.dart';
import 'package:axichat/src/chat/view/chat_bubble_surface.dart';
import 'package:axichat/src/chat/view/chat_cutout_composer.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/chat/view/chat_message_details.dart';
import 'package:axichat/src/chat/util/chat_subject_codec.dart';
import 'package:axichat/src/chat/view/pending_attachment_list.dart';
import 'package:axichat/src/chat/view/recipient_chips_bar.dart';
import 'package:axichat/src/chat/view/message_text_parser.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/widgets/selection_panel_shell.dart';
import 'package:axichat/src/common/bool_tool.dart';
import 'package:axichat/src/common/policy.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/context_action_button.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/models/chat_models.dart' as chat_models;
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show PipelineOwner, RenderProxyBox;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mime/mime.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

extension on MessageStatus {
  IconData get icon => switch (this) {
        MessageStatus.read => LucideIcons.checkCheck,
        MessageStatus.received || MessageStatus.sent => LucideIcons.check,
        MessageStatus.failed => LucideIcons.x,
        _ => LucideIcons.dot,
      };
}

class _SizeReportingWidget extends StatefulWidget {
  const _SizeReportingWidget({
    required this.onSizeChanged,
    required this.child,
  });

  final ValueChanged<Size> onSizeChanged;
  final Widget child;

  @override
  State<_SizeReportingWidget> createState() => _SizeReportingWidgetState();
}

class _SizeReportingWidgetState extends State<_SizeReportingWidget> {
  Size? _lastReportedSize;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderSize = context.size;
      if (renderSize == null) return;
      if (_lastReportedSize == renderSize) return;
      _lastReportedSize = renderSize;
      widget.onSizeChanged(renderSize);
    });
    return widget.child;
  }
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
const _cutoutMaxWidthFraction = 0.9;
const _reactionOverflowGlyphWidth = 18.0;
const _recipientCutoutDepth = 16.0;
const _recipientCutoutRadius = 18.0;
const _recipientCutoutPadding = EdgeInsets.fromLTRB(10, 4, 10, 6);
const _recipientCutoutOffset = Offset.zero;
const _recipientAvatarSize = 28.0;
const _recipientAvatarOverlap = 10.0;
const _recipientCutoutMinThickness = 48.0;
const _selectionCutoutDepth = 20.0;
const _selectionCutoutRadius = 16.0;
const _selectionCutoutPadding = EdgeInsets.fromLTRB(4, 6, 4, 6);
const _selectionCutoutOffset = Offset.zero;
const _selectionCutoutThickness = SelectionIndicator.size + 12.0;
const _selectionCutoutCornerClearance = 0.0;
const _selectionBubbleInteriorInset = _selectionCutoutDepth + 6.0;
const _selectionBubbleVerticalInset = 4.0;
const _selectionOuterInset =
    _selectionCutoutDepth + (SelectionIndicator.size / 2);
const _selectionIndicatorInboundGap = 10.0;
const _selectionIndicatorOutboundGap = 14.0;
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
const _messageArrivalDuration = Duration(milliseconds: 420);
const _messageArrivalCurve = Curves.easeOutCubic;
const _chatHorizontalPadding = 16.0;
const _selectionAutoscrollSlop = 4.0;
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
const _selectionDismissMoveAllowance = 36.0;
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
const _composerHorizontalInset = _chatHorizontalPadding + 4.0;
const _messageListTailSpacer = 36.0;

class _MessageFilterOption {
  const _MessageFilterOption(this.filter, this.label);

  final MessageTimelineFilter filter;
  final String label;
}

const _messageFilterOptions = [
  _MessageFilterOption(
    MessageTimelineFilter.directOnly,
    'Direct only',
  ),
  _MessageFilterOption(
    MessageTimelineFilter.allWithContact,
    'All with contact',
  ),
];

final List<chat_models.Chat> _debugEmailRecipients = List.generate(
  2,
  (index) => chat_models.Chat(
    jid: 'debug${index + 1}@example.com',
    title: 'Debug Recipient ${index + 1}',
    type: chat_models.ChatType.chat,
    lastChangeTimestamp: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    emailAddress: 'debug${index + 1}@example.com',
  ),
);

const _debugReactionEmojis = [
  '👍',
  '❤️',
  '😂',
  '😮',
  '😢',
  '🙏',
  '🔥',
  '👏',
  '😎',
  '🤔',
  '😴',
  '😡',
  '🥳',
  '🤯',
  '😇',
  '🤖',
  '👀',
  '💯',
  '🎉',
  '🫡',
];

final List<ReactionPreview> _debugReactionPreviews = List.unmodifiable(
  List.generate(
    _debugReactionEmojis.length,
    (index) => ReactionPreview(
      emoji: _debugReactionEmojis[index],
      count: (index % 3) + 1,
      reactedBySelf: index == 0,
    ),
  ),
);

const _debugReactionBody =
    'Incoming preview bubble showcasing reaction overflow.';

class _ChatSearchToggleButton extends StatelessWidget {
  const _ChatSearchToggleButton();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ChatSearchCubit?>();
    final active = cubit?.state.active ?? false;
    return AxiIconButton(
      iconData: active ? LucideIcons.x : LucideIcons.search,
      tooltip: active ? 'Close search' : 'Search messages',
      onPressed: cubit == null
          ? null
          : () => context.read<ChatSearchCubit>().toggleActive(),
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
    final searchCubit = context.watch<ChatSearchCubit?>();
    if (searchCubit == null) return const SizedBox.shrink();
    final animationDuration = context.watch<SettingsCubit>().animationDuration;
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
        return AnimatedCrossFade(
          duration: animationDuration,
          reverseDuration: animationDuration,
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
                        placeholder: const Text('Search messages'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AxiIconButton(
                      iconData: LucideIcons.x,
                      tooltip: 'Clear',
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
                      child: const Text('Cancel'),
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
                                child: Text(order.label),
                              ),
                            )
                            .toList(),
                        selectedOptionBuilder: (_, value) => Text(value.label),
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
                        options: _messageFilterOptions
                            .map(
                              (option) => ShadOption<MessageTimelineFilter>(
                                value: option.filter,
                                child: Text(option.label),
                              ),
                            )
                            .toList(),
                        selectedOptionBuilder: (_, value) => Text(
                          _messageFilterOptions
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
                Builder(
                  builder: (context) {
                    final trimmedQuery = state.query.trim();
                    final queryEmpty = trimmedQuery.isEmpty;
                    Widget? statusChild;
                    if (state.error != null) {
                      statusChild = Text(
                        state.error ?? 'Search failed',
                        style: TextStyle(
                          color: context.colorScheme.destructive,
                        ),
                      );
                    } else if (state.status == RequestStatus.loading) {
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
                            'Searching…',
                            style: context.textTheme.muted,
                          ),
                        ],
                      );
                    } else if (queryEmpty) {
                      statusChild = Text(
                        'Matches will appear in the conversation below.',
                        style: context.textTheme.muted,
                      );
                    } else if (state.status == RequestStatus.success) {
                      final matchCount = state.results.length;
                      statusChild = Text(
                        matchCount == 0
                            ? 'No matches. Adjust filters or try another query.'
                            : '$matchCount match${matchCount == 1 ? '' : 'es'} shown below.',
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

ShapeDecoration _bubbleDecoration({
  required Color background,
  Color? borderColor,
}) {
  final side = borderColor == null || borderColor.a == 0
      ? BorderSide.none
      : BorderSide(color: borderColor, width: 1);
  return ShapeDecoration(
    color: background,
    shape: ContinuousRectangleBorder(
      borderRadius: const BorderRadius.all(Radius.circular(_bubbleRadius)),
      side: side,
    ),
  );
}

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

InputDecoration _chatInputDecoration(
  BuildContext context, {
  required String hintText,
}) {
  final colors = context.colorScheme;
  final brightness = Theme.of(context).brightness;
  final border = OutlineInputBorder(
    borderRadius: context.radius,
    borderSide: BorderSide(color: colors.border),
  );
  final focusedBorder = border.copyWith(
    borderSide: BorderSide(
      color: colors.primary,
      width: 1.5,
    ),
  );
  final errorBorder = border.copyWith(
    borderSide: BorderSide(color: colors.destructive),
  );
  return defaultInputDecoration().copyWith(
    hintText: hintText,
    hintStyle: context.textTheme.muted.copyWith(
      color: colors.mutedForeground,
    ),
    filled: true,
    fillColor: colors.card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: border,
    enabledBorder: border,
    disabledBorder: border.copyWith(
      borderSide: BorderSide(
        color: colors.border.withValues(alpha: 0.6),
      ),
    ),
    focusedBorder: focusedBorder,
    errorBorder: errorBorder,
    focusedErrorBorder: errorBorder,
    hoverColor: colors.primary.withValues(
      alpha: brightness == Brightness.dark ? 0.08 : 0.04,
    ),
  );
}

class Chat extends StatefulWidget {
  const Chat({super.key, this.readOnly = false});

  final bool readOnly;

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  late final ShadPopoverController _emojiPopoverController;
  late final FocusNode _focusNode;
  late final TextEditingController _textController;
  late final TextEditingController _subjectController;
  late final FocusNode _subjectFocusNode;
  late final ScrollController _scrollController;
  bool _composerHasText = false;
  String _lastSubjectValue = '';
  final _approvedAttachmentSenders = <String>{};
  final _fileMetadataFutures = <String, Future<FileMetadataData?>>{};
  final _animatedMessageIds = <String>{};

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
  bool _selectionControlsMeasurementPending = false;
  int? _dismissPointer;
  Offset? _dismissPointerDownPosition;
  bool _dismissPointerMoved = false;
  var _sendingAttachment = false;
  double _recipientBarHeight = 0;

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

  Future<void> _handleSpamToggle({required bool sendToSpam}) async {
    final chat = context.read<ChatBloc>().state.chat;
    final jid = chat?.jid;
    if (chat == null || jid == null) return;
    final xmppService = context.read<XmppService?>();
    final emailService = RepositoryProvider.of<EmailService?>(context);
    try {
      await xmppService?.toggleChatSpam(jid: jid, spam: sendToSpam);
      final address = chat.emailAddress?.trim();
      if (chat.transport.isEmail && address?.isNotEmpty == true) {
        if (sendToSpam) {
          await emailService?.spam.mark(address!);
        } else {
          await emailService?.spam.unmark(address!);
        }
      }
    } on Exception {
      if (mounted) {
        _showSnackbar('Failed to update spam status.');
      }
      return;
    }
    if (!mounted) return;
    final toastMessage = sendToSpam
        ? 'Sent ${chat.title} to spam.'
        : 'Returned ${chat.title} to inbox.';
    ShadToaster.maybeOf(context)?.show(
      FeedbackToast.info(
        title: sendToSpam ? 'Reported' : 'Restored',
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

  bool _shouldAnimateMessage(String? messageId) {
    if (messageId == null ||
        messageId.isEmpty ||
        messageId == _selectionSpacerMessageId ||
        messageId == _emptyStateMessageId) {
      return false;
    }
    if (_animatedMessageIds.contains(messageId)) {
      return false;
    }
    _animatedMessageIds.add(messageId);
    return true;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_selectedMessageId == null) return;
    _dismissPointer = event.pointer;
    _dismissPointerDownPosition = event.position;
    _dismissPointerMoved = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_dismissPointer != event.pointer) return;
    final origin = _dismissPointerDownPosition;
    if (origin == null) return;
    if (!_dismissPointerMoved &&
        (event.position - origin).distance > _selectionDismissMoveAllowance) {
      _dismissPointerMoved = true;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_dismissPointer != event.pointer) return;
    final origin = _dismissPointerDownPosition;
    final travel = origin == null ? 0.0 : (event.position - origin).distance;
    if (!_dismissPointerMoved || travel <= _selectionDismissTapAllowance) {
      _maybeDismissSelection(event.position);
    }
    _resetDismissPointer();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_dismissPointer != event.pointer) return;
    _resetDismissPointer();
  }

  void _resetDismissPointer() {
    _dismissPointer = null;
    _dismissPointerDownPosition = null;
    _dismissPointerMoved = false;
  }

  void _handleRecipientBarSizeChanged(Size size) {
    if (!mounted) return;
    _setRecipientBarHeight(size.height);
  }

  void _setRecipientBarHeight(double height) {
    final targetHeight =
        height.isFinite ? math.max(0.0, height) : 0.0; // ignore invalid sizes
    if ((_recipientBarHeight - targetHeight).abs() <=
        _selectionHeadroomTolerance) {
      return;
    }
    setState(() {
      _recipientBarHeight = targetHeight;
    });
    if (_selectionAutoscrollActive) {
      _scheduleSelectionAutoscroll();
    }
  }

  void _ensureRecipientBarHeightCleared() {
    if (_recipientBarHeight <= _selectionHeadroomTolerance) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _setRecipientBarHeight(0);
    });
  }

  Future<FileMetadataData?> _metadataFutureFor(String id) {
    return _fileMetadataFutures.putIfAbsent(
      id,
      () async {
        final xmpp = context.read<XmppService>();
        final db = await xmpp.database;
        return db.getFileMetadata(id);
      },
    );
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
    final displaySender =
        senderEmail?.isNotEmpty == true ? senderEmail! : senderJid;
    final confirmed = await confirm(
      context,
      title: 'Load attachment?',
      message:
          'Only load attachments from contacts you trust.\n\n$displaySender is not in your contacts yet. Continue?',
      confirmLabel: 'Load',
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
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    final host = uri?.host.isNotEmpty == true ? uri!.host : trimmed;
    final approved = await confirm(
      context,
      title: 'Open external link?',
      message:
          'You are about to open:\n$trimmed\n\nOnly tap OK if you trust the site (host: $host).',
      confirmLabel: 'Open link',
      destructiveConfirm: false,
    );
    if (approved != true) return;
    if (uri == null) {
      _showSnackbar('Invalid link: $trimmed');
      return;
    }
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      _showSnackbar('Unable to open $host');
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
    final bloc = context.read<ChatBloc>();
    final pendingAttachments = bloc.state.pendingAttachments;
    final hasQueuedAttachments = pendingAttachments.any(
      (attachment) => attachment.status == PendingAttachmentStatus.queued,
    );
    final hasSubject = _subjectController.text.trim().isNotEmpty;
    final canSend = text.isNotEmpty || hasQueuedAttachments || hasSubject;
    if (!canSend) return;
    bloc.add(ChatMessageSent(text: text));
    if (text.isNotEmpty) {
      _textController.clear();
    }
    _focusNode.requestFocus();
  }

  Future<void> _handleSendButtonLongPress() async {
    if (widget.readOnly) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final colors = context.colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(LucideIcons.save, color: colors.primary),
                title: const Text('Save as draft'),
                onTap: () => Navigator.of(context).pop('save'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (!mounted || action != 'save') return;
    await _saveComposerAsDraft();
  }

  Future<void> _saveComposerAsDraft() async {
    final chatBloc = context.read<ChatBloc>();
    final chat = chatBloc.state.chat;
    final draftCubit = context.read<DraftCubit?>();
    if (chat == null || draftCubit == null) {
      _showSnackbar('Drafts are unavailable right now.');
      return;
    }
    final body = _textController.text;
    final subject = _subjectController.text;
    final trimmedBody = body.trim();
    final trimmedSubject = subject.trim();
    final attachments = chatBloc.state.pendingAttachments
        .map((pending) => pending.attachment)
        .toList();
    final hasContent = trimmedBody.isNotEmpty ||
        trimmedSubject.isNotEmpty ||
        attachments.isNotEmpty;
    if (!hasContent) {
      _showSnackbar('Add a message, subject, or attachment before saving.');
      return;
    }
    final recipients = _resolveDraftRecipients(
      chat: chat,
      recipients: chatBloc.state.recipients,
    );
    try {
      await draftCubit.saveDraft(
        id: null,
        jids: recipients,
        body: body,
        subject: trimmedSubject.isEmpty ? null : subject,
        attachments: attachments,
      );
      if (!mounted) return;
      _showSnackbar('Saved to Drafts.');
    } catch (_) {
      if (!mounted) return;
      _showSnackbar('Failed to save draft. Try again.');
    }
  }

  Future<void> _stashComposerDraftIfDirty() async {
    final chatBloc = context.read<ChatBloc>();
    final chat = chatBloc.state.chat;
    final draftCubit = context.read<DraftCubit?>();
    if (chat == null || draftCubit == null) {
      return;
    }
    final body = _textController.text;
    final subject = _subjectController.text;
    final trimmedBody = body.trim();
    final trimmedSubject = subject.trim();
    final attachments = chatBloc.state.pendingAttachments
        .map((pending) => pending.attachment)
        .toList();
    final recipients = _resolveDraftRecipients(
      chat: chat,
      recipients: chatBloc.state.recipients,
    );
    final hasRecipientChanges = recipients.length > 1 ||
        (recipients.isNotEmpty && recipients.first != chat.jid);
    final hasContent = trimmedBody.isNotEmpty ||
        trimmedSubject.isNotEmpty ||
        attachments.isNotEmpty ||
        hasRecipientChanges;
    if (!hasContent) {
      return;
    }
    try {
      await draftCubit.saveDraft(
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
  }) {
    final accessories = <ChatComposerAccessory>[
      ChatComposerAccessory.leading(
        child: _EmojiPickerAccessory(
          controller: _emojiPopoverController,
          textController: _textController,
        ),
      ),
      ChatComposerAccessory.leading(
        child: _AttachmentAccessoryButton(
          enabled: !_sendingAttachment,
          onPressed: _handleAttachmentPressed,
        ),
      ),
      ChatComposerAccessory.trailing(
        child: _SendMessageAccessory(
          enabled: canSend,
          onPressed: _handleSendMessage,
          onLongPress: widget.readOnly ? null : _handleSendButtonLongPress,
        ),
      ),
    ];
    return accessories;
  }

  Future<void> _handleAttachmentPressed() async {
    if (_sendingAttachment) return;
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
        _showSnackbar('Selected file is not accessible.');
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
      _showSnackbar(error.message ?? 'Unable to attach file.');
    } on Exception {
      _showSnackbar('Unable to attach file.');
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
    final commandSurface =
        EnvScope.maybeOf(context)?.commandSurface ?? CommandSurface.sheet;
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
    final bloc = context.read<ChatBloc>();
    final items = <Widget>[];
    if (pending.attachment.isImage) {
      items.add(
        ShadContextMenuItem(
          leading: const Icon(LucideIcons.eye),
          onPressed: () => _showAttachmentPreview(pending),
          child: const Text('View'),
        ),
      );
    }
    if (pending.status == PendingAttachmentStatus.failed) {
      items.add(
        ShadContextMenuItem(
          leading: const Icon(LucideIcons.refreshCw),
          onPressed: () => bloc.add(ChatAttachmentRetryRequested(pending.id)),
          child: const Text('Retry upload'),
        ),
      );
    }
    items.add(
      ShadContextMenuItem(
        leading: const Icon(LucideIcons.trash),
        onPressed: () => bloc.add(ChatPendingAttachmentRemoved(pending.id)),
        child: const Text('Remove attachment'),
      ),
    );
    return items;
  }

  Future<void> _showAttachmentPreview(PendingAttachment pending) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            SizedBox(
              width: MediaQuery.sizeOf(context).width * 0.9,
              height: MediaQuery.sizeOf(context).height * 0.7,
              child: InteractiveViewer(
                child: Image.file(
                  File(pending.attachment.path),
                  fit: BoxFit.contain,
                ),
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
      ),
    );
  }

  Future<void> _showPendingAttachmentActions(PendingAttachment pending) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final attachment = pending.attachment;
        final sizeLabel = formatBytes(attachment.sizeBytes);
        final bloc = context.read<ChatBloc>();
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
                    leading: const Icon(LucideIcons.eye),
                    title: const Text('View'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _showAttachmentPreview(pending);
                    },
                  ),
                if (pending.status == PendingAttachmentStatus.failed)
                  ListTile(
                    leading: const Icon(LucideIcons.refreshCw),
                    title: const Text('Retry upload'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      bloc.add(ChatAttachmentRetryRequested(pending.id));
                    },
                  ),
                ListTile(
                  leading: const Icon(LucideIcons.trash),
                  title: const Text('Remove attachment'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    bloc.add(ChatPendingAttachmentRemoved(pending.id));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
      _resetDismissPointer();
      _selectMessage(messageId);
    }
  }

  void _clearMessageSelection() {
    if (_selectedMessageId == null) return;
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
    final rawTarget = position.pixels + scrollDelta;
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
    final recipientInset = _recipientBarHeight > _selectionHeadroomTolerance
        ? _recipientBarHeight
        : 0.0;
    final currentGap = inputTop - reactionBottom - recipientInset;
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
      position.jumpTo(target);
      return;
    }
    await position.animateTo(
      target,
      duration: _bubbleFocusDuration ~/ 2,
      curve: _bubbleFocusCurve,
    );
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
    final desired = math.max(
      viewportExtent - _selectionControlsHeight,
      _selectionExtrasViewportGap,
    );
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
    _scrollController = ScrollController();
    _textController.addListener(_typingListener);
    _subjectController.addListener(_handleSubjectChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureBaseSelectionHeadroom();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    _textController.removeListener(_typingListener);
    _textController.dispose();
    _subjectController.removeListener(_handleSubjectChanged);
    _subjectController.dispose();
    _subjectFocusNode.dispose();
    _emojiPopoverController.dispose();
    _bubbleRegionRegistry.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatSearchCubit, ChatSearchState>(
      builder: (context, searchState) {
        final trimmedQuery = searchState.query.trim();
        final searchFiltering = searchState.active && trimmedQuery.isNotEmpty;
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
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
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
                  final toastWidget = switch (toast.variant) {
                    ChatToastVariant.destructive => FeedbackToast.error(
                        title: 'Whoops',
                        message: toast.message,
                      ),
                    ChatToastVariant.warning => FeedbackToast.warning(
                        title: 'Heads up',
                        message: toast.message,
                      ),
                    ChatToastVariant.info => FeedbackToast.success(
                        title: 'All set',
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
                listener: (_, __) => _animatedMessageIds.clear(),
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
                final emailService =
                    RepositoryProvider.of<EmailService>(context, listen: false);
                final emailSelfJid = emailService.selfSenderJid;
                final chatEntity = state.chat;
                final jid = chatEntity?.jid;
                final avatarIdentifier = chatEntity?.avatarIdentifier;
                final supportsEmail = chatEntity?.supportsEmail ?? false;
                final isEmailChat = chatEntity?.deltaChatId != null;
                final isAxiCompatible = chatEntity?.isAxiContact ?? false;
                final rosterContacts = context.watch<RosterCubit>().contacts;
                final isDefaultEmail =
                    chatEntity?.defaultTransport.isEmail ?? false;
                final currentUserId = isDefaultEmail
                    ? (emailSelfJid ?? profile?.jid ?? '')
                    : (profile?.jid ?? emailSelfJid ?? '');
                final shareContexts = state.shareContexts;
                final recipients = state.recipients;
                final pendingAttachments = state.pendingAttachments;
                final latestStatuses = _latestRecipientStatuses(state);
                final fanOutReports = state.fanOutReports;
                final warningEntry = fanOutReports.entries.isEmpty
                    ? null
                    : fanOutReports.entries.last;
                final showAttachmentWarning =
                    warningEntry?.value.attachmentWarning ?? false;
                final retryEntry = _lastReportEntryWhere(
                  fanOutReports.entries,
                  (entry) => entry.value.hasFailures,
                );
                final retryReport = retryEntry?.value;
                final retryShareId = retryEntry?.key;
                final showCompatibilityBadge = supportsEmail && isAxiCompatible;
                final Widget? avatarBadge = showCompatibilityBadge
                    ? const AxiCompatibilityBadge(compact: true)
                    : null;
                final availableChats =
                    (context.watch<ChatsCubit?>()?.state.items ??
                            const <chat_models.Chat>[])
                        .where((chat) => chat.jid != chatEntity?.jid)
                        .toList();
                final user = ChatUser(
                  id: currentUserId,
                  firstName: profile?.username ?? '',
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
                      leadingWidth:
                          readOnly ? 0 : (AxiIconButton.kDefaultSize + 24),
                      leading: readOnly
                          ? null
                          : Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: AxiIconButton.kDefaultSize,
                                  height: AxiIconButton.kDefaultSize,
                                  child: AxiIconButton(
                                    iconData: LucideIcons.arrowLeft,
                                    tooltip: 'Back',
                                    color: context.colorScheme.foreground,
                                    borderColor: context.colorScheme.border,
                                    onPressed: () {
                                      if (_chatRoute != _ChatRoute.main) {
                                        context.read<ChatBloc>().add(
                                            const ChatMessageFocused(null));
                                        return setState(() {
                                          _chatRoute = _ChatRoute.main;
                                          _settingsPanelExpanded = false;
                                        });
                                      }
                                      if (_textController.text.isNotEmpty) {
                                        if (!isDefaultEmail) {
                                          context
                                              .read<DraftCubit?>()
                                              ?.saveDraft(
                                                id: null,
                                                jids: [state.chat!.jid],
                                                body: _textController.text,
                                              );
                                        }
                                      }
                                      if (_settingsPanelExpanded) {
                                        setState(() {
                                          _settingsPanelExpanded = false;
                                        });
                                      }
                                      context
                                          .read<ChatsCubit>()
                                          .toggleChat(jid: state.chat!.jid);
                                    },
                                  ),
                                ),
                              ),
                            ),
                      title: jid == null
                          ? const SizedBox.shrink()
                          : BlocBuilder<RosterCubit, RosterState>(
                              buildWhen: (_, current) =>
                                  current is RosterAvailable,
                              builder: (context, rosterState) {
                                final item = (rosterState is! RosterAvailable
                                        ? context.read<RosterCubit>()['items']
                                            as List<RosterItem>
                                        : rosterState.items)
                                    ?.where((e) => e.jid == jid)
                                    .singleOrNull;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 40.0,
                                        maxHeight: 40.0,
                                      ),
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned.fill(
                                            child: (item == null)
                                                ? AxiAvatar(
                                                    jid:
                                                        avatarIdentifier ?? jid,
                                                  )
                                                : AxiAvatar(
                                                    jid: item.jid,
                                                    subscription:
                                                        item.subscription,
                                                    presence: item.presence,
                                                    status: item.status,
                                                  ),
                                          ),
                                          if (avatarBadge != null)
                                            Positioned(
                                              right: -6,
                                              bottom: -4,
                                              child: avatarBadge,
                                            ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                      ),
                                      child: Text(
                                        state.chat?.title ?? '',
                                        style: context.textTheme.h4,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        item?.status ?? '',
                                        overflow: TextOverflow.ellipsis,
                                        style: context.textTheme.muted,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                      actions: [
                        if (jid != null && _chatRoute == _ChatRoute.main) ...[
                          const _ChatSearchToggleButton(),
                          if (!readOnly) ...[
                            const SizedBox(width: 4),
                            AxiIconButton(
                              iconData: showSettingsPanel
                                  ? LucideIcons.x
                                  : LucideIcons.settings,
                              tooltip: showSettingsPanel
                                  ? 'Close settings'
                                  : 'Chat settings',
                              onPressed: _toggleSettingsPanel,
                            ),
                          ],
                        ] else
                          const SizedBox.shrink(),
                      ],
                      bottom: null,
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
                                    final contentWidth = math.max(
                                      0.0,
                                      constraints.maxWidth -
                                          (_chatHorizontalPadding * 2),
                                    );
                                    final isCompact =
                                        contentWidth < smallScreen;
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
                                    final baseBubbleMaxWidth =
                                        contentWidth * (isCompact ? 0.8 : 0.7);
                                    final messageRowMaxWidth = contentWidth;
                                    final clampedBubbleWidth =
                                        baseBubbleMaxWidth.clamp(
                                      0.0,
                                      contentWidth,
                                    );
                                    final dashMessages = <ChatMessage>[];
                                    final shownSubjectShares = <String>{};
                                    for (var index = 0;
                                        index < filteredItems.length;
                                        index++) {
                                      final e = filteredItems[index];
                                      final isSelfXmpp =
                                          e.senderJid == profile?.jid;
                                      final isSelfEmail =
                                          emailSelfJid != null &&
                                              e.senderJid == emailSelfJid;
                                      final isSelf = isSelfXmpp || isSelfEmail;
                                      final isEmailMessage =
                                          e.deltaMsgId != null;
                                      final author = isSelf
                                          ? user
                                          : ChatUser(
                                              id: e.senderJid,
                                              firstName: state.chat?.title,
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
                                      final errorLabel = e.error.asString;
                                      final renderedText = e.error.isNotNone
                                          ? '$errorLabel${bodyText.isNotEmpty ? ': "${bodyText.trim()}"' : ''}'
                                          : bodyText;
                                      dashMessages.add(
                                        ChatMessage(
                                          user: author,
                                          createdAt: e.timestamp!,
                                          text: renderedText,
                                          status: e.error.isNotNone
                                              ? MessageStatus.failed
                                              : e.displayed
                                                  ? MessageStatus.read
                                                  : e.received
                                                      ? MessageStatus.received
                                                      : e.acked
                                                          ? MessageStatus.sent
                                                          : MessageStatus
                                                              .pending,
                                          customProperties: {
                                            'id': e.stanzaID,
                                            'body': bodyText,
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
                                            'showSubject': showSubjectHeader,
                                            'subjectLabel': subjectLabel,
                                            'isEmailMessage': isEmailMessage,
                                          },
                                        ),
                                      );
                                    }
                                    if (!isEmailChat) {
                                      final chatJid = state.chat?.jid ??
                                          'preview@axichat.dev';
                                      final debugMessageId =
                                          '__debug_reactions_$chatJid';
                                      final debugTimestamp =
                                          DateTime.now().toUtc();
                                      const debugSenderJid =
                                          'preview@axichat.dev';
                                      final debugModel = Message(
                                        stanzaID: debugMessageId,
                                        senderJid: debugSenderJid,
                                        chatJid: chatJid,
                                        body: _debugReactionBody,
                                        timestamp: debugTimestamp,
                                        reactionsPreview:
                                            _debugReactionPreviews,
                                      );
                                      dashMessages.add(
                                        ChatMessage(
                                          user: ChatUser(
                                            id: debugSenderJid,
                                            firstName: state.chat?.title ??
                                                'Preview Contact',
                                          ),
                                          createdAt: debugTimestamp,
                                          text: _debugReactionBody,
                                          customProperties: {
                                            'id': debugMessageId,
                                            'body': _debugReactionBody,
                                            'edited': false,
                                            'retracted': false,
                                            'error': MessageError.none,
                                            'encrypted': false,
                                            'trust': null,
                                            'trusted': null,
                                            'isSelf': false,
                                            'model': debugModel,
                                            'quoted': null,
                                            'reactions': _debugReactionPreviews,
                                            'shareParticipants':
                                                const <chat_models.Chat>[],
                                          },
                                        ),
                                      );
                                    }
                                    final emptyStateLabel = searchFiltering
                                        ? 'No matches'
                                        : 'No messages';
                                    if (filteredItems.isEmpty) {
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
                                      typingBuilder: (_) => const Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          _chatHorizontalPadding,
                                          12,
                                          _chatHorizontalPadding,
                                          8,
                                        ),
                                        child: TypingIndicator(),
                                      ),
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
                                        ? 'Send email message'
                                        : 'Send message';
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
                                          isSelf: quoting.senderJid ==
                                              currentUserId,
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
                                                'composing'
                                            ? ChatUser(
                                                id: state.chat!.jid,
                                                firstName: state.chat!.title,
                                              )
                                            : null;
                                    final typingUsers = <ChatUser>[
                                      if (state.typing == true) user,
                                      if (remoteTyping != null) remoteTyping,
                                    ];
                                    return Column(
                                      children: [
                                        Expanded(
                                          child: KeyedSubtree(
                                            key: _messageListKey,
                                            child: DashChat(
                                              currentUser: user,
                                              onSend: widget.readOnly
                                                  ? (_) {}
                                                  : (_) => _handleSendMessage(),
                                              messages: dashMessages,
                                              typingUsers:
                                                  typingUsers.take(1).toList(),
                                              messageOptions: MessageOptions(
                                                showOtherUsersAvatar: false,
                                                borderRadius: 0,
                                                maxWidth: messageRowMaxWidth,
                                                messagePadding: EdgeInsets.zero,
                                                spaceWhenAvatarIsHidden: 0,
                                                currentUserContainerColor:
                                                    Colors.transparent,
                                                containerColor:
                                                    Colors.transparent,
                                                userNameBuilder: (user) {
                                                  if (user.id ==
                                                      _selectionSpacerMessageId) {
                                                    return const SizedBox
                                                        .shrink();
                                                  }
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      left:
                                                          _chatHorizontalPadding,
                                                      right:
                                                          _chatHorizontalPadding,
                                                      bottom: 4,
                                                    ),
                                                    child: Text(
                                                      user.getFullName(),
                                                      style: context
                                                          .textTheme.muted
                                                          .copyWith(
                                                              fontSize: 12.0),
                                                    ),
                                                  );
                                                },
                                                messageTextBuilder:
                                                    (message, previous, next) {
                                                  final colors =
                                                      context.colorScheme;
                                                  final chatTokens =
                                                      context.chatTheme;
                                                  final isSelectionSpacer =
                                                      message.customProperties?[
                                                              'selectionSpacer'] ==
                                                          true;
                                                  if (isSelectionSpacer) {
                                                    final spacerHeight =
                                                        selectionSpacerVisibleHeight;
                                                    return _SelectionHeadroomSpacer(
                                                      height: spacerHeight,
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
                                                      isEmailChat
                                                          ? <chat_models.Chat>[
                                                              ...bannerParticipants,
                                                              ..._debugEmailRecipients,
                                                            ]
                                                          : bannerParticipants;
                                                  final extraStyle = context
                                                      .textTheme.muted
                                                      .copyWith(
                                                    fontStyle: FontStyle.italic,
                                                  );
                                                  final isEmptyState =
                                                      message.customProperties?[
                                                              'emptyState'] ==
                                                          true;
                                                  if (isEmptyState) {
                                                    final emptyLabel =
                                                        message.customProperties?[
                                                                    'emptyLabel']
                                                                as String? ??
                                                            'No messages';
                                                    return Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        vertical: 24,
                                                        horizontal:
                                                            _chatHorizontalPadding,
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          emptyLabel,
                                                          style: context
                                                              .textTheme.muted,
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                  final self =
                                                      message.customProperties?[
                                                                  'isSelf']
                                                              as bool? ??
                                                          (message.user.id ==
                                                              profile?.jid);
                                                  final error = message
                                                          .customProperties![
                                                      'error'] as MessageError;
                                                  final isError =
                                                      error.isNotNone;
                                                  final bubbleColor = isError
                                                      ? colors.destructive
                                                      : self
                                                          ? colors.primary
                                                          : colors.card;
                                                  final borderColor =
                                                      self || isError
                                                          ? Colors.transparent
                                                          : chatTokens.recvEdge;
                                                  final textColor = isError
                                                      ? colors
                                                          .destructiveForeground
                                                      : self
                                                          ? colors
                                                              .primaryForeground
                                                          : colors.foreground;
                                                  final timestampColor =
                                                      chatTokens.timestamp;
                                                  const iconSize = 13.0;
                                                  final iconFamily = message
                                                      .status!.icon.fontFamily;
                                                  final iconPackage = message
                                                      .status!.icon.fontPackage;
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
                                                  final baseTextStyle = context
                                                      .textTheme.small
                                                      .copyWith(
                                                    color: textColor,
                                                    height: 1.3,
                                                  );
                                                  final linkStyle =
                                                      baseTextStyle.copyWith(
                                                    color: self
                                                        ? colors
                                                            .primaryForeground
                                                        : colors.primary,
                                                    decoration: TextDecoration
                                                        .underline,
                                                    fontWeight: FontWeight.w600,
                                                  );
                                                  final parsedText =
                                                      parseMessageText(
                                                    text: message.text,
                                                    baseStyle: baseTextStyle,
                                                    linkStyle: linkStyle,
                                                  );
                                                  final timeColor = isError
                                                      ? textColor
                                                      : self
                                                          ? colors
                                                              .primaryForeground
                                                          : timestampColor;
                                                  final isEmailMessage = (message
                                                                  .customProperties?[
                                                              'isEmailMessage']
                                                          as bool?) ??
                                                      ((message.customProperties?[
                                                                      'model']
                                                                  as Message?)
                                                              ?.deltaMsgId !=
                                                          null);
                                                  final transportIconData =
                                                      isEmailMessage
                                                          ? LucideIcons.mail
                                                          : LucideIcons
                                                              .messageCircle;
                                                  final time = TextSpan(
                                                    text:
                                                        '${message.createdAt.hour.toString().padLeft(2, '0')}:'
                                                        '${message.createdAt.minute.toString().padLeft(2, '0')}',
                                                    style: context
                                                        .textTheme.muted
                                                        .copyWith(
                                                      color: timeColor,
                                                      fontSize: 11.0,
                                                    ),
                                                  );
                                                  final status = TextSpan(
                                                    text: String.fromCharCode(
                                                      message.status!.icon
                                                          .codePoint,
                                                    ),
                                                    style: TextStyle(
                                                      color: self
                                                          ? colors
                                                              .primaryForeground
                                                          : timestampColor,
                                                      fontSize: iconSize,
                                                      fontFamily: iconFamily,
                                                      package: iconPackage,
                                                    ),
                                                  );
                                                  final transportDetail =
                                                      TextSpan(
                                                    text: String.fromCharCode(
                                                      transportIconData
                                                          .codePoint,
                                                    ),
                                                    style: TextStyle(
                                                      color: timeColor,
                                                      fontSize: iconSize,
                                                      fontFamily:
                                                          transportIconData
                                                              .fontFamily,
                                                      package: transportIconData
                                                          .fontPackage,
                                                    ),
                                                  );
                                                  final trusted =
                                                      message.customProperties![
                                                          'trusted'] as bool?;
                                                  final verification =
                                                      trusted == null
                                                          ? null
                                                          : TextSpan(
                                                              text: String
                                                                  .fromCharCode(
                                                                trusted
                                                                    .toShieldIcon
                                                                    .codePoint,
                                                              ),
                                                              style: context
                                                                  .textTheme
                                                                  .muted
                                                                  .copyWith(
                                                                color: trusted
                                                                    ? axiGreen
                                                                    : colors
                                                                        .destructive,
                                                                fontSize:
                                                                    iconSize,
                                                                fontFamily:
                                                                    iconFamily,
                                                                package:
                                                                    iconPackage,
                                                              ),
                                                            );
                                                  final messageModel =
                                                      message.customProperties?[
                                                          'model'] as Message;
                                                  final quotedModel =
                                                      message.customProperties?[
                                                          'quoted'] as Message?;
                                                  final reactions = (message
                                                                  .customProperties?[
                                                              'reactions']
                                                          as List<
                                                              ReactionPreview>?) ??
                                                      const <ReactionPreview>[];
                                                  final canReact = !isEmailChat;
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
                                                      reactions.isNotEmpty &&
                                                          !showReactionManager;
                                                  final showRecipientCutout =
                                                      !showCompactReactions &&
                                                          isEmailChat &&
                                                          recipientCutoutParticipants
                                                              .isNotEmpty;
                                                  Widget? selectionOverlay;
                                                  CutoutStyle? selectionStyle;
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
                                                    selectionOverlay = Padding(
                                                      padding: EdgeInsets.only(
                                                        left: self
                                                            ? _selectionIndicatorOutboundGap
                                                            : 0,
                                                        right: self
                                                            ? 0
                                                            : _selectionIndicatorInboundGap,
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
                                                  final bubbleContentKey = message
                                                              .customProperties?[
                                                          'id'] ??
                                                      '${message.user.id}-${message.createdAt.microsecondsSinceEpoch}';
                                                  final bubbleChildren =
                                                      <Widget>[];
                                                  if (quotedModel != null) {
                                                    bubbleChildren.add(
                                                      _QuotedMessagePreview(
                                                        message: quotedModel,
                                                        isSelf: quotedModel
                                                                .senderJid ==
                                                            user.id,
                                                      ),
                                                    );
                                                  }
                                                  if (isError) {
                                                    bubbleChildren.addAll([
                                                      Text(
                                                        'Error!',
                                                        style: context
                                                            .textTheme.small
                                                            .copyWith(
                                                          color: textColor,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      DynamicInlineText(
                                                        key: ValueKey(
                                                          bubbleContentKey,
                                                        ),
                                                        text: parsedText.body,
                                                        details: [time],
                                                        links: parsedText.links,
                                                        onLinkTap:
                                                            _handleLinkTap,
                                                      ),
                                                    ]);
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
                                                      final String subjectText =
                                                          subjectLabel;
                                                      bubbleChildren.add(
                                                        Text(
                                                          subjectText,
                                                          style: Theme.of(
                                                            context,
                                                          )
                                                              .textTheme
                                                              .titleMedium
                                                              ?.copyWith(
                                                                color:
                                                                    textColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      );
                                                      bubbleChildren
                                                          .add(const SizedBox(
                                                        height: 6,
                                                      ));
                                                    }
                                                    bubbleChildren.add(
                                                      DynamicInlineText(
                                                        key: ValueKey(
                                                            bubbleContentKey),
                                                        text: parsedText.body,
                                                        details: [
                                                          time,
                                                          transportDetail,
                                                          if (self) status,
                                                          if (verification !=
                                                              null)
                                                            verification,
                                                        ],
                                                        links: parsedText.links,
                                                        onLinkTap:
                                                            _handleLinkTap,
                                                      ),
                                                    );
                                                    if (message.customProperties?[
                                                            'retracted'] ??
                                                        false) {
                                                      bubbleChildren.add(
                                                        Text(
                                                          '(retracted)',
                                                          style: extraStyle,
                                                        ),
                                                      );
                                                    } else if (message
                                                                .customProperties?[
                                                            'edited'] ??
                                                        false) {
                                                      bubbleChildren.add(
                                                        Text(
                                                          '(edited)',
                                                          style: extraStyle,
                                                        ),
                                                      );
                                                    }
                                                  }
                                                  final metadataId =
                                                      messageModel
                                                          .fileMetadataID;
                                                  if (metadataId != null &&
                                                      metadataId.isNotEmpty) {
                                                    if (bubbleChildren
                                                        .isNotEmpty) {
                                                      bubbleChildren.add(
                                                        const SizedBox(
                                                            height: 8),
                                                      );
                                                    }
                                                    final allowAttachment =
                                                        _shouldAllowAttachment(
                                                      senderJid: messageModel
                                                          .senderJid,
                                                      isSelf: self,
                                                      knownContacts:
                                                          rosterContacts,
                                                      isEmailChat: isEmailChat,
                                                    );
                                                    bubbleChildren.add(
                                                      ChatAttachmentPreview(
                                                        metadataFuture:
                                                            _metadataFutureFor(
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
                                                                          messageModel
                                                                              .senderJid,
                                                                      senderEmail: state
                                                                          .chat
                                                                          ?.emailAddress,
                                                                    ),
                                                      ),
                                                    );
                                                  }
                                                  var bubbleBottomInset = 0.0;
                                                  if (showCompactReactions) {
                                                    bubbleBottomInset =
                                                        _reactionBubbleInset;
                                                  }
                                                  if (showRecipientCutout) {
                                                    bubbleBottomInset =
                                                        math.max(
                                                      bubbleBottomInset,
                                                      _recipientBubbleInset,
                                                    );
                                                  }
                                                  EdgeInsetsGeometry
                                                      bubblePadding =
                                                      _bubblePadding;
                                                  if (bubbleBottomInset > 0) {
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
                                                  final bubbleBorderRadius =
                                                      _bubbleBorderRadius(
                                                    isSelf: self,
                                                    chainedPrevious:
                                                        chainedPrev,
                                                    chainedNext: chainedNext,
                                                    isSelected: isSelected,
                                                  );
                                                  final selectionAllowance =
                                                      selectionOverlay != null
                                                          ? _selectionOuterInset
                                                          : 0.0;
                                                  final bubbleMaxWidth =
                                                      math.min(
                                                    messageRowMaxWidth,
                                                    clampedBubbleWidth +
                                                        selectionAllowance,
                                                  );
                                                  final bubbleConstraints =
                                                      BoxConstraints(
                                                    maxWidth: bubbleMaxWidth,
                                                  );
                                                  final bubbleHighlightColor =
                                                      context
                                                          .colorScheme.primary;
                                                  final bubbleContent = Padding(
                                                    padding: bubblePadding,
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      spacing: 4,
                                                      children: bubbleChildren,
                                                    ),
                                                  );
                                                  final nextIsTailSpacer = next
                                                              ?.customProperties?[
                                                          'selectionSpacer'] ==
                                                      true;
                                                  final isRenderableBubble =
                                                      !(isSelectionSpacer ||
                                                          isEmptyState);
                                                  final isLatestBubble =
                                                      isRenderableBubble &&
                                                          (next == null ||
                                                              nextIsTailSpacer);
                                                  final baseOuterBottom =
                                                      isLatestBubble
                                                          ? 12.0
                                                          : 2.0;
                                                  var extraOuterBottom = 0.0;
                                                  if (showCompactReactions) {
                                                    extraOuterBottom = math.max(
                                                      extraOuterBottom,
                                                      _reactionCutoutDepth,
                                                    );
                                                  }
                                                  if (showRecipientCutout) {
                                                    extraOuterBottom = math.max(
                                                      extraOuterBottom,
                                                      _recipientCutoutDepth,
                                                    );
                                                  }
                                                  double extraOuterLeft = 0;
                                                  double extraOuterRight = 0;
                                                  final outerPadding =
                                                      EdgeInsets.only(
                                                    top: 2,
                                                    bottom: baseOuterBottom +
                                                        extraOuterBottom,
                                                    left:
                                                        _chatHorizontalPadding +
                                                            extraOuterLeft,
                                                    right:
                                                        _chatHorizontalPadding +
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
                                                    curve: _bubbleFocusCurve,
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
                                                        reactionOverlay:
                                                            showCompactReactions
                                                                ? _ReactionStrip(
                                                                    reactions:
                                                                        reactions,
                                                                    onReactionTap:
                                                                        canReact
                                                                            ? (emoji) =>
                                                                                _toggleQuickReaction(
                                                                                  messageModel,
                                                                                  emoji,
                                                                                )
                                                                            : null,
                                                                  )
                                                                : null,
                                                        reactionStyle:
                                                            showCompactReactions
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
                                                            showRecipientCutout
                                                                ? _RecipientCutoutStrip(
                                                                    recipients:
                                                                        recipientCutoutParticipants,
                                                                  )
                                                                : null,
                                                        recipientStyle:
                                                            showRecipientCutout
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
                                                                : null,
                                                        selectionOverlay:
                                                            selectionOverlay,
                                                        selectionStyle:
                                                            selectionStyle,
                                                        selectionFollowsSelfEdge:
                                                            false,
                                                      );
                                                      return _MessageBubbleRegion(
                                                        messageId: messageModel
                                                            .stanzaID,
                                                        registry:
                                                            _bubbleRegionRegistry,
                                                        child: bubbleSurface,
                                                      );
                                                    },
                                                  );
                                                  final baseAlignment = self
                                                      ? Alignment.centerRight
                                                      : Alignment.centerLeft;
                                                  final targetAlignment =
                                                      isSingleSelection
                                                          ? Alignment.center
                                                          : baseAlignment;
                                                  final shadowedBubble =
                                                      ConstrainedBox(
                                                    constraints:
                                                        bubbleConstraints,
                                                    child: bubble,
                                                  );
                                                  final alignedBubble =
                                                      AnimatedAlign(
                                                    duration:
                                                        _bubbleFocusDuration,
                                                    curve: _bubbleFocusCurve,
                                                    alignment: targetAlignment,
                                                    child: shadowedBubble,
                                                  );
                                                  final canResend =
                                                      message.status ==
                                                          MessageStatus.failed;
                                                  final canEdit =
                                                      message.status ==
                                                          MessageStatus.failed;
                                                  final includeSelectAction =
                                                      !_multiSelectActive;
                                                  List<GlobalKey>?
                                                      actionButtonKeys;
                                                  if (isSingleSelection) {
                                                    const baseActionCount = 6;
                                                    final actionCount =
                                                        baseActionCount +
                                                            (canResend
                                                                ? 1
                                                                : 0) +
                                                            (canEdit ? 1 : 0) +
                                                            (includeSelectAction
                                                                ? 1
                                                                : 0);
                                                    actionButtonKeys =
                                                        List.generate(
                                                            actionCount,
                                                            (_) => GlobalKey());
                                                    _selectionActionButtonKeys
                                                      ..clear()
                                                      ..addAll(
                                                          actionButtonKeys);
                                                  } else if (_selectedMessageId ==
                                                      messageModel.stanzaID) {
                                                    _selectionActionButtonKeys
                                                        .clear();
                                                  }
                                                  final actionBar =
                                                      _MessageActionBar(
                                                    onReply: () {
                                                      context
                                                          .read<ChatBloc>()
                                                          .add(
                                                            ChatQuoteRequested(
                                                              messageModel,
                                                            ),
                                                          );
                                                      _focusNode.requestFocus();
                                                      _clearAllSelections();
                                                    },
                                                    onForward: () =>
                                                        _handleForward(
                                                            messageModel),
                                                    onCopy: () => _copyMessage(
                                                      dashMessage: message,
                                                      model: messageModel,
                                                    ),
                                                    onShare: () =>
                                                        _shareMessage(
                                                      dashMessage: message,
                                                      model: messageModel,
                                                    ),
                                                    onAddToCalendar: () =>
                                                        _handleAddToCalendar(
                                                      dashMessage: message,
                                                      model: messageModel,
                                                    ),
                                                    onDetails: () =>
                                                        _showMessageDetails(
                                                            message),
                                                    onSelect:
                                                        includeSelectAction
                                                            ? () =>
                                                                _startMultiSelect(
                                                                  messageModel,
                                                                )
                                                            : null,
                                                    onResend: canResend
                                                        ? () => context
                                                            .read<ChatBloc>()
                                                            .add(
                                                              ChatMessageResendRequested(
                                                                messageModel,
                                                              ),
                                                            )
                                                        : null,
                                                    onEdit: canEdit
                                                        ? () => unawaited(
                                                              _handleEditMessage(
                                                                messageModel,
                                                              ),
                                                            )
                                                        : null,
                                                    hitRegionKeys:
                                                        actionButtonKeys,
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
                                                    top: attachmentTopPadding,
                                                    bottom:
                                                        attachmentBottomPadding,
                                                    left:
                                                        _chatHorizontalPadding,
                                                    right:
                                                        _chatHorizontalPadding,
                                                  );
                                                  final attachments =
                                                      AnimatedSwitcher(
                                                    duration:
                                                        _bubbleFocusDuration,
                                                    switchInCurve:
                                                        _bubbleFocusCurve,
                                                    switchOutCurve:
                                                        Curves.easeInCubic,
                                                    layoutBuilder: (
                                                      currentChild,
                                                      previousChildren,
                                                    ) {
                                                      return Stack(
                                                        clipBehavior: Clip.none,
                                                        alignment:
                                                            Alignment.topCenter,
                                                        children: [
                                                          ...previousChildren,
                                                          if (currentChild !=
                                                              null)
                                                            currentChild,
                                                        ],
                                                      );
                                                    },
                                                    transitionBuilder:
                                                        (child, animation) {
                                                      final slideAnimation =
                                                          Tween<Offset>(
                                                        begin: const Offset(
                                                            0, -0.05),
                                                        end: Offset.zero,
                                                      ).animate(animation);
                                                      return FadeTransition(
                                                        opacity: animation,
                                                        child: SizeTransition(
                                                          sizeFactor: animation,
                                                          axisAlignment: -1,
                                                          child:
                                                              SlideTransition(
                                                            position:
                                                                slideAnimation,
                                                            child: child,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    child: isSingleSelection
                                                        ? KeyedSubtree(
                                                            key: attachmentsKey,
                                                            child: Padding(
                                                              padding:
                                                                  attachmentPadding,
                                                              child: Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  actionBar,
                                                                  if (showReactionManager)
                                                                    const SizedBox(
                                                                      height:
                                                                          20,
                                                                    ),
                                                                  if (showReactionManager)
                                                                    KeyedSubtree(
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
                                                                    ),
                                                                ],
                                                              ),
                                                            ),
                                                          )
                                                        : const SizedBox
                                                            .shrink(),
                                                  );
                                                  final messageKey =
                                                      _messageKeys.putIfAbsent(
                                                    messageModel.stanzaID,
                                                    () => GlobalKey(),
                                                  );
                                                  final bubbleDisplay =
                                                      isRenderableBubble
                                                          ? _MessageArrivalAnimator(
                                                              key: ValueKey(
                                                                'arrival-${messageModel.stanzaID}',
                                                              ),
                                                              animate:
                                                                  _shouldAnimateMessage(
                                                                messageModel
                                                                    .stanzaID,
                                                              ),
                                                              isSelf: self,
                                                              child:
                                                                  alignedBubble,
                                                            )
                                                          : alignedBubble;
                                                  final selectableBubble =
                                                      GestureDetector(
                                                    behavior: HitTestBehavior
                                                        .translucent,
                                                    onTap: () {
                                                      if (_multiSelectActive) {
                                                        _toggleMultiSelectMessage(
                                                          messageModel,
                                                        );
                                                      } else if (isSingleSelection) {
                                                        _clearMessageSelection();
                                                      }
                                                    },
                                                    onLongPress: widget.readOnly
                                                        ? null
                                                        : () =>
                                                            _toggleMessageSelection(
                                                              messageModel,
                                                            ),
                                                    child: bubbleDisplay,
                                                  );
                                                  final animatedStack =
                                                      AnimatedSize(
                                                    duration:
                                                        _bubbleFocusDuration,
                                                    curve: _bubbleFocusCurve,
                                                    clipBehavior: Clip.none,
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        selectableBubble,
                                                        attachments,
                                                      ],
                                                    ),
                                                  );
                                                  Widget bubbleWithSlack =
                                                      animatedStack;
                                                  bubbleWithSlack = Align(
                                                    alignment: Alignment.center,
                                                    child: SizedBox(
                                                      width: messageRowMaxWidth,
                                                      child: bubbleWithSlack,
                                                    ),
                                                  );
                                                  return KeyedSubtree(
                                                    key: messageKey,
                                                    child: Padding(
                                                      padding: outerPadding,
                                                      child: bubbleWithSlack,
                                                    ),
                                                  );
                                                },
                                              ),
                                              messageListOptions:
                                                  dashMessageListOptions,
                                              readOnly: true,
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
                                              isEmailTransport: isDefaultEmail,
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
                                              onRecipientBarSizeChanged:
                                                  _handleRecipientBarSizeChanged,
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
                                                  _composerAccessories,
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
    return showModalBottomSheet<String>(
      context: context,
      builder: (context) => SizedBox(
        height: 320,
        child: EmojiPicker(
          config: Config(
            emojiViewConfig: EmojiViewConfig(
              emojiSizeMax: context.read<Policy>().getMaxEmojiSize(),
            ),
          ),
          onEmojiSelected: (_, emoji) => Navigator.of(context).pop(emoji.emoji),
        ),
      ),
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

  Future<void> _shareMessage({
    required ChatMessage dashMessage,
    required Message model,
  }) async {
    final content = (model.body ?? dashMessage.text).trim();
    if (content.isEmpty) {
      _showSnackbar('Message has no text to share');
      return;
    }
    final chatTitle =
        context.read<ChatBloc>().state.chat?.title ?? 'Axichat message';
    await Share.share(
      content,
      subject: 'Shared from $chatTitle',
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
    _clearAllSelections();
    final seededText = (model.body ?? dashMessage.text).trim();
    if (seededText.isEmpty) {
      _showSnackbar('Message has no text to add to calendar');
      return;
    }

    final calendarBloc = context.read<CalendarBloc?>();
    if (calendarBloc == null) {
      _showSnackbar('Calendar is unavailable right now');
      return;
    }
    final CalendarBloc availableCalendarBloc = calendarBloc;

    final locationHelper =
        LocationAutocompleteHelper.fromState(availableCalendarBloc.state);

    await showQuickAddModal(
      context: context,
      prefilledText: seededText,
      locationHelper: locationHelper,
      onTaskAdded: (task) {
        availableCalendarBloc.add(
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
    final joined = _joinedMessageText(messages);
    if (joined.isEmpty) {
      _showSnackbar('Selected messages have no text to copy');
      return;
    }
    await Clipboard.setData(ClipboardData(text: joined));
    _clearMultiSelection();
  }

  Future<void> _shareSelectedMessages(List<Message> messages) async {
    final joined = _joinedMessageText(messages).trim();
    if (joined.isEmpty) {
      _showSnackbar('Selected messages have no text to share');
      return;
    }
    final chatTitle =
        context.read<ChatBloc>().state.chat?.title ?? 'Axichat message';
    await Share.share(
      joined,
      subject: 'Shared from $chatTitle',
    );
    _clearMultiSelection();
  }

  Future<void> _forwardSelectedMessages(List<Message> messages) async {
    if (messages.isEmpty) return;
    final target = await _selectForwardTarget();
    if (!mounted || target == null) return;
    for (final message in messages) {
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
    final joined = _joinedMessageText(messages).trim();
    if (joined.isEmpty) {
      _showSnackbar('Selected messages have no text to add to calendar');
      return;
    }
    final calendarBloc = context.read<CalendarBloc?>();
    if (calendarBloc == null) {
      _showSnackbar('Calendar is unavailable right now');
      return;
    }
    final CalendarBloc availableCalendarBloc = calendarBloc;
    final locationHelper =
        LocationAutocompleteHelper.fromState(availableCalendarBloc.state);
    await showQuickAddModal(
      context: context,
      prefilledText: joined,
      locationHelper: locationHelper,
      onTaskAdded: (task) {
        availableCalendarBloc.add(
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
    final chatsCubit = context.read<ChatsCubit?>();
    final items = chatsCubit?.state.items;
    if (items == null || items.isEmpty) return null;
    final currentJid = context.read<ChatBloc>().jid;
    final options = items
        .where((chat) => chat.jid != currentJid)
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
                    'Forward to...',
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
                      title: Text(chat.title),
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
    final label = chat.contactDisplayName ?? chat.title;
    final trimmed = label.trim();
    final initialCode = trimmed.isEmpty ? null : trimmed.runes.first;
    final initial = initialCode == null
        ? '?'
        : String.fromCharCode(initialCode).toUpperCase();
    final background = stringToColor(chat.jid);
    final textColor = colors.background;
    return Container(
      width: _recipientAvatarSize,
      height: _recipientAvatarSize,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(
          color: colors.card,
          width: 1.6,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: _recipientAvatarSize * 0.45,
            fontWeight: FontWeight.w600,
            color: textColor,
            letterSpacing: 0.5,
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
    required this.isEmailTransport,
    required this.composerHasText,
    required this.subjectController,
    required this.subjectFocusNode,
    required this.textController,
    required this.textFocusNode,
    required this.onSubjectSubmitted,
    required this.onRecipientBarSizeChanged,
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
  });

  final String hintText;
  final List<ComposerRecipient> recipients;
  final List<chat_models.Chat> availableChats;
  final Map<String, FanOutRecipientState> latestStatuses;
  final List<PendingAttachment> pendingAttachments;
  final bool isEmailTransport;
  final bool composerHasText;
  final TextEditingController subjectController;
  final FocusNode subjectFocusNode;
  final TextEditingController textController;
  final FocusNode textFocusNode;
  final VoidCallback onSubjectSubmitted;
  final ValueChanged<Size> onRecipientBarSizeChanged;
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    const horizontalPadding = _composerHorizontalInset;
    final hasQueuedAttachments = pendingAttachments.any(
      (attachment) => attachment.status == PendingAttachmentStatus.queued,
    );
    final hasSubjectText = subjectController.text.trim().isNotEmpty;
    final sendEnabled =
        composerHasText || hasQueuedAttachments || hasSubjectText;
    final subjectHeader = _SubjectTextField(
      controller: subjectController,
      focusNode: subjectFocusNode,
      onSubmitted: onSubjectSubmitted,
    );
    final showAttachmentTray =
        isEmailTransport && pendingAttachments.isNotEmpty;
    final commandSurface =
        EnvScope.maybeOf(context)?.commandSurface ?? CommandSurface.sheet;
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
              padding: const EdgeInsets.fromLTRB(
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
                  ChatCutoutComposer(
                    controller: textController,
                    focusNode: textFocusNode,
                    hintText: hintText,
                    semanticsLabel: 'Message input',
                    onSend: onSend,
                    header: subjectHeader,
                    actions: buildComposerAccessories(
                      canSend: sendEnabled,
                    ),
                    sendEnabled: sendEnabled,
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
        const _ComposerNotice(
          type: _ComposerNoticeType.warning,
          message:
              'Large attachments are sent separately to each recipient and may take longer to deliver.',
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
        final label = failedCount == 1 ? 'recipient' : 'recipients';
        final subjectLabel = report.subject?.trim();
        final hasSubjectLabel = subjectLabel?.isNotEmpty == true;
        final failureMessage = hasSubjectLabel
            ? 'Subject "$subjectLabel" failed to send to $failedCount $label.'
            : 'Failed to send to $failedCount $label.';
        notices.add(
          _ComposerNotice(
            type: _ComposerNoticeType.info,
            message: failureMessage,
            actionLabel: 'Retry',
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
      _SizeReportingWidget(
        onSizeChanged: onRecipientBarSizeChanged,
        child: RecipientChipsBar(
          recipients: recipients,
          availableChats: availableChats,
          latestStatuses: latestStatuses,
          collapsedByDefault: true,
          onRecipientAdded: onRecipientAdded,
          onRecipientRemoved: onRecipientRemoved,
          onRecipientToggled: onRecipientToggled,
        ),
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
    final subjectStyle = context.textTheme.p.copyWith(
      fontSize: 15,
      height: 1.05,
      fontWeight: FontWeight.w600,
      color: colors.foreground,
    );
    return SizedBox(
      height: 28,
      child: Semantics(
        label: 'Email subject',
        textField: true,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.sentences,
          cursorColor: colors.primary,
          onSubmitted: (_) => onSubmitted(),
          style: subjectStyle,
          decoration: InputDecoration(
            hintText: 'Subject',
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
                        'Read only',
                        style: context.textTheme.small.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unarchive to send new messages.',
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
        tooltip: 'Emoji picker',
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
      tooltip: 'Attachments',
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
      tooltip: 'Send message',
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
    final minButtonExtent = scaled(50);
    final splashRadius = scaled(24);
    final button = IconButton(
      icon: Icon(icon, size: scaled(24), color: iconColor),
      tooltip: tooltip,
      onPressed: onPressed,
      splashRadius: splashRadius,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: minButtonExtent,
        minHeight: minButtonExtent,
      ),
      visualDensity: VisualDensity.compact,
    );
    Widget interactiveChild = DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.card,
        shape: SquircleBorder(
          cornerRadius: scaled(14),
          side: BorderSide(color: colors.border, width: scaled(1.4)),
        ),
      ),
      child: button,
    ).withTapBounce(enabled: onPressed != null);
    if (onLongPress != null) {
      interactiveChild = GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onLongPress: onLongPress,
        child: interactiveChild,
      );
    }
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: tooltip,
      onTap: onPressed,
      onLongPress: onLongPress,
      child: interactiveChild,
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
    required this.onForward,
    required this.onCopy,
    required this.onShare,
    required this.onAddToCalendar,
    required this.onDetails,
    required this.onSelect,
    this.onResend,
    this.onEdit,
    this.hitRegionKeys,
  });

  final VoidCallback onReply;
  final VoidCallback onForward;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onAddToCalendar;
  final VoidCallback onDetails;
  final VoidCallback? onSelect;
  final VoidCallback? onResend;
  final VoidCallback? onEdit;
  final List<GlobalKey>? hitRegionKeys;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.of(context).textScaler;
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
        label: 'Reply',
        onPressed: onReply,
      ),
      ContextActionButton(
        key: nextKey(),
        icon: Transform.scale(
          scaleX: -1,
          child: const Icon(LucideIcons.reply, size: 16),
        ),
        label: 'Forward',
        onPressed: onForward,
      ),
      if (onResend != null)
        ContextActionButton(
          key: nextKey(),
          icon: const Icon(LucideIcons.repeat, size: 16),
          label: 'Resend',
          onPressed: onResend!,
        ),
      if (onEdit != null)
        ContextActionButton(
          key: nextKey(),
          icon: const Icon(LucideIcons.pencilLine, size: 16),
          label: 'Edit',
          onPressed: onEdit!,
        ),
      ContextActionButton(
        key: nextKey(),
        icon: const Icon(LucideIcons.copy, size: 16),
        label: 'Copy',
        onPressed: onCopy,
      ),
      ContextActionButton(
        key: nextKey(),
        icon: const Icon(LucideIcons.share2, size: 16),
        label: 'Share',
        onPressed: onShare,
      ),
      ContextActionButton(
        key: nextKey(),
        icon: const Icon(LucideIcons.calendarPlus, size: 16),
        label: 'Add to calendar',
        onPressed: onAddToCalendar,
      ),
      ContextActionButton(
        key: nextKey(),
        icon: const Icon(LucideIcons.info, size: 16),
        label: 'Details',
        onPressed: onDetails,
      ),
    ];
    if (onSelect != null) {
      actions.add(
        ContextActionButton(
          key: nextKey(),
          icon: const Icon(LucideIcons.squareCheck, size: 16),
          label: 'Select',
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
    required this.child,
    required this.animate,
    required this.isSelf,
    super.key,
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
                label: 'Forward',
                onPressed: onForward,
              ),
              ContextActionButton(
                icon: const Icon(LucideIcons.copy, size: 16),
                label: 'Copy',
                onPressed: onCopy,
              ),
              ContextActionButton(
                icon: const Icon(LucideIcons.share2, size: 16),
                label: 'Share',
                onPressed: onShare,
              ),
              ContextActionButton(
                icon: const Icon(LucideIcons.calendarPlus, size: 16),
                label: 'Add to calendar',
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
          'React',
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
    final animationDuration = context.watch<SettingsCubit>().animationDuration;
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
      duration: animationDuration,
      reverseDuration: animationDuration,
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
    final textScaler = MediaQuery.of(context).textScaler;
    final iconSize = textScaler.scale(16);
    final showDirectOnly = state.viewFilter == MessageTimelineFilter.directOnly;
    final notificationsEnabled = !chat.muted;
    final isSpamChat = chat.spam;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        ContextActionButton(
          icon: Icon(
            showDirectOnly ? LucideIcons.user : LucideIcons.users,
            size: iconSize,
          ),
          label: showDirectOnly ? 'Showing direct only' : 'Showing all',
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
              ? 'Mute notifications'
              : 'Enable notifications',
          onPressed: () => onToggleNotifications(!notificationsEnabled),
        ),
        ContextActionButton(
          icon: Icon(
            isSpamChat ? LucideIcons.inbox : LucideIcons.flag,
            size: iconSize,
          ),
          label: isSpamChat ? 'Move to inbox' : 'Report spam',
          destructive: !isSpamChat,
          onPressed: () => onSpamToggle(!isSpamChat),
        ),
        _BlockActionButton(
          jid: chat.jid,
          emailAddress: chat.emailAddress,
          useEmailBlocking: chat.defaultTransport.isEmail,
        ),
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
          label: 'Block',
          destructive: true,
          onPressed: null,
        );
      }
      final EmailService service = emailService;
      final target = address!;
      return ContextActionButton(
        icon: icon,
        label: 'Block',
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
          label: 'Block',
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
                'No reactions yet',
                style: textTheme.small.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
            Text(
              hasReactions
                  ? 'Tap a reaction to add or remove yours'
                  : 'Pick an emoji to react',
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
          const Text('More'),
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
              isSelf ? 'You' : message.senderJid,
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
                  previewText ?? '(no content)',
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
                  'Replying to...',
                  style: context.textTheme.small.copyWith(
                    color: colors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isSelf ? 'You' : message.senderJid,
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
                      previewText ?? '(no content)',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.small,
                    );
                  },
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(LucideIcons.x),
            color: colors.mutedForeground,
            tooltip: 'Cancel reply',
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

class _GuestChatState extends State<GuestChat> {
  final _emojiPopoverController = ShadPopoverController();
  final _encryptionPopoverController = ShadPopoverController();
  late FocusNode _focusNode;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _textController.dispose();
    _emojiPopoverController.dispose();
    _encryptionPopoverController.dispose();
    super.dispose();
  }

  final user = ChatUser(id: 'me', firstName: 'You');

  final messages = <ChatMessage>[
    ChatMessage(
      user: ChatUser(id: 'axichat', firstName: appDisplayName),
      createdAt: DateTime.now(),
      text: 'Open a chat! Unless you just want to talk to yourself.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.background,
        border: Border(
          left: BorderSide(color: context.colorScheme.border),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < smallScreen;
          return DashChat(
            currentUser: user,
            onSend: (message) {
              setState(() => messages.insert(0, message));
              _focusNode.requestFocus();
            },
            messages: messages
                .map(
                  (e) => ChatMessage(
                    user: e.user,
                    createdAt: e.createdAt,
                    text: e.text,
                    status: MessageStatus.sent,
                  ),
                )
                .toList(),
            messageOptions: MessageOptions(
              showOtherUsersAvatar: false,
              borderRadius: 0,
              maxWidth: constraints.maxWidth * (isCompact ? 0.8 : 0.7),
              messagePadding: EdgeInsets.zero,
              currentUserContainerColor: Colors.transparent,
              containerColor: Colors.transparent,
              userNameBuilder: (user) {
                return Padding(
                  padding: const EdgeInsets.only(left: 2.0, bottom: 2.0),
                  child: Text(
                    user.getFullName(),
                    style: context.textTheme.muted.copyWith(fontSize: 12.0),
                  ),
                );
              },
              messageTextBuilder: (message, _, __) {
                final colors = context.colorScheme;
                final chatTokens = context.chatTheme;
                final self = message.user.id == user.id;
                final textColor =
                    self ? colors.primaryForeground : colors.foreground;
                final timestampColor = chatTokens.timestamp;
                final iconFamily = message.status!.icon.fontFamily;
                final iconPackage = message.status!.icon.fontPackage;
                const iconSize = 12.0;
                return DecoratedBox(
                  decoration: _bubbleDecoration(
                    background: self ? colors.primary : colors.card,
                    borderColor:
                        self ? Colors.transparent : chatTokens.recvEdge,
                  ),
                  child: Padding(
                    padding: _bubblePadding,
                    child: DynamicInlineText(
                      key: ValueKey(message.createdAt.microsecondsSinceEpoch),
                      text: TextSpan(
                        text: message.text,
                        style: context.textTheme.small.copyWith(
                          color: textColor,
                        ),
                      ),
                      details: [
                        TextSpan(
                          text:
                              '${message.createdAt.hour.toString().padLeft(2, '0')}:'
                              '${message.createdAt.minute.toString().padLeft(2, '0')}',
                          style: context.textTheme.muted.copyWith(
                            color: self
                                ? colors.primaryForeground
                                : timestampColor,
                            fontSize: iconSize,
                          ),
                        ),
                        if (self)
                          TextSpan(
                            text: String.fromCharCode(
                              message.status!.icon.codePoint,
                            ),
                            style: TextStyle(
                              color: colors.primaryForeground,
                              fontSize: iconSize,
                              fontFamily: iconFamily,
                              package: iconPackage,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            inputOptions: InputOptions(
              sendOnEnter: true,
              alwaysShowSend: true,
              focusNode: _focusNode,
              textController: _textController,
              sendButtonBuilder: (send) => ShadIconButton.ghost(
                onPressed: send,
                icon: const Icon(
                  Icons.send,
                  size: 24,
                ),
              ).withTapBounce(),
              inputDecoration: _chatInputDecoration(
                context,
                hintText: 'Send a message',
              ),
              inputToolbarStyle: BoxDecoration(
                color: context.colorScheme.background,
                border: Border(
                  top: BorderSide(color: context.colorScheme.border),
                ),
              ),
              inputToolbarMargin: EdgeInsets.zero,
              leading: [
                ShadPopover(
                  controller: _emojiPopoverController,
                  child: ShadIconButton.ghost(
                    onPressed: _emojiPopoverController.toggle,
                    icon: const Icon(
                      LucideIcons.smile,
                      size: 24,
                    ),
                  ).withTapBounce(),
                  popover: (context) => EmojiPicker(
                    textEditingController: _textController,
                    config: Config(
                      emojiViewConfig: EmojiViewConfig(
                        emojiSizeMax: context.read<Policy>().getMaxEmojiSize(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
