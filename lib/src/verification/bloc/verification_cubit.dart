// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'verification_cubit.freezed.dart';
part 'verification_state.dart';

class VerificationCubit extends Cubit<VerificationState> {
  VerificationCubit({required this.jid, required OmemoService omemoService})
    : _omemoService = omemoService,
      super(const VerificationState(loading: true)) {
    _initialize();
  }

  final String jid;
  final OmemoService _omemoService;

  Future<void> _initialize() async {
    try {
      await _omemoService.populateTrustCache(jid: jid);
      await _loadFingerprints();
    } finally {
      _clearLoadingIfNeeded();
    }
  }

  Future<void> loadFingerprints() async {
    if (state.loading) return;
    emit(state.copyWith(loading: true));
    try {
      await _loadFingerprints();
    } finally {
      _clearLoadingIfNeeded();
    }
  }

  Future<void> _loadFingerprints() async {
    final fingerprints = await _omemoService.getFingerprints(jid: jid);
    final myFingerprints = await _omemoService.getFingerprints(
      jid: _omemoService.myJid!,
    );
    emit(
      state.copyWith(
        fingerprints: fingerprints,
        myFingerprints: myFingerprints,
        loading: false,
      ),
    );
  }

  Future<void> setDeviceTrust({
    required String jid,
    required int device,
    required BTBVTrustState trust,
  }) async {
    if (state.loading) return;
    emit(state.copyWith(loading: true));
    try {
      await _omemoService.setDeviceTrust(
        jid: jid,
        device: device,
        trust: trust,
      );
      await _loadFingerprints();
    } finally {
      _clearLoadingIfNeeded();
    }
  }

  Future<void> labelFingerprint({
    required String jid,
    required int device,
    required String label,
  }) async {
    if (state.loading) return;
    emit(state.copyWith(loading: true));
    try {
      await _omemoService.labelFingerprint(
        jid: jid,
        device: device,
        label: label,
      );
      await _loadFingerprints();
    } finally {
      _clearLoadingIfNeeded();
    }
  }

  void _clearLoadingIfNeeded() {
    if (state.loading) {
      emit(state.copyWith(loading: false));
    }
  }
}
