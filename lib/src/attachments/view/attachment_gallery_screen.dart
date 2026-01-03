// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/attachments/bloc/attachment_gallery_cubit.dart';
import 'package:axichat/src/attachments/view/attachment_gallery_view.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _attachmentGalleryLeadingInset = 12.0;
const double _attachmentGalleryDividerThickness = 1.0;
const double _attachmentGalleryDividerHeight = 1.0;
const double _attachmentGalleryPreferredSizeHeight = 1.0;
const double _attachmentGalleryLeadingWidth =
    AxiIconButton.kDefaultSize + (_attachmentGalleryLeadingInset * 2);

class AttachmentGalleryScreen extends StatelessWidget {
  const AttachmentGalleryScreen({
    super.key,
    required this.locate,
    this.chat,
  });

  final T Function<T>() locate;
  final Chat? chat;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Chat? resolvedChat = chat;
    final String? chatJid = resolvedChat?.jid;
    final bool showChatLabel = resolvedChat == null;
    final XmppService xmppService = locate<XmppService>();
    return BlocProvider(
      create: (context) => AttachmentGalleryCubit(
        xmppService: xmppService,
        chatJid: chatJid,
      ),
      child: Scaffold(
        backgroundColor: context.colorScheme.background,
        appBar: AppBar(
          title: Text(l10n.draftAttachmentsLabel),
          backgroundColor: context.colorScheme.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leadingWidth: _attachmentGalleryLeadingWidth,
          leading: Padding(
            padding:
                const EdgeInsets.only(left: _attachmentGalleryLeadingInset),
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
            preferredSize:
                const Size.fromHeight(_attachmentGalleryPreferredSizeHeight),
            child: Divider(
              height: _attachmentGalleryDividerHeight,
              thickness: _attachmentGalleryDividerThickness,
              color: context.colorScheme.border,
            ),
          ),
        ),
        body: ColoredBox(
          color: context.colorScheme.background,
          child: AttachmentGalleryView(
            chatOverride: resolvedChat,
            showChatLabel: showChatLabel,
          ),
        ),
      ),
    );
  }
}
