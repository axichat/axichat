import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:chat/src/storage/models.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:equatable/equatable.dart';

part 'roster_event.dart';
part 'roster_state.dart';

class RosterBloc extends Bloc<RosterEvent, RosterState> {
  RosterBloc({required XmppService xmppService})
      : _xmppService = xmppService,
        super(const RosterInitial(items: [], invites: [])) {
    on<_RosterUpdated>(_onRosterUpdated);
    on<_RosterInvitesUpdated>(_onRosterInvitesUpdated);
    on<RosterSubscriptionAdded>(_onRosterSubscriptionAdded);
    on<RosterSubscriptionRemoved>(_onRosterSubscriptionRemoved);
    on<RosterSubscriptionRejected>(_onRosterSubscriptionRejected);
    _rosterSubscription = _xmppService.rosterStream
        ?.listen((items) => add(_RosterUpdated(items)));
    _invitesSubscription = _xmppService.invitesStream
        ?.listen((invites) => add(_RosterInvitesUpdated(invites)));
  }

  final XmppService _xmppService;

  late final StreamSubscription<List<RosterItem>>? _rosterSubscription;
  late final StreamSubscription<List<Invite>>? _invitesSubscription;

  @override
  Future<void> close() {
    _rosterSubscription?.cancel();
    _invitesSubscription?.cancel();
    return super.close();
  }

  void _onRosterUpdated(_RosterUpdated event, Emitter<RosterState> emit) {
    emit(RosterAvailable(items: event.items, invites: state.invites));
  }

  void _onRosterInvitesUpdated(
    _RosterInvitesUpdated event,
    Emitter<RosterState> emit,
  ) {
    emit(RosterInvitesAvailable(items: state.items, invites: event.invites));
  }

  void _onRosterSubscriptionAdded(
    RosterSubscriptionAdded event,
    Emitter<RosterState> emit,
  ) async {
    emit(RosterLoading(
      jid: event.jid,
      items: state.items,
      invites: state.invites,
    ));
    try {
      await _xmppService.addToRoster(jid: event.jid, title: event.title);
    } on XmppRosterException catch (_) {
      emit(RosterFailure(
        'Failed to add contact: '
        'make sure the address exists or try again later.',
        items: state.items,
        invites: state.invites,
      ));
      return;
    }
    emit(RosterSuccess(
      '${event.jid} added to contacts.',
      items: state.items,
      invites: state.invites,
    ));
  }

  void _onRosterSubscriptionRemoved(
    RosterSubscriptionRemoved event,
    Emitter<RosterState> emit,
  ) async {
    emit(RosterLoading(
      jid: event.jid,
      items: state.items,
      invites: state.invites,
    ));
    try {
      await _xmppService.removeFromRoster(jid: event.jid);
    } on XmppRosterException catch (_) {
      emit(RosterFailure(
        'Failed to remove contact: check your network or try again later.',
        items: state.items,
        invites: state.invites,
      ));
      return;
    }
    emit(RosterSuccess(
      '${event.jid} removed from contacts.',
      items: state.items,
      invites: state.invites,
    ));
  }

  void _onRosterSubscriptionRejected(
    RosterSubscriptionRejected event,
    Emitter<RosterState> emit,
  ) async {
    emit(RosterLoading(
      jid: event.item.jid,
      items: state.items,
      invites: state.invites,
    ));
    try {
      await _xmppService.rejectSubscriptionRequest(event.item);
    } on XmppRosterException catch (_) {
      emit(RosterFailure(
        'Failed to reject contact: check your network or try again later.',
        items: state.items,
        invites: state.invites,
      ));
      return;
    }
    emit(RosterSuccess(
      '${event.item.jid} rejected.',
      items: state.items,
      invites: state.invites,
    ));
  }
}
