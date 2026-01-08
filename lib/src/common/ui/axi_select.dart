// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:ui';

import 'package:axichat/src/common/ui/fade_scale_effect.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiSelect<T> extends StatelessWidget {
  const AxiSelect({
    super.key,
    required this.selectedOptionBuilder,
    this.options,
    this.optionsBuilder,
    this.popoverController,
    this.enabled = true,
    this.placeholder,
    this.initialValue,
    this.onChanged,
    this.focusNode,
    this.closeOnTapOutside = true,
    this.minWidth,
    this.maxWidth,
    this.maxHeight,
    this.decoration,
    this.trailing,
    this.padding,
    this.optionsPadding,
    this.showScrollToBottomChevron,
    this.showScrollToTopChevron,
    this.scrollController,
    this.anchor,
    this.shadows,
    this.filter,
    this.header,
    this.footer,
    this.closeOnSelect = true,
    this.allowDeselection = false,
    this.groupId,
    this.itemCount,
    this.shrinkWrap,
    this.controller,
  });

  final ShadSelectedOptionBuilder<T> selectedOptionBuilder;
  final Iterable<ShadOption<T>>? options;
  final Widget? Function(BuildContext, int)? optionsBuilder;
  final ShadPopoverController? popoverController;
  final bool enabled;
  final Widget? placeholder;
  final T? initialValue;
  final ValueChanged<T?>? onChanged;
  final FocusNode? focusNode;
  final bool closeOnTapOutside;
  final double? minWidth;
  final double? maxWidth;
  final double? maxHeight;
  final ShadDecoration? decoration;
  final Widget? trailing;
  final EdgeInsets? padding;
  final EdgeInsets? optionsPadding;
  final bool? showScrollToBottomChevron;
  final bool? showScrollToTopChevron;
  final ScrollController? scrollController;
  final ShadAnchorBase? anchor;
  final List<BoxShadow>? shadows;
  final ImageFilter? filter;
  final Widget? header;
  final Widget? footer;
  final bool closeOnSelect;
  final bool allowDeselection;
  final Object? groupId;
  final int? itemCount;
  final bool? shrinkWrap;
  final ShadSelectController<T>? controller;

  @override
  Widget build(BuildContext context) {
    final resolvedEffects = fadeScaleEffectsFor(context);
    return ShadSelect<T>(
      selectedOptionBuilder: selectedOptionBuilder,
      options: options,
      optionsBuilder: optionsBuilder,
      popoverController: popoverController,
      enabled: enabled,
      placeholder: placeholder,
      initialValue: initialValue,
      onChanged: onChanged,
      focusNode: focusNode,
      closeOnTapOutside: closeOnTapOutside,
      minWidth: minWidth,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      decoration: decoration,
      trailing: trailing,
      padding: padding,
      optionsPadding: optionsPadding,
      showScrollToBottomChevron: showScrollToBottomChevron,
      showScrollToTopChevron: showScrollToTopChevron,
      scrollController: scrollController,
      anchor: anchor,
      effects: resolvedEffects,
      shadows: shadows,
      filter: filter,
      header: header,
      footer: footer,
      closeOnSelect: closeOnSelect,
      allowDeselection: allowDeselection,
      groupId: groupId,
      itemCount: itemCount,
      shrinkWrap: shrinkWrap,
      controller: controller,
    );
  }
}
