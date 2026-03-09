// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:convert';

import 'package:axichat/src/common/shorebird_push.dart';
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
  fdroid;

  bool get isStore => this != none;
}

enum UpdateOfferKind {
  playImmediate,
  playFlexible,
  playCompleteFlexible,
  externalStore,
  shorebirdRestart;

  bool get isPlayFlow =>
      this == UpdateOfferKind.playImmediate ||
      this == UpdateOfferKind.playFlexible ||
      this == UpdateOfferKind.playCompleteFlexible;

  bool get isStoreOffer => this != UpdateOfferKind.shorebirdRestart;
}

enum UpdateActionFailure { openStoreFailed, playUpdateFailed, userDeclined }

typedef PackageInfoLoader = Future<PackageInfo> Function();
typedef TargetPlatformResolver = TargetPlatform Function();
typedef UrlLauncher =
    Future<bool> Function(
      Uri url, {
      LaunchMode mode,
      WebViewConfiguration webViewConfiguration,
      String? webOnlyWindowName,
    });

UpdateChannel resolveUpdateChannel({
  required TargetPlatform platform,
  required bool isWeb,
  required bool shorebirdEnabled,
}) {
  if (isWeb) {
    return UpdateChannel.none;
  }
  return switch (platform) {
    TargetPlatform.iOS => UpdateChannel.appStore,
    TargetPlatform.android =>
      shorebirdEnabled ? UpdateChannel.playStore : UpdateChannel.fdroid,
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
    this.installedVersion,
    this.installedBuild,
    this.currentOffer,
  });

  final UpdateChannel channel;
  final ShorebirdUpdateStatus shorebirdStatus;
  final String? installedVersion;
  final int? installedBuild;
  final UpdateOffer? currentOffer;
}

abstract interface class UpdateStoreBackend {
  Future<UpdateOffer?> check({
    required UpdateChannel channel,
    required PackageInfo packageInfo,
  });
}

abstract interface class ShorebirdPatchBackend {
  Future<ShorebirdUpdateStatus> check({required bool applyUpdate});
}

abstract interface class DisposableUpdateBackend {
  void dispose();
}

final class UpdateService {
  UpdateService({
    required http.Client httpClient,
    PackageInfoLoader? packageInfoLoader,
    TargetPlatformResolver? targetPlatformResolver,
    bool isWeb = kIsWeb,
    UrlLauncher? launchUrlOverride,
    Logger? logger,
    UpdateStoreBackend? playStoreBackend,
    UpdateStoreBackend? appStoreBackend,
    UpdateStoreBackend? fdroidBackend,
    ShorebirdPatchBackend? shorebirdBackend,
  }) : _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
       _targetPlatformResolver =
           targetPlatformResolver ?? (() => defaultTargetPlatform),
       _isWeb = isWeb,
       _launchUrl = launchUrlOverride ?? launchUrl,
       _log = logger ?? Logger('UpdateService'),
       _playStoreBackend = playStoreBackend ?? const _PlayStoreUpdateBackend(),
       _appStoreBackend =
           appStoreBackend ?? _AppStoreUpdateBackend(httpClient: httpClient),
       _fdroidBackend =
           fdroidBackend ?? _FdroidUpdateBackend(httpClient: httpClient),
       _shorebirdBackend =
           shorebirdBackend ??
           _ShorebirdPatchBackend(shorebird: ShorebirdUpdater());

  final PackageInfoLoader _packageInfoLoader;
  final TargetPlatformResolver _targetPlatformResolver;
  final bool _isWeb;
  final UrlLauncher _launchUrl;
  final Logger _log;
  final UpdateStoreBackend _playStoreBackend;
  final UpdateStoreBackend _appStoreBackend;
  final UpdateStoreBackend _fdroidBackend;
  final ShorebirdPatchBackend _shorebirdBackend;

  PackageInfo? _packageInfo;

  Future<UpdateCheckResult> checkForUpdates() async {
    final channel = resolveUpdateChannel(
      platform: _targetPlatformResolver(),
      isWeb: _isWeb,
      shorebirdEnabled: kEnableShorebird,
    );
    final packageInfo = await _loadPackageInfo();
    final storeOffer = packageInfo == null
        ? null
        : await _checkStoreOffer(channel: channel, packageInfo: packageInfo);
    final shorebirdStatus = await _shorebirdBackend.check(
      applyUpdate: storeOffer == null,
    );
    return UpdateCheckResult(
      channel: channel,
      shorebirdStatus: shorebirdStatus,
      installedVersion: packageInfo?.version,
      installedBuild: _parseBuildNumber(packageInfo?.buildNumber),
      currentOffer:
          storeOffer ??
          _buildShorebirdOffer(channel, packageInfo, shorebirdStatus),
    );
  }

  Future<UpdateActionFailure?> startUpdate(UpdateOffer offer) async {
    return switch (offer.kind) {
      UpdateOfferKind.playImmediate => _performImmediateUpdate(),
      UpdateOfferKind.playFlexible => _performFlexibleUpdate(),
      UpdateOfferKind.playCompleteFlexible => _completeFlexibleUpdate(),
      UpdateOfferKind.externalStore => _openStoreUrl(offer.storeUrl),
      UpdateOfferKind.shorebirdRestart => null,
    };
  }

  void dispose() {
    final backends = [_appStoreBackend, _fdroidBackend, _playStoreBackend];
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

  Future<UpdateOffer?> _checkStoreOffer({
    required UpdateChannel channel,
    required PackageInfo packageInfo,
  }) async {
    final backend = switch (channel) {
      UpdateChannel.playStore => _playStoreBackend,
      UpdateChannel.appStore => _appStoreBackend,
      UpdateChannel.fdroid => _fdroidBackend,
      UpdateChannel.none => null,
    };
    if (backend == null) {
      return null;
    }
    try {
      return await backend.check(channel: channel, packageInfo: packageInfo);
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to check for a store update on $channel.',
        error,
        stackTrace,
      );
      return null;
    }
  }

  UpdateOffer? _buildShorebirdOffer(
    UpdateChannel channel,
    PackageInfo? packageInfo,
    ShorebirdUpdateStatus status,
  ) {
    if (!status.requiresRestart) {
      return null;
    }
    final version = packageInfo?.version;
    final build = _parseBuildNumber(packageInfo?.buildNumber);
    final id = version == null
        ? 'shorebird:restart'
        : 'shorebird:$version:${build ?? 0}';
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

  Future<UpdateActionFailure?> _performImmediateUpdate() async {
    try {
      final result = await InAppUpdate.performImmediateUpdate();
      return switch (result) {
        AppUpdateResult.success => null,
        AppUpdateResult.userDeniedUpdate => UpdateActionFailure.userDeclined,
        AppUpdateResult.inAppUpdateFailed =>
          UpdateActionFailure.playUpdateFailed,
      };
    } on PlatformException catch (error, stackTrace) {
      _log.warning('Immediate Play update failed.', error, stackTrace);
      return UpdateActionFailure.playUpdateFailed;
    }
  }

  Future<UpdateActionFailure?> _performFlexibleUpdate() async {
    try {
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.userDeniedUpdate) {
        return UpdateActionFailure.userDeclined;
      }
      if (result == AppUpdateResult.inAppUpdateFailed) {
        return UpdateActionFailure.playUpdateFailed;
      }
      return null;
    } on PlatformException catch (error, stackTrace) {
      _log.warning('Flexible Play update failed.', error, stackTrace);
      return UpdateActionFailure.playUpdateFailed;
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
      return UpdateActionFailure.playUpdateFailed;
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

  static const Duration _requestTimeout = Duration(seconds: 8);

  @override
  Future<UpdateOffer?> check({
    required UpdateChannel channel,
    required PackageInfo packageInfo,
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

  static const Duration _requestTimeout = Duration(seconds: 8);

  @override
  Future<UpdateOffer?> check({
    required UpdateChannel channel,
    required PackageInfo packageInfo,
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

final class _ShorebirdPatchBackend implements ShorebirdPatchBackend {
  const _ShorebirdPatchBackend({required ShorebirdUpdater shorebird})
    : _shorebird = shorebird;

  final ShorebirdUpdater _shorebird;

  @override
  Future<ShorebirdUpdateStatus> check({required bool applyUpdate}) =>
      checkShorebirdStatus(shorebird: _shorebird, applyUpdate: applyUpdate);
}
