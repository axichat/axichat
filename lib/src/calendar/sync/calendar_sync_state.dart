// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:convert';

import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/storage/state_store.dart';

enum CalendarArchiveCoverageStatus {
  unknown,
  incomplete,
  complete;

  bool get isComplete => this == CalendarArchiveCoverageStatus.complete;

  String get wireValue => name;

  static CalendarArchiveCoverageStatus parse(String? value) {
    for (final status in CalendarArchiveCoverageStatus.values) {
      if (status.wireValue == value) {
        return status;
      }
    }
    return CalendarArchiveCoverageStatus.unknown;
  }
}

/// Local-only state for calendar sync, stored in [XmppStateStore].
///
/// Tracks counters and markers to avoid redundant MAM paging and
/// prevent blind overwrites during calendar rehydration.
class CalendarSyncState {
  const CalendarSyncState({
    this.schemaVersion = 3,
    this.updatesSinceSnapshot = 0,
    this.lastAppliedTimestamp,
    this.lastAppliedStanzaId,
    this.lastHandledTimestamp,
    this.lastHandledStanzaId,
    this.lastArchiveResumeId,
    this.lastCoverageCompletedAt,
    this.calendarJid,
    this.archiveJid,
    this.coverageStatus = CalendarArchiveCoverageStatus.unknown,
    this.lastSnapshotChecksum,
  });

  /// Registered key for persisting calendar sync state.
  static final stateKey = XmppStateStore.registerKey('calendar_sync_state_v1');
  static const Duration _futureTimestampTolerance = Duration(minutes: 2);

  final int schemaVersion;

  /// Number of updates (send + receive) since the last snapshot.
  final int updatesSinceSnapshot;

  /// Legacy mutation cursor. Kept for migration and old callers only.
  final DateTime? lastAppliedTimestamp;

  /// Legacy mutation cursor. Kept for migration and old callers only.
  final String? lastAppliedStanzaId;

  /// Timestamp of the most recently handled archive envelope.
  final DateTime? lastHandledTimestamp;

  /// Stanza ID or MAM ID of the most recently handled archive envelope.
  final String? lastHandledStanzaId;

  /// RSM UID of the newest MAM page boundary that was fully handled.
  final String? lastArchiveResumeId;

  /// Time when this calendar last reached a MAM completion boundary.
  final DateTime? lastCoverageCompletedAt;

  /// Normalized bare JID of the calendar this state belongs to.
  final String? calendarJid;

  /// Normalized bare JID of the archive scope that produced the cursor.
  final String? archiveJid;

  final CalendarArchiveCoverageStatus coverageStatus;

  /// Checksum of the most recently applied snapshot.
  final String? lastSnapshotChecksum;

  bool get hasCompleteCoverage => coverageStatus.isComplete;

  DateTime? get recoveryTimestamp =>
      lastHandledTimestamp ?? lastAppliedTimestamp;

  /// Creates a copy with the specified fields replaced.
  CalendarSyncState copyWith({
    int? schemaVersion,
    int? updatesSinceSnapshot,
    Object? lastAppliedTimestamp = _calendarSyncStateUnset,
    Object? lastAppliedStanzaId = _calendarSyncStateUnset,
    Object? lastHandledTimestamp = _calendarSyncStateUnset,
    Object? lastHandledStanzaId = _calendarSyncStateUnset,
    Object? lastArchiveResumeId = _calendarSyncStateUnset,
    Object? lastCoverageCompletedAt = _calendarSyncStateUnset,
    Object? calendarJid = _calendarSyncStateUnset,
    Object? archiveJid = _calendarSyncStateUnset,
    CalendarArchiveCoverageStatus? coverageStatus,
    Object? lastSnapshotChecksum = _calendarSyncStateUnset,
  }) {
    final DateTime? resolvedLastAppliedTimestamp =
        lastAppliedTimestamp == _calendarSyncStateUnset
        ? this.lastAppliedTimestamp
        : lastAppliedTimestamp as DateTime?;
    final DateTime? resolvedLastHandledTimestamp =
        lastHandledTimestamp == _calendarSyncStateUnset
        ? this.lastHandledTimestamp
        : lastHandledTimestamp as DateTime?;
    final DateTime? resolvedLastCoverageCompletedAt =
        lastCoverageCompletedAt == _calendarSyncStateUnset
        ? this.lastCoverageCompletedAt
        : lastCoverageCompletedAt as DateTime?;
    return CalendarSyncState(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      updatesSinceSnapshot: updatesSinceSnapshot ?? this.updatesSinceSnapshot,
      lastAppliedTimestamp: resolvedLastAppliedTimestamp?.toUtc(),
      lastAppliedStanzaId: lastAppliedStanzaId == _calendarSyncStateUnset
          ? this.lastAppliedStanzaId
          : lastAppliedStanzaId as String?,
      lastHandledTimestamp: resolvedLastHandledTimestamp?.toUtc(),
      lastHandledStanzaId: lastHandledStanzaId == _calendarSyncStateUnset
          ? this.lastHandledStanzaId
          : lastHandledStanzaId as String?,
      lastArchiveResumeId: lastArchiveResumeId == _calendarSyncStateUnset
          ? this.lastArchiveResumeId
          : lastArchiveResumeId as String?,
      lastCoverageCompletedAt: resolvedLastCoverageCompletedAt?.toUtc(),
      calendarJid: calendarJid == _calendarSyncStateUnset
          ? this.calendarJid
          : calendarJid as String?,
      archiveJid: archiveJid == _calendarSyncStateUnset
          ? this.archiveJid
          : archiveJid as String?,
      coverageStatus: coverageStatus ?? this.coverageStatus,
      lastSnapshotChecksum: lastSnapshotChecksum == _calendarSyncStateUnset
          ? this.lastSnapshotChecksum
          : lastSnapshotChecksum as String?,
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

  CalendarSyncState markHandled(CalendarSyncInbound inbound) {
    final rawPrevious = lastHandledTimestamp ?? lastAppliedTimestamp;
    final previous = rawPrevious == null
        ? null
        : _boundCursorTimestamp(rawPrevious);
    final candidate = _boundCursorTimestamp(
      inbound.receivedAt ?? DateTime.now().toUtc(),
    );
    final normalizedState =
        previous == null ||
            (rawPrevious != null &&
                previous.microsecondsSinceEpoch ==
                    rawPrevious.toUtc().microsecondsSinceEpoch)
        ? this
        : copyWith(
            lastAppliedTimestamp: previous,
            lastHandledTimestamp: previous,
          );
    final shouldAdvance =
        previous == null ||
        candidate.isAfter(previous) ||
        (candidate.isAtSameMomentAs(previous) &&
            inbound.stanzaId != null &&
            inbound.stanzaId != lastHandledStanzaId);
    final handledTimestamp = shouldAdvance
        ? candidate
        : normalizedState.lastHandledTimestamp ??
              normalizedState.lastAppliedTimestamp;
    final handledStanzaId = shouldAdvance
        ? inbound.stanzaId
        : normalizedState.lastHandledStanzaId ??
              normalizedState.lastAppliedStanzaId;
    return normalizedState.copyWith(
      lastAppliedTimestamp: handledTimestamp,
      lastAppliedStanzaId: handledStanzaId,
      lastHandledTimestamp: handledTimestamp,
      lastHandledStanzaId: handledStanzaId,
      coverageStatus: CalendarArchiveCoverageStatus.incomplete,
    );
  }

  static DateTime _boundCursorTimestamp(DateTime value) {
    final normalized = value.toUtc();
    final now = DateTime.now().toUtc();
    final maxFuture = now.add(_futureTimestampTolerance);
    if (normalized.isAfter(maxFuture)) {
      return now;
    }
    return normalized;
  }

  CalendarSyncState markCoverageComplete({
    DateTime? completedAt,
    String? calendarJid,
    String? archiveJid,
  }) {
    return copyWith(
      calendarJid: calendarJid,
      archiveJid: archiveJid,
      coverageStatus: CalendarArchiveCoverageStatus.complete,
      lastCoverageCompletedAt: (completedAt ?? DateTime.now()).toUtc(),
    );
  }

  CalendarSyncState markArchivePageHandled({
    required String resumeId,
    String? calendarJid,
    String? archiveJid,
  }) {
    final trimmed = resumeId.trim();
    if (trimmed.isEmpty) {
      return this;
    }
    return copyWith(
      schemaVersion: 3,
      lastArchiveResumeId: trimmed,
      calendarJid: calendarJid,
      archiveJid: archiveJid,
      coverageStatus: CalendarArchiveCoverageStatus.incomplete,
    );
  }

  CalendarSyncState markCoverageIncomplete() {
    return copyWith(coverageStatus: CalendarArchiveCoverageStatus.incomplete);
  }

  /// Clears the timestamp and stanza ID fields for nullable replacement.
  CalendarSyncState clearTimestamp() {
    return CalendarSyncState(
      schemaVersion: schemaVersion,
      updatesSinceSnapshot: updatesSinceSnapshot,
      lastArchiveResumeId: lastArchiveResumeId,
      lastCoverageCompletedAt: lastCoverageCompletedAt,
      calendarJid: calendarJid,
      archiveJid: archiveJid,
      coverageStatus: coverageStatus,
      lastSnapshotChecksum: lastSnapshotChecksum,
    );
  }

  /// Serializes this state to a JSON-encoded string.
  String toJson() {
    return jsonEncode(<String, dynamic>{
      'schemaVersion': schemaVersion,
      'updatesSinceSnapshot': updatesSinceSnapshot,
      'lastAppliedTimestamp': lastAppliedTimestamp?.toUtc().toIso8601String(),
      'lastAppliedStanzaId': lastAppliedStanzaId,
      'lastHandledTimestamp': lastHandledTimestamp?.toUtc().toIso8601String(),
      'lastHandledStanzaId': lastHandledStanzaId,
      'lastArchiveResumeId': lastArchiveResumeId,
      'lastCoverageCompletedAt': lastCoverageCompletedAt
          ?.toUtc()
          .toIso8601String(),
      'calendarJid': calendarJid,
      'archiveJid': archiveJid,
      'coverageStatus': coverageStatus.wireValue,
      'lastSnapshotChecksum': lastSnapshotChecksum,
    });
  }

  /// Deserializes from a JSON-encoded string.
  factory CalendarSyncState.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    final schemaVersion = map['schemaVersion'] as int? ?? 1;
    final DateTime? lastAppliedTimestamp = map['lastAppliedTimestamp'] != null
        ? DateTime.parse(map['lastAppliedTimestamp'] as String).toUtc()
        : null;
    final DateTime? lastHandledTimestamp = map['lastHandledTimestamp'] != null
        ? DateTime.parse(map['lastHandledTimestamp'] as String).toUtc()
        : null;
    final DateTime? lastCoverageCompletedAt =
        map['lastCoverageCompletedAt'] != null
        ? DateTime.parse(map['lastCoverageCompletedAt'] as String).toUtc()
        : null;
    return CalendarSyncState(
      schemaVersion: 3,
      updatesSinceSnapshot: map['updatesSinceSnapshot'] as int? ?? 0,
      lastAppliedTimestamp: lastAppliedTimestamp,
      lastAppliedStanzaId: map['lastAppliedStanzaId'] as String?,
      lastHandledTimestamp: lastHandledTimestamp,
      lastHandledStanzaId: map['lastHandledStanzaId'] as String?,
      lastArchiveResumeId: map['lastArchiveResumeId'] as String?,
      lastCoverageCompletedAt: lastCoverageCompletedAt,
      calendarJid: map['calendarJid'] as String?,
      archiveJid: map['archiveJid'] as String?,
      coverageStatus: schemaVersion < 2
          ? CalendarArchiveCoverageStatus.unknown
          : CalendarArchiveCoverageStatus.parse(
              map['coverageStatus'] as String?,
            ),
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
        'schemaVersion: $schemaVersion, '
        'updatesSinceSnapshot: $updatesSinceSnapshot, '
        'lastAppliedTimestamp: $lastAppliedTimestamp, '
        'lastAppliedStanzaId: $lastAppliedStanzaId, '
        'lastHandledTimestamp: $lastHandledTimestamp, '
        'lastHandledStanzaId: $lastHandledStanzaId, '
        'lastArchiveResumeId: $lastArchiveResumeId, '
        'lastCoverageCompletedAt: $lastCoverageCompletedAt, '
        'calendarJid: $calendarJid, '
        'archiveJid: $archiveJid, '
        'coverageStatus: $coverageStatus, '
        'lastSnapshotChecksum: $lastSnapshotChecksum)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalendarSyncState &&
        other.schemaVersion == schemaVersion &&
        other.updatesSinceSnapshot == updatesSinceSnapshot &&
        other.lastAppliedTimestamp == lastAppliedTimestamp &&
        other.lastAppliedStanzaId == lastAppliedStanzaId &&
        other.lastHandledTimestamp == lastHandledTimestamp &&
        other.lastHandledStanzaId == lastHandledStanzaId &&
        other.lastArchiveResumeId == lastArchiveResumeId &&
        other.lastCoverageCompletedAt == lastCoverageCompletedAt &&
        other.calendarJid == calendarJid &&
        other.archiveJid == archiveJid &&
        other.coverageStatus == coverageStatus &&
        other.lastSnapshotChecksum == lastSnapshotChecksum;
  }

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    updatesSinceSnapshot,
    lastAppliedTimestamp,
    lastAppliedStanzaId,
    lastHandledTimestamp,
    lastHandledStanzaId,
    lastArchiveResumeId,
    lastCoverageCompletedAt,
    calendarJid,
    archiveJid,
    coverageStatus,
    lastSnapshotChecksum,
  );
}

const Object _calendarSyncStateUnset = Object();
