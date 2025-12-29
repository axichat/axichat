import 'package:axichat/src/common/file_name_safety.dart';
import 'package:flutter_test/flutter_test.dart';

import '../security_corpus/security_corpus.dart';

const int _maxNameLength = 32;
const String _fallbackName = 'attachment';
const String _posixSeparator = '/';
const String _windowsSeparator = '\\';
const String _rtloControl = '\u202e';
const String _rtloName = 'photo${_rtloControl}exe.jpg';
const String _rtloExpected = 'photoexe.jpg';
const String _posixTraversalName = '../evil.exe';
const String _posixTraversalExpected = 'evil.exe';
const String _windowsTraversalName = '..\\evil.exe';
const String _windowsTraversalExpected = 'evil.exe';
const String _driveTraversalName = 'C:\\temp\\evil.exe';
const String _driveTraversalExpected = 'evil.exe';
const String _posixAbsoluteName = '/etc/passwd';
const String _posixAbsoluteExpected = 'passwd';
const String _safeName = 'safe_name.png';
const int _longBaseRepeat = 40;
const int _truncateMaxLength = 12;
const String _longBaseChar = 'a';
const String _longExtension = '.txt';

const Map<String, String> _pathTraversalCases = <String, String>{
  _posixTraversalName: _posixTraversalExpected,
  _windowsTraversalName: _windowsTraversalExpected,
  _driveTraversalName: _driveTraversalExpected,
  _posixAbsoluteName: _posixAbsoluteExpected,
  _safeName: _safeName,
};

void main() {
  final SecurityCorpus corpus = SecurityCorpus.load();

  group('sanitizeAttachmentFileName', () {
    test('drops path traversal segments', () {
      for (final entry in _pathTraversalCases.entries) {
        final sanitized = sanitizeAttachmentFileName(
          rawName: entry.key,
          fallbackName: _fallbackName,
          maxLength: _maxNameLength,
        );
        expect(sanitized, entry.value);
      }
    });

    test('strips unicode controls', () {
      final sanitized = sanitizeAttachmentFileName(
        rawName: _rtloName,
        fallbackName: _fallbackName,
        maxLength: _maxNameLength,
      );
      expect(sanitized, _rtloExpected);
    });

    test('removes path separators from corpus samples', () {
      for (final name in corpus.attachmentPathTraversalNames) {
        final sanitized = sanitizeAttachmentFileName(
          rawName: name,
          fallbackName: _fallbackName,
          maxLength: _maxNameLength,
        );
        expect(sanitized.contains(_posixSeparator), isFalse);
        expect(sanitized.contains(_windowsSeparator), isFalse);
        expect(sanitized.isNotEmpty, isTrue);
      }
    });

    test('truncates long names while preserving extensions', () {
      final longBase = List.filled(_longBaseRepeat, _longBaseChar).join();
      final longName = '$longBase$_longExtension';
      final sanitized = sanitizeAttachmentFileName(
        rawName: longName,
        fallbackName: _fallbackName,
        maxLength: _truncateMaxLength,
      );
      const int expectedBaseLength = _truncateMaxLength - _longExtension.length;
      final expectedBase = longBase.substring(0, expectedBaseLength);
      expect(sanitized, '$expectedBase$_longExtension');
    });
  });
}
