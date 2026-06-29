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

enum CalendarTaskListSortMode {
  manual,
  dateAdded,
  importance;

  String label(AppLocalizations l10n) {
    return switch (this) {
      CalendarTaskListSortMode.manual => l10n.calendarTaskSortManual,
      CalendarTaskListSortMode.dateAdded => l10n.calendarTaskSortDateAdded,
      CalendarTaskListSortMode.importance => l10n.calendarTaskSortImportance,
    };
  }

  bool get allowsManualReorder => this == CalendarTaskListSortMode.manual;
}

enum GlobalSettingId {
  language,
  themeMode,
  colorScheme,
  endpointConfig,
  backgroundMessaging,
  chatNotificationsMuted,
  emailNotificationsMuted,
  notificationPreviews,
  chatReadReceipts,
  emailReadReceipts,
  chatSendOnEnter,
  emailSendOnEnter,
  emailSendConfirmation,
  typingIndicators,
  lowMotion,
  colorfulAvatars,
  emailForwardingGuideSeen,
  shareSignature,
  hideCompletedScheduled,
  hideCompletedUnscheduled,
  hideCompletedReminders,
  unscheduledSidebarOrder,
  reminderSidebarOrder,
  calendarTaskListSortMode,
  messageTextSize,
  emailImageAutoload,
  emailComposerWatermark,
  emailEncryptionBeta,
  donationPromptTracking,
  attachmentAutoDownloadImages,
  attachmentAutoDownloadVideos,
  attachmentAutoDownloadDocuments,
  attachmentAutoDownloadArchives;

  static const Set<GlobalSettingId> syncedSettings = {
    language,
    themeMode,
    colorScheme,
    chatReadReceipts,
    emailReadReceipts,
    chatSendOnEnter,
    emailSendOnEnter,
    emailSendConfirmation,
    typingIndicators,
    lowMotion,
    colorfulAvatars,
    shareSignature,
    hideCompletedScheduled,
    hideCompletedUnscheduled,
    hideCompletedReminders,
    unscheduledSidebarOrder,
    reminderSidebarOrder,
    calendarTaskListSortMode,
    messageTextSize,
    emailImageAutoload,
    emailComposerWatermark,
    attachmentAutoDownloadImages,
    attachmentAutoDownloadVideos,
    attachmentAutoDownloadDocuments,
    attachmentAutoDownloadArchives,
  };

  static const Set<GlobalSettingId> deviceOnlySettings = {
    endpointConfig,
    backgroundMessaging,
    chatNotificationsMuted,
    emailNotificationsMuted,
    notificationPreviews,
    emailForwardingGuideSeen,
    emailEncryptionBeta,
    donationPromptTracking,
  };

  bool get isSynced => syncedSettings.contains(this);

  bool get isDeviceOnly => deviceOnlySettings.contains(this);

  String? get jsonKey => switch (this) {
    GlobalSettingId.language => 'language',
    GlobalSettingId.themeMode => 'theme_mode',
    GlobalSettingId.colorScheme => 'shad_color',
    GlobalSettingId.chatReadReceipts => 'chat_read_receipts',
    GlobalSettingId.emailReadReceipts => 'email_read_receipts',
    GlobalSettingId.chatSendOnEnter => 'chat_send_on_enter',
    GlobalSettingId.emailSendOnEnter => 'email_send_on_enter',
    GlobalSettingId.emailSendConfirmation => 'email_send_confirmation_enabled',
    GlobalSettingId.typingIndicators => 'indicate_typing',
    GlobalSettingId.lowMotion => 'low_motion',
    GlobalSettingId.colorfulAvatars => 'colorful_avatars',
    GlobalSettingId.shareSignature => 'share_token_signature_enabled',
    GlobalSettingId.hideCompletedScheduled => 'hide_completed_scheduled',
    GlobalSettingId.hideCompletedUnscheduled => 'hide_completed_unscheduled',
    GlobalSettingId.hideCompletedReminders => 'hide_completed_reminders',
    GlobalSettingId.unscheduledSidebarOrder => 'unscheduled_sidebar_order',
    GlobalSettingId.reminderSidebarOrder => 'reminder_sidebar_order',
    GlobalSettingId.calendarTaskListSortMode => 'calendar_task_list_sort_mode',
    GlobalSettingId.messageTextSize => 'message_text_size',
    GlobalSettingId.emailImageAutoload => 'auto_load_email_images',
    GlobalSettingId.emailComposerWatermark =>
      'email_composer_watermark_enabled',
    GlobalSettingId.attachmentAutoDownloadImages => 'auto_download_images',
    GlobalSettingId.attachmentAutoDownloadVideos => 'auto_download_videos',
    GlobalSettingId.attachmentAutoDownloadDocuments =>
      'auto_download_documents',
    GlobalSettingId.attachmentAutoDownloadArchives => 'auto_download_archives',
    _ => null,
  };
}

const List<String> _syncedSettingsKeys = <String>[
  'language',
  'theme_mode',
  'shad_color',
  'chat_read_receipts',
  'email_read_receipts',
  'chat_send_on_enter',
  'email_send_on_enter',
  'email_send_confirmation_enabled',
  'indicate_typing',
  'low_motion',
  'colorful_avatars',
  'share_token_signature_enabled',
  'hide_completed_scheduled',
  'hide_completed_unscheduled',
  'hide_completed_reminders',
  'unscheduled_sidebar_order',
  'reminder_sidebar_order',
  'calendar_task_list_sort_mode',
  'message_text_size',
  'auto_load_email_images',
  'email_composer_watermark_enabled',
  'auto_download_images',
  'auto_download_videos',
  'auto_download_documents',
  'auto_download_archives',
];

@freezed
abstract class SettingsState with _$SettingsState {
  const factory SettingsState({
    @Default(AppLanguage.english) AppLanguage language,
    @Default(ThemeMode.light) ThemeMode themeMode,
    @Default(ShadColor.neutral) ShadColor shadColor,
    @Default(EndpointConfig()) EndpointConfig endpointConfig,
    @Default(false) bool backgroundMessagingEnabled,
    @Default(false) bool chatNotificationsMuted,
    @Default(false) bool emailNotificationsMuted,
    @Default(false) bool notificationPreviewsEnabled,
    @Default(true) bool chatReadReceipts,
    @Default(false) bool emailReadReceipts,
    @Default(true) bool chatSendOnEnter,
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
    @Default(CalendarTaskListSortMode.manual)
    CalendarTaskListSortMode calendarTaskListSortMode,
    @Default(MessageTextSize.px16) MessageTextSize messageTextSize,
    @Default(false) bool autoLoadEmailImages,
    @Default(true) bool emailComposerWatermarkEnabled,
    String? donationPromptAccountJid,
    @Default(100) int donationPromptNextDisplayMessageCount,
    @Default(false) bool donationPromptTrackingInitialized,
    @Default(0) int donationPromptTrackedMessageCount,
    @Default(0) int donationPromptLastObservedStoredMessageCount,
    @Default(false) bool autoDownloadImages,
    @Default(false) bool autoDownloadVideos,
    @Default(false) bool autoDownloadDocuments,
    @Default(false) bool autoDownloadArchives,
    @Default(<String, bool>{})
    Map<String, bool> emailEncryptionBetaEnabledByAddress,
    // ignore: invalid_annotation_target
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(<GlobalSettingId, RequestStatus>{})
    Map<GlobalSettingId, RequestStatus> globalSettingStatuses,
    @Default(false) bool settingsSyncHasConfirmedSnapshot,
    @Default(<String, dynamic>{})
    Map<String, dynamic> settingsSyncConfirmedJson,
  }) = _SettingsState;

  factory SettingsState.fromJson(Map<String, Object?> json) =>
      _$SettingsStateFromJson(json);
}

extension SettingsStateAttachmentDefaults on SettingsState {
  bool get anyAttachmentAutoDownloadEnabled =>
      autoDownloadImages ||
      autoDownloadVideos ||
      autoDownloadDocuments ||
      autoDownloadArchives;

  AttachmentAutoDownload get defaultChatAttachmentAutoDownload =>
      anyAttachmentAutoDownloadEnabled
      ? AttachmentAutoDownload.allowed
      : AttachmentAutoDownload.blocked;
}

extension SettingsStateNotificationSettings on SettingsState {
  bool get allNotificationsMuted =>
      chatNotificationsMuted && emailNotificationsMuted;
}

extension SettingsStateSync on SettingsState {
  Map<String, dynamic> get syncedSettingsJson {
    final json = toJson();
    return Map<String, dynamic>.unmodifiable({
      for (final key in _syncedSettingsKeys)
        if (json.containsKey(key)) key: json[key],
    });
  }

  SettingsState mergeSyncedSettingsJson(Map<String, dynamic> incoming) {
    final merged = Map<String, dynamic>.from(toJson());
    for (final key in _syncedSettingsKeys) {
      if (incoming.containsKey(key)) {
        merged[key] = incoming[key];
      }
    }
    try {
      return SettingsState.fromJson(merged);
    } catch (_) {
      return this;
    }
  }

  Set<GlobalSettingId> get unsyncedGlobalSettingIds {
    return GlobalSettingId.syncedSettings
        .where(isGlobalSettingNotSynced)
        .toSet();
  }

  bool isGlobalSettingLoading(GlobalSettingId settingId) {
    return globalSettingStatuses[settingId]?.isLoading ?? false;
  }

  bool isGlobalSettingNotSynced(GlobalSettingId settingId) {
    final key = settingId.jsonKey;
    if (!settingId.isSynced ||
        key == null ||
        isGlobalSettingLoading(settingId) ||
        !settingsSyncHasConfirmedSnapshot) {
      return false;
    }
    return !const DeepCollectionEquality().equals(
      syncedSettingsJson[key],
      settingsSyncConfirmedJson[key],
    );
  }

  Set<GlobalSettingId> changedGlobalSettingIds(
    SettingsState nextState, {
    Iterable<GlobalSettingId> hints = const {},
  }) {
    final hinted = hints.toSet();
    if (hinted.isNotEmpty) {
      return hinted.where((settingId) {
        final key = settingId.jsonKey;
        if (key == null) return true;
        return !const DeepCollectionEquality().equals(
          syncedSettingsJson[key],
          nextState.syncedSettingsJson[key],
        );
      }).toSet();
    }
    return GlobalSettingId.syncedSettings.where((settingId) {
      final key = settingId.jsonKey;
      if (key == null) return false;
      return !const DeepCollectionEquality().equals(
        syncedSettingsJson[key],
        nextState.syncedSettingsJson[key],
      );
    }).toSet();
  }

  SettingsState markGlobalSettingsLoading(
    Iterable<GlobalSettingId> settingIds, {
    Map<String, dynamic>? confirmedBaseline,
  }) {
    final nextStatuses = Map<GlobalSettingId, RequestStatus>.from(
      globalSettingStatuses,
    );
    for (final settingId in settingIds) {
      if (settingId.isSynced) {
        nextStatuses[settingId] = RequestStatus.loading;
      }
    }
    return copyWith(
      globalSettingStatuses: Map<GlobalSettingId, RequestStatus>.unmodifiable(
        nextStatuses,
      ),
      settingsSyncHasConfirmedSnapshot:
          settingsSyncHasConfirmedSnapshot || confirmedBaseline != null,
      settingsSyncConfirmedJson: confirmedBaseline ?? settingsSyncConfirmedJson,
    );
  }

  SettingsState clearGlobalSettingsLoading(
    Iterable<GlobalSettingId> settingIds, {
    Map<String, dynamic>? confirmedSnapshot,
  }) {
    final nextStatuses = Map<GlobalSettingId, RequestStatus>.from(
      globalSettingStatuses,
    );
    for (final settingId in settingIds) {
      nextStatuses.remove(settingId);
    }
    return copyWith(
      globalSettingStatuses: Map<GlobalSettingId, RequestStatus>.unmodifiable(
        nextStatuses,
      ),
      settingsSyncHasConfirmedSnapshot:
          settingsSyncHasConfirmedSnapshot || confirmedSnapshot != null,
      settingsSyncConfirmedJson: confirmedSnapshot ?? settingsSyncConfirmedJson,
    );
  }
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
  }) => false;
}
