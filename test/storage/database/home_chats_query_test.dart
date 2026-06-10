// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late XmppDrift database;

  setUp(() {
    database = XmppDrift(
      file: File(''),
      passphrase: '',
      executor: NativeDatabase.memory(),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> seedChat({
    required String jid,
    required DateTime lastChange,
    int unreadCount = 0,
  }) {
    return database.createChat(
      Chat(
        jid: jid,
        title: jid,
        type: ChatType.chat,
        lastChangeTimestamp: lastChange,
        transport: MessageTransport.email,
        unreadCount: unreadCount,
      ),
    );
  }

  test(
    'home query includes every unread chat beyond the recent window',
    () async {
      for (var index = 0; index < 6; index++) {
        await seedChat(
          jid: 'recent-$index@example.com',
          lastChange: DateTime.utc(2026, 6, 10, index),
        );
      }
      await seedChat(
        jid: 'old-unread@example.com',
        lastChange: DateTime.utc(2020, 1, 1),
        unreadCount: 4,
      );
      await seedChat(
        jid: 'old-read@example.com',
        lastChange: DateTime.utc(2020, 1, 2),
      );

      final home = await database.getHomeChats(recentLimit: 3);
      final jids = home.map((chat) => chat.jid).toSet();

      expect(jids, contains('old-unread@example.com'));
      expect(jids, isNot(contains('old-read@example.com')));
      expect(jids, contains('recent-5@example.com'));
      expect(jids, contains('recent-4@example.com'));
      expect(jids, contains('recent-3@example.com'));
      expect(jids, isNot(contains('recent-0@example.com')));
    },
  );

  test(
    'home query fills with recent read chats when nothing is unread',
    () async {
      for (var index = 0; index < 4; index++) {
        await seedChat(
          jid: 'chat-$index@example.com',
          lastChange: DateTime.utc(2026, 6, 10, index),
        );
      }

      final home = await database.getHomeChats(recentLimit: 10);

      expect(home, hasLength(4));
    },
  );
}
