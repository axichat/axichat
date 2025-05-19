part of 'chats_cubit.dart';

@Freezed(toJson: false, fromJson: false)
class ChatsState with _$ChatsState {
  const factory ChatsState({
    required String? openJid,
    required List<Chat>? items,
    required bool Function(Chat) filter,
    required RequestStatus creationStatus,
  }) = _ChatsState;
}
