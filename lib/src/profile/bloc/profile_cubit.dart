import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:chat/src/storage/models.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_cubit.freezed.dart';
part 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({required XmppService xmppService})
      : _xmppService = xmppService,
        super(ProfileState(
          jid: xmppService.user!.jid.toString(),
          resource: xmppService.resource,
          title: xmppService.user!.username,
          presence: xmppService.presence,
          status: xmppService.status,
        )) {
    _presenceSubscription = _xmppService.presenceStream.listen(
      (presence) => emit(state.copyWith(presence: presence)),
    );
    _statusSubscription = _xmppService.statusStream.listen(
      (status) => emit(state.copyWith(status: status)),
    );
  }

  final XmppService _xmppService;

  late final StreamSubscription<Presence>? _presenceSubscription;
  late final StreamSubscription<String?>? _statusSubscription;

  @override
  Future<void> close() {
    _presenceSubscription?.cancel();
    _statusSubscription?.cancel();
    return super.close();
  }

  void updatePresence({Presence? presence, String? status}) async {
    try {
      await _xmppService.sendPresence(
        presence: presence ?? state.presence,
        status: status ?? state.status,
      );
    } on XmppPresenceException catch (_) {}
  }
}
