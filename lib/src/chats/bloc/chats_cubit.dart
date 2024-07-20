import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:chat/src/storage/models.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chats_cubit.freezed.dart';
part 'chats_state.dart';

class ChatsCubit extends Cubit<ChatsState> {
  ChatsCubit({required XmppService xmppService})
      : _xmppService = xmppService,
        super(const ChatsState(openJid: null, items: [])) {
    _chatsSubscription =
        _xmppService.chatsStream().listen((items) => _updateChats(items));
  }

  final XmppService _xmppService;

  late final StreamSubscription<List<Chat>>? _chatsSubscription;

  @override
  Future<void> close() {
    _chatsSubscription?.cancel();
    return super.close();
  }

  void _updateChats(List<Chat> items) {
    emit(ChatsState(
      openJid: items.where((e) => e.open).firstOrNull?.jid,
      items: items,
    ));
  }

  Future<void> toggleChat(String jid) async {
    if (jid == state.openJid) {
      await _xmppService.closeChat();
      return;
    }
    await _xmppService.openChat(jid);
  }
}
