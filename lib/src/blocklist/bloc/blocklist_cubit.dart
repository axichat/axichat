import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:chat/src/common/bloc_cache.dart';
import 'package:chat/src/storage/database.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:equatable/equatable.dart';

part 'blocklist_state.dart';

class BlocklistCubit extends Cubit<BlocklistState>
    with BlocCache<BlocklistState> {
  BlocklistCubit({required XmppService xmppService})
      : _xmppService = xmppService,
        super(const BlocklistAvailable(items: [])) {
    _blocklistSubscription = _xmppService
        .blocklistStream()
        .listen((items) => emit(BlocklistAvailable(items: items)));
  }

  final XmppService _xmppService;

  late final StreamSubscription<List<BlocklistData>>? _blocklistSubscription;

  @override
  void onChange(Change<BlocklistState> change) {
    super.onChange(change);
    final current = change.currentState;
    if (current is BlocklistAvailable) {
      cache['items'] = current.items;
    }
  }

  @override
  Future<void> close() {
    _blocklistSubscription?.cancel();
    return super.close();
  }

  void block({required String jid}) async {
    emit(BlocklistLoading(jid: jid));
    try {
      await _xmppService.block(jid: jid);
      await _xmppService.removeFromRoster(jid: jid);
    } on XmppBlockUnsupportedException catch (_) {
      emit(const BlocklistFailure('Server does not support blocking.'));
      return;
    } on XmppBlocklistException catch (_) {
      emit(BlocklistFailure('Failed to block $jid. ' 'Try again later.'));
      return;
    } on XmppRosterException catch (_) {
      emit(BlocklistFailure('Blocked $jid. Remove them from your roster.'));
      return;
    }
    emit(BlocklistSuccess('Blocked $jid'));
  }

  void unblock({required String jid}) async {
    emit(BlocklistLoading(jid: jid));
    try {
      await _xmppService.unblock(jid: jid);
    } on XmppBlockUnsupportedException catch (_) {
      emit(const BlocklistFailure('Server does not support unblocking.'));
      return;
    } on XmppBlocklistException catch (_) {
      emit(BlocklistFailure('Failed to unblock $jid. ' 'Try again later.'));
      return;
    }
    emit(BlocklistSuccess('Unblocked $jid'));
  }

  void unblockAll() async {
    emit(const BlocklistLoading(jid: null));
    try {
      await _xmppService.unblockAll();
    } on XmppBlockUnsupportedException catch (_) {
      emit(const BlocklistFailure('Server does not support unblocking.'));
      return;
    } on XmppBlocklistException catch (_) {
      emit(const BlocklistFailure('Failed to unblock users. Try again later.'));
      return;
    }
    emit(const BlocklistSuccess('Unblocked all.'));
  }
}
