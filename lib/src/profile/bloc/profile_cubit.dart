import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:chat/src/storage/models.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_cubit.freezed.dart';
part 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({required PresenceService presenceService})
      : _presenceService = presenceService,
        super(
          ProfileState(
            jid: presenceService.myJid ?? '',
            resource: presenceService.resource ?? '',
            title: presenceService.username ?? '',
            presence: presenceService.presence,
            status: presenceService.status,
          ),
        ) {
    _presenceSubscription = _presenceService.presenceStream.listen(
      (presence) =>
          emit(state.copyWith(presence: presence ?? Presence.unknown)),
    );
    _statusSubscription = _presenceService.statusStream.listen(
      (status) => emit(state.copyWith(status: status)),
    );
  }

  final PresenceService _presenceService;

  late final StreamSubscription<Presence?> _presenceSubscription;
  late final StreamSubscription<String?> _statusSubscription;

  @override
  Future<void> close() async {
    await _presenceSubscription.cancel();
    await _statusSubscription.cancel();
    return super.close();
  }

  Future<void> updatePresence({Presence? presence, String? status}) async {
    try {
      await _presenceService.sendPresence(
        presence: presence ?? state.presence,
        status: status ?? state.status,
      );
    } on XmppPresenceException catch (_) {}
  }

  // Future<void> disconnect() => _xmppService.disconnect();

  void loadFingerprints() async {
    // final fingerprint = await _xmppService.getCurrentFingerprint();
    // emit(state.copyWith(fingerprint: fingerprint));
  }
}
