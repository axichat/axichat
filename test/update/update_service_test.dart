import 'dart:async';
import 'dart:convert';

import 'package:axichat/src/common/shorebird_push.dart';
import 'package:axichat/src/update/update_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolveUpdateChannel', () {
    test('returns none on web', () async {
      final channel = await resolveUpdateChannel(
        platform: TargetPlatform.android,
        isWeb: true,
        shorebirdEnabled: true,
      );

      expect(channel, UpdateChannel.none);
    });

    test('routes iOS to the App Store', () async {
      final channel = await resolveUpdateChannel(
        platform: TargetPlatform.iOS,
        isWeb: false,
        shorebirdEnabled: true,
      );

      expect(channel, UpdateChannel.appStore);
    });

    test('routes Shorebird-enabled Android builds to Play', () async {
      final channel = await resolveUpdateChannel(
        platform: TargetPlatform.android,
        isWeb: false,
        shorebirdEnabled: true,
      );

      expect(channel, UpdateChannel.playStore);
    });

    test('routes Shorebird-disabled Android builds to F-Droid', () async {
      final channel = await resolveUpdateChannel(
        platform: TargetPlatform.android,
        isWeb: false,
        shorebirdEnabled: false,
      );

      expect(channel, UpdateChannel.fdroid);
    });

    test('routes Windows builds to GitHub releases', () async {
      final channel = await resolveUpdateChannel(
        platform: TargetPlatform.windows,
        isWeb: false,
        shorebirdEnabled: true,
      );

      expect(channel, UpdateChannel.githubRelease);
    });

    test('routes Flatpak Linux builds to Flatpak', () async {
      final channel = await resolveUpdateChannel(
        platform: TargetPlatform.linux,
        isWeb: false,
        shorebirdEnabled: true,
        flatpakSandboxDetector: () async => true,
      );

      expect(channel, UpdateChannel.flatpak);
    });

    test('routes non-Flatpak Linux builds to GitHub releases', () async {
      final channel = await resolveUpdateChannel(
        platform: TargetPlatform.linux,
        isWeb: false,
        shorebirdEnabled: true,
        flatpakSandboxDetector: () async => false,
      );

      expect(channel, UpdateChannel.githubRelease);
    });
  });

  group('UpdateService', () {
    test('prefers the store offer over a Shorebird restart', () async {
      final shorebirdBackend = _RecordingShorebirdBackend(
        status: ShorebirdUpdateStatus.restartRequired,
        nextPatchNumber: 17,
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
          nextPatchNumber: 17,
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
        expect(result.currentOffer?.id, 'shorebird:1.2.3:45:17');
        expect(result.currentOffer?.availableVersion, '1.2.3');
        expect(result.currentOffer?.availableBuild, 45);
        expect(shorebirdBackend.applyUpdateCalls, [true]);
      },
    );

    test('falls back to Shorebird when the store check times out', () async {
      final shorebirdBackend = _RecordingShorebirdBackend(
        status: ShorebirdUpdateStatus.restartRequired,
        nextPatchNumber: 17,
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

    test(
      'suppresses warning logs for expected Play task failures from device state',
      () async {
        final shorebirdBackend = _RecordingShorebirdBackend(
          status: ShorebirdUpdateStatus.upToDate,
        );
        final logger = Logger('UpdateService.play.expected_failure');
        final records = <LogRecord>[];
        final subscription = logger.onRecord.listen(records.add);
        addTearDown(subscription.cancel);
        final service = UpdateService(
          httpClient: MockClient((_) async => throw UnimplementedError()),
          logger: logger,
          packageInfoLoader: () async => _packageInfo(),
          targetPlatformResolver: () => TargetPlatform.android,
          playStoreBackend: _ThrowingStoreBackend(
            error: PlatformException(
              code: 'TASK_FAILURE',
              message:
                  '-6: Install Error(-6): The download/install is not allowed.',
            ),
          ),
          shorebirdBackend: shorebirdBackend,
        );
        addTearDown(service.dispose);

        final result = await service.checkForUpdates();

        expect(result.currentOffer, isNull);
        expect(shorebirdBackend.applyUpdateCalls, [true]);
        expect(
          records.where((record) => record.level >= Level.WARNING),
          isEmpty,
        );
      },
    );

    test('uses GitHub releases for Windows updates', () async {
      final service = UpdateService(
        httpClient: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://api.github.com/repos/axichat/axichat/releases/latest',
          );
          return http.Response(
            jsonEncode({
              'tag_name': 'v2.0.0',
              'html_url':
                  'https://github.com/axichat/axichat/releases/tag/v2.0.0',
              'assets': [
                {'name': 'axichat-windows-setup.exe'},
              ],
            }),
            200,
          );
        }),
        packageInfoLoader: () async => _packageInfo(),
        targetPlatformResolver: () => TargetPlatform.windows,
        shorebirdBackend: _RecordingShorebirdBackend(
          status: ShorebirdUpdateStatus.upToDate,
        ),
      );
      addTearDown(service.dispose);

      final result = await service.checkForUpdates();

      expect(result.channel, UpdateChannel.githubRelease);
      expect(result.currentOffer?.kind, UpdateOfferKind.externalStore);
      expect(result.currentOffer?.availableVersion, '2.0.0');
      expect(
        result.currentOffer?.storeUrl,
        Uri.parse('https://github.com/axichat/axichat/releases/tag/v2.0.0'),
      );
    });

    test('uses the Flatpak backend for Flatpak Linux builds', () async {
      final service = UpdateService(
        httpClient: MockClient((_) async => throw UnimplementedError()),
        packageInfoLoader: () async => _packageInfo(),
        targetPlatformResolver: () => TargetPlatform.linux,
        flatpakSandboxDetector: () async => true,
        flatpakBackend: _FakeStoreBackend(
          offer: const UpdateOffer(
            id: 'flatpak:abc123',
            kind: UpdateOfferKind.flatpakUpdate,
            channel: UpdateChannel.flatpak,
          ),
        ),
        shorebirdBackend: _RecordingShorebirdBackend(
          status: ShorebirdUpdateStatus.upToDate,
        ),
      );
      addTearDown(service.dispose);

      final result = await service.checkForUpdates();

      expect(result.channel, UpdateChannel.flatpak);
      expect(result.currentOffer?.kind, UpdateOfferKind.flatpakUpdate);
      expect(result.currentOffer?.id, 'flatpak:abc123');
    });

    test('starts Flatpak updates through the backend', () async {
      final flatpakBackend = _InteractiveStoreBackend();
      final service = UpdateService(
        httpClient: MockClient((_) async => throw UnimplementedError()),
        flatpakBackend: flatpakBackend,
        shorebirdBackend: _RecordingShorebirdBackend(
          status: ShorebirdUpdateStatus.upToDate,
        ),
      );
      addTearDown(service.dispose);
      final offer = const UpdateOffer(
        id: 'flatpak:abc123',
        kind: UpdateOfferKind.flatpakUpdate,
        channel: UpdateChannel.flatpak,
      );

      final failure = await service.startUpdate(offer);

      expect(failure, isNull);
      expect(flatpakBackend.startedOffers, [offer]);
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
    required TargetPlatform platform,
  }) async => offer;
}

final class _InteractiveStoreBackend
    implements UpdateStoreBackend, InteractiveUpdateBackend {
  final List<UpdateOffer> startedOffers = <UpdateOffer>[];

  @override
  Future<UpdateOffer?> check({
    required UpdateChannel channel,
    required PackageInfo packageInfo,
    required TargetPlatform platform,
  }) async => null;

  @override
  Future<UpdateActionFailure?> startUpdate(UpdateOffer offer) async {
    startedOffers.add(offer);
    return null;
  }
}

final class _RecordingShorebirdBackend implements ShorebirdPatchBackend {
  _RecordingShorebirdBackend({required this.status, this.nextPatchNumber});

  final ShorebirdUpdateStatus status;
  final int? nextPatchNumber;
  final List<bool> applyUpdateCalls = [];

  @override
  Future<ShorebirdCheckResult> check({required bool applyUpdate}) async {
    applyUpdateCalls.add(applyUpdate);
    return ShorebirdCheckResult(
      status: status,
      nextPatchNumber: nextPatchNumber,
    );
  }
}

final class _ThrowingStoreBackend implements UpdateStoreBackend {
  const _ThrowingStoreBackend({required this.error});

  final Exception error;

  @override
  Future<UpdateOffer?> check({
    required UpdateChannel channel,
    required PackageInfo packageInfo,
    required TargetPlatform platform,
  }) => Future<UpdateOffer?>.error(error);
}
