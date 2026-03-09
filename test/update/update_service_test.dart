import 'package:axichat/src/common/shorebird_push.dart';
import 'package:axichat/src/update/update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  group('resolveUpdateChannel', () {
    test('returns none on web', () {
      final channel = resolveUpdateChannel(
        platform: TargetPlatform.android,
        isWeb: true,
        shorebirdEnabled: true,
      );

      expect(channel, UpdateChannel.none);
    });

    test('routes iOS to the App Store', () {
      final channel = resolveUpdateChannel(
        platform: TargetPlatform.iOS,
        isWeb: false,
        shorebirdEnabled: true,
      );

      expect(channel, UpdateChannel.appStore);
    });

    test('routes Shorebird-enabled Android builds to Play', () {
      final channel = resolveUpdateChannel(
        platform: TargetPlatform.android,
        isWeb: false,
        shorebirdEnabled: true,
      );

      expect(channel, UpdateChannel.playStore);
    });

    test('routes Shorebird-disabled Android builds to F-Droid', () {
      final channel = resolveUpdateChannel(
        platform: TargetPlatform.android,
        isWeb: false,
        shorebirdEnabled: false,
      );

      expect(channel, UpdateChannel.fdroid);
    });
  });

  group('UpdateService', () {
    test('prefers the store offer over a Shorebird restart', () async {
      final service = UpdateService(
        httpClient: MockClient((_) async => throw UnimplementedError()),
        packageInfoLoader: () async => _packageInfo(),
        targetPlatformResolver: () => TargetPlatform.iOS,
        appStoreBackend: _FakeStoreBackend(
          offer: UpdateOffer(
            id: 'appstore:2.0.0',
            kind: UpdateOfferKind.externalStore,
            channel: UpdateChannel.appStore,
            availableVersion: '2.0.0',
            storeUrl: Uri.parse('https://apps.apple.com/app/id123'),
          ),
        ),
        shorebirdBackend: const _FakeShorebirdBackend(
          status: ShorebirdUpdateStatus.restartRequired,
        ),
      );
      addTearDown(service.dispose);

      final result = await service.checkForUpdates();

      expect(result.channel, UpdateChannel.appStore);
      expect(result.shorebirdStatus, ShorebirdUpdateStatus.restartRequired);
      expect(result.currentOffer?.id, 'appstore:2.0.0');
      expect(result.currentOffer?.kind, UpdateOfferKind.externalStore);
    });

    test(
      'falls back to a Shorebird restart when no store offer exists',
      () async {
        final service = UpdateService(
          httpClient: MockClient((_) async => throw UnimplementedError()),
          packageInfoLoader: () async => _packageInfo(),
          targetPlatformResolver: () => TargetPlatform.iOS,
          appStoreBackend: const _FakeStoreBackend(offer: null),
          shorebirdBackend: const _FakeShorebirdBackend(
            status: ShorebirdUpdateStatus.restartRequired,
          ),
        );
        addTearDown(service.dispose);

        final result = await service.checkForUpdates();

        expect(result.channel, UpdateChannel.appStore);
        expect(result.currentOffer?.kind, UpdateOfferKind.shorebirdRestart);
        expect(result.currentOffer?.availableVersion, '1.2.3');
        expect(result.currentOffer?.availableBuild, 45);
      },
    );
  });
}

PackageInfo _packageInfo() => PackageInfo(
  appName: 'Axichat',
  packageName: 'im.axi.axichat',
  version: '1.2.3',
  buildNumber: '45',
  buildSignature: '',
  installerStore: null,
);

final class _FakeStoreBackend implements UpdateStoreBackend {
  const _FakeStoreBackend({required this.offer});

  final UpdateOffer? offer;

  @override
  Future<UpdateOffer?> check({
    required UpdateChannel channel,
    required PackageInfo packageInfo,
  }) async => offer;
}

final class _FakeShorebirdBackend implements ShorebirdPatchBackend {
  const _FakeShorebirdBackend({required this.status});

  final ShorebirdUpdateStatus status;

  @override
  Future<ShorebirdUpdateStatus> check() async => status;
}
