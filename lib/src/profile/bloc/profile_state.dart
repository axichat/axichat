part of 'profile_cubit.dart';

@Freezed(toJson: false, fromJson: false)
class ProfileState with _$ProfileState {
  const factory ProfileState({
    required String jid,
    required String title,
    @Default(Presence.chat) Presence presence,
    String? status,
  }) = _ProfileState;
}
