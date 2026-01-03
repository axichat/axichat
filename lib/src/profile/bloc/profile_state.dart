// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'profile_cubit.dart';

@Freezed(toJson: false, fromJson: false)
class ProfileState with _$ProfileState {
  const factory ProfileState({
    required String jid,
    required String resource,
    required String username,
    String? avatarPath,
    String? avatarHash,
    OmemoFingerprint? fingerprint,
    @Default(false) bool regenerating,
    Presence? presence,
    String? status,
  }) = _ProfileState;
}
