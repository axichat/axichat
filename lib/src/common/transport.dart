// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

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
