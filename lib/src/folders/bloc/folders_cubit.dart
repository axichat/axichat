// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'folders_state.dart';

class FoldersCubit extends Cubit<FoldersState> {
  FoldersCubit({
    required XmppService xmppService,
    String collectionId = 'important',
    this.chatJid,
  }) : _xmppService = xmppService,
       collectionId = collectionId.trim().isEmpty
           ? SystemMessageCollection.important.id
           : collectionId.trim(),
       super(
         FoldersState(
           collectionId: collectionId.trim().isEmpty
               ? SystemMessageCollection.important.id
               : collectionId.trim(),
           chatJid: chatJid,
           collections: null,
           memberships: null,
           contactFolderRules: const <String, String>{},
           items: null,
           visibleItems: null,
         ),
       ) {
    _itemsSubscription = _xmppService
        .messageCollectionItemsStream(this.collectionId, chatJid: chatJid)
        .listen(_handleItems);
    _collectionsSubscription = _xmppService.messageCollectionsStream().listen(
      _handleCollections,
    );
    _membershipsSubscription = _xmppService
        .allMessageCollectionMembershipsStream(chatJid: chatJid)
        .listen(_handleMemberships);
    _contactFolderRulesSubscription = _xmppService
        .contactFolderRulesStream()
        .listen(_handleContactFolderRules);
  }

  final XmppService _xmppService;
  final String collectionId;
  final String? chatJid;
  late final StreamSubscription<List<FolderMessageItem>> _itemsSubscription;
  late final StreamSubscription<List<MessageCollectionEntry>>
  _collectionsSubscription;
  late final StreamSubscription<List<MessageCollectionMembershipEntry>>
  _membershipsSubscription;
  late final StreamSubscription<Map<String, String>>
  _contactFolderRulesSubscription;

  void _handleCollections(List<MessageCollectionEntry> collections) {
    emit(state.copyWith(collections: collections));
  }

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

  void _handleMemberships(List<MessageCollectionMembershipEntry> memberships) {
    emit(state.copyWith(memberships: memberships));
  }

  void _handleContactFolderRules(Map<String, String> rules) {
    emit(state.copyWith(contactFolderRules: rules));
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

  void clearActionState() {
    if (state.actionState is FoldersActionIdle) {
      return;
    }
    emit(state.copyWith(actionState: const FoldersActionIdle()));
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

  Future<MessageCollectionEntry?> createFolder(String title) async {
    const loading = FoldersActionLoading(
      action: FoldersActionType.createFolder,
    );
    if (state.isFolderActionLoading(loading)) return null;
    emit(state.markFolderActionLoading(loading));
    try {
      final collection = await _xmppService.createMessageCollection(
        title: title,
      );
      emit(
        state
            .clearFolderActionLoading(loading)
            .copyWith(
              actionState: FoldersActionSuccess(
                action: FoldersActionType.createFolder,
                collectionId: collection.id,
              ),
            ),
      );
      return collection;
    } on MessageCollectionNameException catch (error) {
      emit(
        state
            .clearFolderActionLoading(loading)
            .copyWith(
              actionState: FoldersActionFailure(
                action: FoldersActionType.createFolder,
                reason: FoldersFailureReason.invalidName,
                nameFailure: error.failure,
              ),
            ),
      );
      return null;
    } on XmppMessageException {
      emit(
        state
            .clearFolderActionLoading(loading)
            .copyWith(
              actionState: const FoldersActionFailure(
                action: FoldersActionType.createFolder,
                reason: FoldersFailureReason.createFailed,
              ),
            ),
      );
      return null;
    }
  }

  Future<bool> removeItem(FolderMessageItem item) async {
    if (item.isContactRuleDerived) {
      return false;
    }
    final collectionId = item.collectionId.trim();
    final chatJid = item.chatJid.trim();
    final messageReferenceId = item.messageReferenceId.trim();
    final loading = FoldersActionLoading(
      action: FoldersActionType.removeMembership,
      collectionId: collectionId,
      chatJid: chatJid,
      messageReferenceId: messageReferenceId,
    );
    if (state.isFolderActionLoading(loading)) return false;
    emit(state.markFolderActionLoading(loading));
    try {
      final removed = await _xmppService.removeMessageCollectionMembership(
        item,
      );
      if (!removed) {
        emit(
          state
              .clearFolderActionLoading(loading)
              .copyWith(
                actionState: FoldersActionFailure(
                  action: FoldersActionType.removeMembership,
                  reason: FoldersFailureReason.removeFailed,
                  collectionId: collectionId,
                  chatJid: chatJid,
                  messageReferenceId: messageReferenceId,
                ),
              ),
        );
        return false;
      }
      emit(
        state
            .clearFolderActionLoading(loading)
            .copyWith(
              actionState: FoldersActionSuccess(
                action: FoldersActionType.removeMembership,
                collectionId: collectionId,
                chatJid: chatJid,
                messageReferenceId: messageReferenceId,
              ),
            ),
      );
      return true;
    } on XmppMessageException {
      emit(
        state
            .clearFolderActionLoading(loading)
            .copyWith(
              actionState: FoldersActionFailure(
                action: FoldersActionType.removeMembership,
                reason: FoldersFailureReason.removeFailed,
                collectionId: collectionId,
                chatJid: chatJid,
                messageReferenceId: messageReferenceId,
              ),
            ),
      );
      return false;
    }
  }

  @override
  Future<void> close() async {
    await _itemsSubscription.cancel();
    await _collectionsSubscription.cancel();
    await _membershipsSubscription.cancel();
    await _contactFolderRulesSubscription.cancel();
    return super.close();
  }
}
