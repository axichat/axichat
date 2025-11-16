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

final class _ChatMessagesUpdated extends ChatEvent {
  const _ChatMessagesUpdated(this.items);

  final List<Message> items;

  @override
  List<Object?> get props => [items];
}

final class _EmailSyncStateChanged extends ChatEvent {
  const _EmailSyncStateChanged(this.state);

  final EmailSyncState state;

  @override
  List<Object?> get props => [state];
}

final class ChatMessageFocused extends ChatEvent {
  const ChatMessageFocused(this.messageID);

  final String? messageID;

  @override
  List<Object?> get props => [messageID];
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

final class ChatMessageSent extends ChatEvent {
  const ChatMessageSent({required this.text});

  final String text;

  @override
  List<Object?> get props => [text];
}

final class ChatMuted extends ChatEvent {
  const ChatMuted(this.muted);

  final bool muted;

  @override
  List<Object?> get props => [muted];
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
  });

  final Message message;
  final Chat target;

  @override
  List<Object?> get props => [message, target];
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
