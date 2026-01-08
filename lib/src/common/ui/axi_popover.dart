// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:ui';

import 'package:axichat/src/common/ui/fade_scale_effect.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiPopover extends StatelessWidget {
  const AxiPopover({
    super.key,
    required this.child,
    required this.popover,
    this.controller,
    this.visible,
    this.closeOnTapOutside = true,
    this.focusNode,
    this.anchor,
    this.shadows,
    this.padding,
    this.decoration,
    this.filter,
    this.groupId,
    this.areaGroupId,
    this.useSameGroupIdForChild = true,
  });

  final WidgetBuilder popover;
  final Widget child;
  final ShadPopoverController? controller;
  final bool? visible;
  final bool closeOnTapOutside;
  final FocusNode? focusNode;
  final ShadAnchorBase? anchor;
  final List<BoxShadow>? shadows;
  final EdgeInsetsGeometry? padding;
  final ShadDecoration? decoration;
  final ImageFilter? filter;
  final Object? groupId;
  final Object? areaGroupId;
  final bool useSameGroupIdForChild;

  @override
  Widget build(BuildContext context) {
    final effects = fadeScaleEffectsFor(context);
    return ShadPopover(
      popover: popover,
      controller: controller,
      visible: visible,
      closeOnTapOutside: closeOnTapOutside,
      focusNode: focusNode,
      anchor: anchor,
      effects: effects,
      shadows: shadows,
      padding: padding,
      decoration: decoration,
      filter: filter,
      groupId: groupId,
      areaGroupId: areaGroupId,
      useSameGroupIdForChild: useSameGroupIdForChild,
      child: child,
    );
  }
}
