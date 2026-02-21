// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'accessibility_chat_bloc.dart';

class AccessibilityChatState extends Equatable {
  static const Object _unset = Object();

  const AccessibilityChatState({
    required this.jid,
    required this.messages,
    required this.attachments,
    required this.busy,
    required this.statusMessage,
    required this.errorMessage,
    required this.sendCount,
    required this.draftSaveCount,
    required this.draftId,
  });

  const AccessibilityChatState.initial({
    required this.jid,
    required this.draftId,
  }) : messages = const [],
       attachments = const <String, List<FileMetadataData>>{},
       busy = false,
       statusMessage = null,
       errorMessage = null,
       sendCount = 0,
       draftSaveCount = 0;

  final String jid;
  final List<Message> messages;
  final Map<String, List<FileMetadataData>> attachments;
  final bool busy;
  final AccessibilityChatStatus? statusMessage;
  final AccessibilityChatError? errorMessage;
  final int sendCount;
  final int draftSaveCount;
  final int? draftId;

  AccessibilityChatState copyWith({
    String? jid,
    List<Message>? messages,
    Map<String, List<FileMetadataData>>? attachments,
    bool? busy,
    Object? statusMessage = _unset,
    Object? errorMessage = _unset,
    int? sendCount,
    int? draftSaveCount,
    Object? draftId = _unset,
  }) => AccessibilityChatState(
    jid: jid ?? this.jid,
    messages: messages ?? this.messages,
    attachments: attachments ?? this.attachments,
    busy: busy ?? this.busy,
    statusMessage: statusMessage == _unset
        ? this.statusMessage
        : statusMessage as AccessibilityChatStatus?,
    errorMessage: errorMessage == _unset
        ? this.errorMessage
        : errorMessage as AccessibilityChatError?,
    sendCount: sendCount ?? this.sendCount,
    draftSaveCount: draftSaveCount ?? this.draftSaveCount,
    draftId: draftId == _unset ? this.draftId : draftId as int?,
  );

  @override
  List<Object?> get props => [
    jid,
    messages,
    attachments,
    busy,
    statusMessage,
    errorMessage,
    sendCount,
    draftSaveCount,
    draftId,
  ];
}
