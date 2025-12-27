import 'package:axichat/src/common/transport.dart';

class BlocklistEntry {
  const BlocklistEntry({
    required this.address,
    required this.blockedAt,
    required this.transport,
  });

  final String address;
  final DateTime blockedAt;
  final MessageTransport transport;

  bool get isEmail => transport.isEmail;

  bool get isXmpp => transport.isXmpp;
}
