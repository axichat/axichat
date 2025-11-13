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
    final availableJids = items.map((chat) => chat.jid).toSet();
    final retainedSelection =
        state.selectedJids.where((jid) => availableJids.contains(jid)).toSet();
    emit(state.copyWith(
      openJid: items.where((e) => e.open).firstOrNull?.jid,
      items: items,
      selectedJids: retainedSelection,
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

  void ensureChatSelected(String jid) {
    if (state.selectedJids.contains(jid)) return;
    final updated = Set<String>.of(state.selectedJids)..add(jid);
    emit(state.copyWith(selectedJids: updated));
  }

  void toggleChatSelection(String jid) {
    final updated = Set<String>.of(state.selectedJids);
    if (!updated.remove(jid)) {
      updated.add(jid);
    }
    emit(state.copyWith(selectedJids: updated));
  }

  void clearSelection() {
    if (state.selectedJids.isEmpty) return;
    emit(state.copyWith(selectedJids: const <String>{}));
  }

  Future<void> bulkToggleFavorited({required bool favorited}) async {
    final targets = state.selectedJids.toList();
    if (targets.isEmpty) return;
    for (final jid in targets) {
      await _chatsService.toggleChatFavorited(
        jid: jid,
        favorited: favorited,
      );
    }
    clearSelection();
  }

  Future<void> bulkToggleArchived({required bool archived}) async {
    final targets = state.selectedJids.toList();
    if (targets.isEmpty) return;
    for (final jid in targets) {
      if (archived && state.openJid == jid) {
        await _chatsService.closeChat();
      }
      await _chatsService.toggleChatArchived(jid: jid, archived: archived);
    }
    clearSelection();
  }

  Future<void> bulkToggleHidden({required bool hidden}) async {
    final targets = state.selectedJids.toList();
    if (targets.isEmpty) return;
    for (final jid in targets) {
      if (hidden && state.openJid == jid) {
        await _chatsService.closeChat();
      }
      await _chatsService.toggleChatHidden(jid: jid, hidden: hidden);
    }
    clearSelection();
  }

  Future<void> bulkDeleteSelectedChats() async {
    final targets = state.selectedJids.toList();
    if (targets.isEmpty) return;
    for (final jid in targets) {
      if (state.openJid == jid) {
        await _chatsService.closeChat();
      }
      await _chatsService.deleteChat(jid: jid);
    }
    clearSelection();
  }
}
