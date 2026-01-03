// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:equatable/equatable.dart';

enum PendingAttachmentStatus { queued, uploading, failed }

class PendingAttachment extends Equatable {
  const PendingAttachment({
    required this.id,
    required this.attachment,
    this.status = PendingAttachmentStatus.queued,
    this.isPreparing = false,
    this.errorMessage,
  });

  final String id;
  final EmailAttachment attachment;
  final PendingAttachmentStatus status;
  final bool isPreparing;
  final String? errorMessage;

  PendingAttachment copyWith({
    EmailAttachment? attachment,
    PendingAttachmentStatus? status,
    bool? isPreparing,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return PendingAttachment(
      id: id,
      attachment: attachment ?? this.attachment,
      status: status ?? this.status,
      isPreparing: isPreparing ?? this.isPreparing,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props =>
      [id, attachment, status, isPreparing, errorMessage];
}
