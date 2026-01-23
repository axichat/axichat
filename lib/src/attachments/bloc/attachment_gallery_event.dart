// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'attachment_gallery_bloc.dart';

@freezed
class AttachmentGalleryEvent with _$AttachmentGalleryEvent {
  const factory AttachmentGalleryEvent.itemsUpdated({
    required List<AttachmentGalleryItem> items,
  }) = AttachmentGalleryItemsUpdated;

  const factory AttachmentGalleryEvent.loadFailed({
    required String error,
  }) = AttachmentGalleryLoadFailed;

  const factory AttachmentGalleryEvent.chatsUpdated({
    required List<Chat> items,
  }) = AttachmentGalleryChatsUpdated;

  const factory AttachmentGalleryEvent.queryChanged({
    required String query,
  }) = AttachmentGalleryQueryChanged;

  const factory AttachmentGalleryEvent.sortChanged({
    required AttachmentGallerySortOption sortOption,
  }) = AttachmentGallerySortChanged;

  const factory AttachmentGalleryEvent.typeFilterChanged({
    required AttachmentGalleryTypeFilter typeFilter,
  }) = AttachmentGalleryTypeFilterChanged;

  const factory AttachmentGalleryEvent.sourceFilterChanged({
    required AttachmentGallerySourceFilter sourceFilter,
  }) = AttachmentGallerySourceFilterChanged;

  const factory AttachmentGalleryEvent.layoutChanged({
    required AttachmentGalleryLayout? layout,
  }) = AttachmentGalleryLayoutChanged;

  const factory AttachmentGalleryEvent.approvalGranted({
    required Message message,
    required Chat? chat,
    required bool alwaysAllow,
    required bool isEmailChat,
    required String stanzaId,
  }) = AttachmentGalleryApprovalGranted;

  const factory AttachmentGalleryEvent.emailDownloadRequested({
    required Message message,
    required Completer<bool> completer,
  }) = AttachmentGalleryEmailDownloadRequested;
}
