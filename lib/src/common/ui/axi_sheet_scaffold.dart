import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiSheetHeader extends StatelessWidget {
  const AxiSheetHeader({
    required this.title,
    required this.onClose,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 12),
    super.key,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final VoidCallback onClose;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final Widget titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DefaultTextStyle.merge(
          style: context.modalHeaderTextStyle,
          child: title,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          DefaultTextStyle.merge(
            style: context.textTheme.muted.copyWith(
              color: colors.mutedForeground,
            ),
            child: subtitle!,
          ),
        ],
      ],
    );

    return SafeArea(
      top: true,
      bottom: false,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 10),
            ],
            Expanded(child: titleBlock),
            AxiIconButton(
              iconData: LucideIcons.x,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: onClose,
              iconSize: 16,
              buttonSize: 34,
              tapTargetSize: 40,
              backgroundColor: Colors.transparent,
              borderColor: Colors.transparent,
              color: colors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}

class AxiSheetScaffold extends StatelessWidget {
  const AxiSheetScaffold({
    required this.header,
    required this.body,
    this.footer,
    super.key,
  })  : _scrollChildren = null,
        bodyPadding = null,
        scrollPhysics = null;

  const AxiSheetScaffold.scroll({
    required this.header,
    required List<Widget> children,
    this.footer,
    this.bodyPadding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
    this.scrollPhysics,
    super.key,
  })  : body = null,
        _scrollChildren = children;

  final Widget header;
  final Widget? body;
  final List<Widget>? _scrollChildren;
  final EdgeInsets? bodyPadding;
  final ScrollPhysics? scrollPhysics;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final Widget? fixedBody = body;
    final List<Widget>? scrollChildren = _scrollChildren;
    if (fixedBody != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Flexible(
            fit: FlexFit.loose,
            child: fixedBody,
          ),
          if (footer != null) footer!,
        ],
      );
    }

    final mediaQuery = MediaQuery.of(context);
    final double keyboardInset = mediaQuery.viewInsets.bottom;
    final double safeBottom = mediaQuery.viewPadding.bottom;
    final double bottomInset = math.max(keyboardInset, safeBottom);
    final EdgeInsets padding = (bodyPadding ?? EdgeInsets.zero)
        .copyWith(bottom: (bodyPadding?.bottom ?? 0) + bottomInset);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Flexible(
          fit: FlexFit.loose,
          child: ListView(
            padding: padding,
            shrinkWrap: true,
            physics: scrollPhysics,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            children: [
              ...?scrollChildren,
              if (footer != null) ...[
                const SizedBox(height: 12),
                footer!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}
