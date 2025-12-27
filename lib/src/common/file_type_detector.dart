import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';

const int _fileTypeProbeBytes = 512;
const String _genericBinaryMimeType = 'application/octet-stream';
const String _mimeDetectionPlaceholder = 'file';
const String _jpegAliasMimeType = 'image/jpg';
const String _jpegMimeType = 'image/jpeg';

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
