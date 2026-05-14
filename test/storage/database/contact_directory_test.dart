// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart' hide uuid;
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
    await database.deleteAll();
    await database.close();
  });

  test('getContactDirectoryEntries merges provider contacts only', () async {
    await database.saveRosterItem(
      RosterItem.fromJid('Alice@example.com').copyWith(
        title: 'Roster Alice',
        presence: Presence.chat,
        subscription: Subscription.both,
      ),
    );
    await database.replaceContacts([
      Contact.address(
        nativeID: 'dc-contact-1',
        address: 'alice@example.com',
        displayName: 'Email Alice',
        transport: MessageTransport.email,
      ),
      Contact.address(
        nativeID: 'dc-contact-2',
        address: 'bob@example.com',
        displayName: 'Bob Email',
        transport: MessageTransport.email,
      ),
    ]);
    await database.setContactDisplayNameOverride(
      addressKey: 'alice@example.com',
      displayName: 'Local Alice',
    );
    await database.setContactFavorited(
      addressKey: 'bob@example.com',
      favorited: true,
    );

    final items = await database.getContactDirectoryEntries();

    expect(items, hasLength(2));
    expect(items.map((item) => item.address), [
      'bob@example.com',
      'alice@example.com',
    ]);

    final alice = items.singleWhere(
      (item) => item.address == 'alice@example.com',
    );
    expect(alice.hasXmppRoster, isTrue);
    expect(alice.hasEmailContact, isTrue);
    expect(alice.emailNativeIds, ['dc-contact-1']);
    expect(alice.displayName, 'Local Alice');
    expect(alice.displayNameOverride, 'Local Alice');
    expect(alice.favorited, isFalse);

    final bob = items.singleWhere((item) => item.address == 'bob@example.com');
    expect(bob.hasXmppRoster, isFalse);
    expect(bob.hasEmailContact, isTrue);
    expect(bob.displayName, 'Bob Email');
    expect(bob.favorited, isTrue);
  });

  test('getContactDirectoryEntries falls back to chat avatar paths', () async {
    await database.saveRosterItem(
      RosterItem.fromJid('alice@example.com').copyWith(title: 'Alice'),
    );
    await database.updateChat(
      Chat.fromJid(
        'alice@example.com',
      ).copyWith(avatarPath: '/avatars/alice.enc'),
    );
    await database.createChat(
      Chat.fromJid('bob@example.com').copyWith(avatarPath: '/avatars/bob.enc'),
    );
    await database.replaceContacts([
      Contact.address(
        nativeID: 'dc-contact-4',
        address: 'bob@example.com',
        displayName: 'Bob',
        transport: MessageTransport.email,
      ),
    ]);
    expect(
      (await database.getChat('alice@example.com'))?.avatarPath,
      '/avatars/alice.enc',
    );

    final items = await database.getContactDirectoryEntries();

    expect(
      items
          .singleWhere((item) => item.address == 'alice@example.com')
          .avatarPath,
      '/avatars/alice.enc',
    );
    expect(
      items.singleWhere((item) => item.address == 'bob@example.com').avatarPath,
      '/avatars/bob.enc',
    );
  });

  test(
    'watchContactDirectoryEntries updates for saved email contacts without creating chats',
    () async {
      final contactsFuture = database.watchContactDirectoryEntries().firstWhere(
        (items) => items.any((item) => item.address == 'carol@example.com'),
      );

      await database.replaceContacts([
        Contact.address(
          nativeID: 'dc-contact-3',
          address: 'carol@example.com',
          displayName: 'Carol',
          transport: MessageTransport.email,
        ),
      ]);

      final items = await contactsFuture;
      final carol = items.singleWhere(
        (item) => item.address == 'carol@example.com',
      );

      expect(carol.hasXmppRoster, isFalse);
      expect(carol.hasEmailContact, isTrue);
      expect(carol.displayName, 'Carol');
      expect(await database.getChat('carol@example.com'), isNull);
    },
  );

  test('watchContactPreferences follows private contact records', () async {
    final setFuture = database.watchContactPreferences().firstWhere(
      (items) => items.any(
        (item) =>
            item.addressKey == 'alice@example.com' &&
            item.folderCollectionId == 'Projects',
      ),
    );

    await database.setContactFolderRule(
      addressKey: 'Alice@example.com',
      collectionId: 'Projects',
    );

    expect((await setFuture).single.folderCollectionId, 'Projects');

    final clearFuture = database.watchContactPreferences().firstWhere(
      (items) => items.every((item) => item.addressKey != 'alice@example.com'),
    );

    await database.clearContactFolderRule(addressKey: 'alice@example.com');

    expect(await clearFuture, isEmpty);
  });

  test(
    'contact folder rules derive folder items without membership rows',
    () async {
      await database.applyMessageCollectionDefinitionMutation(
        collectionId: 'Projects',
        updatedAt: DateTime.utc(2026),
        active: true,
      );
      await database.replaceContacts([
        Contact.address(
          nativeID: 'dc-contact-5',
          address: 'alice@example.com',
          displayName: 'Alice',
          transport: MessageTransport.email,
        ),
      ]);
      await database.saveMessage(
        Message(
          stanzaID: 'existing-message',
          senderJid: 'alice@example.com',
          chatJid: 'alice@example.com',
          body: 'Existing',
          timestamp: DateTime.utc(2026, 1, 1, 10),
        ),
      );

      await database.setContactFolderRule(
        addressKey: 'Alice@example.com',
        collectionId: 'Projects',
      );

      expect(await database.getAllMessageCollectionMemberships(), isEmpty);
      expect(
        (await database.getContactDirectoryEntries())
            .singleWhere((item) => item.address == 'alice@example.com')
            .folderCollectionId,
        'Projects',
      );

      await database.saveMessage(
        Message(
          stanzaID: 'future-message',
          senderJid: 'alice@example.com',
          chatJid: 'alice@example.com',
          body: 'Future',
          timestamp: DateTime.utc(2026, 1, 1, 11),
        ),
      );

      expect(await database.getAllMessageCollectionMemberships(), isEmpty);
      expect(
        (await database.getFolderMessageItems(
          'Projects',
        )).map((item) => (item.messageReferenceId, item.isContactRuleDerived)),
        [('future-message', true), ('existing-message', true)],
      );

      await database.applyMessageCollectionMembershipMutation(
        collectionId: 'Projects',
        chatJid: 'alice@example.com',
        messageReferenceId: 'future-message',
        messageStanzaId: 'future-message',
        messageOriginId: null,
        messageMucStanzaId: null,
        deltaAccountId: null,
        deltaMsgId: null,
        addedAt: DateTime.utc(2026, 1, 2),
        active: true,
      );

      expect(
        (await database.getFolderMessageItems(
          'Projects',
        )).map((item) => (item.messageReferenceId, item.isContactRuleDerived)),
        [('future-message', false), ('existing-message', true)],
      );

      await database.clearContactFolderRule(addressKey: 'alice@example.com');
      await database.saveMessage(
        Message(
          stanzaID: 'after-clear-message',
          senderJid: 'alice@example.com',
          chatJid: 'alice@example.com',
          body: 'After clear',
          timestamp: DateTime.utc(2026, 1, 1, 12),
        ),
      );

      expect(
        await database.getMessageCollectionMembership(
          collectionId: 'Projects',
          chatJid: 'alice@example.com',
          messageReferenceId: 'after-clear-message',
        ),
        isNull,
      );
      expect(
        (await database.getMessageCollectionMembership(
          collectionId: 'Projects',
          chatJid: 'alice@example.com',
          messageReferenceId: 'future-message',
        ))?.active,
        isTrue,
      );
      expect(
        (await database.getFolderMessageItems(
          'Projects',
        )).map((item) => item.messageReferenceId),
        ['future-message'],
      );
    },
  );

  test('remote contact folder rule mutations use newest update', () async {
    await database.applyMessageCollectionDefinitionMutation(
      collectionId: 'Projects',
      updatedAt: DateTime.utc(2026),
      active: true,
    );
    await database.replaceContacts([
      Contact.address(
        nativeID: 'dc-contact-6',
        address: 'alice@example.com',
        displayName: 'Alice',
        transport: MessageTransport.email,
      ),
    ]);
    await database.applyContactFolderRuleMutation(
      addressKey: 'alice@example.com',
      collectionId: 'Projects',
      updatedAt: DateTime.utc(2026, 1, 2),
      active: true,
    );

    expect(
      (await database.getContactDirectoryEntries())
          .singleWhere((item) => item.address == 'alice@example.com')
          .folderCollectionId,
      'Projects',
    );

    await database.applyContactFolderRuleMutation(
      addressKey: 'alice@example.com',
      collectionId: null,
      updatedAt: DateTime.utc(2026),
      active: false,
    );

    expect(
      (await database.getContactDirectoryEntries())
          .singleWhere((item) => item.address == 'alice@example.com')
          .folderCollectionId,
      'Projects',
    );

    await database.applyContactFolderRuleMutation(
      addressKey: 'alice@example.com',
      collectionId: null,
      updatedAt: DateTime.utc(2026, 1, 3),
      active: false,
    );

    expect(
      (await database.getContactDirectoryEntries())
          .singleWhere((item) => item.address == 'alice@example.com')
          .folderCollectionId,
      isNull,
    );
  });

  test(
    'remote contact folder rules survive before folder definitions',
    () async {
      await database.replaceContacts([
        Contact.address(
          nativeID: 'dc-contact-7',
          address: 'alice@example.com',
          displayName: 'Alice',
          transport: MessageTransport.email,
        ),
      ]);
      await database.saveMessage(
        Message(
          stanzaID: 'pre-definition-message',
          senderJid: 'alice@example.com',
          chatJid: 'alice@example.com',
          body: 'Before definition',
        ),
      );
      await database.applyContactFolderRuleMutation(
        addressKey: 'alice@example.com',
        collectionId: 'Projects',
        updatedAt: DateTime.utc(2026, 1, 2),
        active: true,
      );

      expect(
        (await database.getContactDirectoryEntries())
            .singleWhere((item) => item.address == 'alice@example.com')
            .folderCollectionId,
        'Projects',
      );
      expect(
        await database.getMessageCollectionMembership(
          collectionId: 'Projects',
          chatJid: 'alice@example.com',
          messageReferenceId: 'pre-definition-message',
        ),
        isNull,
      );

      await database.applyMessageCollectionDefinitionMutation(
        collectionId: 'Projects',
        updatedAt: DateTime.utc(2026, 1, 3),
        active: true,
      );

      expect(
        await database.getMessageCollectionMembership(
          collectionId: 'Projects',
          chatJid: 'alice@example.com',
          messageReferenceId: 'pre-definition-message',
        ),
        isNull,
      );
      expect(
        (await database.getFolderMessageItems(
          'Projects',
        )).single.messageReferenceId,
        'pre-definition-message',
      );
    },
  );

  test(
    'older active folder definitions do not backfill inactive collections',
    () async {
      await database.replaceContacts([
        Contact.address(
          nativeID: 'dc-contact-8',
          address: 'alice@example.com',
          displayName: 'Alice',
          transport: MessageTransport.email,
        ),
      ]);
      await database.saveMessage(
        Message(
          stanzaID: 'inactive-definition-message',
          senderJid: 'alice@example.com',
          chatJid: 'alice@example.com',
          body: 'Inactive definition',
        ),
      );
      await database.applyMessageCollectionDefinitionMutation(
        collectionId: 'Projects',
        updatedAt: DateTime.utc(2026, 1, 3),
        active: false,
      );
      await database.applyContactFolderRuleMutation(
        addressKey: 'alice@example.com',
        collectionId: 'Projects',
        updatedAt: DateTime.utc(2026, 1, 4),
        active: true,
      );

      await database.applyMessageCollectionDefinitionMutation(
        collectionId: 'Projects',
        updatedAt: DateTime.utc(2026, 1, 2),
        active: true,
      );

      expect(
        (await database.getMessageCollection('Projects'))?.active,
        isFalse,
      );
      expect(
        await database.getMessageCollectionMembership(
          collectionId: 'Projects',
          chatJid: 'alice@example.com',
          messageReferenceId: 'inactive-definition-message',
        ),
        isNull,
      );
    },
  );

  test(
    'contact folder rules do not match outgoing self sender identity',
    () async {
      await database.applyMessageCollectionDefinitionMutation(
        collectionId: 'Projects',
        updatedAt: DateTime.utc(2026),
        active: true,
      );
      await database.setContactFolderRule(
        addressKey: 'self@example.com',
        collectionId: 'Projects',
      );

      await database.saveMessage(
        Message(
          stanzaID: 'outgoing-message',
          senderJid: 'self@example.com',
          chatJid: 'bob@example.com',
          body: 'To Bob',
        ),
      );

      expect(
        await database.getMessageCollectionMembership(
          collectionId: 'Projects',
          chatJid: 'bob@example.com',
          messageReferenceId: 'outgoing-message',
        ),
        isNull,
      );
    },
  );
}
