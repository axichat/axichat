// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/endpoint_config.dart';

bool isPersonalCalendarSyncAccount(String? accountJid) {
  final account = normalizedAddressKey(accountJid);
  return account != null && addressDomainPart(account) != null;
}

bool isCalendarSyncTargetAllowed({
  required String? accountJid,
  required String? targetJid,
}) {
  final targetDomain = _calendarSyncDomain(targetJid);
  if (targetDomain == null) {
    return false;
  }
  if (_isAxiCalendarSyncDomain(targetDomain)) {
    return true;
  }
  final accountDomain = _calendarSyncDomain(accountJid);
  if (accountDomain == null) {
    return false;
  }
  return targetDomain == accountDomain;
}

String? _calendarSyncDomain(String? jid) {
  final bare = bareAddress(jid);
  final domain = addressDomainPart(bare)?.trim().toLowerCase();
  return domain == null || domain.isEmpty ? null : domain;
}

bool _isAxiCalendarSyncDomain(String domain) {
  final axiDomain = EndpointConfig.axiImDomain;
  return domain == axiDomain || domain.endsWith('.$axiDomain');
}
