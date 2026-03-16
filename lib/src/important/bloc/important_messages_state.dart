// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'important_messages_cubit.dart';

class ImportantMessagesState extends Equatable {
  const ImportantMessagesState({
    required this.chatJid,
    required this.items,
    required this.visibleItems,
    this.query = '',
    this.sortOrder = SearchSortOrder.newestFirst,
  });

  final String? chatJid;
  final List<ImportantMessageItem>? items;
  final List<ImportantMessageItem>? visibleItems;
  final String query;
  final SearchSortOrder sortOrder;

  ImportantMessagesState copyWith({
    String? chatJid,
    List<ImportantMessageItem>? items,
    List<ImportantMessageItem>? visibleItems,
    String? query,
    SearchSortOrder? sortOrder,
  }) {
    return ImportantMessagesState(
      chatJid: chatJid ?? this.chatJid,
      items: items ?? this.items,
      visibleItems: visibleItems ?? this.visibleItems,
      query: query ?? this.query,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  List<Object?> get props => [chatJid, items, visibleItems, query, sortOrder];
}

class ImportantMessageItem extends Equatable {
  const ImportantMessageItem({
    required this.entry,
    required this.message,
    required this.chat,
  });

  final MessageCollectionMembershipEntry entry;
  final Message? message;
  final Chat? chat;

  String get messageReferenceId => entry.messageReferenceId;

  String get chatJid => entry.chatJid;

  DateTime get markedAt => entry.addedAt;

  bool get hasMessage => message != null;

  @override
  List<Object?> get props => [entry, message, chat];
}
