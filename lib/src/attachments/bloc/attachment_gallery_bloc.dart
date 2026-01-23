// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/attachments/attachment_gallery_models.dart';
import 'package:axichat/src/storage/attachment_gallery_repository.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'attachment_gallery_bloc.freezed.dart';
part 'attachment_gallery_event.dart';
part 'attachment_gallery_state.dart';

class AttachmentGalleryBloc
    extends Bloc<AttachmentGalleryEvent, AttachmentGalleryState> {
  AttachmentGalleryBloc({
    required XmppService xmppService,
    EmailService? emailService,
    String? chatJid,
    Chat? chatOverride,
    required bool showChatLabel,
  })  : _xmppService = xmppService,
        _emailService = emailService,
        _chatOverride = chatOverride,
        _showChatLabel = showChatLabel,
        super(const AttachmentGalleryState()) {
    on<AttachmentGalleryItemsUpdated>(_onItemsUpdated);
    on<AttachmentGalleryLoadFailed>(_onLoadFailed);
    on<AttachmentGalleryChatsUpdated>(_onChatsUpdated);
    on<AttachmentGalleryQueryChanged>(_onQueryChanged);
    on<AttachmentGallerySortChanged>(_onSortChanged);
    on<AttachmentGalleryTypeFilterChanged>(_onTypeFilterChanged);
    on<AttachmentGallerySourceFilterChanged>(_onSourceFilterChanged);
    on<AttachmentGalleryLayoutChanged>(_onLayoutChanged);
    on<AttachmentGalleryApprovalGranted>(_onApprovalGranted);
    on<AttachmentGalleryEmailDownloadRequested>(_onEmailDownloadRequested);
    emit(state.copyWith(status: RequestStatus.loading));
    _itemsSubscription =
        _xmppService.attachmentGalleryStream(chatJid: chatJid).listen(
              (items) => add(AttachmentGalleryItemsUpdated(items: items)),
              onError: (Object error, StackTrace stackTrace) => add(
                AttachmentGalleryLoadFailed(
                  error: error.toString(),
                ),
              ),
            );
  }

  final XmppService _xmppService;
  final EmailService? _emailService;
  final Chat? _chatOverride;
  final bool _showChatLabel;
  StreamSubscription<List<AttachmentGalleryItem>>? _itemsSubscription;
  List<Chat> _chats = const <Chat>[];

  Stream<FileMetadataData?> fileMetadataStream(String id) =>
      _xmppService.fileMetadataStream(id);

  bool _isSelfMessage(Message message) {
    final sender = message.senderJid.trim().toLowerCase();
    final xmppJid = _xmppService.myJid?.trim().toLowerCase();
    if (xmppJid != null && sender == xmppJid) return true;
    final emailJid = _emailService?.selfSenderJid?.trim().toLowerCase();
    if (emailJid != null && sender == emailJid) return true;
    return false;
  }

  Future<bool> downloadEmailMessage(Message message) async {
    final service = _emailService;
    if (service == null) return false;
    await service.downloadFullMessage(message);
    return true;
  }

  void _onItemsUpdated(
    AttachmentGalleryItemsUpdated event,
    Emitter<AttachmentGalleryState> emit,
  ) {
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
        error: null,
      ),
    );
  }

  void _onLoadFailed(
    AttachmentGalleryLoadFailed event,
    Emitter<AttachmentGalleryState> emit,
  ) {
    emit(
      state.copyWith(
        status: RequestStatus.failure,
        error: event.error,
      ),
    );
  }

  void _onChatsUpdated(
    AttachmentGalleryChatsUpdated event,
    Emitter<AttachmentGalleryState> emit,
  ) {
    _chats = event.items;
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
    final trimmedStanzaId = event.stanzaId.trim();
    final nextAllowedOnce = trimmedStanzaId.isEmpty
        ? state.allowedOnceStanzaIds
        : <String>{...state.allowedOnceStanzaIds, trimmedStanzaId};
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
    event.completer.complete(await downloadEmailMessage(event.message));
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
    final chatLookup = _showChatLabel || normalizedQuery.isNotEmpty
        ? <String, Chat>{for (final chat in _chats) chat.jid: chat}
        : const <String, Chat>{};
    final filtered = <AttachmentGalleryEntryData>[];
    for (final item in items) {
      if (!typeFilter.matches(item.metadata)) {
        continue;
      }
      final isSelf = _isSelfMessage(item.message);
      if (!sourceFilter.matches(isSelf: isSelf)) {
        continue;
      }
      final chat = _chatOverride ?? chatLookup[item.message.chatJid];
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
      filtered.add(
        AttachmentGalleryEntryData(
          item: item,
          chat: chat,
          isSelf: isSelf,
          allowOnce: allowedOnceStanzaIds.contains(item.message.stanzaID),
          allowByTrust:
              isSelf || (chat?.attachmentAutoDownload.isAllowed ?? false),
        ),
      );
    }
    filtered.sort(
      (a, b) => sortOption.compare(a.item, b.item),
    );
    return List.unmodifiable(filtered);
  }

  @override
  Future<void> close() async {
    await _itemsSubscription?.cancel();
    return super.close();
  }
}
