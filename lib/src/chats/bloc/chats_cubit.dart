import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chats_cubit.freezed.dart';

part 'chats_state.dart';

class ChatsCubit extends Cubit<ChatsState> {
  ChatsCubit({required ChatsService chatsService})
      : _chatsService = chatsService,
        super(ChatsState(
          openJid: null,
          items: [],
          filter: (chat) => true,
          creationStatus: RequestStatus.none,
        )) {
    _chatsSubscription =
        _chatsService.chatsStream().listen((items) => _updateChats(items));
  }

  final ChatsService _chatsService;

  late final StreamSubscription<List<Chat>> _chatsSubscription;

  @override
  Future<void> close() async {
    await _chatsSubscription.cancel();
    return super.close();
  }

  void _updateChats(List<Chat> items) {
    emit(state.copyWith(
      openJid: items.where((e) => e.open).firstOrNull?.jid,
      items: items,
    ));
  }

  void filterChats(bool Function(Chat) filter) {
    emit(state.copyWith(filter: filter));
  }

  Future<void> toggleChat({required String jid}) async {
    if (jid == state.openJid) {
      await _chatsService.closeChat();
      return;
    }
    await _chatsService.openChat(jid);
  }

  Future<void> toggleFavourited({
    required String jid,
    required bool favourited,
  }) async {
    await _chatsService.toggleChatFavourited(jid: jid, favourited: favourited);
  }

  Future<void> createChatRoom({
    required String title,
    String? nickname,
  }) async {
    if (title.contains('+')) {
      emit(state.copyWith(creationStatus: RequestStatus.failure));
      return;
    }
    emit(state.copyWith(creationStatus: RequestStatus.loading));
    // final uniqueTitle = '${_chatsService.username}+$title';
    // final jid = '$uniqueTitle@conference.${AuthenticationCubit.baseUrl}/${nickname??_chatsService.username}';
  }

  Future<void> deleteChat({required String jid}) async {
    await _chatsService.deleteChat(jid: jid);
  }
}
