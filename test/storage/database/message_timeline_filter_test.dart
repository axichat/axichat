import 'dart:convert';
import 'dart:io';

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/calendar_task_ics_message.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late XmppDrift db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('timeline_filter_test');
    final file = File('${tempDir.path}/db.sqlite');
    db = XmppDrift(
      file: file,
      passphrase: 'passphrase',
      executor: NativeDatabase.memory(),
    );
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  test('message timeline filters respect share participants', () async {
    final contact = Chat(
      jid: 'dc-1@delta.chat',
      title: 'Bob',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime(2024, 1, 1),
      deltaChatId: 1,
      emailAddress: 'bob@example.com',
    );
    final otherContact = Chat(
      jid: 'dc-2@delta.chat',
      title: 'Carol',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime(2024, 1, 1),
      deltaChatId: 2,
      emailAddress: 'carol@example.com',
    );
    await db.createChat(contact);
    await db.createChat(otherContact);

    final directMessage = Message(
      stanzaID: 'direct-1',
      senderJid: contact.jid,
      chatJid: contact.jid,
      timestamp: DateTime.utc(2024, 1, 1),
      body: 'Direct hello',
      encryptionProtocol: EncryptionProtocol.none,
    );
    await db.saveMessage(directMessage);

    const shareId = '01HX5R8W7YAYR5K1R7Q7MB5G4W';
    final sharedMessage = Message(
      stanzaID: 'share-1',
      senderJid: contact.jid,
      chatJid: contact.jid,
      timestamp: DateTime.utc(2024, 1, 2),
      body: 'Shared hello',
      encryptionProtocol: EncryptionProtocol.none,
      deltaChatId: contact.deltaChatId,
      deltaMsgId: 42,
    );
    await db.saveMessage(sharedMessage);

    final participants = [
      const MessageParticipantData(
        shareId: shareId,
        contactJid: 'dc-self@delta.chat',
        role: MessageParticipantRole.sender,
      ),
      MessageParticipantData(
        shareId: shareId,
        contactJid: contact.jid,
        role: MessageParticipantRole.recipient,
      ),
      MessageParticipantData(
        shareId: shareId,
        contactJid: otherContact.jid,
        role: MessageParticipantRole.recipient,
      ),
    ];

    await db.createMessageShare(
      share: MessageShareData(
        shareId: shareId,
        originatorDcMsgId: null,
        subjectToken: shareId,
        createdAt: DateTime.utc(2024, 1, 2),
        participantCount: participants.length,
      ),
      participants: participants,
    );

    await db.insertMessageCopy(
      shareId: shareId,
      dcMsgId: sharedMessage.deltaMsgId!,
      dcChatId: contact.deltaChatId!,
    );

    final directOnly = await db.getChatMessages(
      contact.jid,
      start: 0,
      end: 10,
      filter: MessageTimelineFilter.directOnly,
    );
    final allWithContact = await db.getChatMessages(
      contact.jid,
      start: 0,
      end: 10,
      filter: MessageTimelineFilter.allWithContact,
    );

    expect(directOnly.map((msg) => msg.stanzaID), isNot(contains('share-1')));
    expect(allWithContact.map((msg) => msg.stanzaID), contains('share-1'));
    expect(allWithContact.map((msg) => msg.stanzaID), contains('direct-1'));
  });

  test(
    'email chat accounts keep multiple Delta chats for one chat account',
    () async {
      final chat = Chat(
        jid: 'multi-delta@example.com',
        title: 'Multi Delta',
        type: ChatType.chat,
        transport: MessageTransport.email,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        deltaChatId: 101,
        emailAddress: 'multi-delta@example.com',
      );
      await db.createChat(chat);

      await db.upsertEmailChatAccount(
        chatJid: chat.jid,
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: 101,
      );
      await db.upsertEmailChatAccount(
        chatJid: chat.jid,
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: 202,
      );

      expect(
        await db.getDeltaChatIdsForAccount(
          chatJid: chat.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
        [202, 101],
      );
      expect(
        (await db.getChatByDeltaChatId(
          101,
          accountId: DeltaAccountDefaults.legacyId,
        ))?.jid,
        chat.jid,
      );
      expect(
        (await db.getChatByDeltaChatId(
          202,
          accountId: DeltaAccountDefaults.legacyId,
        ))?.jid,
        chat.jid,
      );

      await db.deleteEmailChatAccount(
        chatJid: chat.jid,
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: 101,
      );

      expect(
        await db.getDeltaChatIdsForAccount(
          chatJid: chat.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
        [202],
      );
      expect(
        await db.getChatByDeltaChatId(
          101,
          accountId: DeltaAccountDefaults.legacyId,
        ),
        isNull,
      );
    },
  );

  test(
    'message copy insert is idempotent for duplicate delta message',
    () async {
      const originalShareId = '01HX5R8W7YAYR5K1R7Q7MB5G4A';
      const duplicateShareId = '01HX5R8W7YAYR5K1R7Q7MB5G4B';
      await db.createMessageShare(
        share: MessageShareData(
          shareId: originalShareId,
          originatorDcMsgId: null,
          createdAt: DateTime.utc(2026, 5, 23),
          participantCount: 0,
        ),
        participants: const [],
      );
      await db.createMessageShare(
        share: MessageShareData(
          shareId: duplicateShareId,
          originatorDcMsgId: null,
          createdAt: DateTime.utc(2026, 5, 23),
          participantCount: 0,
        ),
        participants: const [],
      );

      await db.insertMessageCopy(
        shareId: originalShareId,
        dcMsgId: 58,
        dcChatId: 18,
        dcAccountId: 1,
      );
      await db.insertMessageCopy(
        shareId: duplicateShareId,
        dcMsgId: 58,
        dcChatId: 19,
        dcAccountId: 1,
      );

      expect(
        await db.getShareIdForDeltaMessage(58, deltaAccountId: 1),
        originalShareId,
      );
      final originalCopies = await db.getMessageCopiesForShare(originalShareId);
      final duplicateCopies = await db.getMessageCopiesForShare(
        duplicateShareId,
      );
      expect(originalCopies, hasLength(1));
      expect(originalCopies.single.dcChatId, 19);
      expect(duplicateCopies, isEmpty);
    },
  );

  test('email-backed message counts ignore native XMPP rows', () async {
    final chat = Chat(
      jid: 'mixed@axi.im',
      title: 'Mixed',
      type: ChatType.chat,
      transport: MessageTransport.xmpp,
      lastChangeTimestamp: DateTime.utc(2024, 1, 1),
      emailAddress: 'mixed@example.com',
    );
    await db.createChat(chat);

    await db.saveMessage(
      Message(
        stanzaID: 'native-xmpp',
        senderJid: chat.jid,
        chatJid: chat.jid,
        timestamp: DateTime.utc(2024, 1, 1, 10),
        body: 'Native XMPP',
      ),
    );
    await db.saveMessage(
      Message(
        stanzaID: 'email-account-zero',
        senderJid: 'mixed@example.com',
        chatJid: chat.jid,
        timestamp: DateTime.utc(2024, 1, 1, 11),
        body: 'Email account zero',
        deltaChatId: 10,
        deltaMsgId: 100,
      ),
    );
    await db.saveMessage(
      Message(
        stanzaID: 'email-account-one',
        senderJid: 'mixed@example.com',
        chatJid: chat.jid,
        timestamp: DateTime.utc(2024, 1, 1, 12),
        body: 'Email account one',
        deltaAccountId: 1,
        deltaChatId: 20,
        deltaMsgId: 200,
      ),
    );
    await db.saveMessage(
      Message(
        stanzaID: 'email-pending-account-zero',
        senderJid: 'self@example.com',
        chatJid: chat.jid,
        timestamp: DateTime.utc(2024, 1, 1, 13),
        body: 'Pending email',
        deltaChatId: 10,
      ),
    );

    expect(await db.countChatMessages(chat.jid), 4);
    expect(await db.countEmailBackedChatMessages(chat.jid), 3);
    expect(
      await db.countEmailBackedChatMessages(
        chat.jid,
        deltaAccountId: DeltaAccountDefaults.legacyId,
      ),
      2,
    );
    expect(
      await db.countEmailBackedChatMessages(chat.jid, deltaAccountId: 1),
      1,
    );
  });

  test(
    'email chat account upsert can move a Delta chat between rows',
    () async {
      const deltaChatId = 42;
      final nativeEmail = Chat(
        jid: 'mixed@example.com',
        title: 'Mixed Email',
        type: ChatType.chat,
        transport: MessageTransport.email,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        deltaChatId: deltaChatId,
        emailAddress: 'mixed@example.com',
      );
      final mixedXmpp = Chat(
        jid: 'mixed@axi.im',
        title: 'Mixed XMPP',
        type: ChatType.chat,
        transport: MessageTransport.xmpp,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        deltaChatId: deltaChatId,
        emailAddress: 'mixed@example.com',
      );
      await db.createChat(nativeEmail);
      await db.createChat(mixedXmpp);

      await db.upsertEmailChatAccount(
        chatJid: nativeEmail.jid,
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: deltaChatId,
      );
      await db.upsertEmailChatAccount(
        chatJid: mixedXmpp.jid,
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: deltaChatId,
      );

      expect(
        await db.getDeltaChatIdForAccount(
          chatJid: nativeEmail.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
        isNull,
      );
      expect(
        await db.getDeltaChatIdForAccount(
          chatJid: mixedXmpp.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
        deltaChatId,
      );
      expect(
        (await db.getChatByDeltaChatId(
          deltaChatId,
          accountId: DeltaAccountDefaults.legacyId,
        ))?.jid,
        mixedXmpp.jid,
      );
    },
  );

  test(
    'saveMessage does not increment unread for direct self messages',
    () async {
      const selfJid = 'me@example.com';
      const peerJid = 'peer@example.com';
      final chat = Chat(
        jid: peerJid,
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.email,
        emailAddress: peerJid,
      );
      await db.createChat(chat);

      await db.saveMessage(
        Message(
          stanzaID: 'outbound-1',
          senderJid: selfJid,
          chatJid: peerJid,
          timestamp: DateTime.utc(2024, 1, 1, 10),
          body: 'Outbound hello',
          encryptionProtocol: EncryptionProtocol.none,
        ),
        selfJid: selfJid,
      );

      final afterOutbound = await db.getChat(peerJid);
      expect(afterOutbound?.unreadCount, 0);

      await db.saveMessage(
        Message(
          stanzaID: 'inbound-1',
          senderJid: peerJid,
          chatJid: peerJid,
          timestamp: DateTime.utc(2024, 1, 1, 11),
          body: 'Inbound hello',
          encryptionProtocol: EncryptionProtocol.none,
        ),
        selfJid: selfJid,
      );

      final afterInbound = await db.getChat(peerJid);
      expect(afterInbound?.unreadCount, 1);
    },
  );

  test('group messages persist sender real JID and skip self unread', () async {
    const roomJid = 'room@conference.example.com';
    const selfJid = 'me@example.com';
    await db.saveMessage(
      Message(
        stanzaID: 'group-self-1',
        senderJid: '$roomJid/old',
        senderRealJid: selfJid,
        chatJid: roomJid,
        timestamp: DateTime.utc(2024, 1, 1, 10),
        body: 'Self message before nick change',
        encryptionProtocol: EncryptionProtocol.none,
      ),
      chatType: ChatType.groupChat,
      selfJid: selfJid,
    );

    final stored = await db.getMessageByStanzaID('group-self-1');
    expect(stored?.senderJid, '$roomJid/old');
    expect(stored?.senderRealJid, selfJid);
    expect((await db.getChat(roomJid))?.unreadCount, 0);
    expect(await db.countUnreadMessagesForChat(roomJid, selfJid: selfJid), 0);
  });

  test('hydrates missing MUC identity without clobbering real JID', () async {
    const roomJid = 'room@conference.example.com';
    await db.saveMessage(
      Message(
        stanzaID: 'muc-identity-hydrate',
        senderJid: '$roomJid/alice',
        senderRealJid: 'alice@example.com',
        chatJid: roomJid,
        timestamp: DateTime.utc(2024, 1, 1, 10),
        body: 'MUC message',
        encryptionProtocol: EncryptionProtocol.none,
      ),
      chatType: ChatType.groupChat,
    );

    await db.hydrateMessageMucIdentity(
      stanzaID: 'muc-identity-hydrate',
      senderRealJid: 'mallory@example.com',
      occupantID: 'opaque-alice',
      mucStanzaId: 'room-stanza-id',
    );
    final stored = await db.getMessageByStanzaID('muc-identity-hydrate');

    expect(stored?.senderRealJid, 'alice@example.com');
    expect(stored?.occupantID, 'opaque-alice');
    expect(stored?.mucStanzaId, 'room-stanza-id');
  });

  test('replaces only pending outbound MUC identity', () async {
    const roomJid = 'room@conference.example.com';
    await db.saveMessage(
      Message(
        stanzaID: 'pending-muc-send',
        senderJid: '$roomJid/old',
        senderRealJid: 'me@example.com',
        chatJid: roomJid,
        timestamp: DateTime.utc(2024, 1, 1, 10),
        body: 'pending send',
        encryptionProtocol: EncryptionProtocol.none,
      ),
      chatType: ChatType.groupChat,
    );

    await db.replacePendingOutboundMucIdentity(
      stanzaID: 'pending-muc-send',
      senderJid: '$roomJid/new',
      senderRealJid: 'me@example.com',
      occupantID: 'opaque-self',
    );
    final refreshed = await db.getMessageByStanzaID('pending-muc-send');
    expect(refreshed?.senderJid, '$roomJid/new');
    expect(refreshed?.senderRealJid, 'me@example.com');
    expect(refreshed?.occupantID, 'opaque-self');

    await db.markMessageAcked('pending-muc-send', chatJid: roomJid);
    await db.replacePendingOutboundMucIdentity(
      stanzaID: 'pending-muc-send',
      senderJid: '$roomJid/too-late',
      senderRealJid: 'other@example.com',
      occupantID: 'other-occupant',
    );
    final acked = await db.getMessageByStanzaID('pending-muc-send');
    expect(acked?.senderJid, '$roomJid/new');
    expect(acked?.senderRealJid, 'me@example.com');
    expect(acked?.occupantID, 'opaque-self');
  });

  test(
    'saveMessage increments unread for inbound invite pseudo messages',
    () async {
      const selfJid = 'me@example.com';
      const peerJid = 'peer@example.com';
      final chat = Chat(
        jid: peerJid,
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
      );
      await db.createChat(chat);

      await db.saveMessage(
        Message(
          stanzaID: 'invite-1',
          senderJid: peerJid,
          chatJid: peerJid,
          timestamp: DateTime.utc(2024, 1, 1, 12),
          body: 'You have been invited to a group chat',
          pseudoMessageType: PseudoMessageType.mucInvite,
          pseudoMessageData: const {
            'room': 'room@conference.example.com',
            'token': 'invite-token',
          },
          encryptionProtocol: EncryptionProtocol.none,
        ),
        selfJid: selfJid,
      );

      final afterInvite = await db.getChat(peerJid);
      expect(afterInvite?.unreadCount, 1);
      expect(afterInvite?.lastMessage, 'You have been invited to a group chat');

      await db.openChat(peerJid);

      final afterOpen = await db.getChat(peerJid);
      expect(afterOpen?.unreadCount, 0);
    },
  );

  test(
    'accepted invite markers update the invite without replacing the summary',
    () async {
      const selfJid = 'me@example.com';
      const peerJid = 'peer@example.com';
      final chat = Chat(
        jid: peerJid,
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
      );
      await db.createChat(chat);

      await db.saveMessage(
        Message(
          stanzaID: 'invite-summary-source',
          senderJid: selfJid,
          chatJid: peerJid,
          timestamp: DateTime.utc(2024, 1, 1, 12),
          body: 'You have been invited to a group chat',
          pseudoMessageType: PseudoMessageType.mucInvite,
          pseudoMessageData: const {
            'roomJid': 'room@conference.example.com',
            'token': 'invite-token',
            'inviter': selfJid,
            'invitee': peerJid,
          },
          encryptionProtocol: EncryptionProtocol.none,
        ),
        selfJid: selfJid,
      );

      await db.saveMessage(
        Message(
          stanzaID: 'invite-summary-accepted',
          senderJid: peerJid,
          chatJid: peerJid,
          timestamp: DateTime.utc(2024, 1, 1, 13),
          body: 'Invite accepted',
          pseudoMessageType: PseudoMessageType.mucInviteAccepted,
          pseudoMessageData: const {
            'roomJid': 'room@conference.example.com',
            'token': 'invite-token',
            'inviter': selfJid,
            'invitee': peerJid,
            'accepted': true,
          },
          encryptionProtocol: EncryptionProtocol.none,
        ),
        selfJid: selfJid,
      );

      final afterAcceptance = await db.getChat(peerJid);
      expect(
        afterAcceptance?.lastMessage,
        'You have been invited to a group chat',
      );
      expect(afterAcceptance?.unreadCount, 0);
      expect(
        await db.getLastMessageForChat(
          peerJid,
          filter: MessageTimelineFilter.allWithContact,
        ),
        isNotNull,
      );
      expect(
        (await db.getLastMessageForChat(
          peerJid,
          filter: MessageTimelineFilter.allWithContact,
        ))?.stanzaID,
        'invite-summary-source',
      );
    },
  );

  test(
    'createChat rebuilds invite lastMessage from persisted messages',
    () async {
      const peerJid = 'peer@example.com';

      await db.saveMessage(
        Message(
          stanzaID: 'invite-rebuild-1',
          senderJid: peerJid,
          chatJid: peerJid,
          timestamp: DateTime.utc(2024, 1, 1, 12),
          body: 'You have been invited to a group chat',
          pseudoMessageType: PseudoMessageType.mucInvite,
          pseudoMessageData: const {
            'room': 'room@conference.example.com',
            'token': 'invite-token',
          },
          encryptionProtocol: EncryptionProtocol.none,
        ),
      );

      await db.customStatement('DELETE FROM chats WHERE jid = ?', [peerJid]);

      await db.createChat(
        Chat(
          jid: peerJid,
          title: 'Peer',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        ),
      );

      final recreated = await db.getChat(peerJid);
      expect(recreated?.lastMessage, 'You have been invited to a group chat');
    },
  );

  test('same-timestamp summary updates replace a forwarded preview', () async {
    final contact = Chat(
      jid: 'shared-summary@delta.chat',
      title: 'Shared Summary',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2024, 1, 1),
      deltaChatId: 7,
      emailAddress: 'shared-summary@example.com',
    );
    await db.createChat(contact);

    final sharedTimestamp = DateTime.utc(2024, 1, 5, 12);
    await db.saveMessage(
      Message(
        stanzaID: 'shared-forward-1',
        senderJid: contact.jid,
        chatJid: contact.jid,
        timestamp: sharedTimestamp,
        body: 'forwarded payload',
        subject: 'FWD: sender@example.com',
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: contact.deltaChatId,
        deltaMsgId: 77,
      ),
    );
    await db.saveMessage(
      Message(
        stanzaID: 'direct-summary-1',
        senderJid: contact.jid,
        chatJid: contact.jid,
        timestamp: sharedTimestamp,
        body: 'latest direct message',
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: contact.deltaChatId,
        deltaMsgId: 78,
      ),
    );
    await db.saveMessage(
      Message(
        stanzaID: 'direct-summary-2',
        senderJid: contact.jid,
        chatJid: contact.jid,
        timestamp: sharedTimestamp,
        body: 'latest direct message v2',
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: contact.deltaChatId,
        deltaMsgId: 79,
      ),
    );

    final updatedChat = await db.getChat(contact.jid);
    expect(updatedChat?.lastMessage, 'latest direct message v2');
  });

  test(
    'repairChatSummaryPreservingTimestamp fixes stale preview without rolling back timestamp',
    () async {
      final contact = Chat(
        jid: 'repair-summary@axi.im',
        title: 'Repair Summary',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 7, 18),
      );
      await db.createChat(
        contact.copyWith(lastMessage: 'FWD: sender@example.com'),
      );

      await db.saveMessage(
        Message(
          stanzaID: 'repair-summary-1',
          senderJid: contact.jid,
          chatJid: contact.jid,
          timestamp: DateTime.utc(2024, 1, 7, 9),
          body: 'much newer actual message',
          encryptionProtocol: EncryptionProtocol.none,
        ),
      );

      await db.repairChatSummaryPreservingTimestamp(contact.jid);

      final repaired = await db.getChat(contact.jid);
      expect(repaired?.lastMessage, 'much newer actual message');
      expect(repaired?.lastChangeTimestamp, DateTime.utc(2024, 1, 7, 18));
    },
  );

  test(
    'repairGeneratedEmailAttachmentCaptionBodies clears legacy attachment caption bodies',
    () async {
      final contact = Chat(
        jid: 'legacy-caption@axi.im',
        title: 'Legacy Caption',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 9),
        deltaChatId: 9,
        emailAddress: 'legacy-caption@example.com',
      );
      await db.createChat(contact);
      await db.saveFileMetadata(
        const FileMetadataData(id: 'invoice-file', filename: 'invoice.png'),
      );
      await db.saveFileMetadata(
        const FileMetadataData(id: 'receipt-file', filename: 'receipt.png'),
      );
      await db.saveMessage(
        Message(
          stanzaID: 'legacy-caption-message',
          senderJid: contact.jid,
          chatJid: contact.jid,
          timestamp: DateTime.utc(2024, 1, 9, 9),
          body: '\u{1F4CE} invoice.png (Unknown size)',
          encryptionProtocol: EncryptionProtocol.none,
          fileMetadataID: 'invoice-file',
          pseudoMessageData: const {'emailAttachmentCaption': true},
          deltaChatId: contact.deltaChatId,
          deltaMsgId: 90,
        ),
      );
      await db.saveMessage(
        Message(
          stanzaID: 'legacy-unmarked-caption-message',
          senderJid: contact.jid,
          chatJid: contact.jid,
          timestamp: DateTime.utc(2024, 1, 9, 10),
          body: '\u{1F4CE} receipt.png (Unknown size)',
          encryptionProtocol: EncryptionProtocol.none,
          fileMetadataID: 'receipt-file',
          deltaChatId: contact.deltaChatId,
          deltaMsgId: 91,
        ),
      );

      await db.repairGeneratedEmailAttachmentCaptionBodies();

      final repaired = await db.getMessageByStanzaID('legacy-caption-message');
      final repairedUnmarked = await db.getMessageByStanzaID(
        'legacy-unmarked-caption-message',
      );
      final repairedChat = await db.getChat(contact.jid);
      expect(repaired?.body, isNull);
      expect(repaired?.pseudoMessageData, isNull);
      expect(repairedUnmarked?.body, isNull);
      expect(repairedChat?.lastMessage, 'Attachment: receipt.png');
    },
  );

  test(
    'repairGeneratedEmailAttachmentCaptionBodies preserves real text bodies',
    () async {
      final contact = Chat(
        jid: 'real-caption@axi.im',
        title: 'Real Caption',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 10),
        deltaChatId: 10,
        emailAddress: 'real-caption@example.com',
      );
      await db.createChat(contact);
      await db.saveFileMetadata(
        const FileMetadataData(id: 'real-file', filename: 'invoice.png'),
      );
      await db.saveMessage(
        Message(
          stanzaID: 'real-caption-message',
          senderJid: contact.jid,
          chatJid: contact.jid,
          timestamp: DateTime.utc(2024, 1, 10, 9),
          body: 'Here is the signed invoice.',
          encryptionProtocol: EncryptionProtocol.none,
          fileMetadataID: 'real-file',
          pseudoMessageData: const {'emailAttachmentCaption': true},
          deltaChatId: contact.deltaChatId,
          deltaMsgId: 100,
        ),
      );
      await db.saveMessage(
        Message(
          stanzaID: 'real-paperclip-caption-message',
          senderJid: contact.jid,
          chatJid: contact.jid,
          timestamp: DateTime.utc(2024, 1, 10, 10),
          body: '\u{1F4CE} invoice.png (signed)',
          encryptionProtocol: EncryptionProtocol.none,
          fileMetadataID: 'real-file',
          deltaChatId: contact.deltaChatId,
          deltaMsgId: 101,
        ),
      );

      await db.repairGeneratedEmailAttachmentCaptionBodies();

      final repaired = await db.getMessageByStanzaID('real-caption-message');
      final repairedPaperclip = await db.getMessageByStanzaID(
        'real-paperclip-caption-message',
      );
      final repairedChat = await db.getChat(contact.jid);
      expect(repaired?.body, 'Here is the signed invoice.');
      expect(repaired?.pseudoMessageData, isNull);
      expect(repairedPaperclip?.body, '\u{1F4CE} invoice.png (signed)');
      expect(repairedChat?.lastMessage, '\u{1F4CE} invoice.png (signed)');
    },
  );

  test(
    'calendar task share without body uses task title as last message',
    () async {
      final contact = Chat(
        jid: 'task-share@axi.im',
        title: 'Task Share',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 8),
      );
      final task = CalendarTask.create(title: 'Review launch plan');
      await db.createChat(contact);

      await db.saveMessage(
        Message(
          stanzaID: 'task-share-message',
          senderJid: contact.jid,
          chatJid: contact.jid,
          timestamp: DateTime.utc(2024, 1, 8, 9),
          body: '',
          encryptionProtocol: EncryptionProtocol.none,
          pseudoMessageType: PseudoMessageType.calendarTaskIcs,
          pseudoMessageData: CalendarTaskIcsMessage(task: task).toJson(),
        ),
      );

      final updatedChat = await db.getChat(contact.jid);
      expect(updatedChat?.lastMessage, 'Review launch plan');
    },
  );

  test('countChatMessages can exclude pseudo messages', () async {
    final contact = Chat(
      jid: 'dc-1@delta.chat',
      title: 'Bob',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime(2024, 1, 1),
      deltaChatId: 1,
      emailAddress: 'bob@example.com',
    );
    await db.createChat(contact);

    final realMessage = Message(
      stanzaID: 'real-1',
      senderJid: contact.jid,
      chatJid: contact.jid,
      timestamp: DateTime.utc(2024, 1, 1),
      body: 'hello',
      encryptionProtocol: EncryptionProtocol.none,
    );
    final pseudoMessage = Message(
      stanzaID: 'pseudo-1',
      senderJid: contact.jid,
      chatJid: contact.jid,
      timestamp: DateTime.utc(2024, 1, 2),
      pseudoMessageType: PseudoMessageType.newDevice,
      pseudoMessageData: const {'device': 'new'},
    );

    await db.saveMessage(realMessage);
    await db.saveMessage(pseudoMessage);

    final totalCount = await db.countChatMessages(contact.jid);
    final archivedCount = await db.countChatMessages(
      contact.jid,
      includePseudoMessages: false,
    );

    expect(totalCount, 2);
    expect(archivedCount, 1);
  });

  test('chat summary follows the newest saved message', () async {
    final contact = Chat(
      jid: 'summary-test@delta.chat',
      title: 'Summary Test',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2024, 1, 1),
    );
    await db.createChat(contact);

    final firstMessage = Message(
      stanzaID: 'summary-1',
      senderJid: contact.jid,
      chatJid: contact.jid,
      timestamp: DateTime.utc(2024, 1, 1, 12),
      body: 'first message',
      encryptionProtocol: EncryptionProtocol.none,
    );
    final secondMessage = Message(
      stanzaID: 'summary-2',
      senderJid: contact.jid,
      chatJid: contact.jid,
      timestamp: DateTime.utc(2024, 1, 1, 12, 1),
      body: 'second message',
      encryptionProtocol: EncryptionProtocol.none,
    );

    await db.saveMessage(firstMessage);
    await db.saveMessage(secondMessage);

    final updatedChat = await db.getChat(contact.jid);

    expect(updatedChat?.lastMessage, 'second message');
    expect(updatedChat?.lastChangeTimestamp, secondMessage.timestamp);
  });

  test(
    'roster-created placeholder chats do not pin the first imported history message',
    () async {
      const jid = 'roster-history@example.com';
      await db.saveRosterItems([RosterItem.fromJid(jid)]);

      final seededChat = await db.getChat(jid);
      expect(
        seededChat?.lastChangeTimestamp,
        DateTime.fromMillisecondsSinceEpoch(0),
      );

      final oldestMessage = Message(
        stanzaID: 'history-1',
        senderJid: jid,
        chatJid: jid,
        timestamp: DateTime.utc(2024, 1, 1, 9),
        body: 'oldest imported message',
        encryptionProtocol: EncryptionProtocol.none,
      );
      final middleMessage = Message(
        stanzaID: 'history-2',
        senderJid: jid,
        chatJid: jid,
        timestamp: DateTime.utc(2024, 1, 1, 10),
        body: 'middle imported message',
        encryptionProtocol: EncryptionProtocol.none,
      );
      final newestMessage = Message(
        stanzaID: 'history-3',
        senderJid: jid,
        chatJid: jid,
        timestamp: DateTime.utc(2024, 1, 1, 11),
        body: 'newest imported message',
        encryptionProtocol: EncryptionProtocol.none,
      );

      await db.saveMessage(oldestMessage);
      await db.saveMessage(middleMessage);
      await db.saveMessage(newestMessage);

      final updatedChat = await db.getChat(jid);
      expect(updatedChat?.lastMessage, 'newest imported message');
      expect(updatedChat?.lastChangeTimestamp, newestMessage.timestamp);
    },
  );

  test(
    'imported history repairs subtitle when chat timestamp is already newer',
    () async {
      const jid = 'snapshot-history@example.com';
      final externalTimestamp = DateTime.utc(2024, 1, 1, 12);
      await db.createChat(
        Chat(
          jid: jid,
          title: 'Snapshot History',
          type: ChatType.chat,
          lastChangeTimestamp: externalTimestamp,
        ),
      );

      final oldestMessage = Message(
        stanzaID: 'snapshot-history-1',
        senderJid: jid,
        chatJid: jid,
        timestamp: DateTime.utc(2024, 1, 1, 9),
        body: 'oldest imported message',
        encryptionProtocol: EncryptionProtocol.none,
      );
      final middleMessage = Message(
        stanzaID: 'snapshot-history-2',
        senderJid: jid,
        chatJid: jid,
        timestamp: DateTime.utc(2024, 1, 1, 10),
        body: 'middle imported message',
        encryptionProtocol: EncryptionProtocol.none,
      );
      final newestMessage = Message(
        stanzaID: 'snapshot-history-3',
        senderJid: jid,
        chatJid: jid,
        timestamp: DateTime.utc(2024, 1, 1, 11),
        body: 'newest imported message',
        encryptionProtocol: EncryptionProtocol.none,
      );

      await db.saveMessage(oldestMessage);
      await db.saveMessage(middleMessage);
      await db.saveMessage(newestMessage);

      final updatedChat = await db.getChat(jid);
      expect(updatedChat?.lastMessage, 'newest imported message');
      expect(updatedChat?.lastChangeTimestamp, externalTimestamp);
    },
  );

  test(
    'mixed chats order newer email messages after older XMPP messages',
    () async {
      final contact = Chat(
        jid: 'mixed-order@axi.im',
        title: 'Mixed Order',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.xmpp,
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: 7,
        emailAddress: 'mixed-order@example.com',
        emailFromAddress: 'me@example.com',
      );
      await db.createChat(contact);

      final emailTimestamp = DateTime.utc(2024, 1, 2, 12, 10);
      final xmppMessages = [
        for (final age in [
          const Duration(seconds: 10),
          const Duration(minutes: 1),
          const Duration(minutes: 2),
          const Duration(minutes: 5),
          const Duration(minutes: 10),
        ])
          Message(
            stanzaID: 'xmpp-old-${age.inSeconds}',
            senderJid: contact.jid,
            chatJid: contact.jid,
            timestamp: emailTimestamp.subtract(age),
            body: 'older xmpp ${age.inSeconds}',
            encryptionProtocol: EncryptionProtocol.none,
          ),
      ];
      final emailMessage = Message(
        stanzaID: 'dc-msg-77',
        senderJid: 'mixed-order@example.com',
        chatJid: contact.jid,
        timestamp: emailTimestamp,
        body: 'newer email',
        encryptionProtocol: EncryptionProtocol.none,
        received: true,
        deltaChatId: contact.deltaChatId,
        deltaMsgId: 77,
      );

      for (final message in xmppMessages.reversed) {
        await db.saveMessage(message);
      }
      await db.saveMessage(emailMessage);

      final messages = await db.getChatMessages(contact.jid, start: 0, end: 10);
      final updatedChat = await db.getChat(contact.jid);

      expect(messages.map((message) => message.stanzaID), [
        emailMessage.stanzaID,
        ...xmppMessages.map((message) => message.stanzaID),
      ]);
      expect(updatedChat?.lastMessage, 'newer email');
      expect(updatedChat?.lastChangeTimestamp, emailMessage.timestamp);
    },
  );

  test('same-timestamp email messages follow local insertion order', () async {
    final contact = Chat(
      jid: 'ordering-test@delta.chat',
      title: 'Ordering Test',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2024, 1, 1),
      deltaChatId: 1,
      emailAddress: 'ordering@example.com',
    );
    await db.createChat(contact);

    final sharedTimestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
    final oldestMessage = Message(
      stanzaID: 'dc-msg-12',
      senderJid: contact.jid,
      chatJid: contact.jid,
      timestamp: sharedTimestamp,
      body: 'oldest',
      encryptionProtocol: EncryptionProtocol.none,
      deltaChatId: contact.deltaChatId,
      deltaMsgId: 12,
    );
    final middleMessage = Message(
      stanzaID: 'dc-msg-300',
      senderJid: 'self@example.com',
      chatJid: contact.jid,
      timestamp: sharedTimestamp,
      body: 'middle',
      encryptionProtocol: EncryptionProtocol.none,
      deltaChatId: contact.deltaChatId,
      deltaMsgId: 300,
    );
    final newestMessage = Message(
      stanzaID: 'dc-msg-40',
      senderJid: contact.jid,
      chatJid: contact.jid,
      timestamp: sharedTimestamp,
      body: 'newest',
      encryptionProtocol: EncryptionProtocol.none,
      deltaChatId: contact.deltaChatId,
      deltaMsgId: 40,
    );

    await db.saveMessage(oldestMessage);
    await db.saveMessage(middleMessage);
    await db.saveMessage(newestMessage);

    final messages = await db.getChatMessages(contact.jid, start: 0, end: 10);

    expect(messages.map((message) => message.stanzaID), [
      newestMessage.stanzaID,
      middleMessage.stanzaID,
      oldestMessage.stanzaID,
    ]);
  });

  test(
    'same-timestamp email paging and counts ignore delta message ids',
    () async {
      final contact = Chat(
        jid: 'paging-test@delta.chat',
        title: 'Paging Test',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        deltaChatId: 1,
        emailAddress: 'paging@example.com',
      );
      await db.createChat(contact);

      final sharedTimestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
      final oldestMessage = Message(
        stanzaID: 'dc-msg-12',
        senderJid: contact.jid,
        chatJid: contact.jid,
        timestamp: sharedTimestamp,
        body: 'oldest',
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: contact.deltaChatId,
        deltaMsgId: 12,
      );
      final middleMessage = Message(
        stanzaID: 'dc-msg-300',
        senderJid: 'self@example.com',
        chatJid: contact.jid,
        timestamp: sharedTimestamp,
        body: 'middle',
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: contact.deltaChatId,
        deltaMsgId: 300,
      );
      final newestMessage = Message(
        stanzaID: 'dc-msg-40',
        senderJid: contact.jid,
        chatJid: contact.jid,
        timestamp: sharedTimestamp,
        body: 'newest',
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: contact.deltaChatId,
        deltaMsgId: 40,
      );

      await db.saveMessage(oldestMessage);
      await db.saveMessage(middleMessage);
      await db.saveMessage(newestMessage);

      final olderMessages = await db.getChatMessagesBefore(
        contact.jid,
        beforeTimestamp: sharedTimestamp,
        beforeStanzaId: middleMessage.stanzaID,
        beforeDeltaMsgId: middleMessage.deltaMsgId,
        limit: 10,
      );
      final messagesThroughMiddle = await db.countChatMessagesThrough(
        contact.jid,
        throughTimestamp: sharedTimestamp,
        throughStanzaId: middleMessage.stanzaID,
        throughDeltaMsgId: middleMessage.deltaMsgId,
      );

      expect(olderMessages.map((message) => message.stanzaID), [
        oldestMessage.stanzaID,
      ]);
      expect(messagesThroughMiddle, 2);
    },
  );

  test(
    'conversation index chat meta updates preserve unread and summary fields',
    () async {
      final contact = Chat(
        jid: 'conversation-index@example.com',
        title: 'Conversation Index',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1, 9),
      );
      await db.createChat(contact);

      await db.saveMessage(
        Message(
          stanzaID: 'conversation-index-1',
          senderJid: contact.jid,
          chatJid: contact.jid,
          timestamp: DateTime.utc(2024, 1, 1, 10),
          body: 'Unread preserved',
          encryptionProtocol: EncryptionProtocol.none,
        ),
        selfJid: 'self@example.com',
      );

      await db.updateConversationIndexChatMeta(
        jid: contact.jid,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1, 11),
        muted: true,
        favorited: true,
        archived: true,
        contactJid: contact.jid,
      );

      final chat = await db.getChat(contact.jid);
      expect(chat?.unreadCount, 1);
      expect(chat?.lastMessage, 'Unread preserved');
      expect(chat?.muted, isTrue);
      expect(chat?.favorited, isTrue);
      expect(chat?.archived, isTrue);
      expect(chat?.lastChangeTimestamp, DateTime.utc(2024, 1, 1, 11));
    },
  );

  test(
    'hidden self sync messages keep the self chat titled Saved Messages without surfacing activity',
    () async {
      const selfJid = 'me@example.com';
      final syncEnvelope = jsonEncode({
        'calendar_sync': CalendarSyncMessage.request().toJson(),
      });
      final timestamp = DateTime.utc(2024, 1, 1, 10);

      await db.saveMessage(
        Message(
          stanzaID: 'self-sync-1',
          senderJid: selfJid,
          chatJid: selfJid,
          timestamp: timestamp,
          body: syncEnvelope,
          encryptionProtocol: EncryptionProtocol.none,
        ),
        selfJid: selfJid,
      );

      final chat = await db.getChat(selfJid);
      expect(chat?.title, 'Saved Messages');
      expect(chat?.lastMessage, isNull);
      expect(chat?.lastChangeTimestamp, DateTime.fromMillisecondsSinceEpoch(0));
    },
  );

  test(
    'hidden multi-device sync placeholders do not consume timeline or count windows',
    () async {
      const selfJid = 'me@example.com';
      final selfChat = Chat(
        jid: selfJid,
        title: 'Saved Messages',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1, 9),
        transport: MessageTransport.email,
        emailAddress: selfJid,
      );
      await db.createChat(selfChat);

      await db.saveMessage(
        Message(
          stanzaID: 'visible-self-message',
          senderJid: selfJid,
          chatJid: selfJid,
          timestamp: DateTime.utc(2024, 1, 1, 10),
          body: 'Keep me visible',
          encryptionProtocol: EncryptionProtocol.none,
        ),
        selfJid: selfJid,
      );

      await db.saveMessage(
        Message(
          stanzaID: 'hidden-sync-message',
          senderJid: selfJid,
          chatJid: selfJid,
          timestamp: DateTime.utc(2024, 1, 1, 11),
          subject: 'Multi Device Synchronization',
          body:
              'This message is used to synchronize data between your devices. '
              'Please ignore it.',
          encryptionProtocol: EncryptionProtocol.none,
        ),
        selfJid: selfJid,
      );

      final latestVisible = await db.getChatMessages(
        selfJid,
        start: 0,
        end: 1,
        filter: MessageTimelineFilter.allWithContact,
      );
      final totalVisible = await db.countChatMessages(
        selfJid,
        filter: MessageTimelineFilter.allWithContact,
      );
      final throughVisible = await db.countChatMessagesThrough(
        selfJid,
        throughTimestamp: DateTime.utc(2024, 1, 1, 10),
        throughStanzaId: 'visible-self-message',
        filter: MessageTimelineFilter.allWithContact,
      );

      expect(latestVisible.map((message) => message.stanzaID), [
        'visible-self-message',
      ]);
      expect(totalVisible, 1);
      expect(throughVisible, 1);
    },
  );
}
