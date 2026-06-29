// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:convert';

import 'package:axichat/src/common/address_tools.dart';

enum ForegroundNotificationPreviewSetting {
  show,
  hide;

  static ForegroundNotificationPreviewSetting? fromName(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    for (final setting in values) {
      if (setting.name == normalized) {
        return setting;
      }
    }
    return null;
  }

  bool resolve(bool globalPreviewsEnabled) {
    return switch (this) {
      ForegroundNotificationPreviewSetting.show => true,
      ForegroundNotificationPreviewSetting.hide => false,
    };
  }
}

enum ForegroundChatNotificationBehavior {
  muted,
  alwaysNotify;

  static ForegroundChatNotificationBehavior? fromName(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    for (final behavior in values) {
      if (behavior.name == normalized) {
        return behavior;
      }
    }
    return null;
  }

  bool get isMuted => this == ForegroundChatNotificationBehavior.muted;

  bool get isAlwaysNotify =>
      this == ForegroundChatNotificationBehavior.alwaysNotify;
}

final class ForegroundNotificationStrings {
  const ForegroundNotificationStrings({
    required this.channelMessages,
    required this.newMessageTitle,
    required this.newEmailTitle,
    required this.openAction,
    required this.appTitle,
  });

  const ForegroundNotificationStrings.empty()
    : channelMessages = '',
      newMessageTitle = '',
      newEmailTitle = '',
      openAction = '',
      appTitle = '';

  final String channelMessages;
  final String newMessageTitle;
  final String newEmailTitle;
  final String openAction;
  final String appTitle;

  bool get hasMessageLabels =>
      channelMessages.trim().isNotEmpty && newMessageTitle.trim().isNotEmpty;

  bool get hasEmailLabels =>
      channelMessages.trim().isNotEmpty && newEmailTitle.trim().isNotEmpty;

  @override
  bool operator ==(Object other) {
    return other is ForegroundNotificationStrings &&
        other.channelMessages == channelMessages &&
        other.newMessageTitle == newMessageTitle &&
        other.newEmailTitle == newEmailTitle &&
        other.openAction == openAction &&
        other.appTitle == appTitle;
  }

  @override
  int get hashCode => Object.hash(
    channelMessages,
    newMessageTitle,
    newEmailTitle,
    openAction,
    appTitle,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'channelMessages': channelMessages,
    'newMessageTitle': newMessageTitle,
    'newEmailTitle': newEmailTitle,
    'openAction': openAction,
    'appTitle': appTitle,
  };

  static ForegroundNotificationStrings fromJson(Map<String, Object?> json) {
    return ForegroundNotificationStrings(
      channelMessages: _stringValue(json['channelMessages']),
      newMessageTitle: _stringValue(json['newMessageTitle']),
      newEmailTitle: _stringValue(json['newEmailTitle']),
      openAction: _stringValue(json['openAction']),
      appTitle: _stringValue(json['appTitle']),
    );
  }
}

final class ForegroundChatNotificationPolicy {
  ForegroundChatNotificationPolicy({
    required Iterable<String> addressKeys,
    required this.title,
    required this.threadKey,
    required this.isGroupConversation,
    required this.myNickname,
    required this.previewSetting,
    required this.notificationBehavior,
  }) : addressKeys = List<String>.unmodifiable(
         addressKeys
             .map(normalizedAddressKey)
             .whereType<String>()
             .where((key) => key.isNotEmpty)
             .toSet(),
       );

  final List<String> addressKeys;
  final String title;
  final String threadKey;
  final bool isGroupConversation;
  final String? myNickname;
  final ForegroundNotificationPreviewSetting? previewSetting;
  final ForegroundChatNotificationBehavior? notificationBehavior;

  bool matches(String rawJid) {
    final key = normalizedAddressKey(rawJid);
    return key != null && addressKeys.contains(key);
  }

  bool allowsNotification({required bool globalChatNotificationsMuted}) {
    final behavior = notificationBehavior;
    if (behavior?.isMuted ?? false) {
      return false;
    }
    if (globalChatNotificationsMuted && !(behavior?.isAlwaysNotify ?? false)) {
      return false;
    }
    return true;
  }

  bool resolvePreviews(bool globalPreviewsEnabled) {
    return previewSetting?.resolve(globalPreviewsEnabled) ??
        globalPreviewsEnabled;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'addressKeys': addressKeys,
    'title': title,
    'threadKey': threadKey,
    'isGroupConversation': isGroupConversation,
    'myNickname': myNickname,
    'previewSetting': previewSetting?.name,
    'notificationBehavior': notificationBehavior?.name,
  };

  static ForegroundChatNotificationPolicy? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return null;
    }
    final rawKeys = raw['addressKeys'];
    final keys = rawKeys is List
        ? rawKeys.whereType<String>()
        : const Iterable<String>.empty();
    return ForegroundChatNotificationPolicy(
      addressKeys: keys,
      title: _stringValue(raw['title']),
      threadKey: _stringValue(raw['threadKey']),
      isGroupConversation: raw['isGroupConversation'] == true,
      myNickname: _nullableStringValue(raw['myNickname']),
      previewSetting: ForegroundNotificationPreviewSetting.fromName(
        _nullableStringValue(raw['previewSetting']),
      ),
      notificationBehavior: ForegroundChatNotificationBehavior.fromName(
        _nullableStringValue(raw['notificationBehavior']),
      ),
    );
  }
}

final class ForegroundNotificationSnapshot {
  ForegroundNotificationSnapshot({
    required this.accountJid,
    required this.backgroundMessageNotificationsEnabled,
    required this.chatNotificationsMuted,
    required this.emailNotificationsMuted,
    required this.notificationPreviewsEnabled,
    required this.strings,
    required Iterable<ForegroundChatNotificationPolicy> chatPolicies,
    Iterable<String> blockedJids = const <String>[],
  }) : chatPolicies = List<ForegroundChatNotificationPolicy>.unmodifiable(
         chatPolicies,
       ),
       blockedJids = Set<String>.unmodifiable(
         blockedJids.map(normalizedBareAddressValue).whereType<String>(),
       );

  final String? accountJid;
  final bool backgroundMessageNotificationsEnabled;
  final bool chatNotificationsMuted;
  final bool emailNotificationsMuted;
  final bool notificationPreviewsEnabled;
  final ForegroundNotificationStrings strings;
  final List<ForegroundChatNotificationPolicy> chatPolicies;
  final Set<String> blockedJids;

  ForegroundChatNotificationPolicy? policyFor(String rawJid) {
    for (final policy in chatPolicies) {
      if (policy.matches(rawJid)) {
        return policy;
      }
    }
    return null;
  }

  bool blocksInboundSender(String rawJid) {
    final key = normalizedBareAddressValue(rawJid);
    return key != null && blockedJids.contains(key);
  }

  String encode() => jsonEncode(toJson());

  Map<String, Object?> toJson() => <String, Object?>{
    'version': 1,
    'accountJid': accountJid,
    'backgroundMessageNotificationsEnabled':
        backgroundMessageNotificationsEnabled,
    'chatNotificationsMuted': chatNotificationsMuted,
    'emailNotificationsMuted': emailNotificationsMuted,
    'notificationPreviewsEnabled': notificationPreviewsEnabled,
    'strings': strings.toJson(),
    'chatPolicies': [for (final policy in chatPolicies) policy.toJson()],
    'blockedJids': blockedJids.toList(growable: false),
  };

  static ForegroundNotificationSnapshot? tryDecode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      return fromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  static ForegroundNotificationSnapshot fromJson(Map<String, Object?> json) {
    final rawStrings = json['strings'];
    final rawPolicies = json['chatPolicies'];
    final rawBlockedJids = json['blockedJids'];
    return ForegroundNotificationSnapshot(
      accountJid: _nullableStringValue(json['accountJid']),
      backgroundMessageNotificationsEnabled:
          json['backgroundMessageNotificationsEnabled'] == true,
      chatNotificationsMuted: json['chatNotificationsMuted'] == true,
      emailNotificationsMuted: json['emailNotificationsMuted'] == true,
      notificationPreviewsEnabled: json['notificationPreviewsEnabled'] == true,
      strings: rawStrings is Map<String, Object?>
          ? ForegroundNotificationStrings.fromJson(rawStrings)
          : const ForegroundNotificationStrings.empty(),
      chatPolicies: rawPolicies is List
          ? rawPolicies
                .map(ForegroundChatNotificationPolicy.fromJson)
                .whereType<ForegroundChatNotificationPolicy>()
          : const Iterable<ForegroundChatNotificationPolicy>.empty(),
      blockedJids: rawBlockedJids is List
          ? rawBlockedJids.whereType<String>()
          : const Iterable<String>.empty(),
    );
  }
}

String? foregroundNotificationStanzaDedupeKey(String? stanzaId) {
  final normalized = stanzaId?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return 'stanza:$normalized';
}

String? foregroundNotificationMailPushDedupeKey(String? stanzaId) {
  final normalized = stanzaId?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return 'mail-push-stanza:$normalized';
}

int foregroundNotificationStableId(String key) {
  var hash = 0x811c9dc5;
  for (final codeUnit in key.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return (hash & 0x7fffffff) + 1;
}

String _stringValue(Object? value) => value is String ? value : '';

String? _nullableStringValue(Object? value) {
  if (value is! String) {
    return null;
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
