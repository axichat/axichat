part of 'chat_bloc.dart';

@Freezed(toJson: false, fromJson: false)
class ChatState with _$ChatState {
  const factory ChatState({
    required List<Message> items,
    Chat? chat,
    Message? focused,
    @Default(false) bool typing,
  }) = _ChatState;
}
