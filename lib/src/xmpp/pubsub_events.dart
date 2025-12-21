import 'package:moxxmpp/moxxmpp.dart' as mox;

final class PubSubItemsRefreshedEvent extends mox.XmppEvent {
  PubSubItemsRefreshedEvent({
    required this.from,
    required this.node,
  });

  final mox.JID from;
  final String node;
}

final class PubSubSubscriptionChangedEvent extends mox.XmppEvent {
  PubSubSubscriptionChangedEvent({
    required this.from,
    required this.node,
    required this.subscriberJid,
    required this.state,
    this.subId,
  });

  final mox.JID from;
  final String node;
  final String? subscriberJid;
  final mox.SubscriptionState state;
  final String? subId;
}

final class PubSubSubscriptionConfigChangedEvent extends mox.XmppEvent {
  PubSubSubscriptionConfigChangedEvent({
    required this.from,
    required this.node,
    this.dataForm,
  });

  final mox.JID from;
  final String node;
  final mox.XMLNode? dataForm;
}
