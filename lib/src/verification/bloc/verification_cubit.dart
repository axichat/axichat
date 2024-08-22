import 'package:bloc/bloc.dart';
import 'package:chat/src/storage/database.dart';
import 'package:chat/src/storage/models.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'verification_cubit.freezed.dart';
part 'verification_state.dart';

class VerificationCubit extends Cubit<VerificationState> {
  VerificationCubit({
    required this.jid,
    required XmppService xmppService,
  })  : _xmppService = xmppService,
        super(const VerificationState(loading: true)) {
    _loadFingerprints();
  }

  final String jid;
  final XmppService _xmppService;

  Future<void> _loadFingerprints() async {
    // final fingerprints = await _xmppService.getFingerprints(jid: jid);
    // emit(state.copyWith(fingerprints: fingerprints, loading: false));
  }

  Future<void> setDeviceTrust({
    required int device,
    required BTBVTrustState trust,
  }) async {
    emit(state.copyWith(loading: true));
    // await _xmppService.setDeviceTrust(jid: jid, device: device, trust: trust);
    await _loadFingerprints();
  }

  Future<void> recreateSession() async {
    emit(state.copyWith(loading: true));
    // await _xmppService.recreateSessions(jid: jid);
    await _loadFingerprints();
  }
}
