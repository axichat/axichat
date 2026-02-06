// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/attachments/bloc/attachment_gallery_bloc.dart';
import 'package:axichat/src/localization/app_localizations.dart';

extension AttachmentGallerySortLocalization on AttachmentGallerySortOption {
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
}

extension AttachmentGalleryTypeFilterLocalization
    on AttachmentGalleryTypeFilter {
  String label(AppLocalizations l10n) {
    return switch (this) {
      AttachmentGalleryTypeFilter.all => l10n.attachmentGalleryAllLabel,
      AttachmentGalleryTypeFilter.images => l10n.attachmentGalleryImagesLabel,
      AttachmentGalleryTypeFilter.videos => l10n.attachmentGalleryVideosLabel,
      AttachmentGalleryTypeFilter.files => l10n.attachmentGalleryFilesLabel,
    };
  }
}

extension AttachmentGallerySourceFilterLocalization
    on AttachmentGallerySourceFilter {
  String label(AppLocalizations l10n) {
    return switch (this) {
      AttachmentGallerySourceFilter.all => l10n.attachmentGalleryAllLabel,
      AttachmentGallerySourceFilter.sent => l10n.attachmentGallerySentLabel,
      AttachmentGallerySourceFilter.received =>
        l10n.attachmentGalleryReceivedLabel,
    };
  }
}
