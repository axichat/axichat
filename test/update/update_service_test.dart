import 'dart:async';

import 'package:axichat/src/common/shorebird_push.dart';
import 'package:axichat/src/update/update_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
      final shorebirdBackend = _RecordingShorebirdBackend(
        status: ShorebirdUpdateStatus.restartRequired,
      );
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
        shorebirdBackend: shorebirdBackend,
      );
      addTearDown(service.dispose);

      final result = await service.checkForUpdates();

      expect(result.channel, UpdateChannel.appStore);
      expect(result.shorebirdStatus, ShorebirdUpdateStatus.restartRequired);
      expect(result.currentOffer?.id, 'appstore:2.0.0');
      expect(result.currentOffer?.kind, UpdateOfferKind.externalStore);
      expect(shorebirdBackend.applyUpdateCalls, [false]);
    });

    test(
      'falls back to a Shorebird restart when no store offer exists',
      () async {
        final shorebirdBackend = _RecordingShorebirdBackend(
          status: ShorebirdUpdateStatus.restartRequired,
        );
        final service = UpdateService(
          httpClient: MockClient((_) async => throw UnimplementedError()),
          packageInfoLoader: () async => _packageInfo(),
          targetPlatformResolver: () => TargetPlatform.iOS,
          appStoreBackend: const _FakeStoreBackend(offer: null),
          shorebirdBackend: shorebirdBackend,
        );
        addTearDown(service.dispose);

        final result = await service.checkForUpdates();

        expect(result.channel, UpdateChannel.appStore);
        expect(result.currentOffer?.kind, UpdateOfferKind.shorebirdRestart);
        expect(result.currentOffer?.availableVersion, '1.2.3');
        expect(result.currentOffer?.availableBuild, 45);
        expect(shorebirdBackend.applyUpdateCalls, [true]);
      },
    );

    test('falls back to Shorebird when the store check times out', () async {
      final shorebirdBackend = _RecordingShorebirdBackend(
        status: ShorebirdUpdateStatus.restartRequired,
      );
      final service = UpdateService(
        httpClient: MockClient((_) async => throw UnimplementedError()),
        packageInfoLoader: () async => _packageInfo(),
        targetPlatformResolver: () => TargetPlatform.iOS,
        appStoreBackend: _ThrowingStoreBackend(
          error: TimeoutException('store lookup timed out'),
        ),
        shorebirdBackend: shorebirdBackend,
      );
      addTearDown(service.dispose);

      final result = await service.checkForUpdates();

      expect(result.currentOffer?.kind, UpdateOfferKind.shorebirdRestart);
      expect(shorebirdBackend.applyUpdateCalls, [true]);
    });

    test('returns an open-store failure when launching throws', () async {
      final service = UpdateService(
        httpClient: MockClient((_) async => throw UnimplementedError()),
        launchUrlOverride:
            (
              url, {
              mode = LaunchMode.platformDefault,
              webViewConfiguration = const WebViewConfiguration(),
              webOnlyWindowName,
            }) async {
              throw PlatformException(code: 'launch_failed');
            },
        appStoreBackend: const _FakeStoreBackend(offer: null),
        shorebirdBackend: _RecordingShorebirdBackend(
          status: ShorebirdUpdateStatus.upToDate,
        ),
      );
      addTearDown(service.dispose);

      final failure = await service.startUpdate(
        UpdateOffer(
          id: 'appstore:2.0.0',
          kind: UpdateOfferKind.externalStore,
          channel: UpdateChannel.appStore,
          storeUrl: Uri.parse('https://apps.apple.com/app/id123'),
        ),
      );

      expect(failure, UpdateActionFailure.openStoreFailed);
    });

    test('continues when package info plugin is unavailable', () async {
      final shorebirdBackend = _RecordingShorebirdBackend(
        status: ShorebirdUpdateStatus.upToDate,
      );
      final service = UpdateService(
        httpClient: MockClient((_) async => throw UnimplementedError()),
        packageInfoLoader: () => Future<PackageInfo>.error(
          MissingPluginException('package info unavailable'),
        ),
        targetPlatformResolver: () => TargetPlatform.iOS,
        appStoreBackend: const _FakeStoreBackend(offer: null),
        shorebirdBackend: shorebirdBackend,
      );
      addTearDown(service.dispose);

      final result = await service.checkForUpdates();

      expect(result.installedVersion, isNull);
      expect(result.installedBuild, isNull);
      expect(result.currentOffer, isNull);
      expect(shorebirdBackend.applyUpdateCalls, [true]);
    });
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

final class _RecordingShorebirdBackend implements ShorebirdPatchBackend {
  _RecordingShorebirdBackend({required this.status});

  final ShorebirdUpdateStatus status;
  final List<bool> applyUpdateCalls = [];

  @override
  Future<ShorebirdUpdateStatus> check({required bool applyUpdate}) async {
    applyUpdateCalls.add(applyUpdate);
    return status;
  }
}

final class _ThrowingStoreBackend implements UpdateStoreBackend {
  const _ThrowingStoreBackend({required this.error});

  final Exception error;

  @override
  Future<UpdateOffer?> check({
    required UpdateChannel channel,
    required PackageInfo packageInfo,
  }) => Future<UpdateOffer?>.error(error);
}
