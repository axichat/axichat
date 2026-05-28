// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/compose_recipient.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/compose_window_cubit.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/view/draft_form.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ComposeDraftContent extends StatelessWidget {
  const ComposeDraftContent({
    super.key,
    required this.seed,
    this.draftFormKey,
    this.recipientCountAdjustment = 0,
    this.subjectTrailing,
    this.onClosed,
    this.onDiscarded,
    this.onDraftSaved,
  });

  final ComposeDraftSeed seed;
  final GlobalKey<DraftFormState>? draftFormKey;
  final int recipientCountAdjustment;
  final Widget? subjectTrailing;
  final VoidCallback? onClosed;
  final VoidCallback? onDiscarded;
  final ValueChanged<int>? onDraftSaved;

  @override
  Widget build(BuildContext context) {
    return _ComposeDraftFormContent(
      seed: seed,
      draftFormKey: draftFormKey,
      recipientCountAdjustment: recipientCountAdjustment,
      subjectTrailing: subjectTrailing,
      onClosed: onClosed,
      onDiscarded: onDiscarded,
      onDraftSaved: onDraftSaved,
      showQuoteBanner: true,
    );
  }
}

class _ComposeDraftFormContent extends StatefulWidget {
  const _ComposeDraftFormContent({
    required this.seed,
    required this.showQuoteBanner,
    this.draftFormKey,
    this.recipientCountAdjustment = 0,
    this.subjectTrailing,
    this.onClosed,
    this.onDiscarded,
    this.onDraftSaved,
  });

  final ComposeDraftSeed seed;
  final bool showQuoteBanner;
  final GlobalKey<DraftFormState>? draftFormKey;
  final int recipientCountAdjustment;
  final Widget? subjectTrailing;
  final VoidCallback? onClosed;
  final VoidCallback? onDiscarded;
  final ValueChanged<int>? onDraftSaved;

  @override
  State<_ComposeDraftFormContent> createState() =>
      _ComposeDraftFormContentState();
}

class _ComposeDraftFormContentState extends State<_ComposeDraftFormContent> {
  bool _quoteDismissed = false;
  late List<String> _recipientAddresses;
  String? _quotedMessageLookupId;
  Message? _quotedMessage;

  @override
  void initState() {
    super.initState();
    _recipientAddresses = _normalizeRecipientAddresses(widget.seed.jids);
    _quotedMessageLookupId = _effectiveQuoteTarget?.stanzaId.trim();
    final lookupId = _quotedMessageLookupId;
    if (lookupId != null && lookupId.isNotEmpty) {
      unawaited(_loadQuotedMessage(lookupId));
    }
  }

  @override
  void didUpdateWidget(covariant _ComposeDraftFormContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed.id == widget.seed.id &&
        oldWidget.seed.quoteTarget == widget.seed.quoteTarget &&
        listEquals(oldWidget.seed.jids, widget.seed.jids) &&
        mapEquals(
          oldWidget.seed.recipientTransportOverrides,
          widget.seed.recipientTransportOverrides,
        )) {
      return;
    }
    _quoteDismissed = false;
    _recipientAddresses = _normalizeRecipientAddresses(widget.seed.jids);
    _quotedMessageLookupId = null;
    _quotedMessage = null;
    _syncQuotedMessagePreview();
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = context.watch<SettingsCubit>().state;
    final profileState = context.watch<ProfileCubit>().state;
    final chatsState = context.watch<ChatsCubit>().state;
    final profileJid = profileState.jid.trim();
    final String? myJid = profileJid.isEmpty ? null : profileJid;
    final suggestionAddresses = <String>{if (myJid?.isNotEmpty == true) myJid!};
    final suggestionDomains = <String>{
      EndpointConfig.defaultDomain,
      ...suggestionAddresses.map(_domainFromAddress).whereType<String>(),
    };
    final quoteTarget = widget.showQuoteBanner ? _effectiveQuoteTarget : null;
    return DraftForm(
      key: widget.draftFormKey,
      id: widget.seed.id,
      jids: widget.seed.jids,
      initialRecipients: _initialRecipients(
        jids: widget.seed.jids,
        chats: chatsState.items ?? const <Chat>[],
        shareSignatureEnabled: settingsState.shareTokenSignatureEnabled,
        recipientTransportOverrides: widget.seed.recipientTransportOverrides,
      ),
      recipientTransportOverrides: widget.seed.recipientTransportOverrides,
      body: widget.seed.body,
      subject: widget.seed.subject,
      quoteTarget: _effectiveQuoteTarget,
      attachmentMetadataIds: widget.seed.attachmentMetadataIds,
      calendarTaskIcsMessage: widget.seed.calendarTaskIcsMessage,
      forwardedBlocks: widget.seed.forwardedBlocks,
      forwardedSourceAttachmentMetadataIds:
          widget.seed.forwardedSourceAttachmentMetadataIds,
      autosaveEnabled: widget.seed.autosaveEnabled,
      suggestionAddresses: suggestionAddresses,
      suggestionDomains: suggestionDomains,
      recipientCountAdjustment: widget.recipientCountAdjustment,
      subjectTrailing: widget.subjectTrailing,
      banner: quoteTarget == null
          ? null
          : _DraftQuoteBanner(
              quotedMessage: _quotedMessage,
              selfJid: myJid,
              onClear: _handleQuoteCleared,
            ),
      onRecipientAddressesChanged: _handleRecipientAddressesChanged,
      onClosed: widget.onClosed,
      onDiscarded: widget.onDiscarded,
      onDraftSaved: widget.onDraftSaved,
    );
  }

  void _handleQuoteCleared() {
    setState(() {
      _quoteDismissed = true;
      _quotedMessageLookupId = null;
      _quotedMessage = null;
    });
  }

  void _handleRecipientAddressesChanged(List<String> recipients) {
    final normalized = _normalizeRecipientAddresses(recipients);
    if (listEquals(normalized, _recipientAddresses)) {
      return;
    }
    setState(() {
      _recipientAddresses = normalized;
    });
    _syncQuotedMessagePreview();
  }

  void _syncQuotedMessagePreview() {
    final lookupId = _effectiveQuoteTarget?.stanzaId.trim();
    if (_quotedMessageLookupId == lookupId) {
      return;
    }
    setState(() {
      _quotedMessageLookupId = lookupId;
      _quotedMessage = null;
    });
    if (lookupId == null || lookupId.isEmpty) {
      return;
    }
    unawaited(_loadQuotedMessage(lookupId));
  }

  Future<void> _loadQuotedMessage(String referenceId) async {
    final message = await context.read<DraftCubit>().loadMessageByReferenceId(
      referenceId,
      chatJid: _quoteLookupChatJid,
    );
    if (!mounted || _quotedMessageLookupId != referenceId) {
      return;
    }
    setState(() {
      _quotedMessage = message;
    });
  }

  DraftQuoteTarget? get _effectiveQuoteTarget {
    if (_quoteDismissed) {
      return null;
    }
    final quoteTarget = widget.seed.quoteTarget;
    if (quoteTarget == null) {
      return null;
    }
    final initialRecipients = _normalizeRecipientAddresses(
      widget.seed.jids,
    ).toSet();
    final currentRecipients = _recipientAddresses.toSet();
    if (initialRecipients.length != currentRecipients.length) {
      return null;
    }
    if (!initialRecipients.containsAll(currentRecipients)) {
      return null;
    }
    return quoteTarget;
  }

  String? get _quoteLookupChatJid {
    if (_recipientAddresses.length != 1) {
      return null;
    }
    return _recipientAddresses.single;
  }

  static List<String> _normalizeRecipientAddresses(Iterable<String> values) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }
}

List<ComposerRecipient> _initialRecipients({
  required Iterable<String> jids,
  required List<Chat> chats,
  required bool shareSignatureEnabled,
  required Map<String, MessageTransport> recipientTransportOverrides,
}) {
  final recipients = <ComposerRecipient>[];
  for (final value in jids) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) continue;
    final transportOverride =
        recipientTransportOverrides[contactDirectoryAddressKey(trimmed)];
    Chat? match;
    for (final chat in chats) {
      if (chat.jid == trimmed) {
        match = chat;
        break;
      }
    }
    if (transportOverride != null) {
      recipients.add(
        ComposerRecipient(
          target: Contact.address(
            address: trimmed,
            displayName: match?.displayName,
            shareSignatureEnabled: shareSignatureEnabled,
            transport: transportOverride,
          ),
        ),
      );
      continue;
    }
    if (match != null) {
      recipients.add(
        ComposerRecipient(
          target: Contact.chat(
            chat: match,
            shareSignatureEnabled:
                match.shareSignatureEnabled ?? shareSignatureEnabled,
          ),
        ),
      );
    } else {
      recipients.add(
        ComposerRecipient(
          target: Contact.address(
            address: trimmed,
            shareSignatureEnabled: shareSignatureEnabled,
          ),
        ),
      );
    }
  }
  return recipients;
}

String? _domainFromAddress(String? value) {
  final domain = addressDomainPart(value)?.toLowerCase();
  if (domain == null || domain.isEmpty) {
    return null;
  }
  return domain;
}

class _DraftQuoteBanner extends StatelessWidget {
  const _DraftQuoteBanner({
    required this.quotedMessage,
    required this.selfJid,
    required this.onClear,
  });

  final Message? quotedMessage;
  final String? selfJid;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final senderJid = quotedMessage?.senderJid.trim();
    final normalizedSelfJid = selfJid?.normalizedJidKey;
    final senderLabel = senderJid == null || senderJid.isEmpty
        ? null
        : senderJid.normalizedJidKey == normalizedSelfJid
        ? context.l10n.chatSenderYou
        : (displaySafeAddress(senderJid) ?? senderJid);
    return ComposerQuoteBanner(
      senderLabel: senderLabel,
      previewText: _previewText(context),
      isSelf: senderJid?.normalizedJidKey == normalizedSelfJid,
      onClear: onClear,
    );
  }

  String _previewText(BuildContext context) {
    final message = quotedMessage;
    if (message == null) {
      return context.l10n.chatQuotedNoContent;
    }
    final body = message.body?.trim();
    if (body != null && body.isNotEmpty) {
      return body;
    }
    final subject = message.subject?.trim();
    if (subject != null && subject.isNotEmpty) {
      return subject;
    }
    return context.l10n.chatQuotedNoContent;
  }
}
