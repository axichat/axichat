// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:ui';

import 'package:animations/animations.dart';
import 'package:axichat/src/common/ui/settings_cubit_lookup.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _fadeScaleEffectStart = 0.0;
const double _fadeScaleEffectEnd = 1.0;
const Curve _fadeScaleEffectCurve = Curves.linear;
const Duration _fallbackSelectAnimationDuration = Duration(milliseconds: 300);

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
    final Duration resolvedDuration = _resolveAnimationDuration(context);
    final List<Effect<dynamic>> resolvedEffects =
        resolvedDuration == Duration.zero
            ? const []
            : <Effect<dynamic>>[
                _FadeScaleTransitionEffect(duration: resolvedDuration),
              ];
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

  Duration _resolveAnimationDuration(BuildContext context) {
    final SettingsCubit? settingsCubit = maybeSettingsCubit(context);
    if (settingsCubit == null) {
      return _fallbackSelectAnimationDuration;
    }
    return context.select<SettingsCubit, Duration>(
      (cubit) => cubit.animationDuration,
    );
  }
}

class _FadeScaleTransitionEffect extends Effect<double> {
  const _FadeScaleTransitionEffect({super.duration})
      : super(
          curve: _fadeScaleEffectCurve,
          begin: _fadeScaleEffectStart,
          end: _fadeScaleEffectEnd,
        );

  @override
  Widget build(
    BuildContext context,
    Widget child,
    AnimationController controller,
    EffectEntry entry,
  ) {
    final animation = buildAnimation(controller, entry);
    return FadeScaleTransition(
      animation: animation,
      child: child,
    );
  }
}
