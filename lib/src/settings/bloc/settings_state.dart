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

@immutable
class AttachmentAutoDownloadSettings {
  const AttachmentAutoDownloadSettings({
    this.imagesEnabled = true,
    this.videosEnabled = false,
    this.documentsEnabled = false,
    this.archivesEnabled = false,
  });

  final bool imagesEnabled;
  final bool videosEnabled;
  final bool documentsEnabled;
  final bool archivesEnabled;

  AttachmentAutoDownloadSettings copyWith({
    bool? imagesEnabled,
    bool? videosEnabled,
    bool? documentsEnabled,
    bool? archivesEnabled,
  }) {
    return AttachmentAutoDownloadSettings(
      imagesEnabled: imagesEnabled ?? this.imagesEnabled,
      videosEnabled: videosEnabled ?? this.videosEnabled,
      documentsEnabled: documentsEnabled ?? this.documentsEnabled,
      archivesEnabled: archivesEnabled ?? this.archivesEnabled,
    );
  }

  factory AttachmentAutoDownloadSettings.fromJson(
    Map<String, Object?> json,
  ) {
    bool resolveBool(String snakeKey, String camelKey, bool fallback) {
      final value = json[snakeKey] ?? json[camelKey];
      return value is bool ? value : fallback;
    }

    return AttachmentAutoDownloadSettings(
      imagesEnabled: resolveBool('images_enabled', 'imagesEnabled', true),
      videosEnabled: resolveBool('videos_enabled', 'videosEnabled', false),
      documentsEnabled:
          resolveBool('documents_enabled', 'documentsEnabled', false),
      archivesEnabled:
          resolveBool('archives_enabled', 'archivesEnabled', false),
    );
  }

  Map<String, Object?> toJson() => {
        'images_enabled': imagesEnabled,
        'videos_enabled': videosEnabled,
        'documents_enabled': documentsEnabled,
        'archives_enabled': archivesEnabled,
      };

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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttachmentAutoDownloadSettings &&
        other.imagesEnabled == imagesEnabled &&
        other.videosEnabled == videosEnabled &&
        other.documentsEnabled == documentsEnabled &&
        other.archivesEnabled == archivesEnabled;
  }

  @override
  int get hashCode => Object.hash(
        imagesEnabled,
        videosEnabled,
        documentsEnabled,
        archivesEnabled,
      );
}
