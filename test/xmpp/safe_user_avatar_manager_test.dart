import 'package:axichat/src/xmpp/safe_user_avatar_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moxlib/moxlib.dart' as moxlib;
import 'package:mocktail/mocktail.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

class _MockPubSubManager extends Mock implements mox.PubSubManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'SafeUserAvatarManager emits metadata parsed from PEP notifications',
    () async {
      final manager = SafeUserAvatarManager();
      final sentEvents = <mox.XmppEvent>[];

      final attributes = mox.XmppManagerAttributes(
        sendStanza: (_) async => null,
        sendNonza: (_) {},
        getManagerById: <T extends mox.XmppManagerBase>(_) => null,
        sendEvent: sentEvents.add,
        getConnectionSettings: () => mox.ConnectionSettings(
          jid: mox.JID.fromString('user@example.com'),
          password: 'password',
        ),
        getFullJID: () => mox.JID.fromString('user@example.com/resource'),
        getSocket: () => throw UnimplementedError(),
        getConnection: () => throw UnimplementedError(),
        getNegotiatorById:
            <T extends mox.XmppFeatureNegotiatorBase>(String _) => null,
      );

      manager.register(attributes);

      const avatarId = 'avatar-hash';
      const avatarBytes = 1337;
      const avatarWidth = 128;
      const avatarHeight = 128;
      const avatarType = 'image/png';

      final payload =
          (mox.XmlBuilder.withNamespace('metadata', mox.userAvatarMetadataXmlns)
                ..child(
                  (mox.XmlBuilder('info')
                        ..attr('id', avatarId)
                        ..attr('bytes', avatarBytes.toString())
                        ..attr('type', avatarType)
                        ..attr('width', avatarWidth.toString())
                        ..attr('height', avatarHeight.toString()))
                      .build(),
                ))
              .build();

      final item = mox.PubSubItem(
        id: avatarId,
        node: mox.userAvatarMetadataXmlns,
        payload: payload,
      );
      final event = mox.PubSubNotificationEvent(
        item: item,
        from: 'contact@example.com',
      );

      await manager.onXmppEvent(event);

      expect(sentEvents, hasLength(1));
      expect(sentEvents.single, isA<mox.UserAvatarUpdatedEvent>());

      final avatarEvent = sentEvents.single as mox.UserAvatarUpdatedEvent;
      expect(
          avatarEvent.jid.toBare().toString(), equals('contact@example.com'));
      expect(avatarEvent.metadata, hasLength(1));

      final metadata = avatarEvent.metadata.single;
      expect(metadata.id, equals(avatarId));
      expect(metadata.length, equals(avatarBytes));
      expect(metadata.width, equals(avatarWidth));
      expect(metadata.height, equals(avatarHeight));
      expect(metadata.type, equals(avatarType));
    },
  );

  test(
    'SafeUserAvatarManager fetches metadata when notification payload is missing',
    () async {
      final manager = SafeUserAvatarManager();
      final sentEvents = <mox.XmppEvent>[];
      final pubsub = _MockPubSubManager();

      const avatarId = 'avatar-hash';
      final from = mox.JID.fromString('contact@example.com');

      final payload =
          (mox.XmlBuilder.withNamespace('metadata', mox.userAvatarMetadataXmlns)
                ..child(
                  (mox.XmlBuilder('info')
                        ..attr('id', avatarId)
                        ..attr('bytes', '1337')
                        ..attr('type', 'image/png')
                        ..attr('width', '128')
                        ..attr('height', '128'))
                      .build(),
                ))
              .build();

      when(() => pubsub.getItem(from, mox.userAvatarMetadataXmlns, avatarId))
          .thenAnswer(
        (_) async => moxlib.Result(
          mox.PubSubItem(
            id: avatarId,
            node: mox.userAvatarMetadataXmlns,
            payload: payload,
          ),
        ),
      );

      final attributes = mox.XmppManagerAttributes(
        sendStanza: (_) async => null,
        sendNonza: (_) {},
        getManagerById: <T extends mox.XmppManagerBase>(String id) {
          if (id == mox.pubsubManager) return pubsub as T;
          return null;
        },
        sendEvent: sentEvents.add,
        getConnectionSettings: () => mox.ConnectionSettings(
          jid: mox.JID.fromString('user@example.com'),
          password: 'password',
        ),
        getFullJID: () => mox.JID.fromString('user@example.com/resource'),
        getSocket: () => throw UnimplementedError(),
        getConnection: () => throw UnimplementedError(),
        getNegotiatorById:
            <T extends mox.XmppFeatureNegotiatorBase>(String _) => null,
      );

      manager.register(attributes);

      const item = mox.PubSubItem(
        id: avatarId,
        node: mox.userAvatarMetadataXmlns,
        payload: null,
      );
      final event = mox.PubSubNotificationEvent(
        item: item,
        from: from.toString(),
      );

      await manager.onXmppEvent(event);

      verify(() => pubsub.getItem(from, mox.userAvatarMetadataXmlns, avatarId))
          .called(1);
      expect(sentEvents, hasLength(1));
      expect(sentEvents.single, isA<mox.UserAvatarUpdatedEvent>());
      final avatarEvent = sentEvents.single as mox.UserAvatarUpdatedEvent;
      expect(avatarEvent.metadata, hasLength(1));
      expect(avatarEvent.metadata.single.id, equals(avatarId));
    },
  );

  test(
    'SafeUserAvatarManager unsubscribe calls PubSubManager.unsubscribe',
    () async {
      final manager = SafeUserAvatarManager();
      final pubsub = _MockPubSubManager();
      final jid = mox.JID.fromString('contact@example.com');

      when(() => pubsub.unsubscribe(jid, mox.userAvatarMetadataXmlns))
          .thenAnswer(
        (_) async => const moxlib.Result(true),
      );

      final attributes = mox.XmppManagerAttributes(
        sendStanza: (_) async => null,
        sendNonza: (_) {},
        getManagerById: <T extends mox.XmppManagerBase>(String id) {
          if (id == mox.pubsubManager) return pubsub as T;
          return null;
        },
        sendEvent: (_) {},
        getConnectionSettings: () => mox.ConnectionSettings(
          jid: mox.JID.fromString('user@example.com'),
          password: 'password',
        ),
        getFullJID: () => mox.JID.fromString('user@example.com/resource'),
        getSocket: () => throw UnimplementedError(),
        getConnection: () => throw UnimplementedError(),
        getNegotiatorById:
            <T extends mox.XmppFeatureNegotiatorBase>(String _) => null,
      );

      manager.register(attributes);

      final result = await manager.unsubscribe(jid);

      expect(result.isType<mox.AvatarError>(), isFalse);
      expect(result.get<bool>(), isTrue);
      verify(() => pubsub.unsubscribe(jid, mox.userAvatarMetadataXmlns))
          .called(1);
    },
  );
}
