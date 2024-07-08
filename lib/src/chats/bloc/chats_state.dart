part of 'chats_bloc.dart';

sealed class ChatsState extends Equatable {
  const ChatsState();
}

final class ChatsInitial extends ChatsState {
  @override
  List<Object> get props => [];
}
