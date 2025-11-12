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
import 'package:axichat/src/chat/view/chat_alert.dart';
import 'package:axichat/src/chat/view/chat_attachment_preview.dart';
import 'package:axichat/src/chat/view/chat_cutout_composer.dart';
import 'package:axichat/src/chat/view/chat_drawer.dart';
import 'package:axichat/src/chat/view/chat_message_details.dart';
import 'package:axichat/src/chat/view/incoming_banner.dart';
import 'package:axichat/src/chat/view/recipient_chips_bar.dart';
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
const _reactionChipSpacing = 3.0;
const _reactionCutoutAlignment = 0.76;
const _reactionCornerClearance = 12.0;
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
  const _ChatSearchPanel({required this.onResultTap});

  final ValueChanged<Message> onResultTap;

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
                if (state.status == RequestStatus.loading)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
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
                    ),
                  )
                else if (state.error != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      state.error ?? 'Search failed',
                      style: TextStyle(color: context.colorScheme.destructive),
                    ),
                  ),
                if (state.results.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: state.results.length,
                      itemBuilder: (context, index) {
                        final message = state.results[index];
                        return _ChatSearchResultTile(
                          message: message,
                          onTap: widget.onResultTap,
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                    ),
                  )
                else if (state.status == RequestStatus.success)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No matches',
                      style: context.textTheme.muted,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChatSearchResultTile extends StatelessWidget {
  const _ChatSearchResultTile({
    required this.message,
    required this.onTap,
  });

  final Message message;
  final ValueChanged<Message> onTap;

  @override
  Widget build(BuildContext context) {
    final body = message.body?.trim();
    final timestamp = message.timestamp;
    final label = timestamp == null
        ? ''
        : formatTimeSinceLabel(DateTime.now(), timestamp);
    return Material(
      color: context.colorScheme.card,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        onTap: () => onTap(message),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                body?.isNotEmpty == true ? body! : '[No text]',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: context.textTheme.muted,
                  ),
                  if (body?.isNotEmpty == true)
                    AxiIconButton(
                      iconData: LucideIcons.copy,
                      tooltip: 'Copy',
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: body!),
                      ),
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
  late final ScrollController _scrollController;
  bool _composerHasText = false;
  final _approvedAttachmentSenders = <String>{};
  final _fileMetadataFutures = <String, Future<FileMetadataData?>>{};

  var _chatRoute = _ChatRoute.main;
  String? _selectedMessageId;
  final _messageKeys = <String, GlobalKey>{};
  final _messageBubbleKeys = <String, GlobalKey>{};
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

  void _typingListener() {
    final text = _textController.text;
    final hasText = text.isNotEmpty;
    final trimmedHasText = text.trim().isNotEmpty;
    if (_composerHasText != trimmedHasText && mounted) {
      setState(() {
        _composerHasText = trimmedHasText;
      });
    }
    if (hasText && _selectedMessageId != null) {
      _clearMessageSelection();
    }
    if (!context.read<SettingsCubit>().state.indicateTyping) return;
    if (!hasText) return;
    context.read<ChatBloc>().add(const ChatTypingStarted());
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

  void _handleSearchResultTap(Message message) {
    context.read<ChatBloc>().add(ChatMessageFocused(message.stanzaID));
    setState(() {
      _chatRoute = _ChatRoute.details;
      if (_focusNode.hasFocus) {
        _focusNode.unfocus();
      }
    });
  }

  void _handleSendMessage() {
    final text = _textController.text.trim();
    final bloc = context.read<ChatBloc>();
    final pendingAttachments = bloc.state.pendingAttachments;
    final hasQueuedAttachments = pendingAttachments.any(
      (attachment) => attachment.status == PendingAttachmentStatus.queued,
    );
    final isEmailTransport = context.read<ChatTransportCubit>().state.isEmail;
    final canSend =
        text.isNotEmpty || (isEmailTransport && hasQueuedAttachments);
    if (!canSend) return;
    bloc.add(ChatMessageSent(text: text));
    if (text.isNotEmpty) {
      _textController.clear();
    }
    _focusNode.requestFocus();
  }

  Widget _buildComposer({
    required bool isEmailTransport,
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
    final sendEnabled =
        _composerHasText || (isEmailTransport && hasQueuedAttachments);
    Widget? attachmentTray;
    final showAttachmentTray =
        isEmailTransport && pendingAttachments.isNotEmpty;
    if (showAttachmentTray) {
      attachmentTray = _PendingAttachmentList(
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
                    actions: _buildComposerAccessories(
                      isEmailTransport: isEmailTransport,
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
        notices.add(
          _ComposerNotice(
            type: _ComposerNoticeType.info,
            message: 'Failed to send to $failedCount $label.',
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
    required bool isEmailTransport,
    required bool canSend,
  }) {
    final accessories = <ChatComposerAccessory>[];
    if (!isEmailTransport) {
      accessories.add(
        ChatComposerAccessory.leading(child: _buildEmojiButton()),
      );
    }
    accessories.add(
      ChatComposerAccessory.leading(
        child: _buildAttachmentButton(isEmailTransport: isEmailTransport),
      ),
    );
    accessories.add(
      ChatComposerAccessory.trailing(
        child: _buildSendButton(enabled: canSend),
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

  Widget _buildSendButton({required bool enabled}) {
    final colors = context.colorScheme;
    return _cutoutIconButton(
      icon: LucideIcons.send,
      tooltip: 'Send message',
      activeColor: colors.primary,
      onPressed: enabled ? _handleSendMessage : null,
    );
  }

  Widget _cutoutIconButton({
    required IconData icon,
    required String tooltip,
    Color? activeColor,
    VoidCallback? onPressed,
  }) {
    final colors = context.colorScheme;
    final iconColor = onPressed == null
        ? colors.mutedForeground
        : (activeColor ?? colors.foreground);
    final button = IconButton(
      icon: Icon(icon, size: 24, color: iconColor),
      tooltip: tooltip,
      onPressed: onPressed,
      splashRadius: 24,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: 50,
        minHeight: 50,
      ),
      visualDensity: VisualDensity.compact,
    );
    final decorated = DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.card,
        shape: SquircleBorder(
          cornerRadius: 14,
          side: BorderSide(color: colors.border, width: 1.4),
        ),
      ),
      child: button,
    );
    return decorated.withTapBounce(enabled: onPressed != null);
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
        final sizeLabel = _formatBytes(attachment.sizeBytes);
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
                    _attachmentIcon(attachment),
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

    collect(_messageBubbleKeys[selectedId], padding: 12);
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
    _scrollController = ScrollController();
    _textController.addListener(_typingListener);
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
    _emojiPopoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, state) {
          final profile = context.watch<ProfileCubit?>()?.state;
          final emailService =
              RepositoryProvider.of<EmailService>(context, listen: false);
          final emailSelfJid = emailService.selfSenderJid;
          final jid = state.chat?.jid;
          final transport = context.watch<ChatTransportCubit>().state;
          final canUseEmail = (state.chat?.deltaChatId != null) ||
              (state.chat?.emailAddress?.isNotEmpty ?? false);
          final isEmailChat = state.chat?.deltaChatId != null;
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
          final warningEntry =
              fanOutReports.entries.isEmpty ? null : fanOutReports.entries.last;
          final showAttachmentWarning =
              warningEntry?.value.attachmentWarning ?? false;
          final retryEntry = _lastReportEntryWhere(
            fanOutReports.entries,
            (entry) => entry.value.hasFailures,
          );
          final retryReport = retryEntry?.value;
          final retryShareId = retryEntry?.key;
          final emailSuggestions = (context.watch<ChatsCubit?>()?.state.items ??
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
              endDrawer: jid == null
                  ? null
                  : ChatDrawer(
                      state: state,
                    ),
              appBar: AppBar(
                scrolledUnderElevation: 0,
                forceMaterialTransparency: true,
                shape: Border(
                    bottom: BorderSide(color: context.colorScheme.border)),
                actionsPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                leadingWidth: AxiIconButton.kDefaultSize + 24,
                leading: Padding(
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
                            context
                                .read<ChatBloc>()
                                .add(const ChatMessageFocused(null));
                            return setState(() {
                              _chatRoute = _ChatRoute.main;
                            });
                          }
                          if (_textController.text.isNotEmpty) {
                            if (!isEmailTransport) {
                              context.read<DraftCubit?>()?.saveDraft(
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
                        buildWhen: (_, current) => current is RosterAvailable,
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
                                              subscription: item.subscription,
                                              presence: item.presence,
                                              status: item.status,
                                            ),
                                    ),
                                    Positioned(
                                      right: -6,
                                      bottom: -4,
                                      child: AxiTransportChip(
                                        transport: transport,
                                        compact: true,
                                      ),
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
                    const SizedBox(width: 4),
                    Builder(
                      builder: (context) => AxiIconButton(
                        iconData: LucideIcons.settings,
                        onPressed: Scaffold.of(context).openEndDrawer,
                      ),
                    ),
                  ] else
                    const SizedBox.shrink(),
                ],
              ),
              body: Column(
                children: [
                  const ChatAlert(),
                  _ChatSearchPanel(
                    onResultTap: _handleSearchResultTap,
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration:
                          context.watch<SettingsCubit>().animationDuration,
                      reverseDuration:
                          context.watch<SettingsCubit>().animationDuration,
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
                              final isCompact = contentWidth < smallScreen;
                              final messageById = {
                                for (final item in state.items)
                                  item.stanzaID: item,
                              };
                              final filteredItems = state.items
                                  .where((e) =>
                                      e.body != null || e.error.isNotNone)
                                  .toList();
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
                              for (var index = 0;
                                  index < filteredItems.length;
                                  index++) {
                                final e = filteredItems[index];
                                final isSelfXmpp = e.senderJid == profile?.jid;
                                final isSelfEmail = emailSelfJid != null &&
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
                                final bannerParticipants =
                                    List<chat_models.Chat>.of(
                                  _participantsForBanner(
                                    shareContexts[e.stanzaID],
                                    state.chat?.jid,
                                    currentUserId,
                                  ),
                                );
                                dashMessages.add(
                                  ChatMessage(
                                    user: author,
                                    createdAt: e.timestamp!,
                                    text:
                                        '${e.error.isNotNone ? e.error.asString : ''}'
                                        '${e.error.isNotNone && e.body?.isNotEmpty == true ? ': "${e.body}"' : e.body}',
                                    status: e.error.isNotNone
                                        ? MessageStatus.failed
                                        : e.displayed
                                            ? MessageStatus.read
                                            : e.received
                                                ? MessageStatus.received
                                                : e.acked
                                                    ? MessageStatus.sent
                                                    : MessageStatus.pending,
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
                                      'shareParticipants': bannerParticipants,
                                    },
                                  ),
                                );
                              }
                              if (filteredItems.isEmpty) {
                                dashMessages.add(
                                  ChatMessage(
                                    user: spacerUser,
                                    createdAt: _selectionSpacerTimestamp,
                                    text: ' ',
                                    customProperties: const {
                                      'id': _emptyStateMessageId,
                                      'emptyState': true,
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
                                separatorFrequency: SeparatorFrequency.days,
                                dateSeparatorBuilder: (date) {
                                  if (date.isAtSameMomentAs(
                                    _selectionSpacerTimestamp,
                                  )) {
                                    return const SizedBox.shrink();
                                  }
                                  return DefaultDateSeparator(
                                    date: date,
                                    messageListOptions: dashMessageListOptions,
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
                                onLoadEarlier: state.items.length %
                                            ChatBloc.messageBatchSize !=
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
                                    key: ValueKey<String?>(quoting.stanzaID),
                                    message: quoting,
                                    isSelf: quoting.senderJid == currentUserId,
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
                                  state.chat?.chatState?.name == 'composing'
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
                                          containerColor: Colors.transparent,
                                          userNameBuilder: (user) {
                                            if (user.id ==
                                                _selectionSpacerMessageId) {
                                              return const SizedBox.shrink();
                                            }
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                left: _chatHorizontalPadding,
                                                right: _chatHorizontalPadding,
                                                bottom: 4,
                                              ),
                                              child: Text(
                                                user.getFullName(),
                                                style: context.textTheme.muted
                                                    .copyWith(fontSize: 12.0),
                                              ),
                                            );
                                          },
                                          messageTextBuilder:
                                              (message, previous, next) {
                                            final colors = context.colorScheme;
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
                                            final bannerParticipants = (message
                                                            .customProperties?[
                                                        'shareParticipants']
                                                    as List<
                                                        chat_models.Chat>?) ??
                                                const <chat_models.Chat>[];
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
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 24,
                                                  horizontal:
                                                      _chatHorizontalPadding,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    'No messages',
                                                    style:
                                                        context.textTheme.muted,
                                                  ),
                                                ),
                                              );
                                            }
                                            final self =
                                                message.customProperties?[
                                                        'isSelf'] as bool? ??
                                                    (message.user.id ==
                                                        profile?.jid);
                                            final error = message
                                                    .customProperties!['error']
                                                as MessageError;
                                            final isError = error.isNotNone;
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
                                            final timestampColor =
                                                chatTokens.timestamp;
                                            final encrypted =
                                                message.customProperties![
                                                        'encrypted'] ==
                                                    true;
                                            const iconSize = 13.0;
                                            final iconFamily =
                                                message.status!.icon.fontFamily;
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
                                                  ? colors.primaryForeground
                                                  : colors.primary,
                                              decoration:
                                                  TextDecoration.underline,
                                              fontWeight: FontWeight.w600,
                                            );
                                            final parsedText = parseMessageText(
                                              text: message.text,
                                              baseStyle: baseTextStyle,
                                              linkStyle: linkStyle,
                                            );
                                            final timeColor = isError
                                                ? textColor
                                                : self
                                                    ? colors.primaryForeground
                                                    : timestampColor;
                                            final time = TextSpan(
                                              text:
                                                  '${message.createdAt.hour.toString().padLeft(2, '0')}:'
                                                  '${message.createdAt.minute.toString().padLeft(2, '0')}',
                                              style: context.textTheme.muted
                                                  .copyWith(
                                                color: timeColor,
                                                fontSize: 11.0,
                                              ),
                                            );
                                            final status = TextSpan(
                                              text: String.fromCharCode(
                                                message.status!.icon.codePoint,
                                              ),
                                              style: TextStyle(
                                                color: self
                                                    ? colors.primaryForeground
                                                    : timestampColor,
                                                fontSize: iconSize,
                                                fontFamily: iconFamily,
                                                package: iconPackage,
                                              ),
                                            );
                                            final encryption = TextSpan(
                                              text: String.fromCharCode(
                                                (encrypted
                                                        ? LucideIcons
                                                            .lockKeyhole
                                                        : LucideIcons
                                                            .lockKeyholeOpen)
                                                    .codePoint,
                                              ),
                                              style: context.textTheme.muted
                                                  .copyWith(
                                                color: encrypted
                                                    ? (self
                                                        ? colors
                                                            .primaryForeground
                                                        : colors.foreground)
                                                    : colors.destructive,
                                                fontSize: iconSize,
                                                fontFamily: iconFamily,
                                                package: iconPackage,
                                              ),
                                            );
                                            final trusted =
                                                message.customProperties![
                                                    'trusted'] as bool?;
                                            final verification = trusted == null
                                                ? null
                                                : TextSpan(
                                                    text: String.fromCharCode(
                                                      trusted.toShieldIcon
                                                          .codePoint,
                                                    ),
                                                    style: context
                                                        .textTheme.muted
                                                        .copyWith(
                                                      color: trusted
                                                          ? axiGreen
                                                          : colors.destructive,
                                                      fontSize: iconSize,
                                                      fontFamily: iconFamily,
                                                      package: iconPackage,
                                                    ),
                                                  );
                                            final messageModel = message
                                                    .customProperties?['model']
                                                as Message;
                                            final quotedModel = message
                                                    .customProperties?['quoted']
                                                as Message?;
                                            final reactions = (message
                                                            .customProperties?[
                                                        'reactions']
                                                    as List<
                                                        ReactionPreview>?) ??
                                                const <ReactionPreview>[];
                                            final canReact = !isEmailTransport;
                                            final isSelected =
                                                _selectedMessageId ==
                                                    messageModel.stanzaID;
                                            final showReactionManager =
                                                canReact && isSelected;
                                            final showCompactReactions =
                                                reactions.isNotEmpty &&
                                                    !showReactionManager;
                                            final bubbleContentKey = message
                                                    .customProperties?['id'] ??
                                                '${message.user.id}-${message.createdAt.microsecondsSinceEpoch}';
                                            final bubbleChildren = <Widget>[];
                                            if (quotedModel != null) {
                                              bubbleChildren.add(
                                                _QuotedMessagePreview(
                                                  message: quotedModel,
                                                  isSelf:
                                                      quotedModel.senderJid ==
                                                          user.id,
                                                ),
                                              );
                                            }
                                            if (bannerParticipants.isNotEmpty) {
                                              bubbleChildren.add(
                                                IncomingBanner(
                                                  participants:
                                                      bannerParticipants,
                                                  onParticipantTap:
                                                      (participant) => context
                                                          .read<ChatsCubit?>()
                                                          ?.toggleChat(
                                                            jid:
                                                                participant.jid,
                                                          ),
                                                ),
                                              );
                                              bubbleChildren.add(
                                                const SizedBox(height: 4),
                                              );
                                            }
                                            if (isError) {
                                              bubbleChildren.addAll([
                                                Text(
                                                  'Error!',
                                                  style: context.textTheme.small
                                                      .copyWith(
                                                    color: textColor,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                DynamicInlineText(
                                                  key: ValueKey(
                                                    bubbleContentKey,
                                                  ),
                                                  text: parsedText.body,
                                                  details: [time],
                                                  links: parsedText.links,
                                                  onLinkTap: _handleLinkTap,
                                                ),
                                              ]);
                                            } else {
                                              bubbleChildren.add(
                                                DynamicInlineText(
                                                  key: ValueKey(
                                                      bubbleContentKey),
                                                  text: parsedText.body,
                                                  details: [
                                                    time,
                                                    if (self) status,
                                                    encryption,
                                                    if (verification != null)
                                                      verification,
                                                  ],
                                                  links: parsedText.links,
                                                  onLinkTap: _handleLinkTap,
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
                                                messageModel.fileMetadataID;
                                            if (metadataId != null &&
                                                metadataId.isNotEmpty) {
                                              if (bubbleChildren.isNotEmpty) {
                                                bubbleChildren.add(
                                                  const SizedBox(height: 8),
                                                );
                                              }
                                              final allowAttachment =
                                                  _shouldAllowAttachment(
                                                senderJid:
                                                    messageModel.senderJid,
                                                isSelf: self,
                                                knownContacts: rosterContacts,
                                                isEmailChat: isEmailChat,
                                              );
                                              bubbleChildren.add(
                                                ChatAttachmentPreview(
                                                  metadataFuture:
                                                      _metadataFutureFor(
                                                    metadataId,
                                                  ),
                                                  allowed: allowAttachment,
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
                                            final bubblePadding =
                                                showCompactReactions
                                                    ? _bubblePadding.add(
                                                        const EdgeInsets.only(
                                                          bottom:
                                                              _reactionBubbleInset,
                                                        ),
                                                      )
                                                    : _bubblePadding;
                                            final bubbleBorderRadius =
                                                _bubbleBorderRadius(
                                              isSelf: self,
                                              chainedPrevious: chainedPrev,
                                              chainedNext: chainedNext,
                                              isSelected: isSelected,
                                            );
                                            final bubbleKey =
                                                _messageBubbleKeys.putIfAbsent(
                                              messageModel.stanzaID,
                                              () => GlobalKey(),
                                            );
                                            final bubbleMaxWidth =
                                                clampedBubbleWidth;
                                            final bubbleConstraints =
                                                BoxConstraints(
                                              maxWidth: bubbleMaxWidth,
                                            );
                                            final bubbleHighlightColor =
                                                context.colorScheme.primary;
                                            final bubbleContent = Padding(
                                              padding: bubblePadding,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                spacing: 4,
                                                children: bubbleChildren,
                                              ),
                                            );
                                            final nextIsTailSpacer =
                                                next?.customProperties?[
                                                        'selectionSpacer'] ==
                                                    true;
                                            final isRenderableBubble =
                                                !(isSelectionSpacer ||
                                                    isEmptyState);
                                            final isLatestBubble =
                                                isRenderableBubble &&
                                                    (next == null ||
                                                        nextIsTailSpacer);
                                            final outerPadding =
                                                EdgeInsets.only(
                                              top: 2,
                                              bottom: isLatestBubble ? 12 : 2,
                                              left: _chatHorizontalPadding,
                                              right: _chatHorizontalPadding,
                                            );
                                            final bubble = LayoutBuilder(
                                              builder:
                                                  (context, innerConstraints) {
                                                final width =
                                                    innerConstraints.maxWidth;
                                                final bubbleWidth =
                                                    width.isFinite
                                                        ? width
                                                        : null;
                                                final List<CutoutSpec> cutouts =
                                                    showCompactReactions
                                                        ? _buildReactionCutouts(
                                                            reactions:
                                                                reactions,
                                                            message:
                                                                messageModel,
                                                            canReact: canReact,
                                                            isSelf: self,
                                                            bubbleWidth:
                                                                bubbleWidth,
                                                          )
                                                        : const [];
                                                return TweenAnimationBuilder<
                                                    double>(
                                                  tween: Tween<double>(
                                                    begin: 0,
                                                    end: isSelected ? 1.0 : 0.0,
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
                                                    return CutoutSurface(
                                                      key: bubbleKey,
                                                      backgroundColor:
                                                          bubbleColor,
                                                      borderColor: borderColor,
                                                      shape:
                                                          ContinuousRectangleBorder(
                                                        borderRadius:
                                                            bubbleBorderRadius,
                                                      ),
                                                      cutouts: cutouts,
                                                      shadows:
                                                          _selectedBubbleShadows(
                                                        bubbleHighlightColor,
                                                      ),
                                                      shadowOpacity:
                                                          shadowValue,
                                                      child: child!,
                                                    );
                                                  },
                                                );
                                              },
                                            );
                                            final baseAlignment = self
                                                ? Alignment.centerRight
                                                : Alignment.centerLeft;
                                            final targetAlignment = isSelected
                                                ? Alignment.center
                                                : baseAlignment;
                                            final shadowedBubble =
                                                ConstrainedBox(
                                              constraints: bubbleConstraints,
                                              child: bubble,
                                            );
                                            final alignedBubble = AnimatedAlign(
                                              duration: _bubbleFocusDuration,
                                              curve: _bubbleFocusCurve,
                                              alignment: targetAlignment,
                                              child: shadowedBubble,
                                            );
                                            final canResend = message.status ==
                                                MessageStatus.failed;
                                            List<GlobalKey>? actionButtonKeys;
                                            if (isSelected) {
                                              const baseActionCount = 6;
                                              final actionCount =
                                                  baseActionCount +
                                                      (canResend ? 1 : 0);
                                              actionButtonKeys = List.generate(
                                                  actionCount,
                                                  (_) => GlobalKey());
                                              _selectionActionButtonKeys
                                                ..clear()
                                                ..addAll(actionButtonKeys);
                                            } else if (_selectedMessageId ==
                                                messageModel.stanzaID) {
                                              _selectionActionButtonKeys
                                                  .clear();
                                            }
                                            final actionBar = _MessageActionBar(
                                              onReply: () {
                                                context.read<ChatBloc>().add(
                                                      ChatQuoteRequested(
                                                        messageModel,
                                                      ),
                                                    );
                                                _focusNode.requestFocus();
                                                _clearMessageSelection();
                                              },
                                              onForward: () =>
                                                  _handleForward(messageModel),
                                              onCopy: () => _copyMessage(
                                                dashMessage: message,
                                                model: messageModel,
                                              ),
                                              onShare: () => _shareMessage(
                                                dashMessage: message,
                                                model: messageModel,
                                              ),
                                              onAddToCalendar: () =>
                                                  _handleAddToCalendar(
                                                dashMessage: message,
                                                model: messageModel,
                                              ),
                                              onDetails: () =>
                                                  _showMessageDetails(message),
                                              onResend: canResend
                                                  ? () => context
                                                      .read<ChatBloc>()
                                                      .add(
                                                        ChatMessageResendRequested(
                                                          messageModel,
                                                        ),
                                                      )
                                                  : null,
                                              hitRegionKeys: actionButtonKeys,
                                            );
                                            if (isSelected) {
                                              _activeSelectionExtrasKey ??=
                                                  GlobalKey();
                                              _scheduleSelectionAutoscroll();
                                              _requestSelectionControlsMeasurement();
                                            } else if (_activeSelectionExtrasKey !=
                                                    null &&
                                                _selectedMessageId ==
                                                    messageModel.stanzaID) {
                                              _activeSelectionExtrasKey = null;
                                            }
                                            final attachmentsKey = isSelected
                                                ? _activeSelectionExtrasKey
                                                : null;
                                            final attachmentTopPadding = isSelected
                                                ? _selectionAttachmentSelectedGap
                                                : _selectionAttachmentBaseGap;
                                            final attachmentBottomPadding =
                                                _selectionExtrasViewportGap +
                                                    (showReactionManager
                                                        ? _reactionManagerShadowGap
                                                        : 0);
                                            final attachmentPadding =
                                                EdgeInsets.only(
                                              top: attachmentTopPadding,
                                              bottom: attachmentBottomPadding,
                                              left: _chatHorizontalPadding,
                                              right: _chatHorizontalPadding,
                                            );
                                            final attachments =
                                                AnimatedSwitcher(
                                              duration: _bubbleFocusDuration,
                                              switchInCurve: _bubbleFocusCurve,
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
                                                    if (currentChild != null)
                                                      currentChild,
                                                  ],
                                                );
                                              },
                                              transitionBuilder:
                                                  (child, animation) {
                                                final slideAnimation =
                                                    Tween<Offset>(
                                                  begin: const Offset(0, -0.05),
                                                  end: Offset.zero,
                                                ).animate(animation);
                                                return FadeTransition(
                                                  opacity: animation,
                                                  child: SizeTransition(
                                                    sizeFactor: animation,
                                                    axisAlignment: -1,
                                                    child: SlideTransition(
                                                      position: slideAnimation,
                                                      child: child,
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: isSelected
                                                  ? KeyedSubtree(
                                                      key: attachmentsKey,
                                                      child: Padding(
                                                        padding:
                                                            attachmentPadding,
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .center,
                                                          children: [
                                                            actionBar,
                                                            if (showReactionManager)
                                                              const SizedBox(
                                                                height: 20,
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
                                                                  onAddCustom: () =>
                                                                      _handleReactionSelection(
                                                                    messageModel,
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    )
                                                  : const SizedBox.shrink(),
                                            );
                                            final messageKey =
                                                _messageKeys.putIfAbsent(
                                              messageModel.stanzaID,
                                              () => GlobalKey(),
                                            );
                                            final selectableBubble =
                                                GestureDetector(
                                              behavior:
                                                  HitTestBehavior.translucent,
                                              onTap: () {
                                                if (isSelected) {
                                                  _clearMessageSelection();
                                                }
                                              },
                                              onLongPress: widget.readOnly
                                                  ? null
                                                  : () =>
                                                      _toggleMessageSelection(
                                                        messageModel.stanzaID,
                                                      ),
                                              child: alignedBubble,
                                            );
                                            final animatedStack = AnimatedSize(
                                              duration: _bubbleFocusDuration,
                                              curve: _bubbleFocusCurve,
                                              clipBehavior: Clip.none,
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
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
                                  _buildComposer(
                                    isEmailTransport: isEmailTransport,
                                    hintText: composerHintText,
                                    recipients: recipients,
                                    availableEmailChats: emailSuggestions,
                                    latestStatuses: latestStatuses,
                                    pendingAttachments: pendingAttachments,
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
    _clearMessageSelection();
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
    _clearMessageSelection();
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
    _clearMessageSelection();
  }

  Future<void> _handleAddToCalendar({
    required ChatMessage dashMessage,
    required Message model,
  }) async {
    _clearMessageSelection();
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

  List<CutoutSpec> _buildReactionCutouts({
    required List<ReactionPreview> reactions,
    required Message? message,
    required bool canReact,
    required bool isSelf,
    required double? bubbleWidth,
  }) {
    if (reactions.isEmpty) {
      return const [];
    }
    const maxVisible = 4;
    final visible = reactions.take(maxVisible).toList();
    const emojiSpacing = _reactionChipSpacing;
    final spacing =
        visible.length > 1 ? (visible.length - 1) * emojiSpacing : 0.0;
    final baseWidth = visible.fold<double>(0, (sum, reaction) {
          final countWidth = reaction.count > 1
              ? 8 + (reaction.count.toString().length * 4)
              : 0;
          return sum + 14 + countWidth;
        }) +
        spacing +
        _reactionCutoutPadding.horizontal;
    var thickness = baseWidth.clamp(
        _reactionCutoutThickness, _reactionCutoutThickness + 80);
    if (bubbleWidth != null &&
        bubbleWidth.isFinite &&
        bubbleWidth > (_bubbleRadius + _reactionCornerClearance) * 2) {
      final maxThickness =
          bubbleWidth - (_bubbleRadius + _reactionCornerClearance) * 2;
      thickness = thickness.clamp(
        _reactionCutoutThickness,
        math.max(_reactionCutoutThickness, maxThickness),
      );
    }
    final alignmentX = _reactionAlignmentForBubble(
      bubbleWidth: bubbleWidth,
      thickness: thickness,
      isSelf: isSelf,
    );
    return [
      CutoutSpec(
        edge: CutoutEdge.bottom,
        alignment: Alignment(alignmentX, 1),
        depth: _reactionCutoutDepth,
        thickness: thickness,
        cornerRadius: _reactionCutoutRadius,
        child: Transform.translate(
          offset: _reactionStripOffset,
          child: Padding(
            padding: _reactionCutoutPadding,
            child: _ReactionStrip(
              reactions: visible,
              onReactionTap: canReact && message != null
                  ? (emoji) => _toggleQuickReaction(message, emoji)
                  : null,
            ),
          ),
        ),
      ),
    ];
  }

  double _reactionAlignmentForBubble({
    required double? bubbleWidth,
    required double thickness,
    required bool isSelf,
  }) {
    if (bubbleWidth == null ||
        !bubbleWidth.isFinite ||
        bubbleWidth <= 0 ||
        bubbleWidth.isNaN) {
      return isSelf ? -_reactionCutoutAlignment : _reactionCutoutAlignment;
    }
    const safeInset = _bubbleRadius + _reactionCornerClearance;
    final halfThickness = thickness / 2;
    final minCenter = safeInset + halfThickness;
    final maxCenter = bubbleWidth - safeInset - halfThickness;
    if (maxCenter <= minCenter) {
      return 0;
    }
    final targetCenter = isSelf ? minCenter : maxCenter;
    final fraction = (targetCenter / bubbleWidth).clamp(0.0, 1.0);
    return (fraction * 2) - 1;
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

class _ReactionStrip extends StatelessWidget {
  const _ReactionStrip({
    required this.reactions,
    this.onReactionTap,
  });

  final List<ReactionPreview> reactions;
  final void Function(String emoji)? onReactionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < reactions.length; i++) ...[
          _ReactionChip(
            data: reactions[i],
            onTap: onReactionTap == null
                ? null
                : () => onReactionTap!(reactions[i].emoji),
          ),
          if (i != reactions.length - 1)
            const SizedBox(width: _reactionChipSpacing),
        ],
      ],
    );
  }
}

class _PendingAttachmentList extends StatelessWidget {
  const _PendingAttachmentList({
    required this.attachments,
    required this.onRetry,
    required this.onRemove,
    this.onPressed,
    this.onLongPress,
  });

  final List<PendingAttachment> attachments;
  final ValueChanged<String> onRetry;
  final ValueChanged<String> onRemove;
  final ValueChanged<PendingAttachment>? onPressed;
  final ValueChanged<PendingAttachment>? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: attachments
            .map(
              (pending) => _PendingAttachmentPreview(
                pending: pending,
                onRetry: () => onRetry(pending.id),
                onRemove: () => onRemove(pending.id),
                onPressed: onPressed == null ? null : () => onPressed!(pending),
                onLongPress:
                    onLongPress == null ? null : () => onLongPress!(pending),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PendingAttachmentPreview extends StatelessWidget {
  const _PendingAttachmentPreview({
    required this.pending,
    required this.onRetry,
    required this.onRemove,
    this.onPressed,
    this.onLongPress,
  });

  final PendingAttachment pending;
  final VoidCallback onRetry;
  final VoidCallback onRemove;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    Widget preview;
    if (pending.attachment.isImage) {
      preview = _PendingImageAttachment(
        pending: pending,
        onRetry: onRetry,
        onRemove: onRemove,
      );
    } else {
      preview = _PendingFileAttachment(
        pending: pending,
        onRetry: onRetry,
        onRemove: onRemove,
      );
    }
    if (onPressed == null && onLongPress == null) {
      return preview;
    }
    final borderRadius = BorderRadius.circular(16);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onPressed,
        onLongPress: onLongPress ?? onPressed,
        child: preview,
      ),
    );
  }
}

class _PendingImageAttachment extends StatelessWidget {
  const _PendingImageAttachment({
    required this.pending,
    required this.onRetry,
    required this.onRemove,
  });

  final PendingAttachment pending;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final borderRadius = BorderRadius.circular(16);
    final isFailed = pending.status == PendingAttachmentStatus.failed;
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: borderRadius,
              child: Image.file(
                File(pending.attachment.path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: colors.card,
                  child: Icon(
                    _attachmentIcon(pending.attachment),
                    color: colors.mutedForeground,
                  ),
                ),
              ),
            ),
          ),
          if (isFailed)
            _PendingAttachmentErrorOverlay(
              borderRadius: borderRadius,
              fileName: pending.attachment.fileName,
              message: pending.errorMessage,
              onRetry: onRetry,
              onRemove: onRemove,
            )
          else
            Positioned(
              top: 6,
              right: 6,
              child: _PendingAttachmentStatusBadge(status: pending.status),
            ),
        ],
      ),
    );
  }
}

class _PendingFileAttachment extends StatelessWidget {
  const _PendingFileAttachment({
    required this.pending,
    required this.onRetry,
    required this.onRemove,
  });

  final PendingAttachment pending;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final sizeLabel = _formatBytes(pending.attachment.sizeBytes);
    final borderRadius = BorderRadius.circular(16);
    final isFailed = pending.status == PendingAttachmentStatus.failed;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.min(MediaQuery.sizeOf(context).width * 0.65, 260),
      ),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: borderRadius,
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _attachmentIcon(pending.attachment),
                  size: 20,
                  color: colors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pending.attachment.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.small.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        sizeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.small.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (!isFailed)
                  _PendingAttachmentStatusInlineBadge(status: pending.status),
              ],
            ),
          ),
          if (isFailed)
            _PendingAttachmentErrorOverlay(
              borderRadius: borderRadius,
              fileName: pending.attachment.fileName,
              message: pending.errorMessage,
              onRetry: onRetry,
              onRemove: onRemove,
            ),
        ],
      ),
    );
  }
}

class _PendingAttachmentErrorOverlay extends StatelessWidget {
  const _PendingAttachmentErrorOverlay({
    required this.fileName,
    required this.message,
    required this.onRetry,
    required this.onRemove,
    this.borderRadius = BorderRadius.zero,
  });

  final String fileName;
  final String? message;
  final VoidCallback onRetry;
  final VoidCallback onRemove;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final effectiveMessage = message?.trim().isNotEmpty == true
        ? message!.trim()
        : 'Unable to send attachment.';
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact =
              constraints.maxWidth < 140 || constraints.maxHeight < 110;
          final padding = isCompact
              ? const EdgeInsets.all(4)
              : const EdgeInsets.symmetric(horizontal: 8, vertical: 10);
          final actionButtons = [
            _PendingAttachmentActionButton(
              label: 'Retry',
              icon: LucideIcons.refreshCw,
              onPressed: onRetry,
              compact: isCompact,
            ),
            _PendingAttachmentActionButton(
              label: 'Remove',
              icon: LucideIcons.x,
              onPressed: onRemove,
              compact: isCompact,
            ),
          ];
          final actions = Wrap(
            alignment: WrapAlignment.center,
            spacing: isCompact ? 4 : 8,
            runSpacing: 4,
            children: actionButtons,
          );
          final fileNameWidget = isCompact
              ? const SizedBox.shrink()
              : Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.small.copyWith(
                    color: colors.mutedForeground,
                  ),
                );
          final regularMessage = Text(
            effectiveMessage,
            style: context.textTheme.small.copyWith(
              color: colors.destructive,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          );
          final compactMessage = Text(
            effectiveMessage,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.small.copyWith(
              color: colors.destructive,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          );
          return DecoratedBox(
            decoration: BoxDecoration(
              color: colors.background.withValues(alpha: 0.9),
              borderRadius: borderRadius,
              border: Border.all(color: colors.destructive),
            ),
            child: Padding(
              padding: padding,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.triangleAlert,
                    color: colors.destructive,
                    size: isCompact ? 16 : 20,
                  ),
                  SizedBox(height: isCompact ? 2 : 6),
                  if (isCompact) ...[
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: compactMessage,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 28,
                      child: Center(child: actions),
                    ),
                  ] else ...[
                    regularMessage,
                    const SizedBox(height: 4),
                    fileNameWidget,
                    const SizedBox(height: 8),
                    actions,
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PendingAttachmentActionButton extends StatelessWidget {
  const _PendingAttachmentActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return SizedBox(
        width: 28,
        height: 28,
        child: IconButton(
          onPressed: onPressed,
          tooltip: label,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          iconSize: 16,
          color: context.colorScheme.destructive,
          icon: Icon(icon),
        ),
      );
    }
    return ShadButton.secondary(
      size: ShadButtonSize.sm,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    ).withTapBounce();
  }
}

class _PendingAttachmentSpinner extends StatelessWidget {
  const _PendingAttachmentSpinner({
    required this.color,
    this.strokeWidth = 2.5,
  });

  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator(
      strokeWidth: strokeWidth,
      color: color,
    );
  }
}

class _PendingAttachmentStatusBadge extends StatelessWidget {
  const _PendingAttachmentStatusBadge({required this.status});

  final PendingAttachmentStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final background = colors.background.withValues(alpha: 0.85);
    return Tooltip(
      message: _statusLabel(status),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(color: colors.border),
        ),
        padding: const EdgeInsets.all(4),
        child: _StatusIndicator(status: status),
      ),
    );
  }
}

class _PendingAttachmentStatusInlineBadge extends StatelessWidget {
  const _PendingAttachmentStatusInlineBadge({required this.status});

  final PendingAttachmentStatus status;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _statusLabel(status),
      child: SizedBox(
        width: 20,
        height: 20,
        child: _StatusIndicator(status: status),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status});

  final PendingAttachmentStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    switch (status) {
      case PendingAttachmentStatus.uploading:
        return _PendingAttachmentSpinner(
          color: colors.primary,
          strokeWidth: 2,
        );
      case PendingAttachmentStatus.queued:
        return Icon(
          LucideIcons.clock,
          size: 14,
          color: colors.mutedForeground,
        );
      case PendingAttachmentStatus.failed:
        return Icon(
          LucideIcons.triangleAlert,
          size: 14,
          color: colors.destructive,
        );
    }
  }
}

String _statusLabel(PendingAttachmentStatus status) {
  return switch (status) {
    PendingAttachmentStatus.uploading => 'Uploading attachment…',
    PendingAttachmentStatus.queued => 'Waiting to send',
    PendingAttachmentStatus.failed => 'Upload failed',
  };
}

IconData _attachmentIcon(EmailAttachment attachment) {
  if (attachment.isImage) return Icons.image_outlined;
  if (attachment.isVideo) return Icons.videocam_outlined;
  if (attachment.isAudio) return Icons.audiotrack;
  return Icons.insert_drive_file_outlined;
}

String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  final formatted = unit == 0
      ? size.toStringAsFixed(0)
      : size.toStringAsFixed(size >= 10 ? 0 : 1);
  return '$formatted ${units[unit]}';
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
    final colors = context.colorScheme;
    final highlighted = data.reactedBySelf;
    final emojiStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 16,
              fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
            ) ??
        TextStyle(
          fontSize: 16,
          fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
        );
    final countStyle = context.textTheme.small.copyWith(
      color: highlighted ? colors.primary : colors.mutedForeground,
      fontWeight: FontWeight.w600,
    );
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0.4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              data.emoji,
              style: emojiStyle,
            ),
            if (data.count > 1) ...[
              const SizedBox(width: 2),
              Text(
                data.count.toString(),
                style: countStyle,
              ),
            ],
          ],
        ),
      ),
    );
  }
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
    this.onResend,
    this.hitRegionKeys,
  });

  final VoidCallback onReply;
  final VoidCallback onForward;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onAddToCalendar;
  final VoidCallback onDetails;
  final VoidCallback? onResend;
  final List<GlobalKey>? hitRegionKeys;

  @override
  Widget build(BuildContext context) {
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
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: actions,
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
                        TextSpan(
                          text: String.fromCharCode(
                            LucideIcons.lockKeyhole.codePoint,
                          ),
                          style: context.textTheme.muted.copyWith(
                            color: self
                                ? colors.primaryForeground
                                : timestampColor,
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
