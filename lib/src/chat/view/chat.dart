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
import 'package:axichat/src/chat/bloc/chat_transport_cubit.dart';
import 'package:axichat/src/chat/models/pending_attachment.dart';
import 'package:axichat/src/chat/view/chat_alert.dart';
import 'package:axichat/src/chat/view/chat_attachment_preview.dart';
import 'package:axichat/src/chat/view/chat_bubble_surface.dart';
import 'package:axichat/src/chat/view/chat_cutout_composer.dart';
import 'package:axichat/src/chat/view/chat_drawer.dart';
import 'package:axichat/src/chat/view/chat_message_details.dart';
import 'package:axichat/src/chat/view/pending_attachment_list.dart';
import 'package:axichat/src/chat/view/recipient_chips_bar.dart';
import 'package:axichat/src/chat/view/transport_glyph.dart';
import 'package:axichat/src/chat/view/message_text_parser.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/bool_tool.dart';
import 'package:axichat/src/common/policy.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/context_action_button.dart';
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
const _reactionCutoutThickness = 34.0;
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
const _selectionCutoutDepth = 18.0;
const _selectionCutoutRadius = 16.0;
const _selectionCutoutPadding = EdgeInsets.fromLTRB(8, 6, 8, 8);
const _selectionCutoutOffset = Offset(0, -4);
const _selectionCutoutThickness = 44.0;
const _recipientBubbleInset = _recipientCutoutDepth;
const _recipientOverflowGap = 6.0;
const _bubbleFocusDuration = Duration(milliseconds: 620);
const _bubbleFocusCurve = Curves.easeOutCubic;
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

  var _chatRoute = _ChatRoute.main;
  String? _selectedMessageId;
  final _multiSelectedMessageIds = <String>{};
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

  void _handleSubjectChanged() {
    final text = _subjectController.text;
    if (_lastSubjectValue == text) {
      return;
    }
    _lastSubjectValue = text;
    context.read<ChatBloc>().add(ChatSubjectChanged(text));
  }

  Widget? _buildSubjectField(
    BuildContext context, {
    required bool isEmailTransport,
  }) {
    if (!isEmailTransport) {
      return null;
    }
    final colors = context.colorScheme;
    return TextField(
      controller: _subjectController,
      focusNode: _subjectFocusNode,
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => _focusNode.requestFocus(),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.foreground,
          ),
      decoration: InputDecoration(
        hintText: 'Subject',
        hintStyle: context.textTheme.muted.copyWith(
          color: colors.mutedForeground,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isCollapsed: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
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
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (dialogContext) => ShadDialog(
        title: const Text('Load attachment?'),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ).withTapBounce(),
          ShadButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Load'),
          ).withTapBounce(),
        ],
        child: Text(
          'Only load attachments from contacts you trust.\n\n'
          '$displaySender is not in your contacts yet. Continue?',
          style: dialogContext.textTheme.small,
        ),
      ),
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
    final approved = await showShadDialog<bool>(
      context: context,
      builder: (dialogContext) => ShadDialog(
        title: const Text('Open external link?'),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ).withTapBounce(),
          ShadButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Open link'),
          ).withTapBounce(),
        ],
        child: Text(
          'You are about to open:\n$trimmed\n\n'
          'Only tap OK if you trust the site (host: $host).',
          style: dialogContext.textTheme.small,
        ),
      ),
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
    final isEmailTransport = context.read<ChatTransportCubit>().state.isEmail;
    final hasSubject = _subjectController.text.trim().isNotEmpty;
    final canSend = text.isNotEmpty ||
        (isEmailTransport && (hasQueuedAttachments || hasSubject));
    if (!canSend) return;
    bloc.add(ChatMessageSent(text: text));
    if (text.isNotEmpty) {
      _textController.clear();
    }
    _focusNode.requestFocus();
  }

  Widget _buildComposer({
    required bool isEmailTransport,
    required MessageTransport activeTransport,
    required bool emailCapable,
    required bool xmppCapable,
    required String hintText,
    required List<ComposerRecipient> recipients,
    required List<chat_models.Chat> availableEmailChats,
    required Map<String, FanOutRecipientState> latestStatuses,
    required List<PendingAttachment> pendingAttachments,
    String? composerError,
    bool showAttachmentWarning = false,
    FanOutSendReport? retryReport,
    String? retryShareId,
  }) {
    if (widget.readOnly) {
      _ensureRecipientBarHeightCleared();
      return _buildReadOnlyBanner();
    }
    final colors = context.colorScheme;
    const horizontalPadding = _composerHorizontalInset;
    final hasQueuedAttachments = pendingAttachments.any(
      (attachment) => attachment.status == PendingAttachmentStatus.queued,
    );
    final hasSubjectText = _subjectController.text.trim().isNotEmpty;
    final sendEnabled = _composerHasText ||
        (isEmailTransport && (hasQueuedAttachments || hasSubjectText));
    Widget? attachmentTray;
    final subjectHeader = _buildSubjectField(
      context,
      isEmailTransport: isEmailTransport,
    );
    final showAttachmentTray =
        isEmailTransport && pendingAttachments.isNotEmpty;
    if (showAttachmentTray) {
      attachmentTray = PendingAttachmentList(
        attachments: pendingAttachments,
        onRetry: (id) =>
            context.read<ChatBloc>().add(ChatAttachmentRetryRequested(id)),
        onRemove: (id) =>
            context.read<ChatBloc>().add(ChatPendingAttachmentRemoved(id)),
        onPressed: _handlePendingAttachmentPressed,
        onLongPress: _handlePendingAttachmentLongPressed,
      );
    }
    Widget composer = SafeArea(
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
                    controller: _textController,
                    focusNode: _focusNode,
                    hintText: hintText,
                    onSend: _handleSendMessage,
                    header: subjectHeader,
                    actions: _buildComposerAccessories(
                      activeTransport: activeTransport,
                      emailCapable: emailCapable,
                      xmppCapable: xmppCapable,
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
    if (!isEmailTransport) {
      _ensureRecipientBarHeightCleared();
      return composer;
    }
    final notices = <Widget>[];
    if (composerError != null && composerError.isNotEmpty) {
      notices.add(
        _ComposerNotice(
          type: _ComposerNoticeType.error,
          message: composerError,
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
    if (retryReport != null && retryShareId != null) {
      final failedCount = retryReport.statuses
          .where((status) => status.state == FanOutRecipientState.failed)
          .length;
      if (failedCount > 0) {
        final label = failedCount == 1 ? 'recipient' : 'recipients';
        final subjectLabel = retryReport.subject?.trim();
        final hasSubjectLabel = subjectLabel?.isNotEmpty == true;
        final failureMessage = hasSubjectLabel
            ? 'Subject "$subjectLabel" failed to send to $failedCount $label.'
            : 'Failed to send to $failedCount $label.';
        notices.add(
          _ComposerNotice(
            type: _ComposerNoticeType.info,
            message: failureMessage,
            actionLabel: 'Retry',
            onAction: () => context
                .read<ChatBloc>()
                .add(ChatFanOutRetryRequested(retryShareId)),
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
        onSizeChanged: _handleRecipientBarSizeChanged,
        child: RecipientChipsBar(
          recipients: recipients,
          availableChats: availableEmailChats,
          latestStatuses: latestStatuses,
          onRecipientAdded: (target) =>
              context.read<ChatBloc>().add(ChatComposerRecipientAdded(target)),
          onRecipientRemoved: (key) =>
              context.read<ChatBloc>().add(ChatComposerRecipientRemoved(key)),
          onRecipientToggled: (key) =>
              context.read<ChatBloc>().add(ChatComposerRecipientToggled(key)),
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

  Widget _buildReadOnlyBanner() {
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

  List<ChatComposerAccessory> _buildComposerAccessories({
    required MessageTransport activeTransport,
    required bool emailCapable,
    required bool xmppCapable,
    required bool canSend,
  }) {
    final accessories = <ChatComposerAccessory>[];
    if (activeTransport.isXmpp) {
      accessories.add(
        ChatComposerAccessory.leading(child: _buildEmojiButton()),
      );
    }
    accessories.add(
      ChatComposerAccessory.leading(
        child:
            _buildAttachmentButton(isEmailTransport: activeTransport.isEmail),
      ),
    );
    accessories.add(
      ChatComposerAccessory.trailing(
        child: _buildSendButton(
          enabled: canSend,
          transport: activeTransport,
          emailCapable: emailCapable,
          xmppCapable: xmppCapable,
        ),
      ),
    );
    return accessories;
  }

  Widget _buildEmojiButton() {
    return ShadPopover(
      controller: _emojiPopoverController,
      child: _cutoutIconButton(
        icon: LucideIcons.smile,
        tooltip: 'Emoji picker',
        onPressed: _emojiPopoverController.toggle,
      ),
      popover: (context) => EmojiPicker(
        textEditingController: _textController,
        config: Config(
          emojiViewConfig: EmojiViewConfig(
            emojiSizeMax: context.read<Policy>().getMaxEmojiSize(),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentButton({required bool isEmailTransport}) {
    return _cutoutIconButton(
      icon: LucideIcons.paperclip,
      tooltip: 'Attachments',
      onPressed: isEmailTransport
          ? (_sendingAttachment ? null : _handleAttachmentPressed)
          : () => _showAttachmentInfoDialog(
                isEmailTransport: isEmailTransport,
              ),
    );
  }

  Widget _buildSendButton({
    required bool enabled,
    required MessageTransport transport,
    required bool emailCapable,
    required bool xmppCapable,
  }) {
    final colors = context.colorScheme;
    final options = <MessageTransport>[];
    if (xmppCapable) options.add(MessageTransport.xmpp);
    if (emailCapable) options.add(MessageTransport.email);
    final menuEnabled = options.length > 1;
    final tooltip = menuEnabled
        ? 'Send message (long press to switch transport)'
        : 'Send message';
    final button = _cutoutIconButton(
      tooltip: tooltip,
      activeColor: colors.primary,
      onPressed: enabled ? _handleSendMessage : null,
      iconBuilder: (iconColor) => Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(LucideIcons.send, size: 24, color: iconColor),
          Positioned(
            right: -4,
            bottom: -4,
            child: TransportGlyph(
              transport: transport,
            ),
          ),
        ],
      ),
    );
    if (!menuEnabled) {
      return button;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) => _showTransportMenu(
        anchor: details.globalPosition,
        options: options,
        activeTransport: transport,
      ),
      child: button,
    );
  }

  Future<void> _showTransportMenu({
    required Offset anchor,
    required List<MessageTransport> options,
    required MessageTransport activeTransport,
  }) async {
    if (!mounted) return;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final position = RelativeRect.fromLTRB(
      anchor.dx,
      anchor.dy,
      overlay.size.width - anchor.dx,
      overlay.size.height - anchor.dy,
    );
    final colors = context.colorScheme;
    final selection = await showMenu<MessageTransport>(
      context: context,
      position: position,
      items: options
          .map(
            (option) => PopupMenuItem<MessageTransport>(
              value: option,
              child: Row(
                children: [
                  Icon(
                    option.isEmail
                        ? LucideIcons.mail
                        : LucideIcons.messageCircle,
                    size: 16,
                    color: option.isEmail ? colors.destructive : colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(option.label)),
                  if (option == activeTransport)
                    Icon(
                      LucideIcons.check,
                      size: 16,
                      color: colors.primary,
                    ),
                ],
              ),
            ),
          )
          .toList(),
    );
    if (selection != null && mounted) {
      context.read<ChatBloc>().add(ChatTransportChanged(selection));
    }
  }

  Widget _cutoutIconButton({
    IconData? icon,
    Widget Function(Color iconColor)? iconBuilder,
    required String tooltip,
    Color? activeColor,
    VoidCallback? onPressed,
  }) {
    assert(icon != null || iconBuilder != null, 'Provide an icon or builder.');
    final colors = context.colorScheme;
    final textScaler = MediaQuery.of(context).textScaler;
    double scaled(double value) => textScaler.scale(value);
    final iconColor = onPressed == null
        ? colors.mutedForeground
        : (activeColor ?? colors.foreground);
    final childIcon = iconBuilder != null
        ? iconBuilder(iconColor)
        : Icon(icon!, size: scaled(24), color: iconColor);
    final minButtonExtent = scaled(50);
    final splashRadius = scaled(24);
    final button = IconButton(
      icon: childIcon,
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
    final decorated = DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.card,
        shape: SquircleBorder(
          cornerRadius: scaled(14),
          side: BorderSide(color: colors.border, width: scaled(1.4)),
        ),
      ),
      child: button,
    );
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: tooltip,
      onTap: onPressed,
      child: decorated.withTapBounce(enabled: onPressed != null),
    );
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

  Future<void> _showAttachmentInfoDialog({
    required bool isEmailTransport,
  }) async {
    if (!mounted) return;
    final message = isEmailTransport
        ? 'Attachments are limited to trusted email chats.'
        : 'File uploads are on the roadmap. Inline previews for received files '
            'are available now.';
    await showShadDialog<void>(
      context: context,
      builder: (dialogContext) => ShadDialog(
        title: const Text('Attachments unavailable'),
        actions: [
          ShadButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ).withTapBounce(),
        ],
        child: Text(
          message,
          style: dialogContext.textTheme.small,
        ),
      ),
    );
  }

  void _handlePendingAttachmentPressed(PendingAttachment pending) {
    if (!mounted) return;
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

  void _toggleMessageSelection(String messageId) {
    if (widget.readOnly) return;
    if (_multiSelectActive) {
      _toggleMultiSelectMessage(messageId);
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

  void _startMultiSelect(String messageId) {
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
    });
  }

  void _toggleMultiSelectMessage(String messageId) {
    if (widget.readOnly) return;
    final mutated = _multiSelectedMessageIds.contains(messageId);
    setState(() {
      if (mutated) {
        _multiSelectedMessageIds.remove(messageId);
      } else {
        _multiSelectedMessageIds.add(messageId);
      }
    });
  }

  void _clearMultiSelection() {
    if (_multiSelectedMessageIds.isEmpty) return;
    setState(() {
      _multiSelectedMessageIds.clear();
    });
  }

  void _clearAllSelections() {
    _clearMessageSelection();
    _clearMultiSelection();
  }

  void _pruneMessageSelection(Set<String> availableIds) {
    if (_multiSelectActive) {
      final missing = _multiSelectedMessageIds
          .where((id) => !availableIds.contains(id))
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
  }

  List<Message> _collectSelectedMessages(List<Message> orderedMessages) {
    if (_multiSelectedMessageIds.isEmpty) return const [];
    final selected = <Message>[];
    for (final message in orderedMessages) {
      if (_multiSelectedMessageIds.contains(message.stanzaID)) {
        selected.add(message);
      }
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
                    ChatToastVariant.destructive => ShadToast.destructive(
                        title: const Text('Whoops'),
                        description: Text(toast.message),
                        alignment: Alignment.topRight,
                        showCloseIconOnlyWhenHovered: false,
                      ),
                    ChatToastVariant.warning => ShadToast(
                        title: const Text('Heads up'),
                        description: Text(toast.message),
                        alignment: Alignment.topRight,
                        showCloseIconOnlyWhenHovered: false,
                      ),
                    ChatToastVariant.info => ShadToast(
                        title: const Text('All set'),
                        description: Text(toast.message),
                        alignment: Alignment.topRight,
                        showCloseIconOnlyWhenHovered: false,
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
                final transport = context.watch<ChatTransportCubit>().state;
                final canUseEmail = (chatEntity?.deltaChatId != null) ||
                    (chatEntity?.emailAddress?.isNotEmpty ?? false);
                final isEmailChat = chatEntity?.deltaChatId != null;
                final isAxiCompatible = chatEntity?.isAxiContact ?? false;
                final canUseXmpp =
                    !canUseEmail || isAxiCompatible || chatEntity == null;
                final rosterContacts = context.watch<RosterCubit>().contacts;
                final isEmailTransport = canUseEmail && transport.isEmail;
                final currentUserId = isEmailTransport
                    ? (emailSelfJid ?? profile?.jid ?? '')
                    : (profile?.jid ?? '');
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
                final showCompatibilityBadge = canUseEmail && isAxiCompatible;
                final avatarBadge = showCompatibilityBadge
                    ? const AxiCompatibilityBadge(compact: true)
                    : AxiTransportChip(
                        transport: transport,
                        compact: true,
                      );
                final emailSuggestions =
                    (context.watch<ChatsCubit?>()?.state.items ??
                            const <chat_models.Chat>[])
                        .where((chat) => chat.transport.isEmail)
                        .toList();
                final user = ChatUser(
                  id: currentUserId,
                  firstName: profile?.username ?? '',
                );
                final spacerUser = ChatUser(
                  id: _selectionSpacerMessageId,
                  firstName: '',
                );
                return Container(
                  decoration: BoxDecoration(
                    color: context.colorScheme.background,
                    border: Border(
                      left: BorderSide(color: context.colorScheme.border),
                    ),
                  ),
                  child: Scaffold(
                    backgroundColor: context.colorScheme.background,
                    endDrawerEnableOpenDragGesture: false,
                    endDrawer: readOnly || jid == null
                        ? null
                        : ChatDrawer(
                            state: state,
                          ),
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
                                        });
                                      }
                                      if (_textController.text.isNotEmpty) {
                                        if (!isEmailTransport) {
                                          context
                                              .read<DraftCubit?>()
                                              ?.saveDraft(
                                                id: null,
                                                jids: [state.chat!.jid],
                                                body: _textController.text,
                                              );
                                        }
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
                                                ? AxiAvatar(jid: jid)
                                                : AxiAvatar(
                                                    jid: item.jid,
                                                    subscription:
                                                        item.subscription,
                                                    presence: item.presence,
                                                    status: item.status,
                                                  ),
                                          ),
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
                            Builder(
                              builder: (context) => AxiIconButton(
                                iconData: LucideIcons.settings,
                                onPressed: Scaffold.of(context).openEndDrawer,
                              ),
                            ),
                          ],
                        ] else
                          const SizedBox.shrink(),
                      ],
                    ),
                    body: Column(
                      children: [
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
                                        .where((e) =>
                                            e.body != null || e.error.isNotNone)
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
                                      }
                                      final bodyText = e.body;
                                      final errorLabel = e.error.asString;
                                      final renderedText = e.error.isNotNone
                                          ? '$errorLabel${bodyText?.isNotEmpty == true ? ': "${bodyText!.trim()}"' : ''}'
                                          : (bodyText ?? '');
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
                                            'body': e.body,
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
                                    final composerHintText = isEmailTransport
                                        ? 'Send email message'
                                        : 'Send ${state.chat?.encryptionProtocol.isNone ?? false ? 'plaintext' : 'encrypted'} message';
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
                                                  final canReact =
                                                      !isEmailTransport;
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
                                                    selectionOverlay =
                                                        SelectionIndicator(
                                                      visible: true,
                                                      selected:
                                                          isMultiSelection,
                                                      onPressed: () =>
                                                          _toggleMultiSelectMessage(
                                                        messageModel.stanzaID,
                                                      ),
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
                                                  final bubblePadding =
                                                      bubbleBottomInset > 0
                                                          ? _bubblePadding.add(
                                                              EdgeInsets.only(
                                                                bottom:
                                                                    bubbleBottomInset,
                                                              ),
                                                            )
                                                          : _bubblePadding;
                                                  final bubbleBorderRadius =
                                                      _bubbleBorderRadius(
                                                    isSelf: self,
                                                    chainedPrevious:
                                                        chainedPrev,
                                                    chainedNext: chainedNext,
                                                    isSelected: isSelected,
                                                  );
                                                  final bubbleMaxWidth =
                                                      clampedBubbleWidth;
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
                                                  final outerPadding =
                                                      EdgeInsets.only(
                                                    top: 2,
                                                    bottom: baseOuterBottom +
                                                        extraOuterBottom,
                                                    left:
                                                        _chatHorizontalPadding,
                                                    right:
                                                        _chatHorizontalPadding,
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
                                                                        _reactionCutoutThickness,
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
                                                  List<GlobalKey>?
                                                      actionButtonKeys;
                                                  if (isSingleSelection) {
                                                    const baseActionCount = 6;
                                                    final actionCount =
                                                        baseActionCount +
                                                            (canResend ? 1 : 0);
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
                                                    onSelect: _multiSelectActive
                                                        ? null
                                                        : () =>
                                                            _startMultiSelect(
                                                              messageModel
                                                                  .stanzaID,
                                                            ),
                                                    onResend: canResend
                                                        ? () => context
                                                            .read<ChatBloc>()
                                                            .add(
                                                              ChatMessageResendRequested(
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
                                                  final selectableBubble =
                                                      GestureDetector(
                                                    behavior: HitTestBehavior
                                                        .translucent,
                                                    onTap: () {
                                                      if (_multiSelectActive) {
                                                        _toggleMultiSelectMessage(
                                                          messageModel.stanzaID,
                                                        );
                                                      } else if (isSingleSelection) {
                                                        _clearMessageSelection();
                                                      }
                                                    },
                                                    onLongPress: widget.readOnly
                                                        ? null
                                                        : () =>
                                                            _toggleMessageSelection(
                                                              messageModel
                                                                  .stanzaID,
                                                            ),
                                                    child: alignedBubble,
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
                                          _MessageSelectionToolbar(
                                            count: selectedMessages.length,
                                            onClear: _clearMultiSelection,
                                            onCopy: () => _copySelectedMessages(
                                              List<Message>.of(
                                                selectedMessages,
                                              ),
                                            ),
                                            onShare: () =>
                                                _shareSelectedMessages(
                                              List<Message>.of(
                                                selectedMessages,
                                              ),
                                            ),
                                            onForward: () =>
                                                _forwardSelectedMessages(
                                              List<Message>.of(
                                                selectedMessages,
                                              ),
                                            ),
                                            onAddToCalendar: () =>
                                                _addSelectedToCalendar(
                                              List<Message>.of(
                                                selectedMessages,
                                              ),
                                            ),
                                          )
                                        else
                                          _buildComposer(
                                            isEmailTransport: isEmailTransport,
                                            activeTransport: transport,
                                            emailCapable: canUseEmail,
                                            xmppCapable: canUseXmpp,
                                            hintText: composerHintText,
                                            recipients: recipients,
                                            availableEmailChats:
                                                emailSuggestions,
                                            latestStatuses: latestStatuses,
                                            pendingAttachments:
                                                pendingAttachments,
                                            composerError: state.composerError,
                                            showAttachmentWarning:
                                                showAttachmentWarning,
                                            retryReport: retryReport,
                                            retryShareId: retryShareId,
                                          ),
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

  Future<void> _handleReactionSelection(Message message) async {
    if (!mounted) return;
    final selected = await showModalBottomSheet<String>(
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
    if (!mounted || selected == null || selected.isEmpty) return;
    context.read<ChatBloc>().add(
          ChatMessageReactionToggled(
            message: message,
            emoji: selected,
          ),
        );
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
    return {
      for (final status in lastEntry.statuses) status.chat.jid: status.state,
    };
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

  for (final reaction in reactions) {
    final spacing = visible.isEmpty ? 0 : _reactionChipSpacing;
    final addition = spacing +
        _measureReactionChipWidth(
          context: context,
          reaction: reaction,
          textDirection: textDirection,
          textScaler: textScaler,
        );
    if (used + addition > maxContentWidth) {
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
        totalWidth + spacing + glyphWidth > maxContentWidth) {
      totalWidth -= additions.removeLast();
      visible.removeLast();
      spacing = visible.isEmpty ? 0 : _reactionChipSpacing;
    }
    if (visible.isEmpty) {
      totalWidth = math.min(glyphWidth, maxContentWidth);
    } else {
      totalWidth = math.min(maxContentWidth, totalWidth + spacing + glyphWidth);
    }
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
        icon: const Icon(LucideIcons.squareCheck, size: 16),
        label: 'Select',
        onPressed: onSelect,
      ),
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
    return Wrap(
      spacing: scaled(8),
      runSpacing: scaled(8),
      alignment: WrapAlignment.center,
      children: actions,
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
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onForward;
  final VoidCallback onAddToCalendar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final textScaler = MediaQuery.of(context).textScaler;
    double scaled(double value) => textScaler.scale(value);
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          border: Border(
            top: BorderSide(color: colors.border, width: 1),
          ),
        ),
        child: Padding(
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$count selected',
                      style: textTheme.muted,
                    ),
                  ),
                  ShadButton.outline(
                    onPressed: onClear,
                    child: const Text('Cancel'),
                  ).withTapBounce(),
                ],
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
            ],
          ),
        ),
      ),
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
            Text(
              message.body ?? '(no content)',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.small,
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
                Text(
                  message.body ?? '(no content)',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.small,
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
