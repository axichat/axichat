// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

enum AxiModalFooterKeyboardPolicy { alwaysVisible, hideWhenKeyboardOpen }

class AxiModalSection {
  const AxiModalSection({required this.child, this.padding})
    : edgeToEdge = false,
      topActions = false;

  const AxiModalSection.edge({required this.child, this.padding})
    : edgeToEdge = true,
      topActions = false;

  const AxiModalSection.topActions({required this.child, this.padding})
    : edgeToEdge = false,
      topActions = true;

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool edgeToEdge;
  final bool topActions;
}

class AxiModalHeader extends StatelessWidget {
  const AxiModalHeader({
    required this.title,
    required this.onClose,
    this.showCloseButton = true,
    this.includeBottomDivider = true,
    this.subtitle,
    this.leading,
    this.actions = const <Widget>[],
    this.padding,
    super.key,
  });

  final Widget title;
  final bool showCloseButton;
  final bool includeBottomDivider;
  final Widget? subtitle;
  final Widget? leading;
  final List<Widget> actions;
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

    final Widget content = Padding(
      padding: resolvedPadding,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            SizedBox(width: context.spacing.s),
          ],
          Expanded(child: titleBlock),
          if (actions.isNotEmpty) ...[
            ..._withGaps(
              gap: context.spacing.s,
              children: actions,
              buildGap: (gap) => SizedBox(width: gap),
            ),
            if (showCloseButton) SizedBox(width: context.spacing.s),
          ],
          if (showCloseButton)
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
    if (!includeBottomDivider) {
      return content;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [content, const AxiModalEdgeDivider()],
    );
  }
}

class AxiDialogHeader extends AxiModalHeader {
  const AxiDialogHeader({
    required super.title,
    required super.onClose,
    super.showCloseButton,
    super.includeBottomDivider,
    super.subtitle,
    super.leading,
    super.actions,
    super.padding,
    super.key,
  });
}

class AxiModalScaffold extends StatelessWidget {
  const AxiModalScaffold({
    required this.header,
    required this.body,
    this.footer,
    this.footerKeyboardPolicy = AxiModalFooterKeyboardPolicy.alwaysVisible,
    this.keyboardInset = 0,
    super.key,
  }) : _scrollChildren = null,
       _sections = null,
       bodyPadding = null,
       scrollPhysics = null,
       sectionDividerBuilder = null;

  const AxiModalScaffold.scroll({
    required this.header,
    required List<Widget> children,
    this.footer,
    this.footerKeyboardPolicy = AxiModalFooterKeyboardPolicy.alwaysVisible,
    this.keyboardInset = 0,
    this.bodyPadding,
    this.scrollPhysics,
    this.sectionDividerBuilder,
    super.key,
  }) : body = null,
       _scrollChildren = children,
       _sections = null;

  const AxiModalScaffold.sections({
    required this.header,
    required List<AxiModalSection> sections,
    this.footer,
    this.footerKeyboardPolicy = AxiModalFooterKeyboardPolicy.alwaysVisible,
    this.keyboardInset = 0,
    this.bodyPadding,
    this.scrollPhysics,
    this.sectionDividerBuilder,
    super.key,
  }) : body = null,
       _scrollChildren = null,
       _sections = sections;

  final Widget header;
  final Widget? body;
  final List<Widget>? _scrollChildren;
  final List<AxiModalSection>? _sections;
  final EdgeInsets? bodyPadding;
  final ScrollPhysics? scrollPhysics;
  final Widget? footer;
  final AxiModalFooterKeyboardPolicy footerKeyboardPolicy;
  final double keyboardInset;
  final WidgetBuilder? sectionDividerBuilder;

  @override
  Widget build(BuildContext context) {
    final Widget? fixedBody = body;
    final List<Widget>? scrollChildren = _scrollChildren;
    final List<AxiModalSection>? sections = _sections;
    final Widget? fixedFooter = footer;
    final bool footerHiddenByKeyboard =
        footerKeyboardPolicy ==
            AxiModalFooterKeyboardPolicy.hideWhenKeyboardOpen &&
        keyboardInset > 0;
    if (fixedBody != null) {
      final Widget insetBody = Padding(
        padding: fixedFooter == null || footerHiddenByKeyboard
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
          if (fixedFooter != null)
            Visibility(
              visible: !footerHiddenByKeyboard,
              maintainState: true,
              child: Padding(
                padding: EdgeInsets.only(bottom: keyboardInset),
                child: fixedFooter,
              ),
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
          child: _AxiModalScrollableBody(
            bodyPadding: bodyPadding,
            scrollPhysics: scrollPhysics,
            footer: footer,
            footerVisible: !footerHiddenByKeyboard,
            keyboardInset: keyboardInset,
            sections: sections,
            sectionDividerBuilder: sectionDividerBuilder,
            children: scrollChildren ?? const <Widget>[],
          ),
        ),
      ],
    );
  }
}

class AxiDialogScaffold extends StatelessWidget {
  const AxiDialogScaffold({
    required this.header,
    required this.body,
    this.footer,
    super.key,
  }) : _scrollChildren = null,
       _sections = null,
       bodyPadding = null,
       scrollPhysics = null;

  const AxiDialogScaffold.scroll({
    required this.header,
    required List<Widget> children,
    this.footer,
    this.bodyPadding,
    this.scrollPhysics,
    super.key,
  }) : body = null,
       _scrollChildren = children,
       _sections = null;

  const AxiDialogScaffold.sections({
    required this.header,
    required List<AxiModalSection> sections,
    this.footer,
    this.bodyPadding,
    this.scrollPhysics,
    super.key,
  }) : body = null,
       _scrollChildren = null,
       _sections = sections;

  final Widget header;
  final Widget? body;
  final List<Widget>? _scrollChildren;
  final List<AxiModalSection>? _sections;
  final EdgeInsets? bodyPadding;
  final ScrollPhysics? scrollPhysics;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final Widget? fixedBody = body;
    if (fixedBody != null) {
      return AxiModalScaffold(header: header, body: fixedBody, footer: footer);
    }
    final sections = _sections;
    if (sections != null) {
      return AxiModalScaffold.sections(
        header: header,
        footer: footer,
        bodyPadding: bodyPadding,
        scrollPhysics: scrollPhysics,
        sections: sections,
      );
    }
    return AxiModalScaffold.scroll(
      header: header,
      footer: footer,
      bodyPadding: bodyPadding,
      scrollPhysics: scrollPhysics,
      children: _scrollChildren ?? const <Widget>[],
    );
  }
}

class _AxiModalScrollableBody extends StatefulWidget {
  const _AxiModalScrollableBody({
    required this.children,
    required this.bodyPadding,
    required this.scrollPhysics,
    required this.footer,
    required this.footerVisible,
    required this.keyboardInset,
    required this.sectionDividerBuilder,
    this.sections,
  });

  final List<Widget> children;
  final List<AxiModalSection>? sections;
  final EdgeInsets? bodyPadding;
  final ScrollPhysics? scrollPhysics;
  final Widget? footer;
  final bool footerVisible;
  final double keyboardInset;
  final WidgetBuilder? sectionDividerBuilder;

  @override
  State<_AxiModalScrollableBody> createState() =>
      _AxiModalScrollableBodyState();
}

class _AxiModalScrollableBodyState extends State<_AxiModalScrollableBody> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool usesSections = widget.sections != null;
    final EdgeInsets resolvedPadding =
        widget.bodyPadding ??
        EdgeInsets.only(
          left: context.spacing.m,
          top: usesSections ? 0 : context.spacing.s,
          right: context.spacing.m,
          bottom: usesSections ? 0 : context.spacing.m,
        );
    final Widget? footer = widget.footer;
    final double listBottomPadding =
        resolvedPadding.bottom +
        (footer == null || !widget.footerVisible ? widget.keyboardInset : 0);
    final EdgeInsets listPadding = EdgeInsets.only(
      top: resolvedPadding.top,
      bottom: listBottomPadding,
    );
    final EdgeInsets horizontalPadding = EdgeInsets.only(
      left: resolvedPadding.left,
      right: resolvedPadding.right,
    );
    final Widget list = ClipRect(
      child: ScrollNotificationObserver(
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: ListView(
            controller: _scrollController,
            padding: listPadding,
            shrinkWrap: true,
            physics: widget.scrollPhysics,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            children: _bodyItems(context, horizontalPadding),
          ),
        ),
      ),
    );
    if (footer == null) {
      return list;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(fit: FlexFit.loose, child: list),
        Visibility(
          visible: widget.footerVisible,
          maintainState: true,
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.keyboardInset),
            child: footer,
          ),
        ),
      ],
    );
  }

  List<Widget> _bodyItems(BuildContext context, EdgeInsets horizontalPadding) {
    final sections = widget.sections;
    if (sections == null) {
      return [
        for (final child in widget.children)
          AxiModalBodyItem(horizontalPadding: horizontalPadding, child: child),
      ];
    }

    final bodyItems = <Widget>[];
    for (final section in sections) {
      if (bodyItems.isNotEmpty) {
        bodyItems.add(
          widget.sectionDividerBuilder?.call(context) ??
              const AxiModalSectionDivider(),
        );
      }
      bodyItems.add(
        AxiModalBodyItem(
          horizontalPadding: section.edgeToEdge
              ? EdgeInsets.zero
              : horizontalPadding,
          child: Padding(
            padding:
                section.padding ?? _defaultSectionPadding(context, section),
            child: section.child,
          ),
        ),
      );
    }
    return bodyItems;
  }

  EdgeInsetsGeometry _defaultSectionPadding(
    BuildContext context,
    AxiModalSection section,
  ) {
    if (section.topActions) {
      return EdgeInsets.symmetric(vertical: context.spacing.s);
    }
    return EdgeInsets.symmetric(vertical: context.spacing.m);
  }
}

class AxiModalBodyItem extends StatelessWidget {
  const AxiModalBodyItem({
    super.key,
    required this.child,
    required this.horizontalPadding,
  });

  final Widget child;
  final EdgeInsets horizontalPadding;

  @override
  Widget build(BuildContext context) {
    if (child is AxiModalSectionDivider || horizontalPadding.horizontal == 0) {
      return child;
    }
    return Padding(padding: horizontalPadding, child: child);
  }
}

class AxiModalSectionDivider extends StatelessWidget {
  const AxiModalSectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const AxiModalEdgeDivider();
  }
}

class AxiModalActions extends StatelessWidget {
  const AxiModalActions({
    required this.children,
    this.padding,
    this.gap,
    this.includeTopDivider = true,
    super.key,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final double? gap;
  final bool includeTopDivider;

  @override
  Widget build(BuildContext context) {
    final EdgeInsetsGeometry resolvedPadding =
        padding ?? EdgeInsets.all(context.spacing.m);
    final Widget content = Padding(
      padding: resolvedPadding,
      child: _AxiModalActionsLayout(
        gap: gap ?? context.spacing.s,
        children: children,
      ),
    );
    if (!includeTopDivider) {
      return content;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [const AxiModalEdgeDivider(), content],
    );
  }
}

class AxiDialogActions extends AxiModalActions {
  const AxiDialogActions({
    required super.children,
    super.padding,
    super.gap,
    super.includeTopDivider,
    super.key,
  });
}

class AxiModalEdgeDivider extends StatelessWidget {
  const AxiModalEdgeDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.borderSide.width,
      child: DecoratedBox(
        decoration: BoxDecoration(color: context.borderSide.color),
      ),
    );
  }
}

class _AxiModalActionsLayout extends StatelessWidget {
  const _AxiModalActionsLayout({required this.children, required this.gap});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final bool usesFlex = children.any(
      (widget) => widget is Expanded || widget is Flexible || widget is Spacer,
    );
    if (usesFlex) {
      return Row(
        mainAxisSize: MainAxisSize.max,
        children: _withGaps(
          gap: gap,
          children: children,
          buildGap: (gap) => SizedBox(width: gap),
        ),
      );
    }
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: gap,
      runSpacing: context.spacing.s,
      children: children,
    );
  }
}

List<Widget> _withGaps({
  required List<Widget> children,
  required double gap,
  required Widget Function(double gap) buildGap,
}) {
  if (children.length <= 1) {
    return children;
  }
  final spaced = <Widget>[];
  for (final Widget child in children) {
    if (spaced.isNotEmpty) {
      spaced.add(buildGap(gap));
    }
    spaced.add(child);
  }
  return spaced;
}
