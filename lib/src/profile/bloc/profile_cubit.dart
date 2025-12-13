import 'dart:async';

import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_cubit.freezed.dart';
part 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required XmppService xmppService,
    PresenceService? presenceService,
    OmemoService? omemoService,
  })  : _xmppService = xmppService,
        _presenceService = presenceService,
        _omemoService = omemoService,
        super(
          ProfileState(
            jid: xmppService.myJid ?? '',
            resource: xmppService.resource ?? '',
            username: xmppService.username ?? '',
            presence: presenceService?.presence,
            status: presenceService?.status,
          ),
        ) {
    _presenceSubscription = _presenceService?.presenceStream.listen(
      (presence) =>
          emit(state.copyWith(presence: presence ?? Presence.unknown)),
    );
    _statusSubscription = _presenceService?.statusStream.listen(
      (status) => emit(state.copyWith(status: status)),
    );
    _selfAvatarSubscription = _xmppService.selfAvatarStream.listen(
      (avatar) {
        if (avatar == null || avatar.isEmpty) {
          emit(state.copyWith(avatarPath: null, avatarHash: null));
          return;
        }
        emit(
          state.copyWith(
            avatarPath: avatar.path ?? state.avatarPath,
            avatarHash: avatar.hash ?? state.avatarHash,
          ),
        );
      },
    );
    unawaited(_loadAvatar());
    if (_omemoService != null) {
      loadFingerprints();
    }
  }

  final XmppService _xmppService;
  final PresenceService? _presenceService;
  final OmemoService? _omemoService;

  late final StreamSubscription<Presence?>? _presenceSubscription;
  late final StreamSubscription<String?>? _statusSubscription;
  late final StreamSubscription<StoredAvatar?> _selfAvatarSubscription;

  @override
  Future<void> close() async {
    await _presenceSubscription?.cancel();
    await _statusSubscription?.cancel();
    await _selfAvatarSubscription.cancel();
    return super.close();
  }

  Future<void> updatePresence({Presence? presence, String? status}) async {
    try {
      await _presenceService?.sendPresence(
        presence: presence ?? state.presence,
        status: status ?? state.status,
      );
    } on XmppPresenceException catch (_) {}
  }

  Future<void> loadFingerprints() async {
    if (_omemoService == null) return;
    final fingerprint = await _omemoService.getCurrentFingerprint();
    emit(state.copyWith(fingerprint: fingerprint));
  }

  Future<void> regenerateDevice() async {
    if (_omemoService == null) return;
    emit(state.copyWith(regenerating: true));
    await _omemoService.regenerateDevice();
    await loadFingerprints();
    emit(state.copyWith(regenerating: false));
  }

  Future<void> _loadAvatar() async {
    final stored = await _xmppService.getOwnAvatar();
    if (stored == null || stored.isEmpty) return;
    emit(
      state.copyWith(
        avatarPath: stored.path ?? state.avatarPath,
        avatarHash: stored.hash ?? state.avatarHash,
      ),
    );
  }

  void updateAvatar({
    String? path,
    String? hash,
  }) {
    emit(
      state.copyWith(
        avatarPath: path ?? state.avatarPath,
        avatarHash: hash ?? state.avatarHash,
      ),
    );
  }
}
