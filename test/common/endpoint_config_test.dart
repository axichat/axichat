import 'dart:io';

import 'package:axichat/src/common/endpoint_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EndpointResolver', () {
    test('resolveXmpp uses hostname for SMTP-enabled default domain', () async {
      var lookupCalls = 0;
      final resolver = EndpointResolver(
        lookup: (_) async {
          lookupCalls++;
          return [InternetAddress.loopbackIPv4];
        },
      );

      final endpoint = await resolver.resolveXmpp(
        const EndpointConfig(),
        fallback: const EndpointOverride(host: '198.51.100.10', port: 5222),
      );

      expect(
        endpoint,
        const EndpointOverride(
          host: EndpointConfig.defaultDomain,
          port: EndpointConfig.defaultXmppPort,
        ),
      );
      expect(lookupCalls, 0);
    });

    test('resolveXmpp keeps custom axi.im host authoritative', () async {
      var lookupCalls = 0;
      final resolver = EndpointResolver(
        lookup: (_) async {
          lookupCalls++;
          return [InternetAddress.loopbackIPv4];
        },
      );

      final endpoint = await resolver.resolveXmpp(
        const EndpointConfig(xmppHost: 'xmpp.custom.example'),
        fallback: const EndpointOverride(host: '198.51.100.10', port: 5222),
      );

      expect(
        endpoint,
        const EndpointOverride(
          host: 'xmpp.custom.example',
          port: EndpointConfig.defaultXmppPort,
        ),
      );
      expect(lookupCalls, 0);
    });

    test(
      'resolveXmpp uses hostname for SMTP-enabled self-hosted domains',
      () async {
        var lookupCalls = 0;
        final resolver = EndpointResolver(
          lookup: (_) async {
            lookupCalls++;
            return [InternetAddress.loopbackIPv4];
          },
        );

        final endpoint = await resolver.resolveXmpp(
          const EndpointConfig(domain: 'selfhosted.example'),
        );

        expect(
          endpoint,
          const EndpointOverride(
            host: 'selfhosted.example',
            port: EndpointConfig.defaultXmppPort,
          ),
        );
        expect(lookupCalls, 0);
      },
    );

    test('resolveXmpp uses DNS for XMPP-only self-hosted domains', () async {
      var lookupCalls = 0;
      final resolver = EndpointResolver(
        lookup: (host) async {
          lookupCalls++;
          expect(host, 'selfhosted.example');
          return [InternetAddress.loopbackIPv4];
        },
      );

      final endpoint = await resolver.resolveXmpp(
        const EndpointConfig(domain: 'selfhosted.example', smtpEnabled: false),
      );

      expect(
        endpoint,
        EndpointOverride(
          host: InternetAddress.loopbackIPv4.address,
          port: EndpointConfig.defaultXmppPort,
        ),
      );
      expect(lookupCalls, 1);
    });
  });
}
