// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<MessageTransport?> showTransportChoiceDialog(
  BuildContext context, {
  required String address,
  MessageTransport? defaultTransport,
}) {
  final l10n = context.l10n;
  final title = l10n.chatTransportChoiceTitle;
  final message = l10n.chatTransportChoiceMessage(address);
  final cancelLabel = l10n.chatAttachmentExportCancel;
  final emailLabel = MessageTransport.email.label;
  return showFadeScaleDialog<MessageTransport>(
    context: context,
    builder: (dialogContext) {
      final configuredDomain = dialogContext.select<SettingsCubit, String>(
        (cubit) => cubit.state.endpointConfig.domain.trim().toLowerCase(),
      );
      final addressDomain =
          addressDomainPart(address)?.trim().toLowerCase() ??
          EndpointConfig.defaultDomain;
      final sameDomain =
          addressDomain == configuredDomain ||
          addressDomain == EndpointConfig.defaultDomain;
      final chatLabel = sameDomain
          ? dialogContext.l10n.chatTransportChoiceAxichatLabel
          : MessageTransport.xmpp.label;
      final pop = Navigator.of(dialogContext).pop;
      final emailPrimary = defaultTransport == MessageTransport.email;
      final chatPrimary = defaultTransport == MessageTransport.xmpp;
      final emailButton = emailPrimary
          ? AxiButton.primary(
              onPressed: () => pop(MessageTransport.email),
              child: Text(emailLabel),
            )
          : AxiButton.secondary(
              onPressed: () => pop(MessageTransport.email),
              child: Text(emailLabel),
            );
      final chatButton = chatPrimary
          ? AxiButton.primary(
              onPressed: () => pop(MessageTransport.xmpp),
              child: Text(chatLabel),
            )
          : AxiButton.secondary(
              onPressed: () => pop(MessageTransport.xmpp),
              child: Text(chatLabel),
            );
      return AxiDialog(
        constraints: BoxConstraints(
          maxWidth: dialogContext.sizing.dialogMaxWidth,
        ),
        title: Text(title, style: dialogContext.modalHeaderTextStyle),
        actions: [
          AxiButton.outline(
            onPressed: () => pop(null),
            child: Text(cancelLabel),
          ),
          chatButton,
          emailButton,
        ],
        child: Text(
          message,
          style: dialogContext.textTheme.small,
          textAlign: TextAlign.start,
        ),
      );
    },
  );
}
