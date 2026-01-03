// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:equatable/equatable.dart';

import 'delta_chat_exception.dart';

enum EmailSyncStatus { ready, offline, recovering, error }

class EmailSyncState extends Equatable {
  const EmailSyncState._(
    this.status, {
    this.message,
    this.exception,
    this.requiresAttention = false,
  });

  const EmailSyncState.ready()
      : this._(EmailSyncStatus.ready, message: null, exception: null);

  const EmailSyncState.offline(
    String message, {
    DeltaChatException? exception,
  }) : this._(
          EmailSyncStatus.offline,
          message: message,
          exception: exception,
          requiresAttention: true,
        );

  const EmailSyncState.recovering(String message)
      : this._(
          EmailSyncStatus.recovering,
          message: message,
        );

  const EmailSyncState.error(
    String message, {
    DeltaChatException? exception,
  }) : this._(
          EmailSyncStatus.error,
          message: message,
          exception: exception,
          requiresAttention: true,
        );

  final EmailSyncStatus status;
  final String? message;
  final DeltaChatException? exception;
  final bool requiresAttention;

  bool get isOffline => status == EmailSyncStatus.offline;

  bool get isRecovering => status == EmailSyncStatus.recovering;

  @override
  List<Object?> get props => [status, message, exception, requiresAttention];
}
