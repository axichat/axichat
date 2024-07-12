part of 'chats_cubit.dart';

sealed class ChatsState extends Equatable {
  const ChatsState({required this.openJid, required this.items});

  final String? openJid;
  final List<Chat> items;

  @override
  List<Object?> get props => [items];
}

final class ChatsInitial extends ChatsState {
  const ChatsInitial({required super.openJid, required super.items});
}

final class ChatsAvailable extends ChatsState {
  const ChatsAvailable({required super.openJid, required super.items});
}
