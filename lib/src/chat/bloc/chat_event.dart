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

final class ChatMessageFocused extends ChatEvent {
  const ChatMessageFocused(this.messageID);

  final String messageID;

  @override
  List<Object?> get props => [messageID];
}

final class ChatMessageUnfocused extends ChatEvent {
  const ChatMessageUnfocused();

  @override
  List<Object?> get props => [];
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
