import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io' show Directory, File, Platform, stderr;

import 'src/bindings.dart';

const _assetId = 'package:delta_ffi/deltachat_wrap';
const _libraryName = 'deltachat_wrap';
const _deltaLoadFailureMessage = 'Failed to load deltachat native library.';
const _deltaLoadFailureDetailsPrefix = ' (lastError: ';
const _deltaLoadFailureDetailsSuffix = ')';
const _dartToolDirectoryName = '.dart_tool';
const _libDirectoryName = 'lib';
const _dataDirectoryName = 'data';
const _flutterAssetsDirectoryName = 'flutter_assets';
const _nativeAssetsFileName = 'native_assets.yaml';
const _nativeAssetsKey = 'native-assets';
const _appDirEnvName = 'APPDIR';
const _snapDirEnvName = 'SNAP';
const _pwdEnvName = 'PWD';
const _flutterAssetsEnvName = 'FLUTTER_ASSETS';
const _traceEnvName = 'DELTA_FFI_TRACE';
const _procSelfExePath = '/proc/self/exe';
const int _bundleSearchDepth = 5;

@ffi.DefaultAsset(_assetId)
final DeltaChatBindings deltaBindings = DeltaChatBindings(loadDeltaLibrary());

ffi.DynamicLibrary loadDeltaLibrary() {
  Object? lastError;
  final bool traceEnabled = _isTraceEnabled();
  final List<String> trace = <String>[];

  void recordTrace(String message) {
    if (!traceEnabled) {
      return;
    }
    trace.add(message);
  }

  ffi.DynamicLibrary? tryLoad(
    ffi.DynamicLibrary Function() loader, {
    required String label,
  }) {
    try {
      final library = loader();
      library.lookup<ffi.NativeFunction<ffi.Pointer<ffi.Void> Function()>>(
        'dc_context_new',
      );
      recordTrace('loaded: $label');
      return library;
    } catch (error) {
      recordTrace('failed: $label -> $error');
      lastError = error;
      return null;
    }
  }

  final assetLibrary = tryLoad(
    () => ffi.DynamicLibrary.open(_assetId),
    label: _assetId,
  );
  if (assetLibrary != null) {
    return assetLibrary;
  }

  final configPath = _pathFromNativeAssetsConfig();
  if (configPath != null) {
    final configLibrary = tryLoad(
      () => ffi.DynamicLibrary.open(configPath),
      label: configPath,
    );
    if (configLibrary != null) {
      return configLibrary;
    }
  }

  final processLibrary = tryLoad(
    ffi.DynamicLibrary.process,
    label: 'process',
  );
  if (processLibrary != null) {
    return processLibrary;
  }

  final envOverride = Platform.environment['DELTA_FFI_LIBRARY_PATH'];
  if (envOverride != null && envOverride.isNotEmpty) {
    final envLibrary = tryLoad(
      () => ffi.DynamicLibrary.open(envOverride),
      label: envOverride,
    );
    if (envLibrary != null) {
      return envLibrary;
    }
  }

  for (final candidate in _bundledLibraryFiles(
    includeMissing: traceEnabled,
  )) {
    final library = tryLoad(
      () => ffi.DynamicLibrary.open(candidate),
      label: candidate,
    );
    if (library != null) {
      return library;
    }
  }

  for (final candidate in _candidateLibraryFiles(
    includeMissing: traceEnabled,
  )) {
    final library = tryLoad(
      () => ffi.DynamicLibrary.open(candidate),
      label: candidate,
    );
    if (library != null) {
      return library;
    }
  }

  for (final name in _platformLibraryNames()) {
    final library = tryLoad(
      () => ffi.DynamicLibrary.open(name),
      label: name,
    );
    if (library != null) {
      return library;
    }
  }

  if (traceEnabled && trace.isNotEmpty) {
    stderr.writeln('[delta_ffi] loadDeltaLibrary trace:');
    for (final entry in trace) {
      stderr.writeln('  $entry');
    }
  }

  final message = lastError == null
      ? _deltaLoadFailureMessage
      : '$_deltaLoadFailureMessage$_deltaLoadFailureDetailsPrefix'
          '$lastError$_deltaLoadFailureDetailsSuffix';
  throw ArgumentError.value(
    lastError,
    _libraryName,
    message,
  );
}

bool _isTraceEnabled() {
  final String? value = Platform.environment[_traceEnvName];
  return value != null && value.isNotEmpty && value != '0';
}

List<String> _candidateLibraryFiles({bool includeMissing = false}) {
  final results = <String>[];
  final seen = <String>{};

  void addPath(String? path) {
    if (path == null || path.isEmpty) return;
    if (!seen.add(path)) return;
    if (includeMissing || File(path).existsSync()) {
      results.add(path);
    }
  }

  for (final framework in _frameworkBinaryPaths()) {
    addPath(framework);
  }

  for (final directory in _probableLibraryDirectories()) {
    for (final name in _platformLibraryNames()) {
      addPath(_joinPath(directory.path, [name]));
    }
  }

  return results;
}

List<String> _bundledLibraryFiles({bool includeMissing = false}) {
  final results = <String>[];
  final seen = <String>{};

  void addPath(String? path) {
    if (path == null || path.isEmpty) return;
    if (!seen.add(path)) return;
    if (includeMissing || File(path).existsSync()) {
      results.add(path);
    }
  }

  for (final framework in _frameworkBinaryPaths()) {
    addPath(framework);
  }

  for (final Directory directory in _bundleSearchDirectories()) {
    for (final name in _platformLibraryNames()) {
      addPath(_joinPath(directory.path, [name]));
      addPath(_joinPath(directory.path, [_libDirectoryName, name]));
    }
  }

  return results;
}

Set<Directory> _bundleSearchDirectories() {
  final Set<Directory> results = <Directory>{};

  void addDirectory(Directory directory) {
    results.add(directory);
  }

  void addDirectoryWithParents(Directory directory) {
    Directory current = directory;
    for (var i = 0; i < _bundleSearchDepth; i++) {
      addDirectory(current);
      current = current.parent;
    }
  }

  addDirectoryWithParents(Directory.current);

  final String executablePath = Platform.resolvedExecutable;
  if (executablePath.isNotEmpty) {
    addDirectoryWithParents(File(executablePath).parent);
    final String resolvedPath = _resolveSymbolicPath(executablePath);
    if (resolvedPath.isNotEmpty) {
      addDirectoryWithParents(File(resolvedPath).parent);
    }
  }

  final scriptUri = Platform.script;
  if (scriptUri.scheme == 'file') {
    addDirectoryWithParents(File.fromUri(scriptUri).parent);
  }

  final String? pwd = Platform.environment[_pwdEnvName];
  if (pwd != null && pwd.isNotEmpty) {
    addDirectoryWithParents(Directory(pwd));
  }

  final String? appDir = Platform.environment[_appDirEnvName];
  if (appDir != null && appDir.isNotEmpty) {
    addDirectoryWithParents(Directory(appDir));
  }

  final String? snapDir = Platform.environment[_snapDirEnvName];
  if (snapDir != null && snapDir.isNotEmpty) {
    addDirectoryWithParents(Directory(snapDir));
  }

  final String? flutterAssets = Platform.environment[_flutterAssetsEnvName];
  if (flutterAssets != null && flutterAssets.isNotEmpty) {
    final assetsDir = Directory(flutterAssets);
    if (assetsDir.existsSync()) {
      addDirectoryWithParents(assetsDir);
      addDirectoryWithParents(assetsDir.parent);
      addDirectoryWithParents(assetsDir.parent.parent);
    }
  }

  final String? procExecutablePath = _resolveProcSelfExecutablePath();
  if (procExecutablePath != null && procExecutablePath.isNotEmpty) {
    addDirectoryWithParents(File(procExecutablePath).parent);
  }

  return results;
}

String _resolveSymbolicPath(String path) {
  if (path.isEmpty) {
    return path;
  }
  try {
    final resolved = File(path).resolveSymbolicLinksSync();
    if (resolved.isNotEmpty) {
      return resolved;
    }
  } catch (_) {
    // Ignore missing symlink support.
  }
  return path;
}

String? _resolveProcSelfExecutablePath() {
  if (!Platform.isLinux && !Platform.isAndroid) {
    return null;
  }
  try {
    final file = File(_procSelfExePath);
    if (!file.existsSync()) {
      return null;
    }
    final resolved = file.resolveSymbolicLinksSync();
    return resolved.isEmpty ? null : resolved;
  } catch (_) {
    return null;
  }
}

List<Directory> _probableLibraryDirectories() {
  final results = <Directory>[];
  final seen = <String>{};

  void addDirectory(String? path) {
    if (path == null || path.isEmpty) return;
    if (!seen.add(path)) return;
    final directory = Directory(path);
    if (directory.existsSync()) {
      results.add(directory);
    }
  }

  for (final directory in _bundleSearchDirectories()) {
    addDirectory(directory.path);
    addDirectory(
      _joinPath(directory.path, [_dartToolDirectoryName, _libDirectoryName]),
    );
  }

  return results;
}

Iterable<String> _frameworkBinaryPaths() {
  if (!Platform.isMacOS && !Platform.isIOS) {
    return const <String>[];
  }

  final results = <String>[];
  final seen = <String>{};

  void addPath(String? value) {
    if (value == null || value.isEmpty) return;
    if (seen.add(value)) {
      results.add(value);
    }
  }

  final executable = File(Platform.resolvedExecutable);
  final executableDir = executable.parent;

  if (Platform.isMacOS) {
    final contentsDir = executableDir.parent;
    final frameworksDir = _joinPath(contentsDir.path, ['Frameworks']);
    addPath(
      _joinPath(frameworksDir, ['deltachat_wrap.framework', 'deltachat_wrap']),
    );
    addPath(
      _joinPath(frameworksDir, [
        'deltachat_wrap.framework',
        'Versions',
        'Current',
        'deltachat_wrap',
      ]),
    );
    addPath(
      _joinPath(frameworksDir, [
        'deltachat_wrap.framework',
        'Versions',
        'A',
        'deltachat_wrap',
      ]),
    );
    final versionsDir = _joinPath(frameworksDir, [
      'deltachat_wrap.framework',
      'Versions',
    ]);
    if (versionsDir != null) {
      final directory = Directory(versionsDir);
      if (directory.existsSync()) {
        for (final entry in directory.listSync()) {
          if (entry is Directory) {
            addPath(_joinPath(entry.path, ['deltachat_wrap']));
          }
        }
      }
    }
  } else {
    final appDir = executableDir;
    final frameworksDir = _joinPath(appDir.path, ['Frameworks']);
    addPath(
      _joinPath(frameworksDir, ['deltachat_wrap.framework', 'deltachat_wrap']),
    );
  }

  return results;
}

List<String> _platformLibraryNames() {
  if (Platform.isWindows) {
    return const ['deltachat_wrap.dll'];
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return const ['libdeltachat_wrap.so', 'deltachat_wrap.so'];
  }
  if (Platform.isIOS || Platform.isMacOS) {
    return const [
      'libdeltachat_wrap.dylib',
      'deltachat_wrap.dylib',
      'deltachat_wrap'
    ];
  }
  return const ['libdeltachat_wrap.so'];
}

String? _pathFromNativeAssetsConfig() {
  final configPaths = <String>[];
  final seen = <String>{};

  void addConfigPath(String? base, List<String> segments) {
    final path = _joinPath(base, segments);
    if (path == null || path.isEmpty) {
      return;
    }
    if (seen.add(path)) {
      configPaths.add(path);
    }
  }

  addConfigPath(
    Directory.current.path,
    [_dartToolDirectoryName, _nativeAssetsFileName],
  );

  final String? flutterAssets = Platform.environment[_flutterAssetsEnvName];
  if (flutterAssets != null && flutterAssets.isNotEmpty) {
    addConfigPath(
      flutterAssets,
      [_dartToolDirectoryName, _nativeAssetsFileName],
    );
  }

  for (final directory in _bundleSearchDirectories()) {
    addConfigPath(
      directory.path,
      [_dartToolDirectoryName, _nativeAssetsFileName],
    );
    addConfigPath(
      directory.path,
      [
        _dataDirectoryName,
        _flutterAssetsDirectoryName,
        _dartToolDirectoryName,
        _nativeAssetsFileName,
      ],
    );
    addConfigPath(
      directory.path,
      [
        _flutterAssetsDirectoryName,
        _dartToolDirectoryName,
        _nativeAssetsFileName,
      ],
    );
  }

  for (final path in configPaths) {
    final configFile = File(path);
    if (!configFile.existsSync()) {
      continue;
    }
    try {
      final filtered = configFile
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('#'))
          .join('\n')
          .trim();
      if (filtered.isEmpty) {
        continue;
      }
      final data = jsonDecode(filtered) as Map<String, dynamic>;
      final targetKey = _currentTargetKey();
      if (targetKey == null) {
        continue;
      }
      final nativeAssets = data[_nativeAssetsKey];
      if (nativeAssets is! Map) {
        continue;
      }

      final String? resolved = _resolveAssetPathFromConfig(
        nativeAssets: nativeAssets,
        targetKey: targetKey,
        basePath: configFile.parent.path,
      );
      if (resolved != null) {
        return resolved;
      }
    } catch (_) {
      continue;
    }
  }

  return null;
}

String? _resolveAssetPathFromConfig({
  required Map nativeAssets,
  required String? targetKey,
  required String basePath,
}) {
  final candidates = <Map>[];
  if (targetKey != null) {
    final targetAssets = nativeAssets[targetKey];
    if (targetAssets is Map) {
      candidates.add(targetAssets);
    }
  }

  for (final value in nativeAssets.values) {
    if (value is Map && value.containsKey(_assetId)) {
      candidates.add(value);
    }
  }

  for (final targetAssets in candidates) {
    final assetEntry = targetAssets[_assetId];
    if (assetEntry is! List || assetEntry.isEmpty) {
      continue;
    }
    final locationType = assetEntry[0];
    final value = assetEntry.length > 1 ? assetEntry[1] : null;
    if (locationType == 'absolute' && value is String) {
      return value;
    }
    if (locationType == 'relative' && value is String) {
      return _joinPath(basePath, [value]);
    }
    if (locationType == 'system' && value is String) {
      return value;
    }
    if (locationType == 'executable') {
      return Platform.resolvedExecutable;
    }
  }

  return null;
}

String? _currentTargetKey() {
  try {
    return ffi.Abi.current().toString();
  } catch (_) {
    return null;
  }
}

String? _joinPath(String? base, List<String> segments) {
  if (base == null || base.isEmpty) return null;
  var uri = Directory(base).uri;
  for (var i = 0; i < segments.length; i++) {
    final rawSegment = segments[i];
    if (rawSegment.isEmpty) continue;
    final isLast = i == segments.length - 1;
    final needsSlash = !isLast;
    final segment =
        needsSlash && !rawSegment.endsWith('/') ? '$rawSegment/' : rawSegment;
    uri = uri.resolve(segment);
  }
  return uri.toFilePath();
}
