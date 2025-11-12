import 'dart:async';

import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chats_cubit.freezed.dart';
part 'chats_state.dart';

class ChatsCubit extends Cubit<ChatsState> {
  ChatsCubit({required ChatsService chatsService})
      : _chatsService = chatsService,
        super(
          const ChatsState(
            openJid: null,
            openCalendar: false,
            items: null,
            creationStatus: RequestStatus.none,
          ),
        ) {
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

  Future<void> toggleChat({required String jid}) async {
    if (jid == state.openJid) {
      await _chatsService.closeChat();
      return;
    }
    // Close calendar when opening chat
    if (state.openCalendar) {
      emit(state.copyWith(openCalendar: false));
    }
    await _chatsService.openChat(jid);
  }

  void toggleCalendar() {
    if (state.openCalendar) {
      // Close calendar
      emit(state.copyWith(openCalendar: false));
    } else {
      // Open calendar and close any open chat
      emit(state.copyWith(openCalendar: true, openJid: null));
      if (state.openJid != null) {
        _chatsService.closeChat();
      }
    }
  }

  Future<void> toggleFavorited({
    required String jid,
    required bool favorited,
  }) async {
    await _chatsService.toggleChatFavorited(jid: jid, favorited: favorited);
  }

  Future<void> toggleArchived({
    required String jid,
    required bool archived,
  }) async {
    if (archived && state.openJid == jid) {
      await _chatsService.closeChat();
    }
    await _chatsService.toggleChatArchived(jid: jid, archived: archived);
  }

  Future<void> toggleHidden({
    required String jid,
    required bool hidden,
  }) async {
    if (hidden && state.openJid == jid) {
      await _chatsService.closeChat();
    }
    await _chatsService.toggleChatHidden(jid: jid, hidden: hidden);
  }

  Future<List<Message>> loadChatHistory(String jid) {
    return _chatsService.loadCompleteChatHistory(jid: jid);
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

  Future<void> deleteChatMessages({required String jid}) async {
    await _chatsService.deleteChatMessages(jid: jid);
  }
}
