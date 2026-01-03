// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'accessibility_action_bloc.dart';

sealed class AccessibilityActionEvent extends Equatable {
  const AccessibilityActionEvent();

  @override
  List<Object?> get props => const [];
}

class AccessibilityMenuOpened extends AccessibilityActionEvent {
  const AccessibilityMenuOpened();
}

class AccessibilityMenuClosed extends AccessibilityActionEvent {
  const AccessibilityMenuClosed();
}

class AccessibilityMenuBack extends AccessibilityActionEvent {
  const AccessibilityMenuBack();
}

class AccessibilityMenuJumpedTo extends AccessibilityActionEvent {
  const AccessibilityMenuJumpedTo(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

class AccessibilityMenuReset extends AccessibilityActionEvent {
  const AccessibilityMenuReset();
}

class AccessibilityDiscardWarningRequested extends AccessibilityActionEvent {
  const AccessibilityDiscardWarningRequested();
}

class AccessibilityMenuActionTriggered extends AccessibilityActionEvent {
  const AccessibilityMenuActionTriggered(this.action);

  final AccessibilityMenuAction action;

  @override
  List<Object?> get props => [action];
}

class AccessibilityComposerChanged extends AccessibilityActionEvent {
  const AccessibilityComposerChanged(this.value);

  final String value;

  @override
  List<Object?> get props => [value];
}

class AccessibilitySendMessageRequested extends AccessibilityActionEvent {
  const AccessibilitySendMessageRequested();
}

class AccessibilityRecipientRemoved extends AccessibilityActionEvent {
  const AccessibilityRecipientRemoved(this.jid);

  final String jid;

  @override
  List<Object?> get props => [jid];
}

class AccessibilityNewContactChanged extends AccessibilityActionEvent {
  const AccessibilityNewContactChanged(this.value);

  final String value;

  @override
  List<Object?> get props => [value];
}

class AccessibilityConfirmNewContact extends AccessibilityActionEvent {
  const AccessibilityConfirmNewContact();
}

class AccessibilityDataUpdated extends AccessibilityActionEvent {
  const AccessibilityDataUpdated({
    this.chats,
    this.roster,
    this.invites,
    this.drafts,
  });

  final List<Chat>? chats;
  final List<RosterItem>? roster;
  final List<Invite>? invites;
  final List<Draft>? drafts;

  @override
  List<Object?> get props => [chats, roster, invites, drafts];
}

class AccessibilityLocaleUpdated extends AccessibilityActionEvent {
  const AccessibilityLocaleUpdated(this.localization);

  final AppLocalizations localization;

  @override
  List<Object?> get props => [localization.localeName];
}

class AccessibilityMessagesUpdated extends AccessibilityActionEvent {
  const AccessibilityMessagesUpdated({
    required this.jid,
    required this.messages,
  });

  final String jid;
  final List<Message> messages;

  @override
  List<Object?> get props => [jid, messages];
}
