// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/storage/attachment_gallery_repository.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

class AttachmentGalleryState extends Equatable {
  const AttachmentGalleryState({
    this.status = RequestStatus.none,
    this.items = const <AttachmentGalleryItem>[],
    this.error,
  });

  final RequestStatus status;
  final List<AttachmentGalleryItem> items;
  final String? error;

  AttachmentGalleryState copyWith({
    RequestStatus? status,
    List<AttachmentGalleryItem>? items,
    String? error,
  }) {
    return AttachmentGalleryState(
      status: status ?? this.status,
      items: items ?? this.items,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, items, error];
}

class AttachmentGalleryCubit extends Cubit<AttachmentGalleryState> {
  AttachmentGalleryCubit({
    required XmppService xmppService,
    EmailService? emailService,
    this.chatJid,
  })  : _xmppService = xmppService,
        _emailService = emailService,
        super(const AttachmentGalleryState()) {
    emit(state.copyWith(status: RequestStatus.loading));
    _subscription = _xmppService
        .attachmentGalleryStream(chatJid: chatJid)
        .listen(_handleItems, onError: _handleError);
  }

  final XmppService _xmppService;
  final EmailService? _emailService;
  final String? chatJid;
  StreamSubscription<List<AttachmentGalleryItem>>? _subscription;

  Stream<FileMetadataData?> fileMetadataStream(String id) =>
      _xmppService.fileMetadataStream(id);

  bool isSelfMessage(Message message) {
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

  void _handleItems(List<AttachmentGalleryItem> items) {
    emit(
      state.copyWith(status: RequestStatus.success, items: items, error: null),
    );
  }

  void _handleError(Object error, StackTrace stackTrace) {
    emit(
      state.copyWith(status: RequestStatus.failure, error: error.toString()),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
