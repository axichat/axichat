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
            openStack: <String>[],
            forwardStack: <String>[],
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
    final retainedStack = state.openStack
        .where((jid) => availableJids.contains(jid))
        .toList(growable: false);
    final retainedForward = state.forwardStack
        .where((jid) => availableJids.contains(jid))
        .toList(growable: false);
    final fallbackOpen =
        items.where((chat) => chat.open).firstOrNull?.jid ?? state.openJid;
    final seededStack = retainedStack.isNotEmpty
        ? retainedStack
        : [
            if (fallbackOpen != null && availableJids.contains(fallbackOpen))
              fallbackOpen,
          ];
    emit(
      state.copyWith(
        openStack: seededStack,
        forwardStack: retainedForward,
        openJid: seededStack.isEmpty ? null : seededStack.last,
        items: items,
        selectedJids: retainedSelection,
      ),
    );
  }

  Future<void> toggleChat({required String jid}) async {
    final currentTop = state.openStack.isEmpty ? null : state.openStack.last;
    if (jid == currentTop) {
      if (state.openStack.length > 1) {
        await popChat();
      } else {
        await closeAllChats();
      }
      return;
    }
    // Close calendar when opening chat
    if (state.openCalendar) {
      emit(state.copyWith(openCalendar: false));
    }
    await pushChat(jid: jid);
  }

  Future<void> pushChat({required String jid}) async {
    final filtered =
        state.openStack.where((entry) => entry != jid).toList(growable: false);
    final nextStack = [...filtered, jid];
    emit(
      state.copyWith(
        openStack: nextStack,
        forwardStack: const <String>[],
        openJid: jid,
      ),
    );
    await _chatsService.openChat(jid);
  }

  Future<void> popChat() async {
    if (state.openStack.isEmpty) return;
    final popped = state.openStack.last;
    final nextStack = List<String>.of(state.openStack)..removeLast();
    final nextForward = List<String>.of(state.forwardStack)..add(popped);
    final nextOpen = nextStack.isEmpty ? null : nextStack.last;
    emit(
      state.copyWith(
        openStack: nextStack,
        forwardStack: nextForward,
        openJid: nextOpen,
      ),
    );
    if (nextOpen == null) {
      await _chatsService.closeChat();
    } else {
      await _chatsService.openChat(nextOpen);
    }
  }

  Future<void> restoreChat() async {
    if (state.forwardStack.isEmpty) return;
    final restored = state.forwardStack.last;
    final nextForward = List<String>.of(state.forwardStack)..removeLast();
    final filteredStack =
        state.openStack.where((entry) => entry != restored).toList();
    filteredStack.add(restored);
    emit(
      state.copyWith(
        forwardStack: nextForward,
        openStack: filteredStack,
        openJid: restored,
      ),
    );
    await _chatsService.openChat(restored);
  }

  Future<void> closeAllChats() async {
    if (state.openStack.isEmpty && state.forwardStack.isEmpty) return;
    emit(
      state.copyWith(
        openStack: const <String>[],
        forwardStack: const <String>[],
        openJid: null,
      ),
    );
    await _chatsService.closeChat();
  }

  void toggleCalendar() {
    if (state.openCalendar) {
      emit(state.copyWith(openCalendar: false));
    } else {
      emit(state.copyWith(openCalendar: true));
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
    final mucService = _chatsService as MucService;
    try {
      final roomJid = await mucService.createRoom(
        name: title,
        nickname: nickname,
      );
      await _chatsService.openChat(roomJid);
      emit(state.copyWith(creationStatus: RequestStatus.success));
    } on Exception {
      emit(state.copyWith(creationStatus: RequestStatus.failure));
    }
  }

  Future<void> deleteChat({required String jid}) async {
    await _chatsService.deleteChat(jid: jid);
  }

  Future<void> deleteChatMessages({required String jid}) async {
    await _chatsService.deleteChatMessages(jid: jid);
  }

  Future<void> renameContact({
    required String jid,
    required String displayName,
  }) {
    return _chatsService.renameChatContact(
      jid: jid,
      displayName: displayName,
    );
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
