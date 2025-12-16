import 'package:axichat/src/common/safe_logging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SafeLogging', () {
    test('Redacts account identifiers', () {
      const message = 'Logged in as alice@example.com';
      final sanitized = SafeLogging.sanitizeMessage(message);
      expect(sanitized, contains(SafeLogging.redactedAccount));
      expect(sanitized, isNot(contains('@')));
    });

    test('Redacts absolute file paths', () {
      const message = 'Attachment path=/home/eliot/secret.txt';
      final sanitized = SafeLogging.sanitizeMessage(message);
      expect(sanitized, contains('path=${SafeLogging.redactedPath}'));
      expect(sanitized, isNot(contains('/home/eliot/secret.txt')));
    });

    test('Redacts absolute file paths wrapped in punctuation', () {
      const message = 'Exception opening file (/home/eliot/secret.txt).';
      final sanitized = SafeLogging.sanitizeMessage(message);
      expect(sanitized, contains('(${SafeLogging.redactedPath})'));
      expect(sanitized, isNot(contains('/home/eliot/secret.txt')));
    });

    test('Redacts password-like values', () {
      const message = '{"password":"hunter2","passphrase":"opensesame"}';
      final sanitized = SafeLogging.sanitizeMessage(message);
      expect(sanitized, contains(SafeLogging.redactedSecret));
      expect(sanitized, isNot(contains('hunter2')));
      expect(sanitized, isNot(contains('opensesame')));
    });

    test('Redacts XMPP XML body contents', () {
      const message = '<message><body>Hello there</body></message>';
      final sanitized = SafeLogging.sanitizeMessage(message);
      expect(sanitized, contains(SafeLogging.redactedSecret));
      expect(sanitized, isNot(contains('Hello there')));
    });

    test('Redacts file:// uris', () {
      const message = 'Avatar uri=file:///tmp/avatar.enc';
      final sanitized = SafeLogging.sanitizeMessage(message);
      expect(sanitized, contains(SafeLogging.redactedPath));
      expect(sanitized, isNot(contains('file://')));
    });

    test('Redacts long secrets', () {
      const secretHex =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final sanitized = SafeLogging.sanitizeMessage('hash=$secretHex');
      expect(sanitized, contains(SafeLogging.redactedSecret));
      expect(sanitized, isNot(contains(secretHex)));
      expect(sanitized, isNot(contains('@')));
    });

    test('Summarizes XMPP traffic logs quickly', () {
      final payload = List.filled(5000, 'A').join();
      final message =
          "==> <iq type='set'><pubsub node='urn:xmpp:avatar:data'>$payload</pubsub></iq>";

      final sanitized = SafeLogging.sanitizeMessage(message);
      expect(sanitized, startsWith('==> ('));
      expect(sanitized, contains('<iq>'));
      expect(sanitized, contains('type=set'));
      expect(sanitized, contains('urn:xmpp:avatar:data'));
      expect(sanitized, isNot(contains(payload)));
    });

    test('Omits large non-XMPP logs', () {
      final payload = List.filled(5000, 'x').join();
      final message = 'Logged in as alice@example.com $payload';

      final sanitized = SafeLogging.sanitizeMessage(message);
      expect(sanitized, startsWith(SafeLogging.redactedSecret));
      expect(sanitized, contains('log omitted'));
      expect(sanitized, isNot(contains('@')));
    });
  });
}
