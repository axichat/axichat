import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _windowsRunnerPath = 'windows/runner/main.cpp';
const String _setDefaultDllDirectories = 'SetDefaultDllDirectories';
const String _setDllDirectory = 'SetDllDirectoryW';
const String _loadLibrarySearchDefaultDirs = 'LOAD_LIBRARY_SEARCH_DEFAULT_DIRS';

void main() {
  test('Windows runner hardens DLL search order', () {
    final file = File(_windowsRunnerPath);
    final contents = file.readAsStringSync();

    expect(contents.contains(_setDefaultDllDirectories), isTrue);
    expect(contents.contains(_setDllDirectory), isTrue);
    expect(contents.contains(_loadLibrarySearchDefaultDirs), isTrue);
  });
}
