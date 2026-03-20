// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:typed_data';

import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_cubit.freezed.dart';
part 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({required XmppService xmppService, OmemoService? omemoService})
    : _xmppService = xmppService,
      _omemoService = omemoService,
      super(
        ProfileState(
          jid: xmppService.myJid ?? '',
          resource: xmppService.resource ?? '',
          username: xmppService.username ?? '',
          avatarHydrating: xmppService.selfAvatarHydrating,
          avatarPath: xmppService.cachedSelfAvatar?.path,
          avatarHash: xmppService.cachedSelfAvatar?.hash,
        ),
      ) {
    _selfAvatarSubscription = _xmppService.selfAvatarStream.listen((avatar) {
      emit(
        state.copyWith(
          avatarPath: avatar?.path,
          avatarHash: avatar?.hash,
          avatarHydrating: _xmppService.selfAvatarHydrating,
        ),
      );
    });
    _selfAvatarHydratingSubscription = _xmppService.selfAvatarHydratingStream
        .listen(
          (hydrating) => emit(state.copyWith(avatarHydrating: hydrating)),
        );
    _storedConversationMessageCountSubscription = _xmppService
        .storedConversationMessageCountStream()
        .listen(
          (count) =>
              emit(state.copyWith(storedConversationMessageCount: count)),
        );
    unawaited(_hydrateStoredSelfAvatar());
    if (_omemoService != null) {
      loadFingerprints();
    }
  }

  final XmppService _xmppService;
  final OmemoService? _omemoService;

  late final StreamSubscription<Avatar?> _selfAvatarSubscription;
  late final StreamSubscription<bool> _selfAvatarHydratingSubscription;
  late final StreamSubscription<int>
  _storedConversationMessageCountSubscription;

  @override
  Future<void> close() async {
    await _selfAvatarSubscription.cancel();
    await _selfAvatarHydratingSubscription.cancel();
    await _storedConversationMessageCountSubscription.cancel();
    return super.close();
  }

  Future<void> loadFingerprints() async {
    if (_omemoService == null) return;
    final fingerprint = await _omemoService.getCurrentFingerprint();
    emit(state.copyWith(fingerprint: fingerprint));
  }

  Future<void> _hydrateStoredSelfAvatar() async {
    final avatar = await _xmppService.getOwnAvatar();
    emit(
      state.copyWith(
        avatarPath: avatar?.path,
        avatarHash: avatar?.hash,
        avatarHydrating: _xmppService.selfAvatarHydrating,
      ),
    );
  }

  void syncSessionIdentity() {
    emit(
      state.copyWith(
        jid: _xmppService.myJid ?? '',
        resource: _xmppService.resource ?? '',
        username: _xmppService.username ?? '',
        avatarPath: _xmppService.cachedSelfAvatar?.path,
        avatarHash: _xmppService.cachedSelfAvatar?.hash,
        avatarHydrating: _xmppService.selfAvatarHydrating,
      ),
    );
    if (_omemoService != null) {
      unawaited(loadFingerprints());
    }
  }

  void clearSessionIdentity() {
    emit(
      state.copyWith(
        jid: '',
        resource: '',
        username: '',
        avatarPath: null,
        avatarHash: null,
        avatarHydrating: false,
        fingerprint: null,
        storedConversationMessageCount: 0,
      ),
    );
  }

  Future<void> regenerateDevice() async {
    if (_omemoService == null) return;
    emit(state.copyWith(regenerating: true));
    await _omemoService.regenerateDevice();
    await loadFingerprints();
    emit(state.copyWith(regenerating: false));
  }

  Future<Uint8List?> resolveSafeAvatarBytes({String? path}) {
    final avatarPath = path?.trim() ?? state.avatarPath?.trim();
    if (avatarPath == null || avatarPath.isEmpty) {
      return Future<Uint8List?>.value(null);
    }
    return _xmppService.resolveSafeAvatarBytes(avatarPath: avatarPath);
  }
}
