// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:equatable/equatable.dart';

enum AvatarPresentationKind { avatar, appIcon }

typedef AvatarKind = AvatarPresentationKind;

class AvatarPresentation extends Equatable {
  const AvatarPresentation.appIcon({
    required this.label,
    required this.colorSeed,
  }) : kind = AvatarPresentationKind.appIcon,
       _avatar = null,
       loading = false;

  const AvatarPresentation.avatar({
    required this.label,
    required this.colorSeed,
    Avatar? avatar,
    required this.loading,
  }) : kind = AvatarPresentationKind.avatar,
       _avatar = avatar;

  final AvatarPresentationKind kind;
  final String label;
  final String colorSeed;
  final Avatar? _avatar;
  final bool loading;

  bool get isAppIcon => kind == AvatarPresentationKind.appIcon;

  Avatar? get avatar => _avatar;

  String? get avatarPath => avatar?.path;

  @override
  List<Object?> get props => [kind, label, colorSeed, avatar, loading];
}

class SelfAvatar extends Equatable {
  const SelfAvatar({this.jid, this.avatar, this.hydrating = false});

  final String? jid;
  final Avatar? avatar;
  final bool hydrating;

  @override
  List<Object?> get props => [jid, avatar, hydrating];
}

extension ChatAvatarPresentation on Chat {
  bool isSelfAvatarChat(SelfAvatar? selfAvatar) {
    return remoteJid.sameBare(selfAvatar?.jid?.trim());
  }

  Avatar? get effectiveAvatar {
    final primary = avatarPath?.trim();
    if (primary != null && primary.isNotEmpty) {
      return Avatar(path: primary, hash: avatarHash?.trim());
    }
    final contact = contactAvatarPath?.trim();
    if (contact != null && contact.isNotEmpty) {
      return Avatar(path: contact, hash: null);
    }
    return null;
  }

  String get avatarLabel {
    final displayName = contactDisplayName?.trim();
    if (displayName?.isNotEmpty == true) {
      return displayName!;
    }
    final titleText = title.trim();
    if (titleText.isNotEmpty) {
      return titleText;
    }
    final address = emailAddress?.trim();
    if (address?.isNotEmpty == true) {
      return address!;
    }
    final contact = contactJid?.trim();
    if (contact?.isNotEmpty == true) {
      return contact!;
    }
    return remoteJid;
  }

  String get avatarColorSeed {
    final address = emailAddress?.trim();
    if (address?.isNotEmpty == true) {
      return address!;
    }
    final fromAddress = emailFromAddress?.trim();
    if (fromAddress?.isNotEmpty == true) {
      return fromAddress!;
    }
    final contact = contactJid?.trim();
    if (contact?.isNotEmpty == true) {
      return contact!;
    }
    final remote = remoteJid.trim();
    if (remote.isNotEmpty) {
      return remote;
    }
    return avatarLabel;
  }

  Avatar? resolvedAvatar({SelfAvatar? selfAvatar, Avatar? avatarOverride}) {
    if (avatarOverride != null) {
      return avatarOverride;
    }
    final resolvedSelfAvatar = selfAvatar?.avatar;
    if (isSelfAvatarChat(selfAvatar) && resolvedSelfAvatar != null) {
      return resolvedSelfAvatar;
    }
    return effectiveAvatar;
  }

  bool resolvedAvatarHydrating(SelfAvatar? selfAvatar) {
    return isSelfAvatarChat(selfAvatar) && (selfAvatar?.hydrating ?? false);
  }

  AvatarPresentation avatarPresentation({
    SelfAvatar? selfAvatar,
    Avatar? avatarOverride,
  }) {
    if (isAxichatWelcomeThread) {
      return AvatarPresentation.appIcon(
        label: avatarLabel,
        colorSeed: avatarColorSeed,
      );
    }
    return AvatarPresentation.avatar(
      label: avatarLabel,
      colorSeed: avatarColorSeed,
      avatar: resolvedAvatar(
        selfAvatar: selfAvatar,
        avatarOverride: avatarOverride,
      ),
      loading: resolvedAvatarHydrating(selfAvatar),
    );
  }

  String? get effectiveAvatarPath => effectiveAvatar?.path;
}
