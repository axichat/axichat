import 'package:axichat/src/xmpp/pubsub_events.dart';
import 'package:moxlib/moxlib.dart' as moxlib;
import 'package:moxxmpp/moxxmpp.dart' as mox;

/// Compatibility wrapper for moxxmpp's [mox.UserAvatarManager].
///
/// Fixes metadata parsing for XEP-0084 PEP notifications and corrects the
/// unsubscribe implementation.
class SafeUserAvatarManager extends mox.UserAvatarManager {
  SafeUserAvatarManager();

  static const String _metadataTag = 'metadata';
  static const String _infoTag = 'info';
  static const int _maxMetadataItems = 1;

  @override
  Future<void> onXmppEvent(mox.XmppEvent event) async {
    if (event is PubSubItemsRefreshedEvent) {
      await _handleRefreshEvent(event);
      return;
    }

    if (event is! mox.PubSubNotificationEvent) {
      return super.onXmppEvent(event);
    }

    if (event.item.node != mox.userAvatarMetadataXmlns) return;

    final fromRaw = event.from.trim();
    if (fromRaw.isEmpty) return;

    late final mox.JID from;
    try {
      from = mox.JID.fromString(fromRaw);
    } on Exception {
      return;
    }

    if (event.item.payload case final payload?) {
      await _emitFromPayload(from: from, payload: payload);
      return;
    }

    final itemId = event.item.id.trim();
    await _refreshMetadata(
      from: from,
      itemId: itemId.isNotEmpty ? itemId : null,
    );
  }

  Future<void> _handleRefreshEvent(PubSubItemsRefreshedEvent event) async {
    if (event.node != mox.userAvatarMetadataXmlns) return;
    await _refreshMetadata(from: event.from);
  }

  Future<void> _refreshMetadata({
    required mox.JID from,
    String? itemId,
  }) async {
    final pubsub =
        getAttributes().getManagerById<mox.PubSubManager>(mox.pubsubManager);
    if (pubsub == null) return;

    final bareFrom = from.toBare();
    final normalizedItemId = itemId?.trim();
    if (normalizedItemId?.isNotEmpty == true) {
      final itemResult = await pubsub.getItem(
        bareFrom,
        mox.userAvatarMetadataXmlns,
        normalizedItemId!,
      );
      if (!itemResult.isType<mox.PubSubError>()) {
        final fetchedPayload = itemResult.get<mox.PubSubItem>().payload;
        if (fetchedPayload != null) {
          await _emitFromPayload(from: from, payload: fetchedPayload);
          return;
        }
      }
    }

    var itemsResult = await pubsub.getItems(
      bareFrom,
      mox.userAvatarMetadataXmlns,
      maxItems: _maxMetadataItems,
    );
    if (itemsResult.isType<mox.PubSubError>()) {
      final error = itemsResult.get<mox.PubSubError>();
      final shouldRetry = error is mox.EjabberdMaxItemsError ||
          error is mox.MalformedResponseError ||
          error is mox.UnknownPubSubError;
      if (!shouldRetry) return;
      itemsResult = await pubsub.getItems(
        bareFrom,
        mox.userAvatarMetadataXmlns,
      );
      if (itemsResult.isType<mox.PubSubError>()) return;
    }

    final items = itemsResult.get<List<mox.PubSubItem>>();
    if (items.isEmpty) {
      getAttributes().sendEvent(
        mox.UserAvatarUpdatedEvent(
          from,
          const <mox.UserAvatarMetadata>[],
        ),
      );
      return;
    }

    final payload = items.first.payload;
    if (payload == null) return;
    await _emitFromPayload(from: from, payload: payload);
  }

  Future<void> _emitFromPayload({
    required mox.JID from,
    required mox.XMLNode payload,
  }) async {
    if (payload.tag != _metadataTag ||
        payload.attributes['xmlns'] != mox.userAvatarMetadataXmlns) {
      logger.warning('Received invalid user avatar metadata payload.');
      return;
    }

    final metadata =
        payload.findTags(_infoTag).map(mox.UserAvatarMetadata.fromXML).toList();
    getAttributes().sendEvent(
      mox.UserAvatarUpdatedEvent(
        from,
        metadata,
      ),
    );
  }

  @override
  Future<moxlib.Result<mox.AvatarError, bool>> unsubscribe(mox.JID jid) async {
    final pubsub =
        getAttributes().getManagerById<mox.PubSubManager>(mox.pubsubManager);
    if (pubsub == null) {
      return moxlib.Result(mox.UnknownAvatarError());
    }

    final result = await pubsub.unsubscribe(jid, mox.userAvatarMetadataXmlns);
    if (result.isType<mox.PubSubError>()) {
      logger.warning('Failed to unsubscribe from user avatar metadata.');
      return moxlib.Result(mox.UnknownAvatarError());
    }

    return const moxlib.Result(true);
  }
}
