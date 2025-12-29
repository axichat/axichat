import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _libRoot = 'lib';
const String _androidManifestPath = 'android/app/src/main/AndroidManifest.xml';
const List<String> _forbiddenWebViewSymbols = <String>[
  'WebView',
  'InAppWebView',
  'JavascriptChannel',
  'WKWebView',
  'addJavascriptInterface',
];
const List<String> _forbiddenContactPermissions = <String>[
  'READ_CONTACTS',
  'WRITE_CONTACTS',
  'READ_PROFILE',
];

void main() {
  test('No embedded WebView symbols in app code', () {
    final directory = Directory(_libRoot);
    final dartFiles = directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in dartFiles) {
      final contents = file.readAsStringSync();
      for (final symbol in _forbiddenWebViewSymbols) {
        expect(
          contents.contains(symbol),
          isFalse,
          reason: 'Found $symbol in ${file.path}',
        );
      }
    }
  });

  test('Android manifest does not request contact permissions', () {
    final manifest = File(_androidManifestPath);
    final contents = manifest.readAsStringSync();
    for (final permission in _forbiddenContactPermissions) {
      expect(contents.contains(permission), isFalse);
    }
  });
}
