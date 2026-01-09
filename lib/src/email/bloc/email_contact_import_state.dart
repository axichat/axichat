// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'email_contact_import_cubit.dart';

sealed class EmailContactImportState extends Equatable {
  const EmailContactImportState();

  @override
  List<Object?> get props => const [];
}

final class EmailContactImportInitial extends EmailContactImportState {
  const EmailContactImportInitial();
}

final class EmailContactImportInProgress extends EmailContactImportState {
  const EmailContactImportInProgress();
}

final class EmailContactImportSuccess extends EmailContactImportState {
  const EmailContactImportSuccess(this.summary);

  final EmailContactImportSummary summary;

  @override
  List<Object?> get props => [summary];
}

final class EmailContactImportFailure extends EmailContactImportState {
  const EmailContactImportFailure(this.reason);

  final EmailContactImportFailureReason reason;

  @override
  List<Object?> get props => [reason];
}
