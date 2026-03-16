// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/email/models/fan_out_recipient_status.dart';
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

  @override
  List<Object?> get props => [
    shareId,
    subjectToken,
    subject,
    attachmentWarning,
    statuses,
  ];
}
