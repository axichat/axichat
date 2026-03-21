// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/ui/ui.dart';
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

  void updateLanguage(AppLanguage language) {
    _emitLocalSettingsState(state.copyWith(language: language));
  }

  void updateThemeMode(ThemeMode? themeMode) {
    if (themeMode == null) return;
    _emitLocalSettingsState(state.copyWith(themeMode: themeMode));
  }

  void updateColorScheme(ShadColor? shadColor) {
    if (shadColor == null) return;
    _emitLocalSettingsState(state.copyWith(shadColor: shadColor));
  }

  void updateEndpointConfig(EndpointConfig config) {
    _emitLocalSettingsState(state.copyWith(endpointConfig: config));
  }

  void resetEndpointConfig() {
    updateEndpointConfig(const EndpointConfig());
  }

  void toggleBackgroundMessaging(bool enabled) {
    _emitLocalSettingsState(
      state.copyWith(backgroundMessagingEnabled: enabled),
    );
  }

  void toggleChatNotificationsMuted(bool muted) {
    _emitLocalSettingsState(state.copyWith(chatNotificationsMuted: muted));
  }

  void toggleEmailNotificationsMuted(bool muted) {
    _emitLocalSettingsState(state.copyWith(emailNotificationsMuted: muted));
  }

  void toggleNotificationPreviews(bool enabled) {
    _emitLocalSettingsState(
      state.copyWith(notificationPreviewsEnabled: enabled),
    );
  }

  void toggleChatReadReceipts(bool enabled) {
    _emitLocalSettingsState(state.copyWith(chatReadReceipts: enabled));
  }

  void toggleEmailReadReceipts(bool enabled) {
    _emitLocalSettingsState(state.copyWith(emailReadReceipts: enabled));
  }

  void toggleChatSendOnEnter(bool enabled) {
    _emitLocalSettingsState(state.copyWith(chatSendOnEnter: enabled));
  }

  void toggleEmailSendOnEnter(bool enabled) {
    _emitLocalSettingsState(state.copyWith(emailSendOnEnter: enabled));
  }

  void toggleEmailSendConfirmation(bool enabled) {
    _emitLocalSettingsState(
      state.copyWith(emailSendConfirmationEnabled: enabled),
    );
  }

  void toggleColorfulAvatars(bool colorfulAvatars) {
    _emitLocalSettingsState(state.copyWith(colorfulAvatars: colorfulAvatars));
  }

  void markEmailForwardingGuideSeen() {
    if (state.emailForwardingGuideSeen) {
      return;
    }
    _emitLocalSettingsState(state.copyWith(emailForwardingGuideSeen: true));
  }

  void toggleLowMotion(bool lowMotion) {
    _emitLocalSettingsState(state.copyWith(lowMotion: lowMotion));
  }

  void toggleIndicateTyping(bool indicateTyping) {
    _emitLocalSettingsState(state.copyWith(indicateTyping: indicateTyping));
  }

  void toggleShareTokenSignature(bool enabled) {
    _emitLocalSettingsState(
      state.copyWith(shareTokenSignatureEnabled: enabled),
    );
  }

  void toggleEmailComposerWatermark(bool enabled) {
    _emitLocalSettingsState(
      state.copyWith(emailComposerWatermarkEnabled: enabled),
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
    _emitLocalSettingsState(syncedState);
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
    _emitLocalSettingsState(nextState);
  }

  void toggleHideCompletedScheduled(bool hide) {
    _emitLocalSettingsState(state.copyWith(hideCompletedScheduled: hide));
  }

  void toggleHideCompletedUnscheduled(bool hide) {
    _emitLocalSettingsState(state.copyWith(hideCompletedUnscheduled: hide));
  }

  void toggleHideCompletedReminders(bool hide) {
    _emitLocalSettingsState(state.copyWith(hideCompletedReminders: hide));
  }

  void saveUnscheduledSidebarOrder(List<String> order) {
    _emitLocalSettingsState(
      state.copyWith(unscheduledSidebarOrder: List<String>.from(order)),
    );
  }

  void saveReminderSidebarOrder(List<String> order) {
    _emitLocalSettingsState(
      state.copyWith(reminderSidebarOrder: List<String>.from(order)),
    );
  }

  void updateMessageTextSize(MessageTextSize messageTextSize) {
    _emitLocalSettingsState(state.copyWith(messageTextSize: messageTextSize));
  }

  void toggleAutoLoadEmailImages(bool enabled) {
    _emitLocalSettingsState(state.copyWith(autoLoadEmailImages: enabled));
  }

  void primeAttachmentAutoDownloadSettings() {
    setAttachmentAutoDownloadSettings(
      imagesEnabled: state.autoDownloadImages,
      videosEnabled: state.autoDownloadVideos,
      documentsEnabled: state.autoDownloadDocuments,
      archivesEnabled: state.autoDownloadArchives,
      force: true,
    );
  }

  void setAttachmentAutoDownloadSettings({
    required bool imagesEnabled,
    required bool videosEnabled,
    required bool documentsEnabled,
    required bool archivesEnabled,
    bool force = false,
  }) {
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
    _emitLocalSettingsState(nextState);
    _applyAttachmentAutoDownloadSettings(nextState);
  }

  void _emitLocalSettingsState(SettingsState nextState) {
    if (nextState == state) {
      return;
    }
    final previousState = state;
    emit(nextState);
    if (const DeepCollectionEquality().equals(
      previousState.syncedSettingsJson,
      nextState.syncedSettingsJson,
    )) {
      return;
    }
    final service = _xmppService;
    if (service == null) {
      return;
    }
    unawaited(service.updateSettingsSyncSnapshot(nextState.syncedSettingsJson));
  }

  void _handleRemoteSettingsSync(Map<String, dynamic> syncedSettings) {
    final nextState = state.mergeSyncedSettingsJson(syncedSettings);
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
