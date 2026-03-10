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
  zinc,
}

enum MessageTextSize {
  px14(14),
  px16(16),
  px18(18);

  const MessageTextSize(this.pixels);

  final int pixels;

  double get fontSize => pixels.toDouble();
}

@freezed
abstract class SettingsState with _$SettingsState {
  const factory SettingsState({
    @Default(AppLanguage.system) AppLanguage language,
    @Default(ThemeMode.light) ThemeMode themeMode,
    @Default(ShadColor.neutral) ShadColor shadColor,
    @Default(EndpointConfig()) EndpointConfig endpointConfig,
    @Default(false) bool backgroundMessagingEnabled,
    @Default(false) bool chatNotificationsMuted,
    @Default(false) bool emailNotificationsMuted,
    @Default(false) bool notificationPreviewsEnabled,
    @Default(true) bool chatReadReceipts,
    @Default(false) bool emailReadReceipts,
    @Default(false) bool chatSendOnEnter,
    @Default(false) bool emailSendOnEnter,
    @Default(true) bool emailSendConfirmationEnabled,
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
    @Default(MessageTextSize.px16) MessageTextSize messageTextSize,
    @Default(false) bool autoLoadEmailImages,
    @Default(true) bool emailComposerWatermarkEnabled,
    String? donationPromptAccountJid,
    @Default(100) int donationPromptNextDisplayMessageCount,
    @Default(false) bool donationPromptTrackingInitialized,
    @Default(0) int donationPromptTrackedMessageCount,
    @Default(0) int donationPromptLastObservedStoredMessageCount,
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

extension SettingsStateDonationPrompt on SettingsState {
  String? _normalizedDonationPromptAccountJid(String? accountJid) {
    final normalized = normalizedAddressValue(accountJid);
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  SettingsState _resetDonationPromptTracking({
    required String accountJid,
    required int storedConversationMessageCount,
  }) {
    return copyWith(
      donationPromptAccountJid: accountJid,
      donationPromptNextDisplayMessageCount: 100,
      donationPromptTrackingInitialized: true,
      donationPromptTrackedMessageCount: 0,
      donationPromptLastObservedStoredMessageCount:
          storedConversationMessageCount,
    );
  }

  int _donationPromptNewMessages(int storedConversationMessageCount) {
    final sanitizedStoredMessageCount = storedConversationMessageCount < 0
        ? 0
        : storedConversationMessageCount;
    if (sanitizedStoredMessageCount <=
        donationPromptLastObservedStoredMessageCount) {
      return 0;
    }
    return sanitizedStoredMessageCount -
        donationPromptLastObservedStoredMessageCount;
  }

  int effectiveDonationPromptTrackedMessageCount(
    int storedConversationMessageCount,
  ) {
    final newMessages = _donationPromptNewMessages(
      storedConversationMessageCount,
    );
    if (!donationPromptTrackingInitialized &&
        donationPromptNextDisplayMessageCount <= 100) {
      return donationPromptTrackedMessageCount;
    }
    return donationPromptTrackedMessageCount + newMessages;
  }

  SettingsState syncDonationPromptMessageCount({
    required String? accountJid,
    required int storedConversationMessageCount,
  }) {
    final sanitizedStoredMessageCount = storedConversationMessageCount < 0
        ? 0
        : storedConversationMessageCount;
    final normalizedAccountJid = _normalizedDonationPromptAccountJid(
      accountJid,
    );
    if (normalizedAccountJid == null) {
      return this;
    }
    if (normalizedAccountJid != donationPromptAccountJid) {
      return _resetDonationPromptTracking(
        accountJid: normalizedAccountJid,
        storedConversationMessageCount: sanitizedStoredMessageCount,
      );
    }
    if (!donationPromptTrackingInitialized) {
      final shouldPreserveTrackedCount =
          donationPromptNextDisplayMessageCount > 100;
      final trackedMessageCount = shouldPreserveTrackedCount
          ? effectiveDonationPromptTrackedMessageCount(
              sanitizedStoredMessageCount,
            )
          : 0;
      if (!shouldPreserveTrackedCount &&
          donationPromptTrackedMessageCount == trackedMessageCount &&
          sanitizedStoredMessageCount ==
              donationPromptLastObservedStoredMessageCount) {
        return copyWith(donationPromptTrackingInitialized: true);
      }
      return copyWith(
        donationPromptTrackingInitialized: true,
        donationPromptTrackedMessageCount: trackedMessageCount,
        donationPromptLastObservedStoredMessageCount:
            sanitizedStoredMessageCount,
      );
    }
    final trackedMessageCount = effectiveDonationPromptTrackedMessageCount(
      sanitizedStoredMessageCount,
    );
    if (trackedMessageCount == donationPromptTrackedMessageCount &&
        sanitizedStoredMessageCount ==
            donationPromptLastObservedStoredMessageCount) {
      return this;
    }
    return copyWith(
      donationPromptTrackedMessageCount: trackedMessageCount,
      donationPromptLastObservedStoredMessageCount: sanitizedStoredMessageCount,
    );
  }

  bool showsDonationPrompt({
    required String? accountJid,
    required int storedConversationMessageCount,
  }) {
    final normalizedAccountJid = _normalizedDonationPromptAccountJid(
      accountJid,
    );
    if (normalizedAccountJid == null ||
        normalizedAccountJid != donationPromptAccountJid) {
      return false;
    }
    return effectiveDonationPromptTrackedMessageCount(
          storedConversationMessageCount,
        ) >=
        donationPromptNextDisplayMessageCount;
  }
}
