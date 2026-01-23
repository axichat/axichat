// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/attachments/bloc/attachment_gallery_bloc.dart';
import 'package:axichat/src/attachments/view/attachment_gallery_view.dart';
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
    const leadingInset = 12.0;
    const dividerThickness = 1.0;
    const dividerHeight = 1.0;
    const preferredSizeHeight = 1.0;
    const leadingWidth = AxiIconButton.kDefaultSize + (leadingInset * 2);
    final l10n = context.l10n;
    final Chat? resolvedChat = chat;
    final String? chatJid = resolvedChat?.jid;
    final XmppService xmppService = locate<XmppService>();
    final emailService = RepositoryProvider.of<EmailService?>(context);
    return BlocProvider(
      create: (context) => AttachmentGalleryBloc(
        xmppService: xmppService,
        emailService: emailService,
        chatJid: chatJid,
        chatOverride: resolvedChat,
        showChatLabel: resolvedChat == null,
      ),
      child: Scaffold(
        backgroundColor: context.colorScheme.background,
        appBar: AppBar(
          title: Text(l10n.draftAttachmentsLabel),
          backgroundColor: context.colorScheme.background,
          surfaceTintColor: context.colorScheme.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          leadingWidth: leadingWidth,
          leading: Padding(
            padding: const EdgeInsets.only(
              left: leadingInset,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: AxiIconButton.kDefaultSize,
                height: AxiIconButton.kDefaultSize,
                child: AxiIconButton.ghost(
                  iconData: LucideIcons.arrowLeft,
                  tooltip: l10n.commonBack,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(
              preferredSizeHeight,
            ),
            child: Divider(
              height: dividerHeight,
              thickness: dividerThickness,
              color: context.colorScheme.border,
            ),
          ),
        ),
        body: ColoredBox(
          color: context.colorScheme.background,
          child: AttachmentGalleryView(
            chatOverride: resolvedChat,
            showChatLabel: resolvedChat == null,
          ),
        ),
      ),
    );
  }
}
