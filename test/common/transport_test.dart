import 'package:axichat/src/common/transport.dart';
import 'package:test/test.dart';

void main() {
  group('hintTransportForAddress', () {
    test('returns xmpp for axi.im addresses', () {
      expect(
        hintTransportForAddress('person@axi.im'),
        MessageTransport.xmpp,
      );
    });

    test('returns xmpp for conversations.im addresses', () {
      expect(
        hintTransportForAddress('person@conversations.im'),
        MessageTransport.xmpp,
      );
    });

    test('returns email for gmail.com addresses', () {
      expect(
        hintTransportForAddress('person@gmail.com'),
        MessageTransport.email,
      );
    });

    test('returns email for known email domain with a resource suffix', () {
      expect(
        hintTransportForAddress('person@gmail.com/mobile'),
        MessageTransport.email,
      );
    });

    test('returns xmpp for known xmpp subdomains', () {
      expect(
        hintTransportForAddress('room@chat.conversations.im'),
        MessageTransport.xmpp,
      );
    });

    test('returns null when no hint matches', () {
      expect(hintTransportForAddress('person@example.com'), isNull);
    });
  });
}
