// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/email/models/fan_out_recipient_status.dart';
import 'package:axichat/src/common/compose_recipient.dart';
import 'package:axichat/src/email/models/fan_out_recipient_state.dart';
import 'package:equatable/equatable.dart';

class FanOutSendReport extends Equatable {
  const FanOutSendReport({
    required this.shareId,
    required this.statuses,
    this.subjectToken,
    this.subject,
    this.attachmentWarning = false,
  });

  final String shareId;
  final String? subjectToken;
  final String? subject;
  final bool attachmentWarning;
  final List<FanOutRecipientStatus> statuses;

  bool get hasFailures => statuses.any((status) => status.isFailure);

  Map<ComposerRecipientKey, FanOutRecipientState> statusesByTargetKey(
    List<EmailRecipientIntent> targets,
  ) {
    final statusesByKey = <ComposerRecipientKey, FanOutRecipientState>{};
    if (statuses.isEmpty && !hasFailures) {
      for (final target in targets) {
        statusesByKey[target.recipientKey] = FanOutRecipientState.sent;
      }
      return statusesByKey;
    }
    for (final status in statuses) {
      final existing = statusesByKey[status.recipientKey];
      if (existing == FanOutRecipientState.failed) {
        continue;
      }
      statusesByKey[status.recipientKey] = status.state;
    }
    for (final target in targets) {
      statusesByKey.putIfAbsent(
        target.recipientKey,
        () => FanOutRecipientState.failed,
      );
    }
    return statusesByKey;
  }

  @override
  List<Object?> get props => [
    shareId,
    subjectToken,
    subject,
    attachmentWarning,
    statuses,
  ];
}
