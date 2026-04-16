// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'folders_state.dart';

enum FolderCollection {
  important;

  String get collectionId => switch (this) {
    FolderCollection.important => SystemMessageCollection.important.id,
  };
}

class FoldersCubit extends Cubit<FoldersState> {
  FoldersCubit({
    required XmppService xmppService,
    this.folder = FolderCollection.important,
    this.chatJid,
  }) : _xmppService = xmppService,
       super(
         FoldersState(
           folder: folder,
           chatJid: chatJid,
           items: null,
           visibleItems: null,
         ),
       ) {
    _subscription = _xmppService
        .messageCollectionItemsStream(folder.collectionId, chatJid: chatJid)
        .listen(_handleItems);
  }

  final XmppService _xmppService;
  final FolderCollection folder;
  final String? chatJid;
  late final StreamSubscription<List<FolderMessageItem>> _subscription;

  void _handleItems(List<FolderMessageItem> items) {
    emit(
      state.copyWith(
        items: items,
        visibleItems: _applyCriteria(
          items,
          query: state.query,
          sortOrder: state.sortOrder,
        ),
      ),
    );
  }

  void updateCriteria({
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
            : _applyCriteria(
                items,
                query: normalizedQuery,
                sortOrder: sortOrder,
              ),
      ),
    );
  }

  List<FolderMessageItem> _applyCriteria(
    List<FolderMessageItem> items, {
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
    final ordered = List<FolderMessageItem>.of(filtered)
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
