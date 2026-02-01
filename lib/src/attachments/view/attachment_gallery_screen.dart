// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/attachments/bloc/attachment_gallery_bloc.dart';
import 'package:axichat/src/attachments/view/attachment_gallery_view.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AttachmentGalleryScreen extends StatelessWidget {
  const AttachmentGalleryScreen({super.key, required this.locate, this.chat});

  final T Function<T>() locate;
  final Chat? chat;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final leadingWidth = AxiIconButton.kDefaultSize + (spacing.s * 2);
    final endpointConfig = context.read<AuthenticationCubit>().endpointConfig;
    final EmailService? emailService =
        endpointConfig.enableSmtp ? locate<EmailService>() : null;
    return BlocProvider(
      create: (context) => AttachmentGalleryBloc(
        xmppService: locate<XmppService>(),
        emailService: emailService,
        chatJid: chat?.jid,
        chatOverride: chat,
        showChatLabel: chat == null,
      ),
      child: Scaffold(
        backgroundColor: context.colorScheme.background,
        appBar: AppBar(
          title: Text(context.l10n.draftAttachmentsLabel),
          backgroundColor: context.colorScheme.background,
          surfaceTintColor: context.colorScheme.background,
          shape: Border(
            bottom: BorderSide(
              color: context.borderSide.color,
              width: context.borderSide.width,
            ),
          ),
          leadingWidth: leadingWidth,
          leading: Padding(
            padding: EdgeInsets.only(
              left: spacing.s,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AxiIconButton.ghost(
                iconData: LucideIcons.arrowLeft,
                tooltip: context.l10n.commonBack,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ),
        body: ColoredBox(
          color: context.colorScheme.background,
          child: AttachmentGalleryView(
            chatOverride: chat,
            showChatLabel: chat == null,
          ),
        ),
      ),
    );
  }
}
