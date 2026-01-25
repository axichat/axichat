// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

class AxiSheetHeader extends StatelessWidget {
  const AxiSheetHeader({
    required this.title,
    required this.onClose,
    this.subtitle,
    this.leading,
    this.padding,
    super.key,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final VoidCallback onClose;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final EdgeInsetsGeometry resolvedPadding = padding ??
        EdgeInsets.fromLTRB(
          spacing.m,
          spacing.m,
          spacing.m,
          spacing.s,
        );
    final Widget titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DefaultTextStyle.merge(
          style: context.modalHeaderTextStyle,
          child: title,
        ),
        if (subtitle != null) ...[
          SizedBox(height: spacing.xs),
          DefaultTextStyle.merge(
            style: context.textTheme.muted.copyWith(
              color: colors.mutedForeground,
            ),
            child: subtitle!,
          ),
        ],
      ],
    );

    return Padding(
      padding: resolvedPadding,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            SizedBox(width: spacing.s),
          ],
          Expanded(child: titleBlock),
          ModalCloseButton(
            onPressed: () => closeSheetWithKeyboardDismiss(context, onClose),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            backgroundColor: Colors.transparent,
            borderColor: Colors.transparent,
            color: colors.mutedForeground,
          ),
        ],
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
    this.bodyPadding,
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
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    if (fixedBody != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Flexible(fit: FlexFit.loose, child: fixedBody),
          if (footer != null)
            Padding(
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: footer!,
            ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Flexible(
          fit: FlexFit.loose,
          child: _AxiSheetScrollableBody(
            bodyPadding: bodyPadding,
            scrollPhysics: scrollPhysics,
            footer: footer,
            children: scrollChildren ?? const <Widget>[],
          ),
        ),
      ],
    );
  }
}

class _AxiSheetScrollableBody extends StatefulWidget {
  const _AxiSheetScrollableBody({
    required this.children,
    required this.bodyPadding,
    required this.scrollPhysics,
    required this.footer,
  });

  final List<Widget> children;
  final EdgeInsets? bodyPadding;
  final ScrollPhysics? scrollPhysics;
  final Widget? footer;

  @override
  State<_AxiSheetScrollableBody> createState() =>
      _AxiSheetScrollableBodyState();
}

class _AxiSheetScrollableBodyState extends State<_AxiSheetScrollableBody> {
  final ScrollController _scrollController = ScrollController();
  double _scrollExtent = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleExtentSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final double scrollExtent = _scrollController.position.maxScrollExtent;
      if (scrollExtent == _scrollExtent) return;
      setState(() => _scrollExtent = scrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleExtentSync();
    final spacing = context.spacing;
    final EdgeInsets resolvedPadding = widget.bodyPadding ??
        EdgeInsets.fromLTRB(spacing.m, 0, spacing.m, spacing.m);
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final double scrollExtent = _scrollExtent;
    const double scrollExtentThreshold = 0;
    final double footerSpacing = spacing.s;

    if (scrollExtent > scrollExtentThreshold) {
      final double bottomPadding = resolvedPadding.bottom + keyboardInset;
      final EdgeInsets padding = resolvedPadding.copyWith(
        bottom: bottomPadding,
      );
      return Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: ListView(
          controller: _scrollController,
          padding: padding,
          shrinkWrap: true,
          physics: widget.scrollPhysics,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          children: [
            ...widget.children,
            if (widget.footer != null) ...[
              SizedBox(height: footerSpacing),
              widget.footer!,
            ],
          ],
        ),
      );
    }

    final Widget list = Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView(
        controller: _scrollController,
        padding: resolvedPadding,
        shrinkWrap: true,
        physics: widget.scrollPhysics,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
        children: widget.children,
      ),
    );
    final Widget? footer = widget.footer;
    if (footer == null) {
      return list;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        list,
        SizedBox(height: footerSpacing),
        Padding(
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: footer,
        ),
      ],
    );
  }
}
