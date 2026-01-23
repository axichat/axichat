// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/storage/attachment_gallery_repository.dart';
import 'package:axichat/src/attachments/attachment_metadata_extensions.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/storage/models.dart';

enum AttachmentGallerySortOption {
  newestFirst,
  oldestFirst,
  nameAscending,
  nameDescending,
  sizeAscending,
  sizeDescending,
  ;

  String label(AppLocalizations l10n) {
    return switch (this) {
      AttachmentGallerySortOption.newestFirst => l10n.chatSearchSortNewestFirst,
      AttachmentGallerySortOption.oldestFirst => l10n.chatSearchSortOldestFirst,
      AttachmentGallerySortOption.nameAscending =>
        l10n.attachmentGallerySortNameAscLabel,
      AttachmentGallerySortOption.nameDescending =>
        l10n.attachmentGallerySortNameDescLabel,
      AttachmentGallerySortOption.sizeAscending =>
        l10n.attachmentGallerySortSizeAscLabel,
      AttachmentGallerySortOption.sizeDescending =>
        l10n.attachmentGallerySortSizeDescLabel,
    };
  }

  int compare(AttachmentGalleryItem a, AttachmentGalleryItem b) {
    const fallbackEpochMs = 0;
    const sortBefore = -1;
    const sortAfter = 1;
    final fallbackTimestamp =
        DateTime.fromMillisecondsSinceEpoch(fallbackEpochMs);
    int compareByTimestamp({required bool descending}) {
      final aTimestamp = a.message.timestamp ?? fallbackTimestamp;
      final bTimestamp = b.message.timestamp ?? fallbackTimestamp;
      final result = aTimestamp.compareTo(bTimestamp);
      if (result == 0) return 0;
      return descending ? -result : result;
    }

    int compareByName({required bool descending}) {
      final result = a.metadata.normalizedFilename.compareTo(
        b.metadata.normalizedFilename,
      );
      if (result != 0) {
        return descending ? -result : result;
      }
      return compareByTimestamp(descending: true);
    }

    int compareBySize({required bool descending}) {
      final aSize = a.metadata.sizeBytes;
      final bSize = b.metadata.sizeBytes;
      if (aSize == null && bSize == null) {
        return compareByTimestamp(descending: true);
      }
      if (aSize == null) return sortAfter;
      if (bSize == null) return sortBefore;
      final result = aSize.compareTo(bSize);
      if (result != 0) {
        return descending ? -result : result;
      }
      return compareByTimestamp(descending: true);
    }

    return switch (this) {
      AttachmentGallerySortOption.newestFirst =>
        compareByTimestamp(descending: true),
      AttachmentGallerySortOption.oldestFirst =>
        compareByTimestamp(descending: false),
      AttachmentGallerySortOption.nameAscending =>
        compareByName(descending: false),
      AttachmentGallerySortOption.nameDescending =>
        compareByName(descending: true),
      AttachmentGallerySortOption.sizeAscending =>
        compareBySize(descending: false),
      AttachmentGallerySortOption.sizeDescending =>
        compareBySize(descending: true),
    };
  }
}

enum AttachmentGalleryTypeFilter {
  all,
  images,
  videos,
  files,
  ;

  String label(AppLocalizations l10n) {
    return switch (this) {
      AttachmentGalleryTypeFilter.all => l10n.attachmentGalleryAllLabel,
      AttachmentGalleryTypeFilter.images => l10n.attachmentGalleryImagesLabel,
      AttachmentGalleryTypeFilter.videos => l10n.attachmentGalleryVideosLabel,
      AttachmentGalleryTypeFilter.files => l10n.attachmentGalleryFilesLabel,
    };
  }

  bool matches(FileMetadataData metadata) {
    return switch (this) {
      AttachmentGalleryTypeFilter.all => true,
      AttachmentGalleryTypeFilter.images => metadata.isImage,
      AttachmentGalleryTypeFilter.videos => metadata.isVideo,
      AttachmentGalleryTypeFilter.files =>
        metadata.mediaKind == AttachmentMediaKind.file,
    };
  }
}

enum AttachmentGallerySourceFilter {
  all,
  sent,
  received,
  ;

  String label(AppLocalizations l10n) {
    return switch (this) {
      AttachmentGallerySourceFilter.all => l10n.attachmentGalleryAllLabel,
      AttachmentGallerySourceFilter.sent => l10n.attachmentGallerySentLabel,
      AttachmentGallerySourceFilter.received =>
        l10n.attachmentGalleryReceivedLabel,
    };
  }

  bool matches({required bool isSelf}) {
    return switch (this) {
      AttachmentGallerySourceFilter.all => true,
      AttachmentGallerySourceFilter.sent => isSelf,
      AttachmentGallerySourceFilter.received => !isSelf,
    };
  }
}

enum AttachmentGalleryLayout { grid, list }
