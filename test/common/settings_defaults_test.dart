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

    test('keeps send on enter disabled by default', () {
      expect(state.chatSendOnEnter, isFalse);
      expect(state.emailSendOnEnter, isFalse);
    });

    test('requires email send confirmation by default', () {
      expect(state.emailSendConfirmationEnabled, isTrue);
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
