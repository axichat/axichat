import 'package:axichat/src/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatSettingsSyncModel', () {
    test(
      'markChatSettingsSyncConfirmed clears not synced for current values',
      () {
        final chat = _chat(
          markerResponsive: false,
          chatSettingsConfirmedJson: '{"read_receipts":true}',
        );

        expect(chat.isChatSettingNotSynced(ChatSettingId.readReceipts), isTrue);

        final confirmed = chat.markChatSettingsSyncConfirmed();

        expect(
          confirmed.isChatSettingNotSynced(ChatSettingId.readReceipts),
          isFalse,
        );
      },
    );

    test('clearOverrideValue resets notification behavior to inherited', () {
      final chat = _chat(
        muted: true,
        notificationBehavior: ChatNotificationBehavior.muted,
      );

      final cleared = ChatSettingId.notificationBehavior.clearOverrideValue(
        chat,
      );

      expect(cleared.effectiveNotificationBehavior, isNull);
      expect(cleared.muted, isFalse);
    });
  });
}

Chat _chat({
  bool muted = false,
  bool? markerResponsive,
  String? chatSettingsConfirmedJson,
  ChatNotificationBehavior? notificationBehavior,
}) {
  return Chat(
    jid: 'peer@example.com',
    title: 'Peer',
    type: ChatType.chat,
    lastChangeTimestamp: DateTime.utc(2026),
    muted: muted,
    markerResponsive: markerResponsive,
    notificationBehavior: notificationBehavior,
    chatSettingsConfirmedJson: chatSettingsConfirmedJson,
  );
}
