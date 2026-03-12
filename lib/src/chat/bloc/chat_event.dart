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

final class _PinnedMessagesUpdated extends ChatEvent {
  const _PinnedMessagesUpdated(this.items);

  final List<PinnedMessageEntry> items;

  @override
  List<Object?> get props => [items];
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

  final StoredAvatar? avatar;

  @override
  List<Object?> get props => [avatar];
}

final class _EmailSyncStateChanged extends ChatEvent {
  const _EmailSyncStateChanged(this.state);

  final EmailSyncState state;

  @override
  List<Object?> get props => [state];
}

final class _EmailContactKnownChanged extends ChatEvent {
  const _EmailContactKnownChanged(this.known);

  final bool known;

  @override
  List<Object?> get props => [known];
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

final class ChatEmailDebugDumpRequested extends ChatEvent {
  const ChatEmailDebugDumpRequested(this.message);

  final Message message;

  @override
  List<Object?> get props => [message];
}

final class ChatEmailFullHtmlRequested extends ChatEvent {
  const ChatEmailFullHtmlRequested(this.message);

  final Message message;

  @override
  List<Object?> get props => [message];
}

final class ChatEmailQuotedTextRequested extends ChatEvent {
  const ChatEmailQuotedTextRequested(this.message);

  final Message message;

  @override
  List<Object?> get props => [message];
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

final class ChatLoadEarlier extends ChatEvent {
  const ChatLoadEarlier({this.completer});

  final Completer<void>? completer;

  @override
  List<Object?> get props => [completer];
}

final class ChatShareSignatureToggled extends ChatEvent {
  const ChatShareSignatureToggled({required this.chat, required this.enabled});

  final Chat chat;
  final bool enabled;

  @override
  List<Object?> get props => [chat, enabled];
}

final class ChatAttachmentAutoDownloadToggled extends ChatEvent {
  const ChatAttachmentAutoDownloadToggled({
    required this.chat,
    required this.enabled,
  });

  final Chat chat;
  final bool enabled;

  @override
  List<Object?> get props => [chat, enabled];
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
  final bool responsive;

  @override
  List<Object?> get props => [chatJid, responsive];
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
    required this.successMessage,
    required this.failureMessage,
  });

  final Chat chat;
  final String successMessage;
  final String failureMessage;

  @override
  List<Object?> get props => [chat, successMessage, failureMessage];
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

final class ChatQuoteRequested extends ChatEvent {
  const ChatQuoteRequested(this.message);

  final Message message;

  @override
  List<Object?> get props => const [];
}

final class ChatQuoteCleared extends ChatEvent {
  const ChatQuoteCleared();

  @override
  List<Object?> get props => [];
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

final class ChatMessageImportantToggled extends ChatEvent {
  const ChatMessageImportantToggled({
    required this.message,
    required this.important,
    required this.chat,
  });

  final Message message;
  final bool important;
  final Chat chat;

  @override
  List<Object?> get props => [message, important, chat];
}

final class ChatMessageReactionToggled extends ChatEvent {
  const ChatMessageReactionToggled({
    required this.message,
    required this.emoji,
    required this.isEmailChat,
    this.completer,
  });

  final Message message;
  final String emoji;
  final bool isEmailChat;
  final Completer<bool>? completer;

  @override
  List<Object?> get props => [message, emoji, isEmailChat, completer];
}

final class ChatMessageForwardRequested extends ChatEvent {
  const ChatMessageForwardRequested({
    required this.message,
    required this.target,
  });

  final Message message;
  final FanOutTarget target;

  @override
  List<Object?> get props => [message, target];
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
  const ChatMessageEditRequested(this.message);

  final Message message;

  @override
  List<Object?> get props => const [];
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
  });

  final EmailAttachment attachment;
  final List<ComposerRecipient> recipients;
  final Chat chat;
  final Message? quotedDraft;

  @override
  List<Object?> get props => [attachment, recipients, chat, quotedDraft];
}

final class ChatAttachmentRetryRequested extends ChatEvent {
  const ChatAttachmentRetryRequested({
    required this.attachmentId,
    required this.recipients,
    required this.chat,
    required this.quotedDraft,
    required this.subject,
    required this.settings,
    required this.supportsHttpFileUpload,
  });

  final String attachmentId;
  final List<ComposerRecipient> recipients;
  final Chat chat;
  final Message? quotedDraft;
  final String? subject;
  final ChatSettingsSnapshot settings;
  final bool supportsHttpFileUpload;

  @override
  List<Object?> get props => [
    attachmentId,
    recipients,
    chat,
    quotedDraft,
    subject,
    settings,
    supportsHttpFileUpload,
  ];
}

final class ChatPendingAttachmentRemoved extends ChatEvent {
  const ChatPendingAttachmentRemoved(this.attachmentId);

  final String attachmentId;

  @override
  List<Object?> get props => [attachmentId];
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
