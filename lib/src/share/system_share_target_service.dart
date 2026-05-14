// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:convert';

import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

@immutable
final class SystemShareTarget {
  const SystemShareTarget({
    required this.jid,
    required this.label,
    required this.avatarPath,
    required this.rank,
  });

  final String jid;
  final String label;
  final String? avatarPath;
  final int rank;

  Map<String, Object?> toChannelValue() {
    return toChannelValueWithAvatarBytes();
  }

  Map<String, Object?> toChannelValueWithAvatarBytes({Uint8List? avatarBytes}) {
    return <String, Object?>{
      'jid': jid,
      'label': label,
      'avatarPath': avatarPath,
      'avatarBytes': avatarBytes,
      'rank': rank,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is SystemShareTarget &&
        jid == other.jid &&
        label == other.label &&
        avatarPath == other.avatarPath &&
        rank == other.rank;
  }

  @override
  int get hashCode => Object.hash(jid, label, avatarPath, rank);
}

class SystemShareTargetService {
  SystemShareTargetService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'im.axi.axichat/share_targets';
  static const int _fallbackMaxShareTargetCount = 4;
  static final Logger _logger = Logger('SystemShareTargetService');

  final MethodChannel _channel;
  String? _lastPublishedFingerprint;

  Future<int> getMaxShareTargetCount() async {
    if (!_isAndroid) {
      return 0;
    }
    try {
      final count = await _channel.invokeMethod<int>('getMaxShareTargetCount');
      if (count == null || count <= 0) {
        return _fallbackMaxShareTargetCount;
      }
      return count;
    } on MissingPluginException {
      return 0;
    } on PlatformException catch (error, stackTrace) {
      _logger.fine(
        'Failed to read Android share target limit.',
        error,
        stackTrace,
      );
      return _fallbackMaxShareTargetCount;
    }
  }

  Future<void> publishTargets({
    required List<Chat> chats,
    required bool smtpEnabled,
    Future<Uint8List?> Function(String path)? loadAvatarBytes,
  }) async {
    if (!_isAndroid) {
      _lastPublishedFingerprint = null;
      return;
    }
    final maxCount = await getMaxShareTargetCount();
    final targets = deriveTargets(
      chats: chats,
      smtpEnabled: smtpEnabled,
      maxCount: maxCount,
    );
    if (targets.isEmpty) {
      final fingerprint = stableFingerprint(targets);
      if (_lastPublishedFingerprint == fingerprint) {
        return;
      }
      await clearShareTargets();
      _lastPublishedFingerprint = fingerprint;
      return;
    }
    try {
      final channelTargets = await channelValuesForTargets(
        targets,
        loadAvatarBytes: loadAvatarBytes,
      );
      final fingerprint = stableChannelFingerprint(channelTargets);
      if (_lastPublishedFingerprint == fingerprint) {
        return;
      }
      await _channel.invokeMethod<void>('setShareTargets', channelTargets);
      _lastPublishedFingerprint = fingerprint;
    } on MissingPluginException {
      _lastPublishedFingerprint = null;
    } on PlatformException catch (error, stackTrace) {
      _lastPublishedFingerprint = null;
      _logger.warning(
        'Failed to publish Android share targets.',
        error,
        stackTrace,
      );
    }
  }

  static Future<List<Map<String, Object?>>> channelValuesForTargets(
    List<SystemShareTarget> targets, {
    Future<Uint8List?> Function(String path)? loadAvatarBytes,
  }) async {
    final values = <Map<String, Object?>>[];
    for (final target in targets) {
      final avatarPath = target.avatarPath;
      final avatarBytes = avatarPath == null || loadAvatarBytes == null
          ? null
          : await loadAvatarBytes(avatarPath);
      values.add(
        target.toChannelValueWithAvatarBytes(avatarBytes: avatarBytes),
      );
    }
    return List<Map<String, Object?>>.unmodifiable(values);
  }

  Future<void> clearShareTargets() async {
    _lastPublishedFingerprint = null;
    if (!_isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('clearShareTargets');
    } on MissingPluginException {
      return;
    } on PlatformException catch (error, stackTrace) {
      _logger.warning(
        'Failed to clear Android share targets.',
        error,
        stackTrace,
      );
      return;
    }
  }

  static List<SystemShareTarget> deriveTargets({
    required List<Chat> chats,
    required bool smtpEnabled,
    required int maxCount,
  }) {
    if (maxCount <= 0) {
      return const <SystemShareTarget>[];
    }
    final ranked =
        chats
            .where((chat) => isEligibleChat(chat, smtpEnabled: smtpEnabled))
            .toList(growable: false)
          ..sort((a, b) {
            final timestampOrder = b.lastChangeTimestamp.compareTo(
              a.lastChangeTimestamp,
            );
            if (timestampOrder != 0) {
              return timestampOrder;
            }
            return a.jid.compareTo(b.jid);
          });
    return ranked
        .take(maxCount)
        .indexed
        .map((entry) {
          final chat = entry.$2;
          return SystemShareTarget(
            jid: chat.jid,
            label: _targetLabelFor(chat),
            avatarPath: _targetAvatarPathFor(chat),
            rank: entry.$1,
          );
        })
        .toList(growable: false);
  }

  static String? resolveConversationTargetJid({
    required String? conversationIdentifier,
    required List<Chat> chats,
    required bool smtpEnabled,
  }) {
    final targetJid = conversationIdentifier?.trim();
    if (targetJid == null || targetJid.isEmpty) {
      return null;
    }
    for (final chat in chats) {
      if (chat.jid == targetJid &&
          isEligibleChat(chat, smtpEnabled: smtpEnabled)) {
        return chat.jid;
      }
    }
    return null;
  }

  static bool isEligibleChat(Chat chat, {required bool smtpEnabled}) {
    if (chat.hidden ||
        chat.archived ||
        chat.spam ||
        chat.isAxichatWelcomeThread) {
      return false;
    }
    if (chat.type == ChatType.note) {
      return false;
    }
    if (chat.defaultTransport.isEmail) {
      return smtpEnabled;
    }
    return chat.defaultTransport.isXmpp;
  }

  @visibleForTesting
  static String stableFingerprint(List<SystemShareTarget> targets) {
    return jsonEncode(
      targets.map((target) => target.toChannelValue()).toList(growable: false),
    );
  }

  @visibleForTesting
  static String stableChannelFingerprint(List<Map<String, Object?>> targets) {
    return jsonEncode(targets);
  }

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static String _targetLabelFor(Chat chat) {
    final label = chat.displayName.trim();
    if (label.isNotEmpty) {
      return label;
    }
    return chat.jid;
  }

  static String? _targetAvatarPathFor(Chat chat) {
    final contactAvatarPath = chat.contactAvatarPath?.trim();
    if (contactAvatarPath != null && contactAvatarPath.isNotEmpty) {
      return contactAvatarPath;
    }
    final avatarPath = chat.avatarPath?.trim();
    if (avatarPath != null && avatarPath.isNotEmpty) {
      return avatarPath;
    }
    return null;
  }
}
