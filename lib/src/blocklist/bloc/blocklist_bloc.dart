import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:chat/src/storage/database.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:equatable/equatable.dart';

part 'blocklist_event.dart';
part 'blocklist_state.dart';

class BlocklistBloc extends Bloc<BlocklistEvent, BlocklistState> {
  BlocklistBloc({required XmppService xmppService})
      : _xmppService = xmppService,
        super(const BlocklistInitial(items: [])) {
    on<_BlocklistUpdated>(_onBlocklistUpdated);
    on<BlocklistBlocked>(_onBlocklistBlocked);
    on<BlocklistUnblocked>(_onBlocklistUnblocked);
    on<BlocklistAllUnblocked>(_onBlocklistAllUnblocked);
    _blocklistSubscription = _xmppService.blocklistStream
        ?.listen((items) => add(_BlocklistUpdated(items: items)));
  }

  final XmppService _xmppService;

  late final StreamSubscription<List<BlocklistData>>? _blocklistSubscription;

  @override
  Future<void> close() {
    _blocklistSubscription?.cancel();
    return super.close();
  }

  void _onBlocklistUpdated(
    _BlocklistUpdated event,
    Emitter<BlocklistState> emit,
  ) {
    emit(BlocklistAvailable(items: event.items));
  }

  void _onBlocklistBlocked(
    BlocklistBlocked event,
    Emitter<BlocklistState> emit,
  ) async {
    emit(BlocklistLoading(
      jid: event.jid,
      items: state.items,
    ));
    try {
      await _xmppService.block(jid: event.jid);
      await _xmppService.removeFromRoster(jid: event.jid);
    } on XmppBlockUnsupportedException catch (_) {
      emit(BlocklistFailure(
        'Server does not support blocking.',
        items: state.items,
      ));
      return;
    } on XmppBlocklistException catch (_) {
      emit(BlocklistFailure(
        'Failed to block ${event.jid}. ' 'Try again later.',
        items: state.items,
      ));
      return;
    } on XmppRosterException catch (_) {
      emit(BlocklistFailure(
        'Blocked ${event.jid}. Remove them from your roster.',
        items: state.items,
      ));
      return;
    }
    emit(BlocklistSuccess('Blocked ${event.jid}', items: state.items));
  }

  void _onBlocklistUnblocked(
    BlocklistUnblocked event,
    Emitter<BlocklistState> emit,
  ) async {
    emit(BlocklistLoading(
      jid: event.jid,
      items: state.items,
    ));
    try {
      await _xmppService.unblock(jid: event.jid);
    } on XmppBlockUnsupportedException catch (_) {
      emit(BlocklistFailure(
        'Server does not support unblocking.',
        items: state.items,
      ));
      return;
    } on XmppBlocklistException catch (_) {
      emit(BlocklistFailure(
        'Failed to unblock ${event.jid}. ' 'Try again later.',
        items: state.items,
      ));
      return;
    }
    emit(BlocklistSuccess('Unblocked ${event.jid}', items: state.items));
  }

  void _onBlocklistAllUnblocked(
    BlocklistAllUnblocked event,
    Emitter<BlocklistState> emit,
  ) async {
    emit(BlocklistLoading(
      jid: null,
      items: state.items,
    ));
    try {
      await _xmppService.unblockAll();
    } on XmppBlockUnsupportedException catch (_) {
      emit(BlocklistFailure(
        'Server does not support unblocking.',
        items: state.items,
      ));
      return;
    } on XmppBlocklistException catch (_) {
      emit(BlocklistFailure(
        'Failed to unblock users. Try again later.',
        items: state.items,
      ));
      return;
    }
    emit(BlocklistSuccess('Unblocked all.', items: state.items));
  }
}
