// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/accessibility/bloc/accessibility_action_bloc.dart';
import 'package:axichat/src/accessibility/bloc/accessibility_chat_bloc.dart';
import 'package:axichat/src/accessibility/view/accessibility_l10n.dart';
import 'package:axichat/src/accessibility/view/shortcut_hint.dart';
import 'package:axichat/src/accessibility/models/accessibility_action_models.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/view/chat_attachment_preview.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

String _stepLabelFor(BuildContext context, AccessibilityStepEntry entry) {
  final l10n = context.l10n;
  switch (entry.kind) {
    case AccessibilityStepKind.root:
      return l10n.accessibilityActionsLabel;
    case AccessibilityStepKind.contactPicker:
      return l10n.accessibilityChooseContact;
    case AccessibilityStepKind.composer:
      return l10n.chatComposerMessageHint;
    case AccessibilityStepKind.unread:
      return l10n.accessibilityUnreadConversations;
    case AccessibilityStepKind.invites:
      return l10n.accessibilityPendingInvites;
    case AccessibilityStepKind.newContact:
      return l10n.accessibilityStartNewAddress;
    case AccessibilityStepKind.chatMessages:
      final name = entry.recipients.isNotEmpty
          ? entry.recipients.first.displayName
          : '';
      return name.isNotEmpty
          ? l10n.accessibilityMessagesWithContact(name)
          : l10n.accessibilityMessagesTitle;
    case AccessibilityStepKind.conversation:
      final conversationName = entry.recipients.isNotEmpty
          ? entry.recipients.first.displayName
          : '';
      return conversationName.isNotEmpty
          ? l10n.accessibilityConversationWith(conversationName)
          : l10n.accessibilityConversationLabel;
  }
}

bool _isChatStep(AccessibilityStepEntry entry) {
  return entry.kind == AccessibilityStepKind.chatMessages ||
      entry.kind == AccessibilityStepKind.conversation ||
      entry.kind == AccessibilityStepKind.composer;
}

String? _activeChatJidFor(AccessibilityStepEntry entry) {
  if (!_isChatStep(entry)) return null;
  if (entry.recipients.isEmpty) return null;
  return entry.recipients.first.jid;
}

int _unreadCountFor(List<AccessibilityContact> contacts, String jid) {
  for (final contact in contacts) {
    if (contact.jid == jid) {
      return contact.unreadCount;
    }
  }
  return 0;
}

String? _contactSubtitleFor(
  BuildContext context,
  AccessibilityContact contact,
) {
  final subtitle = contact.subtitle;
  if (subtitle != null && subtitle.isNotEmpty) {
    return subtitle;
  }
  if (contact.source == AccessibilityContactSource.manual) {
    return context.l10n.chatsFilterNonContacts;
  }
  return subtitle;
}

String? _actionStatusLabel(
  BuildContext context,
  AccessibilityActionStatus? status,
) => status?.label(context.l10n);

String? _actionErrorLabel(
  BuildContext context,
  AccessibilityActionError? error,
) => error?.label(context.l10n);

String? _chatStatusLabel(
  BuildContext context,
  AccessibilityChatStatus? status,
) => status?.label(context.l10n);

String? _chatErrorLabel(BuildContext context, AccessibilityChatError? error) {
  final label = error?.label(context.l10n);
  return label == null || label.isEmpty ? null : label;
}

List<AccessibilityMenuSection> _sectionsFor(
  BuildContext context,
  AccessibilityActionState state, {
  AccessibilityChatState? chatState,
}) {
  final entry = state.stack.last;
  switch (entry.kind) {
    case AccessibilityStepKind.root:
      return _rootSectionsFor(context, state);
    case AccessibilityStepKind.contactPicker:
      final purpose = entry.purpose ?? AccessibilityFlowPurpose.openChat;
      return _contactSectionsFor(context, state, purpose);
    case AccessibilityStepKind.unread:
      return _unreadSectionsFor(context, state);
    case AccessibilityStepKind.invites:
      return _inviteSectionsFor(context, state);
    case AccessibilityStepKind.composer:
      return _conversationSectionsFor(
        context,
        state,
        entry,
        chatState: chatState,
      );
    case AccessibilityStepKind.newContact:
      return _newContactSectionsFor(context, state);
    case AccessibilityStepKind.chatMessages:
      return _conversationSectionsFor(
        context,
        state,
        entry,
        chatState: chatState,
      );
    case AccessibilityStepKind.conversation:
      return _conversationSectionsFor(
        context,
        state,
        entry,
        chatState: chatState,
      );
  }
}

List<AccessibilityMenuSection> _rootSectionsFor(
  BuildContext context,
  AccessibilityActionState state,
) {
  final l10n = context.l10n;
  final sections = <AccessibilityMenuSection>[];
  final totalUnread = state.contacts.fold<int>(
    0,
    (count, contact) =>
        contact.unreadCount > 0 ? count + contact.unreadCount : count,
  );

  final summaryDismissId = 'unread-summary-$totalUnread';
  sections.add(
    AccessibilityMenuSection(
      id: 'actions',
      title: l10n.accessibilityActionsTitle,
      items: [
        AccessibilityMenuItem(
          id: 'action-start-chat',
          label: l10n.accessibilityStartNewChat,
          description: l10n.accessibilityStartNewChatDescription,
          kind: AccessibilityMenuItemKind.navigate,
          action: const AccessibilityNavigateAction(
            step: AccessibilityStepKind.contactPicker,
            purpose: AccessibilityFlowPurpose.sendMessage,
          ),
          icon: Icons.add_comment_outlined,
        ),
        AccessibilityMenuItem(
          id: 'action-unread',
          label: l10n.accessibilityReadNewMessages,
          description: l10n.accessibilityUnreadSummaryDescription,
          kind: AccessibilityMenuItemKind.navigate,
          action: const AccessibilityNavigateAction(
            step: AccessibilityStepKind.unread,
            purpose: AccessibilityFlowPurpose.reviewUnread,
          ),
          icon: Icons.mark_chat_unread_outlined,
          badge: totalUnread > 0 ? totalUnread.toString() : null,
          highlight:
              totalUnread > 0 &&
              !state.dismissedHighlights.contains(summaryDismissId),
          dismissId: totalUnread > 0 ? summaryDismissId : null,
        ),
      ],
    ),
  );

  if (state.invites.isNotEmpty) {
    sections.addAll(_inviteSectionsFor(context, state));
  }

  final chatItems = state.contacts
      .where((contact) => contact.source == AccessibilityContactSource.chat)
      .map(
        (contact) => AccessibilityMenuItem(
          id: 'chat-${contact.jid}',
          label: contact.displayName,
          description: _contactSubtitleFor(context, contact),
          kind: AccessibilityMenuItemKind.command,
          action: AccessibilityCommandAction(
            command: AccessibilityCommand.openChat,
            contact: contact,
          ),
          icon: contact.isGroup
              ? Icons.groups_2_outlined
              : Icons.chat_bubble_outline,
          badge: contact.unreadCount > 0
              ? contact.unreadCount.toString()
              : null,
        ),
      )
      .toList();

  sections.add(
    AccessibilityMenuSection(
      id: 'chats',
      title: l10n.homeTabChats,
      items: chatItems.isEmpty
          ? [
              AccessibilityMenuItem(
                id: 'chats-empty',
                label: l10n.chatsEmptyList,
                description: '',
                kind: AccessibilityMenuItemKind.readOnly,
                action: const AccessibilityNoopAction(),
              ),
            ]
          : chatItems,
    ),
  );

  if (state.drafts.isNotEmpty) {
    sections.add(
      AccessibilityMenuSection(
        id: 'drafts',
        title: l10n.homeTabDrafts,
        items: _draftMenuItemsFor(context, state, state.drafts),
      ),
    );
  }

  return sections;
}

List<AccessibilityMenuItem> _draftMenuItemsFor(
  BuildContext context,
  AccessibilityActionState state,
  List<Draft> drafts,
) {
  final l10n = context.l10n;
  return drafts.take(10).map((draft) {
    final description = _draftDescriptionFor(context, state, draft);
    final recipientsLabel = _draftRecipientsLabelFor(state, draft.jids);
    final label = recipientsLabel.isEmpty
        ? l10n.accessibilityDraftLabel(draft.id)
        : l10n.accessibilityDraftLabelWithRecipients(recipientsLabel);
    return AccessibilityMenuItem(
      id: 'draft-${draft.id}',
      label: label,
      description: description,
      kind: AccessibilityMenuItemKind.command,
      action: AccessibilityCommandAction(
        command: AccessibilityCommand.resumeDraft,
        draft: draft,
      ),
      icon: Icons.note_outlined,
    );
  }).toList();
}

String _draftDescriptionFor(
  BuildContext context,
  AccessibilityActionState state,
  Draft draft,
) {
  final l10n = context.l10n;
  final recipientsLabel = _draftRecipientsLabelFor(state, draft.jids);
  final body = (draft.body ?? '').trim();
  final preview = body.isEmpty
      ? l10n.accessibilityMessageNoContent
      : (body.length > 80 ? '${body.substring(0, 80)}…' : body);
  if (recipientsLabel.isEmpty) return preview;
  return l10n.accessibilityDraftPreview(recipientsLabel, preview);
}

String _draftRecipientsLabelFor(
  AccessibilityActionState state,
  List<String> jids,
) {
  if (jids.isEmpty) return '';
  final names = jids.map((jid) => _contactForJid(state, jid).displayName);
  return names.join(', ');
}

List<AccessibilityMenuSection> _contactSectionsFor(
  BuildContext context,
  AccessibilityActionState state,
  AccessibilityFlowPurpose purpose,
) {
  final l10n = context.l10n;
  final description = purpose == AccessibilityFlowPurpose.sendMessage
      ? l10n.chatComposerMessageHint
      : l10n.chatSearchMessages;
  final items = state.contacts
      .map(
        (contact) => AccessibilityMenuItem(
          id: 'contact-${contact.jid}',
          label: contact.displayName,
          description: _contactSubtitleFor(context, contact),
          kind: purpose == AccessibilityFlowPurpose.sendMessage
              ? AccessibilityMenuItemKind.selectContact
              : AccessibilityMenuItemKind.command,
          action: purpose == AccessibilityFlowPurpose.sendMessage
              ? AccessibilitySelectContactAction(contact: contact)
              : AccessibilityCommandAction(
                  command: AccessibilityCommand.openChat,
                  contact: contact,
                ),
          icon: contact.isGroup ? Icons.groups_outlined : Icons.person_outline,
          badge: contact.unreadCount > 0
              ? contact.unreadCount.toString()
              : null,
        ),
      )
      .toList();
  if (purpose == AccessibilityFlowPurpose.sendMessage) {
    items.add(
      AccessibilityMenuItem(
        id: 'new-contact',
        label: l10n.accessibilityStartChat,
        description: l10n.accessibilityStartChatHint,
        kind: AccessibilityMenuItemKind.navigate,
        action: const AccessibilityNavigateAction(
          step: AccessibilityStepKind.newContact,
          purpose: AccessibilityFlowPurpose.sendMessage,
        ),
        icon: Icons.create,
      ),
    );
  }
  return [
    AccessibilityMenuSection(id: 'contacts', title: description, items: items),
  ];
}

List<AccessibilityMenuSection> _unreadSectionsFor(
  BuildContext context,
  AccessibilityActionState state,
) {
  final l10n = context.l10n;
  final items = state.contacts.where((contact) => contact.unreadCount > 0).map((
    contact,
  ) {
    final dismissId = 'unread-${contact.jid}-${contact.unreadCount}';
    return AccessibilityMenuItem(
      id: 'unread-${contact.jid}',
      label: contact.displayName,
      description: _unreadDescriptionFor(context, contact),
      kind: AccessibilityMenuItemKind.command,
      action: AccessibilityCommandAction(
        command: AccessibilityCommand.openChat,
        contact: contact,
      ),
      icon: Icons.mark_chat_unread_outlined,
      badge: contact.unreadCount.toString(),
      highlight: !state.dismissedHighlights.contains(dismissId),
      dismissId: dismissId,
    );
  }).toList();
  if (items.isEmpty) {
    items.add(
      AccessibilityMenuItem(
        id: 'unread-none',
        label: l10n.accessibilityUnreadEmpty,
        description: '',
        kind: AccessibilityMenuItemKind.command,
        action: const AccessibilityCommandAction(
          command: AccessibilityCommand.closeMenu,
        ),
        icon: Icons.mark_chat_unread_outlined,
        disabled: true,
      ),
    );
  }
  return [
    AccessibilityMenuSection(
      id: 'unread',
      title: l10n.accessibilityReadNewMessages,
      items: items,
    ),
  ];
}

List<AccessibilityMenuSection> _inviteSectionsFor(
  BuildContext context,
  AccessibilityActionState state,
) {
  final l10n = context.l10n;
  final items = <AccessibilityMenuItem>[];
  for (final invite in state.invites) {
    final dismissId = 'invite-${invite.jid}';
    items.addAll([
      AccessibilityMenuItem(
        id: 'invite-accept-${invite.jid}',
        label: l10n.accessibilityAcceptInvite,
        description: invite.jid,
        kind: AccessibilityMenuItemKind.inviteDecision,
        action: AccessibilityInviteDecisionAction(invite: invite, accept: true),
        icon: Icons.person_add_alt,
        highlight: !state.dismissedHighlights.contains(dismissId),
        dismissId: dismissId,
      ),
      AccessibilityMenuItem(
        id: 'invite-reject-${invite.jid}',
        label: l10n.accessibilityInviteDismissed,
        description: invite.jid,
        kind: AccessibilityMenuItemKind.inviteDecision,
        action: AccessibilityInviteDecisionAction(
          invite: invite,
          accept: false,
        ),
        icon: Icons.person_off_outlined,
        destructive: true,
        highlight: !state.dismissedHighlights.contains(dismissId),
        dismissId: dismissId,
      ),
    ]);
  }
  if (items.isEmpty) {
    items.add(
      AccessibilityMenuItem(
        id: 'invites-none',
        label: l10n.accessibilityInvitesEmpty,
        description: '',
        kind: AccessibilityMenuItemKind.command,
        action: const AccessibilityCommandAction(
          command: AccessibilityCommand.closeMenu,
        ),
        icon: Icons.person_add_disabled_outlined,
        disabled: true,
      ),
    );
  }
  return [
    AccessibilityMenuSection(
      id: 'invites',
      title: l10n.accessibilityInvitesTitle,
      items: items,
    ),
  ];
}

List<AccessibilityMenuSection> _conversationSectionsFor(
  BuildContext context,
  AccessibilityActionState state,
  AccessibilityStepEntry entry, {
  AccessibilityChatState? chatState,
}) {
  return [_messageSectionFor(context, state, entry, chatState: chatState)];
}

AccessibilityMenuSection _messageSectionFor(
  BuildContext context,
  AccessibilityActionState state,
  AccessibilityStepEntry entry, {
  AccessibilityChatState? chatState,
}) {
  final l10n = context.l10n;
  final targetJid = entry.recipients.isNotEmpty
      ? entry.recipients.first.jid
      : chatState?.jid;
  if (targetJid == null) {
    return AccessibilityMenuSection(
      id: 'chat-messages',
      title: l10n.accessibilityMessagesTitle,
      items: [
        AccessibilityMenuItem(
          id: 'msg-none',
          label: l10n.accessibilityNoConversationSelected,
          description: '',
          kind: AccessibilityMenuItemKind.readOnly,
          action: const AccessibilityNoopAction(),
        ),
      ],
    );
  }
  final contact = _contactFor(state, context, targetJid);
  final items = <AccessibilityMenuItem>[];
  var lastSender = '';
  final attachmentIndex = chatState?.attachments ?? const {};
  final messages = chatState?.messages ?? const <Message>[];
  for (final message in messages) {
    final senderLabel = _senderLabelFor(context, state, message);
    final timestampLabel = _formatTimestamp(context, message.timestamp);
    final attachments = attachmentIndex[_messageId(message)] ?? const [];
    final attachment = attachments.isNotEmpty ? attachments.first : null;
    final body = (message.body ?? '').trim();
    final attachmentNote = _attachmentLabelFor(
      context,
      message,
      metadata: attachments,
    );
    final fullBody = body.isNotEmpty
        ? body
        : (attachmentNote ?? l10n.accessibilityMessageNoContent);
    final showSender = senderLabel != lastSender;
    final label = showSender
        ? l10n.accessibilityMessageLabel(senderLabel, timestampLabel, fullBody)
        : fullBody;
    items.add(
      AccessibilityMenuItem(
        id: 'msg-${_messageId(message)}',
        label: label,
        description: showSender ? null : senderLabel,
        kind: AccessibilityMenuItemKind.readOnly,
        action: const AccessibilityNoopAction(),
        message: message,
        attachment: attachment,
        attachmentLabel: attachmentNote,
        senderLabel: senderLabel,
        timestampLabel: timestampLabel,
        showMetadata: showSender,
      ),
    );
    lastSender = senderLabel;
  }
  if (items.isEmpty) {
    items.add(
      AccessibilityMenuItem(
        id: 'msg-empty',
        label: l10n.accessibilityMessagesEmpty,
        description: '',
        kind: AccessibilityMenuItemKind.readOnly,
        action: const AccessibilityNoopAction(),
      ),
    );
  }
  final title = contact.displayName.isEmpty
      ? l10n.accessibilityMessagesTitle
      : l10n.accessibilityMessagesWithContact(contact.displayName);
  return AccessibilityMenuSection(
    id: 'chat-messages',
    title: title,
    items: items,
  );
}

List<AccessibilityMenuSection> _newContactSectionsFor(
  BuildContext context,
  AccessibilityActionState state,
) {
  final l10n = context.l10n;
  return [
    AccessibilityMenuSection(
      id: 'new-contact',
      title: l10n.accessibilityStartChat,
      items: [
        AccessibilityMenuItem(
          id: 'new-contact-confirm',
          label: l10n.accessibilityStartChat,
          description: l10n.accessibilityStartChatHint,
          kind: AccessibilityMenuItemKind.command,
          action: const AccessibilityCommandAction(
            command: AccessibilityCommand.confirmNewContact,
          ),
          icon: Icons.check,
          disabled: !AddressStringExtensions(
            state.newContactInput.trim(),
          ).isValidJid,
        ),
      ],
    ),
  ];
}

String _unreadDescriptionFor(
  BuildContext context,
  AccessibilityContact contact,
) => context.l10n.chatsUnreadLabel(contact.unreadCount);

AccessibilityContact _contactFor(
  AccessibilityActionState state,
  BuildContext context,
  String? jid,
) {
  final l10n = context.l10n;
  final fallbackJid = jid ?? 'unknown';
  final fallbackName = jid ?? l10n.accessibilityUnknownContact;
  return state.contacts.firstWhere(
    (contact) => contact.jid == fallbackJid,
    orElse: () => AccessibilityContact(
      jid: fallbackJid,
      displayName: fallbackName,
      subtitle: fallbackName,
      source: AccessibilityContactSource.chat,
      encryptionProtocol: EncryptionProtocol.none,
      chatType: ChatType.chat,
      unreadCount: 0,
      transport: MessageTransport.xmpp,
    ),
  );
}

AccessibilityContact _contactForJid(
  AccessibilityActionState state,
  String jid,
) {
  return state.contacts.firstWhere(
    (contact) => contact.jid == jid,
    orElse: () => AccessibilityContact(
      jid: jid,
      displayName: jid,
      subtitle: jid,
      source: AccessibilityContactSource.manual,
      encryptionProtocol: EncryptionProtocol.none,
      chatType: ChatType.chat,
      unreadCount: 0,
      transport: MessageTransport.xmpp,
    ),
  );
}

String _senderLabelFor(
  BuildContext context,
  AccessibilityActionState state,
  Message message,
) {
  final l10n = context.l10n;
  final senderBare = bareAddress(message.senderJid) ?? message.senderJid;
  final myJid = state.myJid;
  if (myJid != null && sameBareAddress(senderBare, myJid)) {
    return l10n.chatSenderYou;
  }
  final matching = state.contacts.firstWhere(
    (contact) => sameBareAddress(contact.jid, senderBare),
    orElse: () => AccessibilityContact(
      jid: senderBare,
      displayName: senderBare,
      subtitle: senderBare,
      source: AccessibilityContactSource.chat,
      encryptionProtocol: message.encryptionProtocol,
      chatType: ChatType.chat,
      unreadCount: 0,
      transport: MessageTransport.xmpp,
    ),
  );
  return matching.displayName;
}

String _formatTimestamp(BuildContext context, DateTime? timestamp) {
  final l10n = context.l10n;
  final safe = timestamp ?? DateTime.now();
  return DateFormat.yMMMd(l10n.localeName).add_jm().format(safe);
}

String? _attachmentLabelFor(
  BuildContext context,
  Message message, {
  List<FileMetadataData>? metadata,
}) {
  final l10n = context.l10n;
  final resolvedMetadata = metadata == null || metadata.isEmpty
      ? null
      : metadata.first;
  final filename = resolvedMetadata?.filename.trim();
  if (filename != null && filename.isNotEmpty) {
    return l10n.accessibilityAttachmentWithName(filename);
  }
  if (metadata?.isNotEmpty == true || message.fileMetadataID != null) {
    return l10n.accessibilityAttachmentGeneric;
  }
  if (message.isFileUploadNotification) {
    return l10n.accessibilityUploadAvailable;
  }
  if (message.pseudoMessageType != null) {
    return message.pseudoMessageType!.name;
  }
  return null;
}

String _messageId(Message message) => message.id ?? message.stanzaID;

class AccessibilityActionMenu extends StatefulWidget {
  const AccessibilityActionMenu({super.key, this.chatLocate});

  final T Function<T>()? chatLocate;

  @override
  State<AccessibilityActionMenu> createState() =>
      _AccessibilityActionMenuState();
}

class _AccessibilityActionMenuState extends State<AccessibilityActionMenu> {
  bool Function(KeyEvent event)? _globalShortcutHandler;

  @override
  void initState() {
    super.initState();
    _globalShortcutHandler = _handleGlobalShortcut;
    HardwareKeyboard.instance.addHandler(_globalShortcutHandler!);
  }

  @override
  void dispose() {
    final handler = _globalShortcutHandler;
    if (handler != null) {
      HardwareKeyboard.instance.removeHandler(handler);
    }
    super.dispose();
  }

  bool _handleGlobalShortcut(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.keyK) return false;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final hasMeta =
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight) ||
        pressed.contains(LogicalKeyboardKey.meta);
    final hasControl =
        pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.control);
    if (!hasMeta && !hasControl) return false;
    final locate = context.read;
    locate<AccessibilityActionBloc>().add(const AccessibilityMenuOpened());
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccessibilityActionBloc, AccessibilityActionState>(
      builder: (context, state) {
        const duration = baseAnimationDuration;
        return IgnorePointer(
          ignoring: !state.visible,
          child: AnimatedOpacity(
            opacity: state.visible ? 1 : 0,
            duration: duration,
            curve: Curves.easeInOutCubic,
            child: state.visible
                ? BlockSemantics(
                    blocking: true,
                    child: _AccessibilityMenuScaffold(
                      state: state,
                      chatLocate: widget.chatLocate,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

class _AccessibilityMenuScaffold extends StatefulWidget {
  const _AccessibilityMenuScaffold({
    required this.state,
    required this.chatLocate,
  });

  final AccessibilityActionState state;
  final T Function<T>()? chatLocate;

  @override
  State<_AccessibilityMenuScaffold> createState() =>
      _AccessibilityMenuScaffoldState();
}

class _AccessibilityMenuScaffoldState extends State<_AccessibilityMenuScaffold>
    with WidgetsBindingObserver {
  final FocusScopeNode _focusScopeNode = FocusScopeNode(
    debugLabel: 'accessibility_menu_scope',
  );
  final GlobalKey<_AccessibilitySectionListState> _sectionsListKey =
      GlobalKey();
  final GlobalKey<_AccessibilitySectionListState> _actionsListKey = GlobalKey();
  final GlobalKey<_MessageCarouselState> _messageCarouselKey = GlobalKey();
  final GlobalKey _legendGroupKey = GlobalKey(debugLabel: 'legend_group');
  final GlobalKey _composerGroupKey = GlobalKey(debugLabel: 'composer_group');
  final GlobalKey _newContactGroupKey = GlobalKey(
    debugLabel: 'new_contact_group',
  );
  final GlobalKey _actionsGroupKey = GlobalKey(debugLabel: 'actions_group');
  final FocusNode _shortcutLegendFocusNode = FocusNode(
    debugLabel: 'accessibility_shortcut_legend',
  );
  final FocusNode _messageFocusNode = FocusNode(
    debugLabel: 'accessibility_message_view',
  );
  final FocusNode _composerFocusNode = FocusNode(
    debugLabel: 'accessibility_composer_field',
  );
  final FocusNode _newContactFocusNode = FocusNode(
    debugLabel: 'accessibility_new_contact_field',
  );
  final FocusNode _actionsFocusNode = FocusNode(
    debugLabel: 'accessibility_actions_group',
  );
  final ScrollController _scrollController = ScrollController();
  FocusNode? _restoreFocusNode;
  Object? _lastFocusedGroup;
  bool _wasVisible = false;
  bool _isEditingText = false;
  String? _lastAnnouncedStep;
  bool Function(KeyEvent event)? _menuShortcutHandler;

  @override
  void initState() {
    super.initState();
    _isEditingText = _isTextInputFocused();
    FocusManager.instance.addListener(_handleFocusChange);
    _menuShortcutHandler = _handleMenuShortcut;
    HardwareKeyboard.instance.addHandler(_menuShortcutHandler!);
    _wasVisible = widget.state.visible;
    if (_wasVisible) {
      _restoreFocusNode = FocusManager.instance.primaryFocus;
      _scheduleInitialFocus();
    }
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _AccessibilityMenuScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.visible && !_wasVisible) {
      _restoreFocusNode = FocusManager.instance.primaryFocus;
      _lastFocusedGroup = null;
      _scheduleInitialFocus();
      _announceStepChange();
    } else if (!widget.state.visible && _wasVisible) {
      _focusScopeNode.unfocus();
      final previous = _restoreFocusNode;
      _restoreFocusNode = null;
      _lastFocusedGroup = null;
      if (previous != null &&
          previous.context != null &&
          previous.canRequestFocus) {
        previous.requestFocus();
      }
      _lastAnnouncedStep = null;
    }
    if (widget.state.currentEntry != oldWidget.state.currentEntry &&
        widget.state.visible) {
      _scheduleInitialFocus();
    }
    final addedMessageSection =
        !_hasMessageSection(oldWidget.state) &&
        _hasMessageSection(widget.state);
    if (widget.state.visible && addedMessageSection) {
      _scheduleInitialFocus();
    }
    _announceStepChange();
    _wasVisible = widget.state.visible;
  }

  @override
  void dispose() {
    final handler = _menuShortcutHandler;
    if (handler != null) {
      HardwareKeyboard.instance.removeHandler(handler);
    }
    FocusManager.instance.removeListener(_handleFocusChange);
    WidgetsBinding.instance.removeObserver(this);
    _shortcutLegendFocusNode.dispose();
    _messageFocusNode.dispose();
    _composerFocusNode.dispose();
    _newContactFocusNode.dispose();
    _actionsFocusNode.dispose();
    _focusScopeNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed && widget.state.visible) {
      _scheduleInitialFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    const escapeActivator = SingleActivator(LogicalKeyboardKey.escape);
    const nextGroupActivator = SingleActivator(
      LogicalKeyboardKey.arrowDown,
      shift: true,
    );
    const previousGroupActivator = SingleActivator(
      LogicalKeyboardKey.arrowUp,
      shift: true,
    );
    final nextGroupKeySet = LogicalKeySet(
      LogicalKeyboardKey.shift,
      LogicalKeyboardKey.arrowDown,
    );
    final previousGroupKeySet = LogicalKeySet(
      LogicalKeyboardKey.shift,
      LogicalKeyboardKey.arrowUp,
    );
    const nextItemActivator = SingleActivator(LogicalKeyboardKey.arrowDown);
    const previousItemActivator = SingleActivator(LogicalKeyboardKey.arrowUp);
    const firstItemActivator = SingleActivator(LogicalKeyboardKey.home);
    const lastItemActivator = SingleActivator(LogicalKeyboardKey.end);
    const activateItemActivator = SingleActivator(LogicalKeyboardKey.enter);
    final shortcuts = <ShortcutActivator, Intent>{
      escapeActivator: const _AccessibilityDismissIntent(),
      nextGroupActivator: const _NextGroupIntent(),
      previousGroupActivator: const _PreviousGroupIntent(),
      nextGroupKeySet: const _NextGroupIntent(),
      previousGroupKeySet: const _PreviousGroupIntent(),
      if (!_isEditingText) ...{
        nextItemActivator: const _NextItemIntent(),
        previousItemActivator: const _PreviousItemIntent(),
        firstItemActivator: const _FirstItemIntent(),
        lastItemActivator: const _LastItemIntent(),
      },
    };
    final scrimColor = context.colorScheme.foreground.withValues(
      alpha: context.motion.tapFocusAlpha + context.motion.tapHoverAlpha,
    );
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => context.read<AccessibilityActionBloc>().add(
              const AccessibilityMenuClosed(),
            ),
            child: ColoredBox(color: scrimColor),
          ),
        ),
        SafeArea(
          child: Center(
            child: Shortcuts(
              shortcuts: shortcuts,
              child: Actions(
                actions: {
                  _AccessibilityDismissIntent:
                      CallbackAction<_AccessibilityDismissIntent>(
                        onInvoke: (_) {
                          final shouldWarn = _shouldWarnOnExit(widget.state);
                          if (shouldWarn &&
                              !widget.state.discardWarningActive) {
                            context.read<AccessibilityActionBloc>().add(
                              const AccessibilityDiscardWarningRequested(),
                            );
                            return null;
                          }
                          if (widget.state.stack.length > 1) {
                            context.read<AccessibilityActionBloc>().add(
                              const AccessibilityMenuBack(),
                            );
                          } else {
                            context.read<AccessibilityActionBloc>().add(
                              const AccessibilityMenuClosed(),
                            );
                          }
                          return null;
                        },
                      ),
                  _NextItemIntent: CallbackAction<_NextItemIntent>(
                    onInvoke: (_) => _handleDirectionalMove(forward: true),
                  ),
                  _PreviousItemIntent: CallbackAction<_PreviousItemIntent>(
                    onInvoke: (_) => _handleDirectionalMove(forward: false),
                  ),
                  _NextGroupIntent: CallbackAction<_NextGroupIntent>(
                    onInvoke: (_) => _focusNextGroup(),
                  ),
                  _PreviousGroupIntent: CallbackAction<_PreviousGroupIntent>(
                    onInvoke: (_) => _focusPreviousGroup(),
                  ),
                  _FirstItemIntent: CallbackAction<_FirstItemIntent>(
                    onInvoke: (_) {
                      if (_currentGroup() == _messageCarouselKey) {
                        _messageCarousel?.firstMessage();
                        return null;
                      }
                      _withList((list) => list.focusFirstItem());
                      return null;
                    },
                  ),
                  _LastItemIntent: CallbackAction<_LastItemIntent>(
                    onInvoke: (_) {
                      if (_currentGroup() == _messageCarouselKey) {
                        _messageCarousel?.lastMessage();
                        return null;
                      }
                      _withList((list) => list.focusLastItem());
                      return null;
                    },
                  ),
                  _ActivateItemIntent: CallbackAction<_ActivateItemIntent>(
                    onInvoke: (_) {
                      if (_currentGroup() == _messageCarouselKey) {
                        return null;
                      }
                      _withList((list) => list.activateFocused());
                      return null;
                    },
                  ),
                },
                child: FocusScope(
                  node: _focusScopeNode,
                  autofocus: true,
                  child: LayoutBuilder(
                    builder: (context, safeConstraints) {
                      final spacing = context.spacing;
                      final modalMinHeightValue =
                          context.sizing.menuItemHeight * 7;
                      final modalMaxWidthValue = context.sizing.dialogMaxWidth;
                      final modalVerticalMargin =
                          context.sizing.menuItemHeight * 2;
                      final availableHeight = safeConstraints.maxHeight;
                      final modalMinHeight =
                          availableHeight < modalMinHeightValue
                          ? availableHeight
                          : modalMinHeightValue;
                      final rawTargetHeight =
                          availableHeight - modalVerticalMargin;
                      final modalHeight = rawTargetHeight
                          .clamp(modalMinHeight, availableHeight)
                          .toDouble();
                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: modalMaxWidthValue,
                        ),
                        child: SizedBox(
                          height: modalHeight,
                          child: AxiModalSurface(
                            padding: EdgeInsets.zero,
                            child: Material(
                              type: MaterialType.transparency,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final viewportHeight = constraints.maxHeight;
                                  return Semantics(
                                    scopesRoute: true,
                                    namesRoute: true,
                                    label:
                                        context.l10n.accessibilityDialogLabel,
                                    hint: context.l10n.accessibilityDialogHint,
                                    explicitChildNodes: true,
                                    child: Scrollbar(
                                      controller: _scrollController,
                                      child: SingleChildScrollView(
                                        controller: _scrollController,
                                        physics: const ClampingScrollPhysics(),
                                        padding: EdgeInsets.all(spacing.m),
                                        clipBehavior: Clip.hardEdge,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minHeight: viewportHeight,
                                          ),
                                          child: FocusTraversalGroup(
                                            policy: OrderedTraversalPolicy(),
                                            child: _AccessibilityChatScope(
                                              state: widget.state,
                                              builder: (context, chatState) =>
                                                  _AccessibilityActionContent(
                                                    state: widget.state,
                                                    chatState: chatState,
                                                    sectionsListKey:
                                                        _sectionsListKey,
                                                    actionsListKey:
                                                        _actionsListKey,
                                                    enableActivationShortcut:
                                                        !_isEditingText,
                                                    legendFocusNode:
                                                        _shortcutLegendFocusNode,
                                                    messageFocusNode:
                                                        _messageFocusNode,
                                                    composerFocusNode:
                                                        _composerFocusNode,
                                                    newContactFocusNode:
                                                        _newContactFocusNode,
                                                    legendGroupKey:
                                                        _legendGroupKey,
                                                    messageCarouselKey:
                                                        _messageCarouselKey,
                                                    composerGroupKey:
                                                        _composerGroupKey,
                                                    actionsGroupKey:
                                                        _actionsGroupKey,
                                                    actionsFocusNode:
                                                        _actionsFocusNode,
                                                    newContactGroupKey:
                                                        _newContactGroupKey,
                                                    viewportHeight:
                                                        viewportHeight,
                                                    activateItemActivator:
                                                        activateItemActivator,
                                                    nextGroupActivator:
                                                        nextGroupActivator,
                                                    previousGroupActivator:
                                                        previousGroupActivator,
                                                    chatLocate:
                                                        widget.chatLocate,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _withList(void Function(_AccessibilitySectionListState list) action) {
    final group = _currentGroup();
    final list = _listForGroup(group);
    if (list == null || list.isEditingText) return;
    action(list);
  }

  _MessageCarouselState? get _messageCarousel =>
      _messageCarouselKey.currentState;

  _AccessibilitySectionListState? _listForGroup(Object? group) {
    if (group == _actionsListKey) {
      return _actionsListKey.currentState;
    }
    if (group == _sectionsListKey) {
      return _sectionsListKey.currentState;
    }
    return null;
  }

  void _handleDirectionalMove({required bool forward}) {
    final current = _currentGroup();
    if (current == _messageCarouselKey) {
      final carousel = _messageCarousel;
      if (carousel != null) {
        forward ? carousel.nextMessage() : carousel.previousMessage();
      }
      return;
    }
    if (current == _composerGroupKey) {
      _moveWithinGroup(_composerGroupKey, forward: forward);
      return;
    }
    if (current == _newContactGroupKey) {
      _moveWithinGroup(_newContactGroupKey, forward: forward);
      return;
    }
    if (current == _actionsGroupKey) {
      _moveWithinGroup(_actionsGroupKey, forward: forward);
      return;
    }
    if (current == _legendGroupKey) {
      _moveWithinGroup(_legendGroupKey, forward: forward);
      return;
    }
    _withList(
      (list) => forward ? list.focusNextItem() : list.focusPreviousItem(),
    );
  }

  void _moveWithinGroup(GlobalKey key, {required bool forward}) {
    final context = key.currentContext;
    if (context == null) return;
    final focusScope = FocusScope.of(context);
    if (forward) {
      focusScope.nextFocus();
    } else {
      focusScope.previousFocus();
    }
  }

  List<Object> _groupOrder() => _groupOrderForState(widget.state);

  List<Object> _groupOrderForState(AccessibilityActionState state) {
    final sections = _sectionsFor(context, state);
    final messageSections = sections
        .where((section) => section.id == 'chat-messages')
        .toList();
    final hasMessages = messageSections.isNotEmpty;
    final isConversation =
        state.currentEntry.kind == AccessibilityStepKind.composer ||
        state.currentEntry.kind == AccessibilityStepKind.chatMessages ||
        state.currentEntry.kind == AccessibilityStepKind.conversation;
    final hasComposer = isConversation;
    final hasNewContact =
        state.currentEntry.kind == AccessibilityStepKind.newContact;
    final actionSections = hasNewContact
        ? <AccessibilityMenuSection>[]
        : sections.where((section) => section.id != 'chat-messages').toList();
    final hasSections = actionSections.isNotEmpty;
    final order = <Object>[];
    order.add(_legendGroupKey);
    if (hasMessages) {
      order.add(_messageCarouselKey);
    }
    if (hasComposer) {
      order.add(_composerGroupKey);
    }
    if (isConversation) {
      order.add(_actionsGroupKey);
    }
    if (isConversation && hasSections) {
      order.add(_actionsListKey);
    }
    if (hasNewContact) {
      order.add(_newContactGroupKey);
    }
    if (!isConversation && hasSections) {
      order.add(_sectionsListKey);
    }
    return order;
  }

  void _focusNextGroup() {
    final order = _groupOrder();
    if (order.isEmpty) return;
    final current = _currentGroup();
    final currentIndex = current == null
        ? -1
        : order.indexOf(current).clamp(0, order.length);
    final nextIndex = (currentIndex + 1).clamp(0, order.length - 1).toInt();
    _focusGroup(order[nextIndex]);
  }

  void _focusPreviousGroup() {
    final order = _groupOrder();
    if (order.isEmpty) return;
    final current = _currentGroup();
    final currentIndex = current == null
        ? order.length
        : order.indexOf(current);
    final previousIndex = (currentIndex - 1).clamp(0, order.length - 1).toInt();
    _focusGroup(order[previousIndex]);
  }

  void _focusGroup(Object group) {
    _lastFocusedGroup = group;
    _focusScopeNode.requestFocus();
    if (group == _legendGroupKey) {
      _shortcutLegendFocusNode.requestFocus();
    } else if (group == _messageCarouselKey) {
      _messageCarouselKey.currentState?.focusInitial();
    } else if (group == _composerGroupKey) {
      _composerFocusNode.requestFocus();
    } else if (group == _actionsGroupKey) {
      _actionsFocusNode.requestFocus();
    } else if (group == _actionsListKey) {
      _actionsListKey.currentState?.focusInitial(fallbackIndex: 0);
    } else if (group == _newContactGroupKey) {
      _newContactFocusNode.requestFocus();
    } else if (group == _sectionsListKey) {
      _sectionsListKey.currentState?.focusInitial();
    } else {
      return;
    }
    _scrollGroupIntoView(group);
  }

  void _scrollGroupIntoView(Object group) {
    final context = _groupContext(group);
    if (context == null) return;
    _ensureVisible(context);
  }

  BuildContext? _groupContext(Object group) {
    if (group is GlobalKey) {
      return group.currentContext;
    }
    return null;
  }

  Object? _currentGroup() {
    final focus = FocusManager.instance.primaryFocus;
    final focusContext = focus?.context;
    if (focusContext == null) return null;
    return _AccessibilityGroupMarker.maybeOf(focusContext);
  }

  bool _hasMessageSection(AccessibilityActionState state) => _sectionsFor(
    context,
    state,
  ).any((section) => section.id == 'chat-messages');

  bool _shouldWarnOnExit(AccessibilityActionState state) {
    final entry = state.currentEntry;
    if (entry.kind == AccessibilityStepKind.composer ||
        entry.kind == AccessibilityStepKind.chatMessages ||
        entry.kind == AccessibilityStepKind.conversation) {
      return state.composerText.trim().isNotEmpty;
    }
    if (entry.kind == AccessibilityStepKind.newContact) {
      return state.newContactInput.trim().isNotEmpty;
    }
    return false;
  }

  void _scheduleInitialFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusScopeNode.requestFocus();
      final groups = _groupOrder();
      Object? target =
          _lastFocusedGroup != null && groups.contains(_lastFocusedGroup)
          ? _lastFocusedGroup
          : null;
      target ??= groups.firstWhere(
        (group) => group != _legendGroupKey,
        orElse: () => _legendGroupKey,
      );
      if (target == _legendGroupKey && groups.isNotEmpty) {
        target = groups.first;
      }
      _focusGroup(target);
    });
  }

  void _handleFocusChange() {
    final editing = _isTextInputFocused();
    if (!mounted) return;
    if (editing != _isEditingText) {
      setState(() {
        _isEditingText = editing;
      });
    }
    final primary = FocusManager.instance.primaryFocus;
    final primaryContext = primary?.context;
    if (widget.state.visible && primaryContext != null) {
      _ensureVisible(primaryContext);
    }
    if (widget.state.visible &&
        (primary == null || primary.context == null) &&
        _groupOrder().isNotEmpty) {
      _scheduleInitialFocus();
    }
  }

  bool _handleMenuShortcut(KeyEvent event) {
    if (!widget.state.visible || event is! KeyDownEvent) {
      return false;
    }
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final hasShift =
        pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight) ||
        pressed.contains(LogicalKeyboardKey.shift);
    if (hasShift && event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _focusNextGroup();
      return true;
    }
    if (hasShift && event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _focusPreviousGroup();
      return true;
    }
    return false;
  }

  void _announceStepChange() {
    if (!mounted || !widget.state.visible) return;
    final label = _stepLabel(widget.state.currentEntry);
    if (label == null || label == _lastAnnouncedStep) return;
    _lastAnnouncedStep = label;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.state.visible) return;
      final view = View.of(context);
      SemanticsService.sendAnnouncement(
        view,
        label,
        Directionality.of(context),
      );
    });
  }

  void _ensureVisible(BuildContext context) {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.state.visible) return;
      Scrollable.ensureVisible(
        context,
        duration: baseAnimationDuration,
        curve: Curves.easeInOutCubic,
        alignment: 0.1,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  String? _stepLabel(AccessibilityStepEntry entry) =>
      _stepLabelFor(context, entry);
}

bool _isTextInputFocused() {
  final focus = FocusManager.instance.primaryFocus;
  final focusContext = focus?.context;
  if (focusContext == null) return false;
  if (!focusContext.mounted) return false;
  final focusedWidget = focusContext.widget;
  return focusedWidget is EditableText;
}

class _AccessibilityGroupMarker extends InheritedWidget {
  const _AccessibilityGroupMarker({required this.group, required super.child});

  final Object group;

  static Object? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_AccessibilityGroupMarker>()
      ?.group;

  @override
  bool updateShouldNotify(covariant _AccessibilityGroupMarker oldWidget) =>
      oldWidget.group != group;
}

class _AccessibilityChatScope extends StatelessWidget {
  const _AccessibilityChatScope({required this.state, required this.builder});

  final AccessibilityActionState state;
  final Widget Function(BuildContext, AccessibilityChatState? chatState)
  builder;

  @override
  Widget build(BuildContext context) {
    final entry = state.currentEntry;
    final chatJid = _activeChatJidFor(entry);
    if (chatJid == null) {
      return builder(context, null);
    }
    final unreadCount = _unreadCountFor(state.contacts, chatJid);
    return BlocProvider(
      key: ValueKey(chatJid),
      create: (context) {
        final endpointConfig = context
            .read<SettingsCubit>()
            .state
            .endpointConfig;
        final emailService = endpointConfig.smtpEnabled
            ? context.read<EmailService>()
            : null;
        return AccessibilityChatBloc(
          jid: chatJid,
          messageService: context.read<XmppService>(),
          draftSyncService: context.read<XmppService>(),
          emailService: emailService,
          contacts: state.contacts,
          myJid: state.myJid,
          initialUnreadCount: unreadCount,
          draftId: entry.draftId,
        );
      },
      child: BlocListener<SettingsCubit, SettingsState>(
        listenWhen: (previous, current) =>
            previous.endpointConfig != current.endpointConfig,
        listener: (context, settings) {
          final emailService = settings.endpointConfig.smtpEnabled
              ? context.read<EmailService>()
              : null;
          context.read<AccessibilityChatBloc>().updateEmailService(
            emailService,
          );
        },
        child: _AccessibilityChatSync(
          state: state,
          unreadCount: unreadCount,
          builder: builder,
        ),
      ),
    );
  }
}

class _AccessibilityChatSync extends StatefulWidget {
  const _AccessibilityChatSync({
    required this.state,
    required this.unreadCount,
    required this.builder,
  });

  final AccessibilityActionState state;
  final int unreadCount;
  final Widget Function(BuildContext, AccessibilityChatState? chatState)
  builder;

  @override
  State<_AccessibilityChatSync> createState() => _AccessibilityChatSyncState();
}

class _AccessibilityChatSyncState extends State<_AccessibilityChatSync> {
  List<AccessibilityContact>? _contacts;
  String? _myJid;
  int? _unreadCount;
  int? _draftId;

  @override
  void initState() {
    super.initState();
    _contacts = widget.state.contacts;
    _myJid = widget.state.myJid;
    _unreadCount = widget.unreadCount;
    _draftId = widget.state.currentEntry.draftId;
  }

  @override
  void didUpdateWidget(covariant _AccessibilityChatSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(_contacts, widget.state.contacts) ||
        _myJid != widget.state.myJid) {
      _contacts = widget.state.contacts;
      _myJid = widget.state.myJid;
      context.read<AccessibilityChatBloc>().add(
        AccessibilityChatContactsUpdated(
          contacts: widget.state.contacts,
          myJid: widget.state.myJid,
        ),
      );
    }
    if (_unreadCount != widget.unreadCount) {
      _unreadCount = widget.unreadCount;
      context.read<AccessibilityChatBloc>().add(
        AccessibilityChatUnreadUpdated(widget.unreadCount),
      );
    }
    final draftId = widget.state.currentEntry.draftId;
    if (_draftId != draftId) {
      _draftId = draftId;
      context.read<AccessibilityChatBloc>().add(
        AccessibilityChatDraftIdUpdated(draftId),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AccessibilityChatBloc, AccessibilityChatState>(
          listenWhen: (previous, current) =>
              previous.sendCount != current.sendCount,
          listener: (context, state) {
            context.read<AccessibilityActionBloc>().add(
              const AccessibilityComposerChanged(''),
            );
          },
        ),
        BlocListener<AccessibilityChatBloc, AccessibilityChatState>(
          listenWhen: (previous, current) =>
              previous.draftSaveCount != current.draftSaveCount,
          listener: (context, state) {
            context.read<AccessibilityActionBloc>().add(
              AccessibilityDraftIdUpdated(state.draftId),
            );
          },
        ),
      ],
      child: BlocBuilder<AccessibilityChatBloc, AccessibilityChatState>(
        builder: (context, chatState) => widget.builder(context, chatState),
      ),
    );
  }
}

class _AccessibilityActionContent extends StatelessWidget {
  const _AccessibilityActionContent({
    required this.state,
    required this.chatState,
    required this.sectionsListKey,
    required this.actionsListKey,
    required this.enableActivationShortcut,
    required this.legendFocusNode,
    required this.messageFocusNode,
    required this.composerFocusNode,
    required this.newContactFocusNode,
    required this.legendGroupKey,
    required this.messageCarouselKey,
    required this.composerGroupKey,
    required this.actionsGroupKey,
    required this.actionsFocusNode,
    required this.newContactGroupKey,
    required this.viewportHeight,
    required this.activateItemActivator,
    required this.nextGroupActivator,
    required this.previousGroupActivator,
    required this.chatLocate,
  });

  final AccessibilityActionState state;
  final AccessibilityChatState? chatState;
  final GlobalKey<_AccessibilitySectionListState> sectionsListKey;
  final GlobalKey<_AccessibilitySectionListState> actionsListKey;
  final bool enableActivationShortcut;
  final FocusNode legendFocusNode;
  final FocusNode messageFocusNode;
  final FocusNode composerFocusNode;
  final FocusNode newContactFocusNode;
  final FocusNode actionsFocusNode;
  final GlobalKey legendGroupKey;
  final GlobalKey<_MessageCarouselState> messageCarouselKey;
  final GlobalKey composerGroupKey;
  final GlobalKey actionsGroupKey;
  final GlobalKey newContactGroupKey;
  final double viewportHeight;
  final ShortcutActivator activateItemActivator;
  final ShortcutActivator nextGroupActivator;
  final ShortcutActivator previousGroupActivator;
  final T Function<T>()? chatLocate;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final breadcrumbLabels = _breadcrumbLabels(state, context);
    final currentRecipients = state.currentEntry.recipients;
    final headerTitle = breadcrumbLabels.isNotEmpty
        ? breadcrumbLabels.last
        : _entryLabel(state.currentEntry, context);
    final isConversation = _isChatStep(state.currentEntry);
    final hasChatState = chatState != null;
    final hasComposer = isConversation;
    final hasNewContact =
        state.currentEntry.kind == AccessibilityStepKind.newContact;
    final sections = _sectionsFor(context, state, chatState: chatState);
    final messageSections = sections
        .where((section) => section.id == 'chat-messages')
        .toList();
    final messageSection = messageSections.isNotEmpty
        ? messageSections.first
        : null;
    int activeUnreadCount(
      String? activeJid,
      List<AccessibilityContact> recipients,
    ) {
      if (activeJid == null) return 0;
      for (final recipient in recipients) {
        if (recipient.jid == activeJid) {
          return recipient.unreadCount;
        }
      }
      return 0;
    }

    int messageInitialIndex(
      List<AccessibilityMenuItem> items,
      int unreadCount,
    ) {
      if (items.isEmpty) return 0;
      if (unreadCount <= 0) return 0;
      var remainingUnread = unreadCount;
      for (var index = items.length - 1; index >= 0; index--) {
        final message = items[index].message;
        if (message == null || message.pseudoMessageType != null) {
          continue;
        }
        remainingUnread -= 1;
        if (remainingUnread <= 0) {
          return index;
        }
      }
      return 0;
    }

    final actionSections = hasNewContact
        ? <AccessibilityMenuSection>[]
        : sections.where((section) => section.id != 'chat-messages').toList();
    final hasMessages = messageSections.isNotEmpty;
    final hasSections = actionSections.isNotEmpty;
    final conversationListHeight = _conversationListHeight(
      viewportHeight,
      context.sizing,
    );
    final rootListHeight = _rootListHeight(viewportHeight, context.sizing);
    const headerOrder = NumericFocusOrder(0);
    const statusOrder = NumericFocusOrder(1);
    const legendOrder = NumericFocusOrder(2);
    const messagesOrder = NumericFocusOrder(3);
    const composerOrder = NumericFocusOrder(4);
    const newContactOrder = NumericFocusOrder(3);
    const actionsOrder = NumericFocusOrder(5);
    const actionsListOrder = NumericFocusOrder(6);
    const sectionsOrder = NumericFocusOrder(4);
    final actionStatus = state.statusMessage;
    final actionError = state.errorMessage;
    final chatStatus = isConversation && hasChatState
        ? chatState?.statusMessage
        : null;
    final chatError = isConversation && hasChatState
        ? chatState?.errorMessage
        : null;
    final bannerStatus =
        _chatStatusLabel(context, chatStatus) ??
        _actionStatusLabel(context, actionStatus);
    final bannerError =
        _chatErrorLabel(context, chatError) ??
        _actionErrorLabel(context, actionError);
    final busy = isConversation && hasChatState
        ? chatState?.busy ?? false
        : state.busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FocusTraversalOrder(
          order: headerOrder,
          child: _AccessibilityMenuHeader(
            breadcrumb: headerTitle,
            breadcrumbs: breadcrumbLabels,
            onCrumbSelected: (index) => context
                .read<AccessibilityActionBloc>()
                .add(AccessibilityMenuJumpedTo(index)),
            onBack: state.stack.length > 1
                ? () => context.read<AccessibilityActionBloc>().add(
                    const AccessibilityMenuBack(),
                  )
                : null,
            onClose: () => context.read<AccessibilityActionBloc>().add(
              const AccessibilityMenuClosed(),
            ),
          ),
        ),
        SizedBox(height: spacing.s),
        FocusTraversalOrder(
          order: legendOrder,
          child: _AccessibilityGroupMarker(
            group: legendGroupKey,
            child: _KeyboardShortcutLegend(
              firstEntryFocusNode: legendFocusNode,
              groupKey: legendGroupKey,
            ),
          ),
        ),
        SizedBox(height: spacing.s),
        if (bannerStatus != null)
          FocusTraversalOrder(
            order: statusOrder,
            child: _AccessibilityBanner(
              message: bannerStatus,
              color: context.colorScheme.card,
              foreground: context.colorScheme.foreground,
              icon: Icons.check_circle,
            ),
          ),
        if (bannerError != null)
          FocusTraversalOrder(
            order: statusOrder,
            child: _AccessibilityBanner(
              message: bannerError,
              color: context.colorScheme.destructive.withValues(
                alpha: context.motion.tapHoverAlpha,
              ),
              foreground: context.colorScheme.destructive,
              icon: Icons.error_outline,
            ),
          ),
        if (bannerStatus != null || bannerError != null)
          SizedBox(height: spacing.s),
        if (messageSection != null)
          FocusTraversalOrder(
            order: messagesOrder,
            child: _AccessibilityGroupMarker(
              group: messageCarouselKey,
              child: _MessageCarousel(
                key: messageCarouselKey,
                section: messageSection,
                focusNode: messageFocusNode,
                initialIndex: messageInitialIndex(
                  messageSection.items,
                  activeUnreadCount(
                    chatState?.jid ??
                        (currentRecipients.isNotEmpty
                            ? currentRecipients.first.jid
                            : null),
                    currentRecipients,
                  ),
                ),
                chatLocate: chatLocate,
              ),
            ),
          ),
        if (hasMessages) SizedBox(height: spacing.s),
        if (hasComposer)
          FocusTraversalOrder(
            order: composerOrder,
            child: _AccessibilityGroupMarker(
              group: composerGroupKey,
              child: _ComposerSection(
                state: state,
                enabled: !busy,
                focusNode: composerFocusNode,
                groupKey: composerGroupKey,
                nextGroupActivator: nextGroupActivator,
                previousGroupActivator: previousGroupActivator,
              ),
            ),
          ),
        if (isConversation)
          FocusTraversalOrder(
            order: actionsOrder,
            child: _AccessibilityGroupMarker(
              group: actionsGroupKey,
              child: _ActionButtonsGroup(
                focusNode: actionsFocusNode,
                groupKey: actionsGroupKey,
                saveEnabled:
                    hasChatState && currentRecipients.isNotEmpty && !busy,
                sendEnabled:
                    state.composerText.trim().isNotEmpty &&
                    currentRecipients.isNotEmpty &&
                    !busy &&
                    hasChatState,
                activateShortcut: const SingleActivator(
                  LogicalKeyboardKey.enter,
                ),
                onSave: () => context.read<AccessibilityChatBloc>().add(
                  AccessibilityChatSaveDraftRequested(
                    body: state.composerText,
                    recipients: currentRecipients,
                    draftId: chatState?.draftId ?? state.currentEntry.draftId,
                  ),
                ),
                onSend: () => context.read<AccessibilityChatBloc>().add(
                  AccessibilityChatSendRequested(
                    body: state.composerText,
                    recipients: currentRecipients,
                  ),
                ),
              ),
            ),
          ),
        if (hasNewContact)
          FocusTraversalOrder(
            order: newContactOrder,
            child: _AccessibilityGroupMarker(
              group: newContactGroupKey,
              child: _NewContactSection(
                state: state,
                focusNode: newContactFocusNode,
                groupKey: newContactGroupKey,
                nextGroupActivator: nextGroupActivator,
                previousGroupActivator: previousGroupActivator,
              ),
            ),
          ),
        if (isConversation && hasSections) SizedBox(height: spacing.s),
        if (isConversation && hasSections)
          SizedBox(
            height: conversationListHeight,
            child: FocusTraversalOrder(
              order: actionsListOrder,
              child: _AccessibilityGroupMarker(
                group: actionsListKey,
                child: Shortcuts(
                  shortcuts: enableActivationShortcut
                      ? {activateItemActivator: const _ActivateItemIntent()}
                      : const {},
                  child: _AccessibilitySectionList(
                    key: actionsListKey,
                    sections: actionSections,
                    headerLabel: headerTitle,
                    autofocus: false,
                    initialIndex: 0,
                  ),
                ),
              ),
            ),
          ),
        if (!isConversation && hasSections)
          SizedBox(
            height: rootListHeight,
            child: FocusTraversalOrder(
              order: sectionsOrder,
              child: _AccessibilityGroupMarker(
                group: sectionsListKey,
                child: Shortcuts(
                  shortcuts: enableActivationShortcut
                      ? {activateItemActivator: const _ActivateItemIntent()}
                      : const {},
                  child: _AccessibilitySectionList(
                    key: sectionsListKey,
                    sections: actionSections,
                    headerLabel: headerTitle,
                    autofocus: !hasComposer && !hasNewContact && !hasMessages,
                  ),
                ),
              ),
            ),
          )
        else if (!isConversation && !hasSections && !hasNewContact)
          SizedBox(
            height: rootListHeight,
            child: FocusTraversalOrder(
              order: sectionsOrder,
              child: Center(
                child: Text(context.l10n.accessibilityNoActionsAvailable),
              ),
            ),
          ),
      ],
    );
  }

  double _conversationListHeight(double viewportHeight, AxiSizing sizing) {
    final heightShare = sizing.dialogMaxHeightFraction / 3;
    final minHeight = sizing.menuItemHeight * 5;
    final maxHeight = sizing.menuItemHeight * 8;
    final heightFromViewport = viewportHeight * heightShare;
    final boundedHeight = heightFromViewport.clamp(minHeight, maxHeight);
    return boundedHeight.toDouble();
  }

  double _rootListHeight(double viewportHeight, AxiSizing sizing) {
    final heightShare = sizing.dialogMaxHeightFraction / 2;
    final minHeight = sizing.menuItemHeight * 6;
    final maxHeight = sizing.menuItemHeight * 12;
    final heightFromViewport = viewportHeight * heightShare;
    final boundedHeight = heightFromViewport.clamp(minHeight, maxHeight);
    return boundedHeight.toDouble();
  }

  String _entryLabel(AccessibilityStepEntry entry, BuildContext context) {
    return _stepLabelFor(context, entry);
  }

  List<String> _breadcrumbLabels(
    AccessibilityActionState state,
    BuildContext context,
  ) => state.stack.map((entry) => _entryLabel(entry, context)).toList();
}

class _AccessibilityMenuHeader extends StatelessWidget {
  const _AccessibilityMenuHeader({
    required this.breadcrumb,
    required this.breadcrumbs,
    required this.onClose,
    this.onBack,
    this.onCrumbSelected,
  });

  final String breadcrumb;
  final List<String> breadcrumbs;
  final VoidCallback onClose;
  final VoidCallback? onBack;
  final ValueChanged<int>? onCrumbSelected;

  @override
  Widget build(BuildContext context) {
    final findShortcut = findActionShortcut(EnvScope.of(context).platform);
    final escapeShortcutValue = escapeShortcut();
    final spacing = context.spacing;
    return Row(
      children: [
        if (onBack != null)
          ShadButton.ghost(
            onPressed: onBack,
            child: const Icon(Icons.arrow_back),
          ),
        if (onBack != null) SizedBox(width: spacing.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(breadcrumb, style: context.textTheme.h3),
              ),
              SizedBox(height: spacing.xs),
              if (breadcrumbs.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: spacing.xs),
                  child: _BreadcrumbChain(
                    labels: breadcrumbs,
                    onSelected: onCrumbSelected,
                  ),
                ),
              Wrap(
                spacing: spacing.s,
                runSpacing: spacing.xs,
                children: [ShortcutHint(shortcut: findShortcut, dense: true)],
              ),
            ],
          ),
        ),
        ShadButton.ghost(
          onPressed: onClose,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.close),
              SizedBox(width: spacing.xs),
              ShortcutHint(shortcut: escapeShortcutValue, dense: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _BreadcrumbChain extends StatelessWidget {
  const _BreadcrumbChain({required this.labels, required this.onSelected});

  final List<String> labels;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final connectorStyle = context.textTheme.muted;
    final spacing = context.spacing;
    return Wrap(
      spacing: spacing.xs,
      runSpacing: spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          _BreadcrumbChip(
            label: labels[i],
            index: i,
            total: labels.length,
            onSelected: onSelected,
          ),
          if (i < labels.length - 1) Text('>', style: connectorStyle),
        ],
      ],
    );
  }
}

class _BreadcrumbChip extends StatelessWidget {
  const _BreadcrumbChip({
    required this.label,
    required this.index,
    required this.total,
    required this.onSelected,
  });

  final String label;
  final int index;
  final int total;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Focus(
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          final borderColor = hasFocus
              ? context.colorScheme.primary
              : context.colorScheme.border;
          final borderWidth = hasFocus
              ? context.sizing.progressIndicatorStrokeWidth * 2
              : context.sizing.progressIndicatorStrokeWidth;
          return Semantics(
            button: true,
            focusable: true,
            label: context.l10n.accessibilityBreadcrumbLabel(
              index + 1,
              total,
              label,
            ),
            child: AnimatedContainer(
              duration: baseAnimationDuration,
              decoration: BoxDecoration(
                color: context.colorScheme.card,
                borderRadius: context.radius,
                border: Border.all(color: borderColor, width: borderWidth),
              ),
              child: Material(
                type: MaterialType.transparency,
                borderRadius: context.radius,
                child: InkWell(
                  borderRadius: context.radius,
                  onTap: onSelected == null ? null : () => onSelected!(index),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.s,
                      vertical: spacing.xs,
                    ),
                    child: Text(label, style: context.textTheme.small),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AccessibilityBanner extends StatelessWidget {
  const _AccessibilityBanner({
    required this.message,
    required this.color,
    required this.foreground,
    required this.icon,
  });

  final String message;
  final Color color;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, borderRadius: context.radius),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.s,
            vertical: spacing.s,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: foreground,
                size: context.sizing.menuItemIconSize,
              ),
              SizedBox(width: spacing.s),
              Expanded(child: Text(message, style: context.textTheme.small)),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyboardShortcutLegend extends StatelessWidget {
  const _KeyboardShortcutLegend({
    required this.firstEntryFocusNode,
    required this.groupKey,
  });

  final FocusNode firstEntryFocusNode;
  final GlobalKey groupKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final platformShortcut = findActionShortcut(EnvScope.of(context).platform);
    final escapeShortcutValue = escapeShortcut();
    const nextFocusShortcut = SingleActivator(LogicalKeyboardKey.tab);
    const previousFocusShortcut = SingleActivator(
      LogicalKeyboardKey.tab,
      shift: true,
    );
    const activateShortcut = SingleActivator(LogicalKeyboardKey.enter);
    const nextItemShortcut = SingleActivator(LogicalKeyboardKey.arrowDown);
    const previousItemShortcut = SingleActivator(LogicalKeyboardKey.arrowUp);
    const nextGroupShortcut = SingleActivator(
      LogicalKeyboardKey.arrowDown,
      shift: true,
    );
    const previousGroupShortcut = SingleActivator(
      LogicalKeyboardKey.arrowUp,
      shift: true,
    );
    const firstItemShortcut = SingleActivator(LogicalKeyboardKey.home);
    const lastItemShortcut = SingleActivator(LogicalKeyboardKey.end);
    final entries = [
      _ShortcutLegendEntry(
        label: l10n.accessibilityShortcutOpenMenu,
        shortcut: platformShortcut,
        focusNode: firstEntryFocusNode,
      ),
      _ShortcutLegendEntry(
        label: l10n.accessibilityShortcutBack,
        shortcut: escapeShortcutValue,
      ),
      _ShortcutLegendEntry(
        label: l10n.accessibilityShortcutNextFocus,
        shortcut: nextFocusShortcut,
      ),
      _ShortcutLegendEntry(
        label: l10n.accessibilityShortcutPreviousFocus,
        shortcut: previousFocusShortcut,
      ),
      _ShortcutLegendEntry(
        label: l10n.accessibilityShortcutActivateItem,
        shortcut: activateShortcut,
      ),
      _ShortcutLegendEntry(
        label: l10n.accessibilityShortcutNextItem,
        shortcut: nextItemShortcut,
      ),
      _ShortcutLegendEntry(
        label: l10n.accessibilityShortcutPreviousItem,
        shortcut: previousItemShortcut,
      ),
      _ShortcutLegendEntry(
        label: l10n.accessibilityShortcutNextGroup,
        shortcut: nextGroupShortcut,
      ),
      _ShortcutLegendEntry(
        label: l10n.accessibilityShortcutPreviousGroup,
        shortcut: previousGroupShortcut,
      ),
      _ShortcutLegendEntry(
        label: l10n.accessibilityShortcutFirstItem,
        shortcut: firstItemShortcut,
      ),
      _ShortcutLegendEntry(
        label: l10n.accessibilityShortcutLastItem,
        shortcut: lastItemShortcut,
      ),
    ];
    return Column(
      key: groupKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FocusScope(
          child: Builder(
            builder: (context) {
              final hasFocus = FocusScope.of(context).hasFocus;
              final spacing = context.spacing;
              final borderColor = hasFocus
                  ? context.colorScheme.primary
                  : context.colorScheme.border;
              final borderWidth = hasFocus
                  ? context.sizing.progressIndicatorStrokeWidth * 2
                  : context.sizing.progressIndicatorStrokeWidth;
              return SizedBox(
                width: double.infinity,
                child: AnimatedContainer(
                  duration: baseAnimationDuration,
                  padding: EdgeInsets.all(spacing.xs),
                  decoration: BoxDecoration(
                    borderRadius: context.radius,
                    border: Border.all(color: borderColor, width: borderWidth),
                    color: context.colorScheme.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.accessibilityKeyboardShortcutsTitle,
                          style: context.textTheme.small,
                        ),
                      ),
                      SizedBox(height: spacing.xxs),
                      Wrap(
                        spacing: spacing.xxs,
                        runSpacing: spacing.xxs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: entries,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ShortcutLegendEntry extends StatelessWidget {
  const _ShortcutLegendEntry({
    required this.label,
    required this.shortcut,
    this.focusNode,
  });

  final String label;
  final MenuSerializableShortcut shortcut;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final textStyle = context.textTheme.muted;
    final description = '$label, ${shortcutLabel(context, shortcut)}';
    return Focus(
      focusNode: focusNode,
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          final borderColor = hasFocus
              ? context.colorScheme.primary
              : context.colorScheme.border;
          final borderWidth = hasFocus
              ? context.sizing.progressIndicatorStrokeWidth * 2
              : context.sizing.progressIndicatorStrokeWidth;
          return Semantics(
            label: context.l10n.accessibilityKeyboardShortcutAnnouncement(
              description,
            ),
            focusable: true,
            readOnly: true,
            child: AnimatedContainer(
              duration: baseAnimationDuration,
              decoration: BoxDecoration(
                borderRadius: context.radius,
                border: Border.all(color: borderColor, width: borderWidth),
                color: context.colorScheme.muted.withValues(
                  alpha: context.motion.tapHoverAlpha / 2,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.xs,
                  vertical: spacing.xxs,
                ),
                child: Wrap(
                  spacing: spacing.xs,
                  runSpacing: spacing.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(label, style: textStyle),
                    ShortcutHint(shortcut: shortcut, dense: true),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ComposerSection extends StatelessWidget {
  const _ComposerSection({
    required this.state,
    required this.enabled,
    required this.focusNode,
    required this.groupKey,
    required this.nextGroupActivator,
    required this.previousGroupActivator,
  });

  final AccessibilityActionState state;
  final bool enabled;
  final FocusNode focusNode;
  final GlobalKey groupKey;
  final ShortcutActivator nextGroupActivator;
  final ShortcutActivator previousGroupActivator;

  @override
  Widget build(BuildContext context) {
    final recipients = state.currentEntry.recipients;
    final spacing = context.spacing;
    return FocusTraversalGroup(
      key: groupKey,
      policy: OrderedTraversalPolicy(),
      child: Padding(
        padding: EdgeInsets.only(bottom: spacing.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FocusTraversalOrder(
              order: const NumericFocusOrder(0),
              child: _AccessibilityTextField(
                label: context.l10n.chatComposerMessageHint,
                text: state.composerText,
                onChanged: (value) => context
                    .read<AccessibilityActionBloc>()
                    .add(AccessibilityComposerChanged(value)),
                hintText: context.l10n.accessibilityComposerPlaceholder,
                minLines: 3,
                maxLines: 5,
                enabled: enabled,
                focusNode: focusNode,
                autofocus: false,
                nextGroupActivator: nextGroupActivator,
                previousGroupActivator: previousGroupActivator,
              ),
            ),
            SizedBox(height: spacing.s),
            FocusTraversalOrder(
              order: const NumericFocusOrder(1),
              child: Material(
                type: MaterialType.transparency,
                child: Wrap(
                  spacing: spacing.s,
                  runSpacing: spacing.s,
                  children: recipients
                      .map(
                        (recipient) => Semantics(
                          label: context.l10n.accessibilityRecipientLabel(
                            recipient.displayName,
                          ),
                          button: true,
                          hint: context.l10n.accessibilityRecipientRemoveHint,
                          child: InputChip(
                            label: Text(recipient.displayName),
                            onDeleted: () =>
                                context.read<AccessibilityActionBloc>().add(
                                  AccessibilityRecipientRemoved(recipient.jid),
                                ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButtonsGroup extends StatelessWidget {
  const _ActionButtonsGroup({
    required this.focusNode,
    required this.groupKey,
    required this.saveEnabled,
    required this.sendEnabled,
    required this.activateShortcut,
    required this.onSave,
    required this.onSend,
  });

  final FocusNode focusNode;
  final GlobalKey groupKey;
  final bool saveEnabled;
  final bool sendEnabled;
  final MenuSerializableShortcut activateShortcut;
  final VoidCallback onSave;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return FocusTraversalGroup(
      key: groupKey,
      policy: OrderedTraversalPolicy(),
      child: Focus(
        focusNode: focusNode,
        child: Builder(
          builder: (context) {
            final hasFocus = Focus.of(context).hasFocus;
            final borderColor = hasFocus
                ? context.colorScheme.primary
                : context.colorScheme.border;
            final borderWidth = hasFocus
                ? context.sizing.progressIndicatorStrokeWidth * 2
                : context.sizing.progressIndicatorStrokeWidth;
            final isNarrow =
                MediaQuery.sizeOf(context).width <
                context.sizing.dialogMaxWidth;
            final saveButton = ShadButton.outline(
              onPressed: saveEnabled ? onSave : null,
              child: Text(context.l10n.draftSave),
            );
            final sendButton = ShadButton(
              onPressed: sendEnabled ? onSend : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.commonSend),
                  SizedBox(width: spacing.s),
                  ShortcutHint(shortcut: activateShortcut, dense: true),
                ],
              ),
            );
            final buttons = isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      saveButton,
                      SizedBox(height: spacing.s),
                      sendButton,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: saveButton),
                      SizedBox(width: spacing.s),
                      Expanded(child: sendButton),
                    ],
                  );
            return Semantics(
              container: true,
              label: context.l10n.accessibilityMessageActionsLabel,
              hint: context.l10n.accessibilityMessageActionsHint,
              child: AnimatedContainer(
                duration: baseAnimationDuration,
                padding: EdgeInsets.all(spacing.s),
                decoration: BoxDecoration(
                  color: context.colorScheme.card,
                  borderRadius: context.radius,
                  border: Border.all(color: borderColor, width: borderWidth),
                ),
                child: buttons,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NewContactSection extends StatelessWidget {
  const _NewContactSection({
    required this.state,
    required this.focusNode,
    required this.groupKey,
    required this.nextGroupActivator,
    required this.previousGroupActivator,
  });

  final AccessibilityActionState state;
  final FocusNode focusNode;
  final GlobalKey groupKey;
  final ShortcutActivator nextGroupActivator;
  final ShortcutActivator previousGroupActivator;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final canSubmit = AddressStringExtensions(
      state.newContactInput.trim(),
    ).isValidJid;
    final locate = context.read;
    return FocusTraversalGroup(
      key: groupKey,
      policy: WidgetOrderTraversalPolicy(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: spacing.s),
            child: _AccessibilityTextField(
              label: context.l10n.accessibilityNewContactLabel,
              text: state.newContactInput,
              onChanged: (value) => locate<AccessibilityActionBloc>().add(
                AccessibilityNewContactChanged(value),
              ),
              hintText: context.l10n.accessibilityNewContactHint,
              enabled: !state.busy,
              focusNode: focusNode,
              autofocus: true,
              nextGroupActivator: nextGroupActivator,
              previousGroupActivator: previousGroupActivator,
            ),
          ),
          Focus(
            child: Builder(
              builder: (context) {
                final hasFocus = Focus.of(context).hasFocus;
                final borderColor = hasFocus
                    ? context.colorScheme.primary
                    : context.colorScheme.border;
                final borderWidth = hasFocus
                    ? context.sizing.progressIndicatorStrokeWidth * 2
                    : context.sizing.progressIndicatorStrokeWidth;
                return Semantics(
                  container: true,
                  button: true,
                  enabled: canSubmit,
                  label: context.l10n.accessibilityStartChat,
                  hint: context.l10n.accessibilityStartChatHint,
                  child: AnimatedContainer(
                    duration: baseAnimationDuration,
                    padding: EdgeInsets.all(spacing.s),
                    decoration: BoxDecoration(
                      color: context.colorScheme.card,
                      borderRadius: context.radius,
                      border: Border.all(
                        color: borderColor,
                        width: borderWidth,
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ShadButton(
                        onPressed: canSubmit
                            ? () => _confirmNewContact(context)
                            : null,
                        child: Text(context.l10n.accessibilityStartChat),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmNewContact(BuildContext context) async {
  final address = context
      .read<AccessibilityActionBloc>()
      .state
      .newContactInput
      .trim();
  if (address.isEmpty) return;
  final endpointConfig = context.read<SettingsCubit>().state.endpointConfig;
  final supportsEmail = endpointConfig.smtpEnabled;
  final supportsXmpp = endpointConfig.xmppEnabled;
  MessageTransport? resolved;
  if (supportsEmail && !supportsXmpp) {
    resolved = MessageTransport.email;
  } else if (!supportsEmail && supportsXmpp) {
    resolved = MessageTransport.xmpp;
  } else if (supportsEmail && supportsXmpp) {
    final hinted = hintTransportForAddress(address);
    resolved = await showTransportChoiceDialog(
      context,
      address: address,
      defaultTransport: hinted,
    );
  }
  if (!context.mounted || resolved == null) return;
  context.read<AccessibilityActionBloc>().add(
    AccessibilityMenuActionTriggered(
      AccessibilityCommandAction(
        command: AccessibilityCommand.confirmNewContact,
        transport: resolved,
      ),
    ),
  );
}

Future<void> _handleMenuAction(
  BuildContext context,
  AccessibilityMenuAction action,
) async {
  if (action is AccessibilityCommandAction &&
      action.command == AccessibilityCommand.confirmNewContact) {
    await _confirmNewContact(context);
    return;
  }
  context.read<AccessibilityActionBloc>().add(
    AccessibilityMenuActionTriggered(action),
  );
}

class _AccessibilityTextField extends StatefulWidget {
  const _AccessibilityTextField({
    required this.label,
    required this.text,
    required this.onChanged,
    required this.hintText,
    required this.nextGroupActivator,
    required this.previousGroupActivator,
    this.minLines = 1,
    this.maxLines = 1,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
  });

  final String label;
  final String text;
  final ValueChanged<String> onChanged;
  final String hintText;
  final ShortcutActivator nextGroupActivator;
  final ShortcutActivator previousGroupActivator;
  final int minLines;
  final int maxLines;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<_AccessibilityTextField> createState() =>
      _AccessibilityTextFieldState();
}

class _AccessibilityTextFieldState extends State<_AccessibilityTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );
  late FocusNode _focusNode =
      widget.focusNode ??
      FocusNode(debugLabel: 'accessibility-text-${widget.label}');
  late bool _ownsFocusNode = widget.focusNode == null;
  bool _didAutofocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    _maybeRequestAutofocus();
  }

  @override
  void didUpdateWidget(covariant _AccessibilityTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autofocus != widget.autofocus) {
      _maybeRequestAutofocus();
    }
    if (oldWidget.focusNode != widget.focusNode && widget.focusNode != null) {
      _focusNode.removeListener(_onFocusChanged);
      if (_ownsFocusNode) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode!;
      _ownsFocusNode = false;
      _focusNode.addListener(_onFocusChanged);
      _didAutofocus = false;
    }
    if (oldWidget.text != widget.text && _controller.text != widget.text) {
      _controller.text = widget.text;
      _controller.selection = TextSelection.collapsed(
        offset: widget.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_onFocusChanged);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  void _maybeRequestAutofocus() {
    if (!widget.autofocus || _focusNode.hasFocus || _didAutofocus) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_focusNode.canRequestFocus) {
        _focusNode.requestFocus();
        _didAutofocus = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final hasFocus = _focusNode.hasFocus;
    final navigationShortcuts = <ShortcutActivator, Intent>{
      widget.nextGroupActivator: const _NextGroupIntent(),
      widget.previousGroupActivator: const _PreviousGroupIntent(),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: context.textTheme.small),
        SizedBox(height: spacing.xs),
        Semantics(
          textField: true,
          label: widget.label,
          hint: context.l10n.accessibilityTextFieldHint,
          child: AnimatedContainer(
            duration: baseAnimationDuration,
            decoration: BoxDecoration(
              borderRadius: context.radius,
              border: Border.all(
                color: hasFocus
                    ? context.colorScheme.primary
                    : context.colorScheme.border,
                width: hasFocus
                    ? context.sizing.progressIndicatorStrokeWidth * 2
                    : context.sizing.progressIndicatorStrokeWidth,
              ),
            ),
            padding: EdgeInsets.all(spacing.xxs),
            child: Shortcuts(
              shortcuts: navigationShortcuts,
              child: AxiTextInput(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                minLines: widget.minLines,
                maxLines: widget.maxLines,
                placeholder: Text(widget.hintText),
                onChanged: widget.onChanged,
                decoration: const ShadDecoration(
                  border: ShadBorder.none,
                  focusedBorder: ShadBorder.none,
                  errorBorder: ShadBorder.none,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageCarousel extends StatefulWidget {
  const _MessageCarousel({
    super.key,
    required this.section,
    required this.focusNode,
    required this.initialIndex,
    required this.chatLocate,
  });

  final AccessibilityMenuSection section;
  final FocusNode focusNode;
  final int initialIndex;
  final T Function<T>()? chatLocate;

  @override
  State<_MessageCarousel> createState() => _MessageCarouselState();
}

class _MessageCarouselState extends State<_MessageCarousel> {
  late int _currentIndex = _clampIndex(widget.initialIndex);
  bool _appliedInitial = false;

  List<AccessibilityMenuItem> get _items => widget.section.items;

  @override
  void didUpdateWidget(covariant _MessageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final itemCountChanged = _items.length != oldWidget.section.items.length;
    final initialChanged = widget.initialIndex != oldWidget.initialIndex;
    final targetIndex = _clampIndex(widget.initialIndex);
    final clampedCurrent = _clampIndex(_currentIndex);
    if (itemCountChanged || initialChanged) {
      if (_currentIndex != targetIndex) {
        setState(() {
          _currentIndex = targetIndex;
        });
      } else if (clampedCurrent != _currentIndex) {
        setState(() {
          _currentIndex = clampedCurrent;
        });
      }
      _appliedInitial = false;
      return;
    }
    if (clampedCurrent != _currentIndex) {
      setState(() {
        _currentIndex = clampedCurrent;
      });
    }
  }

  void focusInitial() {
    if (!_appliedInitial) {
      _setIndex(_clampIndex(widget.initialIndex));
      _appliedInitial = true;
      return;
    }
    _requestFocus();
  }

  void focusCurrent() => _requestFocus();
  void nextMessage() => _setIndex(_currentIndex + 1);
  void previousMessage() => _setIndex(_currentIndex - 1);
  void firstMessage() => _setIndex(0);
  void lastMessage() => _setIndex(_items.isEmpty ? 0 : _items.length - 1);

  int _clampIndex(int value) {
    if (_items.isEmpty) return 0;
    return value.clamp(0, _items.length - 1);
  }

  void _setIndex(int value) {
    final clamped = _clampIndex(value);
    if (clamped != _currentIndex) {
      setState(() {
        _currentIndex = clamped;
      });
    }
    _requestFocus();
  }

  void _requestFocus() {
    if (widget.focusNode.canRequestFocus) {
      widget.focusNode.requestFocus();
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final logicalKey = event.logicalKey;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final hasShift =
        pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight) ||
        pressed.contains(LogicalKeyboardKey.shift);
    if (hasShift &&
        (logicalKey == LogicalKeyboardKey.arrowDown ||
            logicalKey == LogicalKeyboardKey.arrowUp)) {
      return KeyEventResult.ignored;
    }
    if (logicalKey == LogicalKeyboardKey.arrowDown) {
      nextMessage();
      return KeyEventResult.handled;
    }
    if (logicalKey == LogicalKeyboardKey.arrowUp) {
      previousMessage();
      return KeyEventResult.handled;
    }
    if (logicalKey == LogicalKeyboardKey.home) {
      firstMessage();
      return KeyEventResult.handled;
    }
    if (logicalKey == LogicalKeyboardKey.end) {
      lastMessage();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final spacing = context.spacing;
    final chatLocate = widget.chatLocate;
    final hasFocus = widget.focusNode.hasFocus;
    final hasItems = items.isNotEmpty;
    final clampedIndex = _currentIndex.clamp(
      0,
      hasItems ? items.length - 1 : 0,
    );
    final currentItem = hasItems ? items[clampedIndex] : null;
    final currentMessage = currentItem?.message;
    final attachment = currentItem?.attachment;
    final showMetadata = currentItem?.showMetadata ?? false;
    final senderLabel = currentItem?.senderLabel ?? '';
    final timestampLabel = currentItem?.timestampLabel ?? '';
    final attachmentLabel = currentItem?.attachmentLabel;
    final rawBody = (currentMessage?.body ?? '').trim();
    final positionLabel = hasItems
        ? context.l10n.accessibilityMessagePosition(
            clampedIndex + 1,
            items.length,
          )
        : context.l10n.accessibilityNoMessages;
    final metadataValue = showMetadata && senderLabel.isNotEmpty
        ? (timestampLabel.isNotEmpty
              ? context.l10n.accessibilityMessageMetadata(
                  senderLabel,
                  timestampLabel,
                )
              : context.l10n.accessibilityMessageFrom(senderLabel))
        : null;
    final borderColor = hasFocus
        ? context.colorScheme.primary
        : context.colorScheme.border;
    final borderWidth = hasFocus
        ? context.sizing.progressIndicatorStrokeWidth * 2
        : context.sizing.progressIndicatorStrokeWidth;
    final borderRadius = context.radius;
    final shadows = hasFocus
        ? [
            BoxShadow(
              color: context.colorScheme.primary.withValues(
                alpha: context.motion.tapSplashAlpha,
              ),
              blurRadius: context.sizing.modalShadowBlur / 2,
              offset: Offset(0, context.sizing.modalShadowOffsetY / 4),
            ),
          ]
        : const <BoxShadow>[];
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: _handleKey,
      child: Semantics(
        container: true,
        focusable: true,
        label: positionLabel,
        value: metadataValue,
        hint: context.l10n.accessibilityMessageNavigationHint,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: AnimatedContainer(
            duration: baseAnimationDuration,
            padding: EdgeInsets.all(spacing.s),
            decoration: BoxDecoration(
              color: hasFocus
                  ? context.colorScheme.primary.withValues(
                      alpha:
                          context.motion.tapHoverAlpha -
                          (context.motion.tapHoverAlpha / 4),
                    )
                  : context.colorScheme.card,
              borderRadius: borderRadius,
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: shadows,
            ),
            child: AnimatedSize(
              duration: baseAnimationDuration,
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(positionLabel, style: context.textTheme.muted),
                  SizedBox(height: spacing.s),
                  if (showMetadata && senderLabel.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: spacing.xs),
                      child: Text(
                        metadataValue ??
                            context.l10n.accessibilityMessageFrom(senderLabel),
                        style: context.textTheme.muted,
                      ),
                    ),
                  if (rawBody.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: spacing.xs),
                      child: Text(rawBody, style: context.textTheme.p),
                    ),
                  if (attachment != null)
                    Semantics(
                      label:
                          attachmentLabel ??
                          context.l10n.accessibilityAttachmentGeneric,
                      child: ChatAttachmentPreview(
                        stanzaId: currentMessage?.stanzaID ?? '',
                        metadata: attachment,
                        allowed: true,
                        downloadDelegate: chatLocate == null
                            ? null
                            : AttachmentDownloadDelegate(
                                () => chatLocate<ChatBloc>()
                                    .downloadInboundAttachment(
                                      metadataId: attachment.id,
                                      stanzaId: currentMessage?.stanzaID ?? '',
                                    ),
                              ),
                        metadataReloadDelegate: chatLocate == null
                            ? null
                            : AttachmentMetadataReloadDelegate(
                                () => chatLocate<ChatBloc>().reloadFileMetadata(
                                  attachment.id,
                                ),
                              ),
                      ),
                    )
                  else if (attachmentLabel != null && rawBody.isEmpty)
                    Text(attachmentLabel, style: context.textTheme.p),
                  if (rawBody.isEmpty &&
                      attachment == null &&
                      (attachmentLabel == null || attachmentLabel.isEmpty))
                    Text(
                      context.l10n.accessibilityMessageNoContent,
                      style: context.textTheme.muted,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessibilitySectionList extends StatefulWidget {
  const _AccessibilitySectionList({
    super.key,
    required this.sections,
    required this.headerLabel,
    this.autofocus = true,
    this.initialIndex,
  });

  final List<AccessibilityMenuSection> sections;
  final String headerLabel;
  final bool autofocus;
  final int? initialIndex;

  @override
  State<_AccessibilitySectionList> createState() =>
      _AccessibilitySectionListState();
}

class _AccessibilitySectionListState extends State<_AccessibilitySectionList> {
  final ScrollController _scrollController = ScrollController();
  List<FocusNode> _itemNodes = <FocusNode>[];
  int? _lastFocusedIndex;
  bool _hasFocusedItem = false;

  bool get isEditingText {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    final focusContext = focus.context;
    if (focusContext == null || !focusContext.mounted) return false;
    return focusContext.widget is EditableText;
  }

  @override
  void initState() {
    super.initState();
    _refreshStructure();
  }

  @override
  void didUpdateWidget(covariant _AccessibilitySectionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshStructure();
  }

  @override
  void dispose() {
    _disposeNodes();
    _scrollController.dispose();
    super.dispose();
  }

  void focusFirstItem() => _focusIndex(0);
  void focusLastItem() => _focusIndex(_itemNodes.length - 1);
  void focusInitial({int? fallbackIndex}) {
    final current = _currentIndex();
    if (current != null) {
      _focusIndex(current);
      return;
    }
    _focusIndex(fallbackIndex ?? widget.initialIndex ?? 0);
  }

  void focusNextItem() {
    final current = _currentIndex();
    _focusIndex(current == null ? 0 : current + 1);
  }

  void focusPreviousItem() {
    final current = _currentIndex();
    _focusIndex(current == null ? 0 : current - 1);
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    var nodeIndex = 0;
    final spacing = context.spacing;
    for (
      var sectionIndex = 0;
      sectionIndex < widget.sections.length;
      sectionIndex++
    ) {
      final section = widget.sections[sectionIndex];
      final sectionLabel =
          section.title ?? context.l10n.accessibilityActionsTitle;
      final isDuplicateTitle =
          section.title != null && section.title == widget.headerLabel;
      children.add(
        Semantics(
          container: true,
          label: context.l10n.accessibilitySectionSummary(
            sectionLabel,
            section.items.length,
          ),
          child: section.title != null && !isDuplicateTitle
              ? Padding(
                  padding: EdgeInsets.only(bottom: spacing.s),
                  child: Semantics(
                    header: true,
                    child: Text(
                      section.title!,
                      style: context.textTheme.sectionLabelM,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      );
      for (final item in section.items) {
        final focusNode = nodeIndex < _itemNodes.length
            ? _itemNodes[nodeIndex]
            : null;
        children.add(
          Padding(
            padding: EdgeInsets.only(bottom: spacing.s),
            child: _AccessibilityActionTile(
              item: item,
              index: nodeIndex,
              totalCount: _itemNodes.length,
              sectionLabel: sectionLabel,
              focusNode: focusNode,
              autofocus: widget.autofocus && nodeIndex == 0,
              onFocused: () => _lastFocusedIndex = nodeIndex,
              onFocusChanged: (hasFocus) =>
                  _handleFocusChanged(nodeIndex, hasFocus),
              onTap: () => _handleMenuAction(context, item.action),
              onDismiss: item.dismissId == null
                  ? null
                  : () => context.read<AccessibilityActionBloc>().add(
                      AccessibilityMenuActionTriggered(
                        AccessibilityDismissHighlightAction(
                          highlightId: item.dismissId!,
                        ),
                      ),
                    ),
            ),
          ),
        );
        nodeIndex++;
      }
      final hasMoreSections = sectionIndex < widget.sections.length - 1;
      if (hasMoreSections) {
        children.add(SizedBox(height: spacing.s));
      }
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final borderColor = _hasFocusedItem
            ? context.colorScheme.primary
            : context.colorScheme.border;
        final borderWidth = _hasFocusedItem
            ? context.sizing.progressIndicatorStrokeWidth * 2
            : context.sizing.progressIndicatorStrokeWidth;
        return Semantics(
          container: true,
          label: context.l10n.accessibilityActionListLabel(_itemNodes.length),
          hint: context.l10n.accessibilityActionListHint,
          explicitChildNodes: true,
          child: AnimatedContainer(
            duration: baseAnimationDuration,
            padding: EdgeInsets.all(spacing.xs),
            decoration: BoxDecoration(
              borderRadius: context.radius,
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            child: ListView.builder(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              semanticChildCount: children.length,
              itemCount: children.length,
              itemBuilder: (context, index) => children[index],
            ),
          ),
        );
      },
    );
  }

  void _refreshStructure() {
    final itemCount = widget.sections.fold<int>(
      0,
      (total, section) => total + section.items.length,
    );
    if (itemCount != _itemNodes.length) {
      _disposeNodes();
      _itemNodes = List.generate(
        itemCount,
        (index) => FocusNode(debugLabel: 'accessibility-item-$index'),
      );
    }
    if (_lastFocusedIndex != null &&
        (_lastFocusedIndex! < 0 || _lastFocusedIndex! >= _itemNodes.length)) {
      _lastFocusedIndex = null;
    }
    _hasFocusedItem = _itemNodes.any((node) => node.hasFocus);
    if (widget.autofocus &&
        _itemNodes.isNotEmpty &&
        _lastFocusedIndex == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final target = (widget.initialIndex ?? 0).clamp(
            0,
            _itemNodes.length - 1,
          );
          _focusIndex(target);
        }
      });
    }
  }

  void activateFocused() {
    final current = _currentIndex();
    if (current == null || current < 0 || current >= _itemNodes.length) return;
    final item = _itemForIndex(current);
    if (item == null ||
        item.disabled ||
        item.kind == AccessibilityMenuItemKind.readOnly) {
      return;
    }
    if (!mounted) return;
    _handleMenuAction(context, item.action);
  }

  int? _currentIndex() {
    if (_itemNodes.isEmpty) return null;
    if (_lastFocusedIndex != null &&
        _lastFocusedIndex! >= 0 &&
        _lastFocusedIndex! < _itemNodes.length &&
        _itemNodes[_lastFocusedIndex!].hasFocus) {
      return _lastFocusedIndex;
    }
    final index = _itemNodes.indexWhere((node) => node.hasFocus);
    return index == -1 ? null : index;
  }

  AccessibilityMenuItem? _itemForIndex(int index) {
    var cursor = 0;
    for (final section in widget.sections) {
      for (final item in section.items) {
        if (cursor == index) {
          return item;
        }
        cursor++;
      }
    }
    return null;
  }

  void _focusIndex(int index) {
    if (_itemNodes.isEmpty) return;
    final previousIndex = _lastFocusedIndex;
    final clamped = index.clamp(0, _itemNodes.length - 1);
    final focusNode = _itemNodes[clamped];
    _lastFocusedIndex = clamped;
    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
    }
    _scrollToIndex(clamped, previousIndex);
  }

  void _handleFocusChanged(int index, bool hasFocus) {
    if (!mounted) return;
    if (hasFocus) {
      final previousIndex = _lastFocusedIndex;
      _lastFocusedIndex = index;
      _scrollToIndex(index, previousIndex);
      if (!_hasFocusedItem) {
        setState(() {
          _hasFocusedItem = true;
        });
      }
      return;
    }
    final anyFocused = _itemNodes.any((node) => node.hasFocus);
    if (_hasFocusedItem != anyFocused) {
      setState(() {
        _hasFocusedItem = anyFocused;
      });
    }
  }

  void _scrollToIndex(int index, int? previousIndex) {
    if (index < 0 || index >= _itemNodes.length) return;
    final focusContext = _itemNodes[index].context;
    if (focusContext == null) return;
    final movingUp = previousIndex != null && index < previousIndex;
    final alignmentPolicy = movingUp
        ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
        : ScrollPositionAlignmentPolicy.keepVisibleAtEnd;
    Scrollable.ensureVisible(
      focusContext,
      duration: baseAnimationDuration,
      curve: Curves.easeInOutCubic,
      alignment: movingUp ? 0.05 : 0.95,
      alignmentPolicy: alignmentPolicy,
    );
  }

  void _disposeNodes() {
    for (final node in _itemNodes) {
      node.dispose();
    }
    _itemNodes = <FocusNode>[];
  }
}

class _AccessibilityActionTile extends StatelessWidget {
  const _AccessibilityActionTile({
    required this.item,
    required this.index,
    required this.totalCount,
    required this.sectionLabel,
    required this.onTap,
    this.onDismiss,
    this.focusNode,
    this.autofocus = false,
    this.onFocused,
    this.onFocusChanged,
  });

  final AccessibilityMenuItem item;
  final int index;
  final int totalCount;
  final String sectionLabel;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;
  final FocusNode? focusNode;
  final bool autofocus;
  final VoidCallback? onFocused;
  final ValueChanged<bool>? onFocusChanged;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final isReadOnly = item.kind == AccessibilityMenuItemKind.readOnly;
    final tileColor = item.highlight
        ? context.colorScheme.primary.withValues(
            alpha: context.motion.tapHoverAlpha,
          )
        : context.colorScheme.card;
    final foreground = item.destructive
        ? context.colorScheme.destructive
        : context.colorScheme.foreground;
    final positionLabel = context.l10n.accessibilityActionItemPosition(
      index + 1,
      totalCount,
      sectionLabel,
    );
    final semanticsLabel = [
      item.label,
      if (item.description != null && item.description!.isNotEmpty)
        item.description!,
    ].join(', ');
    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      canRequestFocus: true,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          onFocused?.call();
        }
        onFocusChanged?.call(hasFocus);
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          final borderColor = hasFocus
              ? context.colorScheme.primary
              : context.colorScheme.border;
          final borderWidth = hasFocus
              ? context.sizing.progressIndicatorStrokeWidth * 2
              : context.sizing.progressIndicatorStrokeWidth;
          final isEnabled = isReadOnly ? true : !item.disabled;
          return Semantics(
            button: !isReadOnly,
            focusable: true,
            label: semanticsLabel,
            enabled: isEnabled,
            value: positionLabel,
            onTap: isReadOnly || item.disabled ? null : onTap,
            hint: isReadOnly
                ? context.l10n.accessibilityActionReadOnlyHint
                : item.disabled
                ? null
                : context.l10n.accessibilityActionActivateHint,
            child: AnimatedContainer(
              duration: baseAnimationDuration,
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: context.radius,
                border: Border.all(color: borderColor, width: borderWidth),
                boxShadow: [
                  if (hasFocus)
                    BoxShadow(
                      color: context.colorScheme.primary.withValues(
                        alpha:
                            context.motion.tapSplashAlpha +
                            (context.motion.tapHoverAlpha / 4),
                      ),
                      blurRadius: context.sizing.modalShadowBlur / 4,
                      offset: Offset(0, context.sizing.modalShadowOffsetY / 8),
                    ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                borderRadius: context.radius,
                child: InkWell(
                  onTap: isReadOnly || item.disabled ? null : onTap,
                  borderRadius: context.radius,
                  focusColor: context.colorScheme.primary.withValues(
                    alpha:
                        context.motion.tapHoverAlpha +
                        (context.motion.tapHoverAlpha / 4),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.m,
                      vertical: spacing.s,
                    ),
                    child: Row(
                      children: [
                        if (item.icon != null)
                          Padding(
                            padding: EdgeInsets.only(right: spacing.s),
                            child: Icon(item.icon, color: foreground),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.label, style: context.textTheme.p),
                              if (item.description != null)
                                Text(
                                  item.description!,
                                  style: context.textTheme.muted,
                                ),
                            ],
                          ),
                        ),
                        if (item.badge != null)
                          Container(
                            decoration: BoxDecoration(
                              color: context.colorScheme.secondary.withValues(
                                alpha:
                                    context.motion.tapSplashAlpha +
                                    (context.motion.tapHoverAlpha / 4),
                              ),
                              borderRadius: context.radius,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: spacing.s,
                              vertical: spacing.xs,
                            ),
                            child: Text(
                              item.badge!,
                              style: context.textTheme.small,
                            ),
                          ),
                        if (onDismiss != null) ...[
                          SizedBox(width: spacing.s),
                          AxiTooltip(
                            builder: (_) => Text(context.l10n.commonDismiss),
                            child: Semantics(
                              button: true,
                              label: context.l10n.accessibilityDismissHighlight,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.notifications_off_outlined,
                                ),
                                onPressed: onDismiss,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AccessibilityDismissIntent extends Intent {
  const _AccessibilityDismissIntent();
}

class _NextItemIntent extends Intent {
  const _NextItemIntent();
}

class _PreviousItemIntent extends Intent {
  const _PreviousItemIntent();
}

class _NextGroupIntent extends Intent {
  const _NextGroupIntent();
}

class _PreviousGroupIntent extends Intent {
  const _PreviousGroupIntent();
}

class _FirstItemIntent extends Intent {
  const _FirstItemIntent();
}

class _LastItemIntent extends Intent {
  const _LastItemIntent();
}

class _ActivateItemIntent extends Intent {
  const _ActivateItemIntent();
}
