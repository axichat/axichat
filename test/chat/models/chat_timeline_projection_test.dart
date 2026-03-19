import 'package:axichat/src/chat/models/chat_timeline.dart';
import 'package:axichat/src/chat/models/chat_timeline_projection.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/models/chat_models.dart' as chat_models;
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
