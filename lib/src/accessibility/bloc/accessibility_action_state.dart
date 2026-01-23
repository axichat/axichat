// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'accessibility_action_bloc.dart';

class AccessibilityActionState extends Equatable {
  static const Object _unset = Object();

  const AccessibilityActionState({
    required this.visible,
    required this.stack,
    required this.contacts,
    required this.invites,
    required this.drafts,
    required this.myJid,
    required this.composerText,
    required this.newContactInput,
    required this.busy,
    required this.statusMessage,
    required this.errorMessage,
    required this.recipients,
    required this.messages,
    required this.activeChatJid,
    required this.discardWarningActive,
    required this.attachments,
  });

  const AccessibilityActionState.initial()
      : visible = false,
        stack = const [
          AccessibilityStepEntry(kind: AccessibilityStepKind.root)
        ],
        contacts = const [],
        invites = const [],
        drafts = const [],
        myJid = null,
        composerText = '',
        newContactInput = '',
        busy = false,
        statusMessage = null,
        errorMessage = null,
        recipients = const [],
        messages = const [],
        activeChatJid = null,
        discardWarningActive = false,
        attachments = const <String, List<FileMetadataData>>{};

  final bool visible;
  final List<AccessibilityStepEntry> stack;
  final List<AccessibilityContact> contacts;
  final List<Invite> invites;
  final List<Draft> drafts;
  final String? myJid;
  final String composerText;
  final String newContactInput;
  final bool busy;
  final String? statusMessage;
  final String? errorMessage;
  final List<AccessibilityContact> recipients;
  final List<Message> messages;
  final String? activeChatJid;
  final bool discardWarningActive;
  final Map<String, List<FileMetadataData>> attachments;

  AccessibilityStepEntry get currentEntry => stack.last;

  AccessibilityActionState copyWith({
    bool? visible,
    List<AccessibilityStepEntry>? stack,
    List<AccessibilityContact>? contacts,
    List<Invite>? invites,
    List<Draft>? drafts,
    Object? myJid = _unset,
    String? composerText,
    String? newContactInput,
    bool? busy,
    Object? statusMessage = _unset,
    Object? errorMessage = _unset,
    List<AccessibilityContact>? recipients,
    List<Message>? messages,
    Object? activeChatJid = _unset,
    bool? discardWarningActive,
    Map<String, List<FileMetadataData>>? attachments,
  }) =>
      AccessibilityActionState(
        visible: visible ?? this.visible,
        stack: stack ?? this.stack,
        contacts: contacts ?? this.contacts,
        invites: invites ?? this.invites,
        drafts: drafts ?? this.drafts,
        myJid: myJid == _unset ? this.myJid : myJid as String?,
        composerText: composerText ?? this.composerText,
        newContactInput: newContactInput ?? this.newContactInput,
        busy: busy ?? this.busy,
        statusMessage: statusMessage == _unset
            ? this.statusMessage
            : statusMessage as String?,
        errorMessage: errorMessage == _unset
            ? this.errorMessage
            : errorMessage as String?,
        recipients: recipients ?? this.recipients,
        messages: messages ?? this.messages,
        activeChatJid: activeChatJid == _unset
            ? this.activeChatJid
            : activeChatJid as String?,
        discardWarningActive: discardWarningActive ?? this.discardWarningActive,
        attachments: attachments ?? this.attachments,
      );

  @override
  List<Object?> get props => [
        visible,
        stack,
        contacts,
        invites,
        drafts,
        myJid,
        composerText,
        newContactInput,
        busy,
        statusMessage,
        errorMessage,
        recipients,
        messages,
        activeChatJid,
        discardWarningActive,
        attachments,
      ];
}
