// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:ui';

import 'package:axichat/src/app.dart';
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
    final theme = ShadTheme.of(context);
    final styledOptions = options
        ?.map((option) => _styledOption(context, option))
        .toList(growable: false);
    return ShadTheme(
      data: theme,
      child: ShadSelect<T>(
        selectedOptionBuilder: selectedOptionBuilder,
        options: styledOptions,
        optionsBuilder: optionsBuilder == null
            ? null
            : (context, index) {
                final option = optionsBuilder?.call(context, index);
                if (option is ShadOption<T>) {
                  return _styledOption(context, option);
                }
                return option;
              },
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
      ),
    );
  }

  ShadOption<T> _styledOption(BuildContext context, ShadOption<T> option) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    return ShadOption<T>(
      key: option.key,
      value: option.value,
      hoveredBackgroundColor: option.hoveredBackgroundColor ?? colors.accent,
      padding:
          option.padding ??
          EdgeInsets.symmetric(horizontal: spacing.s, vertical: spacing.s),
      selectedIcon:
          option.selectedIcon ??
          Padding(
            padding: EdgeInsetsDirectional.only(start: spacing.m),
            child: Icon(
              LucideIcons.check,
              size: sizing.menuItemIconSize,
              color: colors.accentForeground,
            ),
          ),
      radius:
          option.radius ??
          BorderRadius.all(Radius.circular(context.radii.squircleSm)),
      direction: option.direction,
      backgroundColor: option.backgroundColor ?? colors.popover,
      selectedBackgroundColor: option.selectedBackgroundColor ?? colors.accent,
      textStyle:
          option.textStyle ??
          context.textTheme.small.copyWith(color: colors.foreground),
      selectedTextStyle:
          option.selectedTextStyle ??
          context.textTheme.small.copyWith(color: colors.accentForeground),
      child: option.child,
    );
  }
}
