// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/draft/bloc/compose_window_cubit.dart';
import 'package:axichat/src/draft/view/draft_form.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ComposeDraftContent extends StatelessWidget {
  const ComposeDraftContent({
    super.key,
    required this.seed,
    this.onClosed,
    this.onDiscarded,
    this.onDraftSaved,
  });

  final ComposeDraftSeed seed;
  final VoidCallback? onClosed;
  final VoidCallback? onDiscarded;
  final ValueChanged<int>? onDraftSaved;

  @override
  Widget build(BuildContext context) {
    final myJid = context.watch<XmppService>().myJid;
    final endpointConfig = context.watch<SettingsCubit>().state.endpointConfig;
    final emailAddress = endpointConfig.enableSmtp
        ? context.watch<EmailService>().activeAccount?.address
        : null;
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
      onDraftSaved: onDraftSaved,
    );
  }
}

String? _domainFromAddress(String? value) {
  final domain = addressDomainPart(value)?.toLowerCase();
  if (domain == null || domain.isEmpty) {
    return null;
  }
  return domain;
}
