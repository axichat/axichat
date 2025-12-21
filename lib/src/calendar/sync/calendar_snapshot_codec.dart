import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:axichat/src/calendar/models/calendar_model.dart';

/// Codec for encoding and decoding full [CalendarModel] snapshots.
///
/// Snapshots are gzip-compressed JSON with metadata for version tracking
/// and integrity verification.
class CalendarSnapshotCodec {
  CalendarSnapshotCodec._();

  /// Current snapshot format version.
  static const int currentVersion = 1;

  /// MIME type for snapshot files.
  static const String mimeType = 'application/x-axichat-calendar-snapshot';

  /// File extension for snapshot files.
  static const String fileExtension = '.axical.gz';

  /// Encodes a [CalendarModel] to a gzip-compressed snapshot.
  ///
  /// Returns the compressed bytes suitable for file upload.
  static Uint8List encode(CalendarModel model) {
    final envelope = _createEnvelope(model);
    final jsonBytes = utf8.encode(jsonEncode(envelope));
    return Uint8List.fromList(gzip.encode(jsonBytes));
  }

  /// Decodes a gzip-compressed snapshot to a [CalendarSnapshotResult].
  ///
  /// Returns null if decoding fails or the snapshot is invalid.
  static CalendarSnapshotResult? decode(Uint8List compressedBytes) {
    try {
      final decompressed = gzip.decode(compressedBytes);
      final jsonString = utf8.decode(decompressed);
      final envelope = jsonDecode(jsonString) as Map<String, dynamic>;
      return _parseEnvelope(envelope);
    } on FormatException {
      return null;
    } on Exception {
      return null;
    }
  }

  /// Decodes a snapshot from a file.
  static Future<CalendarSnapshotResult?> decodeFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return decode(bytes);
    } on FileSystemException {
      return null;
    }
  }

  /// Encodes a [CalendarModel] and writes to a file.
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

  /// Computes the checksum for a snapshot envelope.
  static String computeChecksum(CalendarModel model) {
    return model.calculateChecksum();
  }

  /// Verifies that a snapshot's checksum matches its content.
  static bool verifyChecksum(CalendarSnapshotResult snapshot) {
    final computed = snapshot.model.calculateChecksum();
    return computed == snapshot.checksum;
  }

  static Map<String, dynamic> _createEnvelope(CalendarModel model) {
    return <String, dynamic>{
      'version': currentVersion,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'checksum': model.calculateChecksum(),
      'calendar_model': model.toJson(),
    };
  }

  static CalendarSnapshotResult? _parseEnvelope(Map<String, dynamic> envelope) {
    final version = envelope['version'] as int?;
    if (version == null || version > currentVersion) {
      return null;
    }

    final generatedAtStr = envelope['generatedAt'] as String?;
    if (generatedAtStr == null) {
      return null;
    }

    final checksum = envelope['checksum'] as String?;
    if (checksum == null) {
      return null;
    }

    final modelJson = envelope['calendar_model'] as Map<String, dynamic>?;
    if (modelJson == null) {
      return null;
    }

    try {
      final model = CalendarModel.fromJson(modelJson);
      return CalendarSnapshotResult(
        version: version,
        generatedAt: DateTime.parse(generatedAtStr),
        checksum: checksum,
        model: model,
      );
    } on FormatException {
      return null;
    }
  }

  static String _generateFileName() {
    final timestamp =
        DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    return 'calendar_snapshot_$timestamp$fileExtension';
  }
}

/// Result of decoding a calendar snapshot.
class CalendarSnapshotResult {
  const CalendarSnapshotResult({
    required this.version,
    required this.generatedAt,
    required this.checksum,
    required this.model,
  });

  /// Snapshot format version.
  final int version;

  /// When the snapshot was generated.
  final DateTime generatedAt;

  /// Checksum of the model at generation time.
  final String checksum;

  /// The decoded calendar model.
  final CalendarModel model;

  @override
  String toString() {
    return 'CalendarSnapshotResult('
        'version: $version, '
        'generatedAt: $generatedAt, '
        'checksum: ${checksum.substring(0, 8)}...)';
  }
}
