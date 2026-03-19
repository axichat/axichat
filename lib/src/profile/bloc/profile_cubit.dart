// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

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
    _selfAvatarSubscription = _xmppService.selfAvatarStream.listen((
      avatar,
    ) async {
      if (avatar == null) {
        emit(
          state.copyWith(
            avatarPath: null,
            avatarHash: null,
            avatarHydrating: _xmppService.selfAvatarHydrating,
          ),
        );
        return;
      }
      final path = avatar.path.trim();
      if (path.isNotEmpty) {
        await _xmppService.loadAvatarBytes(path);
      }
      emit(
        state.copyWith(
          avatarPath: path,
          avatarHash: avatar.hash ?? state.avatarHash,
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
    unawaited(_loadAvatar());
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

  void syncSessionIdentity() {
    emit(
      state.copyWith(
        jid: _xmppService.myJid ?? '',
        resource: _xmppService.resource ?? '',
        username: _xmppService.username ?? '',
        avatarHydrating: _xmppService.selfAvatarHydrating,
      ),
    );
    unawaited(_loadAvatar());
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

  Future<void> _loadAvatar() async {
    final stored = await _xmppService.getOwnAvatar();
    if (stored == null) {
      emit(state.copyWith(avatarHydrating: _xmppService.selfAvatarHydrating));
      return;
    }
    final path = stored.path;
    await _xmppService.loadAvatarBytes(path);
    emit(
      state.copyWith(
        avatarPath: path,
        avatarHash: stored.hash ?? state.avatarHash,
        avatarHydrating: _xmppService.selfAvatarHydrating,
      ),
    );
  }

  void updateAvatar({String? path, String? hash}) {
    emit(
      state.copyWith(
        avatarPath: path ?? state.avatarPath,
        avatarHash: hash ?? state.avatarHash,
      ),
    );
  }
}
