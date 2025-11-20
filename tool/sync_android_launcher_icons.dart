import 'dart:io';

const _sourceResDir = 'android/app/src/main/res';
const _flavorResDirs = [
  'android/app/src/development/res',
];

void main() {
  final sourceDir = Directory(_sourceResDir);
  if (!sourceDir.existsSync()) {
    stderr.writeln('Unable to find $_sourceResDir');
    exitCode = 1;
    return;
  }

  final resourceDirs = sourceDir.listSync().whereType<Directory>().where((dir) {
    final name = dir.path.split(Platform.pathSeparator).last;
    return name.startsWith('mipmap-') || name.startsWith('drawable-');
  });

  for (final resDir in resourceDirs) {
    final launcherFiles = resDir
        .listSync()
        .whereType<File>()
        .where((file) => _isLauncherAsset(file.path))
        .toList();
    if (launcherFiles.isEmpty) {
      continue;
    }
    for (final flavorDir in _flavorResDirs) {
      final targetDir = Directory(
          '$flavorDir/${resDir.path.split(Platform.pathSeparator).last}')
        ..createSync(recursive: true);
      for (final sourceFile in launcherFiles) {
        final destPath =
            '${targetDir.path}/${sourceFile.uri.pathSegments.last}';
        File(destPath).writeAsBytesSync(sourceFile.readAsBytesSync());
        stdout.writeln('Synced ${sourceFile.path} -> $destPath');
      }
    }
  }
}

bool _isLauncherAsset(String path) {
  final name = path.split(Platform.pathSeparator).last;
  return name.startsWith('ic_launcher');
}
