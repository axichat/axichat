// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ComposerQuoteBanner extends StatelessWidget {
  const ComposerQuoteBanner({
    super.key,
    required this.previewText,
    required this.onClear,
    this.senderLabel,
    this.isSelf = false,
    this.enabled = true,
  });

  final String previewText;
  final String? senderLabel;
  final bool isSelf;
  final bool enabled;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final textTheme = context.textTheme;
    final baseStyle = textTheme.p;
    final senderStyle = baseStyle.copyWith(
      color: colors.mutedForeground,
      fontWeight: FontWeight.w600,
    );
    final normalizedSenderLabel = senderLabel?.trim();
    final hasSenderLabel =
        normalizedSenderLabel != null && normalizedSenderLabel.isNotEmpty;
    return _ComposerQuoteBannerSurface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: hasSenderLabel
                ? ReplyingToPreviewText(
                    senderLabel: normalizedSenderLabel,
                    quoteText: previewText,
                    isSelf: isSelf,
                    replyPrefix: context.l10n.chatReplyingToComposer,
                    baseStyleOverride: baseStyle,
                    prefixStyleOverride: textTheme.sectionLabelLg,
                    senderStyleOverride: senderStyle,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.chatReplyingToComposer,
                        style: textTheme.sectionLabelLg,
                      ),
                      SizedBox(height: spacing.xxs),
                      Text(
                        previewText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: baseStyle.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
          ),
          SizedBox(width: spacing.s),
          AxiIconButton.ghost(
            iconData: LucideIcons.x,
            tooltip: context.l10n.chatCancelReply,
            semanticLabel: context.l10n.chatCancelReply,
            onPressed: enabled ? onClear : null,
            color: colors.mutedForeground,
            backgroundColor: Colors.transparent,
            iconSize: context.sizing.menuItemIconSize,
            buttonSize: context.sizing.menuItemHeight,
            tapTargetSize: context.sizing.menuItemHeight,
          ),
        ],
      ),
    );
  }
}

class ReplyingToPreviewText extends StatelessWidget {
  const ReplyingToPreviewText({
    super.key,
    required this.senderLabel,
    required this.quoteText,
    required this.isSelf,
    this.replyPrefix,
    this.baseStyleOverride,
    this.prefixStyleOverride,
    this.senderStyleOverride,
  });

  final String senderLabel;
  final String quoteText;
  final bool isSelf;
  final String? replyPrefix;
  final TextStyle? baseStyleOverride;
  final TextStyle? prefixStyleOverride;
  final TextStyle? senderStyleOverride;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final baseStyle = baseStyleOverride ?? context.textTheme.small;
    final mutedStyle = baseStyle.copyWith(color: colors.mutedForeground);
    final prefixStyle = prefixStyleOverride ?? context.textTheme.sectionLabelM;
    final senderStyle =
        senderStyleOverride ?? mutedStyle.copyWith(fontWeight: FontWeight.w600);
    return _ReplyingToPreviewTextRenderWidget(
      senderLabel: senderLabel,
      quoteText: quoteText,
      isSelf: isSelf,
      quoteMaxWidth: null,
      replyPrefix: replyPrefix ?? context.l10n.chatReplyingTo.toUpperCase(),
      baseStyle: baseStyle,
      prefixStyle: prefixStyle,
      senderStyle: senderStyle,
      spacing: context.spacing.xxs,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
    );
  }
}

class _ComposerQuoteBannerSurface extends StatelessWidget {
  const _ComposerQuoteBannerSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    return SizedBox(
      width: double.infinity,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.card,
            border: Border(top: BorderSide(color: colors.border, width: 1)),
          ),
          child: Padding(padding: EdgeInsets.all(spacing.m), child: child),
        ),
      ),
    );
  }
}

class _ReplyingToPreviewTextRenderWidget extends LeafRenderObjectWidget {
  const _ReplyingToPreviewTextRenderWidget({
    required this.senderLabel,
    required this.quoteText,
    required this.isSelf,
    required this.replyPrefix,
    required this.baseStyle,
    required this.prefixStyle,
    required this.senderStyle,
    required this.spacing,
    required this.textDirection,
    required this.textScaler,
    this.quoteMaxWidth,
  });

  final String senderLabel;
  final String quoteText;
  final bool isSelf;
  final String replyPrefix;
  final TextStyle baseStyle;
  final TextStyle prefixStyle;
  final TextStyle senderStyle;
  final double spacing;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final double? quoteMaxWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReplyingToPreviewText(
        senderLabel: senderLabel,
        quoteText: quoteText,
        isSelf: isSelf,
        replyPrefix: replyPrefix,
        baseStyle: baseStyle,
        prefixStyle: prefixStyle,
        senderStyle: senderStyle,
        spacing: spacing,
        textDirection: textDirection,
        textScaler: textScaler,
        quoteMaxWidth: quoteMaxWidth,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderReplyingToPreviewText renderObject,
  ) {
    renderObject
      ..senderLabel = senderLabel
      ..quoteText = quoteText
      ..isSelf = isSelf
      ..replyPrefix = replyPrefix
      ..baseStyle = baseStyle
      ..prefixStyle = prefixStyle
      ..senderStyle = senderStyle
      ..spacing = spacing
      ..textDirection = textDirection
      ..textScaler = textScaler
      ..quoteMaxWidth = quoteMaxWidth;
  }
}

class _RenderReplyingToPreviewText extends RenderBox {
  _RenderReplyingToPreviewText({
    required String senderLabel,
    required String quoteText,
    required bool isSelf,
    required String replyPrefix,
    required TextStyle baseStyle,
    required TextStyle prefixStyle,
    required TextStyle senderStyle,
    required double spacing,
    required TextDirection textDirection,
    required TextScaler textScaler,
    required double? quoteMaxWidth,
  }) : _senderLabel = senderLabel,
       _quoteText = quoteText,
       _isSelf = isSelf,
       _replyPrefix = replyPrefix,
       _baseStyle = baseStyle,
       _prefixStyle = prefixStyle,
       _senderStyle = senderStyle,
       _spacing = spacing,
       _textDirection = textDirection,
       _textScaler = textScaler,
       _quoteMaxWidth = quoteMaxWidth;

  String _senderLabel;
  String _quoteText;
  bool _isSelf;
  String _replyPrefix;
  TextStyle _baseStyle;
  TextStyle _prefixStyle;
  TextStyle _senderStyle;
  double _spacing;
  TextDirection _textDirection;
  TextScaler _textScaler;
  double? _quoteMaxWidth;

  final TextPainter _inlinePainter = TextPainter();
  final TextPainter _headerPainter = TextPainter(maxLines: 1);
  final TextPainter _quotePainter = TextPainter(maxLines: 2);
  bool _canInline = true;

  String get senderLabel => _senderLabel;

  set senderLabel(String value) {
    if (_senderLabel == value) return;
    _senderLabel = value;
    markNeedsLayout();
  }

  String get quoteText => _quoteText;

  set quoteText(String value) {
    if (_quoteText == value) return;
    _quoteText = value;
    markNeedsLayout();
  }

  bool get isSelf => _isSelf;

  set isSelf(bool value) {
    if (_isSelf == value) return;
    _isSelf = value;
    markNeedsLayout();
  }

  String get replyPrefix => _replyPrefix;

  set replyPrefix(String value) {
    if (_replyPrefix == value) return;
    _replyPrefix = value;
    markNeedsLayout();
  }

  TextStyle get baseStyle => _baseStyle;

  set baseStyle(TextStyle value) {
    if (_baseStyle == value) return;
    _baseStyle = value;
    markNeedsLayout();
  }

  TextStyle get prefixStyle => _prefixStyle;

  set prefixStyle(TextStyle value) {
    if (_prefixStyle == value) return;
    _prefixStyle = value;
    markNeedsLayout();
  }

  TextStyle get senderStyle => _senderStyle;

  set senderStyle(TextStyle value) {
    if (_senderStyle == value) return;
    _senderStyle = value;
    markNeedsLayout();
  }

  double get spacing => _spacing;

  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;

  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  TextScaler get textScaler => _textScaler;

  set textScaler(TextScaler value) {
    if (_textScaler == value) return;
    _textScaler = value;
    markNeedsLayout();
  }

  double? get quoteMaxWidth => _quoteMaxWidth;

  set quoteMaxWidth(double? value) {
    if (_quoteMaxWidth == value) return;
    _quoteMaxWidth = value;
    markNeedsLayout();
  }

  TextAlign get _textAlign => isSelf ? TextAlign.end : TextAlign.start;

  TextSpan get _headerSpan => TextSpan(
    children: [
      TextSpan(text: replyPrefix, style: prefixStyle),
      const TextSpan(text: ' '),
      TextSpan(text: senderLabel, style: senderStyle),
    ],
  );

  TextSpan get _inlineSpan => TextSpan(
    children: [
      _headerSpan,
      const TextSpan(text: ' '),
      TextSpan(text: '"$quoteText"', style: baseStyle),
    ],
  );

  @override
  void performLayout() {
    final maxPreviewWidth =
        constraints.maxWidth.isFinite && constraints.maxWidth > 0
        ? constraints.maxWidth
        : double.infinity;
    final maxQuoteWidth =
        quoteMaxWidth != null && quoteMaxWidth!.isFinite && quoteMaxWidth! > 0
        ? math.min(maxPreviewWidth, quoteMaxWidth!)
        : maxPreviewWidth;
    _inlinePainter
      ..text = _inlineSpan
      ..textAlign = _textAlign
      ..textDirection = textDirection
      ..textScaler = textScaler
      ..maxLines = null
      ..ellipsis = null
      ..layout(maxWidth: maxQuoteWidth);
    _canInline = _inlinePainter.computeLineMetrics().length <= 1;
    if (_canInline) {
      size = constraints.constrain(
        Size(_inlinePainter.width, _inlinePainter.height),
      );
      return;
    }
    _headerPainter
      ..text = _headerSpan
      ..textAlign = _textAlign
      ..textDirection = textDirection
      ..textScaler = textScaler
      ..ellipsis = null
      ..layout(maxWidth: maxPreviewWidth);
    final fittedQuoteText = _fitQuotedPreviewText(
      quoteText: quoteText,
      style: baseStyle,
      maxWidth: maxQuoteWidth,
      textDirection: textDirection,
      textScaler: textScaler,
    );
    _quotePainter
      ..text = TextSpan(text: fittedQuoteText, style: baseStyle)
      ..textAlign = _textAlign
      ..textDirection = textDirection
      ..textScaler = textScaler
      ..ellipsis = null
      ..layout(maxWidth: maxQuoteWidth);
    final stackedWidth = math.max(_headerPainter.width, _quotePainter.width);
    final stackedHeight =
        _headerPainter.height + spacing + _quotePainter.height;
    size = constraints.constrain(Size(stackedWidth, stackedHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_canInline) {
      final inlineOffset = Offset(
        isSelf ? size.width - _inlinePainter.width : 0,
        0,
      );
      _inlinePainter.paint(context.canvas, offset + inlineOffset);
      return;
    }
    final headerOffset = Offset(
      isSelf ? size.width - _headerPainter.width : 0,
      0,
    );
    _headerPainter.paint(context.canvas, offset + headerOffset);
    final quoteOffset = Offset(
      isSelf ? size.width - _quotePainter.width : 0,
      _headerPainter.height + spacing,
    );
    _quotePainter.paint(context.canvas, offset + quoteOffset);
  }
}

String _fitQuotedPreviewText({
  required String quoteText,
  required TextStyle style,
  required double maxWidth,
  required TextDirection textDirection,
  required TextScaler textScaler,
}) {
  final quotedPreview = '"$quoteText"';
  if (!maxWidth.isFinite || maxWidth <= 0) {
    return quotedPreview;
  }
  final painter = TextPainter(
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: 2,
  );

  bool fits(String candidate) {
    painter.text = TextSpan(text: candidate, style: style);
    painter.layout(maxWidth: maxWidth);
    return !painter.didExceedMaxLines;
  }

  if (fits(quotedPreview)) {
    return quotedPreview;
  }

  final graphemes = quoteText.characters.toList(growable: false);
  var low = 0;
  var high = graphemes.length;
  var best = '"…"';
  while (low <= high) {
    final mid = (low + high) ~/ 2;
    final candidate = '"${graphemes.take(mid).join()}…"';
    if (fits(candidate)) {
      best = candidate;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return best;
}
