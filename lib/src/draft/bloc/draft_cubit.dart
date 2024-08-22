import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:chat/src/common/bloc_cache.dart';
import 'package:chat/src/storage/database.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:equatable/equatable.dart';

part 'draft_state.dart';

class DraftCubit extends Cubit<DraftState> with BlocCache<DraftState> {
  DraftCubit({required XmppService xmppService})
      : _xmppService = xmppService,
        super(const DraftsAvailable(items: [])) {
    _draftsSubscription = _xmppService
        .draftsStream()
        .listen((items) => emit(DraftsAvailable(items: items)));
  }

  final XmppService _xmppService;

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
        await _xmppService.sendMessage(jid: jid, text: body);
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
    await _xmppService.saveDraft(id: id, jids: jids, body: body);
    emit(DraftSaveComplete());
  }

  Future<void> deleteDraft({required int id}) async {
    await _xmppService.deleteDraft(id: id);
  }
}
