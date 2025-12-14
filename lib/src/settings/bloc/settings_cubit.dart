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
      final hasColor = json['shadColor'] != null;
      final parsed = SettingsState.fromJson(json);
      // Force blue as the default palette on fresh boots or malformed payloads.
      return hasColor ? parsed : parsed.copyWith(shadColor: ShadColor.blue);
    } catch (_) {
      return const SettingsState(shadColor: ShadColor.blue);
    }
  }

  @override
  Map<String, dynamic>? toJson(SettingsState state) => state.toJson();
}
