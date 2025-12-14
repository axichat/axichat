import 'dart:io';

import 'package:axichat/src/common/network_safety.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isSafeInternetAddress', () {
    test('rejects loopback, link-local, private, and CGNAT IPv4 ranges', () {
      final blocked = <String>[
        '127.0.0.1',
        '10.0.0.1',
        '172.16.0.1',
        '192.168.1.1',
        '169.254.1.1',
        '100.64.0.1',
      ];
      for (final address in blocked) {
        expect(
            isSafeInternetAddress(InternetAddress.tryParse(address)!), isFalse);
      }
    });

    test('allows publicly routable IPv4 addresses', () {
      expect(
          isSafeInternetAddress(InternetAddress.tryParse('1.1.1.1')!), isTrue);
    });

    test('rejects unique-local and link-local IPv6 ranges', () {
      final blocked = <String>[
        '::1',
        'fe80::1',
        'fc00::1',
        'fd00::1',
        'fec0::1',
      ];
      for (final address in blocked) {
        expect(
            isSafeInternetAddress(InternetAddress.tryParse(address)!), isFalse);
      }
    });
  });

  group('isSafeHostForRemoteConnection', () {
    test('rejects localhost-like hostnames', () async {
      expect(await isSafeHostForRemoteConnection('localhost'), isFalse);
      expect(await isSafeHostForRemoteConnection('test.localhost'), isFalse);
      expect(await isSafeHostForRemoteConnection('printer.local'), isFalse);
    });

    test('rejects a host that resolves to any unsafe address', () async {
      Future<List<InternetAddress>> lookup(String _) async => [
            InternetAddress.tryParse('1.1.1.1')!,
            InternetAddress.tryParse('192.168.0.1')!,
          ];

      expect(
        await isSafeHostForRemoteConnection('example.com', lookup: lookup),
        isFalse,
      );
    });

    test('accepts a host that resolves only to safe addresses', () async {
      Future<List<InternetAddress>> lookup(String _) async => [
            InternetAddress.tryParse('1.1.1.1')!,
            InternetAddress.tryParse('8.8.8.8')!,
          ];

      expect(
        await isSafeHostForRemoteConnection('example.com', lookup: lookup),
        isTrue,
      );
    });
  });
}
