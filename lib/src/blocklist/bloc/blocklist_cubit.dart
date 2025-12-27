import 'dart:async';

import 'package:axichat/src/blocklist/models/blocklist_entry.dart';
import 'package:axichat/src/common/bloc_cache.dart';
import 'package:axichat/src/common/email_validation.dart';
import 'package:axichat/src/common/jid_transport.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'blocklist_state.dart';

const String blocklistItemsCacheKey = 'items';
const String _invalidJidMessage = 'Enter a valid jid';
const String _blockingUnsupportedMessage = 'Server does not support blocking.';
const String _unblockingUnsupportedMessage =
    'Server does not support unblocking.';
const String _unblockAllFailedMessage =
    'Failed to unblock users. Try again later.';
const String _unblockAllSuccessMessage = 'Unblocked all.';

String _blockFailedMessage(String address) =>
    'Failed to block $address. Try again later.';

String _unblockFailedMessage(String address) =>
    'Failed to unblock $address. Try again later.';

String _blockedMessage(String address) => 'Blocked $address';

String _unblockedMessage(String address) => 'Unblocked $address';

class BlocklistCubit extends Cubit<BlocklistState>
    with BlocCache<BlocklistState> {
  BlocklistCubit({required XmppService xmppService})
      : _xmppService = xmppService,
        super(const BlocklistAvailable(items: null)) {
    _xmppBlocklistSubscription =
        _xmppService.blocklistStream().listen(_handleXmppBlocklist);
    _emailBlocklistSubscription =
        _xmppService.emailBlocklistStream().listen(_handleEmailBlocklist);
  }

  final XmppService _xmppService;
  List<BlocklistData>? _xmppBlocklist;
  List<EmailBlocklistEntry>? _emailBlocklist;

  late final StreamSubscription<List<BlocklistData>> _xmppBlocklistSubscription;
  late final StreamSubscription<List<EmailBlocklistEntry>>
      _emailBlocklistSubscription;

  @override
  void onChange(Change<BlocklistState> change) {
    super.onChange(change);
    final current = change.currentState;
    if (current is BlocklistAvailable) {
      cache[blocklistItemsCacheKey] = current.items;
    }
  }

  @override
  Future<void> close() async {
    await _xmppBlocklistSubscription.cancel();
    await _emailBlocklistSubscription.cancel();
    return super.close();
  }

  Future<void> block({
    required String address,
    MessageTransport? transport,
    SpamReportReason? reportReason,
  }) async {
    final normalized = address.trim();
    if (normalized.isEmpty) {
      emit(const BlocklistFailure(_invalidJidMessage));
      return;
    }
    final resolvedTransport = transport ?? normalized.inferredTransport;
    emit(BlocklistLoading(jid: normalized));
    if (resolvedTransport.isEmail) {
      if (!normalized.isValidEmailAddress) {
        emit(const BlocklistFailure(_invalidJidMessage));
        return;
      }
      try {
        await _xmppService.setEmailBlockStatus(
          address: normalized,
          blocked: true,
        );
      } on Exception {
        emit(BlocklistFailure(_blockFailedMessage(normalized)));
        return;
      }
      emit(BlocklistSuccess(_blockedMessage(normalized)));
      return;
    }
    if (!normalized.isValidJid) {
      emit(const BlocklistFailure(_invalidJidMessage));
      return;
    }
    try {
      await _blockXmpp(
        address: normalized,
        reportReason: reportReason,
      );
    } on XmppBlockUnsupportedException catch (_) {
      emit(const BlocklistFailure(_blockingUnsupportedMessage));
      return;
    } on XmppBlocklistException catch (_) {
      emit(BlocklistFailure(_blockFailedMessage(normalized)));
      return;
    }
    emit(BlocklistSuccess(_blockedMessage(normalized)));
  }

  Future<void> _blockXmpp({
    required String address,
    SpamReportReason? reportReason,
  }) async {
    if (reportReason == null) {
      await _xmppService.block(jid: address);
      return;
    }
    try {
      await _xmppService.blockAndReport(
        jid: address,
        reason: reportReason,
      );
    } on XmppSpamReportUnsupportedException catch (_) {
      await _xmppService.block(jid: address);
    } on XmppSpamReportException catch (_) {
      await _xmppService.block(jid: address);
    }
  }

  Future<void> unblock({required BlocklistEntry entry}) async {
    final normalized = entry.address.trim();
    if (normalized.isEmpty) {
      return;
    }
    emit(BlocklistLoading(jid: normalized));
    if (entry.transport.isEmail) {
      try {
        await _xmppService.setEmailBlockStatus(
          address: normalized,
          blocked: false,
        );
      } on Exception {
        emit(BlocklistFailure(_unblockFailedMessage(normalized)));
        return;
      }
      emit(BlocklistSuccess(_unblockedMessage(normalized)));
      return;
    }
    try {
      await _xmppService.unblock(jid: normalized);
    } on XmppBlockUnsupportedException catch (_) {
      emit(const BlocklistFailure(_unblockingUnsupportedMessage));
      return;
    } on XmppBlocklistException catch (_) {
      emit(BlocklistFailure(_unblockFailedMessage(normalized)));
      return;
    }
    emit(BlocklistSuccess(_unblockedMessage(normalized)));
  }

  Future<void> unblockAll() async {
    emit(const BlocklistLoading(jid: null));
    var failed = false;
    try {
      await _xmppService.unblockAll();
    } on XmppBlockUnsupportedException catch (_) {
      failed = true;
    } on XmppBlocklistException catch (_) {
      failed = true;
    }
    try {
      await _xmppService.clearEmailBlocklist();
    } on Exception {
      failed = true;
    }
    if (failed) {
      emit(const BlocklistFailure(_unblockAllFailedMessage));
      return;
    }
    emit(const BlocklistSuccess(_unblockAllSuccessMessage));
  }

  void _handleXmppBlocklist(List<BlocklistData> items) {
    _xmppBlocklist = items;
    _emitMerged();
  }

  void _handleEmailBlocklist(List<EmailBlocklistEntry> items) {
    _emailBlocklist = items;
    _emitMerged();
  }

  void _emitMerged() {
    if (_xmppBlocklist == null && _emailBlocklist == null) {
      emit(const BlocklistAvailable(items: null));
      return;
    }
    final entries = <BlocklistEntry>[
      if (_xmppBlocklist != null)
        for (final item in _xmppBlocklist!)
          BlocklistEntry(
            address: item.jid,
            blockedAt: item.blockedAt,
            transport: MessageTransport.xmpp,
          ),
      if (_emailBlocklist != null)
        for (final item in _emailBlocklist!)
          BlocklistEntry(
            address: item.address,
            blockedAt: item.blockedAt,
            transport: MessageTransport.email,
          ),
    ];
    emit(BlocklistAvailable(items: entries));
  }
}
