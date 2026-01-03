// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:typed_data';
import 'dart:math';

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
  const pngCompressionLevel = 6;
  const jpegStartQuality = 90;
  const minDownscale = 48;
  const downscaleFactor = 0.85;

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

  ProcessedAvatar encode(img.Image candidate) {
    if (candidate.numChannels == 4) {
      final pngBytes = Uint8List.fromList(
        img.encodePng(candidate, level: pngCompressionLevel),
      );
      if (pngBytes.length <= request.maxBytes) {
        return ProcessedAvatar(
          bytes: pngBytes,
          mimeType: 'image/png',
          width: candidate.width,
          height: candidate.height,
        );
      }
    }

    var quality = jpegStartQuality;
    Uint8List jpgBytes = Uint8List.fromList(
      img.encodeJpg(candidate, quality: quality),
    );
    while (jpgBytes.length > request.maxBytes &&
        quality > request.minJpegQuality) {
      quality = (quality - request.qualityStep).clamp(
        request.minJpegQuality,
        jpegStartQuality,
      );
      jpgBytes = Uint8List.fromList(
        img.encodeJpg(candidate, quality: quality),
      );
    }
    return ProcessedAvatar(
      bytes: jpgBytes,
      mimeType: 'image/jpeg',
      width: candidate.width,
      height: candidate.height,
    );
  }

  var candidate = resized;
  var encoded = encode(candidate);
  var targetSize = request.targetSize;
  final minimumSize = min(minDownscale, targetSize);

  while (encoded.bytes.length > request.maxBytes && targetSize > minimumSize) {
    final nextSize = max(
      minimumSize,
      (targetSize * downscaleFactor).round(),
    );
    if (nextSize >= targetSize) break;
    targetSize = nextSize;
    candidate = img.copyResize(
      cropped,
      width: targetSize,
      height: targetSize,
      interpolation: img.Interpolation.cubic,
    );
    encoded = encode(candidate);
  }

  return encoded;
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
