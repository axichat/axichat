// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:path/path.dart' as p;
import 'package:axichat/src/storage/models.dart';

class Attachment {
  const Attachment({
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

  Attachment copyWith({
    String? path,
    String? fileName,
    int? sizeBytes,
    String? mimeType,
    int? width,
    int? height,
    String? caption,
    String? metadataId,
  }) => Attachment(
    path: path ?? this.path,
    fileName: fileName ?? this.fileName,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    mimeType: mimeType ?? this.mimeType,
    width: width ?? this.width,
    height: height ?? this.height,
    caption: caption ?? this.caption,
    metadataId: metadataId ?? this.metadataId,
  );

  static const Set<String> _imageExtensions = <String>{
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

enum FileMetadataMediaKind { image, video, file }

enum FileMetadataDownloadCategory { image, video, document, archive }

extension FileMetadataDownloadCategoryTools on FileMetadataDownloadCategory {
  bool isAutoDownloadAllowed({
    required bool imagesEnabled,
    required bool videosEnabled,
    required bool documentsEnabled,
    required bool archivesEnabled,
  }) {
    return switch (this) {
      FileMetadataDownloadCategory.image => imagesEnabled,
      FileMetadataDownloadCategory.video => videosEnabled,
      FileMetadataDownloadCategory.document => documentsEnabled,
      FileMetadataDownloadCategory.archive => archivesEnabled,
    };
  }
}

extension FileMetadataTools on FileMetadataData {
  bool get isImage {
    const imageExtensions = <String>[
      '.png',
      '.jpg',
      '.jpeg',
      '.gif',
      '.webp',
      '.bmp',
      '.heic',
    ];
    final mime = mimeType?.toLowerCase();
    if (mime?.startsWith('image/') ?? false) return true;
    final name = filename.toLowerCase();
    return imageExtensions.any(name.endsWith);
  }

  bool get isVideo {
    const videoExtensions = <String>[
      '.mp4',
      '.mov',
      '.m4v',
      '.webm',
      '.mkv',
      '.avi',
      '.mpeg',
      '.mpg',
      '.3gp',
      '.3gpp',
    ];
    final mime = mimeType?.toLowerCase();
    if (mime?.startsWith('video/') ?? false) return true;
    final name = filename.toLowerCase();
    return videoExtensions.any(name.endsWith);
  }

  bool get isArchive {
    const archiveExtensions = <String>[
      '.zip',
      '.rar',
      '.7z',
      '.tar',
      '.gz',
      '.tgz',
      '.bz2',
      '.xz',
      '.jar',
    ];
    const archiveMimeTypes = <String>{
      'application/zip',
      'application/x-zip-compressed',
      'application/vnd.rar',
      'application/x-rar-compressed',
      'application/x-7z-compressed',
      'application/x-tar',
      'application/gzip',
      'application/x-gzip',
      'application/x-bzip2',
      'application/x-xz',
      'application/java-archive',
    };
    final mime = mimeType?.toLowerCase();
    if (mime != null && archiveMimeTypes.contains(mime)) {
      return true;
    }
    final name = filename.toLowerCase();
    return archiveExtensions.any(name.endsWith);
  }

  FileMetadataMediaKind get mediaKind {
    if (isImage) return FileMetadataMediaKind.image;
    if (isVideo) return FileMetadataMediaKind.video;
    return FileMetadataMediaKind.file;
  }

  FileMetadataDownloadCategory get downloadCategory {
    if (isImage) return FileMetadataDownloadCategory.image;
    if (isVideo) return FileMetadataDownloadCategory.video;
    if (isArchive) return FileMetadataDownloadCategory.archive;
    return FileMetadataDownloadCategory.document;
  }

  String get normalizedFilename => filename.trim().toLowerCase();
}

String deltaFileMetadataId(int messageId) => 'dc-file-$messageId';
