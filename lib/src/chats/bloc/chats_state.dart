part of 'chats_cubit.dart';

@Freezed(toJson: false, fromJson: false)
class ChatsState with _$ChatsState {
  const factory ChatsState({
    required String? openJid,
    @Default(<String>[]) List<String> openStack,
    @Default(<String>[]) List<String> forwardStack,
    required bool openCalendar,
    @Default(false) bool openChatCalendar,
    required List<Chat>? items,
    required RequestStatus creationStatus,
    @Default(RequestStatus.none) RequestStatus refreshStatus,
    DateTime? lastSyncedAt,
    @Default(<String>{}) Set<String> selectedJids,
  }) = _ChatsState;
}
