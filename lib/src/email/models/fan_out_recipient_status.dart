// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/email/models/fan_out_recipient_state.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:equatable/equatable.dart';

class FanOutRecipientStatus extends Equatable {
  const FanOutRecipientStatus({
    required this.chat,
    required this.state,
    this.deltaMsgId,
    this.error,
  });

  final Chat chat;
  final FanOutRecipientState state;
  final int? deltaMsgId;
  final Object? error;

  bool get isFailure => state == FanOutRecipientState.failed;

  @override
  List<Object?> get props => [chat, state, deltaMsgId, error];
}
