import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:chat/src/storage/models.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:equatable/equatable.dart';

part 'chats_state.dart';

class ChatsCubit extends Cubit<ChatsState> {
  ChatsCubit({required XmppService xmppService})
      : _xmppService = xmppService,
        super(const ChatsInitial(openJid: '', items: [])) {
    _chatsSubscription =
        _xmppService.chatsStream?.listen((items) => _updateChats(items));
  }

  final XmppService _xmppService;

  late final StreamSubscription<List<Chat>>? _chatsSubscription;

  @override
  Future<void> close() {
    _chatsSubscription?.cancel();
    return super.close();
  }

  void _updateChats(List<Chat> items) {
    emit(ChatsAvailable(
      openJid: items.isEmpty
          ? null
          : items.singleWhere((e) => e.open, orElse: () => items.first).jid,
      items: items,
    ));
  }

  Future<void> openChat(String jid) async {
    if (jid == state.openJid) return;
    await _xmppService.openChat(jid);
  }
}
