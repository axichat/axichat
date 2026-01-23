// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/storage/models.dart';

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
