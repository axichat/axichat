import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

import 'src/bindings.dart';

@ffi.DefaultAsset('package:delta_ffi/deltachat_wrap')
final DeltaChatBindings deltaBindings = DeltaChatBindings(loadDeltaLibrary());

ffi.DynamicLibrary loadDeltaLibrary() {
  final loaders = <ffi.DynamicLibrary Function()>[
    ffi.DynamicLibrary.process,
    if (Platform.isAndroid || Platform.isLinux)
      () => ffi.DynamicLibrary.open('libdeltachat_wrap.so'),
    if (Platform.isIOS || Platform.isMacOS)
      () => ffi.DynamicLibrary.open('libdeltachat_wrap.dylib'),
    if (Platform.isWindows) () => ffi.DynamicLibrary.open('deltachat_wrap.dll'),
  ];

  Object? lastError;
  for (final load in loaders) {
    try {
      final library = load();
      // Verify that the expected entrypoint is visible before returning.
      library.lookup<ffi.NativeFunction<ffi.Pointer<ffi.Void> Function()>>(
        'dc_context_new',
      );
      return library;
    } catch (error) {
      lastError = error;
    }
  }

  throw ArgumentError.value(
    lastError,
    'deltachat_wrap',
    'Failed to load deltachat native library.',
  );
}
