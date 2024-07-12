import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:chat/src/storage/models.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:equatable/equatable.dart';

part 'chat_event.dart';
part 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({required this.jid, required XmppService xmppService})
      : _xmppService = xmppService,
        super(const ChatInitial(items: [])) {
    on<_ChatUpdated>(_onChatUpdated);
    if (jid != null) {
      _chatSubscription = _xmppService
          .chatStream(jid!)
          ?.listen((items) => add(_ChatUpdated(items)));
    }
  }

  final String? jid;
  final XmppService _xmppService;

  late final StreamSubscription<List<Message>>? _chatSubscription;

  @override
  Future<void> close() {
    _chatSubscription?.cancel();
    return super.close();
  }

  void _onChatUpdated(_ChatUpdated event, Emitter<ChatState> emit) {
    emit(ChatAvailable(items: event.items));
  }
}
