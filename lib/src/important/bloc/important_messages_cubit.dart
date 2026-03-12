// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/important/models/important_message_item.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'important_messages_state.dart';

class ImportantMessagesCubit extends Cubit<ImportantMessagesState> {
  ImportantMessagesCubit({required XmppService xmppService, this.chatJid})
    : _xmppService = xmppService,
      super(
        ImportantMessagesState(
          chatJid: chatJid,
          items: null,
          visibleItems: null,
        ),
      ) {
    _subscription = _xmppService
        .importantMessagesStream(chatJid: chatJid)
        .listen(_handleEntries);
  }

  final XmppService _xmppService;
  final String? chatJid;
  late final StreamSubscription<List<MessageCollectionMembershipEntry>>
  _subscription;

  Future<void> _handleEntries(
    List<MessageCollectionMembershipEntry> entries,
  ) async {
    final db = await _xmppService.database;
    final messageIds = entries
        .map((entry) => entry.messageReferenceId.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final messages = await db.getMessagesByReferenceIds(
      messageIds,
      chatJid: chatJid,
    );
    final messageByReference = <String, Message>{};
    for (final message in messages) {
      for (final referenceId in message.referenceIds) {
        messageByReference[referenceId] = message;
      }
    }
    final chatIds = entries.map((entry) => entry.chatJid).toSet();
    final chats = await db.getChatsByJids(chatIds);
    final chatByJid = <String, Chat>{for (final chat in chats) chat.jid: chat};
    final items = entries
        .map(
          (entry) => ImportantMessageItem(
            entry: entry,
            message: messageByReference[entry.messageReferenceId],
            chat: chatByJid[entry.chatJid],
          ),
        )
        .toList(growable: false);
    emit(
      state.copyWith(
        items: items,
        visibleItems: _applyFilters(
          items,
          query: state.query,
          sortOrder: state.sortOrder,
        ),
      ),
    );
  }

  void updateFilter({
    required String query,
    required SearchSortOrder sortOrder,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    if (state.query == normalizedQuery && state.sortOrder == sortOrder) {
      return;
    }
    final items = state.items;
    emit(
      state.copyWith(
        query: normalizedQuery,
        sortOrder: sortOrder,
        visibleItems: items == null
            ? null
            : _applyFilters(
                items,
                query: normalizedQuery,
                sortOrder: sortOrder,
              ),
      ),
    );
  }

  List<ImportantMessageItem> _applyFilters(
    List<ImportantMessageItem> items, {
    required String query,
    required SearchSortOrder sortOrder,
  }) {
    final filtered = items
        .where((item) {
          if (query.isEmpty) {
            return true;
          }
          final message = item.message;
          final chat = item.chat;
          final subject = message?.subject?.trim().toLowerCase() ?? '';
          final body = message?.body?.trim().toLowerCase() ?? '';
          final chatTitle = chat?.title.trim().toLowerCase() ?? '';
          final chatJid = item.chatJid.trim().toLowerCase();
          final referenceId = item.messageReferenceId.trim().toLowerCase();
          return subject.contains(query) ||
              body.contains(query) ||
              chatTitle.contains(query) ||
              chatJid.contains(query) ||
              referenceId.contains(query);
        })
        .toList(growable: false);
    final ordered = List<ImportantMessageItem>.of(filtered)
      ..sort((a, b) => a.markedAt.compareTo(b.markedAt));
    if (sortOrder.isNewestFirst) {
      return ordered.reversed.toList(growable: false);
    }
    return ordered;
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
