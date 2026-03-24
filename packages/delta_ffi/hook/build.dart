import 'dart:async';
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
    stdout.writeln('[delta_ffi] Preparing native build.');
    await _ensureDeltachatCrateTypePatched();
    stdout.writeln('[delta_ffi] Crate type patch check complete.');

    final codeConfig = config.code;
    final packageRoot = input.packageRoot;
    final crateDir = packageRoot.resolve('rust/');
    final targetTriple =
        _rustTargetTriple(codeConfig.targetOS, codeConfig.targetArchitecture);
    final resolvedMode = _resolveBuildMode(input, args);
    final isRelease = _isReleaseMode(resolvedMode.name);
    final cargoTargetDir = input.outputDirectory.resolve('cargo-target/');
    final cargoExecutable = _cargoExecutable();
    final isVerboseBuild = _isVerboseBuild();

    final buildArgs = [
      'build',
      if (isVerboseBuild) '-v' else '--quiet',
      '--manifest-path',
      crateDir.resolve('Cargo.toml').toFilePath(),
      '--target',
      targetTriple,
      if (isRelease) '--release',
    ];

    final tripleKeyCargo = targetTriple.toUpperCase().replaceAll('-', '_');
    final environment = await _cargoEnvironment(
      triple: targetTriple,
      codeConfig: codeConfig,
      cargoTargetDir: cargoTargetDir,
    );

    final linkerEnvKey = 'CARGO_TARGET_${tripleKeyCargo}_LINKER';
    stdout.writeln(
        '[delta_ffi] Target: $targetTriple (${codeConfig.targetOS.name}/${codeConfig.targetArchitecture.name})');
    stderr.writeln(
      '[delta_ffi] Resolved build mode: ${resolvedMode.name} (source: ${resolvedMode.source})',
    );
    stderr.writeln(
        '[delta_ffi][warning] Using linker: ${environment[linkerEnvKey] ?? 'default'}');
    stderr.writeln('[delta_ffi] Using cargo executable: $cargoExecutable');
    stderr.writeln(
        '[delta_ffi] Running cargo from ${crateDir.toFilePath()} with args: ${buildArgs.join(' ')}');
    stderr.writeln(
        '[delta_ffi] Using cargo target dir: ${cargoTargetDir.toFilePath()}');

    late final Process process;
    try {
      process = await Process.start(
        cargoExecutable,
        buildArgs,
        workingDirectory: crateDir.toFilePath(),
        environment: environment,
      );
    } on ProcessException catch (error) {
      throw ProcessException(
        cargoExecutable,
        buildArgs,
        '${error.message}\n${_missingCargoHelp()}',
        error.errorCode,
      );
    }
    stdout.writeln('[delta_ffi] Cargo started with pid ${process.pid}.');

    final stdoutOutput = _pipeProcessOutput(
      process.stdout,
      stdout,
    );
    final stderrOutput = _pipeProcessOutput(
      process.stderr,
      stderr,
    );
    final stopwatch = Stopwatch()..start();
    final heartbeat = isVerboseBuild
        ? Timer.periodic(const Duration(seconds: 15), (_) {
            stdout.writeln(
              '[delta_ffi] Cargo still running after ${stopwatch.elapsed}.',
            );
          })
        : null;
    final exitCode = await process.exitCode;
    heartbeat?.cancel();
    stopwatch.stop();
    final capturedStdout = await stdoutOutput;
    final capturedStderr = await stderrOutput;
    stdout.writeln(
      '[delta_ffi] Cargo exited with code $exitCode after ${stopwatch.elapsed}.',
    );

    if (exitCode != 0) {
      throw ProcessException(
        'cargo',
        buildArgs,
        capturedStderr.isNotEmpty ? capturedStderr : capturedStdout,
        exitCode,
      );
    }

    final libraryName = _libraryFileName(codeConfig.targetOS, 'deltachat_wrap');
    final artifact = cargoTargetDir
        .resolve('$targetTriple/')
        .resolve(isRelease ? 'release/' : 'debug/')
        .resolve(libraryName);

    final outputUri = input.outputDirectory.resolve(libraryName);
    final outputFile = File.fromUri(outputUri);
    await outputFile.parent.create(recursive: true);
    stderr.writeln(
      '[delta_ffi] Copying native artifact from ${artifact.toFilePath()} to ${outputFile.path}',
    );
    await File.fromUri(artifact).copy(outputFile.path);
    await _stripBundledLinuxReleaseArtifactIfNeeded(
      outputFile: outputFile,
      targetOS: codeConfig.targetOS,
      isRelease: isRelease,
    );

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

Future<void> _stripBundledLinuxReleaseArtifactIfNeeded({
  required File outputFile,
  required OS targetOS,
  required bool isRelease,
}) async {
  if (!isRelease || targetOS != OS.linux) {
    return;
  }

  final stripExecutable =
      _findExecutableInPath('llvm-strip') ?? _findExecutableInPath('strip');
  if (stripExecutable == null || stripExecutable.isEmpty) {
    stderr.writeln(
      '[delta_ffi][warning] No strip executable found; leaving ${outputFile.path} unstripped.',
    );
    return;
  }

  final stripArgs = ['--strip-unneeded', outputFile.path];
  stderr.writeln(
    '[delta_ffi] Stripping Linux release artifact with $stripExecutable ${stripArgs.join(' ')}',
  );

  final result = await Process.run(stripExecutable, stripArgs);
  if (result.exitCode != 0) {
    final details = [
      if (result.stdout.toString().trim().isNotEmpty)
        result.stdout.toString().trim(),
      if (result.stderr.toString().trim().isNotEmpty)
        result.stderr.toString().trim(),
    ].join('\n');
    throw ProcessException(
      stripExecutable,
      stripArgs,
      details.isEmpty
          ? 'Failed to strip Linux release artifact ${outputFile.path}.'
          : details,
      result.exitCode,
    );
  }
}

String _cargoExecutable() {
  final cargoFromEnvironment = Platform.environment['CARGO'];
  final candidates = <String?>[
    if (cargoFromEnvironment != null && cargoFromEnvironment.isNotEmpty)
      _resolveExecutable(cargoFromEnvironment),
    _cargoHomeExecutable('cargo'),
    _findExecutableInPath('cargo'),
  ];

  for (final candidate in candidates) {
    if (candidate != null && candidate.isNotEmpty) {
      return candidate;
    }
  }

  throw ProcessException(
    'cargo',
    const [],
    _missingCargoHelp(),
    127,
  );
}

String _rustTargetTriple(OS os, Architecture architecture) {
  return switch ((os, architecture)) {
    (OS.macOS, Architecture.x64) => 'x86_64-apple-darwin',
    (OS.macOS, Architecture.arm64) => 'aarch64-apple-darwin',
    (OS.windows, Architecture.arm64) => 'aarch64-pc-windows-msvc',
    (OS.windows, Architecture.ia32) => 'i686-pc-windows-msvc',
    (OS.windows, Architecture.x64) => 'x86_64-pc-windows-msvc',
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
  Map<String, String>? currentEnvironment,
}) {
  final env = <String, String>{};

  // For CARGO_TARGET_* vars we need an upper-case triple with underscores.
  // Example: aarch64-apple-darwin -> AARCH64_APPLE_DARWIN
  final tripleKeyCargo = triple.toUpperCase().replaceAll('-', '_');

  // For cc (CC_*, CFLAGS_*, etc.) we use the target in lower-case,
  // with '-' replaced by '_' as cc expects.
  // Example: aarch64-apple-darwin -> aarch64_apple_darwin
  final tripleKeyCc = triple.replaceAll('-', '_');
  final cCompiler = codeConfig.cCompiler;
  String? compilerPath = cCompiler?.compiler.toFilePath();
  String? archiverPath = cCompiler?.archiver.toFilePath();
  String? linkerPath = cCompiler?.linker.toFilePath();
  String? cxxPath;
  final useWindowsMsvcToolNames =
      codeConfig.targetOS == OS.windows && triple.endsWith('-windows-msvc');
  var toolchainDir =
      compilerPath == null ? null : File(compilerPath).parent.path;

  if (codeConfig.targetOS == OS.android) {
    final androidConfig = codeConfig.android;
    final ndkApi = androidConfig.targetNdkApi;
    final targetToolchainTriple =
        triple == _rustTargetTriple(OS.android, Architecture.arm)
            ? 'armv7a-linux-androideabi'
            : triple;
    final targetPrefix = '$targetToolchainTriple$ndkApi';
    toolchainDir ??= _androidNdkToolchainBinDirectory();
    if (toolchainDir != null) {
      final targetClang = _toolchainBinary(toolchainDir, '$targetPrefix-clang');
      final targetClangxx =
          _toolchainBinary(toolchainDir, '$targetPrefix-clang++');
      final targetArchiver = _toolchainBinary(toolchainDir, 'llvm-ar');
      if (targetClang != null) {
        compilerPath = targetClang;
      }
      if (targetClangxx != null) {
        linkerPath = targetClangxx;
        cxxPath = targetClangxx;
      }
      if (targetArchiver != null && archiverPath == null) {
        archiverPath = targetArchiver;
      }
    }
    final targetArg = '--target=$targetPrefix';
    env['CFLAGS_$tripleKeyCc'] = targetArg;
    env['CXXFLAGS_$tripleKeyCc'] = targetArg;
  }

  if (compilerPath != null && archiverPath != null && linkerPath != null) {
    final compilerCommand =
        useWindowsMsvcToolNames ? _executableName(compilerPath) : compilerPath;
    final archiverCommand =
        useWindowsMsvcToolNames ? _executableName(archiverPath) : archiverPath;
    final linkerCommand =
        useWindowsMsvcToolNames ? _executableName(linkerPath) : linkerPath;
    final cxxCommand = cxxPath == null
        ? null
        : useWindowsMsvcToolNames
            ? _executableName(cxxPath)
            : cxxPath;

    env['CARGO_TARGET_${tripleKeyCargo}_LINKER'] = linkerCommand;
    env['CARGO_TARGET_${tripleKeyCargo}_AR'] = archiverCommand;
    env['CC_$tripleKeyCc'] = compilerCommand;
    if (cxxPath != null) {
      env['CXX_$tripleKeyCc'] = cxxCommand!;
    }
    env['AR_$tripleKeyCc'] = archiverCommand;
    env['PATH'] = [
      File(linkerPath).parent.path,
      File(compilerPath).parent.path,
      File(archiverPath).parent.path,
      _getEnvironmentValue(
              currentEnvironment ?? Platform.environment, 'PATH') ??
          '',
    ].where((element) => element.isNotEmpty).join(_environmentPathSeparator);
  }

  if (codeConfig.targetOS == OS.linux) {
    const fallbackCc = 'cc';
    const fallbackCxx = 'c++';
    const fallbackLinker = 'cc';
    const fallbackArchiver = 'ar';

    env['CARGO_TARGET_${tripleKeyCargo}_LINKER'] = fallbackLinker;
    env['CARGO_TARGET_${tripleKeyCargo}_AR'] = fallbackArchiver;
    env['AR_$tripleKeyCc'] = fallbackArchiver;
    env['CC_$tripleKeyCc'] = fallbackCc;
    env['CXX_$tripleKeyCc'] = fallbackCxx;
  }

  // For macOS targets (e.g. aarch64-apple-darwin), ensure the SDK is visible
  // so headers like TargetConditionals.h can be found.
  if (codeConfig.targetOS == OS.macOS && triple.endsWith('-apple-darwin')) {
    String? sdkRoot = Platform.environment['SDKROOT'];
    if (sdkRoot == null || sdkRoot.isEmpty) {
      try {
        final result = Process.runSync(
          'xcrun',
          ['--sdk', 'macosx', '--show-sdk-path'],
        );
        if (result.exitCode == 0 && result.stdout is String) {
          sdkRoot = (result.stdout as String).trim();
        }
      } catch (_) {
        // Ignore failure; we'll just skip setting SDKROOT.
      }
    }
    if (sdkRoot != null && sdkRoot.isNotEmpty) {
      env['SDKROOT'] = sdkRoot;
      final cflagsKey = 'CFLAGS_$tripleKeyCc';
      final existing = env[cflagsKey];
      final sysrootFlag = '-isysroot $sdkRoot';
      env[cflagsKey] = [
        if (existing != null && existing.isNotEmpty) existing,
        sysrootFlag,
      ].join(' ');
    }
  }

  if (codeConfig.targetOS == OS.android) {
    final androidConfig = codeConfig.android;
    env['ANDROID_NDK_API_LEVEL'] = '${androidConfig.targetNdkApi}';
  }

  return env;
}

Future<Map<String, String>> _cargoEnvironment({
  required String triple,
  required CodeConfig codeConfig,
  required Uri cargoTargetDir,
}) async {
  final environment = Map<String, String>.from(Platform.environment);
  final cCompiler = codeConfig.cCompiler;

  if (codeConfig.targetOS == OS.windows &&
      cCompiler != null &&
      cCompiler.windows.developerCommandPrompt != null) {
    final prompt = cCompiler.windows.developerCommandPrompt!;
    final promptEnvironment = await _environmentFromBatchFile(
      prompt.script,
      arguments: prompt.arguments,
    );
    _mergeEnvironment(environment, promptEnvironment);
  }

  _mergeEnvironment(
    environment,
    _cargoEnvForTarget(
      triple: triple,
      codeConfig: codeConfig,
      currentEnvironment: environment,
    ),
  );

  if (codeConfig.targetOS == OS.windows && cCompiler != null) {
    final compilerPath = cCompiler.compiler.toFilePath();
    final archiverPath = cCompiler.archiver.toFilePath();
    final linkerPath = cCompiler.linker.toFilePath();
    final tripleKeyCargo = triple.toUpperCase().replaceAll('-', '_');
    final useToolNames = triple.endsWith('-windows-msvc');
    final compilerCommand =
        useToolNames ? _executableName(compilerPath) : compilerPath;
    final archiverCommand =
        useToolNames ? _executableName(archiverPath) : archiverPath;
    final linkerCommand =
        useToolNames ? _executableName(linkerPath) : linkerPath;

    _setEnvironmentValue(environment, 'CC', compilerCommand);
    _setEnvironmentValue(environment, 'CXX', compilerCommand);
    _setEnvironmentValue(environment, 'AR', archiverCommand);
    _setEnvironmentValue(environment, 'HOST_CC', compilerCommand);
    _setEnvironmentValue(environment, 'TARGET_CC', compilerCommand);
    _setEnvironmentValue(
      environment,
      'CARGO_TARGET_${tripleKeyCargo}_LINKER',
      linkerCommand,
    );
  }

  _setEnvironmentValue(
    environment,
    'CARGO_TARGET_DIR',
    cargoTargetDir.toFilePath(),
  );
  return environment;
}

Future<String> _pipeProcessOutput(
  Stream<List<int>> stream,
  IOSink sink,
) async {
  final output = StringBuffer();
  await for (final chunk in systemEncoding.decoder.bind(stream)) {
    sink.write(chunk);
    output.write(chunk);
  }
  return output.toString();
}

Future<void> _ensureDeltachatCrateTypePatched() async {
  final cargoHome = _cargoHomeDirectory();
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

String? _cargoHomeDirectory() {
  final cargoHome = Platform.environment['CARGO_HOME'];
  if (cargoHome != null && cargoHome.isNotEmpty) {
    return cargoHome;
  }

  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    return _joinPaths(home, '.cargo');
  }

  final userProfile = Platform.environment['USERPROFILE'];
  if (userProfile != null && userProfile.isNotEmpty) {
    return _joinPaths(userProfile, '.cargo');
  }

  final homeDrive = Platform.environment['HOMEDRIVE'];
  final homePath = Platform.environment['HOMEPATH'];
  if (homeDrive != null &&
      homeDrive.isNotEmpty &&
      homePath != null &&
      homePath.isNotEmpty) {
    return _joinPaths('$homeDrive$homePath', '.cargo');
  }

  return null;
}

String? _cargoHomeExecutable(String executableName) {
  final cargoHome = _cargoHomeDirectory();
  if (cargoHome == null) {
    return null;
  }
  final candidate = _joinPaths(cargoHome, 'bin', executableName);
  if (candidate == null) {
    return null;
  }
  return _resolveExecutable(candidate);
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

String? _resolveExecutable(String command) {
  final normalized = command.trim().replaceAll('"', '');
  if (normalized.isEmpty) {
    return null;
  }

  if (_looksLikePath(normalized)) {
    for (final candidate in _executableCandidates(normalized)) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    return null;
  }

  return _findExecutableInPath(normalized);
}

String? _findExecutableInPath(String executableName) {
  final path = Platform.environment['PATH'];
  if (path == null || path.isEmpty) {
    return null;
  }

  for (final directory in path.split(_environmentPathSeparator)) {
    final normalizedDirectory = directory.trim().replaceAll('"', '');
    if (normalizedDirectory.isEmpty) {
      continue;
    }
    final candidate = _joinPaths(normalizedDirectory, executableName);
    if (candidate == null) {
      continue;
    }
    for (final executable in _executableCandidates(candidate)) {
      if (File(executable).existsSync()) {
        return executable;
      }
    }
  }

  return null;
}

Iterable<String> _executableCandidates(String basePath) sync* {
  if (!Platform.isWindows) {
    yield basePath;
    return;
  }

  final lower = basePath.toLowerCase();
  if (lower.endsWith('.exe') ||
      lower.endsWith('.cmd') ||
      lower.endsWith('.bat')) {
    yield basePath;
    return;
  }

  yield '$basePath.exe';
  yield '$basePath.cmd';
  yield '$basePath.bat';
  yield basePath;
}

bool _looksLikePath(String value) {
  return value.contains(Platform.pathSeparator) ||
      value.contains('/') ||
      value.contains('\\') ||
      (Platform.isWindows && value.contains(':'));
}

String _executableName(String path) {
  final separators = RegExp(r'[\\/]');
  final parts = path.split(separators);
  return parts.isEmpty ? path : parts.last;
}

Future<Map<String, String>> _environmentFromBatchFile(
  Uri batchFile, {
  List<String> arguments = const [],
}) async {
  if (!Platform.isWindows) {
    return const <String, String>{};
  }

  const separator = '=======delta-ffi-env=======';
  final fileName = batchFile.pathSegments.last;
  final dir = batchFile.resolve('.');
  final command =
      'set && echo $separator && $fileName ${arguments.join(' ')} > nul && set';

  final processResult = await Process.run(
    command,
    [],
    runInShell: true,
    workingDirectory: dir.toFilePath(),
  );

  if (processResult.exitCode != 0) {
    throw ProcessException(
      command,
      const [],
      processResult.stderr?.toString() ?? 'Failed to run developer prompt.',
      processResult.exitCode,
    );
  }

  final output = processResult.stdout?.toString() ?? '';
  final resultSplit = output.split(separator);
  if (resultSplit.length != 2) {
    throw ProcessException(
      command,
      const [],
      'Unexpected output while capturing Windows developer prompt environment.',
      processResult.exitCode,
    );
  }

  final original = _parseEnvironmentBlock(resultSplit.first.trim());
  final updated = _parseEnvironmentBlock(resultSplit[1].trim());
  final result = <String, String>{};
  for (final entry in updated.entries) {
    if (!_containsEnvironmentKey(original, entry.key) ||
        _getEnvironmentValue(original, entry.key) != entry.value) {
      result[entry.key] = entry.value;
    }
  }
  return result;
}

Map<String, String> _parseEnvironmentBlock(String block) {
  final result = <String, String>{};
  if (block.isEmpty) {
    return result;
  }

  for (final line in block.split('\r\n')) {
    if (line.isEmpty) {
      continue;
    }
    final separatorIndex = line.indexOf('=');
    if (separatorIndex <= 0) {
      continue;
    }
    result[line.substring(0, separatorIndex)] = line.substring(
      separatorIndex + 1,
    );
  }
  return result;
}

void _mergeEnvironment(
  Map<String, String> target,
  Map<String, String> updates,
) {
  for (final entry in updates.entries) {
    _setEnvironmentValue(target, entry.key, entry.value);
  }
}

void _setEnvironmentValue(
  Map<String, String> environment,
  String key,
  String value,
) {
  final existingKey = _matchingEnvironmentKey(environment, key);
  if (existingKey != null && existingKey != key) {
    environment.remove(existingKey);
  }
  environment[key] = value;
}

String? _getEnvironmentValue(
  Map<String, String> environment,
  String key,
) {
  final matchingKey = _matchingEnvironmentKey(environment, key);
  if (matchingKey == null) {
    return null;
  }
  return environment[matchingKey];
}

bool _containsEnvironmentKey(
  Map<String, String> environment,
  String key,
) {
  return _matchingEnvironmentKey(environment, key) != null;
}

String? _matchingEnvironmentKey(
  Map<String, String> environment,
  String key,
) {
  if (!Platform.isWindows) {
    return environment.containsKey(key) ? key : null;
  }

  final lowercaseKey = key.toLowerCase();
  for (final existingKey in environment.keys) {
    if (existingKey.toLowerCase() == lowercaseKey) {
      return existingKey;
    }
  }
  return null;
}

String? _androidNdkToolchainBinDirectory() {
  final ndkRoot = Platform.environment['ANDROID_NDK_ROOT'] ??
      Platform.environment['ANDROID_NDK_HOME'] ??
      Platform.environment['NDK_HOME'];
  final prebuiltRoot =
      _joinPaths(_joinPaths(ndkRoot, 'toolchains', 'llvm'), 'prebuilt');
  if (prebuiltRoot == null) {
    return null;
  }

  final prebuiltDirectory = Directory(prebuiltRoot);
  if (!prebuiltDirectory.existsSync()) {
    return null;
  }

  for (final hostDirectory
      in prebuiltDirectory.listSync().whereType<Directory>()) {
    final binDirectory = _joinPaths(hostDirectory.path, 'bin');
    if (binDirectory == null) {
      continue;
    }
    if (Directory(binDirectory).existsSync()) {
      return binDirectory;
    }
  }

  return null;
}

String _missingCargoHelp() {
  if (Platform.isWindows) {
    return 'Cargo executable not found. Install the Rust stable MSVC toolchain and ensure cargo is on PATH or in %USERPROFILE%\\.cargo\\bin.';
  }
  return r'Cargo executable not found. Install the Rust stable toolchain and ensure cargo is on PATH or in $HOME/.cargo/bin.';
}

String get _environmentPathSeparator => Platform.isWindows ? ';' : ':';

_BuildModeSelection _resolveBuildMode(
    hooks.BuildInput input, List<String> args) {
  final argMode = _buildModeFromArgs(args);
  if (argMode != null) {
    return _BuildModeSelection(name: argMode, source: 'command line');
  }

  final userDefinesMode = _buildModeFromUserDefines(input);
  if (userDefinesMode != null) {
    return _BuildModeSelection(name: userDefinesMode, source: 'user defines');
  }

  final environmentMode = _buildModeFromEnvironment();
  if (environmentMode != null) {
    return _BuildModeSelection(name: environmentMode, source: 'environment');
  }

  final configJsonMode = _buildModeFromConfigJson(input.config.json);
  if (configJsonMode != null) {
    return _BuildModeSelection(
        name: configJsonMode, source: 'hook config json');
  }

  final configMode = _buildModeName(input.config);
  if (configMode != null) {
    return _BuildModeSelection(name: configMode, source: 'hooks build input');
  }

  final linkingEnabledMode = _buildModeFromLinkingEnabled(input);
  if (linkingEnabledMode != null) {
    return _BuildModeSelection(
      name: linkingEnabledMode,
      source: 'hook linking_enabled',
    );
  }

  return const _BuildModeSelection(name: 'debug', source: 'default');
}

String? _buildModeFromArgs(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '--release':
      case '--release=true':
        return 'release';
      case '--release=false':
        return null;
      case '--debug':
        return 'debug';
      case '--profile':
        if (i + 1 < args.length) {
          final next = args[i + 1].trim().toLowerCase();
          if (_isKnownMode(next)) {
            return next;
          }
        }
        return 'profile';
      case '--build-mode':
      case '--mode':
      case '--flutter-build-mode':
        if (i + 1 < args.length) {
          final value = args[i + 1].trim().toLowerCase();
          if (_isKnownMode(value)) {
            return value;
          }
        }
    }

    if (arg.startsWith('--build-mode=')) {
      final value = arg.substring('--build-mode='.length).trim().toLowerCase();
      if (_isKnownMode(value)) {
        return value;
      }
    }
    if (arg.startsWith('--mode=')) {
      final value = arg.substring('--mode='.length).trim().toLowerCase();
      if (_isKnownMode(value)) {
        return value;
      }
    }
    if (arg.startsWith('--flutter-build-mode=')) {
      final value =
          arg.substring('--flutter-build-mode='.length).trim().toLowerCase();
      if (_isKnownMode(value)) {
        return value;
      }
    }
    if (arg.startsWith('--profile=')) {
      final value = arg.substring('--profile='.length).trim().toLowerCase();
      if (_isKnownMode(value)) {
        return value;
      }
      return 'profile';
    }
    if (arg.startsWith('--release=')) {
      final value = arg.substring('--release='.length).trim().toLowerCase();
      if (_isKnownMode(value)) {
        return value;
      }
      return 'release';
    }
  }

  return null;
}

String? _buildModeFromUserDefines(hooks.BuildInput input) {
  try {
    final dynamic dynamicInput = input;
    final dynamic rawUserDefines = dynamicInput.userDefines;
    if (rawUserDefines is Map) {
      final userDefines = <String, Object?>{};
      for (final entry in rawUserDefines.entries) {
        if (entry.key is String) {
          userDefines[entry.key as String] = entry.value;
        }
      }
      final modeFromUserDefines = _buildModeFromConfigJson(userDefines);
      if (modeFromUserDefines != null) {
        return modeFromUserDefines;
      }
    }
  } catch (_) {
    // Ignore absence/incompatibility of user-defines.
  }

  return null;
}

String? _buildModeFromConfigJson(Map<String, Object?> value) {
  const modeKeys = {'build_mode', 'buildmode', 'build-mode', 'mode'};

  Object? raw = _lookupConfigValue(
    value,
    (key, _) => modeKeys.contains(key),
  );
  if (raw is String) {
    final normalized = raw.toLowerCase();
    if (_isKnownMode(normalized)) {
      return normalized;
    }
  }

  final nested = _lookupConfigValue(value, (key, _) {
    return !key.startsWith('_') && key.endsWith('mode') && key != 'mode_key';
  });
  if (nested is String) {
    final normalized = nested.toLowerCase();
    if (_isKnownMode(normalized)) {
      return normalized;
    }
  }

  return null;
}

String? _buildModeFromLinkingEnabled(hooks.BuildInput input) {
  try {
    final dynamic dynamicInput = input;
    final dynamic config = dynamicInput.config;
    final dynamic linkingEnabled = config.linkingEnabled;
    if (linkingEnabled is bool) {
      return linkingEnabled ? 'release' : 'debug';
    }
  } catch (_) {
    // Ignore absence/incompatibility of linkingEnabled.
  }

  return null;
}

Object? _lookupConfigValue(
  Map<String, Object?> config,
  bool Function(String key, Object? value) matches,
) {
  for (final entry in config.entries) {
    final key = entry.key.toLowerCase();
    if (matches(key, entry.value)) {
      return entry.value;
    }
  }

  for (final entry in config.entries) {
    final value = entry.value;
    if (value is Map<String, Object?>) {
      final nested = _lookupConfigValue(value, matches);
      if (nested != null) {
        return nested;
      }
    } else if (value is List<Object?>) {
      for (final item in value) {
        if (item is Map<String, Object?>) {
          final nested = _lookupConfigValue(item, matches);
          if (nested != null) {
            return nested;
          }
        }
      }
    }
  }

  return null;
}

bool _isKnownMode(String value) {
  return value == 'debug' || value == 'release' || value == 'profile';
}

bool _isVerboseBuild() {
  final raw = Platform.environment['DELTA_FFI_VERBOSE_BUILD'];
  if (raw == null || raw.isEmpty) {
    return false;
  }
  switch (raw.toLowerCase()) {
    case '1':
    case 'true':
    case 'yes':
    case 'on':
      return true;
    default:
      return false;
  }
}

String? _buildModeFromEnvironment() {
  for (final key in const [
    'FLUTTER_BUILD_MODE',
    'BUILD_MODE',
    'CONFIGURATION',
  ]) {
    final value = Platform.environment[key];
    if (value != null && value.isNotEmpty) {
      final normalized = value.trim().toLowerCase();
      if (_isKnownMode(normalized)) {
        return normalized;
      }
    }
  }

  return null;
}

bool _isReleaseMode(String modeName) {
  const releaseNames = {'release', 'profile'};
  return releaseNames.contains(modeName.toLowerCase());
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

class _BuildModeSelection {
  const _BuildModeSelection({required this.name, required this.source});

  final String name;
  final String source;
}
