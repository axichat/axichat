import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:chat/src/storage/models.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:equatable/equatable.dart';

part 'roster_state.dart';

class RosterCubit extends Cubit<RosterState> {
  RosterCubit({required XmppService xmppService})
      : _xmppService = xmppService,
        super(const RosterInitial()) {
    _rosterSubscription = _xmppService.rosterStream
        ?.listen((items) => emit(RosterAvailable(items: items)));
    _invitesSubscription = _xmppService.invitesStream
        ?.listen((invites) => emit(RosterInvitesAvailable(invites: invites)));
  }

  final XmppService _xmppService;

  late final StreamSubscription<List<RosterItem>>? _rosterSubscription;
  late final StreamSubscription<List<Invite>>? _invitesSubscription;

  int get inviteCount => state is RosterInvitesAvailable
      ? (state as RosterInvitesAvailable).invites.length
      : 0;

  @override
  Future<void> close() {
    _rosterSubscription?.cancel();
    _invitesSubscription?.cancel();
    return super.close();
  }

  void addContact({
    required String jid,
    String? title,
  }) async {
    emit(RosterLoading(jid: jid));
    try {
      await _xmppService.addToRoster(jid: jid, title: title);
    } on XmppRosterException catch (_) {
      emit(const RosterFailure('Failed to add contact: '
          'make sure the address exists or try again later.'));
      return;
    }
    emit(RosterSuccess('$jid added to contacts.'));
  }

  void removeContact({required String jid}) async {
    emit(RosterLoading(jid: jid));
    try {
      await _xmppService.removeFromRoster(jid: jid);
    } on XmppRosterException catch (_) {
      emit(const RosterFailure(
          'Failed to remove contact: check your network or try again later.'));
      return;
    }
    emit(RosterSuccess('$jid removed from contacts.'));
  }

  void rejectContact({required String jid}) async {
    emit(RosterLoading(jid: jid));
    try {
      await _xmppService.rejectSubscriptionRequest(jid);
    } on XmppRosterException catch (_) {
      emit(const RosterFailure(
          'Failed to reject contact: check your network or try again later.'));
      return;
    }
    emit(RosterSuccess('$jid rejected.'));
  }
}
