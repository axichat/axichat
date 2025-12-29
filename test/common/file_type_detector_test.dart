import 'dart:io';

import 'package:axichat/src/common/file_type_detector.dart';
import 'package:flutter_test/flutter_test.dart';

const String _safeJpegMimeType = 'image/jpeg';
const String _safePngMimeType = 'image/png';
const String _highRiskMimeType = 'application/x-msdownload';
const String _genericBinaryMimeType = 'application/octet-stream';
const String _safeFileName = 'photo.jpg';
const String _doubleExtensionFileName = 'photo.jpg.exe';
const String _rtloControl = '\u202e';
const String _rtloFileName = 'photo${_rtloControl}exe.jpg';
const String _tempDirPrefix = 'axichat-file-type-test';
const String _pngFileName = 'sample.png';
const List<int> _pngHeaderBytes = <int>[
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
];

const FileTypeReport _safeReport = FileTypeReport(
  detectedMimeType: _safeJpegMimeType,
  declaredMimeType: _safeJpegMimeType,
  extensionMimeType: _safeJpegMimeType,
);

void main() {
  group('FileTypeReport.hasMismatch', () {
    test('flags reliable mime mismatches', () {
      const report = FileTypeReport(
        detectedMimeType: _safePngMimeType,
        declaredMimeType: _safeJpegMimeType,
        extensionMimeType: _safeJpegMimeType,
      );
      expect(report.hasMismatch, isTrue);
    });

    test('ignores mismatches when detection is generic binary', () {
      const report = FileTypeReport(
        detectedMimeType: _genericBinaryMimeType,
        declaredMimeType: _safeJpegMimeType,
        extensionMimeType: _safeJpegMimeType,
      );
      expect(report.hasMismatch, isFalse);
    });
  });

  group('assessFileOpenRisk', () {
    test('warns on high-risk detected mime types', () {
      const report = FileTypeReport(
        detectedMimeType: _highRiskMimeType,
        declaredMimeType: _safeJpegMimeType,
        extensionMimeType: _safeJpegMimeType,
      );
      final risk = assessFileOpenRisk(
        report: report,
        fileName: _safeFileName,
      );
      expect(risk.isWarning, isTrue);
    });

    test('warns on double extensions', () {
      final risk = assessFileOpenRisk(
        report: _safeReport,
        fileName: _doubleExtensionFileName,
      );
      expect(risk.isWarning, isTrue);
    });

    test('warns on unicode control characters in names', () {
      final risk = assessFileOpenRisk(
        report: _safeReport,
        fileName: _rtloFileName,
      );
      expect(risk.isWarning, isTrue);
    });
  });

  group('inspectFileType', () {
    test('detects png headers and reports mismatches', () async {
      final tempDir = await Directory.systemTemp.createTemp(_tempDirPrefix);
      try {
        final filePath =
            '${tempDir.path}${Platform.pathSeparator}$_pngFileName';
        final file = File(filePath);
        await file.writeAsBytes(_pngHeaderBytes, flush: true);
        final report = await inspectFileType(
          file: file,
          declaredMimeType: _safeJpegMimeType,
          fileName: _safeFileName,
        );
        expect(report.detectedLabel, _safePngMimeType);
        expect(report.hasMismatch, isTrue);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
