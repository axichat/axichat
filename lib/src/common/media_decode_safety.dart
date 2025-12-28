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
