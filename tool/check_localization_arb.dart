import 'dart:convert';
import 'dart:io';

void main() {
  final Directory root = Directory.current;
  final Directory localizationDir = Directory(
    '${root.path}/lib/src/localization',
  );
  final File templateArb = File('${localizationDir.path}/app_en.arb');
  final List<String> failures = <String>[];

  if (!templateArb.existsSync()) {
    stderr.writeln('Run this script from the repository root.');
    exitCode = 1;
    return;
  }

  final Set<String> templateKeys = _messageKeys(_readArb(templateArb));
  final List<File> arbFiles =
      localizationDir
          .listSync()
          .whereType<File>()
          .where((file) => RegExp(r'app_.*\.arb$').hasMatch(_basename(file)))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final File file in arbFiles) {
    final Set<String> actualKeys = _messageKeys(_readArb(file));
    final Set<String> extraKeys = actualKeys.difference(templateKeys);
    final Set<String> missingKeys = templateKeys.difference(actualKeys);
    if (extraKeys.isNotEmpty) {
      failures.add(
        '${_basename(file)} has keys missing from app_en.arb: '
        '${extraKeys.join(', ')}',
      );
    }
    if (missingKeys.isNotEmpty) {
      failures.add(
        '${_basename(file)} is missing localization keys: '
        '${missingKeys.join(', ')}',
      );
    }
  }

  final Map<String, Set<String>> missingGetterKeys = _missingGetterKeys(
    root: root,
    knownKeys: templateKeys,
  );
  for (final MapEntry<String, Set<String>> entry in missingGetterKeys.entries) {
    failures.add(
      '${entry.key} references missing l10n keys: '
      '${entry.value.join(', ')}',
    );
  }

  if (failures.isNotEmpty) {
    stderr.writeln(failures.join('\n'));
    exitCode = 1;
    return;
  }

  stdout.writeln('Localization ARB checks passed.');
}

Map<String, Object?> _readArb(File file) {
  return (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>).cast();
}

Set<String> _messageKeys(Map<String, Object?> arb) {
  return arb.keys.where((key) => !key.startsWith('@')).toSet();
}

Map<String, Set<String>> _missingGetterKeys({
  required Directory root,
  required Set<String> knownKeys,
}) {
  final RegExp getterPattern = RegExp(
    r'\b(?:context\.l10n|l10n)\.([A-Za-z_]\w*)',
  );
  final Map<String, Set<String>> missingByFile = <String, Set<String>>{};
  final Directory libDir = Directory('${root.path}/lib');
  for (final File file in libDir.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) {
      continue;
    }
    final Set<String> missingKeys = getterPattern
        .allMatches(file.readAsStringSync())
        .map((match) => match.group(1)!)
        .where((key) => key != 'localeName' && !knownKeys.contains(key))
        .toSet();
    if (missingKeys.isNotEmpty) {
      missingByFile[_relativePath(root, file)] = missingKeys;
    }
  }
  return missingByFile;
}

String _relativePath(Directory root, File file) {
  final String rootPath = '${root.path}/';
  final String path = file.path;
  return path.startsWith(rootPath) ? path.substring(rootPath.length) : path;
}

String _basename(File file) {
  return file.uri.pathSegments.last;
}
