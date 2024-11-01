import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:chat/src/common/bloc_cache.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/storage/models.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:equatable/equatable.dart';

part 'roster_state.dart';

class RosterCubit extends Cubit<RosterState> with BlocCache<RosterState> {
  RosterCubit({required XmppService xmppService})
      : _xmppService = xmppService,
        super(const RosterInitial()) {
    _rosterSubscription = _xmppService
        .rosterStream()
        .listen((items) => emit(RosterAvailable(items: items)));
    _invitesSubscription = _xmppService
        .invitesStream()
        .listen((invites) => emit(RosterInvitesAvailable(invites: invites)));
  }

  final XmppService _xmppService;

  late final StreamSubscription<List<RosterItem>> _rosterSubscription;
  late final StreamSubscription<List<Invite>> _invitesSubscription;

  int get inviteCount => cache['invites']?.length ?? 0;
  var contacts = <String>{};

  @override
  void onChange(Change<RosterState> change) {
    super.onChange(change);
    final current = change.currentState;
    final next = change.nextState;
    if (current is RosterAvailable) {
      cache['items'] = current.items;
      contacts = current.items.map((e) => e.jid).toSet();
    }
    if (next is RosterAvailable) {
      cache['items'] = next.items;
      contacts = next.items.map((e) => e.jid).toSet();
    }
    if (current is RosterInvitesAvailable) {
      cache['invites'] = current.invites;
    }
    if (next is RosterInvitesAvailable) {
      cache['invites'] = next.invites;
    }
  }

  @override
  Future<void> close() async {
    await _rosterSubscription.cancel();
    await _invitesSubscription.cancel();
    return super.close();
  }

  Future<void> addContact({
    required String jid,
    String? title,
  }) async {
    if (!jid.isValidJid) {
      emit(const RosterFailure('Enter a valid jid'));
      return;
    }
    emit(RosterLoading(jid: jid));
    try {
      await _xmppService.addToRoster(jid: jid, title: title);
    } on XmppRosterException catch (_) {
      emit(
        const RosterFailure('Failed to add contact: '
            'make sure the address exists or try again later.'),
      );
      return;
    }
    emit(RosterSuccess('$jid added to contacts.'));
  }

  Future<void> removeContact({required String jid}) async {
    emit(RosterLoading(jid: jid));
    try {
      await _xmppService.removeFromRoster(jid: jid);
    } on XmppRosterException catch (_) {
      emit(
        const RosterFailure(
          'Failed to remove contact: check your network or try again later.',
        ),
      );
      return;
    }
    emit(RosterSuccess('$jid removed from contacts.'));
  }

  Future<void> rejectContact({required String jid}) async {
    emit(RosterLoading(jid: jid));
    try {
      await _xmppService.rejectSubscriptionRequest(jid);
    } on XmppRosterException catch (_) {
      emit(
        const RosterFailure(
          'Failed to reject contact: check your network or try again later.',
        ),
      );
      return;
    }
    emit(RosterSuccess('$jid rejected.'));
  }
}
