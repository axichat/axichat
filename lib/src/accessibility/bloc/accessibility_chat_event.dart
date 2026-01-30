// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'accessibility_chat_bloc.dart';

sealed class AccessibilityChatEvent extends Equatable {
  const AccessibilityChatEvent();

  @override
  List<Object?> get props => const [];
}

class AccessibilityChatLocaleUpdated extends AccessibilityChatEvent {
  const AccessibilityChatLocaleUpdated(this.localization);

  final AppLocalizations localization;

  @override
  List<Object?> get props => [localization.localeName];
}

class AccessibilityChatContactsUpdated extends AccessibilityChatEvent {
  const AccessibilityChatContactsUpdated({
    required this.contacts,
    required this.myJid,
  });

  final List<AccessibilityContact> contacts;
  final String? myJid;

  @override
  List<Object?> get props => [contacts, myJid];
}

class AccessibilityChatUnreadUpdated extends AccessibilityChatEvent {
  const AccessibilityChatUnreadUpdated(this.unreadCount);

  final int unreadCount;

  @override
  List<Object?> get props => [unreadCount];
}

class AccessibilityChatDraftIdUpdated extends AccessibilityChatEvent {
  const AccessibilityChatDraftIdUpdated(this.draftId);

  final int? draftId;

  @override
  List<Object?> get props => [draftId];
}

class AccessibilityChatMessagesUpdated extends AccessibilityChatEvent {
  const AccessibilityChatMessagesUpdated({
    required this.jid,
    required this.messages,
  });

  final String jid;
  final List<Message> messages;

  @override
  List<Object?> get props => [jid, messages];
}

class AccessibilityChatSendRequested extends AccessibilityChatEvent {
  const AccessibilityChatSendRequested({
    required this.body,
    required this.recipients,
  });

  final String body;
  final List<AccessibilityContact> recipients;

  @override
  List<Object?> get props => [body, recipients];
}

class AccessibilityChatSaveDraftRequested extends AccessibilityChatEvent {
  const AccessibilityChatSaveDraftRequested({
    required this.body,
    required this.recipients,
    required this.draftId,
  });

  final String body;
  final List<AccessibilityContact> recipients;
  final int? draftId;

  @override
  List<Object?> get props => [body, recipients, draftId];
}
