// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/address_tools.dart';

enum MessageTransport { xmpp, email }

const String _messageTransportXmppWireValue = 'xmpp';
const String _messageTransportEmailWireValue = 'email';

extension MessageTransportDisplay on MessageTransport {
  String get label => switch (this) {
        MessageTransport.xmpp => 'Chat',
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
  'conversations.im',
  'disroot.org',
  'jabber.org',
};

MessageTransport? hintTransportForAddress(String? address) {
  final domain = addressDomainPart(address)?.toLowerCase();
  if (domain == null || domain.isEmpty) {
    return null;
  }
  if (_emailDomainHints.contains(domain)) {
    return MessageTransport.email;
  }
  if (_xmppDomainHints.contains(domain)) {
    return MessageTransport.xmpp;
  }
  return null;
}
