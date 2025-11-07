import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart' as hooks;

Future<void> main(List<String> args) async {
  await hooks.build(args,
      (hooks.BuildInput input, hooks.BuildOutputBuilder output) async {
    final config = input.config;
    if (!config.buildCodeAssets) {
      return;
    }
    await _ensureDeltachatCrateTypePatched();

    final codeConfig = config.code;
    final packageRoot = input.packageRoot;
    final crateDir = packageRoot.resolve('rust/');
    final targetTriple =
        _rustTargetTriple(codeConfig.targetOS, codeConfig.targetArchitecture);
    final isRelease = _isReleaseBuild(input);

    final buildArgs = [
      'build',
      '--manifest-path',
      crateDir.resolve('Cargo.toml').toFilePath(),
      '--target',
      targetTriple,
      if (isRelease) '--release',
    ];

    final environment = Map<String, String>.from(Platform.environment)
      ..addAll(_cargoEnvForTarget(
        triple: targetTriple,
        codeConfig: codeConfig,
      ));

    final result = await Process.run(
      'cargo',
      buildArgs,
      workingDirectory: crateDir.toFilePath(),
      environment: environment,
    );

    if (result.exitCode != 0) {
      final stderrSink = stderr;
      stderrSink.writeln(result.stdout);
      stderrSink.writeln(result.stderr);
      throw ProcessException(
        'cargo',
        buildArgs,
        result.stderr is String ? result.stderr as String : '${result.stderr}',
        result.exitCode,
      );
    }

    final libraryName = _libraryFileName(codeConfig.targetOS, 'deltachat_wrap');
    final artifact = crateDir
        .resolve('target/')
        .resolve('$targetTriple/')
        .resolve(isRelease ? 'release/' : 'debug/')
        .resolve(libraryName);

    final outputUri = input.outputDirectory.resolve(libraryName);
    final outputFile = File.fromUri(outputUri);
    await outputFile.parent.create(recursive: true);
    await File.fromUri(artifact).copy(outputFile.path);

    output.dependencies.add(crateDir.resolve('Cargo.toml'));

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'deltachat_wrap',
        file: outputUri,
        linkMode: DynamicLoadingBundled(),
      ),
    );
  });
}

String _rustTargetTriple(OS os, Architecture architecture) {
  return switch ((os, architecture)) {
    (OS.macOS, Architecture.x64) => 'x86_64-apple-darwin',
    (OS.macOS, Architecture.arm64) => 'aarch64-apple-darwin',
    (OS.linux, Architecture.x64) => 'x86_64-unknown-linux-gnu',
    (OS.linux, Architecture.arm64) => 'aarch64-unknown-linux-gnu',
    (OS.android, Architecture.arm64) => 'aarch64-linux-android',
    (OS.android, Architecture.x64) => 'x86_64-linux-android',
    (OS.android, Architecture.arm) => 'armv7-linux-androideabi',
    (OS.android, Architecture.ia32) => 'i686-linux-android',
    _ => throw UnsupportedError(
        'Unsupported target combination: ${os.name}/${architecture.name}',
      ),
  };
}

String _libraryFileName(OS os, String name) {
  if (os == OS.macOS || os == OS.iOS) {
    return 'lib$name.dylib';
  }
  if (os == OS.windows) {
    return '$name.dll';
  }
  return 'lib$name.so';
}

Map<String, String> _cargoEnvForTarget({
  required String triple,
  required CodeConfig codeConfig,
}) {
  final env = <String, String>{};
  final cCompiler = codeConfig.cCompiler;
  if (cCompiler != null) {
    var compilerPath = cCompiler.compiler.toFilePath();
    final archiverPath = cCompiler.archiver.toFilePath();
    var linkerPath = cCompiler.linker.toFilePath();
    String? cxxPath;
    final tripleKey = triple.toUpperCase().replaceAll('-', '_');
    final toolchainDir = File(compilerPath).parent.path;

    if (codeConfig.targetOS == OS.android) {
      final androidConfig = codeConfig.android;
      final ndkApi = androidConfig?.targetNdkApi;
      if (ndkApi != null) {
        final targetPrefix = '$triple$ndkApi';
        final targetClang =
            _toolchainBinary(toolchainDir, '$targetPrefix-clang');
        final targetClangxx =
            _toolchainBinary(toolchainDir, '$targetPrefix-clang++');
        if (targetClang != null) {
          compilerPath = targetClang;
        }
        if (targetClangxx != null) {
          linkerPath = targetClangxx;
          cxxPath = targetClangxx;
        }
        final targetArg = '--target=$targetPrefix';
        env['CFLAGS_$tripleKey'] = targetArg;
        env['CXXFLAGS_$tripleKey'] = targetArg;
      }
    }

    env['CARGO_TARGET_${tripleKey}_LINKER'] = linkerPath;
    env['CARGO_TARGET_${tripleKey}_AR'] = archiverPath;
    env['CC_$tripleKey'] = compilerPath;
    if (cxxPath != null) {
      env['CXX_$tripleKey'] = cxxPath;
    }
    env['AR_$tripleKey'] = archiverPath;
    env['PATH'] = [
      File(linkerPath).parent.path,
      File(compilerPath).parent.path,
      Platform.environment['PATH'] ?? '',
    ].where((element) => element.isNotEmpty).join(':');
  }

  if (codeConfig.targetOS == OS.android) {
    final androidConfig = codeConfig.android;
    if (androidConfig != null) {
      env['ANDROID_NDK_API_LEVEL'] = '${androidConfig.targetNdkApi}';
    }
  }

  return env;
}

Future<void> _ensureDeltachatCrateTypePatched() async {
  final cargoHome = Platform.environment['CARGO_HOME'] ??
      _joinPaths(Platform.environment['HOME'], '.cargo');
  if (cargoHome == null) {
    return;
  }

  final checkoutsPath = _joinPaths(cargoHome, 'git', 'checkouts');
  if (checkoutsPath == null) {
    return;
  }
  final checkouts = Directory(checkoutsPath);
  if (!checkouts.existsSync()) {
    return;
  }

  for (final repoDir in checkouts.listSync().whereType<Directory>()) {
    for (final checkoutDir in repoDir.listSync().whereType<Directory>()) {
      final cargoTomlPath =
          _joinPaths(checkoutDir.path, 'deltachat-ffi', 'Cargo.toml');
      if (cargoTomlPath == null) {
        continue;
      }
      final cargoToml = File(cargoTomlPath);
      if (!cargoToml.existsSync()) {
        continue;
      }

      final contents = await cargoToml.readAsString();
      if (contents.contains('"rlib"')) {
        continue;
      }

      final updated = contents.replaceFirstMapped(
        RegExp(r'crate-type\s*=\s*\[(.*?)\]', dotAll: true),
        (match) {
          final body = match.group(1) ?? '';
          if (body.contains('rlib')) {
            return match.group(0)!;
          }
          final trimmed = body.trim();
          final suffix = trimmed.isEmpty ? '"rlib"' : '$trimmed, "rlib"';
          return 'crate-type = [$suffix]';
        },
      );

      if (contents != updated) {
        await cargoToml.writeAsString(updated);
      }
    }
  }
}

String? _joinPaths(String? first, [String? second, String? third]) {
  if (first == null || first.isEmpty) {
    return null;
  }
  final buffer = StringBuffer(first);
  final separator = Platform.pathSeparator;
  void append(String? segment) {
    if (segment == null || segment.isEmpty) {
      return;
    }
    final current = buffer.toString();
    if (!current.endsWith(separator)) {
      buffer.write(separator);
    }
    buffer.write(segment);
  }

  append(second);
  append(third);
  return buffer.toString();
}

String? _toolchainBinary(String directory, String binaryName) {
  final path = _joinPaths(directory, binaryName);
  if (path == null) {
    return null;
  }
  final file = File(path);
  if (!file.existsSync()) {
    return null;
  }
  return file.path;
}

bool _isReleaseBuild(hooks.BuildInput input) {
  const releaseNames = {'release', 'profile'};
  final config = input.config;
  final modeName = _buildModeName(config);
  if (modeName != null && releaseNames.contains(modeName)) {
    return true;
  }

  final environmentMode = Platform.environment['FLUTTER_BUILD_MODE'] ??
      Platform.environment['BUILD_MODE'] ??
      Platform.environment['CONFIGURATION'];
  if (environmentMode != null &&
      releaseNames.contains(environmentMode.toLowerCase())) {
    return true;
  }

  return false;
}

String? _buildModeName(Object config) {
  try {
    final dynamic dynamicConfig = config;
    final dynamic buildMode = dynamicConfig.buildMode;
    if (buildMode == null) {
      return null;
    }

    try {
      final dynamic dynamicMode = buildMode;
      final Object? name = dynamicMode.name;
      if (name is String && name.isNotEmpty) {
        return name.toLowerCase();
      }
    } catch (_) {
      // Ignore missing name getter.
    }

    final description = buildMode.toString();
    final modeName = description.split('.').last.toLowerCase();
    if (modeName.isNotEmpty) {
      return modeName;
    }
  } catch (_) {
    // Intentionally ignored; fall back to environment detection.
  }

  return null;
}
