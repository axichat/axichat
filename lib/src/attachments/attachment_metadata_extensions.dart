// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/storage/models.dart';

enum AttachmentMediaKind { image, video, file }

enum AttachmentDownloadCategory { image, video, document, archive }

extension AttachmentMetadataKind on FileMetadataData {
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

  AttachmentMediaKind get mediaKind {
    if (isImage) return AttachmentMediaKind.image;
    if (isVideo) return AttachmentMediaKind.video;
    return AttachmentMediaKind.file;
  }

  AttachmentDownloadCategory get downloadCategory {
    if (isImage) return AttachmentDownloadCategory.image;
    if (isVideo) return AttachmentDownloadCategory.video;
    if (isArchive) return AttachmentDownloadCategory.archive;
    return AttachmentDownloadCategory.document;
  }

  String get normalizedFilename => filename.trim().toLowerCase();
}
