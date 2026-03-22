import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/settings/app_language.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const SettingsState state = SettingsState();
  const accountJid = 'user@example.com';
  const otherAccountJid = 'other@example.com';

  group('SettingsState defaults', () {
    test('keeps background messaging disabled by default', () {
      expect(state.backgroundMessagingEnabled, isFalse);
    });

    test('blocks remote email images by default', () {
      const expectAutoLoadEmailImages = false;
      expect(state.autoLoadEmailImages, expectAutoLoadEmailImages);
    });

    test('keeps archive auto-download disabled by default', () {
      const expectAutoDownloadArchives = false;
      expect(state.autoDownloadArchives, expectAutoDownloadArchives);
    });

    test('enables send on enter for XMPP by default only', () {
      expect(state.chatSendOnEnter, isTrue);
      expect(state.emailSendOnEnter, isFalse);
    });

    test('requires email send confirmation by default', () {
      expect(state.emailSendConfirmationEnabled, isTrue);
    });

    test('sync payload excludes device-local settings', () {
      final synced = state.syncedSettingsJson;

      expect(synced.containsKey('chat_notifications_muted'), isFalse);
      expect(synced.containsKey('email_notifications_muted'), isFalse);
      expect(synced.containsKey('notification_previews_enabled'), isFalse);
      expect(synced.containsKey('background_messaging_enabled'), isFalse);
      expect(synced.containsKey('endpoint_config'), isFalse);
      expect(synced['chat_read_receipts'], isTrue);
      expect(synced['auto_download_images'], isTrue);
    });

    test('mergeSyncedSettingsJson preserves local-only settings', () {
      final localState = state.copyWith(
        endpointConfig: const EndpointConfig(
          domain: 'custom.example',
          smtpEnabled: false,
        ),
        chatNotificationsMuted: true,
        emailNotificationsMuted: true,
        notificationPreviewsEnabled: true,
        language: AppLanguage.english,
        shadColor: ShadColor.red,
        autoDownloadVideos: false,
      );

      final merged = localState.mergeSyncedSettingsJson(<String, dynamic>{
        'language': 'german',
        'shad_color': 'green',
        'auto_download_videos': true,
        'chat_notifications_muted': false,
        'endpoint_config': const <String, dynamic>{'domain': 'ignored.example'},
      });

      expect(merged.language, AppLanguage.german);
      expect(merged.shadColor, ShadColor.green);
      expect(merged.autoDownloadVideos, isTrue);
      expect(merged.chatNotificationsMuted, isTrue);
      expect(merged.emailNotificationsMuted, isTrue);
      expect(merged.notificationPreviewsEnabled, isTrue);
      expect(merged.endpointConfig.domain, 'custom.example');
      expect(merged.endpointConfig.smtpEnabled, isFalse);
    });

    test(
      'does not show the donation prompt from the initial stored backlog',
      () {
        expect(state.donationPromptNextDisplayMessageCount, 100);
        expect(
          state.showsDonationPrompt(
            accountJid: accountJid,
            storedConversationMessageCount: 99,
          ),
          isFalse,
        );
        expect(
          state.showsDonationPrompt(
            accountJid: accountJid,
            storedConversationMessageCount: 100,
          ),
          isFalse,
        );
      },
    );

    test(
      'baselines the initial stored count and tracks new messages afterward',
      () {
        final afterInitialSync = state.syncDonationPromptMessageCount(
          accountJid: accountJid,
          storedConversationMessageCount: 120,
        );
        expect(afterInitialSync.donationPromptAccountJid, accountJid);
        expect(afterInitialSync.donationPromptTrackingInitialized, isTrue);
        expect(afterInitialSync.donationPromptTrackedMessageCount, 0);
        expect(
          afterInitialSync.donationPromptLastObservedStoredMessageCount,
          120,
        );
        expect(
          afterInitialSync.showsDonationPrompt(
            accountJid: accountJid,
            storedConversationMessageCount: 120,
          ),
          isFalse,
        );

        final afterDeletion = afterInitialSync.syncDonationPromptMessageCount(
          accountJid: accountJid,
          storedConversationMessageCount: 20,
        );
        expect(afterDeletion.donationPromptTrackedMessageCount, 0);
        expect(afterDeletion.donationPromptLastObservedStoredMessageCount, 20);

        final afterMoreMessages = afterDeletion.syncDonationPromptMessageCount(
          accountJid: accountJid,
          storedConversationMessageCount: 35,
        );
        expect(afterMoreMessages.donationPromptTrackedMessageCount, 15);
        expect(
          afterMoreMessages.donationPromptLastObservedStoredMessageCount,
          35,
        );
      },
    );

    test('tracks from zero once donation prompt tracking is initialized', () {
      final afterEmptyBaseline = state.syncDonationPromptMessageCount(
        accountJid: accountJid,
        storedConversationMessageCount: 0,
      );
      expect(afterEmptyBaseline.donationPromptTrackingInitialized, isTrue);
      expect(afterEmptyBaseline.donationPromptTrackedMessageCount, 0);

      final afterFirstMessage = afterEmptyBaseline
          .syncDonationPromptMessageCount(
            accountJid: accountJid,
            storedConversationMessageCount: 1,
          );
      expect(afterFirstMessage.donationPromptTrackedMessageCount, 1);
      expect(
        afterFirstMessage.showsDonationPrompt(
          accountJid: accountJid,
          storedConversationMessageCount: 1,
        ),
        isFalse,
      );
    });

    test('resets donation prompt tracking when the active account changes', () {
      final hiddenPromptState = state.copyWith(
        donationPromptAccountJid: accountJid,
        donationPromptNextDisplayMessageCount: 620,
        donationPromptTrackedMessageCount: 120,
        donationPromptTrackingInitialized: true,
        donationPromptLastObservedStoredMessageCount: 120,
      );
      final reset = hiddenPromptState.syncDonationPromptMessageCount(
        accountJid: otherAccountJid,
        storedConversationMessageCount: 0,
      );
      expect(reset.donationPromptAccountJid, otherAccountJid);
      expect(reset.donationPromptTrackingInitialized, isTrue);
      expect(reset.donationPromptTrackedMessageCount, 0);
      expect(reset.donationPromptNextDisplayMessageCount, 100);
      expect(
        reset.showsDonationPrompt(
          accountJid: otherAccountJid,
          storedConversationMessageCount: 0,
        ),
        isFalse,
      );
    });
  });
}
