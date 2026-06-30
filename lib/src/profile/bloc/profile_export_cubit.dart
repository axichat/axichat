// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/profile/utils/contact_exporter.dart';
import 'package:axichat/src/chats/utils/email_eml_exporter.dart';
import 'package:axichat/src/chats/utils/message_exporter.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum ProfileExportKind {
  xmppMessages,
  xmppContacts,
  emailMessages,
  emailContacts,
}

enum ProfileExportOutcome { success, empty, incomplete, failure }

extension ProfileExportOutcomeChecks on ProfileExportOutcome {
  bool get isSuccess => this == ProfileExportOutcome.success;

  bool get isEmpty => this == ProfileExportOutcome.empty;

  bool get isIncomplete => this == ProfileExportOutcome.incomplete;

  bool get isFailure => this == ProfileExportOutcome.failure;
}

class ProfileExportResult {
  const ProfileExportResult._({
    required this.kind,
    required this.outcome,
    this.file,
    this.itemCount = 0,
    this.warnings = const <String>[],
  });

  const ProfileExportResult.success({
    required ProfileExportKind kind,
    required File file,
    required int itemCount,
  }) : this._(
         kind: kind,
         outcome: ProfileExportOutcome.success,
         file: file,
         itemCount: itemCount,
       );

  const ProfileExportResult.empty({required ProfileExportKind kind})
    : this._(kind: kind, outcome: ProfileExportOutcome.empty, itemCount: 0);

  const ProfileExportResult.incomplete({
    required ProfileExportKind kind,
    File? file,
    int itemCount = 0,
    List<String> warnings = const <String>[],
  }) : this._(
         kind: kind,
         outcome: ProfileExportOutcome.incomplete,
         file: file,
         itemCount: itemCount,
         warnings: warnings,
       );

  const ProfileExportResult.failure({required ProfileExportKind kind})
    : this._(kind: kind, outcome: ProfileExportOutcome.failure, itemCount: 0);

  final ProfileExportKind kind;
  final ProfileExportOutcome outcome;
  final File? file;
  final int itemCount;
  final List<String> warnings;

  bool get hasFile => file != null;
}

class ProfileExportState {
  const ProfileExportState({
    this.status = RequestStatus.none,
    this.activeKind,
    this.completedItems = 0,
    this.totalItems = 0,
  });

  final RequestStatus status;
  final ProfileExportKind? activeKind;
  final int completedItems;
  final int totalItems;

  bool get isBusy => status.isLoading;

  ProfileExportState copyWith({
    RequestStatus? status,
    ProfileExportKind? activeKind,
    int? completedItems,
    int? totalItems,
    bool clearActiveKind = false,
    bool clearProgress = false,
  }) {
    return ProfileExportState(
      status: status ?? this.status,
      activeKind: clearActiveKind ? null : activeKind ?? this.activeKind,
      completedItems: clearProgress ? 0 : completedItems ?? this.completedItems,
      totalItems: clearProgress ? 0 : totalItems ?? this.totalItems,
    );
  }
}

class ProfileExportCubit extends Cubit<ProfileExportState> {
  ProfileExportCubit({
    required XmppService xmppService,
    EmailService? emailService,
  }) : _xmppService = xmppService,
       _emailService = emailService,
       super(const ProfileExportState());

  final XmppService _xmppService;
  final EmailService? _emailService;

  Future<ProfileExportResult> exportXmppMessages() => _runExport(
    kind: ProfileExportKind.xmppMessages,
    operation: _exportXmppMessageTranscript,
  );

  Future<ProfileExportResult> exportEmailMessages() async {
    if (_emailService == null) {
      return const ProfileExportResult.failure(
        kind: ProfileExportKind.emailMessages,
      );
    }
    return _runExport(
      kind: ProfileExportKind.emailMessages,
      operation: _exportEmailEmlMessages,
    );
  }

  Future<ProfileExportResult> exportXmppContacts(
    ContactExportFormat format,
    ContactExportLabels labels,
  ) => _runExport(
    kind: ProfileExportKind.xmppContacts,
    operation: () => _exportXmppContacts(format, labels),
  );

  Future<ProfileExportResult> exportEmailContacts(
    ContactExportFormat format,
    ContactExportLabels labels,
  ) => _runExport(
    kind: ProfileExportKind.emailContacts,
    operation: () => _exportEmailContacts(format, labels),
  );

  Future<ProfileExportResult> _runExport({
    required ProfileExportKind kind,
    required Future<ProfileExportResult> Function() operation,
  }) async {
    if (state.isBusy) {
      return ProfileExportResult.failure(kind: kind);
    }
    emit(
      state.copyWith(
        status: RequestStatus.loading,
        activeKind: kind,
        completedItems: 0,
        totalItems: 0,
      ),
    );
    try {
      final result = await operation();
      emit(
        state.copyWith(
          status: RequestStatus.none,
          clearActiveKind: true,
          clearProgress: true,
        ),
      );
      return result;
    } on EmailEmlExportEmptyException {
      emit(
        state.copyWith(
          status: RequestStatus.none,
          clearActiveKind: true,
          clearProgress: true,
        ),
      );
      return ProfileExportResult.empty(kind: kind);
    } on EmailEmlExportIncompleteException catch (error) {
      emit(
        state.copyWith(
          status: RequestStatus.none,
          clearActiveKind: true,
          clearProgress: true,
        ),
      );
      return ProfileExportResult.incomplete(
        kind: kind,
        warnings: error.warnings,
      );
    } on Exception {
      emit(
        state.copyWith(
          status: RequestStatus.none,
          clearActiveKind: true,
          clearProgress: true,
        ),
      );
      return ProfileExportResult.failure(kind: kind);
    }
  }

  Future<ProfileExportResult> _exportXmppMessageTranscript() async {
    final result = await _messageExporter().exportAllXmppMessages();
    return _profileResultFromMessageExport(
      kind: ProfileExportKind.xmppMessages,
      result: result,
    );
  }

  Future<ProfileExportResult> _exportEmailEmlMessages() async {
    final result = await _messageExporter().exportAllEmailMessages();
    return _profileResultFromMessageExport(
      kind: ProfileExportKind.emailMessages,
      result: result,
    );
  }

  MessageExporter _messageExporter() => MessageExporter(
    xmppService: _xmppService,
    emailService: _emailService,
    onEmailProgress: _updateEmailExportProgress,
  );

  ProfileExportResult _profileResultFromMessageExport({
    required ProfileExportKind kind,
    required MessageExportResult result,
  }) {
    return switch (result.outcome) {
      MessageExportOutcome.success => ProfileExportResult.success(
        kind: kind,
        file: result.file!,
        itemCount: result.itemCount,
      ),
      MessageExportOutcome.empty => ProfileExportResult.empty(kind: kind),
      MessageExportOutcome.incomplete => ProfileExportResult.incomplete(
        kind: kind,
        file: result.file,
        itemCount: result.itemCount,
        warnings: result.warnings,
      ),
      MessageExportOutcome.failure => ProfileExportResult.failure(kind: kind),
    };
  }

  void _updateEmailExportProgress(EmailEmlExportProgress progress) {
    if (!state.isBusy || state.activeKind != ProfileExportKind.emailMessages) {
      return;
    }
    emit(
      state.copyWith(
        completedItems: progress.completedItems,
        totalItems: progress.totalItems,
      ),
    );
  }

  Future<ProfileExportResult> _exportXmppContacts(
    ContactExportFormat format,
    ContactExportLabels labels,
  ) => _exportContacts(
    kind: ProfileExportKind.xmppContacts,
    transport: MessageTransport.xmpp,
    format: format,
    labels: labels,
    fileLabel: 'xmpp-contacts',
  );

  Future<ProfileExportResult> _exportEmailContacts(
    ContactExportFormat format,
    ContactExportLabels labels,
  ) => _exportContacts(
    kind: ProfileExportKind.emailContacts,
    transport: MessageTransport.email,
    format: format,
    labels: labels,
    fileLabel: 'email-contacts',
  );

  Future<ProfileExportResult> _exportContacts({
    required ProfileExportKind kind,
    required MessageTransport transport,
    required ContactExportFormat format,
    required ContactExportLabels labels,
    required String fileLabel,
  }) async {
    final directory = await _xmppService.loadContactDirectorySnapshot();
    final contacts = _sortedContacts(
      directory
          .where(
            (entry) =>
                transport.isXmpp ? entry.hasXmppRoster : entry.hasEmailContact,
          )
          .map(
            (entry) => ContactExportEntry(
              address: entry.address.trim(),
              displayName: entry.preferredDisplayName(transport),
              transport: transport,
            ),
          )
          .where((entry) => entry.address.isNotEmpty)
          .toList(growable: false),
    );
    if (contacts.isEmpty) {
      return ProfileExportResult.empty(kind: kind);
    }
    final file = await ContactExporter.exportContacts(
      contacts: contacts,
      format: format,
      fileLabel: fileLabel,
      labels: labels,
    );
    return ProfileExportResult.success(
      kind: kind,
      file: file,
      itemCount: contacts.length,
    );
  }

  List<ContactExportEntry> _sortedContacts(List<ContactExportEntry> contacts) =>
      contacts.toList()..sort((a, b) {
        final aKey = (a.displayName?.isNotEmpty == true)
            ? a.displayName!.toLowerCase()
            : a.address.toLowerCase();
        final bKey = (b.displayName?.isNotEmpty == true)
            ? b.displayName!.toLowerCase()
            : b.address.toLowerCase();
        return aKey.compareTo(bKey);
      });
}
