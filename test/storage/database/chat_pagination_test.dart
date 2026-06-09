import 'dart:io';

import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test(
    'getChats honors start and end while preserving all-chats sentinel',
    () async {
      final now = DateTime.utc(2026, 1, 1, 12);
      for (var index = 0; index < 5; index++) {
        await database.createChat(
          Chat(
            jid: 'chat-$index@example.com',
            title: 'Chat $index',
            type: ChatType.chat,
            lastChangeTimestamp: now.add(Duration(minutes: index)),
          ),
        );
      }

      final firstPage = await database.getChats(start: 0, end: 2);
      final secondPage = await database.getChats(start: 2, end: 4);
      final allChats = await database.getChats(start: 0, end: 0);

      expect(firstPage.map((chat) => chat.jid), [
        'chat-4@example.com',
        'chat-3@example.com',
      ]);
      expect(secondPage.map((chat) => chat.jid), [
        'chat-2@example.com',
        'chat-1@example.com',
      ]);
      expect(allChats.map((chat) => chat.jid), [
        'chat-4@example.com',
        'chat-3@example.com',
        'chat-2@example.com',
        'chat-1@example.com',
        'chat-0@example.com',
      ]);
    },
  );

  test('watchChats honors start and end', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    for (var index = 0; index < 3; index++) {
      await database.createChat(
        Chat(
          jid: 'watch-$index@example.com',
          title: 'Watch $index',
          type: ChatType.chat,
          lastChangeTimestamp: now.add(Duration(minutes: index)),
        ),
      );
    }

    await expectLater(
      database.watchChats(start: 0, end: 2),
      emits(
        predicate<List<Chat>>(
          (chats) =>
              chats.map((chat) => chat.jid).toList(growable: false).join(',') ==
              'watch-2@example.com,watch-1@example.com',
        ),
      ),
    );
  });

  test('folder badge unread chats exclude read chats', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    await database.createChat(
      Chat(
        jid: 'read@example.com',
        title: 'Read',
        type: ChatType.chat,
        unreadCount: 0,
        lastChangeTimestamp: now.add(const Duration(minutes: 2)),
      ),
    );
    await database.createChat(
      Chat(
        jid: 'unread-old@example.com',
        title: 'Unread old',
        type: ChatType.chat,
        unreadCount: 1,
        lastChangeTimestamp: now,
      ),
    );
    await database.createChat(
      Chat(
        jid: 'unread-new@example.com',
        title: 'Unread new',
        type: ChatType.chat,
        unreadCount: 2,
        lastChangeTimestamp: now.add(const Duration(minutes: 1)),
      ),
    );

    final unread = await database.getUnreadChatsForFolderBadges();

    expect(unread.map((chat) => chat.jid), [
      'unread-new@example.com',
      'unread-old@example.com',
    ]);
  });
}
