import 'package:axichat/src/chat/models/chat_timeline.dart';
import 'package:axichat/src/chat/models/chat_timeline_projection.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/models/chat_models.dart' as chat_models;
import 'package:axichat/src/xmpp/muc/occupant.dart';
import 'package:axichat/src/xmpp/muc/room_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stale unacked send-again projection requires a cutoff', () {
    final chat = chat_models.Chat(
      jid: 'peer@axi.im',
      title: 'Peer',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2024, 1, 1),
    );
    final message = Message(
      stanzaID: 'stale-unacked',
      senderJid: 'self@axi.im',
      chatJid: chat.jid,
      body: 'Pending',
      timestamp: DateTime.utc(2024, 1, 1, 9),
    );

    List<ChatTimelineItem> project(DateTime? staleUnackedCutoff) {
      return buildMainChatTimelineItems(
        messages: [message],
        loadingMessages: false,
        unreadBoundaryStanzaId: null,
        emptyStateCreatedAt: DateTime.utc(2024, 1, 1),
        unreadDividerItemId: 'unread-divider',
        unreadDividerLabel: 'Unread',
        emptyStateItemId: 'empty-state',
        emptyStateLabel: 'Empty',
        isGroupChat: false,
        isEmailChat: false,
        staleUnackedCutoff: staleUnackedCutoff,
        profileJid: 'self@axi.im',
        resolvedEmailSelfJid: null,
        currentUserId: 'self@axi.im',
        selfUserId: 'self@axi.im',
        selfDisplayName: 'Self',
        selfAvatarPath: null,
        myOccupantJid: null,
        selfNick: 'self',
        roomState: null,
        roomMemberSections: const [],
        chat: chat,
        messageById: const {},
        shareContexts: const {},
        shareReplies: const {},
        emailFullHtmlByDeltaId: const {},
        revokedInviteTokens: const {},
        inviteRoomFallbackLabel: 'Room',
        inviteBodyLabel: 'Invite',
        inviteRevokedBodyLabel: 'Invite revoked',
        unknownAuthorLabel: 'Unknown',
        inviteActionLabel: (roomDisplayName) => 'Open $roomDisplayName',
        supportsMarkers: false,
        supportsReceipts: false,
        attachmentsForMessage: (_) => const <String>[],
        reactionPreviewsForMessage: (_) => const <ReactionPreview>[],
        participantsForBanner: (_, _, _) => const <chat_models.Chat>[],
        avatarPathForBareJid: (_) => null,
        ownerJidForShare: (_) => null,
        errorLabel: (_) => 'Error',
        errorLabelWithBody: (_, body) => body,
      );
    }

    final loadingMessage = project(
      null,
    ).whereType<ChatTimelineMessageItem>().single;
    final loadedMessage = project(
      DateTime.utc(2024, 1, 1, 10),
    ).whereType<ChatTimelineMessageItem>().single;

    expect(loadingMessage.canSendAgain, isFalse);
    expect(loadedMessage.canSendAgain, isTrue);
  });

  test(
    'group messages fall back to the sender nick when room state is absent',
    () {
      final chat = chat_models.Chat(
        jid: 'room@conference.axi.im',
        title: 'Room title',
        type: ChatType.groupChat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
      );
      final message = Message(
        stanzaID: 'group-message-1',
        senderJid: 'room@conference.axi.im/alice',
        chatJid: chat.jid,
        body: 'Hello from Alice',
        timestamp: DateTime.utc(2024, 1, 1, 10),
      );

      final items = buildMainChatTimelineItems(
        messages: [message],
        loadingMessages: false,
        unreadBoundaryStanzaId: null,
        emptyStateCreatedAt: DateTime.utc(2024, 1, 1),
        unreadDividerItemId: 'unread-divider',
        unreadDividerLabel: 'Unread',
        emptyStateItemId: 'empty-state',
        emptyStateLabel: 'Empty',
        isGroupChat: true,
        isEmailChat: false,
        profileJid: 'self@axi.im',
        resolvedEmailSelfJid: null,
        currentUserId: 'self-user',
        selfUserId: 'self-user',
        selfDisplayName: 'Self',
        selfAvatarPath: null,
        myOccupantJid: null,
        selfNick: 'self',
        roomState: null,
        roomMemberSections: const [],
        chat: chat,
        messageById: const {},
        shareContexts: const {},
        shareReplies: const {},
        emailFullHtmlByDeltaId: const {},
        revokedInviteTokens: const {},
        inviteRoomFallbackLabel: 'Room',
        inviteBodyLabel: 'Invite',
        inviteRevokedBodyLabel: 'Invite revoked',
        unknownAuthorLabel: 'Unknown',
        inviteActionLabel: (roomDisplayName) => 'Open $roomDisplayName',
        supportsMarkers: false,
        supportsReceipts: false,
        attachmentsForMessage: (_) => const <String>[],
        reactionPreviewsForMessage: (_) => const <ReactionPreview>[],
        participantsForBanner: (_, _, _) => const <chat_models.Chat>[],
        avatarPathForBareJid: (_) => null,
        ownerJidForShare: (_) => null,
        errorLabel: (_) => 'Error',
        errorLabelWithBody: (_, body) => body,
      );

      final timelineMessage = items.whereType<ChatTimelineMessageItem>().single;
      expect(timelineMessage.authorDisplayName, equals('alice'));
    },
  );

  test('group self direction uses stored real JID after nick changes', () {
    const roomJid = 'room@conference.axi.im';
    const selfJid = 'self@axi.im';
    final roomState = RoomState(
      roomJid: roomJid,
      occupants: {
        '$roomJid/new': Occupant(
          occupantId: '$roomJid/new',
          nick: 'new',
          realJid: selfJid,
        ),
      },
      myOccupantJid: '$roomJid/new',
    );
    final oldSelfMessage = Message(
      stanzaID: 'old-self-message',
      senderJid: '$roomJid/old',
      senderRealJid: selfJid,
      chatJid: roomJid,
      body: 'sent before nick change',
      timestamp: DateTime.utc(2024, 1, 1, 10),
    );
    final legacyOldNickMessage = Message(
      stanzaID: 'legacy-old-nick-message',
      senderJid: '$roomJid/old',
      chatJid: roomJid,
      body: 'legacy row without real jid',
      timestamp: DateTime.utc(2024, 1, 1, 10),
    );

    expect(
      isMucSelfMessage(
        message: oldSelfMessage,
        roomState: roomState,
        selfJid: selfJid,
      ),
      isTrue,
    );
    expect(
      isMucSelfMessage(
        message: legacyOldNickMessage,
        roomState: roomState,
        selfJid: selfJid,
      ),
      isFalse,
    );
  });

  test('group claimed-sender validation requires stored real JID', () {
    const roomJid = 'room@conference.axi.im';
    final anonymousMessage = Message(
      stanzaID: 'anonymous-message',
      senderJid: '$roomJid/alice',
      chatJid: roomJid,
      body: 'anonymous',
      timestamp: DateTime.utc(2024, 1, 1, 10),
    );
    final identifiedMessage = anonymousMessage.copyWith(
      stanzaID: 'identified-message',
      senderRealJid: 'alice@axi.im',
    );

    expect(anonymousMessage.senderMatchesClaimedJid('alice@axi.im'), isFalse);
    expect(identifiedMessage.senderMatchesClaimedJid('alice@axi.im'), isTrue);
  });

  test(
    'email forwards extract the original author from common forwarded envelopes',
    () {
      final chat = chat_models.Chat(
        jid: 'forwarder@example.com',
        title: 'Forwarder',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        emailAddress: 'forwarder@example.com',
        emailFromAddress: 'self@example.com',
      );
      final message = Message(
        stanzaID: 'forwarded-email-1',
        senderJid: 'forwarder@example.com',
        chatJid: chat.jid,
        subject: 'Fwd: Quarterly plan',
        body:
            '---------- Forwarded message ---------\n'
            'From: Original Person <original@example.com>\n'
            'Subject: Quarterly plan\n'
            '\n'
            'Forwarded body',
        timestamp: DateTime.utc(2024, 1, 1, 10),
      );

      final items = buildMainChatTimelineItems(
        messages: [message],
        loadingMessages: false,
        unreadBoundaryStanzaId: null,
        emptyStateCreatedAt: DateTime.utc(2024, 1, 1),
        unreadDividerItemId: 'unread-divider',
        unreadDividerLabel: 'Unread',
        emptyStateItemId: 'empty-state',
        emptyStateLabel: 'Empty',
        isGroupChat: false,
        isEmailChat: true,
        profileJid: 'self@example.com',
        resolvedEmailSelfJid: 'self@example.com',
        currentUserId: 'self@example.com',
        selfUserId: 'self@example.com',
        selfDisplayName: 'Self',
        selfAvatarPath: null,
        myOccupantJid: null,
        selfNick: 'self',
        roomState: null,
        roomMemberSections: const [],
        chat: chat,
        messageById: const {},
        shareContexts: const {},
        shareReplies: const {},
        emailFullHtmlByDeltaId: const {},
        revokedInviteTokens: const {},
        inviteRoomFallbackLabel: 'Room',
        inviteBodyLabel: 'Invite',
        inviteRevokedBodyLabel: 'Invite revoked',
        unknownAuthorLabel: 'Unknown',
        inviteActionLabel: (roomDisplayName) => 'Open $roomDisplayName',
        supportsMarkers: false,
        supportsReceipts: false,
        attachmentsForMessage: (_) => const <String>[],
        reactionPreviewsForMessage: (_) => const <ReactionPreview>[],
        participantsForBanner: (_, _, _) => const <chat_models.Chat>[],
        avatarPathForBareJid: (_) => null,
        ownerJidForShare: (_) => null,
        errorLabel: (_) => 'Error',
        errorLabelWithBody: (_, body) => body,
      );

      final timelineMessage = items.whereType<ChatTimelineMessageItem>().single;
      expect(timelineMessage.isForwarded, isTrue);
      expect(
        timelineMessage.forwardedSubjectSenderLabel,
        equals('original@example.com'),
      );
    },
  );

  test(
    'email forwards extract the original author from full html when plain text loses it',
    () {
      final chat = chat_models.Chat(
        jid: 'forwarder@example.com',
        title: 'Forwarder',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        emailAddress: 'forwarder@example.com',
        emailFromAddress: 'self@example.com',
      );
      final message = Message(
        stanzaID: 'forwarded-email-html-1',
        senderJid: 'forwarder@example.com',
        chatJid: chat.jid,
        body: 'Forwarded body',
        subject: 'Fwd: Quarterly plan',
        htmlBody:
            '<div>---------- Forwarded message ---------</div>'
            '<div>From: Original Person &lt;original@example.com&gt;</div>'
            '<div>Subject: Quarterly plan</div>'
            '<div><br></div>'
            '<div>Forwarded body</div>',
        timestamp: DateTime.utc(2024, 1, 1, 10),
      );

      final items = buildMainChatTimelineItems(
        messages: [message],
        loadingMessages: false,
        unreadBoundaryStanzaId: null,
        emptyStateCreatedAt: DateTime.utc(2024, 1, 1),
        unreadDividerItemId: 'unread-divider',
        unreadDividerLabel: 'Unread',
        emptyStateItemId: 'empty-state',
        emptyStateLabel: 'Empty',
        isGroupChat: false,
        isEmailChat: true,
        profileJid: 'self@example.com',
        resolvedEmailSelfJid: 'self@example.com',
        currentUserId: 'self@example.com',
        selfUserId: 'self@example.com',
        selfDisplayName: 'Self',
        selfAvatarPath: null,
        myOccupantJid: null,
        selfNick: 'self',
        roomState: null,
        roomMemberSections: const [],
        chat: chat,
        messageById: const {},
        shareContexts: const {},
        shareReplies: const {},
        emailFullHtmlByDeltaId: const {},
        revokedInviteTokens: const {},
        inviteRoomFallbackLabel: 'Room',
        inviteBodyLabel: 'Invite',
        inviteRevokedBodyLabel: 'Invite revoked',
        unknownAuthorLabel: 'Unknown',
        inviteActionLabel: (roomDisplayName) => 'Open $roomDisplayName',
        supportsMarkers: false,
        supportsReceipts: false,
        attachmentsForMessage: (_) => const <String>[],
        reactionPreviewsForMessage: (_) => const <ReactionPreview>[],
        participantsForBanner: (_, _, _) => const <chat_models.Chat>[],
        avatarPathForBareJid: (_) => null,
        ownerJidForShare: (_) => null,
        errorLabel: (_) => 'Error',
        errorLabelWithBody: (_, body) => body,
      );

      final timelineMessage = items.whereType<ChatTimelineMessageItem>().single;
      expect(timelineMessage.isForwarded, isTrue);
      expect(
        timelineMessage.forwardedSubjectSenderLabel,
        equals('original@example.com'),
      );
    },
  );

  test(
    'email forwards extract the original author from top-level header blocks',
    () {
      final chat = chat_models.Chat(
        jid: 'forwarder@example.com',
        title: 'Forwarder',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        emailAddress: 'forwarder@example.com',
        emailFromAddress: 'self@example.com',
      );
      final message = Message(
        stanzaID: 'forwarded-email-inline-1',
        senderJid: 'forwarder@example.com',
        chatJid: chat.jid,
        subject: 'Fwd: Quarterly plan',
        body:
            'From: Original=20Person=20=3Coriginal@example.com=3E\n'
            'Date: Tue, 19 Mar 2026 10:00:00 +0000\n'
            'Subject: Quarterly plan\n'
            'To: Forwarder <forwarder@example.com>\n'
            '\n'
            'Forwarded body',
        timestamp: DateTime.utc(2024, 1, 1, 10),
      );

      final items = buildMainChatTimelineItems(
        messages: [message],
        loadingMessages: false,
        unreadBoundaryStanzaId: null,
        emptyStateCreatedAt: DateTime.utc(2024, 1, 1),
        unreadDividerItemId: 'unread-divider',
        unreadDividerLabel: 'Unread',
        emptyStateItemId: 'empty-state',
        emptyStateLabel: 'Empty',
        isGroupChat: false,
        isEmailChat: true,
        profileJid: 'self@example.com',
        resolvedEmailSelfJid: 'self@example.com',
        currentUserId: 'self@example.com',
        selfUserId: 'self@example.com',
        selfDisplayName: 'Self',
        selfAvatarPath: null,
        myOccupantJid: null,
        selfNick: 'self',
        roomState: null,
        roomMemberSections: const [],
        chat: chat,
        messageById: const {},
        shareContexts: const {},
        shareReplies: const {},
        emailFullHtmlByDeltaId: const {},
        revokedInviteTokens: const {},
        inviteRoomFallbackLabel: 'Room',
        inviteBodyLabel: 'Invite',
        inviteRevokedBodyLabel: 'Invite revoked',
        unknownAuthorLabel: 'Unknown',
        inviteActionLabel: (roomDisplayName) => 'Open $roomDisplayName',
        supportsMarkers: false,
        supportsReceipts: false,
        attachmentsForMessage: (_) => const <String>[],
        reactionPreviewsForMessage: (_) => const <ReactionPreview>[],
        participantsForBanner: (_, _, _) => const <chat_models.Chat>[],
        avatarPathForBareJid: (_) => null,
        ownerJidForShare: (_) => null,
        errorLabel: (_) => 'Error',
        errorLabelWithBody: (_, body) => body,
      );

      final timelineMessage = items.whereType<ChatTimelineMessageItem>().single;
      expect(timelineMessage.isForwarded, isTrue);
      expect(
        timelineMessage.forwardedSubjectSenderLabel,
        equals('original@example.com'),
      );
    },
  );

  test('email forwards extract the original author after MIME preambles', () {
    final chat = chat_models.Chat(
      jid: 'forwarder@example.com',
      title: 'Forwarder',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2024, 1, 1),
      emailAddress: 'forwarder@example.com',
      emailFromAddress: 'self@example.com',
    );
    final message = Message(
      stanzaID: 'forwarded-email-mime-preamble-1',
      senderJid: 'forwarder@example.com',
      chatJid: chat.jid,
      subject: 'Fwd: Quarterly plan',
      body:
          'Content-Type: text/plain; charset="utf-8"\n'
          'Content-Transfer-Encoding: quoted-printable\n'
          '\n'
          'From: Original=20Person=20=3Coriginal@example.com=3E\n'
          'Date: Tue, 19 Mar 2026 10:00:00 +0000\n'
          'Subject: Quarterly plan\n'
          'To: Forwarder <forwarder@example.com>\n'
          '\n'
          'Forwarded body',
      timestamp: DateTime.utc(2024, 1, 1, 10),
    );

    final items = buildMainChatTimelineItems(
      messages: [message],
      loadingMessages: false,
      unreadBoundaryStanzaId: null,
      emptyStateCreatedAt: DateTime.utc(2024, 1, 1),
      unreadDividerItemId: 'unread-divider',
      unreadDividerLabel: 'Unread',
      emptyStateItemId: 'empty-state',
      emptyStateLabel: 'Empty',
      isGroupChat: false,
      isEmailChat: true,
      profileJid: 'self@example.com',
      resolvedEmailSelfJid: 'self@example.com',
      currentUserId: 'self@example.com',
      selfUserId: 'self@example.com',
      selfDisplayName: 'Self',
      selfAvatarPath: null,
      myOccupantJid: null,
      selfNick: 'self',
      roomState: null,
      roomMemberSections: const [],
      chat: chat,
      messageById: const {},
      shareContexts: const {},
      shareReplies: const {},
      emailFullHtmlByDeltaId: const {},
      revokedInviteTokens: const {},
      inviteRoomFallbackLabel: 'Room',
      inviteBodyLabel: 'Invite',
      inviteRevokedBodyLabel: 'Invite revoked',
      unknownAuthorLabel: 'Unknown',
      inviteActionLabel: (roomDisplayName) => 'Open $roomDisplayName',
      supportsMarkers: false,
      supportsReceipts: false,
      attachmentsForMessage: (_) => const <String>[],
      reactionPreviewsForMessage: (_) => const <ReactionPreview>[],
      participantsForBanner: (_, _, _) => const <chat_models.Chat>[],
      avatarPathForBareJid: (_) => null,
      ownerJidForShare: (_) => null,
      errorLabel: (_) => 'Error',
      errorLabelWithBody: (_, body) => body,
    );

    final timelineMessage = items.whereType<ChatTimelineMessageItem>().single;
    expect(timelineMessage.isForwarded, isTrue);
    expect(
      timelineMessage.forwardedSubjectSenderLabel,
      equals('original@example.com'),
    );
  });
}
