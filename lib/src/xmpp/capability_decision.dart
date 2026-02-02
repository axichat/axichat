// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

enum CapabilityDecisionKind { allowed, unsupported, unknown, error }

class CapabilityDecision {
  const CapabilityDecision(
    this.kind, {
    this.error,
    this.stackTrace,
  });

  final CapabilityDecisionKind kind;
  final Object? error;
  final StackTrace? stackTrace;

  bool get isAllowed => kind == CapabilityDecisionKind.allowed;
  bool get isUnsupported => kind == CapabilityDecisionKind.unsupported;
  bool get isUnknown => kind == CapabilityDecisionKind.unknown;
  bool get isError => kind == CapabilityDecisionKind.error;
}
