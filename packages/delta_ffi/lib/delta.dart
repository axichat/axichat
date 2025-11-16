import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io' show Directory, File, Platform;

import 'src/bindings.dart';

const _assetId = 'package:delta_ffi/deltachat_wrap';
const _libraryName = 'deltachat_wrap';

@ffi.DefaultAsset(_assetId)
final DeltaChatBindings deltaBindings = DeltaChatBindings(loadDeltaLibrary());

ffi.DynamicLibrary loadDeltaLibrary() {
  Object? lastError;

  ffi.DynamicLibrary? tryLoad(ffi.DynamicLibrary Function() loader) {
    try {
      final library = loader();
      library.lookup<ffi.NativeFunction<ffi.Pointer<ffi.Void> Function()>>(
        'dc_context_new',
      );
      return library;
    } catch (error) {
      lastError = error;
      return null;
    }
  }

  final processLibrary = tryLoad(ffi.DynamicLibrary.process);
  if (processLibrary != null) {
    return processLibrary;
  }

  final envOverride = Platform.environment['DELTA_FFI_LIBRARY_PATH'];
  if (envOverride != null && envOverride.isNotEmpty) {
    final envLibrary = tryLoad(() => ffi.DynamicLibrary.open(envOverride));
    if (envLibrary != null) {
      return envLibrary;
    }
  }

  final configPath = _pathFromNativeAssetsConfig();
  if (configPath != null) {
    final configLibrary = tryLoad(() => ffi.DynamicLibrary.open(configPath));
    if (configLibrary != null) {
      return configLibrary;
    }
  }

  for (final candidate in _candidateLibraryFiles()) {
    final library = tryLoad(() => ffi.DynamicLibrary.open(candidate));
    if (library != null) {
      return library;
    }
  }

  for (final name in _platformLibraryNames()) {
    final library = tryLoad(() => ffi.DynamicLibrary.open(name));
    if (library != null) {
      return library;
    }
  }

  throw ArgumentError.value(
    lastError,
    _libraryName,
    'Failed to load deltachat native library.',
  );
}

List<String> _candidateLibraryFiles() {
  final results = <String>[];
  final seen = <String>{};

  void addPath(String? path) {
    if (path == null || path.isEmpty) return;
    if (!seen.add(path)) return;
    if (File(path).existsSync()) {
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

  final cwd = Directory.current.path;
  addDirectory(cwd);
  addDirectory(_joinPath(cwd, ['.dart_tool', 'lib']));

  final executable = Platform.resolvedExecutable;
  final exeDir = File(executable).parent.path;
  addDirectory(exeDir);
  addDirectory(_joinPath(exeDir, ['.dart_tool', 'lib']));

  final scriptUri = Platform.script;
  if (scriptUri.scheme == 'file') {
    final scriptDir = File.fromUri(scriptUri).parent;
    addDirectory(scriptDir.path);
    addDirectory(_joinPath(scriptDir.path, ['.dart_tool', 'lib']));
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
  final configPath =
      _joinPath(Directory.current.path, ['.dart_tool', 'native_assets.yaml']);
  if (configPath == null) {
    return null;
  }
  final configFile = File(configPath);
  if (!configFile.existsSync()) {
    return null;
  }

  try {
    final filtered = configFile
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('#'))
        .join('\n')
        .trim();
    if (filtered.isEmpty) {
      return null;
    }
    final data = jsonDecode(filtered) as Map<String, dynamic>;
    final targetKey = _currentTargetKey();
    if (targetKey == null) {
      return null;
    }
    final nativeAssets = data['native-assets'];
    if (nativeAssets is! Map) {
      return null;
    }
    final targetAssets = nativeAssets[targetKey];
    if (targetAssets is! Map) {
      return null;
    }
    final assetEntry = targetAssets[_assetId];
    if (assetEntry is! List || assetEntry.isEmpty) {
      return null;
    }
    final locationType = assetEntry[0];
    final value = assetEntry.length > 1 ? assetEntry[1] : null;
    if (locationType == 'absolute' && value is String) {
      return value;
    }
    if (locationType == 'relative' && value is String) {
      return _joinPath(Directory.current.path, [value]);
    }
    if (locationType == 'system' && value is String) {
      return value;
    }
    if (locationType == 'executable') {
      return Platform.resolvedExecutable;
    }
  } catch (_) {
    return null;
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
