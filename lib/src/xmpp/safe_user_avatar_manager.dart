import 'package:moxlib/moxlib.dart' as moxlib;
import 'package:moxxmpp/moxxmpp.dart' as mox;

/// Compatibility wrapper for moxxmpp's [mox.UserAvatarManager].
///
/// Fixes metadata parsing for XEP-0084 PEP notifications and corrects the
/// unsubscribe implementation.
class SafeUserAvatarManager extends mox.UserAvatarManager {
  SafeUserAvatarManager();

  @override
  Future<void> onXmppEvent(mox.XmppEvent event) async {
    if (event is! mox.PubSubNotificationEvent) {
      return super.onXmppEvent(event);
    }

    if (event.item.node != mox.userAvatarMetadataXmlns) return;

    final payload = event.item.payload;
    if (payload == null ||
        payload.tag != 'metadata' ||
        payload.attributes['xmlns'] != mox.userAvatarMetadataXmlns) {
      logger.warning('Received invalid user avatar metadata payload.');
      return;
    }

    final metadata = payload.findTags('info').map(mox.UserAvatarMetadata.fromXML);
    getAttributes().sendEvent(
      mox.UserAvatarUpdatedEvent(
        mox.JID.fromString(event.from),
        metadata.toList(),
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

