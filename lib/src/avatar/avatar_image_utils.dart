import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

// package:image Image objects are not isolate-sendable, so decode on the current isolate.
Future<img.Image?> decodeImageBytes(Uint8List bytes) async =>
    img.decodeImage(bytes);

Future<ProcessedAvatar> processAvatar(AvatarProcessRequest request) =>
    compute(_processAvatar, request);

Future<AvatarPreparedSource> prepareAvatarSource(
  AvatarSourcePrepareRequest request,
) =>
    compute(_prepareAvatarSource, request);

ProcessedAvatar _processAvatar(AvatarProcessRequest request) {
  final image = img.decodeImage(request.bytes);
  if (image == null) {
    throw StateError('Invalid image bytes.');
  }

  final left = request.cropLeft.round().clamp(
        0,
        image.width > 0 ? image.width - 1 : 0,
      );
  final top = request.cropTop.round().clamp(
        0,
        image.height > 0 ? image.height - 1 : 0,
      );
  final maxCropWidth = image.width - left;
  final maxCropHeight = image.height - top;
  final maxSide = maxCropWidth < maxCropHeight ? maxCropWidth : maxCropHeight;
  final safeMaxSide = maxSide <= 0 ? 1 : maxSide;
  final side = request.cropSide.round().clamp(1, safeMaxSide);
  final width = side;
  final height = side;

  var cropped = img.copyCrop(
    image,
    x: left,
    y: top,
    width: width,
    height: height,
  );

  if (request.flattenBackground) {
    final background = img.Image(
      width: cropped.width,
      height: cropped.height,
      numChannels: 4,
      format: img.Format.uint8,
    );
    img.fill(background, color: _imgColor(request.backgroundColor));
    img.compositeImage(background, cropped);
    cropped = background;
  }

  if (request.shouldInset) {
    final inset = (cropped.width * request.insetFraction).round();
    final contentSize = cropped.width - inset * 2;
    if (inset > 0 && contentSize > 0) {
      final scaled = img.copyResize(
        cropped,
        width: contentSize,
        height: contentSize,
        interpolation: img.Interpolation.cubic,
      );
      final canvas = img.Image(
        width: cropped.width,
        height: cropped.height,
        numChannels: 4,
        format: img.Format.uint8,
      );
      final paddingColor = request.flattenBackground
          ? _imgColor(request.backgroundColor)
          : img.ColorUint8.rgba(0, 0, 0, 0);
      img.fill(canvas, color: paddingColor);
      img.compositeImage(canvas, scaled, dstX: inset, dstY: inset);
      cropped = canvas;
    }
  }

  final resized = img.copyResize(
    cropped,
    width: request.targetSize,
    height: request.targetSize,
    interpolation: img.Interpolation.cubic,
  );

  Uint8List? encodedBytes;
  String? mimeType;

  if (resized.numChannels == 4) {
    final pngBytes = Uint8List.fromList(img.encodePng(resized, level: 4));
    if (pngBytes.length <= request.maxBytes) {
      encodedBytes = pngBytes;
      mimeType = 'image/png';
    }
  }

  if (encodedBytes == null) {
    var quality = 90;
    Uint8List jpgBytes = Uint8List.fromList(
      img.encodeJpg(resized, quality: quality),
    );
    while (jpgBytes.length > request.maxBytes &&
        quality > request.minJpegQuality) {
      quality =
          (quality - request.qualityStep).clamp(request.minJpegQuality, 90);
      jpgBytes = Uint8List.fromList(
        img.encodeJpg(resized, quality: quality),
      );
    }
    encodedBytes = jpgBytes;
    mimeType = 'image/jpeg';
  }

  return ProcessedAvatar(
    bytes: encodedBytes,
    mimeType: mimeType!,
    width: resized.width,
    height: resized.height,
  );
}

AvatarPreparedSource _prepareAvatarSource(AvatarSourcePrepareRequest request) {
  final image = img.decodeImage(request.bytes);
  if (image == null) {
    throw StateError('Invalid image bytes.');
  }

  final maxSide = image.width > image.height ? image.width : image.height;
  if (maxSide <= 0) {
    throw StateError('Decoded image has invalid dimensions.');
  }

  final maxDimension = request.maxDimension;
  if (maxSide <= maxDimension) {
    return AvatarPreparedSource(
      bytes: request.bytes,
      width: image.width,
      height: image.height,
    );
  }

  final scale = maxDimension / maxSide;
  final targetWidth = (image.width * scale).round().clamp(1, maxDimension);
  final targetHeight = (image.height * scale).round().clamp(1, maxDimension);
  final resized = img.copyResize(
    image,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.cubic,
  );

  final hasAlpha = resized.numChannels == 4;
  final bytes = hasAlpha
      ? Uint8List.fromList(img.encodePng(resized, level: 3))
      : Uint8List.fromList(
          img.encodeJpg(resized, quality: request.jpegQuality),
        );

  return AvatarPreparedSource(
    bytes: bytes,
    width: resized.width,
    height: resized.height,
  );
}

img.Color _imgColor(int argb) => img.ColorUint8.rgba(
      (argb >> 16) & 0xFF,
      (argb >> 8) & 0xFF,
      argb & 0xFF,
      (argb >> 24) & 0xFF,
    );

class AvatarSourcePrepareRequest {
  const AvatarSourcePrepareRequest({
    required this.bytes,
    required this.maxDimension,
    required this.jpegQuality,
  });

  final Uint8List bytes;
  final int maxDimension;
  final int jpegQuality;
}

class AvatarPreparedSource {
  const AvatarPreparedSource({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

class AvatarProcessRequest {
  const AvatarProcessRequest({
    required this.bytes,
    required this.cropLeft,
    required this.cropTop,
    required this.cropSide,
    required this.targetSize,
    required this.maxBytes,
    required this.insetFraction,
    required this.shouldInset,
    required this.backgroundColor,
    required this.flattenBackground,
    required this.minJpegQuality,
    required this.qualityStep,
  });

  final Uint8List bytes;
  final double cropLeft;
  final double cropTop;
  final double cropSide;
  final int targetSize;
  final int maxBytes;
  final double insetFraction;
  final bool shouldInset;
  final int backgroundColor;
  final bool flattenBackground;
  final int minJpegQuality;
  final int qualityStep;
}

class ProcessedAvatar {
  const ProcessedAvatar({
    required this.bytes,
    required this.mimeType,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final String mimeType;
  final int width;
  final int height;
}
