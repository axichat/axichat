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
import 'package:delta_ffi/delta_safe.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;

const int _chatExportStart = 0;
const int _chatExportEnd = 0;
const int _emptyCount = 0;
const int _emailContactListFlags =
    DeltaContactListFlags.addSelf | DeltaContactListFlags.address;
const String _xmppMessagesFileLabel = 'xmpp-messages';
const String _emailMessagesFileLabel = 'email-messages';
const String _xmppContactsFileLabel = 'xmpp-contacts';
const String _emailContactsFileLabel = 'email-contacts';
const String _messageLineTimestampPrefix = '[';
const String _messageLineTimestampSuffix = ']';
const String _messageLineSpacer = ' ';
const String _messageLineSeparator = ': ';
const String _messageSubjectLabel = 'Subject';
const String _messageSubjectSeparator = ': ';
const String _messageSubjectPrefix =
    ' ($_messageSubjectLabel$_messageSubjectSeparator';
const String _messageSubjectSuffix = ')';
const String _subjectOnlyPrefix =
    '$_messageSubjectLabel$_messageSubjectSeparator';
final DateTime _fallbackTimestamp =
    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

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
    this.itemCount = _emptyCount,
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

  const ProfileExportResult.empty({
    required ProfileExportKind kind,
  }) : this._(
          kind: kind,
          outcome: ProfileExportOutcome.empty,
          itemCount: _emptyCount,
        );

  const ProfileExportResult.failure({
    required ProfileExportKind kind,
  }) : this._(
          kind: kind,
          outcome: ProfileExportOutcome.failure,
          itemCount: _emptyCount,
        );

  final ProfileExportKind kind;
  final ProfileExportOutcome outcome;
  final File? file;
  final int itemCount;

  bool get hasFile => file != null;
}

class ProfileExportState {
  const ProfileExportState({
    this.status = RequestStatus.none,
    this.activeKind,
  });

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

class ProfileExportCubit extends Cubit<ProfileExportState> {
  ProfileExportCubit({
    required XmppService xmppService,
    required EmailService emailService,
  })  : _xmppService = xmppService,
        _emailService = emailService,
        super(const ProfileExportState());

  final XmppService _xmppService;
  final EmailService _emailService;

  Future<ProfileExportResult> exportXmppMessages() => _runExport(
        kind: ProfileExportKind.xmppMessages,
        operation: () => _exportMessages(
          kind: ProfileExportKind.xmppMessages,
          transport: MessageTransport.xmpp,
          fileLabel: _xmppMessagesFileLabel,
          lineFormatter: null,
        ),
      );

  Future<ProfileExportResult> exportEmailMessages() => _runExport(
        kind: ProfileExportKind.emailMessages,
        operation: () => _exportMessages(
          kind: ProfileExportKind.emailMessages,
          transport: MessageTransport.email,
          fileLabel: _emailMessagesFileLabel,
          lineFormatter: _formatEmailMessageLine,
        ),
      );

  Future<ProfileExportResult> exportXmppContacts(
    ContactExportFormat format,
  ) =>
      _runExport(
        kind: ProfileExportKind.xmppContacts,
        operation: () => _exportXmppContacts(format),
      );

  Future<ProfileExportResult> exportEmailContacts(
    ContactExportFormat format,
  ) =>
      _runExport(
        kind: ProfileExportKind.emailContacts,
        operation: () => _exportEmailContacts(format),
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
    ChatHistoryMessageLineFormatter? lineFormatter,
  }) async {
    final db = await _xmppService.database;
    final chats = await db.getChats(
      start: _chatExportStart,
      end: _chatExportEnd,
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
  ) async {
    final db = await _xmppService.database;
    final roster = await db.getRoster();
    final contacts = _sortedContacts(
      roster
          .map(
            (item) => ContactExportEntry(
              address: item.jid.trim(),
              displayName: (item.contactDisplayName ?? item.title).trim(),
              transport: MessageTransport.xmpp,
            ),
          )
          .where((entry) => entry.address.isNotEmpty)
          .toList(growable: false),
    );
    if (contacts.isEmpty) {
      return const ProfileExportResult.empty(
        kind: ProfileExportKind.xmppContacts,
      );
    }
    final file = await ContactExporter.exportContacts(
      contacts: contacts,
      format: format,
      fileLabel: _xmppContactsFileLabel,
    );
    return ProfileExportResult.success(
      kind: ProfileExportKind.xmppContacts,
      file: file,
      itemCount: contacts.length,
    );
  }

  Future<ProfileExportResult> _exportEmailContacts(
    ContactExportFormat format,
  ) async {
    final emailContacts = await _emailService.getContacts(
      flags: _emailContactListFlags,
    );
    final contacts = _sortedContacts(
      emailContacts
          .map(
            (contact) => ContactExportEntry(
              address: contact.address?.trim() ?? '',
              displayName: contact.name?.trim(),
              transport: MessageTransport.email,
            ),
          )
          .where((entry) => entry.address.isNotEmpty)
          .toList(growable: false),
    );
    if (contacts.isEmpty) {
      return const ProfileExportResult.empty(
        kind: ProfileExportKind.emailContacts,
      );
    }
    final file = await ContactExporter.exportContacts(
      contacts: contacts,
      format: format,
      fileLabel: _emailContactsFileLabel,
    );
    return ProfileExportResult.success(
      kind: ProfileExportKind.emailContacts,
      file: file,
      itemCount: contacts.length,
    );
  }

  List<ContactExportEntry> _sortedContacts(
    List<ContactExportEntry> contacts,
  ) =>
      contacts.toList()
        ..sort((a, b) {
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
}) {
  final String? body = message.body?.trim();
  final String? subject = message.subject?.trim();
  if ((body == null || body.isEmpty) && (subject == null || subject.isEmpty)) {
    return null;
  }
  final DateTime timestampValue = message.timestamp ?? _fallbackTimestamp;
  final String timestamp = format.format(timestampValue);
  final String sender = _resolveEmailSender(chat, message);
  final String content =
      (body == null || body.isEmpty) ? '$_subjectOnlyPrefix$subject' : body;
  final StringBuffer buffer = StringBuffer()
    ..write(_messageLineTimestampPrefix)
    ..write(timestamp)
    ..write(_messageLineTimestampSuffix)
    ..write(_messageLineSpacer)
    ..write(sender)
    ..write(_messageLineSeparator)
    ..write(content);
  if (subject != null &&
      subject.isNotEmpty &&
      body != null &&
      body.isNotEmpty) {
    buffer
      ..write(_messageSubjectPrefix)
      ..write(subject)
      ..write(_messageSubjectSuffix);
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
