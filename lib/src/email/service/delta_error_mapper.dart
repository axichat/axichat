// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/storage/models/message_models.dart';

class DeltaErrorMapper {
  const DeltaErrorMapper._();

  static MessageError resolve(String? reason) {
    if (reason == null || reason.isEmpty) {
      return MessageError.emailSendFailure;
    }
    final lower = reason.toLowerCase();
    if (_matchesAny(lower, const ['auth', 'login', 'password'])) {
      return MessageError.emailAuthenticationFailed;
    }
    if (_matchesAny(lower, const ['too large', 'size', 'quota'])) {
      return MessageError.emailAttachmentTooLarge;
    }
    if (_matchesAny(
        lower, const ['recipient', 'address', 'invalid', 'unknown'])) {
      return MessageError.emailRecipientRejected;
    }
    if (lower.contains('bounce')) {
      return MessageError.emailBounced;
    }
    if (_matchesAny(lower, const ['throttle', 'rate', 'limit'])) {
      return MessageError.emailThrottled;
    }
    if (_matchesAny(lower, const ['network', 'timeout'])) {
      return MessageError.serverTimeout;
    }
    if (_matchesAny(lower, const ['dns', 'mx'])) {
      return MessageError.serverNotFound;
    }
    return MessageError.emailSendFailure;
  }

  static bool _matchesAny(String input, List<String> needles) =>
      needles.any(input.contains);
}
