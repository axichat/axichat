import 'package:axichat/src/notifications/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const strings = NotificationStrings(
    channelMessages: 'Messages',
    newMessageTitle: 'New message',
    newEmailTitle: 'New email',
    openAction: 'Open notification',
    appTitle: 'Axichat',
    backgroundConnectionDisabledTitle: 'Background notifications disabled',
    backgroundConnectionDisabledBody: 'Open Axichat to reconnect.',
  );

  group('resolveMessageNotificationPresentation', () {
    test('labels hidden email notifications with the sender', () {
      final presentation = resolveMessageNotificationPresentation(
        strings: strings,
        channel: MessageNotificationChannel.email,
        conversationTitle: 'Peer',
        senderName: 'Peer',
        isGroupConversation: false,
        sanitizedBody: null,
        useMessagingStyle: false,
      );

      expect(presentation.title, 'New email: Peer');
      expect(presentation.body, isNull);
    });

    test('labels hidden chat notifications with the sender', () {
      final presentation = resolveMessageNotificationPresentation(
        strings: strings,
        channel: MessageNotificationChannel.chat,
        conversationTitle: 'Peer',
        senderName: 'Peer',
        isGroupConversation: false,
        sanitizedBody: null,
        useMessagingStyle: false,
      );

      expect(presentation.title, 'New message: Peer');
      expect(presentation.body, isNull);
    });

    test('keeps the group title and sender visible without a preview', () {
      final presentation = resolveMessageNotificationPresentation(
        strings: strings,
        channel: MessageNotificationChannel.chat,
        conversationTitle: 'Room',
        senderName: 'Alice',
        isGroupConversation: true,
        sanitizedBody: null,
        useMessagingStyle: false,
      );

      expect(presentation.title, 'New message: Room');
      expect(presentation.body, 'Alice');
    });

    test('leaves messaging style preview notifications unprefixed', () {
      final presentation = resolveMessageNotificationPresentation(
        strings: strings,
        channel: MessageNotificationChannel.email,
        conversationTitle: 'Peer',
        senderName: 'Peer',
        isGroupConversation: false,
        sanitizedBody: 'Hello',
        useMessagingStyle: true,
      );

      expect(presentation.title, 'Peer');
      expect(presentation.body, 'Hello');
    });

    test('keeps non-messaging group previews in the body', () {
      final presentation = resolveMessageNotificationPresentation(
        strings: strings,
        channel: MessageNotificationChannel.chat,
        conversationTitle: 'Room',
        senderName: 'Alice',
        isGroupConversation: true,
        sanitizedBody: 'Hello',
        useMessagingStyle: false,
      );

      expect(presentation.title, 'Room');
      expect(presentation.body, 'Alice: Hello');
    });
  });
}
