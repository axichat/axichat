import 'package:axichat/src/storage/models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

enum AccessibilityStepKind {
  root,
  contactPicker,
  composer,
  unread,
  invites,
  newContact,
  chatMessages,
  conversation,
}

enum AccessibilityFlowPurpose {
  sendMessage,
  openChat,
  reviewUnread,
  reviewInvites,
}

enum AccessibilityMenuItemKind {
  navigate,
  command,
  selectContact,
  inviteDecision,
  dismissHighlight,
  input,
  readOnly,
}

class AccessibilityMenuSection extends Equatable {
  const AccessibilityMenuSection({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String? title;
  final List<AccessibilityMenuItem> items;

  @override
  List<Object?> get props => [id, title, items];
}

class AccessibilityMenuItem extends Equatable {
  const AccessibilityMenuItem({
    required this.id,
    required this.label,
    required this.kind,
    required this.action,
    this.description,
    this.icon,
    this.highlight = false,
    this.destructive = false,
    this.badge,
    this.dismissId,
    this.disabled = false,
    this.message,
    this.attachment,
    this.attachmentLabel,
    this.senderLabel,
    this.timestampLabel,
    this.showMetadata = false,
  });

  final String id;
  final String label;
  final AccessibilityMenuItemKind kind;
  final AccessibilityMenuAction action;
  final String? description;
  final IconData? icon;
  final bool highlight;
  final bool destructive;
  final String? badge;
  final String? dismissId;
  final bool disabled;
  final Message? message;
  final FileMetadataData? attachment;
  final String? attachmentLabel;
  final String? senderLabel;
  final String? timestampLabel;
  final bool showMetadata;

  @override
  List<Object?> get props => [
        id,
        label,
        kind,
        description,
        icon,
        highlight,
        destructive,
        badge,
        dismissId,
        disabled,
        message,
        attachment,
        attachmentLabel,
        senderLabel,
        timestampLabel,
        showMetadata,
      ];
}

sealed class AccessibilityMenuAction extends Equatable {
  const AccessibilityMenuAction();
}

class AccessibilityNavigateAction extends AccessibilityMenuAction {
  const AccessibilityNavigateAction({
    required this.step,
    this.purpose,
  });

  final AccessibilityStepKind step;
  final AccessibilityFlowPurpose? purpose;

  @override
  List<Object?> get props => [step, purpose];
}

enum AccessibilityCommand {
  openChat,
  sendMessage,
  addRecipient,
  backToContacts,
  closeMenu,
  confirmNewContact,
  saveDraft,
  resumeDraft,
}

class AccessibilityCommandAction extends AccessibilityMenuAction {
  const AccessibilityCommandAction({
    required this.command,
    this.contact,
    this.highlightId,
    this.draft,
  });

  final AccessibilityCommand command;
  final AccessibilityContact? contact;
  final String? highlightId;
  final Draft? draft;

  @override
  List<Object?> get props => [command, contact, highlightId, draft];
}

class AccessibilitySelectContactAction extends AccessibilityMenuAction {
  const AccessibilitySelectContactAction({
    required this.contact,
  });

  final AccessibilityContact contact;

  @override
  List<Object?> get props => [contact];
}

class AccessibilityInviteDecisionAction extends AccessibilityMenuAction {
  const AccessibilityInviteDecisionAction({
    required this.invite,
    required this.accept,
  });

  final Invite invite;
  final bool accept;

  @override
  List<Object?> get props => [invite, accept];
}

class AccessibilityDismissHighlightAction extends AccessibilityMenuAction {
  const AccessibilityDismissHighlightAction({required this.highlightId});

  final String highlightId;

  @override
  List<Object?> get props => [highlightId];
}

class AccessibilityNoopAction extends AccessibilityMenuAction {
  const AccessibilityNoopAction();

  @override
  List<Object?> get props => const [];
}

class AccessibilityStepEntry extends Equatable {
  const AccessibilityStepEntry({
    required this.kind,
    this.purpose,
    this.recipients = const <AccessibilityContact>[],
    this.addingRecipient = false,
    this.draftId,
  });

  final AccessibilityStepKind kind;
  final AccessibilityFlowPurpose? purpose;
  final List<AccessibilityContact> recipients;
  final bool addingRecipient;
  final int? draftId;

  AccessibilityStepEntry copyWith({
    AccessibilityStepKind? kind,
    AccessibilityFlowPurpose? purpose,
    List<AccessibilityContact>? recipients,
    bool? addingRecipient,
    int? draftId,
  }) =>
      AccessibilityStepEntry(
        kind: kind ?? this.kind,
        purpose: purpose ?? this.purpose,
        recipients: recipients ?? this.recipients,
        addingRecipient: addingRecipient ?? this.addingRecipient,
        draftId: draftId ?? this.draftId,
      );

  @override
  List<Object?> get props =>
      [kind, purpose, recipients, addingRecipient, draftId];
}

enum AccessibilityContactSource {
  chat,
  roster,
  manual,
}

class AccessibilityContact extends Equatable {
  const AccessibilityContact({
    required this.jid,
    required this.displayName,
    required this.subtitle,
    required this.source,
    required this.encryptionProtocol,
    required this.chatType,
    required this.unreadCount,
    this.isGroup = false,
  });

  final String jid;
  final String displayName;
  final String? subtitle;
  final AccessibilityContactSource source;
  final EncryptionProtocol encryptionProtocol;
  final ChatType chatType;
  final int unreadCount;
  final bool isGroup;

  bool get hasUnread => unreadCount > 0;

  AccessibilityContact copyWith({
    String? displayName,
    String? subtitle,
    AccessibilityContactSource? source,
    ChatType? chatType,
    int? unreadCount,
    bool? isGroup,
  }) =>
      AccessibilityContact(
        jid: jid,
        displayName: displayName ?? this.displayName,
        subtitle: subtitle ?? this.subtitle,
        source: source ?? this.source,
        encryptionProtocol: encryptionProtocol,
        chatType: chatType ?? this.chatType,
        unreadCount: unreadCount ?? this.unreadCount,
        isGroup: isGroup ?? this.isGroup,
      );

  @override
  List<Object?> get props => [
        jid,
        displayName,
        subtitle,
        source,
        encryptionProtocol,
        chatType,
        unreadCount,
        isGroup,
      ];
}
