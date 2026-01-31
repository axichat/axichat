// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'settings_cubit.dart';

enum ShadColor {
  blue,
  gray,
  green,
  neutral,
  orange,
  red,
  rose,
  slate,
  stone,
  violet,
  yellow,
  zinc;
}

@freezed
class SettingsState with _$SettingsState {
  const factory SettingsState({
    @Default(AppLanguage.system) AppLanguage language,
    @Default(ThemeMode.dark) ThemeMode themeMode,
    @Default(ShadColor.blue) ShadColor shadColor,
    @Default(EndpointConfig()) EndpointConfig endpointConfig,
    @Default(false) bool mute,
    @Default(false) bool notificationPreviewsEnabled,
    @Default(true) bool chatReadReceipts,
    @Default(false) bool emailReadReceipts,
    @Default(true) bool indicateTyping,
    @Default(false) bool lowMotion,
    @Default(true) bool colorfulAvatars,
    @Default(false) bool emailForwardingGuideSeen,
    @Default(true) bool shareTokenSignatureEnabled,
    @Default(false) bool hideCompletedScheduled,
    @Default(false) bool hideCompletedUnscheduled,
    @Default(false) bool hideCompletedReminders,
    @Default(<String>[]) List<String> unscheduledSidebarOrder,
    @Default(<String>[]) List<String> reminderSidebarOrder,
    @Default(false) bool autoLoadEmailImages,
    @Default(true) bool autoDownloadImages,
    @Default(false) bool autoDownloadVideos,
    @Default(false) bool autoDownloadDocuments,
    @Default(false) bool autoDownloadArchives,
  }) = _SettingsState;

  factory SettingsState.fromJson(Map<String, Object?> json) =>
      _$SettingsStateFromJson(json);
}

extension SettingsStateAttachmentDefaults on SettingsState {
  AttachmentAutoDownload get defaultChatAttachmentAutoDownload =>
      autoDownloadImages ||
              autoDownloadVideos ||
              autoDownloadDocuments ||
              autoDownloadArchives
          ? AttachmentAutoDownload.allowed
          : AttachmentAutoDownload.blocked;
}
