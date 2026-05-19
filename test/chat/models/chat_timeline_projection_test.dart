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
        acceptedInviteTokens: const {},
        inviteRoomFallbackLabel: 'Room',
        inviteBodyLabel: 'Invite',
        inviteRevokedBodyLabel: 'Invite revoked',
        inviteAcceptedBodyLabel: 'Invite accepted',
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
        acceptedInviteTokens: const {},
        inviteRoomFallbackLabel: 'Room',
        inviteBodyLabel: 'Invite',
        inviteRevokedBodyLabel: 'Invite revoked',
        inviteAcceptedBodyLabel: 'Invite accepted',
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

  test('group member avatars resolve live from real bare JID', () {
    const roomJid = 'room@conference.axi.im';
    const realJid = 'alice@axi.im';
    final occupant = Occupant(
      occupantId: 'opaque-alice',
      nick: 'Alice',
      realJid: realJid,
      affiliation: OccupantAffiliation.member,
      role: OccupantRole.participant,
      isPresent: false,
    );
    final roomState = RoomState(
      roomJid: roomJid,
      occupants: {'opaque-alice': occupant},
    );
    final message = Message(
      stanzaID: 'restored-member-message',
      senderJid: '$roomJid/Alice',
      occupantID: 'opaque-alice',
      chatJid: roomJid,
      body: 'hello',
      timestamp: DateTime.utc(2024, 1, 1, 10),
    );
    final chat = chat_models.Chat(
      jid: roomJid,
      title: 'Room',
      type: ChatType.groupChat,
      lastChangeTimestamp: DateTime.utc(2024, 1, 1),
    );
    final sections = [
      RoomMemberSection(
        kind: RoomMemberSectionKind.members,
        members: [RoomMemberEntry(occupant: occupant, actions: const [])],
      ),
    ];

    var avatarPath = '/avatars/alice-v1.enc';
    final first = resolveMainChatTimelineMessageAuthor(
      message: message,
      isGroupChat: true,
      profileJid: 'self@axi.im',
      resolvedEmailSelfJid: null,
      selfUserId: 'self-user',
      selfDisplayName: 'Self',
      selfAvatarPath: null,
      selfNick: 'self',
      roomState: roomState,
      roomMemberSections: sections,
      chat: chat,
      unknownLabel: 'Unknown',
      avatarPathForBareJid: (_) => avatarPath,
    );

    avatarPath = '/avatars/alice-v2.enc';
    final second = resolveMainChatTimelineMessageAuthor(
      message: message,
      isGroupChat: true,
      profileJid: 'self@axi.im',
      resolvedEmailSelfJid: null,
      selfUserId: 'self-user',
      selfDisplayName: 'Self',
      selfAvatarPath: null,
      selfNick: 'self',
      roomState: roomState,
      roomMemberSections: sections,
      chat: chat,
      unknownLabel: 'Unknown',
      avatarPathForBareJid: (_) => avatarPath,
    );

    expect(first.authorAvatarPath, '/avatars/alice-v1.enc');
    expect(second.authorAvatarPath, '/avatars/alice-v2.enc');
    expect(second.authorAvatarKey, realJid);
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
        acceptedInviteTokens: const {},
        inviteRoomFallbackLabel: 'Room',
        inviteBodyLabel: 'Invite',
        inviteRevokedBodyLabel: 'Invite revoked',
        inviteAcceptedBodyLabel: 'Invite accepted',
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
        acceptedInviteTokens: const {},
        inviteRoomFallbackLabel: 'Room',
        inviteBodyLabel: 'Invite',
        inviteRevokedBodyLabel: 'Invite revoked',
        inviteAcceptedBodyLabel: 'Invite accepted',
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
        acceptedInviteTokens: const {},
        inviteRoomFallbackLabel: 'Room',
        inviteBodyLabel: 'Invite',
        inviteRevokedBodyLabel: 'Invite revoked',
        inviteAcceptedBodyLabel: 'Invite accepted',
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
      acceptedInviteTokens: const {},
      inviteRoomFallbackLabel: 'Room',
      inviteBodyLabel: 'Invite',
      inviteRevokedBodyLabel: 'Invite revoked',
      inviteAcceptedBodyLabel: 'Invite accepted',
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

  test('accepted invite marker updates original invite without rendering', () {
    final chat = chat_models.Chat(
      jid: 'invitee@example.com',
      title: 'Invitee',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2024, 1, 1),
    );
    final invite = Message(
      stanzaID: 'invite-1',
      senderJid: 'self@example.com',
      chatJid: chat.jid,
      body: 'Invite',
      timestamp: DateTime.utc(2024, 1, 1, 10),
      pseudoMessageType: PseudoMessageType.mucInvite,
      pseudoMessageData: const {
        'roomJid': 'room@conference.example.com',
        'roomName': 'Room',
        'token': 'token-1',
        'inviter': 'self@example.com',
        'invitee': 'invitee@example.com',
      },
    );
    final accepted = Message(
      stanzaID: 'invite-accepted-1',
      senderJid: 'invitee@example.com',
      chatJid: chat.jid,
      body: 'Invite accepted',
      timestamp: DateTime.utc(2024, 1, 1, 11),
      pseudoMessageType: PseudoMessageType.mucInviteAccepted,
      pseudoMessageData: const {
        'roomJid': 'room@conference.example.com',
        'roomName': 'Room',
        'token': 'token-1',
        'inviter': 'self@example.com',
        'invitee': 'invitee@example.com',
        'accepted': true,
      },
    );

    final inviteLifecycle = resolveInviteLifecycleTokens([invite, accepted]);
    final items = buildMainChatTimelineItems(
      messages: [invite, accepted],
      loadingMessages: false,
      unreadBoundaryStanzaId: null,
      emptyStateCreatedAt: DateTime.utc(2024, 1, 1),
      unreadDividerItemId: 'unread-divider',
      unreadDividerLabel: 'Unread',
      emptyStateItemId: 'empty-state',
      emptyStateLabel: 'Empty',
      isGroupChat: false,
      isEmailChat: false,
      profileJid: 'self@example.com',
      resolvedEmailSelfJid: null,
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
      revokedInviteTokens: inviteLifecycle.revokedInviteTokens,
      acceptedInviteTokens: inviteLifecycle.acceptedInviteTokens,
      inviteRoomFallbackLabel: 'Room',
      inviteBodyLabel: 'Invite',
      inviteRevokedBodyLabel: 'Invite revoked',
      inviteAcceptedBodyLabel: 'Invite accepted',
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
    expect(timelineMessage.messageModel.stanzaID, equals('invite-1'));
    expect(timelineMessage.inviteAccepted, isTrue);
    expect(timelineMessage.inviteRevoked, isFalse);
    expect(timelineMessage.inviteLabel, equals('Invite accepted'));
    expect(timelineMessage.inviteJoinActionEnabled, isTrue);
    expect(timelineMessage.inviteRevokeActionEnabled, isTrue);
  });

  test('revoked invite marker disables join but keeps revoke available', () {
    final chat = chat_models.Chat(
      jid: 'invitee@example.com',
      title: 'Invitee',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2024, 1, 1),
    );
    final invite = Message(
      stanzaID: 'invite-revoked-source',
      senderJid: 'self@example.com',
      chatJid: chat.jid,
      body: 'Invite',
      timestamp: DateTime.utc(2024, 1, 1, 10),
      pseudoMessageType: PseudoMessageType.mucInvite,
      pseudoMessageData: const {
        'roomJid': 'room@conference.example.com',
        'roomName': 'Room',
        'token': 'token-revoked',
      },
    );
    final revoked = Message(
      stanzaID: 'invite-revoked-marker',
      senderJid: 'self@example.com',
      chatJid: chat.jid,
      body: 'Invite revoked',
      timestamp: DateTime.utc(2024, 1, 1, 11),
      pseudoMessageType: PseudoMessageType.mucInviteRevocation,
      pseudoMessageData: const {
        'roomJid': 'room@conference.example.com',
        'roomName': 'Room',
        'token': 'token-revoked',
        'revoked': true,
      },
    );

    final lifecycle = resolveInviteLifecycleTokens([invite, revoked]);
    final items = _projectMessages(
      chat: chat,
      messages: [invite, revoked],
      revokedInviteTokens: lifecycle.revokedInviteTokens,
      acceptedInviteTokens: lifecycle.acceptedInviteTokens,
    );

    final timelineMessage = items
        .whereType<ChatTimelineMessageItem>()
        .firstWhere((item) => item.messageModel.stanzaID == invite.stanzaID);
    expect(timelineMessage.inviteRevoked, isTrue);
    expect(timelineMessage.inviteJoinActionEnabled, isFalse);
    expect(timelineMessage.inviteRevokeActionEnabled, isTrue);
  });

  test('search-only accepted marker updates visible invite result', () {
    final chat = chat_models.Chat(
      jid: 'invitee@example.com',
      title: 'Invitee',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2024, 1, 1),
    );
    final invite = Message(
      stanzaID: 'invite-search-1',
      senderJid: 'self@example.com',
      chatJid: chat.jid,
      body: 'Invite',
      timestamp: DateTime.utc(2024, 1, 1, 10),
      pseudoMessageType: PseudoMessageType.mucInvite,
      pseudoMessageData: const {
        'roomJid': 'room@conference.example.com',
        'roomName': 'Room',
        'token': 'token-search',
      },
    );
    final accepted = Message(
      stanzaID: 'invite-accepted-search-1',
      senderJid: 'invitee@example.com',
      chatJid: chat.jid,
      body: 'Invite accepted',
      timestamp: DateTime.utc(2024, 1, 1, 11),
      pseudoMessageType: PseudoMessageType.mucInviteAccepted,
      pseudoMessageData: const {
        'roomJid': 'room@conference.example.com',
        'roomName': 'Room',
        'token': 'token-search',
        'accepted': true,
      },
    );

    final lifecycle = resolveActiveInviteLifecycleTokens(
      messages: const <Message>[],
      searchResults: [invite, accepted],
      searchFiltering: true,
    );
    final items = _projectMessages(
      chat: chat,
      messages: [invite, accepted],
      revokedInviteTokens: lifecycle.revokedInviteTokens,
      acceptedInviteTokens: lifecycle.acceptedInviteTokens,
    );

    final timelineMessage = items.whereType<ChatTimelineMessageItem>().single;
    expect(timelineMessage.messageModel.stanzaID, equals('invite-search-1'));
    expect(timelineMessage.inviteAccepted, isTrue);
    expect(timelineMessage.inviteLabel, equals('Invite accepted'));
  });

  test('hidden accepted markers alone render the empty state', () {
    final chat = chat_models.Chat(
      jid: 'invitee@example.com',
      title: 'Invitee',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2024, 1, 1),
    );
    final accepted = Message(
      stanzaID: 'invite-accepted-only-1',
      senderJid: 'invitee@example.com',
      chatJid: chat.jid,
      body: 'Invite accepted',
      timestamp: DateTime.utc(2024, 1, 1, 11),
      pseudoMessageType: PseudoMessageType.mucInviteAccepted,
      pseudoMessageData: const {
        'roomJid': 'room@conference.example.com',
        'token': 'token-only',
        'accepted': true,
      },
    );

    final items = _projectMessages(chat: chat, messages: [accepted]);

    final emptyState = items.single as ChatTimelineEmptyStateItem;
    expect(emptyState.label, equals('Empty'));
  });

  test('invite lifecycle tokens use the latest successful marker', () {
    final revoked = Message(
      stanzaID: 'invite-revoked-1',
      senderJid: 'self@example.com',
      chatJid: 'invitee@example.com',
      body: 'Invite revoked',
      timestamp: DateTime.utc(2024, 1, 1, 10),
      pseudoMessageType: PseudoMessageType.mucInviteRevocation,
      pseudoMessageData: const {'token': 'token-1'},
    );
    final accepted = Message(
      stanzaID: 'invite-accepted-1',
      senderJid: 'invitee@example.com',
      chatJid: 'invitee@example.com',
      body: 'Invite accepted',
      timestamp: DateTime.utc(2024, 1, 1, 11),
      pseudoMessageType: PseudoMessageType.mucInviteAccepted,
      pseudoMessageData: const {'token': 'token-1'},
    );
    final failedAccepted = accepted.copyWith(
      stanzaID: 'invite-accepted-failed',
      timestamp: DateTime.utc(2024, 1, 1, 12),
      error: MessageError.unknown,
    );

    final lifecycle = resolveInviteLifecycleTokens([
      failedAccepted,
      accepted,
      revoked,
    ]);

    expect(lifecycle.acceptedInviteTokens, contains('token-1'));
    expect(lifecycle.revokedInviteTokens, isEmpty);

    final laterRevoked = revoked.copyWith(
      stanzaID: 'invite-revoked-later',
      timestamp: DateTime.utc(2024, 1, 1, 13),
    );
    final laterLifecycle = resolveInviteLifecycleTokens([
      laterRevoked,
      accepted,
    ]);

    expect(laterLifecycle.acceptedInviteTokens, isEmpty);
    expect(laterLifecycle.revokedInviteTokens, contains('token-1'));
  });
}

List<ChatTimelineItem> _projectMessages({
  required chat_models.Chat chat,
  required List<Message> messages,
  Set<String> revokedInviteTokens = const {},
  Set<String> acceptedInviteTokens = const {},
}) {
  return buildMainChatTimelineItems(
    messages: messages,
    loadingMessages: false,
    unreadBoundaryStanzaId: null,
    emptyStateCreatedAt: DateTime.utc(2024, 1, 1),
    unreadDividerItemId: 'unread-divider',
    unreadDividerLabel: 'Unread',
    emptyStateItemId: 'empty-state',
    emptyStateLabel: 'Empty',
    isGroupChat: false,
    isEmailChat: false,
    profileJid: 'self@example.com',
    resolvedEmailSelfJid: null,
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
    revokedInviteTokens: revokedInviteTokens,
    acceptedInviteTokens: acceptedInviteTokens,
    inviteRoomFallbackLabel: 'Room',
    inviteBodyLabel: 'Invite',
    inviteRevokedBodyLabel: 'Invite revoked',
    inviteAcceptedBodyLabel: 'Invite accepted',
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
