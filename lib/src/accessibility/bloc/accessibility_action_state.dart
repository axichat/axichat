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
    required this.dismissedHighlights,
    required this.composerText,
    required this.newContactInput,
    required this.busy,
    required this.statusMessage,
    required this.errorMessage,
    required this.discardWarningActive,
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
        dismissedHighlights = const <String>{},
        composerText = '',
        newContactInput = '',
        busy = false,
        statusMessage = null,
        errorMessage = null,
        discardWarningActive = false;

  final bool visible;
  final List<AccessibilityStepEntry> stack;
  final List<AccessibilityContact> contacts;
  final List<Invite> invites;
  final List<Draft> drafts;
  final String? myJid;
  final Set<String> dismissedHighlights;
  final String composerText;
  final String newContactInput;
  final bool busy;
  final AccessibilityActionStatus? statusMessage;
  final AccessibilityActionError? errorMessage;
  final bool discardWarningActive;

  AccessibilityStepEntry get currentEntry => stack.last;

  AccessibilityActionState copyWith({
    bool? visible,
    List<AccessibilityStepEntry>? stack,
    List<AccessibilityContact>? contacts,
    List<Invite>? invites,
    List<Draft>? drafts,
    Object? myJid = _unset,
    Set<String>? dismissedHighlights,
    String? composerText,
    String? newContactInput,
    bool? busy,
    Object? statusMessage = _unset,
    Object? errorMessage = _unset,
    bool? discardWarningActive,
  }) =>
      AccessibilityActionState(
        visible: visible ?? this.visible,
        stack: stack ?? this.stack,
        contacts: contacts ?? this.contacts,
        invites: invites ?? this.invites,
        drafts: drafts ?? this.drafts,
        myJid: myJid == _unset ? this.myJid : myJid as String?,
        dismissedHighlights: dismissedHighlights ?? this.dismissedHighlights,
        composerText: composerText ?? this.composerText,
        newContactInput: newContactInput ?? this.newContactInput,
        busy: busy ?? this.busy,
        statusMessage: statusMessage == _unset
            ? this.statusMessage
            : statusMessage as AccessibilityActionStatus?,
        errorMessage: errorMessage == _unset
            ? this.errorMessage
            : errorMessage as AccessibilityActionError?,
        discardWarningActive: discardWarningActive ?? this.discardWarningActive,
      );

  @override
  List<Object?> get props => [
        visible,
        stack,
        contacts,
        invites,
        drafts,
        myJid,
        dismissedHighlights,
        composerText,
        newContactInput,
        busy,
        statusMessage,
        errorMessage,
        discardWarningActive,
      ];
}
