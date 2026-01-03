// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:convert';

import 'package:axichat/src/storage/state_store.dart';

/// Local-only state for calendar sync, stored in [XmppStateStore].
///
/// Tracks counters and markers to avoid redundant MAM paging and
/// prevent blind overwrites during calendar rehydration.
class CalendarSyncState {
  const CalendarSyncState({
    this.updatesSinceSnapshot = 0,
    this.lastAppliedTimestamp,
    this.lastAppliedStanzaId,
    this.lastSnapshotChecksum,
  });

  /// Registered key for persisting calendar sync state.
  static final stateKey = XmppStateStore.registerKey('calendar_sync_state_v1');

  /// Number of updates (send + receive) since the last snapshot.
  final int updatesSinceSnapshot;

  /// Timestamp of the most recently applied calendar sync message.
  final DateTime? lastAppliedTimestamp;

  /// Stanza ID of the most recently applied calendar sync message.
  final String? lastAppliedStanzaId;

  /// Checksum of the most recently applied snapshot.
  final String? lastSnapshotChecksum;

  /// Creates a copy with the specified fields replaced.
  CalendarSyncState copyWith({
    int? updatesSinceSnapshot,
    DateTime? lastAppliedTimestamp,
    String? lastAppliedStanzaId,
    String? lastSnapshotChecksum,
  }) {
    return CalendarSyncState(
      updatesSinceSnapshot: updatesSinceSnapshot ?? this.updatesSinceSnapshot,
      lastAppliedTimestamp: lastAppliedTimestamp ?? this.lastAppliedTimestamp,
      lastAppliedStanzaId: lastAppliedStanzaId ?? this.lastAppliedStanzaId,
      lastSnapshotChecksum: lastSnapshotChecksum ?? this.lastSnapshotChecksum,
    );
  }

  /// Increments the update counter by one.
  CalendarSyncState incrementCounter() {
    return copyWith(updatesSinceSnapshot: updatesSinceSnapshot + 1);
  }

  /// Resets the update counter to zero (typically after a snapshot).
  CalendarSyncState resetCounter() {
    return copyWith(updatesSinceSnapshot: 0);
  }

  /// Clears the timestamp and stanza ID fields for nullable replacement.
  CalendarSyncState clearTimestamp() {
    return CalendarSyncState(
      updatesSinceSnapshot: updatesSinceSnapshot,
      lastSnapshotChecksum: lastSnapshotChecksum,
    );
  }

  /// Serializes this state to a JSON-encoded string.
  String toJson() {
    return jsonEncode(<String, dynamic>{
      'updatesSinceSnapshot': updatesSinceSnapshot,
      'lastAppliedTimestamp': lastAppliedTimestamp?.toIso8601String(),
      'lastAppliedStanzaId': lastAppliedStanzaId,
      'lastSnapshotChecksum': lastSnapshotChecksum,
    });
  }

  /// Deserializes from a JSON-encoded string.
  factory CalendarSyncState.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    return CalendarSyncState(
      updatesSinceSnapshot: map['updatesSinceSnapshot'] as int? ?? 0,
      lastAppliedTimestamp: map['lastAppliedTimestamp'] != null
          ? DateTime.parse(map['lastAppliedTimestamp'] as String)
          : null,
      lastAppliedStanzaId: map['lastAppliedStanzaId'] as String?,
      lastSnapshotChecksum: map['lastSnapshotChecksum'] as String?,
    );
  }

  /// Reads the current state from [XmppStateStore].
  static CalendarSyncState read() {
    final raw = XmppStateStore().read(key: stateKey);
    if (raw == null || raw is! String) {
      return const CalendarSyncState();
    }
    try {
      return CalendarSyncState.fromJson(raw);
    } on FormatException {
      return const CalendarSyncState();
    }
  }

  /// Writes this state to [XmppStateStore].
  Future<void> write() async {
    await XmppStateStore().write(key: stateKey, value: toJson());
  }

  /// Deletes the persisted state from [XmppStateStore].
  static Future<void> clear() async {
    await XmppStateStore().delete(key: stateKey);
  }

  @override
  String toString() {
    return 'CalendarSyncState('
        'updatesSinceSnapshot: $updatesSinceSnapshot, '
        'lastAppliedTimestamp: $lastAppliedTimestamp, '
        'lastAppliedStanzaId: $lastAppliedStanzaId, '
        'lastSnapshotChecksum: $lastSnapshotChecksum)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalendarSyncState &&
        other.updatesSinceSnapshot == updatesSinceSnapshot &&
        other.lastAppliedTimestamp == lastAppliedTimestamp &&
        other.lastAppliedStanzaId == lastAppliedStanzaId &&
        other.lastSnapshotChecksum == lastSnapshotChecksum;
  }

  @override
  int get hashCode => Object.hash(
        updatesSinceSnapshot,
        lastAppliedTimestamp,
        lastAppliedStanzaId,
        lastSnapshotChecksum,
      );
}
