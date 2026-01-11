import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io' show Directory, File, Platform;

import 'src/bindings.dart';

const _assetId = 'package:delta_ffi/deltachat_wrap';
const _libraryName = 'deltachat_wrap';
const _deltaLoadFailureMessage = 'Failed to load deltachat native library.';
const _deltaLoadFailureDetailsPrefix = ' (lastError: ';
const _deltaLoadFailureDetailsSuffix = ')';

@ffi.DefaultAsset(_assetId)
final DeltaChatBindings deltaBindings = DeltaChatBindings(loadDeltaLibrary());

const bool _isProduct = bool.fromEnvironment('dart.vm.product');
const List<String> _requiredDeltaSymbols = [
  'dc_accounts_add_account',
  'dc_accounts_add_closed_account',
  'dc_accounts_background_fetch',
  'dc_accounts_get_account',
  'dc_accounts_get_all',
  'dc_accounts_get_event_emitter',
  'dc_accounts_maybe_network',
  'dc_accounts_maybe_network_lost',
  'dc_accounts_migrate_account',
  'dc_accounts_new',
  'dc_accounts_remove_account',
  'dc_accounts_set_push_device_token',
  'dc_accounts_start_io',
  'dc_accounts_stop_io',
  'dc_accounts_unref',
  'dc_array_get_cnt',
  'dc_array_get_id',
  'dc_array_unref',
  'dc_block_contact',
  'dc_chat_get_contact_id',
  'dc_chat_get_mailinglist_addr',
  'dc_chat_get_name',
  'dc_chat_get_type',
  'dc_chat_unref',
  'dc_chatlist_get_chat_id',
  'dc_chatlist_get_cnt',
  'dc_chatlist_get_msg_id',
  'dc_chatlist_unref',
  'dc_configure',
  'dc_contact_get_addr',
  'dc_contact_get_name',
  'dc_contact_unref',
  'dc_context_change_passphrase',
  'dc_context_is_open',
  'dc_context_new',
  'dc_context_new_closed',
  'dc_context_open',
  'dc_context_unref',
  'dc_create_chat_by_contact_id',
  'dc_create_contact',
  'dc_delete_contact',
  'dc_delete_msgs',
  'dc_download_full_msg',
  'dc_event_emitter_unref',
  'dc_event_get_account_id',
  'dc_event_get_data1_int',
  'dc_event_get_data1_str',
  'dc_event_get_data2_int',
  'dc_event_get_data2_str',
  'dc_event_get_id',
  'dc_event_unref',
  'dc_forward_msgs',
  'dc_get_blocked_contacts',
  'dc_get_chat',
  'dc_get_chat_contacts',
  'dc_get_chat_msgs',
  'dc_get_chatlist',
  'dc_get_connectivity',
  'dc_get_contact',
  'dc_get_contacts',
  'dc_get_draft',
  'dc_get_event_emitter',
  'dc_get_fresh_msg_cnt',
  'dc_get_fresh_msgs',
  'dc_get_last_error',
  'dc_get_msg',
  'dc_get_msg_cnt',
  'dc_get_next_event',
  'dc_is_configured',
  'dc_lookup_contact_id_by_addr',
  'dc_marknoticed_chat',
  'dc_markseen_msgs',
  'dc_maybe_network',
  'dc_msg_get_chat_id',
  'dc_msg_get_download_state',
  'dc_msg_get_error',
  'dc_msg_get_file',
  'dc_msg_get_filebytes',
  'dc_msg_get_filename',
  'dc_msg_get_filemime',
  'dc_msg_get_height',
  'dc_msg_get_html',
  'dc_msg_get_id',
  'dc_msg_get_quoted_msg',
  'dc_msg_get_quoted_text',
  'dc_msg_get_state',
  'dc_msg_get_subject',
  'dc_msg_get_text',
  'dc_msg_get_timestamp',
  'dc_msg_get_viewtype',
  'dc_msg_get_width',
  'dc_msg_is_outgoing',
  'dc_msg_new',
  'dc_msg_set_file_and_deduplicate',
  'dc_msg_set_html',
  'dc_msg_set_quote',
  'dc_msg_set_subject',
  'dc_msg_set_text',
  'dc_msg_unref',
  'dc_resend_msgs',
  'dc_search_msgs',
  'dc_send_msg',
  'dc_send_text_msg',
  'dc_set_chat_visibility',
  'dc_set_config',
  'dc_set_draft',
  'dc_start_io',
  'dc_stop_io',
  'dc_str_unref',
  'dc_unblock_contact',
];

ffi.DynamicLibrary loadDeltaLibrary() {
  Object? lastError;

  ffi.DynamicLibrary? finalizeLibrary(ffi.DynamicLibrary? library) {
    if (library == null) return null;
    if (_isProduct) {
      _assertRequiredSymbols(library);
    }
    return library;
  }

  ffi.DynamicLibrary? tryLoad(ffi.DynamicLibrary Function() loader) {
    try {
      final library = loader();
      library.lookup<ffi.NativeFunction<ffi.Pointer<ffi.Void> Function()>>(
        'dc_context_new',
      );
      return finalizeLibrary(library);
    } catch (error) {
      lastError = error;
      return null;
    }
  }

  final assetLibrary = tryLoad(() => ffi.DynamicLibrary.open(_assetId));
  if (assetLibrary != null) {
    return assetLibrary;
  }

  final configPath = _pathFromNativeAssetsConfig();
  if (configPath != null) {
    final configLibrary = tryLoad(() => ffi.DynamicLibrary.open(configPath));
    if (configLibrary != null) {
      return configLibrary;
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

  for (final candidate in _bundledLibraryFiles()) {
    final library = tryLoad(() => ffi.DynamicLibrary.open(candidate));
    if (library != null) {
      return library;
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

void _assertRequiredSymbols(ffi.DynamicLibrary library) {
  for (final symbol in _requiredDeltaSymbols) {
    try {
      library.lookup<ffi.NativeFunction<ffi.Void Function()>>(symbol);
    } on ArgumentError {
      throw ArgumentError.value(
        symbol,
        'symbol',
        'Missing required DeltaChat symbol in bundled library.',
      );
    }
  }
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

List<String> _bundledLibraryFiles() {
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

  final exeDir = File(Platform.resolvedExecutable).parent;
  for (final name in _platformLibraryNames()) {
    addPath(_joinPath(exeDir.path, [name]));
    addPath(_joinPath(exeDir.path, ['lib', name]));
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
