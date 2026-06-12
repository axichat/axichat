// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';

String contactDirectoryAddressKey(String? address) {
  final normalized =
      normalizedBareAddressValue(address) ?? normalizedAddressValue(address);
  return normalized ?? '';
}

class ContactDirectoryEntry extends Equatable {
  const ContactDirectoryEntry({
    required this.address,
    this.hasPrivateContact = false,
    required this.hasXmppRoster,
    required this.hasEmailContact,
    required this.emailNativeIds,
    this.isManualContact = false,
    this.xmppTitle,
    this.emailDisplayName,
    this.displayNameOverride,
    this.folderCollectionId,
    this.favorited = false,
    this.detailFields = const <ContactDetailFieldEntry>[],
    this.avatarPath,
    this.subscription,
  });

  final String address;
  final bool hasPrivateContact;
  final bool hasXmppRoster;
  final bool hasEmailContact;
  final List<String> emailNativeIds;
  final bool isManualContact;
  final String? xmppTitle;
  final String? emailDisplayName;
  final String? displayNameOverride;
  final String? folderCollectionId;
  final bool favorited;
  final List<ContactDetailFieldEntry> detailFields;
  final String? avatarPath;
  final Subscription? subscription;

  bool get isEmailOnly => hasEmailContact && !hasXmppRoster;

  bool get hasManualState => hasPrivateContact && isManualContact;

  String get displayName {
    final name = preferredDisplayName();
    if (name != null) {
      return name;
    }
    return address;
  }

  String? preferredDisplayName([MessageTransport? transport]) {
    final override = _trimmedOrNull(displayNameOverride);
    if (override != null) {
      return override;
    }
    if (transport == null) {
      return _trimmedOrNull(xmppTitle) ?? _trimmedOrNull(emailDisplayName);
    }
    final primary = switch (transport) {
      MessageTransport.email => _trimmedOrNull(emailDisplayName),
      _ => _trimmedOrNull(xmppTitle),
    };
    if (primary != null) {
      return primary;
    }
    return switch (transport) {
      MessageTransport.email => _trimmedOrNull(xmppTitle),
      _ => _trimmedOrNull(emailDisplayName),
    };
  }

  ContactDirectoryEntry withFavorited(bool value) => ContactDirectoryEntry(
    address: address,
    hasPrivateContact: hasPrivateContact,
    hasXmppRoster: hasXmppRoster,
    hasEmailContact: hasEmailContact,
    emailNativeIds: emailNativeIds,
    isManualContact: isManualContact,
    xmppTitle: xmppTitle,
    emailDisplayName: emailDisplayName,
    displayNameOverride: displayNameOverride,
    folderCollectionId: folderCollectionId,
    favorited: value,
    detailFields: detailFields,
    avatarPath: avatarPath,
    subscription: subscription,
  );

  @override
  List<Object?> get props => [
    address,
    hasPrivateContact,
    hasXmppRoster,
    hasEmailContact,
    emailNativeIds,
    isManualContact,
    xmppTitle,
    emailDisplayName,
    displayNameOverride,
    folderCollectionId,
    favorited,
    detailFields,
    avatarPath,
    subscription,
  ];
}

enum ContactDetailFieldKind {
  displayName,
  namePrefix,
  givenName,
  middleName,
  familyName,
  nameSuffix,
  nickname,
  organization,
  role,
  phone,
  email,
  address,
  website,
  birthday,
  note,
  customText;

  String get syncName => switch (this) {
    ContactDetailFieldKind.displayName => 'display_name',
    ContactDetailFieldKind.namePrefix => 'name_prefix',
    ContactDetailFieldKind.givenName => 'given_name',
    ContactDetailFieldKind.middleName => 'middle_name',
    ContactDetailFieldKind.familyName => 'family_name',
    ContactDetailFieldKind.nameSuffix => 'name_suffix',
    ContactDetailFieldKind.nickname => 'nickname',
    ContactDetailFieldKind.organization => 'organization',
    ContactDetailFieldKind.role => 'role',
    ContactDetailFieldKind.phone => 'phone',
    ContactDetailFieldKind.email => 'email',
    ContactDetailFieldKind.address => 'address',
    ContactDetailFieldKind.website => 'website',
    ContactDetailFieldKind.birthday => 'birthday',
    ContactDetailFieldKind.note => 'note',
    ContactDetailFieldKind.customText => 'custom_text',
  };

  static ContactDetailFieldKind? fromSyncName(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    for (final kind in values) {
      if (kind.syncName == normalized ||
          kind.name.toLowerCase() == normalized) {
        return kind;
      }
    }
    return null;
  }
}

class ContactDetailFieldEntry extends Equatable {
  const ContactDetailFieldEntry({
    required this.fieldId,
    required this.kind,
    this.label,
    required this.value,
    required this.sortOrder,
    required this.active,
    required this.updatedAt,
    this.sourceId,
  });

  final String fieldId;
  final ContactDetailFieldKind kind;
  final String? label;
  final String value;
  final int sortOrder;
  final bool active;
  final DateTime updatedAt;
  final String? sourceId;

  @override
  List<Object?> get props => [
    fieldId,
    kind,
    label,
    value,
    sortOrder,
    active,
    updatedAt,
    sourceId,
  ];
}

@DataClassName('PrivateContactRecord')
class PrivateContactRecords extends Table {
  TextColumn get addressKey => text()();

  BoolColumn get active => boolean().withDefault(const Constant(true))();

  BoolColumn get manual => boolean().withDefault(const Constant(false))();

  BoolColumn get favorited => boolean().withDefault(const Constant(false))();

  TextColumn get displayNameOverride => text().nullable()();

  TextColumn get folderCollectionId => text().nullable()();

  DateTimeColumn get activeUpdatedAt => dateTime().nullable()();

  DateTimeColumn get manualUpdatedAt => dateTime().nullable()();

  DateTimeColumn get favoriteUpdatedAt => dateTime().nullable()();

  DateTimeColumn get displayNameUpdatedAt => dateTime().nullable()();

  DateTimeColumn get folderRuleUpdatedAt => dateTime().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.timestamp().toUtc())();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.timestamp().toUtc())();

  TextColumn get sourceId => text().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {addressKey};
}

@DataClassName('PrivateContactDetailFieldEntry')
class PrivateContactDetailFields extends Table {
  TextColumn get addressKey => text()();

  TextColumn get fieldId => text()();

  IntColumn get kind => intEnum<ContactDetailFieldKind>()();

  TextColumn get label => text().nullable()();

  TextColumn get value => text()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  BoolColumn get active => boolean().withDefault(const Constant(true))();

  DateTimeColumn get updatedAt => dateTime()();

  TextColumn get sourceId => text().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {addressKey, fieldId};
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
