// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/attachments/attachment_metadata_extensions.dart';
import 'package:axichat/src/storage/models.dart';

class AttachmentAutoDownloadSettings {
  const AttachmentAutoDownloadSettings({
    this.imagesEnabled = _defaultImagesEnabled,
    this.videosEnabled = _defaultVideosEnabled,
    this.documentsEnabled = _defaultDocumentsEnabled,
    this.archivesEnabled = _defaultArchivesEnabled,
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
      imagesEnabled: images is bool ? images : _defaultImagesEnabled,
      videosEnabled: videos is bool ? videos : _defaultVideosEnabled,
      documentsEnabled:
          documents is bool ? documents : _defaultDocumentsEnabled,
      archivesEnabled:
          archives is bool ? archives : _defaultArchivesEnabled,
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

  static const bool _defaultImagesEnabled = true;
  static const bool _defaultVideosEnabled = false;
  static const bool _defaultDocumentsEnabled = false;
  static const bool _defaultArchivesEnabled = false;

  static const String _autoDownloadImagesKey = 'images';
  static const String _autoDownloadVideosKey = 'videos';
  static const String _autoDownloadDocumentsKey = 'documents';
  static const String _autoDownloadArchivesKey = 'archives';
}
