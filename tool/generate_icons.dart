import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

/// Generates platform-specific launcher icon variants from a single square
/// source image. Each platform has slightly different masking expectations
/// (squircle, circle, rounded rectangle, etc.), so we pre-render those shapes
/// before flutter_launcher_icons copies them into the various bundles.
Future<void> main(List<String> args) async {
  final sourcePath =
      args.isNotEmpty ? args[0] : 'assets/icons/app_icon_source.png';
  final outputDir = args.length > 1 ? args[1] : 'assets/icons/generated';

  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Source icon not found at $sourcePath');
    exit(1);
  }

  final sourceBytes = sourceFile.readAsBytesSync();
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    stderr.writeln('Unable to decode $sourcePath');
    exit(1);
  }
  final source = decoded.hasAlpha ? decoded : decoded.convert(numChannels: 4);

  if (source.width != source.height) {
    stderr.writeln(
        'Source icon must be square. Got ${source.width}x${source.height}.');
    exit(1);
  }

  final outDirectory = Directory(outputDir)..createSync(recursive: true);
  final macosMask = _tryLoadMask('assets/icons/masks/macos_mask.png');
  if (macosMask == null) {
    stdout.writeln(
      'Warning: macOS mask missing, falling back to generated squircle.',
    );
  }
  final generator = _IconGenerator(source, outDirectory);

  generator.writeVariant(
    fileName: 'app_icon_ios.png',
    exponent: 3.6,
    insetFraction: 0.05,
  );
  generator.writeVariant(
    fileName: 'app_icon_macos.png',
    mask: macosMask,
    exponent: macosMask == null ? 3.6 : null,
    insetFraction: macosMask == null ? 0.05 : null,
  );
  generator.writeVariant(
    fileName: 'app_icon_web.png',
    exponent: 3.4,
    insetFraction: 0.04,
  );
  generator.writeVariant(
    fileName: 'app_icon_windows.png',
    exponent: 4.2,
    insetFraction: 0.02,
  );
  generator.writeVariant(
    fileName: 'app_icon_linux.png',
    exponent: 3.4,
    insetFraction: 0.1,
  );
  generator.writeVariant(
    fileName: 'app_icon_android_legacy.png',
    exponent: 2.6,
    insetFraction: 0.12,
  );
  generator.writeVariant(
    fileName: 'app_icon_android_foreground.png',
    exponent: 2.0,
    insetFraction: 0.2,
  );
  generator.writeSolidColor(
    fileName: 'app_icon_android_background.png',
    color: const _RgbaColor(0x1B, 0xA5, 0xFF, 0xFF),
  );

  stdout.writeln(
      'Generated platform-specific icon variants in ${outDirectory.path}');
}

img.Image? _tryLoadMask(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return null;
  }
  final image = img.decodeImage(file.readAsBytesSync());
  if (image == null) {
    stderr.writeln('Failed to decode mask at $path');
    return null;
  }
  return image;
}

class _IconGenerator {
  _IconGenerator(this.source, this.directory);

  final img.Image source;
  final Directory directory;

  void writeVariant({
    required String fileName,
    double? exponent,
    double? insetFraction,
    img.Image? mask,
  }) {
    final variant = img.Image.from(source);
    if (mask != null) {
      _applyImageMask(variant, mask);
    } else {
      if (exponent == null || insetFraction == null) {
        throw ArgumentError('Provide either a mask or exponent/inset pair.');
      }
      _applySuperellipseMask(
        variant,
        exponent: exponent,
        insetFraction: insetFraction,
      );
    }
    _writePng(variant, fileName);
  }

  void writeSolidColor({
    required String fileName,
    required _RgbaColor color,
  }) {
    final image = img.Image(width: source.width, height: source.height);
    img.fill(
      image,
      color: img.ColorRgba8(color.r, color.g, color.b, color.a),
    );
    _writePng(image, fileName);
  }

  void _writePng(img.Image image, String fileName) {
    final file = File('${directory.path}/$fileName')
      ..createSync(recursive: true);
    file.writeAsBytesSync(img.encodePng(image));
  }
}

void _applyImageMask(img.Image image, img.Image mask) {
  if (mask.width != image.width || mask.height != image.height) {
    throw ArgumentError('Mask size ${mask.width}x${mask.height} does not match '
        '${image.width}x${image.height}');
  }
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final maskPixel = mask.getPixel(x, y);
      final newAlpha = (pixel.a * maskPixel.a) ~/ 255;
      image.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, newAlpha);
    }
  }
}

void _applySuperellipseMask(
  img.Image image, {
  required double exponent,
  required double insetFraction,
}) {
  final width = image.width;
  final height = image.height;
  final half = (width - 1) / 2;
  final inset = width * insetFraction / 2;
  final scale = max(half - inset, 1);

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final nx = (x - half) / scale;
      final ny = (y - half) / scale;
      final radius =
          pow(pow(nx.abs(), exponent) + pow(ny.abs(), exponent), 1 / exponent);
      if (radius > 1) {
        final pixel = image.getPixel(x, y);
        image.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, 0);
      }
    }
  }
}

class _RgbaColor {
  const _RgbaColor(this.r, this.g, this.b, this.a);

  final int r;
  final int g;
  final int b;
  final int a;
}
