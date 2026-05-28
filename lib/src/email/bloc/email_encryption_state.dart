// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'email_encryption_cubit.dart';

enum EmailEncryptionFailureReason {
  noActiveAccount,
  unsupportedKeyFormat,
  noPrivateKeyFound,
  ambiguousKeyArchive,
  importFailed,
  exportFailed,
  saveFailed,
}

sealed class EmailEncryptionState extends Equatable {
  const EmailEncryptionState();

  bool get isBusy => false;

  @override
  List<Object?> get props => const [];
}

final class EmailEncryptionIdle extends EmailEncryptionState {
  const EmailEncryptionIdle({this.account});

  final EmailEncryptionAccountInfo? account;

  @override
  List<Object?> get props => [account];
}

final class EmailEncryptionImportRunning extends EmailEncryptionState {
  const EmailEncryptionImportRunning();

  @override
  bool get isBusy => true;
}

final class EmailEncryptionSelfKeyConfirmationRequired
    extends EmailEncryptionState {
  const EmailEncryptionSelfKeyConfirmationRequired({
    required this.path,
    required this.metadata,
  });

  final String path;
  final EmailOpenPgpKeyMetadata metadata;

  @override
  List<Object?> get props => [path, metadata];
}

final class EmailEncryptionExportRunning extends EmailEncryptionState {
  const EmailEncryptionExportRunning();

  @override
  bool get isBusy => true;
}

final class EmailEncryptionExportReady extends EmailEncryptionState {
  const EmailEncryptionExportReady({required this.normalizedAddress});

  final String normalizedAddress;

  @override
  List<Object?> get props => [normalizedAddress];
}

final class EmailEncryptionSaveRunning extends EmailEncryptionState {
  const EmailEncryptionSaveRunning(this.normalizedAddress);

  final String normalizedAddress;

  @override
  bool get isBusy => true;

  @override
  List<Object?> get props => [normalizedAddress];
}

final class EmailEncryptionActivationReady extends EmailEncryptionState {
  const EmailEncryptionActivationReady(this.normalizedAddress);

  final String normalizedAddress;

  @override
  List<Object?> get props => [normalizedAddress];
}

final class EmailEncryptionDisableReady extends EmailEncryptionState {
  const EmailEncryptionDisableReady(this.normalizedAddress);

  final String normalizedAddress;

  @override
  List<Object?> get props => [normalizedAddress];
}

final class EmailEncryptionFailure extends EmailEncryptionState {
  const EmailEncryptionFailure(this.reason);

  final EmailEncryptionFailureReason reason;

  @override
  List<Object?> get props => [reason];
}
