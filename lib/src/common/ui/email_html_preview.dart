// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/view/timeline/message/email_html_web_view.dart';
import 'package:axichat/src/chat/view/timeline/message/email_image_extension.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart' as html_widget;
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiEmailHtmlPreview extends StatefulWidget {
  const AxiEmailHtmlPreview({
    super.key,
    required this.html,
    required this.shouldLoadSafeRemoteImages,
    required this.originalContentUnblocked,
    required this.baseFontSize,
    required this.onLinkTap,
    this.onRemoteImagesApproved,
    this.onOriginalContentUnblocked,
  });

  final String html;
  final bool shouldLoadSafeRemoteImages;
  final bool originalContentUnblocked;
  final double baseFontSize;
  final ValueChanged<String> onLinkTap;
  final VoidCallback? onRemoteImagesApproved;
  final Future<void> Function()? onOriginalContentUnblocked;

  @override
  State<AxiEmailHtmlPreview> createState() => _AxiEmailHtmlPreviewState();
}

class _AxiEmailHtmlPreviewState extends State<AxiEmailHtmlPreview> {
  late String _normalizedHtmlBody;
  late bool _hasRenderableRemoteImages;
  late bool _hasBlockedHtmlContent;
  late bool _hasCidHtmlImages;
  late String _preparedHtmlBodyForFallback;
  int _derivationRequestId = 0;

  @override
  void initState() {
    super.initState();
    _deriveFromHtml();
  }

  @override
  void didUpdateWidget(covariant AxiEmailHtmlPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _deriveFromHtml();
    }
  }

  void _deriveFromHtml() {
    _derivationRequestId += 1;
    final requestId = _derivationRequestId;
    _normalizedHtmlBody = widget.html.trim();
    if (_normalizedHtmlBody.isEmpty) {
      _hasRenderableRemoteImages = false;
      _hasBlockedHtmlContent = false;
      _hasCidHtmlImages = false;
      _preparedHtmlBodyForFallback = '';
      return;
    }
    final cachedDerivation = HtmlContentCodec.cachedEmailDerivations(
      _normalizedHtmlBody,
    );
    if (cachedDerivation != null) {
      _applyDerivation(cachedDerivation);
      return;
    }
    _hasRenderableRemoteImages =
        HtmlContentCodec.containsRenderableRemoteImages(_normalizedHtmlBody);
    _hasBlockedHtmlContent = HtmlContentCodec.containsBlockedWebViewContent(
      _normalizedHtmlBody,
    );
    _hasCidHtmlImages = HtmlContentCodec.containsCidImages(_normalizedHtmlBody);
    _preparedHtmlBodyForFallback = '';
    unawaited(_deriveFromHtmlAsync(requestId, _normalizedHtmlBody));
  }

  void _applyDerivation(EmailHtmlDerivation derivation) {
    _hasRenderableRemoteImages = derivation.containsRemoteImages;
    _hasBlockedHtmlContent = derivation.containsBlockedWebViewContent;
    _hasCidHtmlImages = derivation.containsCidImages;
    _preparedHtmlBodyForFallback = derivation.preparedFlutterHtml;
  }

  Future<void> _deriveFromHtmlAsync(
    int requestId,
    String normalizedHtmlBody,
  ) async {
    try {
      await HtmlContentCodec.precacheEmailDerivations([normalizedHtmlBody]);
    } on Exception {
      return;
    }
    if (!mounted ||
        requestId != _derivationRequestId ||
        normalizedHtmlBody != _normalizedHtmlBody) {
      return;
    }
    final cachedDerivation = HtmlContentCodec.cachedEmailDerivations(
      normalizedHtmlBody,
    );
    if (cachedDerivation == null) {
      return;
    }
    setState(() => _applyDerivation(cachedDerivation));
  }

  @override
  Widget build(BuildContext context) {
    final normalizedHtmlBody = _normalizedHtmlBody;
    if (normalizedHtmlBody.isEmpty) {
      return const SizedBox.shrink();
    }
    final shouldLoadSafeRemoteImages = widget.shouldLoadSafeRemoteImages;
    final onLinkTap = widget.onLinkTap;
    final onRemoteImagesApproved = widget.onRemoteImagesApproved;
    final onOriginalContentUnblocked = widget.onOriginalContentUnblocked;
    final hasBlockedRemoteHtmlImages =
        !shouldLoadSafeRemoteImages && _hasRenderableRemoteImages;
    final hasBlockedHtmlContent = _hasBlockedHtmlContent;
    final hasCidHtmlImages = _hasCidHtmlImages;
    final emailHtmlContentMode =
        hasBlockedHtmlContent && widget.originalContentUnblocked
        ? EmailHtmlContentMode.originalPassive
        : EmailHtmlContentMode.safe;
    final isOriginalEmailContent =
        emailHtmlContentMode == EmailHtmlContentMode.originalPassive;
    final allowRemoteImagesInWebView = emailHtmlContentMode.allowsRemoteImages(
      shouldLoadSafeRemoteImages: shouldLoadSafeRemoteImages,
    );
    final preparedHtmlBodyForFallback = _preparedHtmlBodyForFallback;
    final Widget? emailHtmlLoadingFallback =
        preparedHtmlBodyForFallback.trim().isEmpty
        ? null
        : _EmailHtmlFallback(
            html: preparedHtmlBodyForFallback,
            shouldLoadImages: false,
            baseFontSize: widget.baseFontSize,
            onLinkTap: onLinkTap,
          );
    final spacing = context.spacing;
    final originalContentAction = hasBlockedHtmlContent
        ? isOriginalEmailContent
              ? EmailOriginalContentAction.active
              : onOriginalContentUnblocked != null
              ? EmailOriginalContentAction.available
              : EmailOriginalContentAction.hidden
        : EmailOriginalContentAction.hidden;
    final showEmailActionRow =
        originalContentAction.isVisible ||
        (hasBlockedRemoteHtmlImages && onRemoteImagesApproved != null);
    return Column(
      spacing: spacing.m,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showEmailActionRow)
          EmailActionButtonRow(
            onLoadImages: hasBlockedRemoteHtmlImages
                ? onRemoteImagesApproved
                : null,
            originalContentAction: originalContentAction,
            onViewOriginal: hasBlockedHtmlContent && !isOriginalEmailContent
                ? onOriginalContentUnblocked
                : null,
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
              EmailHtmlWebView.embedded(
                html: normalizedHtmlBody,
                allowRemoteImages: allowRemoteImagesInWebView,
                contentMode: emailHtmlContentMode,
                backgroundColor: context.colorScheme.card,
                textColor: context.colorScheme.foreground,
                linkColor: context.colorScheme.primary,
                baseFontSize: widget.baseFontSize,
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
    required this.baseFontSize,
    required this.onLinkTap,
  });

  final String html;
  final bool shouldLoadImages;
  final double baseFontSize;
  final ValueChanged<String> onLinkTap;

  @override
  Widget build(BuildContext context) {
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
            fallbackFontSize: baseFontSize,
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
