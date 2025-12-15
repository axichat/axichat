import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/app_language.dart';
import 'package:axichat/src/settings/message_storage_mode.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

part 'settings_cubit.freezed.dart';
part 'settings_cubit.g.dart';
part 'settings_state.dart';

class SettingsCubit extends HydratedCubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

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
