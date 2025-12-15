import 'package:axichat/src/xmpp/safe_pubsub_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  mox.XmppManagerAttributes buildAttributes({
    required List<mox.StanzaDetails> sentStanzas,
    required mox.JID fullJid,
  }) {
    return mox.XmppManagerAttributes(
      sendStanza: (details) async {
        sentStanzas.add(details);
        return mox.Stanza.iq(type: 'result');
      },
      sendNonza: (_) {},
      getManagerById: <T extends mox.XmppManagerBase>(_) => null,
      sendEvent: (_) {},
      getConnectionSettings: () => mox.ConnectionSettings(
        jid: fullJid,
        password: 'password',
      ),
      getFullJID: () => fullJid,
      getSocket: () => throw UnimplementedError(),
      getConnection: () => throw UnimplementedError(),
      getNegotiatorById: <T extends mox.XmppFeatureNegotiatorBase>(String _) =>
          null,
    );
  }

  test(
    'XEP-0060 publish stanza uses pubsub/publish/item hierarchy',
    () async {
      final sent = <mox.StanzaDetails>[];
      final manager = SafePubSubManager()
        ..register(
          buildAttributes(
            sentStanzas: sent,
            fullJid: mox.JID.fromString('user@example.com/resource'),
          ),
        );

      final serviceJid = mox.JID.fromString('pubsub.example.com');
      final payload = (mox.XmlBuilder.withNamespace('payload', 'urn:test')
            ..text('value'))
          .build();

      final result = await manager.publish(
        serviceJid,
        'test-node',
        payload,
        id: 'item-id',
        options: const mox.PubSubPublishOptions(accessModel: 'open'),
      );

      expect(result.isType<mox.PubSubError>(), isFalse);
      expect(result.get<bool>(), isTrue);
      expect(sent, hasLength(1));

      final stanza = sent.single.stanza;
      expect(stanza.tag, equals('iq'));
      expect(stanza.attributes['type'], equals('set'));
      expect(stanza.attributes['to'], equals(serviceJid.toString()));

      final pubsub = stanza.firstTag('pubsub', xmlns: mox.pubsubXmlns);
      expect(pubsub, isNotNull);

      final publish = pubsub!.firstTag('publish');
      expect(publish?.attributes['node'], equals('test-node'));

      final item = publish!.firstTag('item');
      expect(item?.attributes['id'], equals('item-id'));
      expect(item?.firstTag('payload', xmlns: 'urn:test'), isNotNull);

      final publishOptions = pubsub.firstTag('publish-options');
      expect(publishOptions, isNotNull);
      final form = publishOptions!.firstTag('x', xmlns: mox.dataFormsXmlns);
      expect(form, isNotNull);
      expect(form!.attributes['type'], equals('submit'));

      mox.XMLNode? formTypeField;
      for (final field in form.findTags('field')) {
        if (field.attributes['var'] == 'FORM_TYPE') {
          formTypeField = field;
          break;
        }
      }
      expect(formTypeField, isNotNull);
      expect(
        formTypeField!.firstTag('value')?.innerText(),
        equals(mox.pubsubPublishOptionsXmlns),
      );
    },
  );

  test(
    'XEP-0060 subscribe stanza includes node and jid',
    () async {
      final sent = <mox.StanzaDetails>[];
      final fullJid = mox.JID.fromString('user@example.com/resource');
      final manager = SafePubSubManager()
        ..register(
          buildAttributes(
            sentStanzas: sent,
            fullJid: fullJid,
          ),
        );

      final serviceJid = mox.JID.fromString('pubsub.example.com');
      final result = await manager.subscribe(serviceJid, 'test-node');

      expect(result.isType<mox.PubSubError>(), isFalse);
      final subscription = result.get<mox.SubscriptionInfo>();
      expect(subscription.jid, equals(fullJid.toBare().toString()));
      expect(subscription.node, equals('test-node'));
      expect(sent, hasLength(1));

      final stanza = sent.single.stanza;
      expect(stanza.tag, equals('iq'));
      expect(stanza.attributes['type'], equals('set'));
      expect(stanza.attributes['to'], equals(serviceJid.toString()));

      final pubsub = stanza.firstTag('pubsub', xmlns: mox.pubsubXmlns);
      expect(pubsub, isNotNull);

      final subscribe = pubsub!.firstTag('subscribe');
      expect(subscribe?.attributes['node'], equals('test-node'));
      expect(subscribe?.attributes['jid'], equals(fullJid.toBare().toString()));
    },
  );

  test(
    'XEP-0060 unsubscribe stanza includes node and jid',
    () async {
      final sent = <mox.StanzaDetails>[];
      final fullJid = mox.JID.fromString('user@example.com/resource');
      final manager = SafePubSubManager()
        ..register(
          buildAttributes(
            sentStanzas: sent,
            fullJid: fullJid,
          ),
        );

      final serviceJid = mox.JID.fromString('pubsub.example.com');
      final result = await manager.unsubscribe(serviceJid, 'test-node');

      expect(result.isType<mox.PubSubError>(), isFalse);
      expect(result.get<bool>(), isTrue);
      expect(sent, hasLength(1));

      final stanza = sent.single.stanza;
      expect(stanza.tag, equals('iq'));
      expect(stanza.attributes['type'], equals('set'));
      expect(stanza.attributes['to'], equals(serviceJid.toString()));

      final pubsub = stanza.firstTag('pubsub', xmlns: mox.pubsubXmlns);
      expect(pubsub, isNotNull);

      final unsubscribe = pubsub!.firstTag('unsubscribe');
      expect(unsubscribe?.attributes['node'], equals('test-node'));
      expect(
        unsubscribe?.attributes['jid'],
        equals(fullJid.toBare().toString()),
      );
    },
  );

  test(
    'XEP-0060 getItems stanza includes node and max_items',
    () async {
      final sent = <mox.StanzaDetails>[];
      final manager = SafePubSubManager()
        ..register(
          buildAttributes(
            sentStanzas: sent,
            fullJid: mox.JID.fromString('user@example.com/resource'),
          ),
        );

      final serviceJid = mox.JID.fromString('pubsub.example.com');
      await manager.getItems(serviceJid, 'test-node', maxItems: 1);

      expect(sent, hasLength(1));
      final stanza = sent.single.stanza;
      expect(stanza.tag, equals('iq'));
      expect(stanza.attributes['type'], equals('get'));
      expect(stanza.attributes['to'], equals(serviceJid.toString()));

      final pubsub = stanza.firstTag('pubsub', xmlns: mox.pubsubXmlns);
      expect(pubsub, isNotNull);

      final items = pubsub!.firstTag('items');
      expect(items?.attributes['node'], equals('test-node'));
      expect(items?.attributes['max_items']?.toString(), equals('1'));
    },
  );

  test(
    'XEP-0060 getItem stanza includes item id',
    () async {
      final sent = <mox.StanzaDetails>[];
      final manager = SafePubSubManager()
        ..register(
          buildAttributes(
            sentStanzas: sent,
            fullJid: mox.JID.fromString('user@example.com/resource'),
          ),
        );

      final serviceJid = mox.JID.fromString('pubsub.example.com');
      await manager.getItem(serviceJid, 'test-node', 'item-id');

      expect(sent, hasLength(1));
      final stanza = sent.single.stanza;
      expect(stanza.tag, equals('iq'));
      expect(stanza.attributes['type'], equals('get'));
      expect(stanza.attributes['to'], equals(serviceJid.toString()));

      final pubsub = stanza.firstTag('pubsub', xmlns: mox.pubsubXmlns);
      expect(pubsub, isNotNull);

      final items = pubsub!.firstTag('items');
      expect(items?.attributes['node'], equals('test-node'));

      final item = items!.firstTag('item');
      expect(item?.attributes['id'], equals('item-id'));
    },
  );
}
