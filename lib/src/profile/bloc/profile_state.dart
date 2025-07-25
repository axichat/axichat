part of 'profile_cubit.dart';

@Freezed(toJson: false, fromJson: false)
class ProfileState with _$ProfileState {
  const factory ProfileState({
    required String jid,
    required String resource,
    required String username,
    OmemoFingerprint? fingerprint,
    @Default(false) bool regenerating,
    @Default(Presence.unknown) Presence presence,
    String? status,
  }) = _ProfileState;
}
