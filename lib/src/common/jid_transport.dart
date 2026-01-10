// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/transport.dart';

const String _jidAtSymbol = '@';
final RegExp _axiDomainPattern = RegExp(r'@axi\.im$', caseSensitive: false);
const String _jidResourceDelimiter = '/';

extension JidTransportExtension on String {
  String get _normalized => trim().toLowerCase();

  String get _bareJid => _normalized.split(_jidResourceDelimiter).first;

  String get bareJid => _bareJid;

  bool get isAxiJid {
    final normalized = _bareJid;
    if (normalized.isEmpty || !normalized.contains(_jidAtSymbol)) {
      return false;
    }
    return _axiDomainPattern.hasMatch(normalized);
  }

  bool get isEmailJid {
    final normalized = _bareJid;
    if (normalized.isEmpty || !normalized.contains(_jidAtSymbol)) {
      return false;
    }
    return !_axiDomainPattern.hasMatch(normalized);
  }

  MessageTransport get inferredTransport =>
      isEmailJid ? MessageTransport.email : MessageTransport.xmpp;
}
