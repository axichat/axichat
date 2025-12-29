import 'package:axichat/src/attachments/attachment_auto_download_settings.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/app_language.dart';
import 'package:axichat/src/settings/message_storage_mode.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

part 'settings_cubit.freezed.dart';
part 'settings_cubit.g.dart';
part 'settings_state.dart';

class SettingsCubit extends HydratedCubit<SettingsState> {
  SettingsCubit({XmppService? xmppService})
      : _xmppService = xmppService,
        super(const SettingsState()) {
    _syncAttachmentAutoDownloadSettings(state);
  }

  final XmppService? _xmppService;

  Duration get animationDuration =>
      state.lowMotion ? Duration.zero : baseAnimationDuration;

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

  void toggleMute(bool mute) {
    emit(state.copyWith(mute: mute));
  }

  void toggleNotificationPreviews(bool enabled) {
    emit(state.copyWith(notificationPreviewsEnabled: enabled));
  }

  void toggleReadReceipts(bool readReceipts) {
    emit(state.copyWith(readReceipts: readReceipts));
  }

  void toggleColorfulAvatars(bool colorfulAvatars) {
    emit(state.copyWith(colorfulAvatars: colorfulAvatars));
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

  void updateMessageStorageMode(MessageStorageMode mode) {
    emit(state.copyWith(messageStorageMode: mode));
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

  void toggleAutoDownloadImages(bool enabled) {
    emit(state.copyWith(autoDownloadImages: enabled));
  }

  void toggleAutoDownloadVideos(bool enabled) {
    emit(state.copyWith(autoDownloadVideos: enabled));
  }

  void toggleAutoDownloadDocuments(bool enabled) {
    emit(state.copyWith(autoDownloadDocuments: enabled));
  }

  void toggleAutoDownloadArchives(bool enabled) {
    emit(state.copyWith(autoDownloadArchives: enabled));
  }

  @override
  void onChange(Change<SettingsState> change) {
    super.onChange(change);
    _syncAttachmentAutoDownloadSettings(change.nextState,
        previous: change.currentState);
  }

  void _syncAttachmentAutoDownloadSettings(
    SettingsState next, {
    SettingsState? previous,
  }) {
    final previousState = previous;
    if (previousState != null &&
        previousState.autoDownloadImages == next.autoDownloadImages &&
        previousState.autoDownloadVideos == next.autoDownloadVideos &&
        previousState.autoDownloadDocuments == next.autoDownloadDocuments &&
        previousState.autoDownloadArchives == next.autoDownloadArchives) {
      return;
    }
    final settings = AttachmentAutoDownloadSettings(
      imagesEnabled: next.autoDownloadImages,
      videosEnabled: next.autoDownloadVideos,
      documentsEnabled: next.autoDownloadDocuments,
      archivesEnabled: next.autoDownloadArchives,
    );
    _xmppService?.updateAttachmentAutoDownloadSettings(settings);
  }

  @override
  SettingsState? fromJson(Map<String, dynamic> json) {
    try {
      final migrated = Map<String, dynamic>.from(json);
      const keyMap = <String, String>{
        'themeMode': 'theme_mode',
        'shadColor': 'shad_color',
        'notificationPreviewsEnabled': 'notification_previews_enabled',
        'readReceipts': 'read_receipts',
        'indicateTyping': 'indicate_typing',
        'lowMotion': 'low_motion',
        'colorfulAvatars': 'colorful_avatars',
        'messageStorageMode': 'message_storage_mode',
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
      return SettingsState.fromJson(migrated);
    } catch (_) {
      return const SettingsState(shadColor: ShadColor.blue);
    }
  }

  @override
  Map<String, dynamic>? toJson(SettingsState state) => state.toJson();
}
