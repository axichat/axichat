part of 'verification_cubit.dart';

@freezed
class VerificationState with _$VerificationState {
  const factory VerificationState({
    @Default([]) List<OmemoFingerprint> fingerprints,
    @Default([]) List<OmemoFingerprint> myFingerprints,
    @Default(false) bool loading,
  }) = _VerificationState;
}
