// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'chat_bloc.dart';

sealed class ChatEvent extends Equatable {
  const ChatEvent();
}

final class _ChatUpdated extends ChatEvent {
  const _ChatUpdated(this.chat);

  final Chat chat;

  @override
  List<Object?> get props => [chat];
}

final class _ChatStarted extends ChatEvent {
  const _ChatStarted();

  @override
  List<Object?> get props => [];
}

final class _ChatMessagesUpdated extends ChatEvent {
  const _ChatMessagesUpdated(this.items);

  final List<Message> items;

  @override
  List<Object?> get props => [items];
}

final class _ChatPresentationHydrationRequested extends ChatEvent {
  const _ChatPresentationHydrationRequested({
    required this.messageReferenceIds,
    required this.deltaMessageIds,
    required this.missingQuoteIds,
    required this.metadataIds,
    this.renderedMessages = const <Message>[],
    this.allowOffWindowEmailContentHydration = false,
    required this.syncFileMetadata,
  });

  final Set<String> messageReferenceIds;
  final Set<int> deltaMessageIds;
  final Set<String> missingQuoteIds;
  final Set<String> metadataIds;
  final List<Message> renderedMessages;
  final bool allowOffWindowEmailContentHydration;
  final bool syncFileMetadata;

  @override
  List<Object?> get props => [
    messageReferenceIds,
    deltaMessageIds,
    missingQuoteIds,
    metadataIds,
    renderedMessages,
    allowOffWindowEmailContentHydration,
    syncFileMetadata,
  ];
}

enum _ChatReadStateSyncSendPolicy {
  whenResumed,
  allowed;

  bool get allowsSendNow => switch (this) {
    whenResumed =>
      SchedulerBinding.instance.lifecycleState == AppLifecycleState.resumed,
    allowed => true,
  };
}

final class _ChatReadStateSyncRequested extends ChatEvent {
  const _ChatReadStateSyncRequested({
    this.sendPolicy = _ChatReadStateSyncSendPolicy.whenResumed,
  });

  final _ChatReadStateSyncSendPolicy sendPolicy;

  @override
  List<Object?> get props => [sendPolicy];
}

final class ChatRenderedMessagesHydrationRequested extends ChatEvent {
  ChatRenderedMessagesHydrationRequested(Iterable<Message> messages)
    : messages = List<Message>.unmodifiable(messages);

  final List<Message> messages;

  @override
  List<Object?> get props => [messages];
}

final class _PinnedMessagesUpdated extends ChatEvent {
  const _PinnedMessagesUpdated({required this.sourceKey, required this.items});

  final String? sourceKey;
  final List<PinnedMessageAggregate> items;

  @override
  List<Object?> get props => [sourceKey, items];
}

final class _PinnedMessagesLoadFailed extends ChatEvent {
  const _PinnedMessagesLoadFailed(this.sourceKey);

  final String? sourceKey;

  @override
  List<Object?> get props => [sourceKey];
}

final class _FileMetadataBatchUpdated extends ChatEvent {
  const _FileMetadataBatchUpdated({required this.metadataById});

  final Map<String, FileMetadataData?> metadataById;

  @override
  List<Object?> get props => [metadataById];
}

final class ChatPinnedMessagesOpened extends ChatEvent {
  const ChatPinnedMessagesOpened();

  @override
  List<Object?> get props => [];
}

final class ChatPinnedMessagesRetryRequested extends ChatEvent {
  const ChatPinnedMessagesRetryRequested();

  @override
  List<Object?> get props => [];
}

final class ChatPinnedMessageNoticeHidden extends ChatEvent {
  const ChatPinnedMessageNoticeHidden();

  @override
  List<Object?> get props => [];
}

final class ChatPinnedMessageSelected extends ChatEvent {
  const ChatPinnedMessageSelected(this.messageStanzaId);

  final String messageStanzaId;

  @override
  List<Object?> get props => [messageStanzaId];
}

final class ChatImportantMessageSelected extends ChatEvent {
  const ChatImportantMessageSelected(this.messageReferenceId);

  final String messageReferenceId;

  @override
  List<Object?> get props => [messageReferenceId];
}

final class ChatRoomMembersOpened extends ChatEvent {
  const ChatRoomMembersOpened();

  @override
  List<Object?> get props => [];
}

final class _RoomStateUpdated extends ChatEvent {
  const _RoomStateUpdated(this.roomState);

  final RoomState roomState;

  @override
  List<Object?> get props => [roomState];
}

final class _RoomRosterUpdated extends ChatEvent {
  const _RoomRosterUpdated(this.items);

  final List<RosterItem> items;

  @override
  List<Object?> get props => [items];
}

final class _RoomChatsUpdated extends ChatEvent {
  const _RoomChatsUpdated(this.items);

  final List<Chat> items;

  @override
  List<Object?> get props => [items];
}

final class _RoomSelfAvatarUpdated extends ChatEvent {
  const _RoomSelfAvatarUpdated(this.avatar);

  final Avatar? avatar;

  @override
  List<Object?> get props => [avatar];
}

final class _EmailSyncStateChanged extends ChatEvent {
  const _EmailSyncStateChanged(this.state);

  final EmailSyncState state;

  @override
  List<Object?> get props => [state];
}

final class _XmppConnectionStateChanged extends ChatEvent {
  const _XmppConnectionStateChanged(this.state);

  final ConnectionState state;

  @override
  List<Object?> get props => [state];
}

final class _HttpUploadSupportUpdated extends ChatEvent {
  const _HttpUploadSupportUpdated(this.supported);

  final bool supported;

  @override
  List<Object?> get props => [supported];
}

final class ChatSettingsUpdated extends ChatEvent {
  const ChatSettingsUpdated(this.settings);

  final ChatSettingsSnapshot settings;

  @override
  List<Object?> get props => [settings];
}

final class ChatEmailServiceUpdated extends ChatEvent {
  const ChatEmailServiceUpdated(this.emailService);

  final EmailService? emailService;

  @override
  List<Object?> get props => [emailService];
}

final class _ChatSavedTransportOverrideUpdated extends ChatEvent {
  const _ChatSavedTransportOverrideUpdated(this.transport);

  final MessageTransport? transport;

  @override
  List<Object?> get props => [transport];
}

final class ChatReadThresholdChanged extends ChatEvent {
  const ChatReadThresholdChanged(this.messageIds);

  final List<String> messageIds;

  @override
  List<Object?> get props => [messageIds];
}

final class ChatMessageReadRequested extends ChatEvent {
  const ChatMessageReadRequested(this.messageId);

  final String messageId;

  @override
  List<Object?> get props => [messageId];
}

final class ChatMessageFocused extends ChatEvent {
  const ChatMessageFocused(this.messageID);

  final String? messageID;

  @override
  List<Object?> get props => [messageID];
}

final class ChatEmailHeadersRequested extends ChatEvent {
  const ChatEmailHeadersRequested(this.message);

  final Message message;

  @override
  List<Object?> get props => [message];
}

final class ChatEmailFullHtmlRequested extends ChatEvent {
  const ChatEmailFullHtmlRequested(this.message, {this.allowOffWindow = false});

  final Message message;
  final bool allowOffWindow;

  @override
  List<Object?> get props => [message, allowOffWindow];
}

final class ChatEmailQuotedTextRequested extends ChatEvent {
  const ChatEmailQuotedTextRequested(
    this.message, {
    this.allowOffWindow = false,
  });

  final Message message;
  final bool allowOffWindow;

  @override
  List<Object?> get props => [message, allowOffWindow];
}

final class _ChatTypingStopped extends ChatEvent {
  const _ChatTypingStopped({required this.chat});

  final Chat chat;

  @override
  List<Object?> get props => [chat];
}

final class ChatTypingStarted extends ChatEvent {
  const ChatTypingStarted({required this.chat});

  final Chat chat;

  @override
  List<Object?> get props => [chat];
}

final class _TypingParticipantsUpdated extends ChatEvent {
  const _TypingParticipantsUpdated(this.participants);

  final List<String> participants;

  @override
  List<Object?> get props => [participants];
}

final class ChatMessageSent extends ChatEvent {
  const ChatMessageSent({
    required this.chat,
    required this.text,
    required this.recipients,
    required this.pendingAttachments,
    required this.settings,
    required this.supportsHttpFileUpload,
    required this.attachmentFallbackLabel,
    this.subject,
    this.quotedDraft,
    this.roomState,
    this.calendarTaskIcs,
    this.calendarTaskIcsReadOnly = CalendarTaskIcsMessage.defaultReadOnly,
    this.calendarTaskShareText,
    this.oneShotTransportOverride,
    this.completer,
  });

  final Chat chat;
  final String text;
  final List<ComposerRecipient> recipients;
  final List<PendingAttachment> pendingAttachments;
  final ChatSettingsSnapshot settings;
  final bool supportsHttpFileUpload;
  final String attachmentFallbackLabel;
  final String? subject;
  final Message? quotedDraft;
  final RoomState? roomState;
  final CalendarTask? calendarTaskIcs;
  final bool calendarTaskIcsReadOnly;
  final String? calendarTaskShareText;
  final MessageTransport? oneShotTransportOverride;
  final Completer<List<PendingAttachment>>? completer;

  @override
  List<Object?> get props => [
    chat,
    text,
    recipients,
    pendingAttachments,
    settings,
    supportsHttpFileUpload,
    attachmentFallbackLabel,
    subject,
    quotedDraft,
    roomState,
    calendarTaskIcs,
    calendarTaskIcsReadOnly,
    calendarTaskShareText,
    oneShotTransportOverride,
    completer,
  ];
}

final class ChatAvailabilityMessageSent extends ChatEvent {
  const ChatAvailabilityMessageSent({
    required this.chat,
    required this.message,
  });

  final Chat chat;
  final CalendarAvailabilityMessage message;

  @override
  List<Object?> get props => [chat, message];
}

final class ChatMuted extends ChatEvent {
  const ChatMuted({required this.chatJid, required this.muted});

  final String chatJid;
  final bool muted;

  @override
  List<Object?> get props => [chatJid, muted];
}

final class ChatNotificationPreviewSettingChanged extends ChatEvent {
  const ChatNotificationPreviewSettingChanged({
    required this.chat,
    required this.setting,
  });

  final Chat chat;
  final NotificationPreviewSetting? setting;

  @override
  List<Object?> get props => [chat, setting];
}

final class ChatNotificationBehaviorChanged extends ChatEvent {
  const ChatNotificationBehaviorChanged({
    required this.chat,
    required this.behavior,
  });

  final Chat chat;
  final ChatNotificationBehavior? behavior;

  @override
  List<Object?> get props => [chat, behavior];
}

final class ChatLoadEarlier extends ChatEvent {
  const ChatLoadEarlier({this.completer});

  final Completer<void>? completer;

  @override
  List<Object?> get props => [completer];
}

final class ChatShareSignatureToggled extends ChatEvent {
  const ChatShareSignatureToggled({required this.chat, required this.enabled});

  final Chat chat;
  final bool? enabled;

  @override
  List<Object?> get props => [chat, enabled];
}

final class ChatAttachmentAutoDownloadToggled extends ChatEvent {
  const ChatAttachmentAutoDownloadToggled({
    required this.chat,
    required this.value,
  });

  final Chat chat;
  final AttachmentAutoDownload? value;

  @override
  List<Object?> get props => [chat, value];
}

final class ChatAttachmentAutoDownloadRequested extends ChatEvent {
  const ChatAttachmentAutoDownloadRequested(this.stanzaId);

  final String stanzaId;

  @override
  List<Object?> get props => [stanzaId];
}

final class ChatResponsivityChanged extends ChatEvent {
  const ChatResponsivityChanged({
    required this.chatJid,
    required this.responsive,
  });

  final String chatJid;
  final bool? responsive;

  @override
  List<Object?> get props => [chatJid, responsive];
}

final class ChatTypingIndicatorsChanged extends ChatEvent {
  const ChatTypingIndicatorsChanged({
    required this.chatJid,
    required this.enabled,
  });

  final String chatJid;
  final bool? enabled;

  @override
  List<Object?> get props => [chatJid, enabled];
}

final class ChatEmailRemoteImagesChanged extends ChatEvent {
  const ChatEmailRemoteImagesChanged({
    required this.chatJid,
    required this.enabled,
  });

  final String chatJid;
  final bool? enabled;

  @override
  List<Object?> get props => [chatJid, enabled];
}

final class ChatEmailReadReceiptsChanged extends ChatEvent {
  const ChatEmailReadReceiptsChanged({
    required this.chatJid,
    required this.enabled,
  });

  final String chatJid;
  final bool? enabled;

  @override
  List<Object?> get props => [chatJid, enabled];
}

final class ChatEmailSendConfirmationChanged extends ChatEvent {
  const ChatEmailSendConfirmationChanged({
    required this.chatJid,
    required this.enabled,
  });

  final String chatJid;
  final bool? enabled;

  @override
  List<Object?> get props => [chatJid, enabled];
}

final class ChatEmailComposerWatermarkChanged extends ChatEvent {
  const ChatEmailComposerWatermarkChanged({
    required this.chatJid,
    required this.enabled,
  });

  final String chatJid;
  final bool? enabled;

  @override
  List<Object?> get props => [chatJid, enabled];
}

final class ChatSavedTransportOverrideChanged extends ChatEvent {
  const ChatSavedTransportOverrideChanged({
    required this.chatJid,
    required this.transport,
  });

  final String chatJid;
  final MessageTransport? transport;

  @override
  List<Object?> get props => [chatJid, transport];
}

final class ChatSettingSyncRetried extends ChatEvent {
  const ChatSettingSyncRetried(this.settingId);

  final ChatSettingId settingId;

  @override
  List<Object?> get props => [settingId];
}

final class ChatEncryptionChanged extends ChatEvent {
  const ChatEncryptionChanged({required this.chatJid, required this.protocol});

  final String chatJid;
  final EncryptionProtocol protocol;

  @override
  List<Object?> get props => [chatJid, protocol];
}

final class ChatEncryptionRepaired extends ChatEvent {
  const ChatEncryptionRepaired({required this.chatJid});

  final String chatJid;

  @override
  List<Object?> get props => [chatJid];
}

final class ChatCapabilitiesRequested extends ChatEvent {
  const ChatCapabilitiesRequested({this.forceRefresh = false});

  final bool forceRefresh;

  @override
  List<Object?> get props => [forceRefresh];
}

final class ChatAlertHidden extends ChatEvent {
  const ChatAlertHidden({required this.chatJid, this.forever = false});

  final String chatJid;
  final bool forever;

  @override
  List<Object?> get props => [chatJid, forever];
}

final class ChatSpamStatusRequested extends ChatEvent {
  const ChatSpamStatusRequested({
    required this.chat,
    required this.sendToSpam,
    required this.successTitle,
    required this.successMessage,
    required this.failureMessage,
  });

  final Chat chat;
  final bool sendToSpam;
  final String successTitle;
  final String successMessage;
  final String failureMessage;

  @override
  List<Object?> get props => [
    chat,
    sendToSpam,
    successTitle,
    successMessage,
    failureMessage,
  ];
}

final class ChatContactAddRequested extends ChatEvent {
  const ChatContactAddRequested({
    required this.chat,
    required this.failureMessage,
    this.acceptedCompleter,
  });

  final Chat chat;
  final String failureMessage;
  final Completer<bool>? acceptedCompleter;

  @override
  List<Object?> get props => [chat, failureMessage];
}

final class ChatRecipientEmailChatRequested extends ChatEvent {
  const ChatRecipientEmailChatRequested({
    required this.recipient,
    required this.failureMessage,
  });

  final Chat recipient;
  final String failureMessage;

  @override
  List<Object?> get props => [recipient, failureMessage];
}

final class ChatMessagePinRequested extends ChatEvent {
  const ChatMessagePinRequested({
    required this.message,
    required this.pin,
    required this.chat,
    required this.roomState,
  });

  final Message message;
  final bool pin;
  final Chat chat;
  final RoomState? roomState;

  @override
  List<Object?> get props => [message, pin, chat, roomState];
}

final class ChatMessageCollectionMembershipChanged extends ChatEvent {
  const ChatMessageCollectionMembershipChanged({
    required this.message,
    required this.collectionId,
    required this.chat,
    required this.active,
  });

  final Message message;
  final String collectionId;
  final Chat chat;
  final bool active;

  @override
  List<Object?> get props => [message, collectionId, chat, active];
}

final class ChatMessageReactionToggled extends ChatEvent {
  const ChatMessageReactionToggled({
    required this.message,
    required this.emoji,
    this.completer,
  });

  final Message message;
  final String emoji;
  final Completer<bool>? completer;

  @override
  List<Object?> get props => [message, emoji, completer];
}

final class ChatMessageForwardRequested extends ChatEvent {
  const ChatMessageForwardRequested({required this.message});

  final Message message;

  @override
  List<Object?> get props => [message];
}

final class ChatForwardDraftConsumed extends ChatEvent {
  const ChatForwardDraftConsumed();

  @override
  List<Object?> get props => const [];
}

final class ChatMessageResendRequested extends ChatEvent {
  const ChatMessageResendRequested({
    required this.message,
    required this.chatType,
  });

  final Message message;
  final ChatType chatType;

  @override
  List<Object?> get props => [message, chatType];
}

final class ChatMessageEditRequested extends ChatEvent {
  const ChatMessageEditRequested(this.message, {this.attachmentsCompleter});

  final Message message;
  final Completer<List<PendingAttachment>>? attachmentsCompleter;

  @override
  List<Object?> get props => [message, attachmentsCompleter];
}

final class ChatComposerErrorCleared extends ChatEvent {
  const ChatComposerErrorCleared();

  @override
  List<Object?> get props => const [];
}

final class ChatAttachmentPicked extends ChatEvent {
  const ChatAttachmentPicked({
    required this.attachment,
    required this.recipients,
    required this.chat,
    required this.quotedDraft,
    required this.completer,
  });

  final Attachment attachment;
  final List<ComposerRecipient> recipients;
  final Chat chat;
  final Message? quotedDraft;
  final CancelableCompleter<PendingAttachment?> completer;

  @override
  List<Object?> get props => [
    attachment,
    recipients,
    chat,
    quotedDraft,
    completer,
  ];
}

final class ChatAttachmentRetryRequested extends ChatEvent {
  const ChatAttachmentRetryRequested({
    required this.attachment,
    required this.recipients,
    required this.chat,
    required this.quotedDraft,
    required this.subject,
    required this.settings,
    required this.supportsHttpFileUpload,
    required this.completer,
  });

  final PendingAttachment attachment;
  final List<ComposerRecipient> recipients;
  final Chat chat;
  final Message? quotedDraft;
  final String? subject;
  final ChatSettingsSnapshot settings;
  final bool supportsHttpFileUpload;
  final Completer<PendingAttachment?> completer;

  @override
  List<Object?> get props => [
    attachment,
    recipients,
    chat,
    quotedDraft,
    subject,
    settings,
    supportsHttpFileUpload,
    completer,
  ];
}

final class ChatDemoPendingAttachmentsRequested extends ChatEvent {
  const ChatDemoPendingAttachmentsRequested({
    required this.chat,
    required this.existingFileNames,
    required this.completer,
  });

  final Chat chat;
  final Set<String> existingFileNames;
  final Completer<List<PendingAttachment>> completer;

  @override
  List<Object?> get props => [chat, existingFileNames, completer];
}

final class ChatInviteRequested extends ChatEvent {
  const ChatInviteRequested(
    this.jid, {
    required this.chat,
    required this.roomState,
    this.reason,
  });

  final String jid;
  final Chat chat;
  final RoomState? roomState;
  final String? reason;

  @override
  List<Object?> get props => [jid, chat, roomState, reason];
}

final class ChatModerationActionRequested extends ChatEvent {
  const ChatModerationActionRequested({
    required this.occupantId,
    required this.action,
    required this.actionLabel,
    required this.chat,
    required this.roomState,
    this.reason,
    this.completer,
  });

  final String occupantId;
  final MucModerationAction action;
  final String actionLabel;
  final Chat chat;
  final RoomState? roomState;
  final String? reason;
  final Completer<void>? completer;

  @override
  List<Object?> get props => [
    occupantId,
    action,
    actionLabel,
    chat,
    roomState,
    reason,
    completer,
  ];
}

final class ChatViewFilterChanged extends ChatEvent {
  const ChatViewFilterChanged({
    required this.filter,
    required this.chatJid,
    this.persist = true,
  });

  final MessageTimelineFilter filter;
  final String chatJid;
  final bool persist;

  @override
  List<Object?> get props => [filter, chatJid, persist];
}

final class ChatFanOutRetryRequested extends ChatEvent {
  const ChatFanOutRetryRequested({
    required this.draft,
    required this.recipients,
    required this.chat,
    required this.settings,
  });

  final FanOutDraft draft;
  final List<ComposerRecipient> recipients;
  final Chat chat;
  final ChatSettingsSnapshot settings;

  @override
  List<Object?> get props => [draft, recipients, chat, settings];
}

final class ChatSubjectChanged extends ChatEvent {
  const ChatSubjectChanged(this.subject);

  final String subject;

  @override
  List<Object?> get props => [subject];
}

final class ChatInviteRevocationRequested extends ChatEvent {
  const ChatInviteRevocationRequested({
    required this.message,
    required this.inviteeJidFallback,
  });

  final Message message;
  final String? inviteeJidFallback;

  @override
  List<Object?> get props => [message, inviteeJidFallback];
}

final class ChatInviteJoinRequested extends ChatEvent {
  const ChatInviteJoinRequested(this.message);

  final Message message;

  @override
  List<Object?> get props => const [];
}

final class ChatLeaveRoomRequested extends ChatEvent {
  const ChatLeaveRoomRequested({
    required this.chatJid,
    required this.chatType,
    this.completer,
  });

  final String chatJid;
  final ChatType chatType;
  final Completer<void>? completer;

  @override
  List<Object?> get props => [chatJid, chatType, completer];
}

final class ChatDestroyRoomRequested extends ChatEvent {
  const ChatDestroyRoomRequested({
    required this.chatJid,
    required this.chatType,
    this.completer,
  });

  final String chatJid;
  final ChatType chatType;
  final Completer<void>? completer;

  @override
  List<Object?> get props => [chatJid, chatType, completer];
}

final class ChatNicknameChangeRequested extends ChatEvent {
  const ChatNicknameChangeRequested({
    required this.nickname,
    required this.chatJid,
    required this.chatType,
  });

  final String nickname;
  final String chatJid;
  final ChatType chatType;

  @override
  List<Object?> get props => [nickname, chatJid, chatType];
}

final class ChatRoomAvatarChangeRequested extends ChatEvent {
  const ChatRoomAvatarChangeRequested({
    required this.avatar,
    required this.chat,
    required this.roomState,
  });

  final AvatarUploadPayload avatar;
  final Chat chat;
  final RoomState roomState;

  @override
  List<Object?> get props => [avatar.hash, chat, roomState];
}

final class ChatContactRenameRequested extends ChatEvent {
  const ChatContactRenameRequested(
    this.displayName, {
    required this.chat,
    required this.successMessage,
    required this.failureMessage,
  });

  final String displayName;
  final Chat chat;
  final String successMessage;
  final String failureMessage;

  @override
  List<Object?> get props => [
    displayName,
    chat,
    successMessage,
    failureMessage,
  ];
}
