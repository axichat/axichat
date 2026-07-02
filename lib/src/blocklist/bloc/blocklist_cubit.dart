// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/anti_abuse_sync.dart' as anti_abuse;
import 'package:axichat/src/common/bloc_cache.dart';
import 'package:axichat/src/common/email_validation.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/service/delta_chat_exception.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'blocklist_state.dart';

extension BlocklistNoticeLocalization on BlocklistNotice {
  String resolve(AppLocalizations l10n) => switch (type) {
    BlocklistNoticeType.invalidJid => l10n.blocklistInvalidJid,
    BlocklistNoticeType.blockFailed => l10n.blocklistBlockFailed(address ?? ''),
    BlocklistNoticeType.blockMultipleFailed =>
      l10n.blocklistBlockMultipleFailed(count ?? 0),
    BlocklistNoticeType.unblockFailed => l10n.blocklistUnblockFailed(
      address ?? '',
    ),
    BlocklistNoticeType.blocked => l10n.blocklistBlocked(address ?? ''),
    BlocklistNoticeType.blockedMultiple => l10n.blocklistBlockedMultiple(
      count ?? 0,
    ),
    BlocklistNoticeType.unblocked => l10n.blocklistUnblocked(address ?? ''),
    BlocklistNoticeType.blockUnsupported => l10n.blocklistBlockingUnsupported,
    BlocklistNoticeType.unblockUnsupported =>
      l10n.blocklistUnblockingUnsupported,
    BlocklistNoticeType.unblockAllFailed => l10n.blocklistUnblockAllFailed,
    BlocklistNoticeType.unblockAllSuccess => l10n.blocklistUnblockAllSuccess,
  };
}

class BlocklistCubit extends Cubit<BlocklistState>
    with BlocCache<BlocklistState> {
  static const String blocklistItemsCacheKey = 'items';
  static const String blocklistVisibleItemsCacheKey = 'visibleItems';

  BlocklistCubit({required XmppService xmppService, EmailService? emailService})
    : _xmppService = xmppService,
      _emailService = emailService,
      super(const BlocklistAvailable(items: null, visibleItems: null)) {
    _xmppBlocklistSubscription = _xmppService.blocklistStream().listen(
      _handleXmppBlocklist,
    );
    _emailBlocklistSubscription = _xmppService.addressBlocklistStream().listen(
      _handleEmailBlocklist,
    );
    _addressBlockSyncSubscription = _xmppService.addressBlockSyncUpdateStream
        .listen(_handleAddressBlockSyncUpdate);
  }

  final XmppService _xmppService;
  EmailService? _emailService;
  List<BlocklistData>? _xmppBlocklist;
  List<EmailBlocklistEntry>? _emailBlocklist;
  String _filterQuery = '';
  SearchSortOrder _filterSortOrder = SearchSortOrder.newestFirst;

  late final StreamSubscription<List<BlocklistData>> _xmppBlocklistSubscription;
  late final StreamSubscription<List<EmailBlocklistEntry>>
  _emailBlocklistSubscription;
  late final StreamSubscription<anti_abuse.AddressBlockSyncUpdate>
  _addressBlockSyncSubscription;

  @override
  void onChange(Change<BlocklistState> change) {
    super.onChange(change);
    final next = change.nextState;
    if (next is BlocklistAvailable || next.items != null) {
      cache[blocklistItemsCacheKey] = next.items;
    }
    if (next is BlocklistAvailable || next.visibleItems != null) {
      cache[blocklistVisibleItemsCacheKey] = next.visibleItems;
    }
  }

  @override
  Future<void> close() async {
    await _xmppBlocklistSubscription.cancel();
    await _emailBlocklistSubscription.cancel();
    await _addressBlockSyncSubscription.cancel();
    return super.close();
  }

  void updateEmailService(EmailService? emailService) {
    _emailService = emailService;
  }

  Future<void> block({
    required String address,
    required MessageTransport transport,
    SpamReportReason? reportReason,
  }) async {
    final normalized = _normalizeOperationAddress(
      address: address,
      transport: transport,
    );
    final operation = BlocklistOperation.block(
      address: normalized,
      transport: transport,
    );
    if (normalized.isEmpty) {
      _emitFailure(
        const BlocklistNotice(BlocklistNoticeType.invalidJid),
        operation: operation,
      );
      return;
    }
    _emitLoading(operation: operation);
    if (transport.isEmail) {
      if (!normalized.isValidEmailAddress) {
        _emitFailure(
          const BlocklistNotice(BlocklistNoticeType.invalidJid),
          operation: operation,
        );
        return;
      }
      try {
        await _blockEmail(address: normalized);
      } on EmailServiceException catch (_) {
        _emitFailure(
          BlocklistNotice(BlocklistNoticeType.blockFailed, address: normalized),
          operation: operation,
        );
        return;
      } on DeltaChatException catch (_) {
        _emitFailure(
          BlocklistNotice(BlocklistNoticeType.blockFailed, address: normalized),
          operation: operation,
        );
        return;
      } on XmppException catch (_) {
        _emitFailure(
          BlocklistNotice(BlocklistNoticeType.blockFailed, address: normalized),
          operation: operation,
        );
        return;
      }
      _emitSuccess(
        BlocklistNotice(BlocklistNoticeType.blocked, address: normalized),
        operation: operation,
      );
      return;
    }
    if (!normalized.isValidJid) {
      _emitFailure(
        const BlocklistNotice(BlocklistNoticeType.invalidJid),
        operation: operation,
      );
      return;
    }
    try {
      await _blockXmpp(address: normalized, reportReason: reportReason);
    } on XmppBlockUnsupportedException catch (_) {
      _emitFailure(
        const BlocklistNotice(BlocklistNoticeType.blockUnsupported),
        operation: operation,
      );
      return;
    } on XmppBlocklistException catch (_) {
      _emitFailure(
        BlocklistNotice(BlocklistNoticeType.blockFailed, address: normalized),
        operation: operation,
      );
      return;
    }
    _emitSuccess(
      BlocklistNotice(BlocklistNoticeType.blocked, address: normalized),
      operation: operation,
    );
  }

  Future<void> blockTargets({required List<BlocklistTarget> targets}) async {
    final normalizedTargets = _normalizeBlocklistTargets(targets);
    final operation = BlocklistOperation.blockMany(targets: normalizedTargets);
    if (normalizedTargets.isEmpty) {
      _emitFailure(
        const BlocklistNotice(BlocklistNoticeType.invalidJid),
        operation: operation,
      );
      return;
    }
    if (normalizedTargets.any(_isInvalidBlocklistTarget)) {
      _emitFailure(
        const BlocklistNotice(BlocklistNoticeType.invalidJid),
        operation: operation,
      );
      return;
    }
    _emitLoading(operation: operation);
    final failed = <BlocklistTarget>[];
    var unsupported = false;
    for (final target in normalizedTargets) {
      try {
        if (target.transport.isEmail) {
          await _blockEmail(address: target.address);
        } else {
          await _blockXmpp(address: target.address);
        }
      } on XmppBlockUnsupportedException catch (_) {
        failed.add(target);
        unsupported = true;
      } on XmppBlocklistException catch (_) {
        failed.add(target);
      } on EmailServiceException catch (_) {
        failed.add(target);
      } on DeltaChatException catch (_) {
        failed.add(target);
      } on XmppException catch (_) {
        failed.add(target);
      }
    }
    if (failed.isNotEmpty) {
      if (unsupported && failed.length == normalizedTargets.length) {
        _emitFailure(
          const BlocklistNotice(BlocklistNoticeType.blockUnsupported),
          operation: operation,
        );
        return;
      }
      _emitFailure(
        failed.length == 1
            ? BlocklistNotice(
                BlocklistNoticeType.blockFailed,
                address: failed.single.address,
              )
            : BlocklistNotice(
                BlocklistNoticeType.blockMultipleFailed,
                count: failed.length,
              ),
        operation: operation,
      );
      return;
    }
    _emitSuccess(
      normalizedTargets.length == 1
          ? BlocklistNotice(
              BlocklistNoticeType.blocked,
              address: normalizedTargets.single.address,
            )
          : BlocklistNotice(
              BlocklistNoticeType.blockedMultiple,
              count: normalizedTargets.length,
            ),
      operation: operation,
    );
  }

  Future<void> blockContact({
    required String address,
    required bool includeEmail,
    required bool includeXmpp,
    SpamReportReason? reportReason,
  }) async {
    final normalized =
        normalizedAddressKey(address) ??
        normalizedAddressValue(address) ??
        address.trim();
    final operation = BlocklistOperation.blockContact(address: normalized);
    if (normalized.isEmpty || (!includeEmail && !includeXmpp)) {
      _emitFailure(
        const BlocklistNotice(BlocklistNoticeType.invalidJid),
        operation: operation,
      );
      return;
    }
    _emitLoading(operation: operation);
    if (includeEmail) {
      final emailAddress = _normalizeOperationAddress(
        address: address,
        transport: MessageTransport.email,
      );
      if (emailAddress.isEmpty || !emailAddress.isValidEmailAddress) {
        _emitFailure(
          const BlocklistNotice(BlocklistNoticeType.invalidJid),
          operation: operation,
        );
        return;
      }
      try {
        await _blockEmail(address: emailAddress);
      } on EmailServiceException catch (_) {
        _emitFailure(
          BlocklistNotice(
            BlocklistNoticeType.blockFailed,
            address: emailAddress,
          ),
          operation: operation,
        );
        return;
      } on DeltaChatException catch (_) {
        _emitFailure(
          BlocklistNotice(
            BlocklistNoticeType.blockFailed,
            address: emailAddress,
          ),
          operation: operation,
        );
        return;
      } on XmppException catch (_) {
        _emitFailure(
          BlocklistNotice(
            BlocklistNoticeType.blockFailed,
            address: emailAddress,
          ),
          operation: operation,
        );
        return;
      }
    }
    if (includeXmpp) {
      if (!normalized.isValidJid) {
        _emitFailure(
          const BlocklistNotice(BlocklistNoticeType.invalidJid),
          operation: operation,
        );
        return;
      }
      try {
        await _blockXmpp(address: normalized, reportReason: reportReason);
      } on XmppBlockUnsupportedException catch (_) {
        _emitFailure(
          const BlocklistNotice(BlocklistNoticeType.blockUnsupported),
          operation: operation,
        );
        return;
      } on XmppBlocklistException catch (_) {
        _emitFailure(
          BlocklistNotice(BlocklistNoticeType.blockFailed, address: normalized),
          operation: operation,
        );
        return;
      }
    }
    _emitSuccess(
      BlocklistNotice(BlocklistNoticeType.blocked, address: normalized),
      operation: operation,
    );
  }

  Future<void> _blockEmail({required String address}) async {
    final wasBlocked = _isEmailAddressBlockedInState(address);
    await _xmppService.setAddressBlockStatus(address: address, blocked: true);
    try {
      await _applyEmailBlocklistCoreState(address: address, blocked: true);
    } on EmailServiceException catch (_) {
      if (!wasBlocked) {
        await _rollbackEmailBlock(address);
      }
      rethrow;
    } on DeltaChatException catch (_) {
      if (!wasBlocked) {
        await _rollbackEmailBlock(address);
      }
      rethrow;
    }
  }

  Future<EmailCoreBlockStateResult> _unblockEmail({
    required String address,
  }) async {
    final result = await _applyEmailBlocklistCoreState(
      address: address,
      blocked: false,
    );
    await _xmppService.setAddressBlockStatus(address: address, blocked: false);
    return result;
  }

  Future<EmailCoreBlockStateResult> _applyEmailBlocklistCoreState({
    required String address,
    required bool blocked,
  }) async {
    final emailService = _emailService;
    if (emailService == null) {
      throw const EmailServiceCoreBlockStateException();
    }
    return emailService.applyEmailBlocklistCoreState(
      address: address,
      blocked: blocked,
    );
  }

  Future<void> _rollbackEmailBlock(String address) async {
    try {
      await _xmppService.setAddressBlockStatus(
        address: address,
        blocked: false,
      );
    } on XmppException catch (_) {}
  }

  bool _isEmailAddressBlockedInState(String address) {
    final normalized = normalizedAddressValue(address);
    if (normalized == null || normalized.isEmpty) {
      return false;
    }
    final emailBlocklist = _emailBlocklist;
    if (emailBlocklist != null) {
      return emailBlocklist.any(
        (entry) => normalizedAddressValue(entry.address) == normalized,
      );
    }
    return (state.items ?? const <BlocklistEntry>[]).any(
      (entry) =>
          entry.transport.isEmail &&
          normalizedAddressValue(entry.address) == normalized,
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
    final normalized = _normalizeOperationAddress(
      address: entry.address,
      transport: entry.transport,
    );
    final operation = BlocklistOperation.unblock(
      address: normalized,
      transport: entry.transport,
    );
    if (normalized.isEmpty) {
      return;
    }
    _emitLoading(operation: operation);
    if (entry.transport.isEmail) {
      try {
        await _unblockEmail(address: normalized);
      } on EmailServiceException catch (_) {
        _emitFailure(
          BlocklistNotice(
            BlocklistNoticeType.unblockFailed,
            address: normalized,
          ),
          operation: operation,
        );
        return;
      } on DeltaChatException catch (_) {
        _emitFailure(
          BlocklistNotice(
            BlocklistNoticeType.unblockFailed,
            address: normalized,
          ),
          operation: operation,
        );
        return;
      } on XmppException catch (_) {
        _emitFailure(
          BlocklistNotice(
            BlocklistNoticeType.unblockFailed,
            address: normalized,
          ),
          operation: operation,
        );
        return;
      }
      _emitSuccess(
        BlocklistNotice(BlocklistNoticeType.unblocked, address: normalized),
        operation: operation,
      );
      return;
    }
    try {
      await _xmppService.unblock(jid: normalized);
    } on XmppBlockUnsupportedException catch (_) {
      _emitFailure(
        const BlocklistNotice(BlocklistNoticeType.unblockUnsupported),
        operation: operation,
      );
      return;
    } on XmppBlocklistException catch (_) {
      _emitFailure(
        BlocklistNotice(BlocklistNoticeType.unblockFailed, address: normalized),
        operation: operation,
      );
      return;
    }
    _emitSuccess(
      BlocklistNotice(BlocklistNoticeType.unblocked, address: normalized),
      operation: operation,
    );
  }

  Future<void> unblockContact({
    required String address,
    required bool includeEmail,
    required bool includeXmpp,
  }) async {
    final normalized =
        normalizedAddressKey(address) ??
        normalizedAddressValue(address) ??
        address.trim();
    final operation = BlocklistOperation.unblockContact(address: normalized);
    if (normalized.isEmpty || (!includeEmail && !includeXmpp)) {
      _emitFailure(
        const BlocklistNotice(BlocklistNoticeType.invalidJid),
        operation: operation,
      );
      return;
    }
    _emitLoading(operation: operation);
    if (includeEmail) {
      final emailAddress = normalizedAddressValue(address);
      if (emailAddress == null || !emailAddress.isValidEmailAddress) {
        _emitFailure(
          const BlocklistNotice(BlocklistNoticeType.invalidJid),
          operation: operation,
        );
        return;
      }
      try {
        await _unblockEmail(address: emailAddress);
      } on EmailServiceException catch (_) {
        _emitFailure(
          BlocklistNotice(
            BlocklistNoticeType.unblockFailed,
            address: normalized,
          ),
          operation: operation,
        );
        return;
      } on DeltaChatException catch (_) {
        _emitFailure(
          BlocklistNotice(
            BlocklistNoticeType.unblockFailed,
            address: normalized,
          ),
          operation: operation,
        );
        return;
      } on XmppException catch (_) {
        _emitFailure(
          BlocklistNotice(
            BlocklistNoticeType.unblockFailed,
            address: normalized,
          ),
          operation: operation,
        );
        return;
      }
    }
    if (includeXmpp) {
      final jid = normalizedAddressKey(address);
      if (jid == null || !jid.isValidJid) {
        _emitFailure(
          const BlocklistNotice(BlocklistNoticeType.invalidJid),
          operation: operation,
        );
        return;
      }
      try {
        await _xmppService.unblock(jid: jid);
      } on XmppBlockUnsupportedException catch (_) {
        _emitFailure(
          const BlocklistNotice(BlocklistNoticeType.unblockUnsupported),
          operation: operation,
        );
        return;
      } on XmppBlocklistException catch (_) {
        _emitFailure(
          BlocklistNotice(
            BlocklistNoticeType.unblockFailed,
            address: normalized,
          ),
          operation: operation,
        );
        return;
      }
    }
    _emitSuccess(
      BlocklistNotice(BlocklistNoticeType.unblocked, address: normalized),
      operation: operation,
    );
  }

  Future<void> unblockAll() async {
    const operation = BlocklistOperation.unblockAll();
    _emitLoading(operation: operation);
    var failed = false;
    final emailAddresses = _blockedEmailAddresses();
    try {
      for (final address in emailAddresses) {
        await _applyEmailBlocklistCoreState(address: address, blocked: false);
      }
    } on EmailServiceException catch (_) {
      failed = true;
    } on DeltaChatException catch (_) {
      failed = true;
    }
    if (failed) {
      _emitFailure(
        const BlocklistNotice(BlocklistNoticeType.unblockAllFailed),
        operation: operation,
      );
      return;
    }
    try {
      await _xmppService.unblockAll();
    } on XmppBlockUnsupportedException catch (_) {
      failed = true;
    } on XmppBlocklistException catch (_) {
      failed = true;
    }
    try {
      await _xmppService.clearAddressBlocks();
    } on XmppException {
      failed = true;
    }
    if (failed) {
      _emitFailure(
        const BlocklistNotice(BlocklistNoticeType.unblockAllFailed),
        operation: operation,
      );
      return;
    }
    _emitSuccess(
      const BlocklistNotice(BlocklistNoticeType.unblockAllSuccess),
      operation: operation,
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

  void _handleAddressBlockSyncUpdate(anti_abuse.AddressBlockSyncUpdate update) {
    final normalized = normalizedAddressValue(update.address);
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    final items = List<EmailBlocklistEntry>.of(
      _emailBlocklist ?? const <EmailBlocklistEntry>[],
    );
    final index = items.indexWhere(
      (item) => normalizedAddressValue(item.address) == normalized,
    );
    if (!update.blocked) {
      if (index != -1) {
        items.removeAt(index);
        _emailBlocklist = items;
        _emitMerged();
      }
      return;
    }
    final updatedAt = update.updatedAt.toUtc();
    final entry = EmailBlocklistEntry(
      address: normalized,
      blockedAt: updatedAt,
      sourceId: update.sourceId,
    );
    if (index == -1) {
      items.add(entry);
    } else if (!items[index].blockedAt.toUtc().isAfter(updatedAt)) {
      items[index] = entry;
    }
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
    final current = state;
    if (current is BlocklistLoading) {
      emit(
        BlocklistLoading(
          operation: current.operation,
          items: entries,
          visibleItems: visibleItems,
        ),
      );
      return;
    }
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
        operation: current.operation,
        items: items,
        visibleItems: visibleItems,
      ),
      BlocklistSuccess() => BlocklistSuccess(
        current.notice,
        operation: current.operation,
        items: items,
        visibleItems: visibleItems,
      ),
      BlocklistFailure() => BlocklistFailure(
        current.notice,
        operation: current.operation,
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

  String _normalizeOperationAddress({
    required String address,
    required MessageTransport transport,
  }) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (transport.isEmail) {
      return normalizedAddressValue(trimmed) ?? trimmed.toLowerCase();
    }
    return normalizedAddressKey(trimmed) ?? trimmed;
  }

  List<BlocklistTarget> _normalizeBlocklistTargets(
    Iterable<BlocklistTarget> targets,
  ) {
    final normalizedTargets = <BlocklistTarget>[];
    final seen = <String>{};
    for (final target in targets) {
      final normalized = _normalizeOperationAddress(
        address: target.address,
        transport: target.transport,
      );
      if (normalized.isEmpty) {
        continue;
      }
      final key = '${target.transport.wireValue}:$normalized';
      if (!seen.add(key)) {
        continue;
      }
      normalizedTargets.add(
        BlocklistTarget(address: normalized, transport: target.transport),
      );
    }
    return normalizedTargets;
  }

  List<String> _blockedEmailAddresses() {
    final addresses = <String>[];
    final seen = <String>{};
    final emailBlocklist = _emailBlocklist;
    if (emailBlocklist != null) {
      for (final entry in emailBlocklist) {
        final normalized = normalizedAddressValue(entry.address);
        if (normalized != null && seen.add(normalized)) {
          addresses.add(normalized);
        }
      }
      return addresses;
    }
    for (final entry in state.items ?? const <BlocklistEntry>[]) {
      if (!entry.transport.isEmail) {
        continue;
      }
      final normalized = normalizedAddressValue(entry.address);
      if (normalized != null && seen.add(normalized)) {
        addresses.add(normalized);
      }
    }
    return addresses;
  }

  bool _isInvalidBlocklistTarget(BlocklistTarget target) {
    if (target.transport.isEmail) {
      return !target.address.isValidEmailAddress;
    }
    return !target.address.isValidJid;
  }

  void _emitLoading({required BlocklistOperation operation}) {
    emit(
      BlocklistLoading(
        operation: operation,
        items: state.items,
        visibleItems: state.visibleItems,
      ),
    );
  }

  void _emitSuccess(
    BlocklistNotice notice, {
    required BlocklistOperation operation,
  }) {
    emit(
      BlocklistSuccess(
        notice,
        operation: operation,
        items: state.items,
        visibleItems: state.visibleItems,
      ),
    );
  }

  void _emitFailure(
    BlocklistNotice notice, {
    required BlocklistOperation operation,
  }) {
    emit(
      BlocklistFailure(
        notice,
        operation: operation,
        items: state.items,
        visibleItems: state.visibleItems,
      ),
    );
  }
}
