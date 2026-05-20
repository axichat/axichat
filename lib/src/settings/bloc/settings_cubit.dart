// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/app_language.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

part 'settings_cubit.freezed.dart';
part 'settings_cubit.g.dart';
part 'settings_state.dart';

class SettingsCubit extends HydratedCubit<SettingsState> {
  SettingsCubit({XmppService? xmppService, Capability? capability})
    : _xmppService = xmppService,
      _capability = capability,
      super(const SettingsState()) {
    _applyAttachmentAutoDownloadSettings(state);
    final service = _xmppService;
    if (service != null) {
      _settingsSyncSubscription = service.settingsSyncUpdateStream.listen(
        _handleRemoteSettingsSync,
      );
      unawaited(service.seedSettingsSyncSnapshot(state.syncedSettingsJson));
    }
  }

  final XmppService? _xmppService;
  final Capability? _capability;
  StreamSubscription<Map<String, dynamic>>? _settingsSyncSubscription;

  bool get canForegroundService => _capability?.canForegroundService ?? false;

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

  Future<void> toggleBackgroundMessaging(bool enabled) async {
    await _emitLocalSettingsState(
      state.copyWith(backgroundMessagingEnabled: enabled),
      changedSettingIds: const {GlobalSettingId.backgroundMessaging},
    );
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
    _applyAttachmentAutoDownloadSettings(nextState);
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
    if (service == null) {
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
    if (nextState == state) {
      return;
    }
    final previousState = state;
    final service = _xmppService;
    final changedSyncedSettingIds = previousState
        .changedGlobalSettingIds(nextState, hints: changedSettingIds)
        .where((settingId) => settingId.isSynced)
        .toSet();
    final shouldPublish = !const DeepCollectionEquality().equals(
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
    if (changedSettingIds.isEmpty) {
      return;
    }
    emit(state.markGlobalSettingsLoading(changedSettingIds));
    final published = await service.updateSettingsSyncSnapshot(snapshot);
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
    _applyAttachmentAutoDownloadSettings(nextState);
  }

  void _applyAttachmentAutoDownloadSettings(SettingsState nextState) {
    _xmppService?.updateAttachmentAutoDownloadSettings(
      imagesEnabled: nextState.autoDownloadImages,
      videosEnabled: nextState.autoDownloadVideos,
      documentsEnabled: nextState.autoDownloadDocuments,
      archivesEnabled: nextState.autoDownloadArchives,
    );
  }

  @override
  Future<void> close() async {
    await _settingsSyncSubscription?.cancel();
    _settingsSyncSubscription = null;
    return super.close();
  }

  @override
  SettingsState? fromJson(Map<String, dynamic> json) {
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
      return SettingsState.fromJson(migrated);
    } catch (_) {
      return const SettingsState(
        themeMode: ThemeMode.light,
        shadColor: ShadColor.neutral,
      );
    }
  }

  @override
  Map<String, dynamic>? toJson(SettingsState state) => state.toJson();
}
