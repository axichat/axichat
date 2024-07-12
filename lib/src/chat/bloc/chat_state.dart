part of 'chat_bloc.dart';

sealed class ChatState extends Equatable {
  const ChatState({required this.items});

  final List<Message> items;

  @override
  List<Object?> get props => [items];
}

final class ChatInitial extends ChatState {
  const ChatInitial({required super.items});
}

final class ChatAvailable extends ChatState {
  const ChatAvailable({required super.items});
}
