import 'dart:async';

import 'package:async/async.dart';
import 'package:axichat/src/common/event_transform.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/scheduler.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_bloc.freezed.dart';
part 'chat_event.dart';
part 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({
    required this.jid,
    required MessageService messageService,
    required ChatsService chatsService,
    required NotificationService notificationService,
    OmemoService? omemoService,
  })  : _messageService = messageService,
        _chatsService = chatsService,
        _notificationService = notificationService,
        _omemoService = omemoService,
        super(const ChatState(items: [])) {
    on<_ChatUpdated>(_onChatUpdated);
    on<_ChatMessagesUpdated>(_onChatMessagesUpdated);
    on<ChatMessageFocused>(_onChatMessageFocused);
    on<ChatMessageUnfocused>(_onChatMessageUnfocused);
    on<ChatTypingStarted>(_onChatTypingStarted);
    on<_ChatTypingStopped>(_onChatTypingStopped);
    on<ChatMessageSent>(
      _onChatMessageSent,
      transformer: blocThrottle(downTime),
    );
    on<ChatMuted>(_onChatMuted);
    on<ChatResponsivityChanged>(_onChatResponsivityChanged);
    on<ChatEncryptionChanged>(_onChatEncryptionChanged);
    on<ChatEncryptionRepaired>(_onChatEncryptionRepaired);
    on<ChatLoadEarlier>(_onChatLoadEarlier);
    if (jid != null) {
      _notificationService.dismissNotifications();
      _chatSubscription = _chatsService
          .chatStream(jid!)
          .listen((chat) => chat == null ? null : add(_ChatUpdated(chat)));
      _messageSubscription = _messageService
          .messageStreamForChat(jid!, end: messageBatchSize)
          .listen((items) => add(_ChatMessagesUpdated(items)));
    }
  }

  static const messageBatchSize = 50;

  final String? jid;
  final MessageService _messageService;
  final ChatsService _chatsService;
  final NotificationService _notificationService;
  final OmemoService? _omemoService;

  late final StreamSubscription<Chat?> _chatSubscription;
  late StreamSubscription<List<Message>> _messageSubscription;

  RestartableTimer? _typingTimer;

  @override
  Future<void> close() async {
    await _chatSubscription.cancel();
    await _messageSubscription.cancel();
    _typingTimer?.cancel();
    _typingTimer = null;
    return super.close();
  }

  void _onChatUpdated(_ChatUpdated event, Emitter<ChatState> emit) {
    emit(state.copyWith(chat: event.chat));
  }

  void _onChatMessagesUpdated(
    _ChatMessagesUpdated event,
    Emitter<ChatState> emit,
  ) {
    emit(state.copyWith(items: event.items));

    if (SchedulerBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      for (final item in event.items) {
        if (!item.displayed && item.senderJid != _chatsService.myJid) {
          _messageService.sendReadMarker(jid!, item.stanzaID);
        }
      }
    }
  }

  void _onChatMessageFocused(
    ChatMessageFocused event,
    Emitter<ChatState> emit,
  ) {
    emit(
      state.copyWith(
        focused:
            state.items.where((e) => e.stanzaID == event.messageID).firstOrNull,
      ),
    );
  }

  void _onChatMessageUnfocused(
    ChatMessageUnfocused event,
    Emitter<ChatState> emit,
  ) {
    if (state.focused == null) return;
    emit(state.copyWith(focused: null));
  }

  Future<void> _onChatTypingStarted(
      ChatTypingStarted event, Emitter<ChatState> emit) async {
    if (_typingTimer case final timer?) {
      if (timer.isActive) {
        timer.reset();
      }
      return;
    } else {
      _typingTimer = RestartableTimer(
        const Duration(seconds: 3),
        () => add(const _ChatTypingStopped()),
      );
    }
    await _chatsService.sendTyping(jid: state.chat!.jid, typing: true);
    emit(state.copyWith(typing: true));
  }

  void _onChatTypingStopped(_ChatTypingStopped event, Emitter<ChatState> emit) {
    _stopTyping();
    emit(state.copyWith(typing: false));
  }

  Future<void> _onChatMessageSent(
    ChatMessageSent event,
    Emitter<ChatState> emit,
  ) async {
    _stopTyping();
    emit(state.copyWith(typing: false));
    try {
      await _messageService.sendMessage(jid: jid!, text: event.text);
    } on XmppMessageException catch (_) {
      // Don't panic. User will see a visual difference in the message bubble.
    }
  }

  Future<void> _onChatMuted(
    ChatMuted event,
    Emitter<ChatState> emit,
  ) async {
    if (jid == null) return;
    await _chatsService.toggleChatMuted(jid: jid!, muted: event.muted);
  }

  Future<void> _onChatResponsivityChanged(
    ChatResponsivityChanged event,
    Emitter<ChatState> emit,
  ) async {
    if (jid == null) return;
    await _chatsService.toggleChatMarkerResponsive(
        jid: jid!, responsive: event.responsive);
  }

  Future<void> _onChatEncryptionChanged(
    ChatEncryptionChanged event,
    Emitter<ChatState> emit,
  ) async {
    if (jid == null) return;
    await _chatsService.setChatEncryption(jid: jid!, protocol: event.protocol);
  }

  Future<void> _onChatEncryptionRepaired(
    ChatEncryptionRepaired event,
    Emitter<ChatState> emit,
  ) async {
    if (jid == null) return;
    await _omemoService?.recreateSessions(jid: jid!);
  }

  Future<void> _onChatLoadEarlier(
    ChatLoadEarlier event,
    Emitter<ChatState> emit,
  ) async {
    await _messageSubscription.cancel();
    _messageSubscription = _messageService
        .messageStreamForChat(jid!, end: state.items.length + messageBatchSize)
        .listen((items) => add(_ChatMessagesUpdated(items)));
  }

  Future<void> _stopTyping() async {
    _typingTimer?.cancel();
    _typingTimer = null;
    await _chatsService.sendTyping(jid: state.chat!.jid, typing: false);
  }
}
