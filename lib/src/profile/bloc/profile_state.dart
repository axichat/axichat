part of 'profile_cubit.dart';

@Freezed(toJson: false, fromJson: false)
class ProfileState with _$ProfileState {
  const factory ProfileState({
    required String jid,
    required String resource,
    required String title,
    @Default('') String fingerprint,
    @Default(Presence.chat) Presence presence,
    String? status,
  }) = _ProfileState;
}
