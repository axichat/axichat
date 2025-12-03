part of 'chats_cubit.dart';

@Freezed(toJson: false, fromJson: false)
class ChatsState with _$ChatsState {
  const factory ChatsState({
    required String? openJid,
    @Default(<String>[]) List<String> openStack,
    @Default(<String>[]) List<String> forwardStack,
    required bool openCalendar,
    required List<Chat>? items,
    required RequestStatus creationStatus,
    @Default(<String>{}) Set<String> selectedJids,
  }) = _ChatsState;
}
