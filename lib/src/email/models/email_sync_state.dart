// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:equatable/equatable.dart';

import 'package:axichat/src/email/service/delta_chat_exception.dart';

enum EmailSyncStatus { ready, offline, recovering, error }

enum EmailHistoryImportPromptStatus {
  hidden,
  visible,
  importing,
  completed,
  failed;

  bool get isVisible =>
      this == visible ||
      this == importing ||
      this == completed ||
      this == failed;

  bool get isImporting => this == importing;

  bool get isCompleted => this == completed;

  bool get isFailed => this == failed;
}

class EmailSyncState extends Equatable {
  const EmailSyncState._(
    this.status, {
    this.message,
    this.exception,
    this.requiresAttention = false,
    this.historyImportPromptStatus = EmailHistoryImportPromptStatus.hidden,
  });

  const EmailSyncState.ready()
    : this._(EmailSyncStatus.ready, message: null, exception: null);

  const EmailSyncState.offline(String message, {DeltaChatException? exception})
    : this._(
        EmailSyncStatus.offline,
        message: message,
        exception: exception,
        requiresAttention: true,
      );

  const EmailSyncState.recovering(String message)
    : this._(EmailSyncStatus.recovering, message: message);

  const EmailSyncState.error(String message, {DeltaChatException? exception})
    : this._(
        EmailSyncStatus.error,
        message: message,
        exception: exception,
        requiresAttention: true,
      );

  final EmailSyncStatus status;
  final String? message;
  final DeltaChatException? exception;
  final bool requiresAttention;
  final EmailHistoryImportPromptStatus historyImportPromptStatus;

  bool get isOffline => status == EmailSyncStatus.offline;

  bool get isRecovering => status == EmailSyncStatus.recovering;

  EmailSyncState withHistoryImportPromptStatus(
    EmailHistoryImportPromptStatus status,
  ) {
    if (historyImportPromptStatus == status) {
      return this;
    }
    return EmailSyncState._(
      this.status,
      message: message,
      exception: exception,
      requiresAttention: requiresAttention,
      historyImportPromptStatus: status,
    );
  }

  @override
  List<Object?> get props => [
    status,
    message,
    exception,
    requiresAttention,
    historyImportPromptStatus,
  ];
}
