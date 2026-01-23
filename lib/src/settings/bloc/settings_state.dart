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
    @Default(false) bool mute,
    @Default(false) bool notificationPreviewsEnabled,
    @Default(true) bool chatReadReceipts,
    @Default(false) bool emailReadReceipts,
    @Default(true) bool indicateTyping,
    @Default(false) bool lowMotion,
    @Default(true) bool colorfulAvatars,
    @Default(false) bool emailForwardingGuideSeen,
    @Default(MessageStorageMode.local) MessageStorageMode messageStorageMode,
    @Default(true) bool shareTokenSignatureEnabled,
    @Default(false) bool hideCompletedScheduled,
    @Default(false) bool hideCompletedUnscheduled,
    @Default(false) bool hideCompletedReminders,
    @Default(<String>[]) List<String> unscheduledSidebarOrder,
    @Default(<String>[]) List<String> reminderSidebarOrder,
    @Default(false) bool autoLoadEmailImages,
    @Default(AttachmentAutoDownloadSettings())
    AttachmentAutoDownloadSettings attachmentAutoDownloadSettings,
  }) = _SettingsState;

  factory SettingsState.fromJson(Map<String, Object?> json) =>
      _$SettingsStateFromJson(json);
}

@freezed
class AttachmentAutoDownloadSettings with _$AttachmentAutoDownloadSettings {
  const factory AttachmentAutoDownloadSettings({
    @Default(true) bool imagesEnabled,
    @Default(false) bool videosEnabled,
    @Default(false) bool documentsEnabled,
    @Default(false) bool archivesEnabled,
  }) = _AttachmentAutoDownloadSettings;

  const AttachmentAutoDownloadSettings._();

  factory AttachmentAutoDownloadSettings.fromJson(Map<String, Object?> json) =>
      _$AttachmentAutoDownloadSettingsFromJson(json);

  bool allowsCategory(FileMetadataDownloadCategory category) {
    return switch (category) {
      FileMetadataDownloadCategory.image => imagesEnabled,
      FileMetadataDownloadCategory.video => videosEnabled,
      FileMetadataDownloadCategory.document => documentsEnabled,
      FileMetadataDownloadCategory.archive => archivesEnabled,
    };
  }

  bool allowsMetadata(FileMetadataData metadata) =>
      allowsCategory(metadata.downloadCategory);
}
