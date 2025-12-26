import 'package:axichat/src/app.dart';
import 'package:axichat/src/attachments/bloc/attachment_gallery_cubit.dart';
import 'package:axichat/src/attachments/view/attachment_gallery_view.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
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
  const AttachmentGalleryScreen({super.key, required this.locate});

  final T Function<T>() locate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocProvider(
      create: (context) => AttachmentGalleryCubit(
        xmppService: locate<XmppService>(),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.draftAttachmentsLabel),
          leadingWidth: _attachmentGalleryLeadingWidth,
          leading: Padding(
            padding:
                const EdgeInsets.only(left: _attachmentGalleryLeadingInset),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: AxiIconButton.kDefaultSize,
                height: AxiIconButton.kDefaultSize,
                child: AxiIconButton(
                  iconData: LucideIcons.arrowLeft,
                  tooltip: l10n.commonBack,
                  color: context.colorScheme.foreground,
                  borderColor: context.colorScheme.border,
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
        body: const AttachmentGalleryView(showChatLabel: true),
      ),
    );
  }
}
