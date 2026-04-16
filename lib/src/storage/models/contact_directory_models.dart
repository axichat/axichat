// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:equatable/equatable.dart';

String contactDirectoryAddressKey(String? address) {
  final normalized =
      normalizedBareAddressValue(address) ?? normalizedAddressValue(address);
  return normalized ?? '';
}

class ContactDirectoryEntry extends Equatable {
  const ContactDirectoryEntry({
    required this.address,
    required this.hasXmppRoster,
    required this.hasEmailContact,
    required this.emailNativeIds,
    this.xmppTitle,
    this.emailDisplayName,
    this.avatarPath,
    this.subscription,
  });

  final String address;
  final bool hasXmppRoster;
  final bool hasEmailContact;
  final List<String> emailNativeIds;
  final String? xmppTitle;
  final String? emailDisplayName;
  final String? avatarPath;
  final Subscription? subscription;

  bool get isEmailOnly => hasEmailContact && !hasXmppRoster;

  String get displayName {
    final name = preferredDisplayName();
    if (name != null) {
      return name;
    }
    return address;
  }

  String? preferredDisplayName([MessageTransport? transport]) {
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

  @override
  List<Object?> get props => [
    address,
    hasXmppRoster,
    hasEmailContact,
    emailNativeIds,
    xmppTitle,
    emailDisplayName,
    avatarPath,
    subscription,
  ];
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
