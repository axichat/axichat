// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/compose_window_cubit.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/view/draft_form.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ComposeDraftContent extends StatelessWidget {
  const ComposeDraftContent({
    super.key,
    required this.seed,
    required this.locate,
    this.recipientCountAdjustment = 0,
    this.subjectTrailing,
    this.onClosed,
    this.onDiscarded,
    this.onDraftSaved,
  });

  final ComposeDraftSeed seed;
  final T Function<T>() locate;
  final int recipientCountAdjustment;
  final Widget? subjectTrailing;
  final VoidCallback? onClosed;
  final VoidCallback? onDiscarded;
  final ValueChanged<int>? onDraftSaved;

  @override
  Widget build(BuildContext context) {
    return _ComposeDraftFormContent(
      seed: seed,
      locate: locate,
      recipientCountAdjustment: recipientCountAdjustment,
      subjectTrailing: subjectTrailing,
      onClosed: onClosed,
      onDiscarded: onDiscarded,
      onDraftSaved: onDraftSaved,
      showQuoteBanner: true,
    );
  }
}

class EmbeddedComposeDraftContent extends StatelessWidget {
  const EmbeddedComposeDraftContent({
    super.key,
    required this.seed,
    required this.locate,
    this.recipientCountAdjustment = 0,
    this.subjectTrailing,
    this.onClosed,
    this.onDiscarded,
    this.onDraftSaved,
  });

  final ComposeDraftSeed seed;
  final T Function<T>() locate;
  final int recipientCountAdjustment;
  final Widget? subjectTrailing;
  final VoidCallback? onClosed;
  final VoidCallback? onDiscarded;
  final ValueChanged<int>? onDraftSaved;

  @override
  Widget build(BuildContext context) {
    return _ComposeDraftFormContent(
      seed: seed,
      locate: locate,
      recipientCountAdjustment: recipientCountAdjustment,
      subjectTrailing: subjectTrailing,
      onClosed: onClosed,
      onDiscarded: onDiscarded,
      onDraftSaved: onDraftSaved,
      showQuoteBanner: false,
    );
  }
}

class _ComposeDraftFormContent extends StatefulWidget {
  const _ComposeDraftFormContent({
    required this.seed,
    required this.locate,
    required this.showQuoteBanner,
    this.recipientCountAdjustment = 0,
    this.subjectTrailing,
    this.onClosed,
    this.onDiscarded,
    this.onDraftSaved,
  });

  final ComposeDraftSeed seed;
  final T Function<T>() locate;
  final bool showQuoteBanner;
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
        listEquals(oldWidget.seed.jids, widget.seed.jids)) {
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
    final xmppService = widget.locate<XmppService>();
    return BlocBuilder<SettingsCubit, SettingsState>(
      bloc: widget.locate<SettingsCubit>(),
      builder: (context, settingsState) {
        final endpointConfig = settingsState.endpointConfig;
        final emailService = endpointConfig.smtpEnabled
            ? widget.locate<EmailService>()
            : null;
        final emailAddress = emailService?.activeAccount?.address;
        final myJid = xmppService.myJid;
        final suggestionAddresses = <String>{
          if (myJid?.isNotEmpty == true) myJid!,
          if (emailAddress?.isNotEmpty == true) emailAddress!,
        };
        final suggestionDomains = <String>{
          EndpointConfig.defaultDomain,
          ...suggestionAddresses.map(_domainFromAddress).whereType<String>(),
        };
        return DraftForm(
          id: widget.seed.id,
          jids: widget.seed.jids,
          body: widget.seed.body,
          subject: widget.seed.subject,
          quoteTarget: _effectiveQuoteTarget,
          attachmentMetadataIds: widget.seed.attachmentMetadataIds,
          suggestionAddresses: suggestionAddresses,
          suggestionDomains: suggestionDomains,
          locate: widget.locate,
          recipientCountAdjustment: widget.recipientCountAdjustment,
          subjectTrailing: widget.subjectTrailing,
          banner: _buildQuoteBanner(selfJid: myJid),
          onRecipientAddressesChanged: _handleRecipientAddressesChanged,
          onClosed: widget.onClosed,
          onDiscarded: widget.onDiscarded,
          onDraftSaved: widget.onDraftSaved,
        );
      },
    );
  }

  Widget? _buildQuoteBanner({required String? selfJid}) {
    if (!widget.showQuoteBanner) {
      return null;
    }
    final quoteTarget = _effectiveQuoteTarget;
    if (quoteTarget == null) {
      return null;
    }
    final senderJid = _quotedMessage?.senderJid.trim();
    final normalizedSelfJid = selfJid?.normalizedJidKey;
    final senderLabel = senderJid == null || senderJid.isEmpty
        ? null
        : senderJid.normalizedJidKey == normalizedSelfJid
        ? context.l10n.chatSenderYou
        : (displaySafeAddress(senderJid) ?? senderJid);
    final previewText = switch (_quotedMessage) {
      final message? => () {
        final body = message.body?.trim();
        if (body != null && body.isNotEmpty) {
          return body;
        }
        final subject = message.subject?.trim();
        if (subject != null && subject.isNotEmpty) {
          return subject;
        }
        return context.l10n.chatQuotedNoContent;
      }(),
      _ => context.l10n.chatQuotedNoContent,
    };
    return ComposerQuoteBanner(
      senderLabel: senderLabel,
      previewText: previewText,
      isSelf: senderJid?.normalizedJidKey == normalizedSelfJid,
      onClear: () {
        setState(() {
          _quoteDismissed = true;
          _quotedMessageLookupId = null;
          _quotedMessage = null;
        });
      },
    );
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
    final message = await widget.locate<DraftCubit>().loadMessageByReferenceId(
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

String? _domainFromAddress(String? value) {
  final domain = addressDomainPart(value)?.toLowerCase();
  if (domain == null || domain.isEmpty) {
    return null;
  }
  return domain;
}
