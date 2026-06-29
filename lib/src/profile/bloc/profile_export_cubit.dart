// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/chats/utils/chat_history_exporter.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/profile/utils/contact_exporter.dart';
import 'package:axichat/src/profile/utils/profile_email_eml_exporter.dart';
import 'package:axichat/src/storage/models.dart';
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
    } on ProfileEmailEmlExportEmptyException {
      emit(
        state.copyWith(
          status: RequestStatus.none,
          clearActiveKind: true,
          clearProgress: true,
        ),
      );
      return ProfileExportResult.empty(kind: kind);
    } on ProfileEmailEmlExportIncompleteException catch (error) {
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
    const int chatExportStart = 0;
    const int chatExportEnd = 0;
    final chats = await _xmppService.loadChats(
      start: chatExportStart,
      end: chatExportEnd,
    );
    final selectedChats = chats
        .where((chat) => chat.transport == MessageTransport.xmpp)
        .toList(growable: false);
    if (selectedChats.isEmpty) {
      return const ProfileExportResult.empty(
        kind: ProfileExportKind.xmppMessages,
      );
    }
    final exportResult = await ChatHistoryExporter.exportChats(
      chats: selectedChats,
      loadHistory: (jid) => _xmppService.loadCompleteChatHistory(jid: jid),
      fileLabel: 'xmpp-messages',
    );
    if (!exportResult.hasContent || exportResult.file == null) {
      return const ProfileExportResult.empty(
        kind: ProfileExportKind.xmppMessages,
      );
    }
    return ProfileExportResult.success(
      kind: ProfileExportKind.xmppMessages,
      file: exportResult.file!,
      itemCount: exportResult.messageCount,
    );
  }

  Future<ProfileExportResult> _exportEmailEmlMessages() async {
    const int chatExportStart = 0;
    const int chatExportEnd = 0;
    final chats = await _xmppService.loadChats(
      start: chatExportStart,
      end: chatExportEnd,
    );
    final selectedChats = chats
        .where(
          (chat) =>
              chat.transport == MessageTransport.email || chat.isEmailBacked,
        )
        .toList(growable: false);
    if (selectedChats.isEmpty) {
      return const ProfileExportResult.empty(
        kind: ProfileExportKind.emailMessages,
      );
    }
    final exportResult = await ProfileEmailEmlExporter.exportMessages(
      chats: selectedChats,
      loadHistory: (jid) => _xmppService.loadCompleteChatHistory(jid: jid),
      loadMessageAttachmentsForMessages:
          _xmppService.loadMessageAttachmentsForMessages,
      loadMessageAttachmentsForGroup:
          _xmppService.loadMessageAttachmentsForGroup,
      loadFileMetadataByIds: _xmppService.loadFileMetadataByIds,
      loadEmailContent: _loadEmailEmlContent,
      onProgress: _updateEmailExportProgress,
    );
    if (exportResult.warnings.isNotEmpty) {
      return ProfileExportResult.incomplete(
        kind: ProfileExportKind.emailMessages,
        file: exportResult.file,
        itemCount: exportResult.messageCount,
        warnings: exportResult.warnings,
      );
    }
    return ProfileExportResult.success(
      kind: ProfileExportKind.emailMessages,
      file: exportResult.file,
      itemCount: exportResult.messageCount,
    );
  }

  void _updateEmailExportProgress(ProfileEmailEmlExportProgress progress) {
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

  Future<ProfileEmailEmlContent> _loadEmailEmlContent(Message message) async {
    final emailService = _emailService;
    if (emailService == null || !message.isEmailBacked) {
      return const ProfileEmailEmlContent();
    }
    var warning = '';
    void addWarning(String value) {
      if (warning.isEmpty) {
        warning = value;
      }
    }

    var preparedMessage = message;
    try {
      await emailService.requestEmailContentPreparation(
        message,
        priority: EmailContentPreparationPriority.manual,
      );
    } on Exception {
      addWarning('Full email content could not be prepared.');
    }
    try {
      preparedMessage =
          await _xmppService.loadMessageByStanzaId(message.stanzaID) ?? message;
    } catch (_) {
      // Keep the original row if a best-effort refresh is unavailable.
    }

    String? mimeHeaders;
    try {
      mimeHeaders = await emailService.getMessageRawHeadersForMessage(
        preparedMessage,
      );
    } on Exception {
      addWarning('MIME headers could not be exported.');
    }

    String? rfc822PlainText;
    String? rfc822HtmlBody;
    try {
      final rfc822Body = await emailService.getMessageRfc822Body(
        preparedMessage,
      );
      rfc822PlainText = rfc822Body?.plainText;
      rfc822HtmlBody = rfc822Body?.htmlBody;
    } on Exception {
      addWarning('RFC822 body content could not be exported.');
    }
    final deltaMsgId = preparedMessage.deltaMsgId;
    if (preparedMessage.hasRfc822BodyContent ||
        deltaMsgId == null ||
        deltaMsgId <= 0) {
      rfc822PlainText ??= preparedMessage.body;
      rfc822HtmlBody ??= preparedMessage.htmlBody;
    }

    String? fullHtml;
    final hasRfc822Body =
        rfc822PlainText?.trim().isNotEmpty == true ||
        rfc822HtmlBody?.trim().isNotEmpty == true;
    final hasStoredHydratedBody =
        preparedMessage.hasRfc822BodyContent &&
        (preparedMessage.body?.trim().isNotEmpty == true ||
            preparedMessage.htmlBody?.trim().isNotEmpty == true);
    final bodyUnavailable = preparedMessage.rfc822BodyContentUnavailable;
    if (!hasRfc822Body && !hasStoredHydratedBody && !bodyUnavailable) {
      try {
        fullHtml = await emailService.getMessageFullHtml(preparedMessage);
      } on Exception {
        addWarning('Full HTML content could not be exported.');
      }
    }

    if (!hasRfc822Body &&
        !hasStoredHydratedBody &&
        (fullHtml?.trim().isNotEmpty != true) &&
        preparedMessage.rfc822BodyStatus.isPendingDownload) {
      addWarning('Full email body was not available.');
    }

    return ProfileEmailEmlContent(
      mimeHeaders: mimeHeaders,
      rfc822PlainText: rfc822PlainText,
      rfc822HtmlBody: rfc822HtmlBody,
      fullHtml: fullHtml,
      bodyUnavailable: bodyUnavailable,
      warning: warning.isEmpty ? null : warning,
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
