// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'attachment_gallery_bloc.dart';

@freezed
class AttachmentGalleryState with _$AttachmentGalleryState {
  const factory AttachmentGalleryState({
    @Default(RequestStatus.none) RequestStatus status,
    @Default(<AttachmentGalleryItem>[]) List<AttachmentGalleryItem> items,
    @Default(<AttachmentGalleryEntryData>[])
    List<AttachmentGalleryEntryData> entries,
    @Default('') String query,
    @Default(AttachmentGallerySortOption.newestFirst)
    AttachmentGallerySortOption sortOption,
    @Default(AttachmentGalleryTypeFilter.all)
    AttachmentGalleryTypeFilter typeFilter,
    @Default(AttachmentGallerySourceFilter.all)
    AttachmentGallerySourceFilter sourceFilter,
    AttachmentGalleryLayout? layoutOverride,
    @Default(<String>{}) Set<String> allowedOnceStanzaIds,
    String? error,
  }) = _AttachmentGalleryState;
}

@freezed
class AttachmentGalleryEntryData with _$AttachmentGalleryEntryData {
  const factory AttachmentGalleryEntryData({
    required AttachmentGalleryItem item,
    required Chat? chat,
    required bool isSelf,
    required bool allowOnce,
    required bool allowByTrust,
  }) = _AttachmentGalleryEntryData;
}
