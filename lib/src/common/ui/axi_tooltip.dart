// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:flutter/material.dart';

class AxiTooltip extends StatelessWidget {
  const AxiTooltip({
    super.key,
    required this.builder,
    required this.child,
  });

  final WidgetBuilder builder;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = builder(context);
    final colors = context.colorScheme;
    final radius = context.radius;
    final textStyle = content is Text && content.style != null
        ? content.style!
        : context.textTheme.muted;
    final plainText = _plainText(content);
    final bool hasPlainText = plainText != null;
    return Tooltip(
      richMessage: hasPlainText ? null : _richSpan(content, textStyle),
      message: hasPlainText ? plainText : null,
      preferBelow: true,
      verticalOffset: 12,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.popover,
        borderRadius: radius,
        border: Border.all(color: colors.border),
      ),
      textStyle: textStyle,
      child: child,
    );
  }

  InlineSpan _richSpan(Widget content, TextStyle fallbackStyle) {
    if (content is Text) {
      if (content.textSpan != null) {
        return content.textSpan!;
      }
      return TextSpan(
        text: content.data ?? '',
        style: content.style ?? fallbackStyle,
      );
    }
    if (content is RichText) {
      return content.text;
    }
    return WidgetSpan(child: content);
  }

  String? _plainText(Widget content) {
    if (content is Text) {
      return content.data ?? content.textSpan?.toPlainText();
    }
    if (content is RichText) {
      return content.text.toPlainText();
    }
    return null;
  }
}
