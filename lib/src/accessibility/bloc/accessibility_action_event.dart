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
  });

  final List<Chat>? chats;
  final List<RosterItem>? roster;
  final List<Invite>? invites;

  @override
  List<Object?> get props => [chats, roster, invites];
}

class AccessibilityLocaleUpdated extends AccessibilityActionEvent {
  const AccessibilityLocaleUpdated(this.localization);

  final AppLocalizations localization;

  @override
  List<Object?> get props => [localization.localeName];
}
