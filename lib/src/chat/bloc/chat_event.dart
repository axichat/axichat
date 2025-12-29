part of 'chat_bloc.dart';

enum EmailForwardingMode {
  original,
  safe,
}

extension EmailForwardingModeExtensions on EmailForwardingMode {
  bool get isOriginal => this == EmailForwardingMode.original;

  bool get isSafe => this == EmailForwardingMode.safe;
}

sealed class ChatEvent extends Equatable {
  const ChatEvent();
}

final class _ChatUpdated extends ChatEvent {
  const _ChatUpdated(this.chat);

  final Chat chat;

  @override
  List<Object?> get props => [chat];
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

final class ChatPinnedMessagesOpened extends ChatEvent {
  const ChatPinnedMessagesOpened();

  @override
  List<Object?> get props => [];
}

final class _RoomStateUpdated extends ChatEvent {
  const _RoomStateUpdated(this.roomState);

  final RoomState roomState;

  @override
  List<Object?> get props => [roomState];
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

final class ChatMessageFocused extends ChatEvent {
  const ChatMessageFocused(this.messageID);

  final String? messageID;

  @override
  List<Object?> get props => [messageID];
}

final class ChatEmailHeadersRequested extends ChatEvent {
  const ChatEmailHeadersRequested(this.deltaMessageId);

  final int deltaMessageId;

  @override
  List<Object?> get props => [deltaMessageId];
}

final class _ChatTypingStopped extends ChatEvent {
  const _ChatTypingStopped();

  @override
  List<Object?> get props => [];
}

final class ChatTypingStarted extends ChatEvent {
  const ChatTypingStarted();

  @override
  List<Object?> get props => [];
}

final class _TypingParticipantsUpdated extends ChatEvent {
  const _TypingParticipantsUpdated(this.participants);

  final List<String> participants;

  @override
  List<Object?> get props => [participants];
}

final class ChatMessageSent extends ChatEvent {
  const ChatMessageSent({
    required this.text,
    this.calendarTaskIcs,
    this.calendarTaskIcsReadOnly = CalendarTaskIcsMessage.defaultReadOnly,
  });

  final String text;
  final CalendarTask? calendarTaskIcs;
  final bool calendarTaskIcsReadOnly;

  @override
  List<Object?> get props => [text, calendarTaskIcs, calendarTaskIcsReadOnly];
}

final class ChatAvailabilityMessageSent extends ChatEvent {
  const ChatAvailabilityMessageSent({
    required this.message,
  });

  final CalendarAvailabilityMessage message;

  @override
  List<Object?> get props => [message];
}

final class ChatMuted extends ChatEvent {
  const ChatMuted(this.muted);

  final bool muted;

  @override
  List<Object?> get props => [muted];
}

final class ChatNotificationPreviewSettingChanged extends ChatEvent {
  const ChatNotificationPreviewSettingChanged(this.setting);

  final NotificationPreviewSetting setting;

  @override
  List<Object?> get props => [setting];
}

final class ChatShareSignatureToggled extends ChatEvent {
  const ChatShareSignatureToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

final class ChatAttachmentAutoDownloadToggled extends ChatEvent {
  const ChatAttachmentAutoDownloadToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

final class ChatResponsivityChanged extends ChatEvent {
  const ChatResponsivityChanged(this.responsive);

  final bool responsive;

  @override
  List<Object?> get props => [responsive];
}

final class ChatEncryptionChanged extends ChatEvent {
  const ChatEncryptionChanged({required this.protocol});

  final EncryptionProtocol protocol;

  @override
  List<Object?> get props => [protocol];
}

final class ChatEncryptionRepaired extends ChatEvent {
  const ChatEncryptionRepaired();

  @override
  List<Object?> get props => [];
}

final class ChatLoadEarlier extends ChatEvent {
  const ChatLoadEarlier();

  @override
  List<Object?> get props => [];
}

final class ChatAlertHidden extends ChatEvent {
  const ChatAlertHidden({this.forever = false});

  final bool forever;

  @override
  List<Object?> get props => [forever];
}

final class ChatQuoteRequested extends ChatEvent {
  const ChatQuoteRequested(this.message);

  final Message message;

  @override
  List<Object?> get props => [message];
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
  });

  final Message message;
  final bool pin;

  @override
  List<Object?> get props => [message, pin];
}

final class ChatMessageReactionToggled extends ChatEvent {
  const ChatMessageReactionToggled({
    required this.message,
    required this.emoji,
  });

  final Message message;
  final String emoji;

  @override
  List<Object?> get props => [message, emoji];
}

final class ChatMessageForwardRequested extends ChatEvent {
  const ChatMessageForwardRequested({
    required this.message,
    required this.target,
    this.forwardingMode = EmailForwardingMode.original,
  });

  final Message message;
  final Chat target;
  final EmailForwardingMode forwardingMode;

  @override
  List<Object?> get props => [message, target, forwardingMode];
}

final class ChatMessageResendRequested extends ChatEvent {
  const ChatMessageResendRequested(this.message);

  final Message message;

  @override
  List<Object?> get props => [message];
}

final class ChatMessageEditRequested extends ChatEvent {
  const ChatMessageEditRequested(this.message);

  final Message message;

  @override
  List<Object?> get props => [message];
}

final class ChatAttachmentPicked extends ChatEvent {
  const ChatAttachmentPicked(this.attachment);

  final EmailAttachment attachment;

  @override
  List<Object?> get props => [attachment];
}

final class ChatAttachmentRetryRequested extends ChatEvent {
  const ChatAttachmentRetryRequested(this.attachmentId);

  final String attachmentId;

  @override
  List<Object?> get props => [attachmentId];
}

final class ChatPendingAttachmentRemoved extends ChatEvent {
  const ChatPendingAttachmentRemoved(this.attachmentId);

  final String attachmentId;

  @override
  List<Object?> get props => [attachmentId];
}

final class ChatInviteRequested extends ChatEvent {
  const ChatInviteRequested(this.jid, {this.reason});

  final String jid;
  final String? reason;

  @override
  List<Object?> get props => [jid, reason];
}

final class ChatModerationActionRequested extends ChatEvent {
  const ChatModerationActionRequested({
    required this.occupantId,
    required this.action,
    this.reason,
  });

  final String occupantId;
  final MucModerationAction action;
  final String? reason;

  @override
  List<Object?> get props => [occupantId, action, reason];
}

final class ChatViewFilterChanged extends ChatEvent {
  const ChatViewFilterChanged({
    required this.filter,
    this.persist = true,
  });

  final MessageTimelineFilter filter;
  final bool persist;

  @override
  List<Object?> get props => [filter, persist];
}

final class ChatComposerRecipientAdded extends ChatEvent {
  const ChatComposerRecipientAdded(this.target);

  final FanOutTarget target;

  @override
  List<Object?> get props => [target];
}

final class ChatComposerRecipientRemoved extends ChatEvent {
  const ChatComposerRecipientRemoved(this.recipientKey);

  final String recipientKey;

  @override
  List<Object?> get props => [recipientKey];
}

final class ChatComposerRecipientToggled extends ChatEvent {
  const ChatComposerRecipientToggled(this.recipientKey, {this.included});

  final String recipientKey;
  final bool? included;

  @override
  List<Object?> get props => [recipientKey, included];
}

final class ChatFanOutRetryRequested extends ChatEvent {
  const ChatFanOutRetryRequested(this.shareId);

  final String shareId;

  @override
  List<Object?> get props => [shareId];
}

final class ChatSubjectChanged extends ChatEvent {
  const ChatSubjectChanged(this.subject);

  final String subject;

  @override
  List<Object?> get props => [subject];
}

final class ChatInviteRevocationRequested extends ChatEvent {
  const ChatInviteRevocationRequested(this.message);

  final Message message;

  @override
  List<Object?> get props => [message];
}

final class ChatInviteJoinRequested extends ChatEvent {
  const ChatInviteJoinRequested(this.message);

  final Message message;

  @override
  List<Object?> get props => [message];
}

final class ChatLeaveRoomRequested extends ChatEvent {
  const ChatLeaveRoomRequested();

  @override
  List<Object?> get props => [];
}

final class ChatNicknameChangeRequested extends ChatEvent {
  const ChatNicknameChangeRequested(this.nickname);

  final String nickname;

  @override
  List<Object?> get props => [nickname];
}

final class ChatContactRenameRequested extends ChatEvent {
  const ChatContactRenameRequested(
    this.displayName, {
    required this.successMessage,
    required this.failureMessage,
  });

  final String displayName;
  final String successMessage;
  final String failureMessage;

  @override
  List<Object?> get props => [displayName, successMessage, failureMessage];
}

final class ChatEmailImagesLoaded extends ChatEvent {
  const ChatEmailImagesLoaded(this.messageId);

  final String messageId;

  @override
  List<Object?> get props => [messageId];
}
