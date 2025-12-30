import 'dart:async';

import 'package:axichat/src/attachments/attachment_gallery_repository.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/storage/database.dart';
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
    this.chatJid,
  })  : _xmppService = xmppService,
        super(const AttachmentGalleryState()) {
    unawaited(_subscribe());
  }

  final XmppService _xmppService;
  final String? chatJid;
  StreamSubscription<List<AttachmentGalleryItem>>? _subscription;

  Future<void> _subscribe() async {
    emit(state.copyWith(status: RequestStatus.loading));
    final db = await _xmppService.database;
    if (db is! XmppDrift) {
      emit(
        state.copyWith(
          status: RequestStatus.failure,
          error: null,
        ),
      );
      return;
    }
    final repository = AttachmentGalleryRepository(db);
    await _subscription?.cancel();
    _subscription = repository.watch(chatJid: chatJid).listen(
          _handleItems,
          onError: _handleError,
        );
  }

  void _handleItems(List<AttachmentGalleryItem> items) {
    emit(
      state.copyWith(
        status: RequestStatus.success,
        items: items,
        error: null,
      ),
    );
  }

  void _handleError(Object error, StackTrace stackTrace) {
    emit(
      state.copyWith(
        status: RequestStatus.failure,
        error: error.toString(),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
