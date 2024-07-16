import 'dart:async';

import 'package:async/async.dart';
import 'package:bloc/bloc.dart';
import 'package:chat/src/common/ui/event_transform.dart';
import 'package:chat/src/storage/models.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:equatable/equatable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_bloc.freezed.dart';
part 'chat_event.dart';
part 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({required this.jid, required XmppService xmppService})
      : _xmppService = xmppService,
        super(const ChatState(items: [])) {
    on<_ChatUpdated>(_onChatUpdated);
    on<_ChatMessagesUpdated>(_onChatMessagesUpdated);
    on<ChatTypingStarted>(_onChatTypingStarted);
    on<_ChatTypingStopped>(_onChatTypingStopped);
    on<ChatMessageSent>(
      _onChatMessageSent,
      transformer: blocThrottle(downTime),
    );
    if (jid != null) {
      _chatSubscription = _xmppService
          .chatStream(jid!)
          ?.listen((chat) => add(_ChatUpdated(chat)));
      _messageSubscription = _xmppService
          .messageStream(jid!)
          ?.listen((items) => add(_ChatMessagesUpdated(items)));
    }
  }

  final String? jid;
  final XmppService _xmppService;

  late final StreamSubscription<Chat>? _chatSubscription;
  late final StreamSubscription<List<Message>>? _messageSubscription;

  RestartableTimer? _typingTimer;

  @override
  Future<void> close() {
    _chatSubscription?.cancel();
    _messageSubscription?.cancel();
    _typingTimer?.cancel();
    _typingTimer = null;
    return super.close();
  }

  void _onChatUpdated(_ChatUpdated event, Emitter<ChatState> emit) {
    emit(state.copyWith(chat: event.chat));
  }

  void _onChatMessagesUpdated(
      _ChatMessagesUpdated event, Emitter<ChatState> emit) {
    emit(state.copyWith(items: event.items));
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
    await _xmppService.sendTyping(jid: state.chat!.jid, typing: true);
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
      await _xmppService.sendMessage(jid: jid!, text: event.text);
    } on XmppMessageException catch (_) {
      // Don't panic. User will see a visual difference in the message bubble.
    }
  }

  Future<void> _stopTyping() async {
    _typingTimer?.cancel();
    _typingTimer = null;
    await _xmppService.sendTyping(jid: state.chat!.jid, typing: false);
  }
}
