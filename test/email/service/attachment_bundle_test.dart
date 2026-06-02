import 'dart:io';

import 'package:archive/archive.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/email/service/attachment_bundle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'axichat-attachment-bundle-test-',
    );
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() {
    PathProviderPlatform.instance = originalPathProvider;
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('bundles nonempty files with unique names and exact bytes', () async {
    final first = File('${tempDir.path}/first.txt')
      ..writeAsBytesSync(<int>[1, 2, 3, 4]);
    final second = File('${tempDir.path}/second.txt')
      ..writeAsBytesSync(<int>[5, 6, 7]);

    final bundled = await EmailAttachmentBundler.bundle(
      attachments: [
        Attachment(
          path: first.path,
          fileName: 'same.txt',
          sizeBytes: 0,
          mimeType: 'text/plain',
        ),
        Attachment(
          path: second.path,
          fileName: 'same.txt',
          sizeBytes: 0,
          mimeType: 'text/plain',
        ),
      ],
      caption: null,
    );

    final zipBytes = await File(bundled.path).readAsBytes();
    expect(zipBytes.length, greaterThan(22));
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final files = archive.files.where((entry) => entry.isFile).toList();
    expect(files.map((entry) => entry.name), ['same.txt', 'same_2.txt']);
    expect(files[0].content, first.readAsBytesSync());
    expect(files[1].content, second.readAsBytesSync());
    expect(bundled.sizeBytes, zipBytes.length);
    expect(bundled.mimeType, emailAttachmentBundleMimeType);
  });

  test(
    'uniques duplicate names when extension leaves no suffix room',
    () async {
      final first = File('${tempDir.path}/first.payload')
        ..writeAsBytesSync(<int>[1]);
      final second = File('${tempDir.path}/second.payload')
        ..writeAsBytesSync(<int>[2]);
      final longExtension = '.${List.filled(118, 'x').join()}';
      final longName = 'a$longExtension';

      final bundled = await EmailAttachmentBundler.bundle(
        attachments: [
          Attachment(path: first.path, fileName: longName, sizeBytes: 0),
          Attachment(path: second.path, fileName: longName, sizeBytes: 0),
        ],
        caption: null,
      );

      final archive = ZipDecoder().decodeBytes(
        await File(bundled.path).readAsBytes(),
      );
      final files = archive.files.where((entry) => entry.isFile).toList();
      expect(files.map((entry) => entry.name), [longName, 'a_2']);
    },
  );

  test('keeps zero-byte files as valid entries', () async {
    final empty = File('${tempDir.path}/empty.txt')..writeAsBytesSync(<int>[]);

    final bundled = await EmailAttachmentBundler.bundle(
      attachments: [
        Attachment(
          path: empty.path,
          fileName: 'empty.txt',
          sizeBytes: 999,
          mimeType: 'text/plain',
        ),
      ],
      caption: null,
    );

    final archive = ZipDecoder().decodeBytes(
      await File(bundled.path).readAsBytes(),
    );
    final files = archive.files.where((entry) => entry.isFile).toList();
    expect(files, hasLength(1));
    expect(files.single.name, 'empty.txt');
    expect(files.single.content, isEmpty);
  });

  test('rejects directories before writing bundle', () async {
    final directory = Directory('${tempDir.path}/not-a-file')..createSync();

    expect(
      EmailAttachmentBundler.bundle(
        attachments: [
          Attachment(
            path: directory.path,
            fileName: 'not-a-file',
            sizeBytes: 0,
          ),
        ],
        caption: null,
      ),
      throwsA(isA<EmailAttachmentBundleInvalidEntityTypeException>()),
    );
  });
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.temporaryPath);

  final String temporaryPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}
