import 'dart:io';
import 'dart:typed_data';

import 'package:axichat/src/common/unicode_safety.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

const int _fileTypeProbeBytes = 512;
const String _genericBinaryMimeType = 'application/octet-stream';
const String _mimeDetectionPlaceholder = 'file';
const String _jpegAliasMimeType = 'image/jpg';
const String _jpegMimeType = 'image/jpeg';
const String _tnefFileName = 'winmail.dat';

const Set<String> _imageMimeTypes = <String>{
  'image/png',
  _jpegMimeType,
  'image/gif',
  'image/webp',
  'image/bmp',
  'image/heic',
  'image/heif',
  'image/avif',
};

const Set<String> _videoMimeTypes = <String>{
  'video/mp4',
  'video/quicktime',
  'video/webm',
  'video/x-matroska',
  'video/x-msvideo',
  'video/mpeg',
  'video/3gpp',
  'video/3gpp2',
};

const Set<String> _highRiskExtensions = <String>{
  'app',
  'bat',
  'cmd',
  'com',
  'cpl',
  'dmg',
  'docm',
  'dotm',
  'exe',
  'htm',
  'html',
  'jar',
  'js',
  'lnk',
  'msi',
  'msix',
  'msp',
  'pkg',
  'potm',
  'ppam',
  'pptm',
  'ps1',
  'psd1',
  'psm1',
  'py',
  'scr',
  'sh',
  'sldm',
  'svg',
  'svgz',
  'tnef',
  'url',
  'vbs',
  'vcf',
  'xlam',
  'xlsm',
  'xltm',
};

const Set<String> _highRiskMimeTypes = <String>{
  'application/javascript',
  'application/vnd.microsoft.portable-executable',
  'application/vnd.ms-excel.addin.macroenabled.12',
  'application/vnd.ms-excel.sheet.macroenabled.12',
  'application/vnd.ms-excel.template.macroenabled.12',
  'application/vnd.ms-powerpoint.addin.macroenabled.12',
  'application/vnd.ms-powerpoint.presentation.macroenabled.12',
  'application/vnd.ms-powerpoint.slideshow.macroenabled.12',
  'application/vnd.ms-powerpoint.template.macroenabled.12',
  'application/vnd.ms-word.document.macroenabled.12',
  'application/vnd.ms-word.template.macroenabled.12',
  'application/x-apple-diskimage',
  'application/x-dosexec',
  'application/x-elf',
  'application/x-executable',
  'application/x-ms-shortcut',
  'application/x-msdownload',
  'application/x-msdos-program',
  'application/x-msi',
  'application/x-ms-installer',
  'application/ms-tnef',
  'application/vnd.ms-tnef',
  'application/x-powershell',
  'application/x-shellscript',
  'application/x-sh',
  'application/x-url',
  'application/vcard',
  'application/x-vcard',
  'application/x-vbscript',
  'application/x-python',
  'image/svg+xml',
  'text/html',
  'text/javascript',
  'text/vcard',
  'text/x-vcard',
  'text/directory',
  'text/vbscript',
  'text/x-python',
  'text/x-shellscript',
};

enum FileOpenRisk {
  safe,
  warning;

  bool get isWarning => this == warning;
}

class FileTypeReport {
  const FileTypeReport({
    required this.detectedMimeType,
    required this.declaredMimeType,
    required this.extensionMimeType,
  });

  final String? detectedMimeType;
  final String? declaredMimeType;
  final String? extensionMimeType;

  bool get isDetectedImage => _isImageMimeType(detectedMimeType);
  bool get isDetectedVideo => _isVideoMimeType(detectedMimeType);

  bool get hasMismatch {
    final normalizedDetected = _normalizeMimeType(detectedMimeType);
    if (!_isReliableMimeType(normalizedDetected)) return false;
    final normalizedDeclared = _normalizeMimeType(declaredMimeType) ??
        _normalizeMimeType(extensionMimeType);
    if (normalizedDeclared == null) return false;
    return normalizedDeclared != normalizedDetected;
  }

  String? get detectedLabel => _normalizeMimeType(detectedMimeType);

  String? get declaredLabel =>
      _normalizeMimeType(declaredMimeType) ??
      _normalizeMimeType(extensionMimeType);
}

Future<FileTypeReport> inspectFileType({
  required File file,
  required String? declaredMimeType,
  required String? fileName,
}) async {
  try {
    final headerBytes = await _readHeaderBytes(file);
    final detectedMimeType = _normalizeMimeType(
      lookupMimeType(
        _mimeDetectionPlaceholder,
        headerBytes: headerBytes.isEmpty ? null : headerBytes,
      ),
    );
    final extensionMimeType = _normalizeMimeType(
      lookupMimeType(fileName ?? file.path),
    );
    return FileTypeReport(
      detectedMimeType: detectedMimeType,
      declaredMimeType: declaredMimeType,
      extensionMimeType: extensionMimeType,
    );
  } on Exception {
    return FileTypeReport(
      detectedMimeType: null,
      declaredMimeType: declaredMimeType,
      extensionMimeType: _normalizeMimeType(
        lookupMimeType(fileName ?? file.path),
      ),
    );
  }
}

Future<Uint8List> _readHeaderBytes(File file) async {
  final handle = await file.open();
  try {
    final length = await handle.length();
    final bytesToRead =
        length < _fileTypeProbeBytes ? length : _fileTypeProbeBytes;
    if (bytesToRead <= 0) return Uint8List(0);
    final chunk = await handle.read(bytesToRead);
    return Uint8List.fromList(chunk);
  } finally {
    await handle.close();
  }
}

String? _normalizeMimeType(String? mimeType) {
  final trimmed = mimeType?.trim().toLowerCase();
  if (trimmed == null || trimmed.isEmpty) return null;
  if (trimmed == _jpegAliasMimeType) return _jpegMimeType;
  return trimmed;
}

bool _isReliableMimeType(String? mimeType) {
  if (mimeType == null || mimeType.isEmpty) return false;
  return mimeType != _genericBinaryMimeType;
}

bool _isImageMimeType(String? mimeType) {
  final normalized = _normalizeMimeType(mimeType);
  if (normalized == null) return false;
  return _imageMimeTypes.contains(normalized);
}

bool _isVideoMimeType(String? mimeType) {
  final normalized = _normalizeMimeType(mimeType);
  if (normalized == null) return false;
  if (normalized.startsWith('video/')) return true;
  return _videoMimeTypes.contains(normalized);
}

FileOpenRisk assessFileOpenRisk({
  required FileTypeReport report,
  required String? fileName,
}) {
  final detected = report.detectedLabel;
  if (_isHighRiskMimeType(detected)) {
    return FileOpenRisk.warning;
  }
  final declared = report.declaredLabel;
  if (_isHighRiskMimeType(declared)) {
    return FileOpenRisk.warning;
  }
  final extension = _normalizeExtension(fileName);
  if (extension != null && _highRiskExtensions.contains(extension)) {
    return FileOpenRisk.warning;
  }
  if (_isHighRiskFileName(fileName)) {
    return FileOpenRisk.warning;
  }
  return FileOpenRisk.safe;
}

String? _normalizeExtension(String? fileName) {
  final trimmed = fileName?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final extension = p.extension(trimmed).toLowerCase();
  if (extension.isEmpty) return null;
  return extension.startsWith('.') ? extension.substring(1) : extension;
}

bool _isHighRiskFileName(String? fileName) {
  final trimmed = fileName?.trim();
  if (trimmed == null || trimmed.isEmpty) return false;
  final baseName = p.basename(trimmed);
  if (containsUnicodeControlCharacters(baseName)) {
    return true;
  }
  return baseName.toLowerCase() == _tnefFileName;
}

bool _isHighRiskMimeType(String? mimeType) {
  final normalized = _normalizeMimeType(mimeType);
  if (normalized == null) return false;
  return _highRiskMimeTypes.contains(normalized);
}
