// ignore_for_file: avoid_print

import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/inspect_icon_alpha.dart <path>');
    exit(1);
  }
  final file = File(args.first);
  if (!file.existsSync()) {
    stderr.writeln('Missing file ${args.first}');
    exit(1);
  }
  final image = img.decodeImage(file.readAsBytesSync());
  if (image == null) {
    stderr.writeln('Unable to decode image');
    exit(1);
  }

  print('Image: ${image.width}x${image.height}');
  final samples = <(int, int)>[
    (0, 0),
    (10, 10),
    (50, 50),
    (100, 100),
    (image.width ~/ 2, image.height ~/ 2),
    (image.width - 1, image.height - 1),
  ];

  for (final sample in samples) {
    final x = sample.$1.clamp(0, image.width - 1);
    final y = sample.$2.clamp(0, image.height - 1);
    final pixel = image.getPixel(x, y);
    print('($x,$y): rgba(${pixel.r}, ${pixel.g}, ${pixel.b}, ${pixel.a})');
  }
}
