import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

class ImageDecodeLimits {
  const ImageDecodeLimits({
    required this.maxBytes,
    required this.maxPixels,
    required this.maxFrames,
    required this.minDimension,
    required this.decodeTimeout,
    this.minBytes = _defaultMinBytes,
    this.minFrames = _defaultMinFrames,
  });

  static const int _defaultMinBytes = 1;
  static const int _defaultMinFrames = 1;

  final int maxBytes;
  final int maxPixels;
  final int maxFrames;
  final int minDimension;
  final Duration decodeTimeout;
  final int minBytes;
  final int minFrames;
}

const int _maxDecodeFailureCount = 3;
const int _maxDecodeFailureEntries = 256;
const Duration _decodeFailureCooldown = Duration(minutes: 10);

class MediaDecodeGuard {
  MediaDecodeGuard._();

  static final MediaDecodeGuard instance = MediaDecodeGuard._();

  final Map<String, _DecodeFailure> _failures = <String, _DecodeFailure>{};

  bool allowAttempt(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return true;
    final entry = _failures[trimmed];
    if (entry == null) return true;
    if (_isExpired(entry)) {
      _failures.remove(trimmed);
      return true;
    }
    return entry.count < _maxDecodeFailureCount;
  }

  void registerFailure(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;
    final now = DateTime.now();
    final entry = _failures[trimmed];
    if (entry == null || _isExpired(entry)) {
      _failures[trimmed] = _DecodeFailure(count: 1, lastFailure: now);
    } else {
      _failures[trimmed] = entry.increment(now);
    }
    _evictIfNeeded();
  }

  void registerSuccess(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;
    _failures.remove(trimmed);
  }

  bool _isExpired(_DecodeFailure entry) =>
      DateTime.now().difference(entry.lastFailure) > _decodeFailureCooldown;

  void _evictIfNeeded() {
    if (_failures.length <= _maxDecodeFailureEntries) return;
    var oldestKey = '';
    DateTime? oldestTime;
    for (final entry in _failures.entries) {
      if (oldestTime == null || entry.value.lastFailure.isBefore(oldestTime)) {
        oldestTime = entry.value.lastFailure;
        oldestKey = entry.key;
      }
    }
    if (oldestKey.isNotEmpty) {
      _failures.remove(oldestKey);
    }
  }
}

class _DecodeFailure {
  const _DecodeFailure({
    required this.count,
    required this.lastFailure,
  });

  final int count;
  final DateTime lastFailure;

  _DecodeFailure increment(DateTime timestamp) => _DecodeFailure(
        count: count + 1,
        lastFailure: timestamp,
      );
}

Future<bool> isSafeImageFile(File file, ImageDecodeLimits limits) async {
  try {
    if (!await file.exists()) {
      return false;
    }
    final length = await file.length();
    if (!_isLengthSafe(length, limits)) {
      return false;
    }
    final bytes = await file.readAsBytes();
    if (!_isLengthSafe(bytes.length, limits)) {
      return false;
    }
    return isSafeImageBytes(bytes, limits);
  } on Exception {
    return false;
  }
}

Future<bool> isSafeImageBytes(
  Uint8List bytes,
  ImageDecodeLimits limits,
) async {
  if (!_isLengthSafe(bytes.length, limits)) {
    return false;
  }
  try {
    final codec =
        await ui.instantiateImageCodec(bytes).timeout(limits.decodeTimeout);
    try {
      final frameCount = codec.frameCount;
      if (frameCount < limits.minFrames || frameCount > limits.maxFrames) {
        return false;
      }
      final frame = await codec.getNextFrame().timeout(limits.decodeTimeout);
      final image = frame.image;
      try {
        final width = image.width;
        final height = image.height;
        if (width < limits.minDimension || height < limits.minDimension) {
          return false;
        }
        final pixelCount = width * height;
        if (pixelCount > limits.maxPixels) {
          return false;
        }
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
    return true;
  } on Exception {
    return false;
  }
}

bool _isLengthSafe(int length, ImageDecodeLimits limits) {
  if (length < limits.minBytes) {
    return false;
  }
  if (length > limits.maxBytes) {
    return false;
  }
  return true;
}
