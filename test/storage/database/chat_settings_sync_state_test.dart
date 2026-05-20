import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late XmppDrift database;

  setUp(() {
    database = XmppDrift.inMemory();
  });

  tearDown(() async {
    await database.close();
  });

  test('updateChatSettingsSyncState clears nullable setting columns', () async {
    final timestamp = DateTime.utc(2026, 5, 19, 8);
    final chat = Chat.fromJid('settings-clear@example.com').copyWith(
      muted: true,
      notificationPreviewSetting: NotificationPreviewSetting.show,
      notificationBehavior: ChatNotificationBehavior.muted,
      markerResponsive: true,
      shareSignatureEnabled: true,
      attachmentAutoDownload: AttachmentAutoDownload.allowed,
      emailRemoteImagesEnabled: true,
      typingIndicatorsEnabled: true,
      emailReadReceiptsEnabled: true,
      emailSendConfirmationEnabled: true,
      emailComposerWatermarkEnabled: true,
      chatSettingsUpdatedAt: timestamp,
      chatSettingsSourceId: 'source-a',
      chatSettingsConfirmedJson: '{"read_receipts":true}',
      chatSettingsConfirmedUpdatedAt: timestamp,
      chatSettingsConfirmedSourceId: 'source-a',
    );
    await database.createChat(chat);

    await database.updateChatSettingsSyncState(
      chat.copyWith(
        muted: false,
        notificationPreviewSetting: null,
        notificationBehavior: null,
        markerResponsive: null,
        shareSignatureEnabled: null,
        attachmentAutoDownload: null,
        emailRemoteImagesEnabled: null,
        typingIndicatorsEnabled: null,
        emailReadReceiptsEnabled: null,
        emailSendConfirmationEnabled: null,
        emailComposerWatermarkEnabled: null,
        chatSettingsUpdatedAt: null,
        chatSettingsSourceId: null,
        chatSettingsConfirmedJson: null,
        chatSettingsConfirmedUpdatedAt: null,
        chatSettingsConfirmedSourceId: null,
      ),
    );

    final saved = await database.getChat(chat.jid);
    expect(saved?.muted, isFalse);
    expect(saved?.notificationPreviewSetting, isNull);
    expect(saved?.notificationBehavior, isNull);
    expect(saved?.markerResponsive, isNull);
    expect(saved?.shareSignatureEnabled, isNull);
    expect(saved?.attachmentAutoDownload, isNull);
    expect(saved?.emailRemoteImagesEnabled, isNull);
    expect(saved?.typingIndicatorsEnabled, isNull);
    expect(saved?.emailReadReceiptsEnabled, isNull);
    expect(saved?.emailSendConfirmationEnabled, isNull);
    expect(saved?.emailComposerWatermarkEnabled, isNull);
    expect(saved?.chatSettingsUpdatedAt, isNull);
    expect(saved?.chatSettingsSourceId, isNull);
    expect(saved?.chatSettingsConfirmedJson, isNull);
    expect(saved?.chatSettingsConfirmedUpdatedAt, isNull);
    expect(saved?.chatSettingsConfirmedSourceId, isNull);
  });
}
