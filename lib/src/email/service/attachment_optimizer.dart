// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class EmailAttachmentOptimizer {
  const EmailAttachmentOptimizer._();

  static const _maxDimension = 2048;
  static const _jpegQuality = 82;
  static const _pngCompressionLevel = 6;
  static const _optimizedDirectoryName = 'email_attachments';
  static const _optimizedFilePrefix = 'attachment_';
  static const _jpegExtension = '.jpg';
  static const _pngExtension = '.png';
  static const _jpegMimeType = 'image/jpeg';
  static const _pngMimeType = 'image/png';

  static const _requestPathKey = 'path';
  static const _requestFileNameKey = 'fileName';
  static const _requestMimeTypeKey = 'mimeType';
  static const _requestTempDirKey = 'tempDirPath';

  static const _resultShouldReplaceKey = 'shouldReplace';
  static const _resultPathKey = 'path';
  static const _resultFileNameKey = 'fileName';
  static const _resultMimeTypeKey = 'mimeType';
  static const _resultSizeBytesKey = 'sizeBytes';
  static const _resultWidthKey = 'width';
  static const _resultHeightKey = 'height';

  static Future<EmailAttachment> optimize(EmailAttachment attachment) async {
    if (!attachment.isImage || attachment.isGif) {
      return attachment;
    }
    final file = File(attachment.path);
    if (!await file.exists()) {
      return attachment;
    }
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final Map<String, Object?> request = <String, Object?>{}
        ..[_requestPathKey] = attachment.path
        ..[_requestFileNameKey] = attachment.fileName
        ..[_requestMimeTypeKey] = attachment.mimeType
        ..[_requestTempDirKey] = tempDir.path;
      final Map<String, Object?>? result = kIsWeb
          ? _optimizeAttachmentInIsolate(request)
          : await compute(_optimizeAttachmentInIsolate, request);
      final bool shouldReplace =
          result?[_resultShouldReplaceKey] as bool? ?? false;
      if (!shouldReplace) {
        return attachment;
      }
      final String optimizedPath = result?[_resultPathKey] as String? ?? '';
      if (optimizedPath.isEmpty) {
        return attachment;
      }
      final String optimizedFileName =
          result?[_resultFileNameKey] as String? ?? attachment.fileName;
      final String optimizedMimeType = result?[_resultMimeTypeKey] as String? ??
          attachment.mimeType ??
          _pngMimeType;
      final int optimizedSizeBytes =
          result?[_resultSizeBytesKey] as int? ?? attachment.sizeBytes;
      final int? width = result?[_resultWidthKey] as int?;
      final int? height = result?[_resultHeightKey] as int?;
      return attachment.copyWith(
        path: optimizedPath,
        fileName: optimizedFileName,
        mimeType: optimizedMimeType,
        sizeBytes: optimizedSizeBytes,
        width: width,
        height: height,
      );
    } on Exception {
      return attachment;
    }
  }
}

Map<String, Object?> _optimizeAttachmentInIsolate(
  Map<String, Object?> request,
) {
  final String path =
      request[EmailAttachmentOptimizer._requestPathKey] as String? ?? '';
  if (path.isEmpty) {
    return const <String, Object?>{
      EmailAttachmentOptimizer._resultShouldReplaceKey: false,
    };
  }
  final String fileName =
      request[EmailAttachmentOptimizer._requestFileNameKey] as String? ?? '';
  final String? declaredMimeType =
      request[EmailAttachmentOptimizer._requestMimeTypeKey] as String?;
  final String tempDirPath =
      request[EmailAttachmentOptimizer._requestTempDirKey] as String? ?? '';
  if (tempDirPath.isEmpty) {
    return const <String, Object?>{
      EmailAttachmentOptimizer._resultShouldReplaceKey: false,
    };
  }
  final File file = File(path);
  if (!file.existsSync()) {
    return const <String, Object?>{
      EmailAttachmentOptimizer._resultShouldReplaceKey: false,
    };
  }
  final Uint8List bytes = file.readAsBytesSync();
  final img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return const <String, Object?>{
      EmailAttachmentOptimizer._resultShouldReplaceKey: false,
    };
  }
  final img.Image oriented = img.bakeOrientation(decoded);
  final img.Image resized = _resizeIfNeeded(oriented);
  final bool encodeAsJpeg = !resized.hasAlpha;
  final List<int> encodedBytes = encodeAsJpeg
      ? img.encodeJpg(resized, quality: EmailAttachmentOptimizer._jpegQuality)
      : img.encodePng(
          resized,
          level: EmailAttachmentOptimizer._pngCompressionLevel,
        );
  if (encodedBytes.length >= bytes.length) {
    return const <String, Object?>{
      EmailAttachmentOptimizer._resultShouldReplaceKey: false,
    };
  }
  final String extension = encodeAsJpeg
      ? EmailAttachmentOptimizer._jpegExtension
      : _resolveOptimizedExtension(fileName);
  final String sanitizedName = encodeAsJpeg
      ? _resolveJpegFileName(fileName)
      : _resolvePngFileName(fileName);
  final Directory directory = Directory(
    p.join(
      tempDirPath,
      EmailAttachmentOptimizer._optimizedDirectoryName,
    ),
  );
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
  final String optimizedFileName =
      '${EmailAttachmentOptimizer._optimizedFilePrefix}'
      '${DateTime.now().microsecondsSinceEpoch}$extension';
  final File optimizedFile = File(
    p.join(directory.path, optimizedFileName),
  );
  optimizedFile.writeAsBytesSync(encodedBytes, flush: true);
  final String mimeType = encodeAsJpeg
      ? EmailAttachmentOptimizer._jpegMimeType
      : _resolvePngMimeType(declaredMimeType);
  return <String, Object?>{
    EmailAttachmentOptimizer._resultShouldReplaceKey: true,
    EmailAttachmentOptimizer._resultPathKey: optimizedFile.path,
    EmailAttachmentOptimizer._resultFileNameKey: sanitizedName.isNotEmpty
        ? sanitizedName
        : p.basename(optimizedFile.path),
    EmailAttachmentOptimizer._resultMimeTypeKey: mimeType,
    EmailAttachmentOptimizer._resultSizeBytesKey: encodedBytes.length,
    EmailAttachmentOptimizer._resultWidthKey: resized.width,
    EmailAttachmentOptimizer._resultHeightKey: resized.height,
  };
}

img.Image _resizeIfNeeded(img.Image image) {
  final int maxSide = image.width > image.height ? image.width : image.height;
  if (maxSide <= EmailAttachmentOptimizer._maxDimension) {
    return image;
  }
  return img.copyResize(
    image,
    width: image.width >= image.height
        ? EmailAttachmentOptimizer._maxDimension
        : null,
    height: image.height > image.width
        ? EmailAttachmentOptimizer._maxDimension
        : null,
    interpolation: img.Interpolation.cubic,
  );
}

String _resolveOptimizedExtension(String fileName) {
  final String extension = p.extension(fileName);
  if (extension.isNotEmpty) {
    return extension;
  }
  return EmailAttachmentOptimizer._pngExtension;
}

String _resolveJpegFileName(String fileName) {
  final String baseName = p.basenameWithoutExtension(fileName);
  if (baseName.isEmpty) {
    return '${EmailAttachmentOptimizer._optimizedFilePrefix}'
        '${DateTime.now().microsecondsSinceEpoch}'
        '${EmailAttachmentOptimizer._jpegExtension}';
  }
  return '$baseName${EmailAttachmentOptimizer._jpegExtension}';
}

String _resolvePngFileName(String fileName) {
  if (fileName.isNotEmpty) {
    return fileName;
  }
  return '${EmailAttachmentOptimizer._optimizedFilePrefix}'
      '${DateTime.now().microsecondsSinceEpoch}'
      '${EmailAttachmentOptimizer._pngExtension}';
}

String _resolvePngMimeType(String? declaredMimeType) {
  final String? trimmed = declaredMimeType?.trim();
  if (trimmed != null && trimmed.isNotEmpty) {
    return trimmed;
  }
  return EmailAttachmentOptimizer._pngMimeType;
}
