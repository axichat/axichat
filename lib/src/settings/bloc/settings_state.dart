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
  zinc,
}

@freezed
class SettingsState with _$SettingsState {
  const factory SettingsState({
    @Default(AppLanguage.system) AppLanguage language,
    @Default(ThemeMode.light) ThemeMode themeMode,
    @Default(ShadColor.blue) ShadColor shadColor,
    @Default(false) bool mute,
    @Default(false) bool notificationPreviewsEnabled,
    @Default(true) bool readReceipts,
    @Default(true) bool indicateTyping,
    @Default(false) bool lowMotion,
    @Default(true) bool colorfulAvatars,
    @Default(MessageStorageMode.local) MessageStorageMode messageStorageMode,
    @Default(true) bool shareTokenSignatureEnabled,
    @Default(false) bool hideCompletedScheduled,
    @Default(false) bool hideCompletedUnscheduled,
    @Default(false) bool hideCompletedReminders,
    @Default(<String>[]) List<String> unscheduledSidebarOrder,
    @Default(<String>[]) List<String> reminderSidebarOrder,
    @Default(false) bool autoLoadEmailImages,
    @Default(defaultAutoDownloadImages) bool autoDownloadImages,
    @Default(defaultAutoDownloadVideos) bool autoDownloadVideos,
    @Default(defaultAutoDownloadDocuments) bool autoDownloadDocuments,
    @Default(defaultAutoDownloadArchives) bool autoDownloadArchives,
  }) = _SettingsState;

  factory SettingsState.fromJson(Map<String, Object?> json) =>
      _$SettingsStateFromJson(json);
}

extension SettingsAttachmentAutoDownload on SettingsState {
  AttachmentAutoDownloadSettings get attachmentAutoDownloadSettings =>
      AttachmentAutoDownloadSettings(
        imagesEnabled: autoDownloadImages,
        videosEnabled: autoDownloadVideos,
        documentsEnabled: autoDownloadDocuments,
        archivesEnabled: autoDownloadArchives,
      );
}
