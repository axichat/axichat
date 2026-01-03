// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/attachments/attachment_metadata_extensions.dart';
import 'package:axichat/src/storage/models.dart';

const bool defaultAutoDownloadImages = true;
const bool defaultAutoDownloadVideos = false;
const bool defaultAutoDownloadDocuments = false;
const bool defaultAutoDownloadArchives = false;

const String _autoDownloadImagesKey = 'images';
const String _autoDownloadVideosKey = 'videos';
const String _autoDownloadDocumentsKey = 'documents';
const String _autoDownloadArchivesKey = 'archives';

class AttachmentAutoDownloadSettings {
  const AttachmentAutoDownloadSettings({
    this.imagesEnabled = defaultAutoDownloadImages,
    this.videosEnabled = defaultAutoDownloadVideos,
    this.documentsEnabled = defaultAutoDownloadDocuments,
    this.archivesEnabled = defaultAutoDownloadArchives,
  });

  factory AttachmentAutoDownloadSettings.fromJson(Object? raw) {
    if (raw is! Map) {
      return const AttachmentAutoDownloadSettings();
    }
    final images = raw[_autoDownloadImagesKey];
    final videos = raw[_autoDownloadVideosKey];
    final documents = raw[_autoDownloadDocumentsKey];
    final archives = raw[_autoDownloadArchivesKey];
    return AttachmentAutoDownloadSettings(
      imagesEnabled: images is bool ? images : defaultAutoDownloadImages,
      videosEnabled: videos is bool ? videos : defaultAutoDownloadVideos,
      documentsEnabled:
          documents is bool ? documents : defaultAutoDownloadDocuments,
      archivesEnabled:
          archives is bool ? archives : defaultAutoDownloadArchives,
    );
  }

  final bool imagesEnabled;
  final bool videosEnabled;
  final bool documentsEnabled;
  final bool archivesEnabled;

  Map<String, Object?> toJson() => <String, Object?>{
        _autoDownloadImagesKey: imagesEnabled,
        _autoDownloadVideosKey: videosEnabled,
        _autoDownloadDocumentsKey: documentsEnabled,
        _autoDownloadArchivesKey: archivesEnabled,
      };

  bool allowsCategory(AttachmentDownloadCategory category) {
    return switch (category) {
      AttachmentDownloadCategory.image => imagesEnabled,
      AttachmentDownloadCategory.video => videosEnabled,
      AttachmentDownloadCategory.document => documentsEnabled,
      AttachmentDownloadCategory.archive => archivesEnabled,
    };
  }

  bool allowsMetadata(FileMetadataData metadata) =>
      allowsCategory(metadata.downloadCategory);
}
