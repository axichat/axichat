import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/draft/bloc/compose_window_cubit.dart';
import 'package:axichat/src/draft/view/draft_form.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ComposeDraftContent extends StatelessWidget {
  const ComposeDraftContent({
    super.key,
    required this.seed,
    this.onClosed,
    this.onDiscarded,
  });

  final ComposeDraftSeed seed;
  final VoidCallback? onClosed;
  final VoidCallback? onDiscarded;

  @override
  Widget build(BuildContext context) {
    final myJid = context.watch<XmppService>().myJid;
    final emailAddress = context.watch<EmailService?>()?.activeAccount?.address;
    final suggestionAddresses = <String>{
      if (myJid?.isNotEmpty == true) myJid!,
      if (emailAddress?.isNotEmpty == true) emailAddress!,
    };
    final suggestionDomains = <String>{
      EndpointConfig.defaultDomain,
      ...suggestionAddresses.map(_domainFromAddress).whereType<String>(),
    };
    return DraftForm(
      id: seed.id,
      jids: seed.jids,
      body: seed.body,
      subject: seed.subject,
      attachmentMetadataIds: seed.attachmentMetadataIds,
      suggestionAddresses: suggestionAddresses,
      suggestionDomains: suggestionDomains,
      onClosed: onClosed,
      onDiscarded: onDiscarded,
    );
  }
}

String? _domainFromAddress(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty || !trimmed.contains('@')) {
    return null;
  }
  final parts = trimmed.split('@');
  if (parts.length != 2) return null;
  final domain = parts.last.trim().toLowerCase();
  return domain.isEmpty ? null : domain;
}
