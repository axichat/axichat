import 'dart:io';
import 'package:image/image.dart' as img;

const _inputBackground = 'assets/icons/app_icon_background.png';
const _inputForeground = 'assets/icons/app_icon_foreground.png';
const _inputMonochrome = 'assets/icons/app_icon_monochrome.png';

const _outputBackground =
    'assets/icons/generated/app_icon_android_background.png';
const _outputForeground =
    'assets/icons/generated/app_icon_android_foreground.png';
const _outputMonochrome =
    'assets/icons/generated/app_icon_android_monochrome.png';

const _targetSize = 1024;

void main(List<String> arguments) {
  final background =
      _prepareLayer(_loadImage(_inputBackground), layer: 'background');
  final foreground =
      _prepareLayer(_loadImage(_inputForeground), layer: 'foreground');
  final monochromeSource = _loadOptionalImage(_inputMonochrome);
  final monochrome = _prepareLayer(
    monochromeSource ?? _deriveMonochrome(foreground),
    layer: 'monochrome',
  );

  _writeImage(_outputBackground, background);
  _writeImage(_outputForeground, foreground);
  _writeImage(_outputMonochrome, monochrome);
}

img.Image _loadImage(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Missing required icon asset: $path');
    exit(1);
  }
  final bytes = file.readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    stderr.writeln('Unable to decode image at $path');
    exit(1);
  }
  return decoded;
}

img.Image? _loadOptionalImage(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return null;
  }
  final bytes = file.readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    stderr.writeln(
        'Optional icon asset at $path is invalid. Falling back to derived monochrome.');
    return null;
  }
  return decoded;
}

img.Image _prepareLayer(img.Image image, {required String layer}) {
  if (image.width != image.height) {
    stderr.writeln(
        'Warning: $layer layer is not square (${image.width}x${image.height}). It will be resized to $_targetSize x $_targetSize.');
  }
  if (image.width == _targetSize && image.height == _targetSize) {
    return img.Image.from(image);
  }
  return img.copyResize(image,
      width: _targetSize,
      height: _targetSize,
      interpolation: img.Interpolation.linear);
}

img.Image _deriveMonochrome(img.Image source) {
  final mono = img.Image(
    width: source.width,
    height: source.height,
    numChannels: 4,
    backgroundColor: img.ColorRgba8(0, 0, 0, 0),
  );
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final pixel = source.getPixel(x, y);
      final alpha = pixel.a.toInt();
      if (alpha == 0) {
        continue;
      }
      mono.setPixelRgba(x, y, 255, 255, 255, alpha);
    }
  }
  stdout.writeln('Derived monochrome layer from foreground.');
  return mono;
}

void _writeImage(String path, img.Image image) {
  final file = File(path);
  file.createSync(recursive: true);
  file.writeAsBytesSync(img.encodePng(image));
  stdout.writeln('Wrote $path');
}
