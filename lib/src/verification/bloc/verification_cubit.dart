import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'verification_cubit.freezed.dart';
part 'verification_state.dart';

class VerificationCubit extends Cubit<VerificationState> {
  VerificationCubit({
    required this.jid,
    required OmemoService omemoService,
  })  : _omemoService = omemoService,
        super(const VerificationState(loading: true)) {
    loadFingerprints();
  }

  final String jid;
  final OmemoService _omemoService;

  Future<void> loadFingerprints() async {
    emit(state.copyWith(loading: true));
    final fingerprints = await _omemoService.getFingerprints(jid: jid);
    emit(state.copyWith(fingerprints: fingerprints, loading: false));
  }

  Future<void> setDeviceTrust({
    required int device,
    required BTBVTrustState trust,
  }) async {
    emit(state.copyWith(loading: true));
    await _omemoService.setDeviceTrust(jid: jid, device: device, trust: trust);
    await loadFingerprints();
  }
}
