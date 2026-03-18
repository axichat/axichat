// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:convert';

import 'package:axichat/src/common/legal_urls.dart';
import 'package:axichat/src/common/shorebird_push.dart';
import 'package:axichat/src/update/flatpak_update_portal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:upgrader/upgrader.dart';
import 'package:url_launcher/url_launcher.dart';

enum UpdateChannel {
  none,
  playStore,
  appStore,
  fdroid,
  githubRelease,
  flatpak;

  bool get isStore => this != none && this != githubRelease;
}

enum UpdateOfferKind {
  playImmediate,
  playFlexible,
  playCompleteFlexible,
  externalStore,
  flatpakUpdate,
  shorebirdRestart;

  bool get isPlayFlow =>
      this == UpdateOfferKind.playImmediate ||
      this == UpdateOfferKind.playFlexible ||
      this == UpdateOfferKind.playCompleteFlexible;

  bool get isStoreOffer => this != UpdateOfferKind.shorebirdRestart;
}

enum UpdateActionFailure { openStoreFailed, startUpdateFailed, userDeclined }

typedef PackageInfoLoader = Future<PackageInfo> Function();
typedef TargetPlatformResolver = TargetPlatform Function();
typedef FlatpakSandboxDetector = Future<bool> Function();
typedef UrlLauncher =
    Future<bool> Function(
      Uri url, {
      LaunchMode mode,
      WebViewConfiguration webViewConfiguration,
      String? webOnlyWindowName,
    });

Future<UpdateChannel> resolveUpdateChannel({
  required TargetPlatform platform,
  required bool isWeb,
  required bool shorebirdEnabled,
  FlatpakSandboxDetector? flatpakSandboxDetector,
}) async {
  if (isWeb) {
    return UpdateChannel.none;
  }
  if (platform == TargetPlatform.linux) {
    final isFlatpak = await (flatpakSandboxDetector ?? isFlatpakSandbox)();
    return isFlatpak ? UpdateChannel.flatpak : UpdateChannel.githubRelease;
  }
  return switch (platform) {
    TargetPlatform.iOS => UpdateChannel.appStore,
    TargetPlatform.android =>
      shorebirdEnabled ? UpdateChannel.playStore : UpdateChannel.fdroid,
    TargetPlatform.windows => UpdateChannel.githubRelease,
    _ => UpdateChannel.none,
  };
}

final class UpdateOffer {
  const UpdateOffer({
    required this.id,
    required this.kind,
    required this.channel,
    this.availableVersion,
    this.availableBuild,
    this.storeUrl,
  });

  final String id;
  final UpdateOfferKind kind;
  final UpdateChannel channel;
  final String? availableVersion;
  final int? availableBuild;
  final Uri? storeUrl;
}

final class UpdateCheckResult {
  const UpdateCheckResult({
    required this.channel,
    required this.shorebirdStatus,
    this.shorebirdNextPatchNumber,
    this.installedVersion,
    this.installedBuild,
    this.currentOffer,
  });

  final UpdateChannel channel;
  final ShorebirdUpdateStatus shorebirdStatus;
  final int? shorebirdNextPatchNumber;
  final String? installedVersion;
  final int? installedBuild;
  final UpdateOffer? currentOffer;
}

abstract interface class UpdateStoreBackend {
  Future<UpdateOffer?> check({
    required UpdateChannel channel,
    required PackageInfo packageInfo,
    required TargetPlatform platform,
  });
}

abstract interface class ShorebirdPatchBackend {
  Future<ShorebirdCheckResult> check({required bool applyUpdate});
}

abstract interface class InteractiveUpdateBackend {
  Future<UpdateActionFailure?> startUpdate(UpdateOffer offer);
}

abstract interface class DisposableUpdateBackend {
  void dispose();
}

final class UpdateService {
  UpdateService({
    required http.Client httpClient,
    PackageInfoLoader? packageInfoLoader,
    TargetPlatformResolver? targetPlatformResolver,
    FlatpakSandboxDetector? flatpakSandboxDetector,
    bool isWeb = kIsWeb,
    UrlLauncher? launchUrlOverride,
    Logger? logger,
    UpdateStoreBackend? playStoreBackend,
    UpdateStoreBackend? appStoreBackend,
    UpdateStoreBackend? fdroidBackend,
    UpdateStoreBackend? githubReleaseBackend,
    UpdateStoreBackend? flatpakBackend,
    ShorebirdPatchBackend? shorebirdBackend,
  }) : _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
       _targetPlatformResolver =
           targetPlatformResolver ?? (() => defaultTargetPlatform),
       _flatpakSandboxDetector = flatpakSandboxDetector ?? isFlatpakSandbox,
       _isWeb = isWeb,
       _launchUrl = launchUrlOverride ?? launchUrl,
       _log = logger ?? Logger('UpdateService'),
       _playStoreBackend = playStoreBackend ?? const _PlayStoreUpdateBackend(),
       _appStoreBackend =
           appStoreBackend ?? _AppStoreUpdateBackend(httpClient: httpClient),
       _fdroidBackend =
           fdroidBackend ?? _FdroidUpdateBackend(httpClient: httpClient),
       _githubReleaseBackend =
           githubReleaseBackend ??
           _GitHubReleaseUpdateBackend(httpClient: httpClient),
       _flatpakBackend =
           flatpakBackend ??
           _FlatpakUpdateBackend(portal: createFlatpakUpdatePortal()),
       _shorebirdBackend =
           shorebirdBackend ??
           _ShorebirdPatchBackend(shorebird: ShorebirdUpdater());

  final PackageInfoLoader _packageInfoLoader;
  final TargetPlatformResolver _targetPlatformResolver;
  final FlatpakSandboxDetector _flatpakSandboxDetector;
  final bool _isWeb;
  final UrlLauncher _launchUrl;
  final Logger _log;
  final UpdateStoreBackend _playStoreBackend;
  final UpdateStoreBackend _appStoreBackend;
  final UpdateStoreBackend _fdroidBackend;
  final UpdateStoreBackend _githubReleaseBackend;
  final UpdateStoreBackend _flatpakBackend;
  final ShorebirdPatchBackend _shorebirdBackend;

  PackageInfo? _packageInfo;

  Future<UpdateCheckResult> checkForUpdates() async {
    final targetPlatform = _targetPlatformResolver();
    final channel = await resolveUpdateChannel(
      platform: targetPlatform,
      isWeb: _isWeb,
      shorebirdEnabled: kEnableShorebird,
      flatpakSandboxDetector: _flatpakSandboxDetector,
    );
    final packageInfo = await _loadPackageInfo();
    final storeOffer = packageInfo == null
        ? null
        : await _checkUpdateOffer(
            channel: channel,
            packageInfo: packageInfo,
            platform: targetPlatform,
          );
    final shorebirdResult = await _shorebirdBackend.check(
      applyUpdate: storeOffer == null,
    );
    return UpdateCheckResult(
      channel: channel,
      shorebirdStatus: shorebirdResult.status,
      shorebirdNextPatchNumber: shorebirdResult.nextPatchNumber,
      installedVersion: packageInfo?.version,
      installedBuild: _parseBuildNumber(packageInfo?.buildNumber),
      currentOffer:
          storeOffer ??
          _buildShorebirdOffer(
            channel,
            packageInfo,
            shorebirdResult.status,
            shorebirdResult.nextPatchNumber,
          ),
    );
  }

  Future<UpdateActionFailure?> startUpdate(UpdateOffer offer) async {
    return switch (offer.kind) {
      UpdateOfferKind.playImmediate => _performImmediateUpdate(),
      UpdateOfferKind.playFlexible => _performFlexibleUpdate(),
      UpdateOfferKind.playCompleteFlexible => _completeFlexibleUpdate(),
      UpdateOfferKind.externalStore => _openStoreUrl(offer.storeUrl),
      UpdateOfferKind.flatpakUpdate => _startBackendUpdate(
        backend: _flatpakBackend,
        offer: offer,
      ),
      UpdateOfferKind.shorebirdRestart => null,
    };
  }

  void dispose() {
    final backends = [
      _appStoreBackend,
      _fdroidBackend,
      _playStoreBackend,
      _githubReleaseBackend,
      _flatpakBackend,
    ];
    for (final backend in backends) {
      if (backend is DisposableUpdateBackend) {
        (backend as DisposableUpdateBackend).dispose();
      }
    }
  }

  Future<PackageInfo?> _loadPackageInfo() async {
    if (_packageInfo != null) {
      return _packageInfo;
    }
    try {
      final loaded = await _packageInfoLoader();
      _packageInfo = loaded;
      return loaded;
    } on MissingPluginException catch (error, stackTrace) {
      _log.warning(
        'Package info plugin is unavailable for update checks.',
        error,
        stackTrace,
      );
      return null;
    } on PlatformException catch (error, stackTrace) {
      _log.warning(
        'Failed to read package info for update checks.',
        error,
        stackTrace,
      );
      return null;
    }
  }

  Future<UpdateOffer?> _checkUpdateOffer({
    required UpdateChannel channel,
    required PackageInfo packageInfo,
    required TargetPlatform platform,
  }) async {
    final backend = switch (channel) {
      UpdateChannel.playStore => _playStoreBackend,
      UpdateChannel.appStore => _appStoreBackend,
      UpdateChannel.fdroid => _fdroidBackend,
      UpdateChannel.githubRelease => _githubReleaseBackend,
      UpdateChannel.flatpak => _flatpakBackend,
      UpdateChannel.none => null,
    };
    if (backend == null) {
      return null;
    }
    try {
      return await backend.check(
        channel: channel,
        packageInfo: packageInfo,
        platform: platform,
      );
    } on PlatformException catch (error, stackTrace) {
      if (_isExpectedPlayStoreCheckFailure(channel: channel, error: error)) {
        _log.info(
          'Skipping Play in-app update check: ${error.message ?? error.code}.',
        );
        return null;
      }
      _log.warning(
        'Failed to check for an update on $channel.',
        error,
        stackTrace,
      );
      return null;
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to check for an update on $channel.',
        error,
        stackTrace,
      );
      return null;
    }
  }

  bool _isExpectedPlayStoreCheckFailure({
    required UpdateChannel channel,
    required PlatformException error,
  }) {
    if (channel != UpdateChannel.playStore || error.code != 'TASK_FAILURE') {
      return false;
    }
    final message = error.message;
    if (message == null || message.isEmpty) {
      return false;
    }
    final match = RegExp(r'Install Error\((-?\d+)\)').firstMatch(message);
    final installErrorCode = match == null
        ? null
        : int.tryParse(match.group(1)!);
    return installErrorCode == -5 || installErrorCode == -6;
  }

  UpdateOffer? _buildShorebirdOffer(
    UpdateChannel channel,
    PackageInfo? packageInfo,
    ShorebirdUpdateStatus status,
    int? nextPatchNumber,
  ) {
    if (!status.requiresRestart) {
      return null;
    }
    final version = packageInfo?.version;
    final build = _parseBuildNumber(packageInfo?.buildNumber);
    final versionToken = version ?? 'unknown';
    final patchToken = nextPatchNumber?.toString() ?? 'unknown';
    final id = 'shorebird:$versionToken:${build ?? 0}:$patchToken';
    return UpdateOffer(
      id: id,
      kind: UpdateOfferKind.shorebirdRestart,
      channel: channel,
      availableVersion: version,
      availableBuild: build,
    );
  }

  int? _parseBuildNumber(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return int.tryParse(raw);
  }

  Future<UpdateActionFailure?> _startBackendUpdate({
    required UpdateStoreBackend backend,
    required UpdateOffer offer,
  }) async {
    if (backend is! InteractiveUpdateBackend) {
      return UpdateActionFailure.startUpdateFailed;
    }
    return (backend as InteractiveUpdateBackend).startUpdate(offer);
  }

  Future<UpdateActionFailure?> _performImmediateUpdate() async {
    try {
      final result = await InAppUpdate.performImmediateUpdate();
      return switch (result) {
        AppUpdateResult.success => null,
        AppUpdateResult.userDeniedUpdate => UpdateActionFailure.userDeclined,
        AppUpdateResult.inAppUpdateFailed =>
          UpdateActionFailure.startUpdateFailed,
      };
    } on PlatformException catch (error, stackTrace) {
      _log.warning('Immediate Play update failed.', error, stackTrace);
      return UpdateActionFailure.startUpdateFailed;
    }
  }

  Future<UpdateActionFailure?> _performFlexibleUpdate() async {
    try {
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.userDeniedUpdate) {
        return UpdateActionFailure.userDeclined;
      }
      if (result == AppUpdateResult.inAppUpdateFailed) {
        return UpdateActionFailure.startUpdateFailed;
      }
      return null;
    } on PlatformException catch (error, stackTrace) {
      _log.warning('Flexible Play update failed.', error, stackTrace);
      return UpdateActionFailure.startUpdateFailed;
    }
  }

  Future<UpdateActionFailure?> _completeFlexibleUpdate() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
      return null;
    } on PlatformException catch (error, stackTrace) {
      _log.warning(
        'Completing flexible Play update failed.',
        error,
        stackTrace,
      );
      return UpdateActionFailure.startUpdateFailed;
    }
  }

  Future<UpdateActionFailure?> _openStoreUrl(Uri? storeUrl) async {
    if (storeUrl == null) {
      return UpdateActionFailure.openStoreFailed;
    }
    try {
      final launched = await _launchUrl(
        storeUrl,
        mode: LaunchMode.externalApplication,
      );
      return launched ? null : UpdateActionFailure.openStoreFailed;
    } on MissingPluginException catch (error, stackTrace) {
      _log.warning('Store launcher plugin is unavailable.', error, stackTrace);
      return UpdateActionFailure.openStoreFailed;
    } on PlatformException catch (error, stackTrace) {
      _log.warning('Opening the store URL failed.', error, stackTrace);
      return UpdateActionFailure.openStoreFailed;
    }
  }
}

final class _PlayStoreUpdateBackend implements UpdateStoreBackend {
  const _PlayStoreUpdateBackend();

  @override
  Future<UpdateOffer?> check({
    required UpdateChannel channel,
    required PackageInfo packageInfo,
    required TargetPlatform platform,
  }) async {
    final info = await InAppUpdate.checkForUpdate();
    final availability = info.updateAvailability;
    if (availability == UpdateAvailability.updateNotAvailable ||
        availability == UpdateAvailability.unknown) {
      return null;
    }
    final availableBuild = info.availableVersionCode;
    final baseId = 'play:${availableBuild ?? packageInfo.buildNumber}';
    if (availability == UpdateAvailability.developerTriggeredUpdateInProgress &&
        info.installStatus == InstallStatus.downloaded) {
      return UpdateOffer(
        id: '$baseId:complete',
        kind: UpdateOfferKind.playCompleteFlexible,
        channel: channel,
        availableBuild: availableBuild,
      );
    }
    if (availability != UpdateAvailability.updateAvailable) {
      return null;
    }
    if (info.immediateUpdateAllowed &&
        (info.updatePriority >= 4 ||
            (info.clientVersionStalenessDays ?? 0) >= 7)) {
      return UpdateOffer(
        id: '$baseId:immediate',
        kind: UpdateOfferKind.playImmediate,
        channel: channel,
        availableBuild: availableBuild,
      );
    }
    if (info.flexibleUpdateAllowed) {
      return UpdateOffer(
        id: '$baseId:flexible',
        kind: UpdateOfferKind.playFlexible,
        channel: channel,
        availableBuild: availableBuild,
      );
    }
    if (info.immediateUpdateAllowed) {
      return UpdateOffer(
        id: '$baseId:immediate',
        kind: UpdateOfferKind.playImmediate,
        channel: channel,
        availableBuild: availableBuild,
      );
    }
    return UpdateOffer(
      id: '$baseId:store',
      kind: UpdateOfferKind.externalStore,
      channel: channel,
      availableBuild: availableBuild,
      storeUrl: Uri.parse(
        'https://play.google.com/store/apps/details?id=${packageInfo.packageName}',
      ),
    );
  }
}

final class _AppStoreUpdateBackend
    implements UpdateStoreBackend, DisposableUpdateBackend {
  _AppStoreUpdateBackend({required http.Client httpClient})
    : _upgrader = Upgrader(
        client: httpClient,
        storeController: UpgraderStoreController(
          onAndroid: null,
          oniOS: UpgraderAppStore.new,
          onFuchsia: null,
          onLinux: null,
          onMacOS: null,
          onWeb: null,
          onWindows: null,
        ),
      );

  final Upgrader _upgrader;
  bool _initialized = false;

  static const Duration _requestTimeout = Duration(seconds: 15);

  @override
  Future<UpdateOffer?> check({
    required UpdateChannel channel,
    required PackageInfo packageInfo,
    required TargetPlatform platform,
  }) async {
    if (!_initialized) {
      await _upgrader.initialize().timeout(_requestTimeout);
      _initialized = true;
    } else {
      await _upgrader.updateVersionInfo().timeout(_requestTimeout);
    }
    if (!_upgrader.isUpdateAvailable()) {
      return null;
    }
    final versionInfo = _upgrader.versionInfo;
    final storeUrl = versionInfo?.appStoreListingURL;
    final parsedStoreUrl = storeUrl == null ? null : Uri.tryParse(storeUrl);
    if (parsedStoreUrl == null) {
      return null;
    }
    final availableVersion = versionInfo?.appStoreVersion?.toString();
    return UpdateOffer(
      id: 'appstore:${availableVersion ?? packageInfo.version}',
      kind: UpdateOfferKind.externalStore,
      channel: channel,
      availableVersion: availableVersion,
      storeUrl: parsedStoreUrl,
    );
  }

  @override
  void dispose() {
    _upgrader.dispose();
  }
}

final class _FdroidUpdateBackend
    implements UpdateStoreBackend, DisposableUpdateBackend {
  _FdroidUpdateBackend({required http.Client httpClient})
    : _httpClient = httpClient,
      _log = Logger('FDroidUpdateBackend');

  final http.Client _httpClient;
  final Logger _log;

  static const Duration _requestTimeout = Duration(seconds: 15);

  @override
  Future<UpdateOffer?> check({
    required UpdateChannel channel,
    required PackageInfo packageInfo,
    required TargetPlatform platform,
  }) async {
    final installedBuild = int.tryParse(packageInfo.buildNumber);
    if (installedBuild == null) {
      return null;
    }
    final packageName = packageInfo.packageName;
    if (packageName.isEmpty) {
      return null;
    }
    final apiUri = Uri.parse(
      'https://f-droid.org/api/v1/packages/$packageName',
    );
    http.Response response;
    try {
      response = await _httpClient.get(apiUri).timeout(_requestTimeout);
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to fetch F-Droid package metadata.',
        error,
        stackTrace,
      );
      return null;
    }
    if (response.statusCode != 200) {
      return null;
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final rawSuggestedBuild = decoded['suggestedVersionCode'];
    final suggestedBuild = switch (rawSuggestedBuild) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value),
      _ => null,
    };
    if (suggestedBuild == null || suggestedBuild <= installedBuild) {
      return null;
    }
    final suggestedVersion = decoded['suggestedVersionName'] as String?;
    return UpdateOffer(
      id: 'fdroid:$suggestedBuild',
      kind: UpdateOfferKind.externalStore,
      channel: channel,
      availableVersion: suggestedVersion,
      availableBuild: suggestedBuild,
      storeUrl: Uri.parse('https://f-droid.org/packages/$packageName/'),
    );
  }

  @override
  void dispose() {}
}

final class _GitHubReleaseUpdateBackend implements UpdateStoreBackend {
  _GitHubReleaseUpdateBackend({required http.Client httpClient})
    : _httpClient = httpClient,
      _repositoryUri = Uri.parse(githubUrl),
      _log = Logger('GitHubReleaseUpdateBackend');

  final http.Client _httpClient;
  final Uri _repositoryUri;
  final Logger _log;

  static const Duration _requestTimeout = Duration(seconds: 15);

  @override
  Future<UpdateOffer?> check({
    required UpdateChannel channel,
    required PackageInfo packageInfo,
    required TargetPlatform platform,
  }) async {
    final releaseApiUri = _releaseApiUri();
    if (releaseApiUri == null) {
      return null;
    }
    http.Response response;
    try {
      response = await _httpClient
          .get(
            releaseApiUri,
            headers: const {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
              'User-Agent': 'Axichat Update Checker',
            },
          )
          .timeout(_requestTimeout);
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to fetch GitHub release metadata.',
        error,
        stackTrace,
      );
      return null;
    }
    if (response.statusCode != 200) {
      return null;
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    if (!_hasSupportedDesktopAsset(decoded, platform)) {
      return null;
    }
    final availableVersion = _availableVersion(decoded);
    if (availableVersion == null) {
      return null;
    }
    if (!_isRemoteVersionNewer(
      installedVersion: packageInfo.version,
      availableVersion: availableVersion,
    )) {
      return null;
    }
    final releaseUrl =
        Uri.tryParse(decoded['html_url'] as String? ?? '') ??
        Uri.parse('${_repositoryUri.toString()}/releases');
    return UpdateOffer(
      id: 'github:$availableVersion',
      kind: UpdateOfferKind.externalStore,
      channel: channel,
      availableVersion: availableVersion,
      storeUrl: releaseUrl,
    );
  }

  Uri? _releaseApiUri() {
    final segments = _repositoryUri.pathSegments
        .where((item) => item.isNotEmpty)
        .toList();
    if (segments.length < 2) {
      return null;
    }
    final owner = segments[0];
    final repo = segments[1];
    return Uri.https('api.github.com', '/repos/$owner/$repo/releases/latest');
  }

  bool _hasSupportedDesktopAsset(
    Map<String, dynamic> release,
    TargetPlatform platform,
  ) {
    final assets = release['assets'];
    if (assets is! List) {
      return false;
    }
    final assetNames = assets
        .whereType<Map<String, dynamic>>()
        .map((asset) => asset['name'])
        .whereType<String>();
    return switch (platform) {
      TargetPlatform.windows => assetNames.any(
        (name) =>
            name == 'axichat-windows-setup.exe' ||
            name == 'axichat-windows.zip',
      ),
      TargetPlatform.linux => assetNames.any(
        (name) =>
            name == 'axichat-linux.tar.gz' ||
            (name.startsWith('axichat-linux-') && name.endsWith('.deb')),
      ),
      _ => false,
    };
  }

  String? _availableVersion(Map<String, dynamic> release) {
    final tagName = release['tag_name'] as String?;
    final name = release['name'] as String?;
    return _extractSemanticVersion(tagName) ?? _extractSemanticVersion(name);
  }

  bool _isRemoteVersionNewer({
    required String installedVersion,
    required String availableVersion,
  }) {
    if (installedVersion == availableVersion) {
      return false;
    }
    final installedParts = _parseSemanticVersion(installedVersion);
    final availableParts = _parseSemanticVersion(availableVersion);
    if (installedParts == null || availableParts == null) {
      return false;
    }
    for (var index = 0; index < installedParts.length; index++) {
      final installedPart = installedParts[index];
      final availablePart = availableParts[index];
      if (availablePart > installedPart) {
        return true;
      }
      if (availablePart < installedPart) {
        return false;
      }
    }
    return false;
  }

  String? _extractSemanticVersion(String? raw) {
    final parsed = _parseSemanticVersion(raw);
    if (parsed == null) {
      return null;
    }
    return '${parsed[0]}.${parsed[1]}.${parsed[2]}';
  }

  List<int>? _parseSemanticVersion(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final match = RegExp(r'v?(\d+)\.(\d+)\.(\d+)').firstMatch(raw);
    if (match == null) {
      return null;
    }
    return [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    ];
  }
}

final class _FlatpakUpdateBackend
    implements
        UpdateStoreBackend,
        InteractiveUpdateBackend,
        DisposableUpdateBackend {
  _FlatpakUpdateBackend({required FlatpakUpdatePortal? portal})
    : _portal = portal,
      _log = Logger('FlatpakUpdateBackend');

  final FlatpakUpdatePortal? _portal;
  final Logger _log;

  FlatpakUpdateMonitor? _monitor;
  StreamSubscription<FlatpakUpdateInfo>? _updateSubscription;
  Completer<void>? _firstCheckCompleter;
  FlatpakUpdateInfo? _latestUpdateInfo;
  bool _monitorInitialized = false;

  static const Duration _monitorTimeout = Duration(seconds: 15);
  static const Duration _initialSignalTimeout = Duration(seconds: 15);

  @override
  Future<UpdateOffer?> check({
    required UpdateChannel channel,
    required PackageInfo packageInfo,
    required TargetPlatform platform,
  }) async {
    await _ensureMonitor();
    await _awaitInitialSignal();
    final updateInfo = _latestUpdateInfo;
    if (updateInfo == null || !updateInfo.hasUpdate) {
      return null;
    }
    return UpdateOffer(
      id: 'flatpak:${updateInfo.remoteCommit ?? 'unknown'}',
      kind: UpdateOfferKind.flatpakUpdate,
      channel: channel,
    );
  }

  @override
  Future<UpdateActionFailure?> startUpdate(UpdateOffer offer) async {
    final monitor = _monitor;
    if (monitor == null) {
      return UpdateActionFailure.startUpdateFailed;
    }
    try {
      await monitor.update().timeout(_monitorTimeout);
      return null;
    } on Exception catch (error, stackTrace) {
      _log.warning('Starting the Flatpak update failed.', error, stackTrace);
      return UpdateActionFailure.startUpdateFailed;
    }
  }

  @override
  void dispose() {
    final subscription = _updateSubscription;
    _updateSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    final monitor = _monitor;
    _monitor = null;
    if (monitor != null) {
      unawaited(monitor.close());
    }
  }

  Future<void> _ensureMonitor() async {
    if (_monitorInitialized) {
      return;
    }
    _monitorInitialized = true;
    _firstCheckCompleter = Completer<void>();
    final portal = _portal;
    if (portal == null) {
      _completeFirstCheck();
      return;
    }
    try {
      final monitor = await portal.createUpdateMonitor().timeout(
        _monitorTimeout,
      );
      _monitor = monitor;
      _updateSubscription = monitor.updateAvailable.listen(
        (updateInfo) {
          _latestUpdateInfo = updateInfo;
          _completeFirstCheck();
        },
        onError: (Object error, StackTrace stackTrace) {
          _log.warning('Flatpak update monitor failed.', error, stackTrace);
          _completeFirstCheck();
        },
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to create the Flatpak update monitor.',
        error,
        stackTrace,
      );
      _completeFirstCheck();
    }
  }

  Future<void> _awaitInitialSignal() async {
    final completer = _firstCheckCompleter;
    if (completer == null || completer.isCompleted) {
      return;
    }
    try {
      await completer.future.timeout(_initialSignalTimeout);
    } on TimeoutException {
      _completeFirstCheck();
    }
  }

  void _completeFirstCheck() {
    final completer = _firstCheckCompleter;
    if (completer == null || completer.isCompleted) {
      return;
    }
    completer.complete();
  }
}

final class _ShorebirdPatchBackend implements ShorebirdPatchBackend {
  const _ShorebirdPatchBackend({required ShorebirdUpdater shorebird})
    : _shorebird = shorebird;

  final ShorebirdUpdater _shorebird;

  @override
  Future<ShorebirdCheckResult> check({required bool applyUpdate}) =>
      checkShorebirdStatus(shorebird: _shorebird, applyUpdate: applyUpdate);
}
