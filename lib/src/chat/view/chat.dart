import 'dart:async';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/bloc/chat_transport_cubit.dart';
import 'package:axichat/src/chat/view/chat_alert.dart';
import 'package:axichat/src/chat/view/chat_drawer.dart';
import 'package:axichat/src/chat/view/chat_message_details.dart';
import 'package:axichat/src/chat/view/chat_verification_list.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/bool_tool.dart';
import 'package:axichat/src/common/policy.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/models/chat_models.dart' as chat_models;
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
  verification,
  details,
}

const _bubblePadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
const _bubbleRadius = 18.0;
const _reactionBubbleInset = 20.0;
const _reactionCutoutDepth = 14.0;
const _reactionCutoutThickness = 34.0;
const _reactionCutoutRadius = 16.0;
const _reactionStripOffset = Offset(0, -2);
const _reactionCutoutPadding =
    EdgeInsets.symmetric(horizontal: 16, vertical: 4);
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
const _selectionControlsChangeThreshold = 8.0;
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
  const Chat({super.key});

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  late final ShadPopoverController _emojiPopoverController;
  late final FocusNode _focusNode;
  late final TextEditingController _textController;
  late final ScrollController _scrollController;

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
  bool _selectionAutoscrollSatisfied = false;
  bool _selectionControlsMeasurementPending = false;
  int? _dismissPointer;
  Offset? _dismissPointerDownPosition;
  bool _dismissPointerMoved = false;

  void _typingListener() {
    final hasText = _textController.text.isNotEmpty;
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
      _selectionAutoscrollSatisfied = false;
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
      _selectionAutoscrollSatisfied = false;
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
    _selectionAutoscrollScheduled = false;
    try {
      if (!_selectionAutoscrollActive || _selectedMessageId == null) return;
      await _waitForPostFrame();
      if (!_selectionAutoscrollActive || _selectedMessageId == null) return;
      if (!_scrollController.hasClients) {
        _scheduleSelectionAutoscroll();
        return;
      }
      final gapDelta = _selectionGapDelta();
      if (gapDelta == null) {
        _scheduleSelectionAutoscroll();
        return;
      }
      if (gapDelta.abs() <= _selectionHeadroomTolerance) {
        if ((_selectionSpacerHeight - _selectionSpacerBaseHeight).abs() >
            _selectionHeadroomTolerance) {
          setState(() {
            _selectionSpacerHeight = _selectionSpacerBaseHeight;
          });
        }
        _selectionAutoscrollActive = false;
        _selectionAutoscrollSatisfied = true;
        return;
      }
      await _shiftSelectionBy(gapDelta);
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

  Future<void> _shiftSelectionBy(double gapDelta) async {
    if (!_scrollController.hasClients) return;
    if (gapDelta.abs() <= _selectionHeadroomTolerance) {
      _selectionAutoscrollActive = false;
      _selectionAutoscrollSatisfied = true;
      return;
    }
    final position = _scrollController.position;
    final directionSign = _axisDirectionSign(position.axisDirection);
    final scrollDelta = gapDelta * directionSign;
    final rawTarget = position.pixels + scrollDelta;
    final minExtent = position.minScrollExtent.toDouble();
    final maxExtent = position.maxScrollExtent.toDouble();
    if (rawTarget > maxExtent + _selectionHeadroomTolerance) {
      _extendSelectionHeadroom(rawTarget - maxExtent);
      return;
    }
    if (rawTarget < minExtent - _selectionHeadroomTolerance) {
      _extendSelectionHeadroom(minExtent - rawTarget);
      return;
    }
    final target = rawTarget.clamp(minExtent, maxExtent);
    if ((position.pixels - target).abs() < _selectionAutoscrollSlop) {
      _selectionAutoscrollActive = false;
      _selectionAutoscrollSatisfied = true;
      return;
    }
    await position.animateTo(
      target,
      duration: _bubbleFocusDuration,
      curve: _bubbleFocusCurve,
    );
    if (_selectionAutoscrollActive) {
      _scheduleSelectionAutoscroll();
    }
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

  void _extendSelectionHeadroom(double amount) {
    final additional = math.max(amount, 0.0);
    if (additional <= _selectionHeadroomTolerance) return;
    setState(() {
      _selectionSpacerHeight =
          math.max(_selectionSpacerHeight, _selectionSpacerBaseHeight) +
              additional;
      if (_selectedMessageId != null) {
        _selectionAutoscrollActive = true;
        _selectionAutoscrollSatisfied = false;
      }
    });
    _scheduleSelectionAutoscroll();
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
        _selectionControlsChangeThreshold) {
      return;
    }
    final selectionActive = _selectedMessageId != null;
    final shouldRearm = selectionActive && _selectionAutoscrollSatisfied;
    setState(() {
      _selectionControlsHeight = height;
      if (shouldRearm) {
        _selectionAutoscrollActive = true;
        _selectionAutoscrollSatisfied = false;
      }
    });
    if (_scrollController.hasClients) {
      _updateSelectionSpacerBase(_scrollController.position.viewportDimension);
    }
    if (_selectionAutoscrollActive) {
      _scheduleSelectionAutoscroll();
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
          final isEmailTransport = canUseEmail && transport.isEmail;
          final currentUserId = isEmailTransport
              ? (emailSelfJid ?? profile?.jid ?? '')
              : (profile?.jid ?? '');
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
                      showVerification: () => setState(() {
                        _chatRoute = _ChatRoute.verification;
                      }),
                    ),
              appBar: AppBar(
                scrolledUnderElevation: 0,
                forceMaterialTransparency: true,
                shape: Border(
                    bottom: BorderSide(color: context.colorScheme.border)),
                actionsPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                leading: ShadIconButton.ghost(
                  icon: const Icon(
                    LucideIcons.arrowLeft,
                    size: 20.0,
                  ),
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
                    context.read<ChatsCubit>().toggleChat(jid: state.chat!.jid);
                  },
                ).withTapBounce(),
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
                  if (jid == null || _chatRoute != _ChatRoute.main)
                    const SizedBox.shrink()
                  else
                    Builder(
                      builder: (context) => AxiIconButton(
                        iconData: LucideIcons.settings,
                        onPressed: Scaffold.of(context).openEndDrawer,
                      ),
                    )
                ],
              ),
              body: Column(
                children: [
                  const ChatAlert(),
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
                                          0.0,
                                          _selectionSpacerHeight,
                                        )
                                      : 0.0;
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
                                  padding: EdgeInsets.only(left: 16, top: 16),
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
                                chatFooterBuilder: () {
                                  if (state.items.isEmpty &&
                                      state.quoting == null) {
                                    return Center(
                                      child: Text(
                                        'No messages',
                                        style: context.textTheme.muted,
                                      ),
                                    );
                                  }
                                  final quoting = state.quoting;
                                  if (quoting == null) {
                                    return null;
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: _QuoteBanner(
                                      message: quoting,
                                      isSelf:
                                          quoting.senderJid == currentUserId,
                                      onClear: () => context
                                          .read<ChatBloc>()
                                          .add(const ChatQuoteCleared()),
                                    ),
                                  );
                                }(),
                              );
                              return Column(
                                children: [
                                  Expanded(
                                    child: KeyedSubtree(
                                      key: _messageListKey,
                                      child: DashChat(
                                        currentUser: user,
                                        onSend: (message) {
                                          context.read<ChatBloc>().add(
                                              ChatMessageSent(
                                                  text: message.text));
                                          _focusNode.requestFocus();
                                        },
                                        messages: dashMessages,
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
                                            final extraStyle = context
                                                .textTheme.muted
                                                .copyWith(
                                              fontStyle: FontStyle.italic,
                                            );
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
                                            final text = TextSpan(
                                              text: message.text,
                                              style: context.textTheme.small
                                                  .copyWith(
                                                color: textColor,
                                                height: 1.3,
                                              ),
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
                                                      bubbleContentKey),
                                                  text: text,
                                                  details: [time],
                                                ),
                                              ]);
                                            } else {
                                              bubbleChildren.add(
                                                DynamicInlineText(
                                                  key: ValueKey(
                                                      bubbleContentKey),
                                                  text: text,
                                                  details: [
                                                    time,
                                                    if (self) status,
                                                    encryption,
                                                    if (verification != null)
                                                      verification,
                                                  ],
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
                                              final actionCount =
                                                  canResend ? 5 : 4;
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
                                              onLongPress: () =>
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 2,
                                                  horizontal:
                                                      _chatHorizontalPadding,
                                                ),
                                                child: bubbleWithSlack,
                                              ),
                                            );
                                          },
                                        ),
                                        messageListOptions:
                                            dashMessageListOptions,
                                        inputOptions: InputOptions(
                                          sendOnEnter: true,
                                          alwaysShowSend: true,
                                          focusNode: _focusNode,
                                          textController: _textController,
                                          sendButtonBuilder: (send) =>
                                              ShadIconButton.ghost(
                                            onPressed: send,
                                            icon: const Icon(
                                              Icons.send,
                                              size: 24,
                                            ),
                                          ).withTapBounce(),
                                          inputDecoration: _chatInputDecoration(
                                            context,
                                            hintText: isEmailTransport
                                                ? 'Send email message'
                                                : 'Send ${state.chat?.encryptionProtocol.isNone ?? false ? 'plaintext' : 'encrypted'} message',
                                          ),
                                          inputToolbarStyle: BoxDecoration(
                                            color:
                                                context.colorScheme.background,
                                            border: Border(
                                              top: BorderSide(
                                                  color: context
                                                      .colorScheme.border),
                                            ),
                                          ),
                                          inputToolbarMargin: EdgeInsets.zero,
                                          leading: [
                                            ShadPopover(
                                              controller:
                                                  _emojiPopoverController,
                                              child: ShadIconButton.ghost(
                                                onPressed:
                                                    _emojiPopoverController
                                                        .toggle,
                                                icon: const Icon(
                                                  LucideIcons.smile,
                                                  size: 24,
                                                ),
                                              ).withTapBounce(),
                                              popover: (context) => EmojiPicker(
                                                textEditingController:
                                                    _textController,
                                                config: Config(
                                                  emojiViewConfig:
                                                      EmojiViewConfig(
                                                    emojiSizeMax: context
                                                        .read<Policy>()
                                                        .getMaxEmojiSize(),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                          showTraillingBeforeSend: true,
                                          // trailing: [
                                          //   if (state.chat case final chat?) ...[
                                          //     ShadButton.ghost(
                                          //       onPressed: () => context.push(
                                          //         '/encryption/${chat.jid}',
                                          //         extra: context.read,
                                          //       ),
                                          //       foregroundColor: chat.encryptionProtocol.isNotNone
                                          //           ? context.colorScheme.primary
                                          //           : context.colorScheme.destructive,
                                          //       icon: Icon(
                                          //         chat.encryptionProtocol.isNotNone
                                          //             ? LucideIcons.lockKeyhole
                                          //             : LucideIcons.lockKeyholeOpen,
                                          //       ),
                                          //     ),
                                          //   ]
                                          // ],
                                        ),
                                        typingUsers: [
                                          if (state.typing == true) user,
                                          if (state.chat?.chatState?.name ==
                                              'composing')
                                            ChatUser(
                                              id: state.chat!.jid,
                                              firstName: state.chat!.title,
                                            ),
                                        ].take(1).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          VerificationList(jid: jid),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedMessageId == null) return;
      _selectionAutoscrollActive = true;
      _selectionAutoscrollSatisfied = false;
      _scheduleSelectionAutoscroll();
    });
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

class _MessageActionBar extends StatelessWidget {
  const _MessageActionBar({
    required this.onReply,
    required this.onForward,
    required this.onCopy,
    required this.onDetails,
    this.onResend,
    this.hitRegionKeys,
  });

  final VoidCallback onReply;
  final VoidCallback onForward;
  final VoidCallback onCopy;
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
      _MessageActionButton(
        key: nextKey(),
        icon: const Icon(LucideIcons.reply, size: 16),
        label: 'Reply',
        onPressed: onReply,
      ),
      _MessageActionButton(
        key: nextKey(),
        icon: Transform.scale(
          scaleX: -1,
          child: const Icon(LucideIcons.reply, size: 16),
        ),
        label: 'Forward',
        onPressed: onForward,
      ),
      if (onResend != null)
        _MessageActionButton(
          key: nextKey(),
          icon: const Icon(LucideIcons.repeat, size: 16),
          label: 'Resend',
          onPressed: onResend!,
        ),
      _MessageActionButton(
        key: nextKey(),
        icon: const Icon(LucideIcons.copy, size: 16),
        label: 'Copy',
        onPressed: onCopy,
      ),
      _MessageActionButton(
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

class _MessageActionButton extends StatelessWidget {
  const _MessageActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ShadButton.outline(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    ).withTapBounce();
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
