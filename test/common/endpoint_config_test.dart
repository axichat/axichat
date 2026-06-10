import 'package:axichat/src/common/endpoint_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EndpointConfig', () {
    test('fromJson ignores legacy XMPP endpoint overrides', () {
      final config = EndpointConfig.fromJson({
        'domain': 'selfhosted.example',
        'xmppEnabled': true,
        'smtpEnabled': true,
        'xmppHost': 'xmpp.custom.example',
        'xmppPort': 6222,
        'imapHost': 'imap.selfhosted.example',
        'smtpHost': 'smtp.selfhosted.example',
      });

      expect(config.domain, 'selfhosted.example');
      expect(config.xmppEnabled, isTrue);
      expect(config.smtpEnabled, isTrue);
      expect(config.imapHost, 'imap.selfhosted.example');
      expect(config.smtpHost, 'smtp.selfhosted.example');
      expect(config.toJson(), isNot(containsPair('xmppHost', anything)));
      expect(config.toJson(), isNot(containsPair('xmppPort', anything)));
    });

    test('copyWith preserves email endpoint overrides only', () {
      final config = const EndpointConfig().copyWith(
        domain: 'selfhosted.example',
        imapHost: 'imap.selfhosted.example',
        smtpHost: 'smtp.selfhosted.example',
        smtpPort: 587,
      );

      expect(config.domain, 'selfhosted.example');
      expect(config.imapHost, 'imap.selfhosted.example');
      expect(config.smtpHost, 'smtp.selfhosted.example');
      expect(config.smtpPort, 587);
      expect(config.toJson(), isNot(containsPair('xmppHost', anything)));
      expect(config.toJson(), isNot(containsPair('xmppPort', anything)));
    });
  });
}
