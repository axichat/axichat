// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:convert';

import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/calendar/storage/storage_builders.dart';
import 'package:axichat/src/storage/state_store.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

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

enum CalendarSnapshotCoverageStatus {
  unknown,
  verified,
  archiveCompleteWithoutSnapshot;

  bool get isRecoveryBoundary =>
      this == CalendarSnapshotCoverageStatus.verified ||
      this == CalendarSnapshotCoverageStatus.archiveCompleteWithoutSnapshot;

  String get wireValue => name;

  static CalendarSnapshotCoverageStatus parse(String? value) {
    for (final status in CalendarSnapshotCoverageStatus.values) {
      if (status.wireValue == value) {
        return status;
      }
    }
    return CalendarSnapshotCoverageStatus.unknown;
  }
}

/// Local-only state for calendar sync, stored in [XmppStateStore].
///
/// Tracks counters and markers to avoid redundant MAM paging and
/// prevent blind overwrites during calendar rehydration.
class CalendarSyncState {
  const CalendarSyncState({
    this.schemaVersion = 4,
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
    this.snapshotCoverageStatus = CalendarSnapshotCoverageStatus.unknown,
    this.lastVerifiedSnapshotChecksum,
    this.lastVerifiedSnapshotStanzaId,
    this.lastVerifiedSnapshotAt,
  });

  /// Legacy registered key for calendar sync state persisted outside the
  /// account-scoped calendar store.
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

  final CalendarSnapshotCoverageStatus snapshotCoverageStatus;

  final String? lastVerifiedSnapshotChecksum;

  final String? lastVerifiedSnapshotStanzaId;

  final DateTime? lastVerifiedSnapshotAt;

  bool get hasCompleteCoverage => coverageStatus.isComplete;

  bool get hasVerifiedRecoveryBoundary =>
      snapshotCoverageStatus.isRecoveryBoundary;

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
    CalendarSnapshotCoverageStatus? snapshotCoverageStatus,
    Object? lastVerifiedSnapshotChecksum = _calendarSyncStateUnset,
    Object? lastVerifiedSnapshotStanzaId = _calendarSyncStateUnset,
    Object? lastVerifiedSnapshotAt = _calendarSyncStateUnset,
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
    final DateTime? resolvedLastVerifiedSnapshotAt =
        lastVerifiedSnapshotAt == _calendarSyncStateUnset
        ? this.lastVerifiedSnapshotAt
        : lastVerifiedSnapshotAt as DateTime?;
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
      snapshotCoverageStatus:
          snapshotCoverageStatus ?? this.snapshotCoverageStatus,
      lastVerifiedSnapshotChecksum:
          lastVerifiedSnapshotChecksum == _calendarSyncStateUnset
          ? this.lastVerifiedSnapshotChecksum
          : lastVerifiedSnapshotChecksum as String?,
      lastVerifiedSnapshotStanzaId:
          lastVerifiedSnapshotStanzaId == _calendarSyncStateUnset
          ? this.lastVerifiedSnapshotStanzaId
          : lastVerifiedSnapshotStanzaId as String?,
      lastVerifiedSnapshotAt: resolvedLastVerifiedSnapshotAt?.toUtc(),
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

  CalendarSyncState markSnapshotPublished(String? checksum) {
    final trimmed = checksum?.trim();
    return copyWith(
      lastSnapshotChecksum: trimmed == null || trimmed.isEmpty ? null : trimmed,
      snapshotCoverageStatus: CalendarSnapshotCoverageStatus.unknown,
      lastVerifiedSnapshotChecksum: null,
      lastVerifiedSnapshotStanzaId: null,
      lastVerifiedSnapshotAt: null,
    );
  }

  CalendarSyncState markSnapshotVerified({
    required String checksum,
    String? stanzaId,
    DateTime? verifiedAt,
  }) {
    final trimmedChecksum = checksum.trim();
    if (trimmedChecksum.isEmpty) {
      return this;
    }
    final trimmedStanzaId = stanzaId?.trim();
    return copyWith(
      lastSnapshotChecksum: trimmedChecksum,
      snapshotCoverageStatus: CalendarSnapshotCoverageStatus.verified,
      lastVerifiedSnapshotChecksum: trimmedChecksum,
      lastVerifiedSnapshotStanzaId:
          trimmedStanzaId == null || trimmedStanzaId.isEmpty
          ? null
          : trimmedStanzaId,
      lastVerifiedSnapshotAt: (verifiedAt ?? DateTime.now()).toUtc(),
    );
  }

  CalendarSyncState markArchiveCompleteWithoutSnapshot() {
    return copyWith(
      snapshotCoverageStatus:
          CalendarSnapshotCoverageStatus.archiveCompleteWithoutSnapshot,
      lastVerifiedSnapshotChecksum: null,
      lastVerifiedSnapshotStanzaId: null,
      lastVerifiedSnapshotAt: null,
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
      schemaVersion: 4,
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
      snapshotCoverageStatus: snapshotCoverageStatus,
      lastVerifiedSnapshotChecksum: lastVerifiedSnapshotChecksum,
      lastVerifiedSnapshotStanzaId: lastVerifiedSnapshotStanzaId,
      lastVerifiedSnapshotAt: lastVerifiedSnapshotAt,
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
      'snapshotCoverageStatus': snapshotCoverageStatus.wireValue,
      'lastVerifiedSnapshotChecksum': lastVerifiedSnapshotChecksum,
      'lastVerifiedSnapshotStanzaId': lastVerifiedSnapshotStanzaId,
      'lastVerifiedSnapshotAt': lastVerifiedSnapshotAt
          ?.toUtc()
          .toIso8601String(),
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
    final DateTime? lastVerifiedSnapshotAt =
        map['lastVerifiedSnapshotAt'] != null
        ? DateTime.parse(map['lastVerifiedSnapshotAt'] as String).toUtc()
        : null;
    return CalendarSyncState(
      schemaVersion: 4,
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
      snapshotCoverageStatus: schemaVersion < 4
          ? CalendarSnapshotCoverageStatus.unknown
          : CalendarSnapshotCoverageStatus.parse(
              map['snapshotCoverageStatus'] as String?,
            ),
      lastVerifiedSnapshotChecksum:
          map['lastVerifiedSnapshotChecksum'] as String?,
      lastVerifiedSnapshotStanzaId:
          map['lastVerifiedSnapshotStanzaId'] as String?,
      lastVerifiedSnapshotAt: lastVerifiedSnapshotAt,
    );
  }

  /// Reads the current personal calendar sync state from account-scoped
  /// calendar storage.
  static CalendarSyncState read() {
    return const PersonalCalendarSyncStateStore().read();
  }

  /// Reads the legacy split sync state from [XmppStateStore].
  static CalendarSyncState readLegacy() {
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

  /// Writes this state to account-scoped calendar storage.
  Future<void> write() async {
    await const PersonalCalendarSyncStateStore().write(this);
  }

  /// Writes this state to the legacy split [XmppStateStore].
  Future<void> writeLegacy() async {
    await XmppStateStore().write(key: stateKey, value: toJson());
  }

  /// Deletes the persisted state from account-scoped calendar storage.
  static Future<void> clear() async {
    await const PersonalCalendarSyncStateStore().delete();
  }

  /// Deletes the legacy split state from [XmppStateStore].
  static Future<void> clearLegacy() async {
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
        'lastSnapshotChecksum: $lastSnapshotChecksum, '
        'snapshotCoverageStatus: $snapshotCoverageStatus, '
        'lastVerifiedSnapshotChecksum: $lastVerifiedSnapshotChecksum, '
        'lastVerifiedSnapshotStanzaId: $lastVerifiedSnapshotStanzaId, '
        'lastVerifiedSnapshotAt: $lastVerifiedSnapshotAt)';
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
        other.lastSnapshotChecksum == lastSnapshotChecksum &&
        other.snapshotCoverageStatus == snapshotCoverageStatus &&
        other.lastVerifiedSnapshotChecksum == lastVerifiedSnapshotChecksum &&
        other.lastVerifiedSnapshotStanzaId == lastVerifiedSnapshotStanzaId &&
        other.lastVerifiedSnapshotAt == lastVerifiedSnapshotAt;
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
    snapshotCoverageStatus,
    lastVerifiedSnapshotChecksum,
    lastVerifiedSnapshotStanzaId,
    lastVerifiedSnapshotAt,
  );
}

class PersonalCalendarSyncStateStore {
  const PersonalCalendarSyncStateStore({Storage? storage}) : _storage = storage;

  static String get _storageKey =>
      '${authStoragePrefix}personal_calendar_sync_state_v1';

  final Storage? _storage;

  CalendarSyncState read() {
    return readOrNull() ?? const CalendarSyncState();
  }

  CalendarSyncState? readOrNull() {
    final storage = _resolvedStorage();
    if (storage == null) {
      return null;
    }
    final raw = storage.read(_storageKey);
    if (raw == null || raw is! String) {
      return null;
    }
    try {
      return CalendarSyncState.fromJson(raw);
    } on FormatException {
      return null;
    }
  }

  Future<void> write(CalendarSyncState state) async {
    final storage = _resolvedStorage();
    if (storage == null) {
      return;
    }
    await storage.write(_storageKey, state.toJson());
  }

  Future<void> delete() async {
    final storage = _resolvedStorage();
    if (storage == null) {
      return;
    }
    await storage.delete(_storageKey);
  }

  Storage? _resolvedStorage() {
    try {
      return _storage ?? HydratedBloc.storage;
    } on StorageNotFound {
      return null;
    }
  }
}

const Object _calendarSyncStateUnset = Object();
