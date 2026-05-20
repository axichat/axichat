import 'package:axichat/src/home/bloc/home_bloc.dart';
import 'package:axichat/src/home/view/home_screen.dart';
import 'package:axichat/src/storage/database.dart' as db;
import 'package:axichat/src/storage/models.dart' as m;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home badge counts only include chats', () {
    final counts = resolveHomeBadgeCountsForTesting(chatsUnreadCount: 7);

    expect(counts.contacts, 0);
    expect(counts.important, 0);
    expect(counts.spam, 0);
    expect(counts.folders, 0);
    expect(counts.home, 7);
    expect(counts.tabs[HomeTab.chats], 7);
    expect(counts.tabs[HomeTab.contacts], 0);
    expect(counts.tabs[HomeTab.drafts], 0);
    expect(counts.tabs[HomeTab.folders], 0);
  });

  testWidgets('home badge coordinator ignores non-chat threads', (
    tester,
  ) async {
    late HomeResolvedBadgeCounts capturedCounts;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: HomeBadgeCoordinator(
          chatItems: <m.Chat>[
            m.Chat.fromJid('chat-a@example.com').copyWith(unreadCount: 3),
            m.Chat.fromJid('chat-b@example.com').copyWith(unreadCount: 4),
            m.Chat.fromJid(
              'archived@example.com',
            ).copyWith(unreadCount: 9, archived: true),
            m.Chat.fromJid(
              'spam@example.com',
            ).copyWith(unreadCount: 11, spam: true),
            m.Chat.fromJid(
              'hidden@example.com',
            ).copyWith(unreadCount: 13, hidden: true),
          ],
          builder: (context, badgeCounts) {
            capturedCounts = badgeCounts;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(capturedCounts.chats, 7);
    expect(capturedCounts.contacts, 0);
    expect(capturedCounts.drafts, 0);
    expect(capturedCounts.important, 0);
    expect(capturedCounts.spam, 0);
    expect(capturedCounts.home, 7);
  });

  test('folder unread badges derive from chat unread counts', () {
    final timestamp = DateTime.utc(2026, 5, 20);
    final collections = <db.MessageCollectionEntry>[
      db.MessageCollectionEntry(
        id: 'Projects',
        title: 'Projects',
        isSystem: false,
        sortOrder: 0,
        createdAt: timestamp,
        updatedAt: timestamp,
        active: true,
      ),
      db.MessageCollectionEntry(
        id: 'Receipts',
        title: 'Receipts',
        isSystem: false,
        sortOrder: 1,
        createdAt: timestamp,
        updatedAt: timestamp,
        active: true,
      ),
    ];

    final counts = resolveFolderUnreadBadgeCountsForTesting(
      chats: <m.Chat>[
        m.Chat.fromJid('explicit@example.com').copyWith(unreadCount: 3),
        m.Chat.fromJid('rule@example.com').copyWith(unreadCount: 5),
        m.Chat.fromJid('both@example.com').copyWith(unreadCount: 7),
        m.Chat.fromJid(
          'archived@example.com',
        ).copyWith(unreadCount: 11, archived: true),
        m.Chat.fromJid(
          'spam@example.com',
        ).copyWith(unreadCount: 13, spam: true),
      ],
      collections: collections,
      memberships: <db.MessageCollectionMembershipEntry>[
        db.MessageCollectionMembershipEntry(
          collectionId: 'Projects',
          chatJid: 'explicit@example.com',
          messageReferenceId: 'explicit-message',
          messageStanzaId: 'explicit-message',
          messageOriginId: null,
          messageMucStanzaId: null,
          deltaAccountId: null,
          deltaMsgId: null,
          addedAt: timestamp,
          active: true,
        ),
        db.MessageCollectionMembershipEntry(
          collectionId: 'Projects',
          chatJid: 'both@example.com',
          messageReferenceId: 'both-message',
          messageStanzaId: 'both-message',
          messageOriginId: null,
          messageMucStanzaId: null,
          deltaAccountId: null,
          deltaMsgId: null,
          addedAt: timestamp,
          active: true,
        ),
        db.MessageCollectionMembershipEntry(
          collectionId: 'Projects',
          chatJid: 'archived@example.com',
          messageReferenceId: 'archived-message',
          messageStanzaId: 'archived-message',
          messageOriginId: null,
          messageMucStanzaId: null,
          deltaAccountId: null,
          deltaMsgId: null,
          addedAt: timestamp,
          active: true,
        ),
      ],
      contactFolderRules: const <String, String>{
        'rule@example.com': 'Projects',
        'both@example.com': 'Projects',
        'explicit@example.com': 'Receipts',
      },
    );

    expect(counts.collections['Projects'], 15);
    expect(counts.collections['Receipts'], 3);
    expect(counts.spam, 13);
  });
}
