import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/settings/app_language.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks.dart';

class _InMemoryStorage implements Storage {
  final Map<String, dynamic> _store = {};

  @override
  dynamic read(String key) => _store[key];

  @override
  Future<void> write(String key, dynamic value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }

  @override
  Future<void> close() async {}
}

void main() {
  setUpAll(() {
    registerFallbackValue(CredentialStore.registerKey('test_fallback'));
  });

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

    test('keeps attachment image auto-download disabled by default', () {
      expect(state.autoDownloadImages, isFalse);
    });

    test(
      'keeps restored attachment image auto-download disabled by default',
      () {
        expect(SettingsState.fromJson(const {}).autoDownloadImages, isFalse);
      },
    );

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
      expect(synced.containsKey('email_encryption_beta'), isFalse);
      expect(synced['chat_read_receipts'], isTrue);
      expect(synced['auto_download_images'], isFalse);
    });

    test('email encryption beta is local only', () {
      final localState = state.copyWith(
        emailEncryptionBetaEnabledByAddress: const {'user@example.com': true},
      );

      expect(
        localState.syncedSettingsJson.containsKey('email_encryption_beta'),
        isFalse,
      );
      expect(
        localState.syncedSettingsJson.containsKey(
          'email_encryption_beta_enabled_by_address',
        ),
        isFalse,
      );
    });

    test('all notifications muted is derived from transport mutes', () {
      expect(state.allNotificationsMuted, isFalse);
      expect(
        state.copyWith(chatNotificationsMuted: true).allNotificationsMuted,
        isFalse,
      );
      expect(
        state
            .copyWith(
              chatNotificationsMuted: true,
              emailNotificationsMuted: true,
            )
            .allNotificationsMuted,
        isTrue,
      );
    });

    test('does not mark loading settings as not synced', () {
      final changed = state.copyWith(
        chatReadReceipts: false,
        globalSettingStatuses: const {
          GlobalSettingId.chatReadReceipts: RequestStatus.loading,
        },
        settingsSyncHasConfirmedSnapshot: true,
        settingsSyncConfirmedJson: state.syncedSettingsJson,
      );

      expect(
        changed.isGlobalSettingNotSynced(GlobalSettingId.chatReadReceipts),
        isFalse,
      );
      expect(
        changed.unsyncedGlobalSettingIds,
        isNot(contains(GlobalSettingId.chatReadReceipts)),
      );
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

    test('does not show the donation prompt while disabled', () {
      const promptState = SettingsState(
        endpointConfig: EndpointConfig(domain: 'selfhost.example'),
        donationPromptAccountJid: accountJid,
        donationPromptTrackingInitialized: true,
        donationPromptTrackedMessageCount: 100,
        donationPromptLastObservedStoredMessageCount: 100,
      );

      expect(
        promptState.showsDonationPrompt(
          accountJid: accountJid,
          storedConversationMessageCount: 100,
        ),
        isFalse,
      );
      expect(
        promptState
            .copyWith(endpointConfig: const EndpointConfig())
            .showsDonationPrompt(
              accountJid: accountJid,
              storedConversationMessageCount: 100,
            ),
        isFalse,
      );
      expect(
        promptState
            .copyWith(donationPromptAccountJid: 'user@axi.im')
            .showsDonationPrompt(
              accountJid: 'user@axi.im',
              storedConversationMessageCount: 100,
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

  group('SettingsCubit email encryption beta updates', () {
    test('normalizes addresses and removes disabled entries', () async {
      HydratedBloc.storage = _InMemoryStorage();
      final cubit = SettingsCubit();
      addTearDown(cubit.close);
      await cubit.activateAccountSettings(accountJid);

      await cubit.setEmailEncryptionBetaEnabled('User@Example.COM', true);

      expect(cubit.state.emailEncryptionBetaEnabledByAddress, {
        'user@example.com': true,
      });

      await cubit.setEmailEncryptionBetaEnabled('user@example.com', false);

      expect(cubit.state.emailEncryptionBetaEnabledByAddress, isEmpty);
    });

    test('rejects empty and invalid addresses', () async {
      HydratedBloc.storage = _InMemoryStorage();
      final cubit = SettingsCubit();
      addTearDown(cubit.close);

      await expectLater(
        cubit.setEmailEncryptionBetaEnabled('', true),
        throwsArgumentError,
      );
      await expectLater(
        cubit.setEmailEncryptionBetaEnabled('not-an-address', true),
        throwsArgumentError,
      );
    });
  });

  group('SettingsCubit background messaging account preferences', () {
    late MockCredentialStore credentialStore;
    late Map<String, String?> credentialStorage;

    setUp(() {
      credentialStore = MockCredentialStore();
      credentialStorage = <String, String?>{};
      when(() => credentialStore.read(key: any(named: 'key'))).thenAnswer((
        invocation,
      ) async {
        final key = invocation.namedArguments[#key] as RegisteredCredentialKey;
        return credentialStorage[key.value];
      });
      when(
        () => credentialStore.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key] as RegisteredCredentialKey;
        credentialStorage[key.value] =
            invocation.namedArguments[#value] as String?;
        return true;
      });
      when(() => credentialStore.delete(key: any(named: 'key'))).thenAnswer((
        invocation,
      ) async {
        final key = invocation.namedArguments[#key] as RegisteredCredentialKey;
        credentialStorage.remove(key.value);
        return true;
      });
      when(() => credentialStore.close()).thenAnswer((_) async {});
    });

    test(
      'does not let one account inherit another background preference',
      () async {
        HydratedBloc.storage = _InMemoryStorage();
        final cubit = SettingsCubit(credentialStore: credentialStore);
        addTearDown(cubit.close);
        await cubit.activateAccountSettings('User@Example.COM');

        await cubit.toggleBackgroundMessaging(
          true,
          accountJid: 'User@Example.COM',
        );
        await cubit.activateAccountSettings('other@example.com');

        expect(cubit.state.backgroundMessagingEnabled, isFalse);

        await cubit.activateAccountSettings('user@example.com');

        expect(cubit.state.backgroundMessagingEnabled, isTrue);
      },
    );

    test(
      'does not let a no-account background update mutate bootstrap',
      () async {
        HydratedBloc.storage = _InMemoryStorage();
        final cubit = SettingsCubit(credentialStore: credentialStore);
        addTearDown(cubit.close);

        await cubit.toggleBackgroundMessaging(true);

        expect(cubit.state.backgroundMessagingEnabled, isFalse);
        expect(
          await cubit.backgroundMessagingEnabledForAccount('user@example.com'),
          isFalse,
        );
      },
    );

    test('keeps account-owned settings out of bootstrap', () async {
      HydratedBloc.storage = _InMemoryStorage();
      final cubit = SettingsCubit(credentialStore: credentialStore);
      addTearDown(cubit.close);

      await cubit.toggleChatReadReceipts(false);
      await cubit.toggleNotificationPreviews(true);
      await cubit.updateThemeMode(ThemeMode.dark);

      expect(cubit.state.chatReadReceipts, isTrue);
      expect(cubit.state.notificationPreviewsEnabled, isFalse);
      expect(cubit.state.themeMode, ThemeMode.dark);
    });

    test('imports legacy flat settings for the initially stored jid', () async {
      HydratedBloc.storage = _InMemoryStorage();
      credentialStorage['jid'] = 'user@example.com';
      final cubit = SettingsCubit(credentialStore: credentialStore);
      addTearDown(cubit.close);
      cubit.fromJson(const {
        'chat_read_receipts': false,
        'background_messaging_enabled': true,
      });

      await cubit.activateAccountSettings('user@example.com');

      expect(cubit.state.chatReadReceipts, isFalse);
      expect(cubit.state.backgroundMessagingEnabled, isTrue);

      await cubit.activateAccountSettings('other@example.com');

      expect(cubit.state.chatReadReceipts, isTrue);
      expect(cubit.state.backgroundMessagingEnabled, isFalse);
    });

    test(
      'pre-connect lookup reads matching legacy flat background preference',
      () async {
        HydratedBloc.storage = _InMemoryStorage();
        credentialStorage['jid'] = 'user@example.com';
        final cubit = SettingsCubit(credentialStore: credentialStore);
        addTearDown(cubit.close);
        cubit.fromJson(const {
          'chat_read_receipts': false,
          'background_messaging_enabled': true,
        });

        expect(
          await cubit.backgroundMessagingEnabledForAccount('user@example.com'),
          isTrue,
        );
        expect(
          await cubit.backgroundMessagingEnabledForAccount('other@example.com'),
          isFalse,
        );

        await cubit.activateAccountSettings('user@example.com');

        expect(cubit.state.chatReadReceipts, isFalse);
        expect(cubit.state.backgroundMessagingEnabled, isTrue);
      },
    );

    test(
      'pre-connect lookup lets legacy per-address preference override flat settings',
      () async {
        HydratedBloc.storage = _InMemoryStorage();
        credentialStorage['jid'] = 'user@example.com';
        credentialStorage['background_messaging_by_address_v1'] =
            '{"user@example.com":false}';
        final cubit = SettingsCubit(credentialStore: credentialStore);
        addTearDown(cubit.close);
        cubit.fromJson(const {'background_messaging_enabled': true});

        expect(
          await cubit.backgroundMessagingEnabledForAccount('user@example.com'),
          isFalse,
        );

        await cubit.activateAccountSettings('user@example.com');

        expect(cubit.state.backgroundMessagingEnabled, isFalse);
      },
    );

    test(
      'does not import legacy flat settings for a later credential jid',
      () async {
        HydratedBloc.storage = _InMemoryStorage();
        credentialStorage['jid'] = 'old@example.com';
        final cubit = SettingsCubit(credentialStore: credentialStore);
        addTearDown(cubit.close);
        cubit.fromJson(const {
          'chat_read_receipts': false,
          'background_messaging_enabled': true,
        });
        credentialStorage['jid'] = 'new@example.com';

        await cubit.activateAccountSettings('new@example.com');

        expect(cubit.state.chatReadReceipts, isTrue);
        expect(cubit.state.backgroundMessagingEnabled, isFalse);

        await cubit.activateAccountSettings('old@example.com');

        expect(cubit.state.chatReadReceipts, isFalse);
        expect(cubit.state.backgroundMessagingEnabled, isTrue);
      },
    );

    test(
      'uses the provided account jid when toggling background messaging',
      () async {
        HydratedBloc.storage = _InMemoryStorage();
        final cubit = SettingsCubit(credentialStore: credentialStore);
        addTearDown(cubit.close);

        await cubit.activateAccountSettings('first@example.com');
        await cubit.toggleBackgroundMessaging(
          true,
          accountJid: 'second@example.com',
        );

        expect(cubit.state.backgroundMessagingEnabled, isTrue);

        await cubit.activateAccountSettings('first@example.com');

        expect(cubit.state.backgroundMessagingEnabled, isFalse);

        await cubit.activateAccountSettings('second@example.com');

        expect(cubit.state.backgroundMessagingEnabled, isTrue);
      },
    );

    test(
      'imports legacy per-address background preference for matching jid',
      () async {
        HydratedBloc.storage = _InMemoryStorage();
        credentialStorage['background_messaging_by_address_v1'] =
            '{"user@example.com":true}';
        final cubit = SettingsCubit(credentialStore: credentialStore);
        addTearDown(cubit.close);

        await cubit.activateAccountSettings('other@example.com');

        expect(cubit.state.backgroundMessagingEnabled, isFalse);

        await cubit.activateAccountSettings('user@example.com');

        expect(cubit.state.backgroundMessagingEnabled, isTrue);
      },
    );
  });
}
