// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'email_demo_cubit.dart';

enum EmailDemoStatus {
  idle,
  loginToProvision,
  notProvisioned,
  ready,
  provisioning,
  provisioned,
  provisionFailed,
  provisionFirst,
  sending,
  sent,
  sendFailed,
}

enum EmailDemoFailure {
  missingProfile,
  missingPrefix,
  missingPassphrase,
  unexpected,
}

@freezed
abstract class EmailDemoState with _$EmailDemoState {
  const factory EmailDemoState({
    required EmailDemoStatus status,
    required EmailAccount? account,
    required EmailDemoFailure? failure,
    required String? detail,
  }) = _EmailDemoState;
}
