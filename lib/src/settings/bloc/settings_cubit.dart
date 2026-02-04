// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/common/endpoint_config.dart';
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
        super(const SettingsState());

  final XmppService? _xmppService;
  final Capability? _capability;

  bool get canForegroundService => _capability?.canForegroundService ?? false;

  Duration get animationDuration =>
      state.lowMotion ? Duration.zero : baseAnimationDuration;

  Duration get authCompletionDuration =>
      state.lowMotion ? baseAnimationDuration : authCompletionAnimationDuration;

  void updateLanguage(AppLanguage language) {
    emit(state.copyWith(language: language));
  }

  void updateThemeMode(ThemeMode? themeMode) {
    if (themeMode == null) return;
    emit(state.copyWith(themeMode: themeMode));
  }

  void updateColorScheme(ShadColor? shadColor) {
    if (shadColor == null) return;
    emit(state.copyWith(shadColor: shadColor));
  }

  void updateEndpointConfig(EndpointConfig config) {
    emit(state.copyWith(endpointConfig: config));
  }

  void resetEndpointConfig() {
    updateEndpointConfig(const EndpointConfig());
  }

  void toggleMute(bool mute) {
    emit(state.copyWith(mute: mute));
  }

  void toggleNotificationPreviews(bool enabled) {
    emit(state.copyWith(notificationPreviewsEnabled: enabled));
  }

  void toggleChatReadReceipts(bool enabled) {
    emit(state.copyWith(chatReadReceipts: enabled));
  }

  void toggleEmailReadReceipts(bool enabled) {
    emit(state.copyWith(emailReadReceipts: enabled));
  }

  void toggleColorfulAvatars(bool colorfulAvatars) {
    emit(state.copyWith(colorfulAvatars: colorfulAvatars));
  }

  void markEmailForwardingGuideSeen() {
    if (state.emailForwardingGuideSeen) {
      return;
    }
    emit(state.copyWith(emailForwardingGuideSeen: true));
  }

  void toggleLowMotion(bool lowMotion) {
    emit(state.copyWith(lowMotion: lowMotion));
  }

  void toggleIndicateTyping(bool indicateTyping) {
    emit(state.copyWith(indicateTyping: indicateTyping));
  }

  void toggleShareTokenSignature(bool enabled) {
    emit(state.copyWith(shareTokenSignatureEnabled: enabled));
  }

  void toggleHideCompletedScheduled(bool hide) {
    emit(state.copyWith(hideCompletedScheduled: hide));
  }

  void toggleHideCompletedUnscheduled(bool hide) {
    emit(state.copyWith(hideCompletedUnscheduled: hide));
  }

  void toggleHideCompletedReminders(bool hide) {
    emit(state.copyWith(hideCompletedReminders: hide));
  }

  void saveUnscheduledSidebarOrder(List<String> order) {
    emit(state.copyWith(unscheduledSidebarOrder: List<String>.from(order)));
  }

  void saveReminderSidebarOrder(List<String> order) {
    emit(state.copyWith(reminderSidebarOrder: List<String>.from(order)));
  }

  void toggleAutoLoadEmailImages(bool enabled) {
    emit(state.copyWith(autoLoadEmailImages: enabled));
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
    emit(
      state.copyWith(
        autoDownloadImages: imagesEnabled,
        autoDownloadVideos: videosEnabled,
        autoDownloadDocuments: documentsEnabled,
        autoDownloadArchives: archivesEnabled,
      ),
    );
    _xmppService?.updateAttachmentAutoDownloadSettings(
      imagesEnabled: imagesEnabled,
      videosEnabled: videosEnabled,
      documentsEnabled: documentsEnabled,
      archivesEnabled: archivesEnabled,
    );
  }

  @override
  SettingsState? fromJson(Map<String, dynamic> json) {
    try {
      final migrated = Map<String, dynamic>.from(json);
      const keyMap = <String, String>{
        'themeMode': 'theme_mode',
        'shadColor': 'shad_color',
        'notificationPreviewsEnabled': 'notification_previews_enabled',
        'chatReadReceipts': 'chat_read_receipts',
        'emailReadReceipts': 'email_read_receipts',
        'indicateTyping': 'indicate_typing',
        'lowMotion': 'low_motion',
        'colorfulAvatars': 'colorful_avatars',
        'shareTokenSignatureEnabled': 'share_token_signature_enabled',
        'hideCompletedScheduled': 'hide_completed_scheduled',
        'hideCompletedUnscheduled': 'hide_completed_unscheduled',
        'hideCompletedReminders': 'hide_completed_reminders',
        'unscheduledSidebarOrder': 'unscheduled_sidebar_order',
        'reminderSidebarOrder': 'reminder_sidebar_order',
        'autoLoadEmailImages': 'auto_load_email_images',
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
        final Map<dynamic, dynamic> parsed =
            settings is Map ? settings : const {};
        final imagesValue = parsed['images_enabled'];
        final videosValue = parsed['videos_enabled'];
        final documentsValue = parsed['documents_enabled'];
        final archivesValue = parsed['archives_enabled'];
        migrated['auto_download_images'] =
            imagesValue is bool ? imagesValue : defaultState.autoDownloadImages;
        migrated['auto_download_videos'] =
            videosValue is bool ? videosValue : defaultState.autoDownloadVideos;
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
      return SettingsState.fromJson(migrated);
    } catch (_) {
      return const SettingsState(shadColor: ShadColor.blue);
    }
  }

  @override
  Map<String, dynamic>? toJson(SettingsState state) => state.toJson();
}
