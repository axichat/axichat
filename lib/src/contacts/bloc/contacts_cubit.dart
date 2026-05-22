// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/service/delta_chat_exception.dart';
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
    _contactsSubscription = _xmppService.contactDirectoryStream().listen(
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

  void updateCriteria({
    required String query,
    required SearchSortOrder sort,
    SearchFilterId? filterId,
  }) {
    final next = ContactsViewCriteria(
      query: query.trim().toLowerCase(),
      sort: sort,
      filterId: filterId,
    );
    if (next == _criteria) {
      return;
    }
    _criteria = next;
    _emitViewState();
  }

  Future<void> addContact({
    required String address,
    String? displayName,
    required MessageTransport transport,
  }) async {
    final normalized = bareAddress(address) ?? address.trim();
    if (!normalized.isValidJid) {
      emit(
        state.copyWith(
          actionState: ContactActionFailure(
            action: ContactActionType.addContact,
            address: normalized,
            reason: ContactFailureReason.invalidAddress,
          ),
        ),
      );
      return;
    }
    final loading = ContactActionLoading(
      action: ContactActionType.addContact,
      address: normalized,
    );
    if (state.isContactAddressLoading(normalized)) return;
    emit(state.markContactActionLoading(loading));
    final title = _trimmedOrNull(displayName);
    if (transport.isXmpp) {
      try {
        await _xmppService.addToRoster(jid: normalized, title: title);
      } on XmppRosterException {
        emit(
          state
              .clearContactActionLoading(loading)
              .copyWith(
                actionState: ContactActionFailure(
                  action: ContactActionType.addContact,
                  address: normalized,
                  reason: ContactFailureReason.addFailed,
                ),
              ),
        );
        return;
      }
    } else {
      final emailService = _emailService;
      if (emailService == null) {
        emit(
          state
              .clearContactActionLoading(loading)
              .copyWith(
                actionState: ContactActionFailure(
                  action: ContactActionType.addContact,
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
          displayName: title,
        );
      } on EmailServiceException {
        emit(
          state
              .clearContactActionLoading(loading)
              .copyWith(
                actionState: ContactActionFailure(
                  action: ContactActionType.addContact,
                  address: normalized,
                  reason: ContactFailureReason.addFailed,
                ),
              ),
        );
        return;
      } on EmailProvisioningException {
        emit(
          state
              .clearContactActionLoading(loading)
              .copyWith(
                actionState: ContactActionFailure(
                  action: ContactActionType.addContact,
                  address: normalized,
                  reason: ContactFailureReason.addFailed,
                ),
              ),
        );
        return;
      } on DeltaChatException {
        emit(
          state
              .clearContactActionLoading(loading)
              .copyWith(
                actionState: ContactActionFailure(
                  action: ContactActionType.addContact,
                  address: normalized,
                  reason: ContactFailureReason.addFailed,
                ),
              ),
        );
        return;
      }
    }
    emit(
      state
          .clearContactActionLoading(loading)
          .copyWith(
            actionState: ContactActionSuccess(
              action: ContactActionType.addContact,
              address: normalized,
            ),
          ),
    );
  }

  Future<void> removeContact(ContactDirectoryEntry contact) async {
    final normalized = contactDirectoryAddressKey(contact.address);
    if (normalized.isEmpty) {
      emit(
        state.copyWith(
          actionState: ContactActionFailure(
            action: ContactActionType.removeContact,
            address: contact.address,
            reason: ContactFailureReason.invalidAddress,
          ),
        ),
      );
      return;
    }
    final EmailService? emailService;
    if (contact.hasEmailContact) {
      emailService = _emailService;
      if (emailService == null) {
        emit(
          state.copyWith(
            actionState: ContactActionFailure(
              action: ContactActionType.removeContact,
              address: normalized,
              reason: ContactFailureReason.unavailable,
            ),
          ),
        );
        return;
      }
    } else {
      emailService = null;
    }
    final loading = ContactActionLoading(
      action: ContactActionType.removeContact,
      address: normalized,
    );
    if (state.isContactAddressLoading(normalized)) return;
    emit(state.markContactActionLoading(loading));
    if (contact.hasXmppRoster) {
      try {
        await _xmppService.removeFromRoster(jid: normalized);
      } on XmppRosterException {
        emit(
          state
              .clearContactActionLoading(loading)
              .copyWith(
                actionState: ContactActionFailure(
                  action: ContactActionType.removeContact,
                  address: normalized,
                  reason: ContactFailureReason.removeFailed,
                ),
              ),
        );
        return;
      }
    }
    if (emailService != null) {
      try {
        await emailService.deleteContactsByNativeIds(contact.emailNativeIds);
      } on EmailServiceException {
        emit(
          state
              .clearContactActionLoading(loading)
              .copyWith(
                actionState: ContactActionFailure(
                  action: ContactActionType.removeContact,
                  address: normalized,
                  reason: ContactFailureReason.removeFailed,
                ),
              ),
        );
        return;
      } on EmailProvisioningException {
        emit(
          state
              .clearContactActionLoading(loading)
              .copyWith(
                actionState: ContactActionFailure(
                  action: ContactActionType.removeContact,
                  address: normalized,
                  reason: ContactFailureReason.removeFailed,
                ),
              ),
        );
        return;
      } on DeltaChatException {
        emit(
          state
              .clearContactActionLoading(loading)
              .copyWith(
                actionState: ContactActionFailure(
                  action: ContactActionType.removeContact,
                  address: normalized,
                  reason: ContactFailureReason.removeFailed,
                ),
              ),
        );
        return;
      }
    }
    if (contact.hasPrivateContact) {
      try {
        await _xmppService.deactivatePrivateContact(address: normalized);
      } on XmppContactDirectoryException {
        emit(
          state
              .clearContactActionLoading(loading)
              .copyWith(
                actionState: ContactActionFailure(
                  action: ContactActionType.removeContact,
                  address: normalized,
                  reason: ContactFailureReason.removeFailed,
                ),
              ),
        );
        return;
      }
    }
    emit(
      state
          .clearContactActionLoading(loading)
          .copyWith(
            actionState: ContactActionSuccess(
              action: ContactActionType.removeContact,
              address: normalized,
            ),
          ),
    );
  }

  Future<bool> addManualContact({
    required String address,
    String? displayName,
  }) async {
    final normalized = bareAddress(address) ?? address.trim();
    if (!normalized.isValidJid) {
      emit(
        state.copyWith(
          actionState: ContactActionFailure(
            action: ContactActionType.addManual,
            address: normalized,
            reason: ContactFailureReason.invalidAddress,
          ),
        ),
      );
      return false;
    }
    final loading = ContactActionLoading(
      action: ContactActionType.addManual,
      address: normalized,
    );
    if (state.isContactAddressLoading(normalized)) return false;
    emit(state.markContactActionLoading(loading));
    try {
      await _xmppService.addManualContact(
        address: normalized,
        displayName: displayName,
      );
    } on XmppContactDirectoryException {
      emit(
        state
            .clearContactActionLoading(loading)
            .copyWith(
              actionState: ContactActionFailure(
                action: ContactActionType.addManual,
                address: normalized,
                reason: ContactFailureReason.addFailed,
              ),
            ),
      );
      return false;
    }
    emit(
      state
          .clearContactActionLoading(loading)
          .copyWith(
            actionState: ContactActionSuccess(
              action: ContactActionType.addManual,
              address: normalized,
            ),
          ),
    );
    return true;
  }

  Future<void> removeManualContact({
    required ContactDirectoryEntry contact,
  }) async {
    final addressKey = contactDirectoryAddressKey(contact.address);
    if (addressKey.isEmpty) {
      emit(
        state.copyWith(
          actionState: ContactActionFailure(
            action: ContactActionType.removeManual,
            address: contact.address,
            reason: ContactFailureReason.invalidAddress,
          ),
        ),
      );
      return;
    }
    final loading = ContactActionLoading(
      action: ContactActionType.removeManual,
      address: addressKey,
    );
    if (state.isContactAddressLoading(addressKey)) return;
    emit(state.markContactActionLoading(loading));
    try {
      await _xmppService.deactivatePrivateContact(address: contact.address);
    } on XmppContactDirectoryException {
      emit(
        state
            .clearContactActionLoading(loading)
            .copyWith(
              actionState: ContactActionFailure(
                action: ContactActionType.removeManual,
                address: contact.address,
                reason: ContactFailureReason.removeFailed,
              ),
            ),
      );
      return;
    }
    emit(
      state
          .clearContactActionLoading(loading)
          .copyWith(
            actionState: ContactActionSuccess(
              action: ContactActionType.removeManual,
              address: contact.address,
            ),
          ),
    );
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
    final loading = ContactActionLoading(
      action: ContactActionType.addEmail,
      address: normalized,
    );
    if (state.isContactAddressLoading(normalized)) return;
    emit(state.markContactActionLoading(loading));
    final emailService = _emailService;
    if (emailService == null) {
      emit(
        state
            .clearContactActionLoading(loading)
            .copyWith(
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
    } on EmailServiceException {
      emit(
        state
            .clearContactActionLoading(loading)
            .copyWith(
              actionState: ContactActionFailure(
                action: ContactActionType.addEmail,
                address: normalized,
                reason: ContactFailureReason.addFailed,
              ),
            ),
      );
      return;
    } on EmailProvisioningException {
      emit(
        state
            .clearContactActionLoading(loading)
            .copyWith(
              actionState: ContactActionFailure(
                action: ContactActionType.addEmail,
                address: normalized,
                reason: ContactFailureReason.addFailed,
              ),
            ),
      );
      return;
    } on DeltaChatException {
      emit(
        state
            .clearContactActionLoading(loading)
            .copyWith(
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
      state
          .clearContactActionLoading(loading)
          .copyWith(
            actionState: ContactActionSuccess(
              action: ContactActionType.addEmail,
              address: normalized,
            ),
          ),
    );
  }

  Future<void> setFavorited({
    required ContactDirectoryEntry contact,
    required bool favorited,
  }) async {
    final normalized = contactDirectoryAddressKey(contact.address);
    if (normalized.isEmpty) {
      emit(
        state.copyWith(
          actionState: ContactActionFailure(
            action: favorited
                ? ContactActionType.favorite
                : ContactActionType.unfavorite,
            address: normalized,
            reason: ContactFailureReason.invalidAddress,
          ),
        ),
      );
      return;
    }
    final action = favorited
        ? ContactActionType.favorite
        : ContactActionType.unfavorite;
    final loading = ContactActionLoading(action: action, address: normalized);
    if (state.isContactAddressLoading(normalized)) return;
    emit(state.markContactActionLoading(loading));
    final previousItems = _items;
    _replaceContact(
      _currentContactOrFallback(contact).withFavorited(favorited),
    );
    try {
      await _xmppService.setContactFavorited(
        address: normalized,
        favorited: favorited,
      );
    } on XmppContactDirectoryException {
      _items = previousItems;
      emit(
        state
            .clearContactActionLoading(loading)
            .copyWith(
              items: _items,
              visibleItems: _visibleItems(),
              actionState: ContactActionFailure(
                action: action,
                address: normalized,
                reason: ContactFailureReason.updateFailed,
              ),
            ),
      );
      return;
    }
    emit(
      state
          .clearContactActionLoading(loading)
          .copyWith(
            items: _items,
            visibleItems: _visibleItems(),
            actionState: ContactActionSuccess(
              action: action,
              address: normalized,
            ),
          ),
    );
  }

  Future<void> renameContact({
    required ContactDirectoryEntry contact,
    required String displayName,
  }) async {
    final normalized = contactDirectoryAddressKey(contact.address);
    if (normalized.isEmpty) {
      emit(
        state.copyWith(
          actionState: ContactActionFailure(
            action: ContactActionType.rename,
            address: normalized,
            reason: ContactFailureReason.invalidAddress,
          ),
        ),
      );
      return;
    }
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      await resetContactDisplayName(contact: contact);
      return;
    }
    final loading = ContactActionLoading(
      action: ContactActionType.rename,
      address: normalized,
    );
    if (state.isContactAddressLoading(normalized)) return;
    emit(state.markContactActionLoading(loading));
    try {
      await _xmppService.setContactDisplayNameOverride(
        address: normalized,
        displayName: trimmed,
      );
      if (contact.hasXmppRoster) {
        try {
          await _xmppService.renameRosterContact(
            jid: normalized,
            title: trimmed,
          );
        } on XmppRosterException {
          // Local display overrides are Axichat-owned; roster sync is best effort.
        }
      }
    } on XmppContactDirectoryException {
      emit(
        state
            .clearContactActionLoading(loading)
            .copyWith(
              actionState: ContactActionFailure(
                action: ContactActionType.rename,
                address: normalized,
                reason: ContactFailureReason.updateFailed,
              ),
            ),
      );
      return;
    }
    emit(
      state
          .clearContactActionLoading(loading)
          .copyWith(
            actionState: ContactActionSuccess(
              action: ContactActionType.rename,
              address: normalized,
            ),
          ),
    );
  }

  Future<void> resetContactDisplayName({
    required ContactDirectoryEntry contact,
  }) async {
    final normalized = contactDirectoryAddressKey(contact.address);
    if (normalized.isEmpty) {
      emit(
        state.copyWith(
          actionState: ContactActionFailure(
            action: ContactActionType.resetRename,
            address: normalized,
            reason: ContactFailureReason.invalidAddress,
          ),
        ),
      );
      return;
    }
    final loading = ContactActionLoading(
      action: ContactActionType.resetRename,
      address: normalized,
    );
    if (state.isContactAddressLoading(normalized)) return;
    emit(state.markContactActionLoading(loading));
    try {
      await _xmppService.setContactDisplayNameOverride(
        address: normalized,
        displayName: null,
      );
    } on XmppContactDirectoryException {
      emit(
        state
            .clearContactActionLoading(loading)
            .copyWith(
              actionState: ContactActionFailure(
                action: ContactActionType.resetRename,
                address: normalized,
                reason: ContactFailureReason.updateFailed,
              ),
            ),
      );
      return;
    }
    emit(
      state
          .clearContactActionLoading(loading)
          .copyWith(
            actionState: ContactActionSuccess(
              action: ContactActionType.resetRename,
              address: normalized,
            ),
          ),
    );
  }

  Future<void> setContactFolderRule({
    required ContactDirectoryEntry contact,
    required String collectionId,
  }) async {
    final normalized = contactDirectoryAddressKey(contact.address);
    final trimmedCollectionId = collectionId.trim();
    if (normalized.isEmpty || trimmedCollectionId.isEmpty) {
      emit(
        state.copyWith(
          actionState: ContactActionFailure(
            action: ContactActionType.setFolderRule,
            address: normalized,
            collectionId: trimmedCollectionId,
            reason: ContactFailureReason.invalidAddress,
          ),
        ),
      );
      return;
    }
    final loading = ContactActionLoading(
      action: ContactActionType.setFolderRule,
      address: normalized,
      collectionId: trimmedCollectionId,
    );
    if (state.isContactAddressLoading(normalized)) return;
    emit(state.markContactActionLoading(loading));
    try {
      await _xmppService.setContactFolderRule(
        address: normalized,
        collectionId: trimmedCollectionId,
      );
    } on XmppContactDirectoryException {
      emit(
        state
            .clearContactActionLoading(loading)
            .copyWith(
              actionState: ContactActionFailure(
                action: ContactActionType.setFolderRule,
                address: normalized,
                collectionId: trimmedCollectionId,
                reason: ContactFailureReason.updateFailed,
              ),
            ),
      );
      return;
    }
    emit(
      state
          .clearContactActionLoading(loading)
          .copyWith(
            actionState: ContactActionSuccess(
              action: ContactActionType.setFolderRule,
              address: normalized,
              collectionId: trimmedCollectionId,
            ),
          ),
    );
  }

  Future<void> clearContactFolderRule({
    required ContactDirectoryEntry contact,
  }) async {
    final normalized = contactDirectoryAddressKey(contact.address);
    if (normalized.isEmpty) {
      emit(
        state.copyWith(
          actionState: ContactActionFailure(
            action: ContactActionType.clearFolderRule,
            address: normalized,
            reason: ContactFailureReason.invalidAddress,
          ),
        ),
      );
      return;
    }
    final loading = ContactActionLoading(
      action: ContactActionType.clearFolderRule,
      address: normalized,
      collectionId: contact.folderCollectionId,
    );
    if (state.isContactAddressLoading(normalized)) return;
    emit(state.markContactActionLoading(loading));
    try {
      await _xmppService.clearContactFolderRule(address: normalized);
    } on XmppContactDirectoryException {
      emit(
        state
            .clearContactActionLoading(loading)
            .copyWith(
              actionState: ContactActionFailure(
                action: ContactActionType.clearFolderRule,
                address: normalized,
                collectionId: contact.folderCollectionId,
                reason: ContactFailureReason.updateFailed,
              ),
            ),
      );
      return;
    }
    emit(
      state
          .clearContactActionLoading(loading)
          .copyWith(
            actionState: ContactActionSuccess(
              action: ContactActionType.clearFolderRule,
              address: normalized,
              collectionId: contact.folderCollectionId,
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
    final loading = ContactActionLoading(
      action: ContactActionType.removeEmail,
      address: normalized,
    );
    if (state.isContactAddressLoading(normalized)) return;
    emit(state.markContactActionLoading(loading));
    try {
      await emailService.deleteContactsByNativeIds(nativeIds);
    } on EmailServiceException {
      emit(
        state
            .clearContactActionLoading(loading)
            .copyWith(
              actionState: ContactActionFailure(
                action: ContactActionType.removeEmail,
                address: normalized,
                reason: ContactFailureReason.removeFailed,
              ),
            ),
      );
      return;
    } on EmailProvisioningException {
      emit(
        state
            .clearContactActionLoading(loading)
            .copyWith(
              actionState: ContactActionFailure(
                action: ContactActionType.removeEmail,
                address: normalized,
                reason: ContactFailureReason.removeFailed,
              ),
            ),
      );
      return;
    } on DeltaChatException {
      emit(
        state
            .clearContactActionLoading(loading)
            .copyWith(
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
      state
          .clearContactActionLoading(loading)
          .copyWith(
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
    emit(
      state.copyWith(
        items: _items,
        visibleItems: _visibleItems(),
        criteria: _criteria,
      ),
    );
  }

  List<ContactDirectoryEntry>? _visibleItems() {
    final items = _items;
    if (items == null) {
      return null;
    }
    return List<ContactDirectoryEntry>.unmodifiable(
      _applyCriteria(items, _criteria),
    );
  }

  ContactDirectoryEntry _currentContactOrFallback(
    ContactDirectoryEntry fallback,
  ) {
    final key = contactDirectoryAddressKey(fallback.address);
    for (final item in _items ?? const <ContactDirectoryEntry>[]) {
      if (contactDirectoryAddressKey(item.address) == key) {
        return item;
      }
    }
    return fallback;
  }

  void _replaceContact(ContactDirectoryEntry contact) {
    final items = _items;
    if (items == null) {
      return;
    }
    final key = contactDirectoryAddressKey(contact.address);
    _items = List<ContactDirectoryEntry>.unmodifiable(
      items.map((item) {
        if (contactDirectoryAddressKey(item.address) == key) {
          return contact;
        }
        return item;
      }),
    );
    _emitViewState();
  }

  List<ContactDirectoryEntry> _applyCriteria(
    List<ContactDirectoryEntry> items,
    ContactsViewCriteria criteria,
  ) {
    Iterable<ContactDirectoryEntry> filtered = items;
    filtered = switch (criteria.filterId ?? SearchFilterId.all) {
      SearchFilterId.favorites => filtered.where((item) => item.favorited),
      SearchFilterId.xmpp => filtered.where((item) => item.hasXmppRoster),
      SearchFilterId.email => filtered.where((item) => item.hasEmailContact),
      _ => filtered,
    };
    if (criteria.query.isNotEmpty) {
      filtered = filtered.where((item) => _matchesQuery(item, criteria.query));
    }
    final sorted = filtered.toList();
    sorted.sort((a, b) {
      if (a.favorited != b.favorited) {
        return a.favorited ? -1 : 1;
      }
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
      if (item.displayNameOverride?.trim().isNotEmpty == true)
        item.displayNameOverride!,
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

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
