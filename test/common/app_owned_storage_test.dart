// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:axichat/src/common/app_owned_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.temporaryPath);

  final String temporaryPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'appOwnedTemporaryDirectory creates an exact named child directory',
    () async {
      final originalPlatform = PathProviderPlatform.instance;
      final tempDir = await Directory.systemTemp.createTemp(
        'app_owned_storage',
      );
      PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);

      try {
        final directory = await appOwnedTemporaryDirectory(
          emailAttachmentTempDirectoryName,
        );

        expect(
          directory.path,
          p.join(tempDir.path, emailAttachmentTempDirectoryName),
        );
      } finally {
        PathProviderPlatform.instance = originalPlatform;
        await tempDir.delete(recursive: true);
      }
    },
  );

  test(
    'appOwnedTemporaryDirectory rejects current-directory references',
    () async {
      expect(appOwnedTemporaryDirectory('.'), throwsArgumentError);
    },
  );

  test(
    'appOwnedTemporaryDirectory rejects parent-directory references',
    () async {
      expect(appOwnedTemporaryDirectory('..'), throwsArgumentError);
    },
  );

  test('normalizeAppOwnedPathSegment rejects nested paths', () {
    expect(
      () => normalizeAppOwnedPathSegment('../outside'),
      throwsArgumentError,
    );
  });
}
