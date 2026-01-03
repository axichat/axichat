// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:path/path.dart' as p;

class EmailAttachment {
  const EmailAttachment({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    this.mimeType,
    this.width,
    this.height,
    this.caption,
    this.metadataId,
  });

  final String path;
  final String fileName;
  final int sizeBytes;
  final String? mimeType;
  final int? width;
  final int? height;
  final String? caption;
  final String? metadataId;

  EmailAttachment copyWith({
    String? path,
    String? fileName,
    int? sizeBytes,
    String? mimeType,
    int? width,
    int? height,
    String? caption,
    String? metadataId,
  }) =>
      EmailAttachment(
        path: path ?? this.path,
        fileName: fileName ?? this.fileName,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        mimeType: mimeType ?? this.mimeType,
        width: width ?? this.width,
        height: height ?? this.height,
        caption: caption ?? this.caption,
        metadataId: metadataId ?? this.metadataId,
      );

  static const _imageExtensions = <String>{
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.bmp',
    '.tif',
    '.tiff',
    '.heic',
    '.heif',
    '.avif',
    '.gif',
  };

  bool get isImage {
    final normalizedMimeType = mimeType?.toLowerCase();
    if (normalizedMimeType != null) {
      return normalizedMimeType.startsWith('image/');
    }
    final extension = p.extension(fileName).isNotEmpty
        ? p.extension(fileName).toLowerCase()
        : p.extension(path).toLowerCase();
    return _imageExtensions.contains(extension);
  }

  bool get isGif {
    final normalizedMimeType = mimeType?.toLowerCase();
    if (normalizedMimeType != null) {
      return normalizedMimeType == 'image/gif';
    }
    final extension = p.extension(fileName).isNotEmpty
        ? p.extension(fileName).toLowerCase()
        : p.extension(path).toLowerCase();
    return extension == '.gif';
  }

  bool get isVideo =>
      mimeType != null && mimeType!.toLowerCase().startsWith('video/');

  bool get isAudio =>
      mimeType != null && mimeType!.toLowerCase().startsWith('audio/');
}
