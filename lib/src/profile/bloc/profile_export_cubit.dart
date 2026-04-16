// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/chats/utils/chat_history_exporter.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/profile/utils/contact_exporter.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;

enum ProfileExportKind {
  xmppMessages,
  xmppContacts,
  emailMessages,
  emailContacts,
}

enum ProfileExportOutcome { success, empty, failure }

extension ProfileExportOutcomeChecks on ProfileExportOutcome {
  bool get isSuccess => this == ProfileExportOutcome.success;

  bool get isEmpty => this == ProfileExportOutcome.empty;

  bool get isFailure => this == ProfileExportOutcome.failure;
}

class ProfileExportResult {
  const ProfileExportResult._({
    required this.kind,
    required this.outcome,
    this.file,
    this.itemCount = 0,
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

  const ProfileExportResult.failure({required ProfileExportKind kind})
    : this._(kind: kind, outcome: ProfileExportOutcome.failure, itemCount: 0);

  final ProfileExportKind kind;
  final ProfileExportOutcome outcome;
  final File? file;
  final int itemCount;

  bool get hasFile => file != null;
}

class ProfileExportState {
  const ProfileExportState({this.status = RequestStatus.none, this.activeKind});

  final RequestStatus status;
  final ProfileExportKind? activeKind;

  bool get isBusy => status.isLoading;

  ProfileExportState copyWith({
    RequestStatus? status,
    ProfileExportKind? activeKind,
    bool clearActiveKind = false,
  }) {
    return ProfileExportState(
      status: status ?? this.status,
      activeKind: clearActiveKind ? null : activeKind ?? this.activeKind,
    );
  }
}

class EmailMessageLineLabels {
  const EmailMessageLineLabels({required this.subjectLabel});

  final String subjectLabel;
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
    operation: () => _exportMessages(
      kind: ProfileExportKind.xmppMessages,
      transport: MessageTransport.xmpp,
      fileLabel: 'xmpp-messages',
      lineFormatter: null,
    ),
  );

  Future<ProfileExportResult> exportEmailMessages(
    EmailMessageLineLabels labels,
  ) async {
    if (_emailService == null) {
      return const ProfileExportResult.failure(
        kind: ProfileExportKind.emailMessages,
      );
    }
    return _runExport(
      kind: ProfileExportKind.emailMessages,
      operation: () => _exportMessages(
        kind: ProfileExportKind.emailMessages,
        transport: MessageTransport.email,
        fileLabel: 'email-messages',
        lineFormatter:
            ({
              required Chat chat,
              required Message message,
              required intl.DateFormat format,
            }) => _formatEmailMessageLine(
              chat: chat,
              message: message,
              format: format,
              labels: labels,
            ),
      ),
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
    emit(state.copyWith(status: RequestStatus.loading, activeKind: kind));
    try {
      final result = await operation();
      emit(state.copyWith(status: RequestStatus.none, clearActiveKind: true));
      return result;
    } on Exception {
      emit(state.copyWith(status: RequestStatus.none, clearActiveKind: true));
      return ProfileExportResult.failure(kind: kind);
    }
  }

  Future<ProfileExportResult> _exportMessages({
    required ProfileExportKind kind,
    required MessageTransport transport,
    required String fileLabel,
    String? Function({
      required Chat chat,
      required Message message,
      required intl.DateFormat format,
    })?
    lineFormatter,
  }) async {
    const int chatExportStart = 0;
    const int chatExportEnd = 0;
    final chats = await _xmppService.loadChats(
      start: chatExportStart,
      end: chatExportEnd,
    );
    final selectedChats = chats
        .where((chat) => chat.transport == transport)
        .toList(growable: false);
    if (selectedChats.isEmpty) {
      return ProfileExportResult.empty(kind: kind);
    }
    final exportResult = await ChatHistoryExporter.exportChats(
      chats: selectedChats,
      loadHistory: (jid) => _xmppService.loadCompleteChatHistory(jid: jid),
      fileLabel: fileLabel,
      lineFormatter: lineFormatter,
    );
    if (!exportResult.hasContent || exportResult.file == null) {
      return ProfileExportResult.empty(kind: kind);
    }
    return ProfileExportResult.success(
      kind: kind,
      file: exportResult.file!,
      itemCount: exportResult.messageCount,
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
    final directory = await _xmppService.loadContactsSnapshot();
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

String? _formatEmailMessageLine({
  required Chat chat,
  required Message message,
  required intl.DateFormat format,
  required EmailMessageLineLabels labels,
}) {
  final DateTime fallbackTimestamp = DateTime.fromMillisecondsSinceEpoch(
    0,
    isUtc: true,
  );
  final String? body = message.body?.trim();
  final String? subject = message.subject?.trim();
  if ((body == null || body.isEmpty) && (subject == null || subject.isEmpty)) {
    return null;
  }
  final DateTime timestampValue = message.timestamp ?? fallbackTimestamp;
  final String timestamp = format.format(timestampValue);
  final String sender = _resolveEmailSender(chat, message);
  final String content = (body == null || body.isEmpty)
      ? '${labels.subjectLabel}: $subject'
      : body;
  final StringBuffer buffer = StringBuffer()
    ..write('[')
    ..write(timestamp)
    ..write(']')
    ..write(' ')
    ..write(sender)
    ..write(': ')
    ..write(content);
  if (subject != null &&
      subject.isNotEmpty &&
      body != null &&
      body.isNotEmpty) {
    buffer
      ..write(' (${labels.subjectLabel}: ')
      ..write(subject)
      ..write(')');
  }
  return buffer.toString();
}

String _resolveEmailSender(Chat chat, Message message) {
  final String sender = message.senderJid.trim();
  if (sender.isNotEmpty) {
    return sender;
  }
  final String? address = chat.emailAddress?.trim();
  if (address != null && address.isNotEmpty) {
    return address;
  }
  final String? contact = chat.contactJid?.trim();
  if (contact != null && contact.isNotEmpty) {
    return contact;
  }
  return chat.jid;
}
