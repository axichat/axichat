import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:axichat/src/common/bloc_cache.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:equatable/equatable.dart';

part 'draft_state.dart';

class DraftCubit extends Cubit<DraftState> with BlocCache<DraftState> {
  DraftCubit({required MessageService messageService})
      : _messageService = messageService,
        super(const DraftsAvailable(items: [])) {
    _draftsSubscription = _messageService
        .draftsStream()
        .listen((items) => emit(DraftsAvailable(items: items)));
  }

  final MessageService _messageService;

  late final StreamSubscription<List<Draft>> _draftsSubscription;

  @override
  void onChange(Change<DraftState> change) {
    super.onChange(change);
    final current = change.currentState;
    if (current is DraftsAvailable) {
      cache['items'] = current.items;
    }
  }

  @override
  Future<void> close() async {
    await _draftsSubscription.cancel();
    return super.close();
  }

  Future<void> sendDraft({
    required int? id,
    required List<String> jids,
    required String body,
  }) async {
    emit(DraftSending());
    try {
      for (final jid in jids) {
        await _messageService.sendMessage(jid: jid, text: body);
      }
    } on XmppMessageException catch (_) {
      emit(const DraftFailure(
          'Failed to send message. Ensure recipient address exists.'));
      return;
    }
    if (id != null) {
      await deleteDraft(id: id);
    }
    emit(DraftSendComplete());
  }

  Future<void> saveDraft({
    required int? id,
    required List<String> jids,
    required String body,
  }) async {
    await _messageService.saveDraft(id: id, jids: jids, body: body);
    emit(DraftSaveComplete());
  }

  Future<void> deleteDraft({required int id}) async {
    await _messageService.deleteDraft(id: id);
  }
}
