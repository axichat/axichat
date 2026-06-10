import 'package:axichat/src/chat/models/chat_timeline.dart';
import 'package:axichat/src/chat/view/chat.dart' as chat_view;
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/models/chat_models.dart' as chat_models;
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'materialized row replacement removes same-stanza messages from other chats',
    (tester) async {
      final renderedSnapshots = <List<Message>>[];
      final firstMessage = _message(chatJid: 'first@axi.im');
      final secondMessage = _message(chatJid: 'second@axi.im');

      await tester.pumpWidget(
        _wrap(
          chat_view.debugChatMessageListForTesting(
            items: [_timelineItem(firstMessage)],
            itemBuilder: _row,
            messageListOptions: const MessageListOptions(
              showDateSeparator: false,
            ),
            scrollToBottomOptions: const ScrollToBottomOptions(disabled: true),
            onRenderedMessagesChanged: renderedSnapshots.add,
          ),
        ),
      );
      await tester.pump();

      expect(renderedSnapshots.last.single.chatJid, firstMessage.chatJid);

      await tester.pumpWidget(
        _wrap(
          chat_view.debugChatMessageListForTesting(
            items: [_timelineItem(secondMessage)],
            itemBuilder: _row,
            messageListOptions: const MessageListOptions(
              showDateSeparator: false,
            ),
            scrollToBottomOptions: const ScrollToBottomOptions(disabled: true),
            onRenderedMessagesChanged: renderedSnapshots.add,
          ),
        ),
      );
      await tester.pump();

      expect(renderedSnapshots.last.map((message) => message.chatJid), [
        secondMessage.chatJid,
      ]);
    },
  );

  testWidgets('hydration key changes re-emit the materialized row set', (
    tester,
  ) async {
    final renderedSnapshots = <List<Message>>[];
    final message = _message(chatJid: 'first@axi.im');

    await tester.pumpWidget(
      _wrap(
        chat_view.debugChatMessageListForTesting(
          items: [_timelineItem(message)],
          itemBuilder: _row,
          messageListOptions: const MessageListOptions(
            showDateSeparator: false,
          ),
          scrollToBottomOptions: const ScrollToBottomOptions(disabled: true),
          onRenderedMessagesChanged: renderedSnapshots.add,
          renderedMessagesHydrationKey: false,
        ),
      ),
    );
    await tester.pump();

    expect(renderedSnapshots, hasLength(1));

    await tester.pumpWidget(
      _wrap(
        chat_view.debugChatMessageListForTesting(
          items: [_timelineItem(message)],
          itemBuilder: _row,
          messageListOptions: const MessageListOptions(
            showDateSeparator: false,
          ),
          scrollToBottomOptions: const ScrollToBottomOptions(disabled: true),
          onRenderedMessagesChanged: renderedSnapshots.add,
          renderedMessagesHydrationKey: true,
        ),
      ),
    );
    await tester.pump();

    expect(renderedSnapshots, hasLength(2));
    expect(renderedSnapshots.last.single, message);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SizedBox(height: 240, child: child)),
  );
}

Widget _row(
  ChatTimelineItem item,
  ChatTimelineItem? previous,
  ChatTimelineItem? next,
) {
  return SizedBox(height: 48, child: Text(item.id));
}

Message _message({required String chatJid}) {
  return Message(
    stanzaID: 'same-stanza-id',
    senderJid: chatJid,
    chatJid: chatJid,
    timestamp: DateTime(2026, 1, 1),
    body: 'body',
  );
}

ChatTimelineMessageItem _timelineItem(Message message) {
  return ChatTimelineMessageItem(
    id: message.stanzaID,
    createdAt: message.timestamp!,
    messageModel: message,
    authorId: message.senderJid,
    authorDisplayName: message.senderJid,
    authorAvatarKey: message.senderJid,
    authorAvatarPath: null,
    delivery: ChatTimelineMessageDelivery.none,
    rowText: message.body!,
    isSelf: false,
    isEmailMessage: false,
    canSendAgain: false,
    showUnreadIndicator: false,
    error: MessageError.none,
    trusted: null,
    renderedText: message.body!,
    attachmentIds: const <String>[],
    edited: false,
    retracted: false,
    calendarFragment: null,
    calendarTaskIcs: null,
    calendarTaskIcsReadOnly: false,
    availabilityMessage: null,
    quotedMessage: null,
    reactions: const <ReactionPreview>[],
    shareParticipants: const <chat_models.Chat>[],
    replyParticipants: const <chat_models.Chat>[],
    showSubject: false,
    subjectLabel: null,
    emailRfcGroupKey: null,
    isEmailRfcGroupLeader: true,
    emailVisualKind: ChatTimelineEmailVisualKind.none,
    isForwarded: false,
    forwardedFromJid: null,
    forwardedOriginalSenderLabel: null,
    forwardedSubjectSenderLabel: null,
    isInvite: false,
    isInviteRevocation: false,
    inviteRevoked: false,
    inviteAccepted: false,
    inviteLabel: '',
    inviteActionLabel: '',
    inviteRoom: null,
    inviteRoomName: null,
    resolvedHtmlBody: null,
    emailBodyBlocks: const <ChatTimelineEmailBodyBlock>[],
  );
}
