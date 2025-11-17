// ignore_for_file: avoid_print

import 'dart:io';

import 'package:image/image.dart' as img;

/// Prints the first opaque pixel encountered on several rows so we can deduce
/// the platform mask insets.
///
/// Usage: `dart run tool/mask_probe.dart <image-path>`
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/mask_probe.dart <image-path>');
    exit(1);
  }

  final file = File(args.first);
  if (!file.existsSync()) {
    stderr.writeln('Missing file ${file.path}');
    exit(1);
  }

  final image = img.decodeImage(file.readAsBytesSync());
  if (image == null) {
    stderr.writeln('Unable to decode ${file.path}');
    exit(1);
  }

  print('Image: ${image.width}x${image.height}');
  const fractions = <double>[
    0,
    0.02,
    0.04,
    0.06,
    0.08,
    0.1,
    0.12,
    0.15,
    0.2,
    0.25,
    0.3,
    0.35,
    0.4,
    0.5,
  ];
  final rows = fractions
      .map((fraction) =>
          (image.height * fraction).round().clamp(0, image.height - 1))
      .toList();

  for (final row in rows) {
    final column = _firstOpaque(image, row);
    print('row $row -> first opaque column $column');
  }
}

int _firstOpaque(img.Image image, int row) {
  for (var x = 0; x < image.width; x++) {
    if (image.getPixel(x, row).a > 0) {
      return x;
    }
  }
  return -1;
}
