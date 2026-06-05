// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:axichat/src/calendar/models/calendar_model.dart';

/// Codec for single-file calendar snapshots.
class CalendarSnapshotCodec {
  CalendarSnapshotCodec._();

  static const int currentVersion = 1;

  static const String mimeType = 'application/x-axichat-calendar-snapshot';
  static const String fileExtension = '.axical.gz';

  static const int maxCompressedBytes = 256 * 1024 * 1024;
  static const int maxDecompressedBytes = 1024 * 1024 * 1024;

  static const String _versionKey = 'version';
  static const String _generatedAtKey = 'generatedAt';
  static const String _checksumKey = 'checksum';
  static const String _calendarModelKey = 'calendar_model';

  static Uint8List encode(CalendarModel model) {
    final checksum = model.calculateChecksum();
    final envelope = <String, dynamic>{
      _versionKey: currentVersion,
      _generatedAtKey: DateTime.now().toUtc().toIso8601String(),
      _checksumKey: checksum,
      _calendarModelKey: model.copyWith(checksum: checksum).toJson(),
    };
    final jsonBytes = utf8.encode(jsonEncode(envelope));
    if (jsonBytes.length > maxDecompressedBytes) {
      throw const CalendarSnapshotTooLargeException(
        'Calendar snapshot exceeds the receiver limit.',
      );
    }
    final compressedBytes = Uint8List.fromList(gzip.encode(jsonBytes));
    if (compressedBytes.length > maxCompressedBytes) {
      throw const CalendarSnapshotTooLargeException(
        'Calendar snapshot upload exceeds the receiver limit.',
      );
    }
    return compressedBytes;
  }

  static CalendarSnapshotResult? decode(Uint8List compressedBytes) {
    if (compressedBytes.isEmpty ||
        compressedBytes.length > maxCompressedBytes) {
      return null;
    }
    try {
      final decompressed = _decodeGzipWithLimit(
        compressedBytes,
        maxBytes: maxDecompressedBytes,
      );
      if (decompressed == null) {
        return null;
      }
      final decoded = jsonDecode(utf8.decode(decompressed));
      if (decoded is! Map) {
        return null;
      }
      return _parseEnvelope(Map<String, dynamic>.from(decoded));
    } on FormatException {
      return null;
    } on Exception {
      return null;
    }
  }

  static Future<CalendarSnapshotResult?> decodeFile(File file) async {
    try {
      final length = await file.length();
      if (length <= 0 || length > maxCompressedBytes) {
        return null;
      }
      return decode(await file.readAsBytes());
    } on FileSystemException {
      return null;
    }
  }

  static Future<File> encodeToFile(
    CalendarModel model, {
    required Directory directory,
    String? fileName,
  }) async {
    final bytes = encode(model);
    final name = fileName ?? _generateFileName();
    final file = File('${directory.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  static String computeChecksum(CalendarModel model) =>
      model.calculateChecksum();

  static bool verifyChecksum(CalendarSnapshotResult snapshot) {
    return snapshot.model.calculateChecksum() == snapshot.checksum;
  }

  static CalendarSnapshotResult? _parseEnvelope(Map<String, dynamic> envelope) {
    final version = envelope[_versionKey] as int?;
    final generatedAtStr = envelope[_generatedAtKey] as String?;
    final checksum = envelope[_checksumKey] as String?;
    final modelJson = envelope[_calendarModelKey] as Map<String, dynamic>?;
    if (version == null ||
        version > currentVersion ||
        generatedAtStr == null ||
        checksum == null ||
        modelJson == null) {
      return null;
    }
    try {
      return CalendarSnapshotResult(
        version: version,
        generatedAt: DateTime.parse(generatedAtStr).toUtc(),
        checksum: checksum,
        model: CalendarModel.fromJson(modelJson),
      );
    } on FormatException {
      return null;
    } on Exception {
      return null;
    }
  }

  static Uint8List? _decodeGzipWithLimit(
    Uint8List compressedBytes, {
    required int maxBytes,
  }) {
    final sink = _LimitedByteSink(maxBytes);
    final converter = GZipCodec().decoder.startChunkedConversion(sink);
    try {
      converter.add(compressedBytes);
      converter.close();
      return sink.takeBytes();
    } on FormatException {
      return null;
    } on Exception {
      return null;
    }
  }

  static String _generateFileName() {
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      ':',
      '-',
    );
    return 'calendar_snapshot_$timestamp$fileExtension';
  }
}

class CalendarSnapshotResult {
  const CalendarSnapshotResult({
    required this.version,
    required this.generatedAt,
    required this.checksum,
    required this.model,
  });

  final int version;
  final DateTime generatedAt;
  final String checksum;
  final CalendarModel model;

  @override
  String toString() {
    final checksumPreview = checksum.length <= 8
        ? checksum
        : checksum.substring(0, 8);
    return 'CalendarSnapshotResult('
        'version: $version, '
        'generatedAt: $generatedAt, '
        'checksum: $checksumPreview...)';
  }
}

class CalendarSnapshotUploadResult {
  const CalendarSnapshotUploadResult({
    required this.url,
    required this.checksum,
    required this.version,
  });

  final String url;
  final String checksum;
  final int version;
}

class CalendarSnapshotTooLargeException implements Exception {
  const CalendarSnapshotTooLargeException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _LimitedByteSink extends ByteConversionSinkBase {
  _LimitedByteSink(this._maxBytes);

  final int _maxBytes;
  final BytesBuilder _builder = BytesBuilder();
  var _length = 0;
  var _closed = false;

  @override
  void add(List<int> chunk) {
    if (_closed) {
      return;
    }
    final nextLength = _length + chunk.length;
    if (nextLength > _maxBytes) {
      _closed = true;
      throw const FormatException();
    }
    _length = nextLength;
    _builder.add(chunk);
  }

  @override
  void close() {
    _closed = true;
  }

  Uint8List takeBytes() => _builder.takeBytes();
}
