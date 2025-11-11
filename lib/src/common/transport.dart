enum MessageTransport { xmpp, email }

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
