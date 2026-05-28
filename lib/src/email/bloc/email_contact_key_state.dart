// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'email_contact_key_cubit.dart';

enum EmailContactKeyFailureReason {
  noActiveAccount,
  unsupportedFormat,
  importFailed,
  removeFailed,
}

enum EmailContactKeySuccessKind { imported, removed }

sealed class EmailContactKeyState extends Equatable {
  const EmailContactKeyState();

  bool get isBusy => false;

  @override
  List<Object?> get props => const [];
}

final class EmailContactKeyIdle extends EmailContactKeyState {
  const EmailContactKeyIdle({
    this.account,
    this.trustedKey,
    this.normalizedAddress,
  });

  final EmailEncryptionAccountInfo? account;
  final EmailTrustedContactKey? trustedKey;
  final String? normalizedAddress;

  @override
  List<Object?> get props => [account, trustedKey, normalizedAddress];
}

final class EmailContactKeyInspecting extends EmailContactKeyState {
  const EmailContactKeyInspecting();

  @override
  bool get isBusy => true;
}

final class EmailContactKeyConfirmationRequired extends EmailContactKeyState {
  const EmailContactKeyConfirmationRequired(this.metadata);

  final EmailOpenPgpKeyMetadata metadata;

  @override
  List<Object?> get props => [metadata];
}

final class EmailContactKeyImporting extends EmailContactKeyState {
  const EmailContactKeyImporting();

  @override
  bool get isBusy => true;
}

final class EmailContactKeyRemoving extends EmailContactKeyState {
  const EmailContactKeyRemoving();

  @override
  bool get isBusy => true;
}

final class EmailContactKeySuccess extends EmailContactKeyState {
  const EmailContactKeySuccess(this.kind);

  final EmailContactKeySuccessKind kind;

  @override
  List<Object?> get props => [kind];
}

final class EmailContactKeyFailure extends EmailContactKeyState {
  const EmailContactKeyFailure(this.reason);

  final EmailContactKeyFailureReason reason;

  @override
  List<Object?> get props => [reason];
}
