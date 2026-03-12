// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:equatable/equatable.dart';

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
