// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:convert';

import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/email_validation.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/authentication/bloc/email_provisioning_client.dart'
    as provisioning;
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/app_language.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

part 'settings_cubit.freezed.dart';
part 'settings_cubit.g.dart';
part 'settings_state.dart';

class SettingsCubit extends HydratedCubit<SettingsState> {
  SettingsCubit({
    XmppService? xmppService,
    Capability? capability,
    CredentialStore? credentialStore,
    http.Client? httpClient,
    provisioning.EmailProvisioningClient? recoveryClient,
  }) : _xmppService = xmppService,
       _capability = capability,
       _credentialStore = credentialStore,
       _recoveryClient =
           recoveryClient ??
           provisioning.EmailProvisioningClient.fromEnvironment(
             httpClient: httpClient,
           ),
       _ownsRecoveryClient = recoveryClient == null,
       _bootstrapState = _initialStateFor(capability),
       super(_initialStateFor(capability)) {
    _initialStoredLoginJid = _readStoredLoginJid();
    _applySettingsSideEffects(state);
    final service = _xmppService;
    if (service != null) {
      _settingsSyncSubscription = service.settingsSyncUpdateStream.listen(
        _handleRemoteSettingsSync,
      );
    }
  }

  static const int _settingsEnvelopeVersion = 1;
  static const String _settingsEnvelopeVersionKey = 'version';
  static const String _settingsEnvelopeBootstrapKey = 'bootstrap';
  static const String _settingsEnvelopeAccountsKey = 'accounts';
  static const String _endpointConfigJsonKey = 'endpoint_config';
  static const String _storedLoginJidKeyName = 'jid';

  final XmppService? _xmppService;
  final Capability? _capability;
  final CredentialStore? _credentialStore;
  final provisioning.EmailProvisioningClient _recoveryClient;
  final bool _ownsRecoveryClient;
  late final Future<String?> _initialStoredLoginJid;
  final Logger _log = Logger('SettingsCubit');
  StreamSubscription<Map<String, dynamic>>? _settingsSyncSubscription;
  final RegisteredCredentialKey _storedLoginJidKey =
      CredentialStore.registerKey(_storedLoginJidKeyName);
  final RegisteredCredentialKey _backgroundMessagingPreferencesKey =
      CredentialStore.registerKey('background_messaging_by_address_v1');
  final RegisteredCredentialKey _accountWelcomeShownKey =
      CredentialStore.registerKey('account_welcome_shown_by_address_v1');
  final RegisteredCredentialKey _emailWebViewTipShownKey =
      CredentialStore.registerKey('email_webview_tip_shown_by_address_v1');
  final RegisteredCredentialKey _calendarTaskDragTipShownKey =
      CredentialStore.registerKey('calendar_task_drag_tip_shown_by_address_v1');
  final RegisteredCredentialKey _recoveryWelcomeDismissedKey =
      CredentialStore.registerKey('recovery_welcome_dismissed_by_address_v1');
  SettingsState _bootstrapState;
  final Map<String, Map<String, dynamic>> _accountSettingsJsonByKey =
      <String, Map<String, dynamic>>{};
  final Map<String, Map<String, dynamic>> _pendingRemoteSettingsSyncByKey =
      <String, Map<String, dynamic>>{};
  Map<String, dynamic>? _legacyAccountSettingsJson;
  String? _activeAccountKey;

  bool get canBackgroundMessaging =>
      _capability?.canBackgroundMessaging ?? false;

  bool get canForegroundService => _capability?.canForegroundService ?? false;

  bool get _defaultBackgroundMessagingEnabled =>
      _capability?.defaultsBackgroundMessagingEnabled ?? false;

  static SettingsState _initialStateFor(Capability? capability) {
    return SettingsState(
      backgroundMessagingEnabled:
          capability?.defaultsBackgroundMessagingEnabled ?? false,
    );
  }

  Duration get animationDuration =>
      state.lowMotion ? Duration.zero : baseAnimationDuration;

  Duration get authCompletionDuration =>
      state.lowMotion ? baseAnimationDuration : authCompletionAnimationDuration;

  Future<void> updateLanguage(AppLanguage language) async {
    await _emitLocalSettingsState(
      state.copyWith(language: language),
      changedSettingIds: const {GlobalSettingId.language},
    );
  }

  Future<void> updateThemeMode(ThemeMode? themeMode) async {
    if (themeMode == null) return;
    await _emitLocalSettingsState(
      state.copyWith(themeMode: themeMode),
      changedSettingIds: const {GlobalSettingId.themeMode},
    );
  }

  Future<void> updateColorScheme(ShadColor? shadColor) async {
    if (shadColor == null) return;
    await _emitLocalSettingsState(
      state.copyWith(shadColor: shadColor),
      changedSettingIds: const {GlobalSettingId.colorScheme},
    );
  }

  Future<void> updateEndpointConfig(EndpointConfig config) async {
    await _emitLocalSettingsState(
      state.copyWith(endpointConfig: config),
      changedSettingIds: const {GlobalSettingId.endpointConfig},
    );
  }

  Future<void> resetEndpointConfig() async {
    await updateEndpointConfig(const EndpointConfig());
  }

  Future<void> toggleBackgroundMessaging(
    bool enabled, {
    String? accountJid,
  }) async {
    final accountKey = _accountKeyForJid(accountJid);
    if (_activeAccountKey == null) {
      if (accountKey == null) return;
      await activateAccountSettings(accountJid);
    } else if (accountKey != null && accountKey != _activeAccountKey) {
      await activateAccountSettings(accountJid);
    }
    await _emitLocalSettingsState(
      state.copyWith(backgroundMessagingEnabled: enabled),
      changedSettingIds: const {GlobalSettingId.backgroundMessaging},
    );
  }

  Future<void> activateAccountSettings(String? accountJid) async {
    _persistVisibleState(state);
    final accountKey = _accountKeyForJid(accountJid);
    _activeAccountKey = accountKey;
    if (accountKey == null) {
      final nextState = _bootstrapState;
      if (nextState != state) {
        emit(nextState);
      }
      _applySettingsSideEffects(nextState);
      return;
    }

    final storedJson = _accountSettingsJsonByKey[accountKey];
    var nextState = storedJson == null
        ? _newAccountSettingsState()
        : _accountStateFromJson(storedJson);
    if (storedJson == null) {
      final legacyAccountJson = await _legacyAccountSettingsJsonFor(accountJid);
      if (legacyAccountJson != null) {
        nextState = _accountStateFromJson(legacyAccountJson);
      }
      final legacyBackgroundPreference =
          await _legacyBackgroundMessagingPreference(accountJid);
      if (legacyBackgroundPreference != null) {
        nextState = nextState.copyWith(
          backgroundMessagingEnabled: legacyBackgroundPreference,
        );
      }
    }
    final pendingRemoteSettings = _pendingRemoteSettingsSyncByKey.remove(
      accountKey,
    );
    if (pendingRemoteSettings != null) {
      nextState = nextState
          .mergeSyncedSettingsJson(pendingRemoteSettings)
          .clearGlobalSettingsLoading(
            GlobalSettingId.syncedSettings,
            confirmedSnapshot: pendingRemoteSettings,
          );
    }
    nextState = _withBootstrapEndpoint(nextState);
    _accountSettingsJsonByKey[accountKey] = _accountJsonFromState(nextState);
    if (nextState != state) {
      emit(nextState);
    }
    _applySettingsSideEffects(nextState);
    await _seedSettingsSyncSnapshotIfActive();
  }

  Future<void> activateBackgroundMessagingAccount(String? accountJid) async {
    await activateAccountSettings(accountJid);
  }

  Future<bool> backgroundMessagingEnabledForAccount(String? accountJid) async {
    final accountKey = _accountKeyForJid(accountJid);
    if (accountKey == null) {
      return false;
    }
    final storedJson = _accountSettingsJsonByKey[accountKey];
    if (storedJson != null) {
      return _accountStateFromJson(storedJson).backgroundMessagingEnabled;
    }
    final legacyBackgroundPreference =
        await _legacyBackgroundMessagingPreference(accountJid);
    if (legacyBackgroundPreference != null) {
      return legacyBackgroundPreference;
    }
    final legacyAccountJson = await _matchingLegacyAccountSettingsJsonFor(
      accountJid,
    );
    if (legacyAccountJson != null) {
      return _accountStateFromJson(
        legacyAccountJson,
      ).backgroundMessagingEnabled;
    }
    return _defaultBackgroundMessagingEnabled;
  }

  Future<void> toggleChatNotificationsMuted(bool muted) async {
    await _emitLocalSettingsState(
      state.copyWith(chatNotificationsMuted: muted),
      changedSettingIds: const {GlobalSettingId.chatNotificationsMuted},
    );
  }

  Future<void> toggleEmailNotificationsMuted(bool muted) async {
    await _emitLocalSettingsState(
      state.copyWith(emailNotificationsMuted: muted),
      changedSettingIds: const {GlobalSettingId.emailNotificationsMuted},
    );
  }

  Future<void> toggleAllNotificationsMuted(bool muted) async {
    await _emitLocalSettingsState(
      state.copyWith(
        chatNotificationsMuted: muted,
        emailNotificationsMuted: muted,
      ),
      changedSettingIds: const {
        GlobalSettingId.chatNotificationsMuted,
        GlobalSettingId.emailNotificationsMuted,
      },
    );
  }

  Future<void> toggleNotificationPreviews(bool enabled) async {
    await _emitLocalSettingsState(
      state.copyWith(notificationPreviewsEnabled: enabled),
      changedSettingIds: const {GlobalSettingId.notificationPreviews},
    );
  }

  Future<void> toggleChatReadReceipts(bool enabled) async {
    await _emitLocalSettingsState(
      state.copyWith(chatReadReceipts: enabled),
      changedSettingIds: const {GlobalSettingId.chatReadReceipts},
    );
  }

  Future<void> toggleEmailReadReceipts(bool enabled) async {
    await _emitLocalSettingsState(
      state.copyWith(emailReadReceipts: enabled),
      changedSettingIds: const {GlobalSettingId.emailReadReceipts},
    );
  }

  Future<void> toggleChatSendOnEnter(bool enabled) async {
    await _emitLocalSettingsState(
      state.copyWith(chatSendOnEnter: enabled),
      changedSettingIds: const {GlobalSettingId.chatSendOnEnter},
    );
  }

  Future<void> toggleEmailSendOnEnter(bool enabled) async {
    await _emitLocalSettingsState(
      state.copyWith(emailSendOnEnter: enabled),
      changedSettingIds: const {GlobalSettingId.emailSendOnEnter},
    );
  }

  Future<void> toggleEmailSendConfirmation(bool enabled) async {
    await _emitLocalSettingsState(
      state.copyWith(emailSendConfirmationEnabled: enabled),
      changedSettingIds: const {GlobalSettingId.emailSendConfirmation},
    );
  }

  Future<void> toggleColorfulAvatars(bool colorfulAvatars) async {
    await _emitLocalSettingsState(
      state.copyWith(colorfulAvatars: colorfulAvatars),
      changedSettingIds: const {GlobalSettingId.colorfulAvatars},
    );
  }

  Future<void> markEmailForwardingGuideSeen() async {
    if (state.emailForwardingGuideSeen) {
      return;
    }
    await _emitLocalSettingsState(
      state.copyWith(emailForwardingGuideSeen: true),
      changedSettingIds: const {GlobalSettingId.emailForwardingGuideSeen},
    );
  }

  Future<bool> accountWelcomeShownFor(String? accountJid) async {
    final normalized = _normalizedAccountJid(accountJid);
    if (normalized == null) {
      return true;
    }
    final shown = await _readAccountWelcomeShown();
    return shown.contains(normalized);
  }

  Future<void> markAccountWelcomeShownFor(String? accountJid) async {
    final normalized = _normalizedAccountJid(accountJid);
    if (normalized == null) {
      return;
    }
    final shown = await _readAccountWelcomeShown();
    if (shown.contains(normalized)) {
      return;
    }
    await _writeAccountWelcomeShown({...shown, normalized});
  }

  Future<bool> emailWebViewTipShownFor(String? accountJid) async {
    final normalized = _normalizedAccountJid(accountJid);
    if (normalized == null) {
      return true;
    }
    final shown = await _readEmailWebViewTipShown();
    return shown.contains(normalized);
  }

  Future<void> markEmailWebViewTipShownFor(String? accountJid) async {
    final normalized = _normalizedAccountJid(accountJid);
    if (normalized == null) {
      return;
    }
    final shown = await _readEmailWebViewTipShown();
    if (shown.contains(normalized)) {
      return;
    }
    await _writeEmailWebViewTipShown({...shown, normalized});
  }

  Future<bool> calendarTaskDragTipShownFor(String? accountJid) async {
    final normalized = _normalizedAccountJid(accountJid);
    if (normalized == null) {
      return true;
    }
    final shown = await _readCalendarTaskDragTipShown();
    return shown.contains(normalized);
  }

  Future<void> markCalendarTaskDragTipShownFor(String? accountJid) async {
    final normalized = _normalizedAccountJid(accountJid);
    if (normalized == null) {
      return;
    }
    final shown = await _readCalendarTaskDragTipShown();
    if (shown.contains(normalized)) {
      return;
    }
    await _writeCalendarTaskDragTipShown({...shown, normalized});
  }

  bool recoveryAvailableForAccount(String? accountJid) =>
      _normalizedAxiRecoveryAccountJid(accountJid) != null;

  Future<bool> recoveryWelcomeDismissedFor(String? accountJid) async {
    final normalized = _normalizedAxiRecoveryAccountJid(accountJid);
    if (normalized == null) {
      return true;
    }
    final dismissed = await _readRecoveryWelcomeDismissals();
    return dismissed.contains(normalized);
  }

  Future<void> dismissRecoveryWelcomeFor(String? accountJid) async {
    final normalized = _normalizedAxiRecoveryAccountJid(accountJid);
    if (normalized == null) {
      return;
    }
    final dismissed = await _readRecoveryWelcomeDismissals();
    if (dismissed.contains(normalized)) {
      return;
    }
    await _writeRecoveryWelcomeDismissals({...dismissed, normalized});
  }

  Future<provisioning.RecoveryStatus?> recoveryStatus({
    required String? accountJid,
    required String password,
  }) async {
    final normalized = _normalizedAxiRecoveryAccountJid(accountJid);
    if (normalized == null) {
      return null;
    }
    if (password.trim().isEmpty) {
      return null;
    }
    _log.info(
      'Loading recovery status: '
      'accountDomain=${addressDomainPart(normalized) ?? ''}',
    );
    try {
      final status = await _recoveryClient.recoveryStatus(
        email: normalized,
        password: password,
      );
      _log.info(
        'Loaded recovery status: '
        'emailConfigured=${status.recoveryEmailConfigured} '
        'totpConfigured=${status.totpConfigured}',
      );
      return status;
    } on provisioning.EmailProvisioningApiException catch (error, stackTrace) {
      _log.warning(
        'Recovery status failed: '
        'type=${error.runtimeType} '
        'status=${error.statusCode ?? ''} '
        'recoverable=${error.isRecoverable} '
        'debug=${error.debugMessage ?? ''}',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<provisioning.RecoveryEmailChallenge?> startRecoveryEmailSetup({
    required String? accountJid,
    required String password,
    required String recoveryEmail,
  }) async {
    final normalized = _normalizedAxiRecoveryAccountJid(accountJid);
    if (normalized == null) {
      return null;
    }
    _log.info(
      'Starting recovery email setup: '
      'accountDomain=${addressDomainPart(normalized) ?? ''} '
      'recoveryEmailProvided=${recoveryEmail.trim().isNotEmpty}',
    );
    try {
      final challenge = await _recoveryClient.startRecoveryEmailSetup(
        email: normalized,
        password: password,
        recoveryEmail: recoveryEmail,
      );
      _log.info('Started recovery email setup.');
      return challenge;
    } on provisioning.EmailProvisioningApiException catch (error, stackTrace) {
      _log.warning(
        'Recovery email setup failed: '
        'type=${error.runtimeType} '
        'status=${error.statusCode ?? ''} '
        'recoverable=${error.isRecoverable} '
        'debug=${error.debugMessage ?? ''}',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<void> confirmRecoveryEmailSetup({
    required String? accountJid,
    required String password,
    required String challenge,
    required String code,
  }) async {
    final normalized = _normalizedAxiRecoveryAccountJid(accountJid);
    if (normalized == null) {
      return;
    }
    await _recoveryClient.confirmRecoveryEmailSetup(
      email: normalized,
      password: password,
      challenge: challenge,
      code: code,
    );
  }

  Future<void> removeRecoveryEmail({
    required String? accountJid,
    required String password,
  }) async {
    final normalized = _normalizedAxiRecoveryAccountJid(accountJid);
    if (normalized == null) {
      return;
    }
    await _recoveryClient.removeRecoveryEmail(
      email: normalized,
      password: password,
    );
  }

  Future<provisioning.RecoveryTotpSetup?> startRecoveryTotpSetup({
    required String? accountJid,
    required String password,
  }) async {
    final normalized = _normalizedAxiRecoveryAccountJid(accountJid);
    if (normalized == null) {
      return null;
    }
    return _recoveryClient.startRecoveryTotpSetup(
      email: normalized,
      password: password,
    );
  }

  Future<void> confirmRecoveryTotpSetup({
    required String? accountJid,
    required String password,
    required String code,
    String? challenge,
  }) async {
    final normalized = _normalizedAxiRecoveryAccountJid(accountJid);
    if (normalized == null) {
      return;
    }
    await _recoveryClient.confirmRecoveryTotpSetup(
      email: normalized,
      password: password,
      code: code,
      challenge: challenge,
    );
  }

  Future<void> removeRecoveryTotp({
    required String? accountJid,
    required String password,
  }) async {
    final normalized = _normalizedAxiRecoveryAccountJid(accountJid);
    if (normalized == null) {
      return;
    }
    await _recoveryClient.removeRecoveryTotp(
      email: normalized,
      password: password,
    );
  }

  Future<provisioning.RecoveryEmailChallenge?> startRecoveryEmailReset({
    required String? accountJid,
    required String recoveryEmail,
  }) async {
    final normalized = _normalizedAxiRecoveryAccountJid(accountJid);
    if (normalized == null) {
      return null;
    }
    return _recoveryClient.startRecoveryEmailReset(
      email: normalized,
      recoveryEmail: recoveryEmail,
    );
  }

  Future<provisioning.RecoveryResetToken?> verifyRecoveryEmailReset({
    required String? accountJid,
    required String challenge,
    required String code,
  }) async {
    final normalized = _normalizedAxiRecoveryAccountJid(accountJid);
    if (normalized == null) {
      return null;
    }
    return _recoveryClient.verifyRecoveryEmailReset(
      email: normalized,
      challenge: challenge,
      code: code,
    );
  }

  Future<provisioning.RecoveryResetToken?> verifyRecoveryTotpReset({
    required String? accountJid,
    required String code,
  }) async {
    final normalized = _normalizedAxiRecoveryAccountJid(accountJid);
    if (normalized == null) {
      return null;
    }
    return _recoveryClient.verifyRecoveryTotpReset(
      email: normalized,
      code: code,
    );
  }

  Future<void> resetPasswordWithRecovery({
    required String? accountJid,
    required String resetToken,
    required String newPassword,
  }) async {
    final normalized = _normalizedAxiRecoveryAccountJid(accountJid);
    if (normalized == null) {
      return;
    }
    await _recoveryClient.resetPasswordWithRecovery(
      email: normalized,
      resetToken: resetToken,
      newPassword: newPassword,
    );
  }

  Future<void> toggleLowMotion(bool lowMotion) async {
    await _emitLocalSettingsState(
      state.copyWith(lowMotion: lowMotion),
      changedSettingIds: const {GlobalSettingId.lowMotion},
    );
  }

  Future<void> toggleIndicateTyping(bool indicateTyping) async {
    await _emitLocalSettingsState(
      state.copyWith(indicateTyping: indicateTyping),
      changedSettingIds: const {GlobalSettingId.typingIndicators},
    );
  }

  Future<void> toggleShareTokenSignature(bool enabled) async {
    await _emitLocalSettingsState(
      state.copyWith(shareTokenSignatureEnabled: enabled),
      changedSettingIds: const {GlobalSettingId.shareSignature},
    );
  }

  Future<void> toggleEmailComposerWatermark(bool enabled) async {
    await _emitLocalSettingsState(
      state.copyWith(emailComposerWatermarkEnabled: enabled),
      changedSettingIds: const {GlobalSettingId.emailComposerWatermark},
    );
  }

  Future<void> setEmailEncryptionBetaEnabled(
    String address,
    bool enabled,
  ) async {
    final normalized = normalizedAddressValue(address);
    if (normalized == null ||
        normalized.isEmpty ||
        !normalized.isValidEmailAddress) {
      throw ArgumentError.value(
        address,
        'address',
        'Expected a valid email address.',
      );
    }
    final nextMap = Map<String, bool>.from(
      state.emailEncryptionBetaEnabledByAddress,
    );
    if (enabled) {
      nextMap[normalized] = true;
    } else {
      nextMap.remove(normalized);
    }
    await _emitLocalSettingsState(
      state.copyWith(emailEncryptionBetaEnabledByAddress: nextMap),
      changedSettingIds: const {GlobalSettingId.emailEncryptionBeta},
    );
  }

  void trackDonationPromptMessageCount({
    required String? accountJid,
    required int storedConversationMessageCount,
  }) {
    final syncedState = state.syncDonationPromptMessageCount(
      accountJid: accountJid,
      storedConversationMessageCount: storedConversationMessageCount,
    );
    if (syncedState == state) {
      return;
    }
    unawaited(
      _emitLocalSettingsState(
        syncedState,
        changedSettingIds: const {GlobalSettingId.donationPromptTracking},
      ),
    );
  }

  void hideDonationPrompt({
    required String? accountJid,
    required int storedConversationMessageCount,
  }) {
    final syncedState = state.syncDonationPromptMessageCount(
      accountJid: accountJid,
      storedConversationMessageCount: storedConversationMessageCount,
    );
    final nextState = syncedState.copyWith(
      donationPromptNextDisplayMessageCount:
          syncedState.donationPromptTrackedMessageCount + 500,
    );
    if (nextState == state) {
      return;
    }
    unawaited(
      _emitLocalSettingsState(
        nextState,
        changedSettingIds: const {GlobalSettingId.donationPromptTracking},
      ),
    );
  }

  Future<void> toggleHideCompletedScheduled(bool hide) async {
    await _emitLocalSettingsState(
      state.copyWith(hideCompletedScheduled: hide),
      changedSettingIds: const {GlobalSettingId.hideCompletedScheduled},
    );
  }

  Future<void> toggleHideCompletedUnscheduled(bool hide) async {
    await _emitLocalSettingsState(
      state.copyWith(hideCompletedUnscheduled: hide),
      changedSettingIds: const {GlobalSettingId.hideCompletedUnscheduled},
    );
  }

  Future<void> toggleHideCompletedReminders(bool hide) async {
    await _emitLocalSettingsState(
      state.copyWith(hideCompletedReminders: hide),
      changedSettingIds: const {GlobalSettingId.hideCompletedReminders},
    );
  }

  Future<void> saveUnscheduledSidebarOrder(List<String> order) async {
    await _emitLocalSettingsState(
      state.copyWith(unscheduledSidebarOrder: List<String>.from(order)),
      changedSettingIds: const {GlobalSettingId.unscheduledSidebarOrder},
    );
  }

  Future<void> saveReminderSidebarOrder(List<String> order) async {
    await _emitLocalSettingsState(
      state.copyWith(reminderSidebarOrder: List<String>.from(order)),
      changedSettingIds: const {GlobalSettingId.reminderSidebarOrder},
    );
  }

  Future<void> updateCalendarTaskListSortMode(
    CalendarTaskListSortMode mode,
  ) async {
    await _emitLocalSettingsState(
      state.copyWith(calendarTaskListSortMode: mode),
      changedSettingIds: const {GlobalSettingId.calendarTaskListSortMode},
    );
  }

  Future<void> updateMessageTextSize(MessageTextSize messageTextSize) async {
    await _emitLocalSettingsState(
      state.copyWith(messageTextSize: messageTextSize),
      changedSettingIds: const {GlobalSettingId.messageTextSize},
    );
  }

  Future<void> toggleAutoLoadEmailImages(bool enabled) async {
    await _emitLocalSettingsState(
      state.copyWith(autoLoadEmailImages: enabled),
      changedSettingIds: const {GlobalSettingId.emailImageAutoload},
    );
  }

  void primeAttachmentAutoDownloadSettings() {
    unawaited(
      setAttachmentAutoDownloadSettings(
        imagesEnabled: state.autoDownloadImages,
        videosEnabled: state.autoDownloadVideos,
        documentsEnabled: state.autoDownloadDocuments,
        archivesEnabled: state.autoDownloadArchives,
        force: true,
      ),
    );
  }

  Future<void> setAttachmentAutoDownloadSettings({
    required bool imagesEnabled,
    required bool videosEnabled,
    required bool documentsEnabled,
    required bool archivesEnabled,
    bool force = false,
  }) async {
    if (!force &&
        state.autoDownloadImages == imagesEnabled &&
        state.autoDownloadVideos == videosEnabled &&
        state.autoDownloadDocuments == documentsEnabled &&
        state.autoDownloadArchives == archivesEnabled) {
      return;
    }
    final nextState = state.copyWith(
      autoDownloadImages: imagesEnabled,
      autoDownloadVideos: videosEnabled,
      autoDownloadDocuments: documentsEnabled,
      autoDownloadArchives: archivesEnabled,
    );
    await _emitLocalSettingsState(
      nextState,
      changedSettingIds: const {
        GlobalSettingId.attachmentAutoDownloadImages,
        GlobalSettingId.attachmentAutoDownloadVideos,
        GlobalSettingId.attachmentAutoDownloadDocuments,
        GlobalSettingId.attachmentAutoDownloadArchives,
      },
    );
  }

  Future<void> retrySettingsSync() async {
    final service = _xmppService;
    if (service == null || _activeAccountKey == null) {
      return;
    }
    final changedSettingIds = state.unsyncedGlobalSettingIds.toSet();
    if (changedSettingIds.isEmpty) {
      return;
    }
    await _publishSettingsSnapshot(
      service: service,
      snapshot: state.syncedSettingsJson,
      changedSettingIds: changedSettingIds,
    );
  }

  Future<void> retryGlobalSettingSync(GlobalSettingId settingId) async {
    if (!state.isGlobalSettingNotSynced(settingId)) {
      return;
    }
    await retrySettingsSync();
  }

  Future<void> _emitLocalSettingsState(
    SettingsState nextState, {
    Iterable<GlobalSettingId> changedSettingIds = const {},
  }) async {
    final changedSettingIdsSet = changedSettingIds.toSet();
    nextState = _scopeNextState(nextState, changedSettingIdsSet);
    if (nextState == state) {
      return;
    }
    final previousState = state;
    final service = _xmppService;
    final changedSyncedSettingIds = previousState
        .changedGlobalSettingIds(nextState, hints: changedSettingIds)
        .where((settingId) => settingId.isSynced)
        .toSet();
    final shouldPublish =
        _activeAccountKey != null &&
        !const DeepCollectionEquality().equals(
          previousState.syncedSettingsJson,
          nextState.syncedSettingsJson,
        );
    final emittedState = service == null || !shouldPublish
        ? nextState
        : nextState.markGlobalSettingsLoading(
            changedSyncedSettingIds,
            confirmedBaseline: previousState.settingsSyncHasConfirmedSnapshot
                ? null
                : previousState.syncedSettingsJson,
          );
    emit(emittedState);
    _persistVisibleState(emittedState);
    _applySettingsSideEffects(emittedState);
    if (!shouldPublish) {
      return;
    }
    if (service == null) {
      return;
    }
    await _publishSettingsSnapshot(
      service: service,
      snapshot: nextState.syncedSettingsJson,
      changedSettingIds: changedSyncedSettingIds,
    );
  }

  Future<void> _publishSettingsSnapshot({
    required XmppService service,
    required Map<String, dynamic> snapshot,
    required Set<GlobalSettingId> changedSettingIds,
  }) async {
    final publishingAccountKey = _activeAccountKey;
    if (publishingAccountKey == null) {
      return;
    }
    if (changedSettingIds.isEmpty) {
      return;
    }
    emit(state.markGlobalSettingsLoading(changedSettingIds));
    final published = await service.updateSettingsSyncSnapshot(snapshot);
    if (_activeAccountKey != publishingAccountKey) {
      return;
    }
    final currentState = state;
    final stillCurrentSettingIds = changedSettingIds
        .where(
          (settingId) => const DeepCollectionEquality().equals(
            currentState.syncedSettingsJson[settingId.jsonKey],
            snapshot[settingId.jsonKey],
          ),
        )
        .toSet();
    if (stillCurrentSettingIds.isEmpty) {
      if (published) {
        emit(
          currentState.copyWith(
            settingsSyncHasConfirmedSnapshot: true,
            settingsSyncConfirmedJson: snapshot,
          ),
        );
      }
      return;
    }
    emit(
      currentState.clearGlobalSettingsLoading(
        stillCurrentSettingIds,
        confirmedSnapshot: published ? snapshot : null,
      ),
    );
  }

  void _handleRemoteSettingsSync(Map<String, dynamic> syncedSettings) {
    final eventAccountKey = _accountKeyForJid(_xmppService?.myJid);
    if (_activeAccountKey == null) {
      if (eventAccountKey != null) {
        _pendingRemoteSettingsSyncByKey[eventAccountKey] =
            Map<String, dynamic>.from(syncedSettings);
      }
      return;
    }
    if (eventAccountKey != null && eventAccountKey != _activeAccountKey) {
      _pendingRemoteSettingsSyncByKey[eventAccountKey] =
          Map<String, dynamic>.from(syncedSettings);
      return;
    }
    final nextState = state
        .mergeSyncedSettingsJson(syncedSettings)
        .clearGlobalSettingsLoading(
          GlobalSettingId.syncedSettings,
          confirmedSnapshot: syncedSettings,
        );
    if (nextState == state) {
      return;
    }
    emit(nextState);
    _persistVisibleState(nextState);
    _applySettingsSideEffects(nextState);
  }

  void _applySettingsSideEffects(SettingsState nextState) {
    _applyAttachmentAutoDownloadSettings(nextState);
    _applyForegroundNotificationSettings(nextState);
  }

  void _applyAttachmentAutoDownloadSettings(SettingsState nextState) {
    _xmppService?.updateAttachmentAutoDownloadSettings(
      imagesEnabled: nextState.autoDownloadImages,
      videosEnabled: nextState.autoDownloadVideos,
      documentsEnabled: nextState.autoDownloadDocuments,
      archivesEnabled: nextState.autoDownloadArchives,
    );
  }

  void _applyForegroundNotificationSettings(SettingsState nextState) {
    _xmppService?.updateForegroundNotificationSettings(
      backgroundMessageNotificationsEnabled: _messageNotificationsEnabledFor(
        nextState,
      ),
      chatNotificationsMuted: nextState.chatNotificationsMuted,
      emailNotificationsMuted: nextState.emailNotificationsMuted,
      notificationPreviewsEnabled: nextState.notificationPreviewsEnabled,
    );
  }

  bool _messageNotificationsEnabledFor(SettingsState state) {
    return _capability?.canBackgroundMessaging != true ||
        state.backgroundMessagingEnabled;
  }

  SettingsState _scopeNextState(
    SettingsState nextState,
    Set<GlobalSettingId> changedSettingIds,
  ) {
    if (changedSettingIds.contains(GlobalSettingId.endpointConfig)) {
      _bootstrapState = _bootstrapState.copyWith(
        endpointConfig: nextState.endpointConfig,
      );
    }
    if (_activeAccountKey != null) {
      return _withBootstrapEndpoint(nextState);
    }
    return _bootstrapStateFrom(nextState);
  }

  SettingsState _bootstrapStateFrom(SettingsState state) {
    return SettingsState(
      language: state.language,
      themeMode: state.themeMode,
      shadColor: state.shadColor,
      endpointConfig: state.endpointConfig,
      lowMotion: state.lowMotion,
    );
  }

  SettingsState _newAccountSettingsState() {
    final defaults = _initialStateFor(_capability);
    return defaults.copyWith(
      language: _bootstrapState.language,
      themeMode: _bootstrapState.themeMode,
      shadColor: _bootstrapState.shadColor,
      endpointConfig: _bootstrapState.endpointConfig,
      lowMotion: _bootstrapState.lowMotion,
    );
  }

  SettingsState _withBootstrapEndpoint(SettingsState state) {
    if (state.endpointConfig == _bootstrapState.endpointConfig) {
      return state;
    }
    return state.copyWith(endpointConfig: _bootstrapState.endpointConfig);
  }

  void _persistVisibleState(SettingsState visibleState) {
    final accountKey = _activeAccountKey;
    if (accountKey == null) {
      _bootstrapState = _bootstrapStateFrom(visibleState);
      return;
    }
    _accountSettingsJsonByKey[accountKey] = _accountJsonFromState(
      _withBootstrapEndpoint(visibleState),
    );
  }

  Map<String, dynamic> _accountJsonFromState(SettingsState state) {
    return Map<String, dynamic>.from(state.toJson())
      ..remove(_endpointConfigJsonKey);
  }

  Map<String, dynamic> _bootstrapJsonFromState(SettingsState state) {
    return _bootstrapStateFrom(state).toJson();
  }

  SettingsState _accountStateFromJson(Map<String, dynamic> json) {
    return _withBootstrapEndpoint(_settingsStateFromStoredJson(json));
  }

  Future<void> _seedSettingsSyncSnapshotIfActive() async {
    final service = _xmppService;
    if (service == null || _activeAccountKey == null) {
      return;
    }
    try {
      await service.seedSettingsSyncSnapshot(state.syncedSettingsJson);
    } on Exception catch (error, stackTrace) {
      _log.fine(
        'Failed to seed settings sync snapshot for active account.',
        error,
        stackTrace,
      );
    }
  }

  String? _accountKeyForJid(String? accountJid) {
    final normalized = _normalizedAccountJid(accountJid);
    if (normalized == null) {
      return null;
    }
    return crypto.sha256.convert(utf8.encode(normalized)).toString();
  }

  String? _normalizedAccountJid(String? accountJid) {
    final normalized = normalizedAddressValue(accountJid);
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String? _normalizedAxiAccountJid(String? accountJid) {
    final normalized = _normalizedAccountJid(accountJid);
    if (normalized == null || !isAxiJid(normalized)) {
      return null;
    }
    return normalized;
  }

  String? _normalizedAxiRecoveryAccountJid(String? accountJid) {
    if (!state.endpointConfig.isAxiImDomain) {
      return null;
    }
    return _normalizedAxiAccountJid(accountJid);
  }

  Future<Set<String>> _readRecoveryWelcomeDismissals() async {
    return _readDismissedAccounts(_recoveryWelcomeDismissedKey);
  }

  Future<Set<String>> _readAccountWelcomeShown() async {
    return _readDismissedAccounts(_accountWelcomeShownKey);
  }

  Future<Set<String>> _readEmailWebViewTipShown() async {
    return _readDismissedAccounts(_emailWebViewTipShownKey);
  }

  Future<Set<String>> _readCalendarTaskDragTipShown() async {
    return _readDismissedAccounts(_calendarTaskDragTipShownKey);
  }

  Future<void> _writeAccountWelcomeShown(Set<String> shownAccounts) async {
    await _writeDismissedAccounts(
      key: _accountWelcomeShownKey,
      dismissedAccounts: shownAccounts,
    );
  }

  Future<void> _writeEmailWebViewTipShown(Set<String> shownAccounts) async {
    await _writeDismissedAccounts(
      key: _emailWebViewTipShownKey,
      dismissedAccounts: shownAccounts,
    );
  }

  Future<void> _writeCalendarTaskDragTipShown(Set<String> shownAccounts) async {
    await _writeDismissedAccounts(
      key: _calendarTaskDragTipShownKey,
      dismissedAccounts: shownAccounts,
    );
  }

  Future<void> _writeRecoveryWelcomeDismissals(
    Set<String> dismissedAccounts,
  ) async {
    await _writeDismissedAccounts(
      key: _recoveryWelcomeDismissedKey,
      dismissedAccounts: dismissedAccounts,
    );
  }

  Future<Set<String>> _readDismissedAccounts(
    RegisteredCredentialKey key,
  ) async {
    final credentialStore = _credentialStore;
    if (credentialStore == null) {
      return const {};
    }
    final serialized = await credentialStore.read(key: key);
    if (serialized == null || serialized.trim().isEmpty) {
      return const {};
    }
    try {
      final decoded = jsonDecode(serialized);
      if (decoded is! Map<String, dynamic>) {
        await credentialStore.delete(key: key);
        return const {};
      }
      return decoded.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key.trim().toLowerCase())
          .where((entry) => entry.isNotEmpty)
          .toSet();
    } on FormatException {
      await credentialStore.delete(key: key);
      return const {};
    }
  }

  Future<void> _writeDismissedAccounts({
    required RegisteredCredentialKey key,
    required Set<String> dismissedAccounts,
  }) async {
    final credentialStore = _credentialStore;
    if (credentialStore == null) {
      return;
    }
    final values = <String, bool>{
      for (final account in dismissedAccounts)
        if (account.trim().isNotEmpty) account.trim().toLowerCase(): true,
    };
    if (values.isEmpty) {
      await credentialStore.delete(key: key);
      return;
    }
    await credentialStore.write(key: key, value: jsonEncode(values));
  }

  Future<String?> _readStoredLoginJid() async {
    final credentialStore = _credentialStore;
    if (credentialStore == null) {
      return null;
    }
    final storedJid = await credentialStore.read(key: _storedLoginJidKey);
    return _normalizedAccountJid(storedJid);
  }

  Future<Map<String, dynamic>?> _legacyAccountSettingsJsonFor(
    String? accountJid,
  ) async {
    final legacyJson = await _matchingLegacyAccountSettingsJsonFor(accountJid);
    if (legacyJson == null) {
      return null;
    }
    _legacyAccountSettingsJson = null;
    return legacyJson;
  }

  Future<Map<String, dynamic>?> _matchingLegacyAccountSettingsJsonFor(
    String? accountJid,
  ) async {
    final legacyJson = _legacyAccountSettingsJson;
    if (legacyJson == null) {
      return null;
    }
    final normalizedAccountJid = _normalizedAccountJid(accountJid);
    if (normalizedAccountJid == null) {
      return null;
    }
    if (await _initialStoredLoginJid != normalizedAccountJid) {
      return null;
    }
    return Map<String, dynamic>.from(legacyJson);
  }

  Future<bool?> _legacyBackgroundMessagingPreference(String? accountJid) async {
    final normalizedAccountJid = _normalizedAccountJid(accountJid);
    if (normalizedAccountJid == null) {
      return null;
    }
    final preferences = await _readBackgroundMessagingPreferences();
    return preferences[normalizedAccountJid];
  }

  Future<Map<String, bool>> _readBackgroundMessagingPreferences() async {
    final credentialStore = _credentialStore;
    if (credentialStore == null) {
      return const {};
    }
    final serialized = await credentialStore.read(
      key: _backgroundMessagingPreferencesKey,
    );
    if (serialized == null || serialized.trim().isEmpty) {
      return const {};
    }
    try {
      final decoded = jsonDecode(serialized);
      if (decoded is! Map<String, dynamic>) {
        await credentialStore.delete(key: _backgroundMessagingPreferencesKey);
        return const {};
      }
      final preferences = <String, bool>{};
      for (final entry in decoded.entries) {
        final key = entry.key.trim().toLowerCase();
        final value = entry.value;
        if (key.isNotEmpty && value is bool) {
          preferences[key] = value;
        }
      }
      return preferences;
    } on FormatException {
      await credentialStore.delete(key: _backgroundMessagingPreferencesKey);
      return const {};
    }
  }

  @override
  Future<void> close() async {
    await _settingsSyncSubscription?.cancel();
    _settingsSyncSubscription = null;
    if (_ownsRecoveryClient) {
      _recoveryClient.close();
    }
    return super.close();
  }

  @override
  SettingsState? fromJson(Map<String, dynamic> json) {
    try {
      if (json.containsKey(_settingsEnvelopeBootstrapKey) ||
          json.containsKey(_settingsEnvelopeAccountsKey)) {
        return _fromEnvelopeJson(json);
      }
      final legacyState = _settingsStateFromStoredJson(json);
      _bootstrapState = _bootstrapStateFrom(legacyState);
      _accountSettingsJsonByKey.clear();
      _pendingRemoteSettingsSyncByKey.clear();
      _legacyAccountSettingsJson = _accountJsonFromState(legacyState);
      _activeAccountKey = null;
      return _bootstrapState;
    } catch (_) {
      _bootstrapState = _initialStateFor(
        _capability,
      ).copyWith(themeMode: ThemeMode.light, shadColor: ShadColor.neutral);
      _accountSettingsJsonByKey.clear();
      _pendingRemoteSettingsSyncByKey.clear();
      _legacyAccountSettingsJson = null;
      _activeAccountKey = null;
      return _bootstrapState;
    }
  }

  SettingsState _fromEnvelopeJson(Map<String, dynamic> json) {
    final bootstrapJson = _mapFromJsonObject(
      json[_settingsEnvelopeBootstrapKey],
    );
    _bootstrapState = _bootstrapStateFrom(
      _settingsStateFromStoredJson(bootstrapJson),
    );
    _accountSettingsJsonByKey
      ..clear()
      ..addAll(_accountsFromJson(json[_settingsEnvelopeAccountsKey]));
    _pendingRemoteSettingsSyncByKey.clear();
    _legacyAccountSettingsJson = null;
    _activeAccountKey = null;
    return _bootstrapState;
  }

  Map<String, Map<String, dynamic>> _accountsFromJson(Object? value) {
    if (value is! Map) {
      return const {};
    }
    final accounts = <String, Map<String, dynamic>>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String || key.trim().isEmpty) {
        continue;
      }
      final accountJson = _mapFromJsonObject(entry.value);
      if (accountJson.isNotEmpty) {
        accounts[key] = accountJson;
      }
    }
    return accounts;
  }

  Map<String, dynamic> _mapFromJsonObject(Object? value) {
    if (value is! Map) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{
      for (final entry in value.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
  }

  SettingsState _settingsStateFromStoredJson(Map<String, dynamic> json) {
    try {
      final migrated = Map<String, dynamic>.from(json);
      const keyMap = <String, String>{
        'themeMode': 'theme_mode',
        'shadColor': 'shad_color',
        'backgroundMessagingEnabled': 'background_messaging_enabled',
        'chatNotificationsMuted': 'chat_notifications_muted',
        'emailNotificationsMuted': 'email_notifications_muted',
        'notificationPreviewsEnabled': 'notification_previews_enabled',
        'chatReadReceipts': 'chat_read_receipts',
        'emailReadReceipts': 'email_read_receipts',
        'chatSendOnEnter': 'chat_send_on_enter',
        'emailSendOnEnter': 'email_send_on_enter',
        'emailSendConfirmationEnabled': 'email_send_confirmation_enabled',
        'indicateTyping': 'indicate_typing',
        'lowMotion': 'low_motion',
        'colorfulAvatars': 'colorful_avatars',
        'shareTokenSignatureEnabled': 'share_token_signature_enabled',
        'emailComposerWatermarkEnabled': 'email_composer_watermark_enabled',
        'hideCompletedScheduled': 'hide_completed_scheduled',
        'hideCompletedUnscheduled': 'hide_completed_unscheduled',
        'hideCompletedReminders': 'hide_completed_reminders',
        'unscheduledSidebarOrder': 'unscheduled_sidebar_order',
        'reminderSidebarOrder': 'reminder_sidebar_order',
        'calendarTaskListSortMode': 'calendar_task_list_sort_mode',
        'messageTextSize': 'message_text_size',
        'autoLoadEmailImages': 'auto_load_email_images',
        'donationPromptNextDisplayMessageCount':
            'donation_prompt_next_display_message_count',
        'donationPromptTrackedMessageCount':
            'donation_prompt_tracked_message_count',
        'donationPromptLastObservedStoredMessageCount':
            'donation_prompt_last_observed_stored_message_count',
        'autoDownloadImages': 'auto_download_images',
        'autoDownloadVideos': 'auto_download_videos',
        'autoDownloadDocuments': 'auto_download_documents',
        'autoDownloadArchives': 'auto_download_archives',
      };
      for (final entry in keyMap.entries) {
        if (migrated.containsKey(entry.key) &&
            !migrated.containsKey(entry.value)) {
          migrated[entry.value] = migrated[entry.key];
        }
      }
      if (migrated.containsKey('attachment_auto_download_settings')) {
        const defaultState = SettingsState();
        final settings = migrated['attachment_auto_download_settings'];
        final Map<dynamic, dynamic> parsed = settings is Map
            ? settings
            : const {};
        final imagesValue = parsed['images_enabled'];
        final videosValue = parsed['videos_enabled'];
        final documentsValue = parsed['documents_enabled'];
        final archivesValue = parsed['archives_enabled'];
        migrated['auto_download_images'] = imagesValue is bool
            ? imagesValue
            : defaultState.autoDownloadImages;
        migrated['auto_download_videos'] = videosValue is bool
            ? videosValue
            : defaultState.autoDownloadVideos;
        migrated['auto_download_documents'] = documentsValue is bool
            ? documentsValue
            : defaultState.autoDownloadDocuments;
        migrated['auto_download_archives'] = archivesValue is bool
            ? archivesValue
            : defaultState.autoDownloadArchives;
      }
      if (!migrated.containsKey('chat_read_receipts')) {
        if (migrated.containsKey('read_receipts')) {
          migrated['chat_read_receipts'] = migrated['read_receipts'];
        } else if (migrated.containsKey('readReceipts')) {
          migrated['chat_read_receipts'] = migrated['readReceipts'];
        }
      }
      if (!migrated.containsKey('chat_notifications_muted') ||
          !migrated.containsKey('email_notifications_muted')) {
        final muteValue = migrated['mute'];
        if (muteValue is bool) {
          migrated.putIfAbsent('chat_notifications_muted', () => muteValue);
          migrated.putIfAbsent('email_notifications_muted', () => muteValue);
        }
      }
      migrated.putIfAbsent(
        'background_messaging_enabled',
        () => _defaultBackgroundMessagingEnabled,
      );
      return SettingsState.fromJson(migrated);
    } catch (_) {
      return _initialStateFor(
        _capability,
      ).copyWith(themeMode: ThemeMode.light, shadColor: ShadColor.neutral);
    }
  }

  @override
  Map<String, dynamic>? toJson(SettingsState state) {
    _persistVisibleState(state);
    return <String, dynamic>{
      _settingsEnvelopeVersionKey: _settingsEnvelopeVersion,
      _settingsEnvelopeBootstrapKey: _bootstrapJsonFromState(_bootstrapState),
      _settingsEnvelopeAccountsKey: <String, Map<String, dynamic>>{
        for (final entry in _accountSettingsJsonByKey.entries)
          entry.key: Map<String, dynamic>.from(entry.value),
      },
    };
  }
}
