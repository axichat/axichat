// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/endpoint_config.dart';

enum MessageTransport { xmpp, email }

const String _messageTransportXmppWireValue = 'xmpp';
const String _messageTransportEmailWireValue = 'email';

extension MessageTransportDisplay on MessageTransport {
  String get label => switch (this) {
    MessageTransport.xmpp => 'XMPP',
    MessageTransport.email => 'Email',
  };
}

extension MessageTransportBehavior on MessageTransport {
  bool get isXmpp => this == MessageTransport.xmpp;

  bool get isEmail => this == MessageTransport.email;
}

extension MessageTransportCodec on MessageTransport {
  String get wireValue => switch (this) {
    MessageTransport.xmpp => _messageTransportXmppWireValue,
    MessageTransport.email => _messageTransportEmailWireValue,
  };

  static MessageTransport fromWireValue(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      _messageTransportEmailWireValue => MessageTransport.email,
      _ => MessageTransport.xmpp,
    };
  }
}

const Set<String> _emailDomainHints = <String>{
  'gmail.com',
  'outlook.com',
  'hotmail.com',
  'yahoo.com',
  'aol.com',
  'icloud.com',
  'me.com',
  'mac.com',
  'live.com',
  'msn.com',
  'protonmail.com',
  'proton.me',
  'tuta.com',
};

const Set<String> _xmppDomainHints = <String>{
  EndpointConfig.defaultDomain,
  'conversations.im',
  'disroot.org',
  'jabber.org',
};

MessageTransport? hintTransportForAddress(
  String? address, {
  Iterable<String> xmppDomainHints = const <String>[],
}) {
  final domain = _hintDomainForAddress(address);
  if (domain == null || domain.isEmpty) {
    return null;
  }
  final extraXmppDomainHints = _normalizedHintDomains(xmppDomainHints);
  if (_matchesHintedDomain(domain, extraXmppDomainHints)) {
    return MessageTransport.xmpp;
  }
  if (_matchesHintedDomain(domain, _emailDomainHints)) {
    return MessageTransport.email;
  }
  if (_matchesHintedDomain(domain, _xmppDomainHints)) {
    return MessageTransport.xmpp;
  }
  return null;
}

String? _hintDomainForAddress(String? address) {
  final bare = bareAddress(address);
  final domain = addressDomainPart(bare ?? address)?.trim().toLowerCase();
  if (domain == null || domain.isEmpty) {
    return null;
  }
  return domain.endsWith('.') ? domain.substring(0, domain.length - 1) : domain;
}

Set<String> _normalizedHintDomains(Iterable<String> domains) {
  final normalized = <String>{};
  for (final domain in domains) {
    final trimmed = domain.trim().toLowerCase();
    if (trimmed.isEmpty) {
      continue;
    }
    normalized.add(
      trimmed.endsWith('.')
          ? trimmed.substring(0, trimmed.length - 1)
          : trimmed,
    );
  }
  return normalized;
}

bool _matchesHintedDomain(String domain, Set<String> hints) {
  for (final hint in hints) {
    if (domain == hint || domain.endsWith('.$hint')) {
      return true;
    }
  }
  return false;
}
