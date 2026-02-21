// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/keyboard_pop_scope.dart';
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
    final EdgeInsetsGeometry resolvedPadding =
        padding ??
        EdgeInsets.fromLTRB(
          context.spacing.m,
          context.spacing.m,
          context.spacing.m,
          context.spacing.s,
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
          SizedBox(height: context.spacing.xs),
          DefaultTextStyle.merge(
            style: context.textTheme.muted.copyWith(
              color: context.colorScheme.mutedForeground,
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
            SizedBox(width: context.spacing.s),
          ],
          Expanded(child: titleBlock),
          ModalCloseButton(
            onPressed: () => closeSheetWithKeyboardDismiss(context, onClose),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            backgroundColor: Colors.transparent,
            borderColor: Colors.transparent,
            color: context.colorScheme.mutedForeground,
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
  }) : _scrollChildren = null,
       bodyPadding = null,
       scrollPhysics = null;

  const AxiSheetScaffold.scroll({
    required this.header,
    required List<Widget> children,
    this.footer,
    this.bodyPadding,
    this.scrollPhysics,
    super.key,
  }) : body = null,
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
      final Widget insetBody = Padding(
        padding: footer == null
            ? EdgeInsets.only(bottom: keyboardInset)
            : EdgeInsets.zero,
        child: fixedBody,
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Flexible(fit: FlexFit.loose, child: insetBody),
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
    final EdgeInsets resolvedPadding =
        widget.bodyPadding ??
        EdgeInsets.only(
          left: context.spacing.m,
          right: context.spacing.m,
          bottom: context.spacing.m,
        );
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final double scrollExtent = _scrollExtent;
    const double scrollExtentThreshold = 0;
    final double footerSpacing = context.spacing.s;
    final Widget? footer = widget.footer;

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

    final double listBottomPadding = footer == null
        ? resolvedPadding.bottom + keyboardInset
        : resolvedPadding.bottom;
    final EdgeInsets listPadding = resolvedPadding.copyWith(
      bottom: listBottomPadding,
    );
    final Widget list = Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView(
        controller: _scrollController,
        padding: listPadding,
        shrinkWrap: true,
        physics: widget.scrollPhysics,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
        children: widget.children,
      ),
    );
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
