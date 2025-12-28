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

final class PubSubFetchResult<T> {
  const PubSubFetchResult({
    required this.items,
    required this.isSuccess,
    this.isComplete = _pubSubFetchCompleteDefault,
  });

  final List<T> items;
  final bool isSuccess;
  final bool isComplete;
}

const bool _pubSubFetchCompleteDefault = true;

extension PubSubPepNotificationAuthorization on mox.PubSubNotificationEvent {
  bool isFromPepOwner(mox.JID owner) {
    final publisher = item.publisher?.trim();
    if (publisher != null && publisher.isNotEmpty) {
      return _matchesPepOwner(publisher, owner);
    }
    return _matchesPepOwner(from, owner);
  }
}

extension PubSubPepRetractionAuthorization on mox.PubSubItemsRetractedEvent {
  bool isFromPepOwner(mox.JID owner) => _matchesPepOwner(from, owner);
}

bool _matchesPepOwner(String raw, mox.JID owner) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return false;
  final ownerBare = owner.toBare().toString();
  try {
    return mox.JID.fromString(trimmed).toBare().toString() == ownerBare;
  } on Exception {
    return trimmed == ownerBare;
  }
}
