// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/axi_modal_scaffold.dart';
import 'package:flutter/material.dart';

double _sheetKeyboardInset(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route is! ModalBottomSheetRoute) {
    return 0;
  }
  return MediaQuery.viewInsetsOf(context).bottom;
}

enum AxiSheetFooterKeyboardPolicy { alwaysVisible, hideWhenKeyboardOpen }

class AxiSheetSection extends AxiModalSection {
  const AxiSheetSection({required super.child, super.padding}) : super();

  const AxiSheetSection.edge({required super.child, super.padding})
    : super.edge();

  const AxiSheetSection.topActions({required super.child, super.padding})
    : super.topActions();
}

class AxiSheetHeader extends AxiModalHeader {
  const AxiSheetHeader({
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

class AxiSheetScaffold extends StatelessWidget {
  const AxiSheetScaffold({
    required this.header,
    required this.body,
    this.footer,
    this.footerKeyboardPolicy = AxiSheetFooterKeyboardPolicy.alwaysVisible,
    super.key,
  }) : _scrollChildren = null,
       _sections = null,
       bodyPadding = null,
       scrollPhysics = null;

  const AxiSheetScaffold.scroll({
    required this.header,
    required List<Widget> children,
    this.footer,
    this.footerKeyboardPolicy = AxiSheetFooterKeyboardPolicy.alwaysVisible,
    this.bodyPadding,
    this.scrollPhysics,
    super.key,
  }) : body = null,
       _scrollChildren = children,
       _sections = null;

  const AxiSheetScaffold.sections({
    required this.header,
    required List<AxiSheetSection> sections,
    this.footer,
    this.footerKeyboardPolicy = AxiSheetFooterKeyboardPolicy.alwaysVisible,
    this.bodyPadding,
    this.scrollPhysics,
    super.key,
  }) : body = null,
       _scrollChildren = null,
       _sections = sections;

  final Widget header;
  final Widget? body;
  final List<Widget>? _scrollChildren;
  final List<AxiSheetSection>? _sections;
  final EdgeInsets? bodyPadding;
  final ScrollPhysics? scrollPhysics;
  final Widget? footer;
  final AxiSheetFooterKeyboardPolicy footerKeyboardPolicy;

  @override
  Widget build(BuildContext context) {
    final policy =
        footerKeyboardPolicy ==
            AxiSheetFooterKeyboardPolicy.hideWhenKeyboardOpen
        ? AxiModalFooterKeyboardPolicy.hideWhenKeyboardOpen
        : AxiModalFooterKeyboardPolicy.alwaysVisible;
    final sections = _sections;
    final fixedBody = body;
    if (fixedBody != null) {
      return AxiModalScaffold(
        header: header,
        body: fixedBody,
        footer: footer,
        footerKeyboardPolicy: policy,
        keyboardInset: _sheetKeyboardInset(context),
      );
    }
    if (sections != null) {
      return AxiModalScaffold.sections(
        header: header,
        footer: footer,
        footerKeyboardPolicy: policy,
        keyboardInset: _sheetKeyboardInset(context),
        bodyPadding: bodyPadding,
        scrollPhysics: scrollPhysics,
        sectionDividerBuilder: (_) => const AxiSheetSectionDivider(),
        sections: sections,
      );
    }
    return AxiModalScaffold.scroll(
      header: header,
      footer: footer,
      footerKeyboardPolicy: policy,
      keyboardInset: _sheetKeyboardInset(context),
      bodyPadding: bodyPadding,
      scrollPhysics: scrollPhysics,
      children: _scrollChildren ?? const <Widget>[],
    );
  }
}

class AxiSheetBodyItem extends AxiModalBodyItem {
  const AxiSheetBodyItem({
    super.key,
    required super.child,
    required super.horizontalPadding,
  });
}

class AxiSheetSectionDivider extends AxiModalSectionDivider {
  const AxiSheetSectionDivider({super.key});
}

class AxiSheetActions extends AxiModalActions {
  const AxiSheetActions({
    required super.children,
    super.padding,
    super.gap,
    super.includeTopDivider,
    super.key,
  });
}
