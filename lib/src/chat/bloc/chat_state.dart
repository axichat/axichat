part of 'chat_bloc.dart';

@Freezed(toJson: false, fromJson: false)
class ChatState with _$ChatState {
  const factory ChatState({
    @Default(null) Chat? chat,
    required List<Message> items,
    @Default(bool) bool typing,
  }) = _ChatState;
}
