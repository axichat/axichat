// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/view/timeline/message/email_html_web_view.dart';
import 'package:axichat/src/chat/view/timeline/message/email_image_extension.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/ui/buttons/axi_button.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart' as html_widget;
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiEmailHtmlPreview extends StatelessWidget {
  const AxiEmailHtmlPreview({
    super.key,
    required this.html,
    required this.shouldLoadSafeRemoteImages,
    required this.originalContentUnblocked,
    required this.onLinkTap,
    this.onRemoteImagesApproved,
    this.onOriginalContentUnblocked,
  });

  final String html;
  final bool shouldLoadSafeRemoteImages;
  final bool originalContentUnblocked;
  final ValueChanged<String> onLinkTap;
  final VoidCallback? onRemoteImagesApproved;
  final Future<void> Function()? onOriginalContentUnblocked;

  @override
  Widget build(BuildContext context) {
    final normalizedHtmlBody = html.trim();
    if (normalizedHtmlBody.isEmpty) {
      return const SizedBox.shrink();
    }
    final hasBlockedRemoteHtmlImages =
        !shouldLoadSafeRemoteImages &&
        HtmlContentCodec.containsRenderableRemoteImages(normalizedHtmlBody);
    final hasBlockedHtmlContent =
        HtmlContentCodec.containsBlockedWebViewContent(normalizedHtmlBody);
    final hasCidHtmlImages = HtmlContentCodec.containsCidImages(
      normalizedHtmlBody,
    );
    final emailHtmlContentMode =
        hasBlockedHtmlContent && originalContentUnblocked
        ? EmailHtmlContentMode.originalPassive
        : EmailHtmlContentMode.safe;
    final isOriginalEmailContent =
        emailHtmlContentMode == EmailHtmlContentMode.originalPassive;
    final allowRemoteImagesInWebView = emailHtmlContentMode.allowsRemoteImages(
      shouldLoadSafeRemoteImages: shouldLoadSafeRemoteImages,
    );
    final preparedHtmlBodyForFallback =
        HtmlContentCodec.prepareEmailHtmlForFlutterHtml(
          normalizedHtmlBody,
          allowRemoteImages: false,
        );
    final Widget? emailHtmlLoadingFallback =
        preparedHtmlBodyForFallback.trim().isEmpty
        ? null
        : _EmailHtmlFallback(
            html: preparedHtmlBodyForFallback,
            shouldLoadImages: false,
            onLinkTap: onLinkTap,
          );
    final spacing = context.spacing;
    return Column(
      spacing: spacing.m,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasBlockedHtmlContent && !isOriginalEmailContent)
          _EmailHtmlSafetyNotice(
            iconData: LucideIcons.shieldAlert,
            label: context.l10n.chatEmailInteractiveContentBlockedLabel,
            onUnblock: onOriginalContentUnblocked,
          ),
        if (hasCidHtmlImages) const _EmailHtmlCidNotice(),
        DecoratedBox(
          decoration: ShapeDecoration(
            color: context.colorScheme.card,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(context.radii.squircle),
              side: context.borderSide,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasBlockedRemoteHtmlImages &&
                  !isOriginalEmailContent &&
                  onRemoteImagesApproved != null)
                Padding(
                  padding: EdgeInsets.all(spacing.s),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: EmailImagePlaceholder(onTap: onRemoteImagesApproved),
                  ),
                ),
              EmailHtmlWebView.embedded(
                html: normalizedHtmlBody,
                allowRemoteImages: allowRemoteImagesInWebView,
                contentMode: emailHtmlContentMode,
                backgroundColor: context.colorScheme.card,
                textColor: context.colorScheme.foreground,
                linkColor: context.colorScheme.primary,
                loadingFallback: isOriginalEmailContent
                    ? null
                    : emailHtmlLoadingFallback,
                simplifyLayout: true,
                minHeight: context.sizing.attachmentPreviewExtent,
                onLinkTap: onLinkTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmailHtmlFallback extends StatelessWidget {
  const _EmailHtmlFallback({
    required this.html,
    required this.shouldLoadImages,
    required this.onLinkTap,
  });

  final String html;
  final bool shouldLoadImages;
  final ValueChanged<String> onLinkTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final fallbackFontSize =
        textTheme.p.fontSize ??
        textTheme.small.fontSize ??
        context.sizing.menuItemIconSize;
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: double.infinity,
        child: html_widget.Html(
          data: html,
          shrinkWrap: false,
          extensions: createEmailHtmlExtensions(
            shouldLoadImages: shouldLoadImages,
          ),
          style: createEmailHtmlStyles(
            fallbackFontSize: fallbackFontSize,
            textColor: context.colorScheme.foreground,
            linkColor: context.colorScheme.primary,
          ),
          onLinkTap: (url, _, _) {
            if (url == null) {
              return;
            }
            onLinkTap(url);
          },
        ),
      ),
    );
  }
}

class _EmailHtmlSafetyNotice extends StatelessWidget {
  const _EmailHtmlSafetyNotice({
    required this.iconData,
    required this.label,
    required this.onUnblock,
  });

  final IconData iconData;
  final String label;
  final Future<void> Function()? onUnblock;

  @override
  Widget build(BuildContext context) {
    return _EmailHtmlSafetyNoticeContent(
      iconData: iconData,
      label: label,
      onUnblock: onUnblock,
    );
  }
}

class _EmailHtmlSafetyNoticeContent extends StatefulWidget {
  const _EmailHtmlSafetyNoticeContent({
    required this.iconData,
    required this.label,
    required this.onUnblock,
  });

  final IconData iconData;
  final String label;
  final Future<void> Function()? onUnblock;

  @override
  State<_EmailHtmlSafetyNoticeContent> createState() =>
      _EmailHtmlSafetyNoticeContentState();
}

class _EmailHtmlSafetyNoticeContentState
    extends State<_EmailHtmlSafetyNoticeContent> {
  var _unblocking = false;

  Future<void> _handleUnblock() async {
    final onUnblock = widget.onUnblock;
    if (_unblocking || onUnblock == null) {
      return;
    }
    setState(() {
      _unblocking = true;
    });
    try {
      await onUnblock();
    } finally {
      if (mounted) {
        setState(() {
          _unblocking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: context.spacing.xs,
      children: [
        _EmailHtmlStatusNotice(iconData: widget.iconData, label: widget.label),
        AxiButton.outline(
          size: AxiButtonSize.sm,
          onPressed: widget.onUnblock == null || _unblocking
              ? null
              : () => unawaited(_handleUnblock()),
          child: Text(context.l10n.chatEmailUnblockInteractiveContentButton),
        ),
      ],
    );
  }
}

class _EmailHtmlCidNotice extends StatelessWidget {
  const _EmailHtmlCidNotice();

  @override
  Widget build(BuildContext context) {
    return _EmailHtmlStatusNotice(
      iconData: LucideIcons.imageOff,
      label: context.l10n.chatEmailInlineImagesUnsupportedLabel,
    );
  }
}

class _EmailHtmlStatusNotice extends StatelessWidget {
  const _EmailHtmlStatusNotice({required this.iconData, required this.label});

  final IconData iconData;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: context.spacing.xs,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          iconData,
          size: context.sizing.menuItemIconSize,
          color: context.colorScheme.mutedForeground,
        ),
        Text(
          label,
          style: context.textTheme.muted,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
