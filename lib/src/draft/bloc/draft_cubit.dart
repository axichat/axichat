import 'dart:async';

import 'package:axichat/src/common/bloc_cache.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'draft_state.dart';

class DraftCubit extends Cubit<DraftState> with BlocCache<DraftState> {
  DraftCubit({
    required MessageService messageService,
    EmailService? emailService,
  })  : _messageService = messageService,
        _emailService = emailService,
        super(const DraftsAvailable(items: null)) {
    _draftsSubscription = _messageService
        .draftsStream()
        .listen((items) => emit(DraftsAvailable(items: items)));
  }

  final MessageService _messageService;
  final EmailService? _emailService;

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
    MessageTransport transport = MessageTransport.xmpp,
  }) async {
    emit(DraftSending());
    try {
      if (transport == MessageTransport.email) {
        final emailService = _emailService;
        if (emailService == null) {
          throw StateError('EmailService unavailable for email draft send.');
        }
        for (final address in jids) {
          await emailService.sendToAddress(
            address: address,
            body: body,
            displayName: address.split('@').first,
          );
        }
      } else {
        for (final jid in jids) {
          await _messageService.sendMessage(jid: jid, text: body);
        }
      }
    } on XmppMessageException catch (_) {
      emit(const DraftFailure(
          'Failed to send message. Ensure recipient address exists.'));
      return;
    } on Exception catch (_) {
      emit(const DraftFailure(
          'Failed to send email. Ensure recipient address exists.'));
      return;
    }
    if (id != null) {
      await deleteDraft(id: id);
    }
    emit(DraftSendComplete());
  }

  Future<int> saveDraft({
    required int? id,
    required List<String> jids,
    required String body,
  }) async {
    final savedID =
        await _messageService.saveDraft(id: id, jids: jids, body: body);
    emit(DraftSaveComplete());
    return savedID;
  }

  Future<void> deleteDraft({required int id}) async {
    await _messageService.deleteDraft(id: id);
  }
}
