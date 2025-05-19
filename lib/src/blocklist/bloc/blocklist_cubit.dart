import 'dart:async';

import 'package:axichat/src/common/bloc_cache.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'blocklist_state.dart';

class BlocklistCubit extends Cubit<BlocklistState>
    with BlocCache<BlocklistState> {
  BlocklistCubit({required BlockingService blockingService})
      : _blockingService = blockingService,
        super(const BlocklistAvailable(items: null)) {
    _blocklistSubscription = _blockingService
        .blocklistStream()
        .listen((items) => emit(BlocklistAvailable(items: items)));
  }

  final BlockingService _blockingService;

  late final StreamSubscription<List<BlocklistData>> _blocklistSubscription;

  @override
  void onChange(Change<BlocklistState> change) {
    super.onChange(change);
    final current = change.currentState;
    if (current is BlocklistAvailable) {
      cache['items'] = current.items;
    }
  }

  @override
  Future<void> close() async {
    await _blocklistSubscription.cancel();
    return super.close();
  }

  void block({required String jid}) async {
    if (!jid.isValidJid) {
      emit(const BlocklistFailure('Enter a valid jid'));
      return;
    }
    emit(BlocklistLoading(jid: jid));
    try {
      await _blockingService.block(jid: jid);
    } on XmppBlockUnsupportedException catch (_) {
      emit(const BlocklistFailure('Server does not support blocking.'));
      return;
    } on XmppBlocklistException catch (_) {
      emit(BlocklistFailure('Failed to block $jid. ' 'Try again later.'));
      return;
    }

    emit(BlocklistSuccess('Blocked $jid'));
  }

  void unblock({required String jid}) async {
    emit(BlocklistLoading(jid: jid));
    try {
      await _blockingService.unblock(jid: jid);
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
      await _blockingService.unblockAll();
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
