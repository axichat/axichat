// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'contacts_state.dart';

class ContactsCubit extends Cubit<ContactsState> {
  ContactsCubit({required XmppService xmppService, EmailService? emailService})
    : _xmppService = xmppService,
      _emailService = emailService,
      super(const ContactsState()) {
    _contactsSubscription = _xmppService.contactsStream().listen(
      _handleContacts,
    );
  }

  final XmppService _xmppService;
  EmailService? _emailService;
  late final StreamSubscription<List<ContactDirectoryEntry>>
  _contactsSubscription;
  List<ContactDirectoryEntry>? _items;
  var _criteria = const ContactsViewCriteria();

  void updateEmailService(EmailService? emailService) {
    _emailService = emailService;
  }

  @override
  Future<void> close() async {
    await _contactsSubscription.cancel();
    return super.close();
  }

  void updateCriteria({required String query, required SearchSortOrder sort}) {
    final next = ContactsViewCriteria(
      query: query.trim().toLowerCase(),
      sort: sort,
    );
    if (next == _criteria) {
      return;
    }
    _criteria = next;
    _emitViewState();
  }

  Future<void> addEmailContact({
    required String address,
    String? displayName,
  }) async {
    final normalized = bareAddress(address) ?? address.trim();
    if (!normalized.isValidJid) {
      emit(
        state.copyWith(
          actionState: ContactActionFailure(
            action: ContactActionType.addEmail,
            address: normalized,
            reason: ContactFailureReason.invalidAddress,
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        actionState: ContactActionLoading(
          action: ContactActionType.addEmail,
          address: normalized,
        ),
      ),
    );
    final emailService = _emailService;
    if (emailService == null) {
      emit(
        state.copyWith(
          actionState: ContactActionFailure(
            action: ContactActionType.addEmail,
            address: normalized,
            reason: ContactFailureReason.unavailable,
          ),
        ),
      );
      return;
    }
    try {
      await emailService.addContactAddress(
        address: normalized,
        displayName: displayName,
      );
    } on Exception {
      emit(
        state.copyWith(
          actionState: ContactActionFailure(
            action: ContactActionType.addEmail,
            address: normalized,
            reason: ContactFailureReason.addFailed,
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        actionState: ContactActionSuccess(
          action: ContactActionType.addEmail,
          address: normalized,
        ),
      ),
    );
  }

  Future<void> removeEmailContact({
    required String address,
    required List<String> nativeIds,
  }) async {
    final normalized = contactDirectoryAddressKey(address);
    final emailService = _emailService;
    if (emailService == null) {
      emit(
        state.copyWith(
          actionState: ContactActionFailure(
            action: ContactActionType.removeEmail,
            address: normalized,
            reason: ContactFailureReason.unavailable,
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        actionState: ContactActionLoading(
          action: ContactActionType.removeEmail,
          address: normalized,
        ),
      ),
    );
    try {
      await emailService.deleteContactsByNativeIds(nativeIds);
    } on Exception {
      emit(
        state.copyWith(
          actionState: ContactActionFailure(
            action: ContactActionType.removeEmail,
            address: normalized,
            reason: ContactFailureReason.removeFailed,
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        actionState: ContactActionSuccess(
          action: ContactActionType.removeEmail,
          address: normalized,
        ),
      ),
    );
  }

  void _handleContacts(List<ContactDirectoryEntry> items) {
    _items = List<ContactDirectoryEntry>.unmodifiable(items);
    _emitViewState();
  }

  void _emitViewState() {
    final visibleItems = _items == null
        ? null
        : List<ContactDirectoryEntry>.unmodifiable(
            _applyCriteria(_items!, _criteria),
          );
    emit(
      state.copyWith(
        items: _items,
        visibleItems: visibleItems,
        criteria: _criteria,
      ),
    );
  }

  List<ContactDirectoryEntry> _applyCriteria(
    List<ContactDirectoryEntry> items,
    ContactsViewCriteria criteria,
  ) {
    Iterable<ContactDirectoryEntry> filtered = items;
    if (criteria.query.isNotEmpty) {
      filtered = filtered.where((item) => _matchesQuery(item, criteria.query));
    }
    final sorted = filtered.toList();
    sorted.sort((a, b) {
      final comparison = a.displayName.toLowerCase().compareTo(
        b.displayName.toLowerCase(),
      );
      final resolved = comparison != 0
          ? comparison
          : a.address.compareTo(b.address);
      return criteria.sort.isNewestFirst ? resolved : -resolved;
    });
    return sorted;
  }

  bool _matchesQuery(ContactDirectoryEntry item, String query) {
    final values = <String>[
      item.displayName,
      item.address,
      if (item.xmppTitle?.trim().isNotEmpty == true) item.xmppTitle!,
      if (item.emailDisplayName?.trim().isNotEmpty == true)
        item.emailDisplayName!,
    ];
    for (final value in values) {
      if (value.toLowerCase().contains(query)) {
        return true;
      }
    }
    return false;
  }
}
