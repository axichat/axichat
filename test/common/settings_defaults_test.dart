import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const SettingsState state = SettingsState();

  group('SettingsState defaults', () {
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

    test('shows the donation prompt after 100 tracked messages by default', () {
      expect(state.donationPromptNextDisplayMessageCount, 100);
      expect(state.showsDonationPrompt(99), isFalse);
      expect(state.showsDonationPrompt(100), isTrue);
    });

    test('tracks new messages across stored-count resets', () {
      final afterInitialSync = state.syncDonationPromptMessageCount(120);
      expect(afterInitialSync.donationPromptTrackedMessageCount, 120);
      expect(
        afterInitialSync.donationPromptLastObservedStoredMessageCount,
        120,
      );

      final afterDeletion = afterInitialSync.syncDonationPromptMessageCount(20);
      expect(afterDeletion.donationPromptTrackedMessageCount, 120);
      expect(afterDeletion.donationPromptLastObservedStoredMessageCount, 20);

      final afterMoreMessages = afterDeletion.syncDonationPromptMessageCount(
        35,
      );
      expect(afterMoreMessages.donationPromptTrackedMessageCount, 135);
      expect(
        afterMoreMessages.donationPromptLastObservedStoredMessageCount,
        35,
      );
    });
  });
}
