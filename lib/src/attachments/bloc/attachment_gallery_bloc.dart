// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'attachment_gallery_bloc.freezed.dart';
part 'attachment_gallery_event.dart';
part 'attachment_gallery_state.dart';

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

enum AttachmentGallerySortOption {
  newestFirst,
  oldestFirst,
  nameAscending,
  nameDescending,
  sizeAscending,
  sizeDescending;

  int compare(AttachmentGalleryItem a, AttachmentGalleryItem b) {
    const fallbackEpochMs = 0;
    const sortBefore = -1;
    const sortAfter = 1;
    final fallbackTimestamp = DateTime.fromMillisecondsSinceEpoch(
      fallbackEpochMs,
    );
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
      AttachmentGallerySortOption.newestFirst => compareByTimestamp(
        descending: true,
      ),
      AttachmentGallerySortOption.oldestFirst => compareByTimestamp(
        descending: false,
      ),
      AttachmentGallerySortOption.nameAscending => compareByName(
        descending: false,
      ),
      AttachmentGallerySortOption.nameDescending => compareByName(
        descending: true,
      ),
      AttachmentGallerySortOption.sizeAscending => compareBySize(
        descending: false,
      ),
      AttachmentGallerySortOption.sizeDescending => compareBySize(
        descending: true,
      ),
    };
  }
}

enum AttachmentGalleryTypeFilter {
  all,
  images,
  videos,
  files;

  bool matches(FileMetadataData metadata) {
    return switch (this) {
      AttachmentGalleryTypeFilter.all => true,
      AttachmentGalleryTypeFilter.images => metadata.isImage,
      AttachmentGalleryTypeFilter.videos => metadata.isVideo,
      AttachmentGalleryTypeFilter.files =>
        metadata.mediaKind == FileMetadataMediaKind.file,
    };
  }
}

enum AttachmentGallerySourceFilter {
  all,
  sent,
  received;

  bool matches({required bool isSelf}) {
    return switch (this) {
      AttachmentGallerySourceFilter.all => true,
      AttachmentGallerySourceFilter.sent => isSelf,
      AttachmentGallerySourceFilter.received => !isSelf,
    };
  }
}

enum AttachmentGalleryLayout { grid, list }

class AttachmentGalleryBloc
    extends Bloc<AttachmentGalleryEvent, AttachmentGalleryState> {
  AttachmentGalleryBloc({
    required XmppService xmppService,
    EmailService? emailService,
    String? chatJid,
    Chat? chatOverride,
    required bool showChatLabel,
  }) : _xmppService = xmppService,
       _emailService = emailService,
       _chatOverride = chatOverride,
       _showChatLabel = showChatLabel,
       super(const AttachmentGalleryState(status: RequestStatus.loading)) {
    on<AttachmentGalleryItemsUpdated>(_onItemsUpdated);
    on<AttachmentGalleryLoadFailed>(_onLoadFailed);
    on<AttachmentGalleryQueryChanged>(_onQueryChanged);
    on<AttachmentGallerySortChanged>(_onSortChanged);
    on<AttachmentGalleryTypeFilterChanged>(_onTypeFilterChanged);
    on<AttachmentGallerySourceFilterChanged>(_onSourceFilterChanged);
    on<AttachmentGalleryLayoutChanged>(_onLayoutChanged);
    on<AttachmentGalleryApprovalGranted>(_onApprovalGranted);
    on<AttachmentGalleryEmailDownloadRequested>(_onEmailDownloadRequested);
    on<AttachmentGalleryEmailServiceUpdated>(_onEmailServiceUpdated);
    on<AttachmentGalleryFileMetadataBatchUpdated>(_onFileMetadataBatchUpdated);
    _itemsSubscription = _xmppService
        .attachmentGalleryStream(chatJid: chatJid)
        .listen(
          (items) => add(AttachmentGalleryItemsUpdated(items: items)),
          onError: (Object error, StackTrace stackTrace) =>
              add(AttachmentGalleryLoadFailed(error: error.toString())),
        );
  }

  final XmppService _xmppService;
  EmailService? _emailService;
  final Chat? _chatOverride;
  final bool _showChatLabel;
  StreamSubscription<List<AttachmentGalleryItem>>? _itemsSubscription;
  StreamSubscription<Map<String, FileMetadataData?>>? _fileMetadataSubscription;
  Set<String> _trackedFileMetadataIds = const <String>{};
  var _fileMetadataRetryAttempts = 0;
  var _fileMetadataSubscriptionCancelling = false;

  Future<bool> downloadInboundAttachment({
    required String metadataId,
    required String stanzaId,
  }) async {
    final downloadedPath = await _xmppService.downloadInboundAttachment(
      metadataId: metadataId,
      stanzaId: stanzaId,
    );
    return downloadedPath?.trim().isNotEmpty == true;
  }

  Future<FileMetadataData?> reloadFileMetadata(String metadataId) async {
    return _xmppService.loadFileMetadata(metadataId);
  }

  bool _isSelfMessage(Message message) {
    if (sameNormalizedAddressValue(message.senderJid, _xmppService.myJid)) {
      return true;
    }
    return sameNormalizedAddressValue(
      message.senderJid,
      _emailService?.selfSenderJid,
    );
  }

  Future<bool> downloadEmailMessage(Message message) async {
    final service = _emailService;
    if (service == null) return false;
    await service.downloadFullMessage(message);
    return true;
  }

  Future<void> _onItemsUpdated(
    AttachmentGalleryItemsUpdated event,
    Emitter<AttachmentGalleryState> emit,
  ) async {
    await _syncFileMetadataSubscriptions(event.items);
    final nextMetadataById = _pruneFileMetadataById(
      items: event.items,
      existing: state.fileMetadataById,
    );
    emit(
      state.copyWith(
        status: RequestStatus.success,
        items: event.items,
        entries: _resolveEntries(
          items: event.items,
          query: state.query,
          sortOption: state.sortOption,
          typeFilter: state.typeFilter,
          sourceFilter: state.sourceFilter,
          allowedOnceStanzaIds: state.allowedOnceStanzaIds,
        ),
        fileMetadataById: nextMetadataById,
        error: null,
      ),
    );
  }

  void _onLoadFailed(
    AttachmentGalleryLoadFailed event,
    Emitter<AttachmentGalleryState> emit,
  ) {
    emit(state.copyWith(status: RequestStatus.failure, error: event.error));
  }

  void _onFileMetadataBatchUpdated(
    AttachmentGalleryFileMetadataBatchUpdated event,
    Emitter<AttachmentGalleryState> emit,
  ) {
    _fileMetadataRetryAttempts = 0;
    final nextMetadataById = _pruneFileMetadataById(
      items: state.items,
      existing: event.metadataById,
    );
    if (nextMetadataById.length == state.fileMetadataById.length &&
        nextMetadataById.entries.every(
          (entry) => state.fileMetadataById[entry.key] == entry.value,
        )) {
      return;
    }
    emit(state.copyWith(fileMetadataById: nextMetadataById));
  }

  void _onQueryChanged(
    AttachmentGalleryQueryChanged event,
    Emitter<AttachmentGalleryState> emit,
  ) {
    final normalizedQuery = event.query.trim().toLowerCase();
    emit(
      state.copyWith(
        query: normalizedQuery,
        entries: _resolveEntries(
          items: state.items,
          query: normalizedQuery,
          sortOption: state.sortOption,
          typeFilter: state.typeFilter,
          sourceFilter: state.sourceFilter,
          allowedOnceStanzaIds: state.allowedOnceStanzaIds,
        ),
      ),
    );
  }

  void _onSortChanged(
    AttachmentGallerySortChanged event,
    Emitter<AttachmentGalleryState> emit,
  ) {
    emit(
      state.copyWith(
        sortOption: event.sortOption,
        entries: _resolveEntries(
          items: state.items,
          query: state.query,
          sortOption: event.sortOption,
          typeFilter: state.typeFilter,
          sourceFilter: state.sourceFilter,
          allowedOnceStanzaIds: state.allowedOnceStanzaIds,
        ),
      ),
    );
  }

  void _onTypeFilterChanged(
    AttachmentGalleryTypeFilterChanged event,
    Emitter<AttachmentGalleryState> emit,
  ) {
    emit(
      state.copyWith(
        typeFilter: event.typeFilter,
        entries: _resolveEntries(
          items: state.items,
          query: state.query,
          sortOption: state.sortOption,
          typeFilter: event.typeFilter,
          sourceFilter: state.sourceFilter,
          allowedOnceStanzaIds: state.allowedOnceStanzaIds,
        ),
      ),
    );
  }

  void _onSourceFilterChanged(
    AttachmentGallerySourceFilterChanged event,
    Emitter<AttachmentGalleryState> emit,
  ) {
    emit(
      state.copyWith(
        sourceFilter: event.sourceFilter,
        entries: _resolveEntries(
          items: state.items,
          query: state.query,
          sortOption: state.sortOption,
          typeFilter: state.typeFilter,
          sourceFilter: event.sourceFilter,
          allowedOnceStanzaIds: state.allowedOnceStanzaIds,
        ),
      ),
    );
  }

  void _onLayoutChanged(
    AttachmentGalleryLayoutChanged event,
    Emitter<AttachmentGalleryState> emit,
  ) {
    emit(state.copyWith(layoutOverride: event.layout));
  }

  Future<void> _onApprovalGranted(
    AttachmentGalleryApprovalGranted event,
    Emitter<AttachmentGalleryState> emit,
  ) async {
    final normalizedStanzaId = _normalizeStanzaId(event.stanzaId);
    final nextAllowedOnce = normalizedStanzaId.isEmpty
        ? state.allowedOnceStanzaIds
        : <String>{...state.allowedOnceStanzaIds, normalizedStanzaId};
    emit(
      state.copyWith(
        allowedOnceStanzaIds: nextAllowedOnce,
        entries: _resolveEntries(
          items: state.items,
          query: state.query,
          sortOption: state.sortOption,
          typeFilter: state.typeFilter,
          sourceFilter: state.sourceFilter,
          allowedOnceStanzaIds: nextAllowedOnce,
        ),
      ),
    );
    if (event.alwaysAllow && event.chat != null) {
      await _xmppService.toggleChatAttachmentAutoDownload(
        jid: event.chat!.jid,
        enabled: true,
      );
    }
    if (event.isEmailChat) {
      await downloadEmailMessage(event.message);
    }
  }

  Future<void> _onEmailDownloadRequested(
    AttachmentGalleryEmailDownloadRequested event,
    Emitter<AttachmentGalleryState> emit,
  ) async {
    if (event.completer.isCompleted) return;
    try {
      final downloaded = await downloadEmailMessage(event.message);
      if (event.completer.isCompleted) return;
      event.completer.complete(downloaded);
    } catch (error, stackTrace) {
      if (event.completer.isCompleted) return;
      event.completer.completeError(error, stackTrace);
    }
  }

  void _onEmailServiceUpdated(
    AttachmentGalleryEmailServiceUpdated event,
    Emitter<AttachmentGalleryState> emit,
  ) {
    final emailService = event.emailService;
    if (identical(_emailService, emailService)) {
      return;
    }
    _emailService = emailService;
    emit(
      state.copyWith(
        entries: _resolveEntries(
          items: state.items,
          query: state.query,
          sortOption: state.sortOption,
          typeFilter: state.typeFilter,
          sourceFilter: state.sourceFilter,
          allowedOnceStanzaIds: state.allowedOnceStanzaIds,
        ),
      ),
    );
  }

  List<AttachmentGalleryEntryData> _resolveEntries({
    required List<AttachmentGalleryItem> items,
    required String query,
    required AttachmentGallerySortOption sortOption,
    required AttachmentGalleryTypeFilter typeFilter,
    required AttachmentGallerySourceFilter sourceFilter,
    required Set<String> allowedOnceStanzaIds,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final filtered = <AttachmentGalleryEntryData>[];
    for (final item in items) {
      if (!typeFilter.matches(item.metadata)) {
        continue;
      }
      final isSelf = _isSelfMessage(item.message);
      if (!sourceFilter.matches(isSelf: isSelf)) {
        continue;
      }
      final chat = _chatOverride ?? item.chat;
      if (normalizedQuery.isNotEmpty) {
        if (!item.metadata.normalizedFilename.contains(normalizedQuery)) {
          if (!_showChatLabel) {
            continue;
          }
          final chatLabel = chat?.displayName.trim().toLowerCase() ?? '';
          if (chatLabel.isEmpty || !chatLabel.contains(normalizedQuery)) {
            continue;
          }
        }
      }
      final defaultAutoDownload =
          _xmppService.defaultChatAttachmentAutoDownload;
      filtered.add(
        AttachmentGalleryEntryData(
          item: item,
          chat: chat,
          isSelf: isSelf,
          allowOnce: allowedOnceStanzaIds.contains(
            _normalizeStanzaId(item.message.stanzaID),
          ),
          allowByTrust:
              isSelf ||
              (chat?.attachmentAutoDownload ?? defaultAutoDownload).isAllowed,
        ),
      );
    }
    filtered.sort((a, b) => sortOption.compare(a.item, b.item));
    return List.unmodifiable(filtered);
  }

  String _metadataIdForItem(AttachmentGalleryItem item) {
    return item.metadata.id.trim();
  }

  Map<String, FileMetadataData?> _pruneFileMetadataById({
    required List<AttachmentGalleryItem> items,
    required Map<String, FileMetadataData?> existing,
  }) {
    if (items.isEmpty) {
      return const <String, FileMetadataData?>{};
    }
    final nextMetadataById = <String, FileMetadataData?>{};
    for (final item in items) {
      final metadataId = _metadataIdForItem(item);
      if (metadataId.isEmpty) {
        continue;
      }
      nextMetadataById[metadataId] = existing.containsKey(metadataId)
          ? existing[metadataId]
          : item.metadata;
    }
    return nextMetadataById;
  }

  Future<void> _syncFileMetadataSubscriptions(
    List<AttachmentGalleryItem> items,
  ) async {
    final requiredIds = <String>{
      for (final item in items)
        if (_metadataIdForItem(item).isNotEmpty) _metadataIdForItem(item),
    };
    final sameIds =
        requiredIds.length == _trackedFileMetadataIds.length &&
        requiredIds.containsAll(_trackedFileMetadataIds);
    if (sameIds && _fileMetadataSubscription != null) {
      return;
    }
    if (!sameIds) {
      _fileMetadataRetryAttempts = 0;
    }
    _trackedFileMetadataIds = requiredIds;
    final previous = _fileMetadataSubscription;
    _fileMetadataSubscription = null;
    if (previous != null) {
      _fileMetadataSubscriptionCancelling = true;
      try {
        await previous.cancel();
      } finally {
        _fileMetadataSubscriptionCancelling = false;
      }
    }
    if (requiredIds.isEmpty) {
      return;
    }
    _fileMetadataSubscription = _xmppService
        .fileMetadataByIdsStream(requiredIds)
        .listen(
          (metadataById) => add(
            AttachmentGalleryFileMetadataBatchUpdated(
              metadataById: metadataById,
            ),
          ),
          onError: (Object error, StackTrace stackTrace) {
            _fileMetadataSubscription = null;
            _retryFileMetadataSubscription();
          },
          onDone: () {
            _fileMetadataSubscription = null;
            _retryFileMetadataSubscription();
          },
        );
  }

  void _retryFileMetadataSubscription() {
    if (_fileMetadataSubscriptionCancelling ||
        _trackedFileMetadataIds.isEmpty) {
      return;
    }
    if (_fileMetadataRetryAttempts >= 3) {
      return;
    }
    _fileMetadataRetryAttempts += 1;
    unawaited(_syncFileMetadataSubscriptions(state.items));
  }

  String _normalizeStanzaId(String stanzaId) => stanzaId.trim();

  @override
  Future<void> close() async {
    await _itemsSubscription?.cancel();
    final metadataSubscription = _fileMetadataSubscription;
    _fileMetadataSubscription = null;
    _trackedFileMetadataIds = const <String>{};
    _fileMetadataRetryAttempts = 0;
    _fileMetadataSubscriptionCancelling = true;
    try {
      await metadataSubscription?.cancel();
    } finally {
      _fileMetadataSubscriptionCancelling = false;
    }
    return super.close();
  }
}
