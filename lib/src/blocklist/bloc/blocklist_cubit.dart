// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/blocklist/models/blocklist_entry.dart';
import 'package:axichat/src/common/bloc_cache.dart';
import 'package:axichat/src/common/email_validation.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'blocklist_state.dart';

class BlocklistCubit extends Cubit<BlocklistState>
    with BlocCache<BlocklistState> {
  static const String blocklistItemsCacheKey = 'items';

  BlocklistCubit({required XmppService xmppService})
      : _xmppService = xmppService,
        super(const BlocklistAvailable(items: null, visibleItems: null)) {
    _xmppBlocklistSubscription = _xmppService.blocklistStream().listen(
          _handleXmppBlocklist,
        );
    _emailBlocklistSubscription = _xmppService.emailBlocklistStream().listen(
          _handleEmailBlocklist,
        );
  }

  final XmppService _xmppService;
  List<BlocklistData>? _xmppBlocklist;
  List<EmailBlocklistEntry>? _emailBlocklist;
  String _filterQuery = '';
  SearchSortOrder _filterSortOrder = SearchSortOrder.newestFirst;

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
      _emitFailure(const BlocklistNotice(BlocklistNoticeType.invalidJid));
      return;
    }
    final resolvedTransport = transport ?? normalized.inferredTransport;
    _emitLoading(jid: normalized);
    if (resolvedTransport.isEmail) {
      if (!normalized.isValidEmailAddress) {
        _emitFailure(const BlocklistNotice(BlocklistNoticeType.invalidJid));
        return;
      }
      try {
        await _xmppService.setBlockStatus(
          address: normalized,
          blocked: true,
        );
      } on XmppException {
        _emitFailure(
          BlocklistNotice(
            BlocklistNoticeType.blockFailed,
            address: normalized,
          ),
        );
        return;
      }
      _emitSuccess(
        BlocklistNotice(
          BlocklistNoticeType.blocked,
          address: normalized,
        ),
      );
      return;
    }
    if (!normalized.isValidJid) {
      _emitFailure(const BlocklistNotice(BlocklistNoticeType.invalidJid));
      return;
    }
    try {
      await _blockXmpp(address: normalized, reportReason: reportReason);
    } on XmppBlockUnsupportedException catch (_) {
      _emitFailure(
        const BlocklistNotice(BlocklistNoticeType.blockUnsupported),
      );
      return;
    } on XmppBlocklistException catch (_) {
      _emitFailure(
        BlocklistNotice(
          BlocklistNoticeType.blockFailed,
          address: normalized,
        ),
      );
      return;
    }
    _emitSuccess(
      BlocklistNotice(
        BlocklistNoticeType.blocked,
        address: normalized,
      ),
    );
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
      await _xmppService.blockAndReport(jid: address, reason: reportReason);
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
    _emitLoading(jid: normalized);
    if (entry.transport.isEmail) {
      try {
        await _xmppService.setBlockStatus(
          address: normalized,
          blocked: false,
        );
      } on XmppException {
        _emitFailure(
          BlocklistNotice(
            BlocklistNoticeType.unblockFailed,
            address: normalized,
          ),
        );
        return;
      }
      _emitSuccess(
        BlocklistNotice(
          BlocklistNoticeType.unblocked,
          address: normalized,
        ),
      );
      return;
    }
    try {
      await _xmppService.unblock(jid: normalized);
    } on XmppBlockUnsupportedException catch (_) {
      _emitFailure(
        const BlocklistNotice(BlocklistNoticeType.unblockUnsupported),
      );
      return;
    } on XmppBlocklistException catch (_) {
      _emitFailure(
        BlocklistNotice(
          BlocklistNoticeType.unblockFailed,
          address: normalized,
        ),
      );
      return;
    }
    _emitSuccess(
      BlocklistNotice(
        BlocklistNoticeType.unblocked,
        address: normalized,
      ),
    );
  }

  Future<void> unblockAll() async {
    _emitLoading(jid: null);
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
      _emitFailure(
        const BlocklistNotice(BlocklistNoticeType.unblockAllFailed),
      );
      return;
    }
    _emitSuccess(
      const BlocklistNotice(BlocklistNoticeType.unblockAllSuccess),
    );
  }

  void updateFilter({
    required String query,
    required SearchSortOrder sortOrder,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    if (_filterQuery == normalizedQuery && _filterSortOrder == sortOrder) {
      return;
    }
    _filterQuery = normalizedQuery;
    _filterSortOrder = sortOrder;
    final items = state.items;
    if (items == null) {
      return;
    }
    final visibleItems = _applyFilters(items);
    emit(_stateWithVisible(state, visibleItems));
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
      emit(const BlocklistAvailable(items: null, visibleItems: null));
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
    final visibleItems = _applyFilters(entries);
    emit(BlocklistAvailable(items: entries, visibleItems: visibleItems));
  }

  BlocklistState _stateWithVisible(
    BlocklistState current,
    List<BlocklistEntry> visibleItems,
  ) {
    final items = current.items;
    return switch (current) {
      BlocklistAvailable() => BlocklistAvailable(
          items: items,
          visibleItems: visibleItems,
        ),
      BlocklistLoading() => BlocklistLoading(
          jid: current.jid,
          items: items,
          visibleItems: visibleItems,
        ),
      BlocklistSuccess() => BlocklistSuccess(
          current.notice,
          items: items,
          visibleItems: visibleItems,
        ),
      BlocklistFailure() => BlocklistFailure(
          current.notice,
          items: items,
          visibleItems: visibleItems,
        ),
    };
  }

  List<BlocklistEntry> _applyFilters(List<BlocklistEntry> items) {
    List<BlocklistEntry> visibleItems = items;
    if (_filterQuery.isNotEmpty) {
      visibleItems = visibleItems
          .where((item) => item.address.toLowerCase().contains(_filterQuery))
          .toList();
    } else {
      visibleItems = List<BlocklistEntry>.from(visibleItems);
    }
    visibleItems.sort(
      (a, b) => _filterSortOrder.isNewestFirst
          ? b.blockedAt.compareTo(a.blockedAt)
          : a.blockedAt.compareTo(b.blockedAt),
    );
    return visibleItems;
  }

  void _emitLoading({required String? jid}) {
    emit(
      BlocklistLoading(
        jid: jid,
        items: state.items,
        visibleItems: state.visibleItems,
      ),
    );
  }

  void _emitSuccess(BlocklistNotice notice) {
    emit(
      BlocklistSuccess(
        notice,
        items: state.items,
        visibleItems: state.visibleItems,
      ),
    );
  }

  void _emitFailure(BlocklistNotice notice) {
    emit(
      BlocklistFailure(
        notice,
        items: state.items,
        visibleItems: state.visibleItems,
      ),
    );
  }
}
