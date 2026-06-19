// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/axi_menu.dart';
import 'package:axichat/src/common/ui/axi_popover.dart';
import 'package:axichat/src/common/ui/axi_tap_bounce.dart';
import 'package:axichat/src/common/ui/axi_tooltip.dart';
import 'package:axichat/src/common/ui/buttons/axi_button.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

typedef AxiDropdownSelectedBuilder<T> =
    Widget Function(BuildContext context, T value);
typedef AxiDropdownOptionBuilder<T> =
    Widget Function(
      BuildContext context,
      AxiDropdownOption<T> option,
      bool selected,
    );

class AxiDropdownOption<T> {
  const AxiDropdownOption({
    required this.value,
    required this.label,
    this.child,
    this.selectedChild,
    this.leading,
    this.trailing,
    this.enabled = true,
  });

  final T value;
  final String label;
  final Widget? child;
  final Widget? selectedChild;
  final Widget? leading;
  final Widget? trailing;
  final bool enabled;
}

class AxiDropdown<T> extends StatefulWidget {
  const AxiDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    this.selectedBuilder,
    this.optionBuilder,
    this.buttonSize = AxiButtonSize.sm,
    this.widthBehavior = AxiButtonWidth.fit,
    this.minWidth,
    this.maxWidth,
    this.maxHeight,
    this.decoration,
    this.padding,
    this.trailing,
    this.closeOnTapOutside = true,
    this.tooltip,
    this.semanticLabel,
    this.groupId,
  });

  final T value;
  final List<AxiDropdownOption<T>> options;
  final ValueChanged<T>? onChanged;
  final bool enabled;
  final AxiDropdownSelectedBuilder<T>? selectedBuilder;
  final AxiDropdownOptionBuilder<T>? optionBuilder;
  final AxiButtonSize buttonSize;
  final AxiButtonWidth widthBehavior;
  final double? minWidth;
  final double? maxWidth;
  final double? maxHeight;
  final ShadDecoration? decoration;
  final EdgeInsets? padding;
  final Widget? trailing;
  final bool closeOnTapOutside;
  final String? tooltip;
  final String? semanticLabel;
  final Object? groupId;

  @override
  State<AxiDropdown<T>> createState() => _AxiDropdownState<T>();
}

class _AxiDropdownState<T> extends State<AxiDropdown<T>> {
  late final ShadPopoverController _popoverController;
  final AxiTapBounceController _bounceController = AxiTapBounceController();
  final ValueNotifier<Set<WidgetState>> _triggerStates =
      ValueNotifier<Set<WidgetState>>(<WidgetState>{});

  @override
  void initState() {
    super.initState();
    _popoverController = ShadPopoverController();
  }

  @override
  void dispose() {
    _triggerStates.dispose();
    _popoverController.dispose();
    super.dispose();
  }

  bool get _enabled => widget.enabled && widget.onChanged != null;

  AxiDropdownOption<T>? get _selectedOption {
    for (final option in widget.options) {
      if (option.value == widget.value) {
        return option;
      }
    }
    return null;
  }

  void _updateTriggerState(WidgetState state, bool enabled) {
    final next = Set<WidgetState>.from(_triggerStates.value);
    if (enabled) {
      next.add(state);
    } else {
      next.remove(state);
    }
    _triggerStates.value = next;
  }

  void _select(AxiDropdownOption<T> option) {
    if (!option.enabled) {
      return;
    }
    _popoverController.hide();
    if (option.value != widget.value) {
      widget.onChanged?.call(option.value);
    }
  }

  Widget _withKeyboardActivation(Widget child) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              if (_enabled) {
                _popoverController.toggle();
              }
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedOption;
    final selectedChild =
        widget.selectedBuilder?.call(context, widget.value) ??
        selected?.selectedChild ??
        selected?.child ??
        Text(selected?.label ?? '');
    final trigger = widget.decoration == null && widget.padding == null
        ? _buttonTrigger(context, selectedChild)
        : _decoratedTrigger(context, selectedChild);
    return AxiPopover(
      controller: _popoverController,
      closeOnTapOutside: widget.closeOnTapOutside,
      padding: EdgeInsets.zero,
      decoration: ShadDecoration.none,
      shadows: const <BoxShadow>[],
      groupId: widget.groupId,
      popover: (context) {
        return AxiMenu(
          minWidth: widget.minWidth,
          maxWidth: widget.maxWidth,
          maxHeight: widget.maxHeight,
          actions: [
            for (final option in widget.options)
              AxiMenuAction(
                label: option.label,
                child:
                    widget.optionBuilder?.call(
                      context,
                      option,
                      option.value == widget.value,
                    ) ??
                    option.child,
                leading: option.leading,
                trailing: option.value == widget.value
                    ? const Icon(LucideIcons.check)
                    : option.trailing,
                enabled: option.enabled,
                onPressed: () => _select(option),
              ),
          ],
        );
      },
      child: trigger,
    );
  }

  Widget _buttonTrigger(BuildContext context, Widget selectedChild) {
    final Duration animationDuration = context.select<SettingsCubit, Duration>(
      (cubit) => cubit.animationDuration,
    );
    final Duration pressDuration = Duration(
      milliseconds:
          (animationDuration.inMilliseconds *
                  context.motion.buttonPressDurationFactor)
              .round(),
    );
    final Duration releaseDuration = Duration(
      milliseconds:
          (animationDuration.inMilliseconds *
                  context.motion.buttonReleaseDurationFactor)
              .round(),
    );
    return ValueListenableBuilder<Set<WidgetState>>(
      valueListenable: _triggerStates,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        final pressed = states.contains(WidgetState.pressed);
        final focused = states.contains(WidgetState.focused);
        final colors = context.colorScheme;
        final active = _enabled && (hovered || pressed || focused);
        final background = active ? colors.accent : colors.secondary;
        final foreground = active
            ? colors.accentForeground
            : colors.secondaryForeground;
        final disabledForeground = colors.mutedForeground;
        final triggerForeground = _enabled ? foreground : disabledForeground;
        final gap = widget.buttonSize.gap(context.spacing);
        Widget content = ConstrainedBox(
          constraints: BoxConstraints(minHeight: context.sizing.menuItemHeight),
          child: Padding(
            padding: widget.buttonSize.padding(context.spacing),
            child: Row(
              mainAxisSize: widget.widthBehavior == AxiButtonWidth.expand
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(child: selectedChild),
                SizedBox(width: gap),
                widget.trailing ??
                    Icon(
                      LucideIcons.chevronDown,
                      size: context.sizing.menuItemIconSize,
                    ),
              ],
            ),
          ),
        );
        content = IconTheme.merge(
          data: IconThemeData(color: triggerForeground),
          child: DefaultTextStyle(
            style: context.textTheme.small.copyWith(color: triggerForeground),
            textAlign: TextAlign.center,
            child: content,
          ),
        );
        Widget trigger = Material(
          color: background,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(
              widget.buttonSize.cornerRadius(context.radii),
            ),
            side: BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: content,
        );
        if (widget.minWidth != null || widget.maxWidth != null) {
          trigger = ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: widget.minWidth ?? 0,
              maxWidth: widget.maxWidth ?? double.infinity,
            ),
            child: trigger,
          );
        }
        trigger = ShadFocusable(
          canRequestFocus: _enabled,
          onFocusChange: _enabled
              ? (value) => _updateTriggerState(WidgetState.focused, value)
              : null,
          builder: (context, focused, child) =>
              child ?? const SizedBox.shrink(),
          child: ShadGestureDetector(
            cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
            behavior: HitTestBehavior.opaque,
            hoverStrategies: ShadTheme.of(context).hoverStrategies,
            onHoverChange: _enabled
                ? (value) => _updateTriggerState(WidgetState.hovered, value)
                : null,
            onTap: _enabled ? _popoverController.toggle : null,
            onTapDown: _enabled
                ? (details) {
                    _updateTriggerState(WidgetState.pressed, true);
                    _bounceController.handleTapDown(details);
                  }
                : null,
            onTapUp: _enabled
                ? (details) {
                    _updateTriggerState(WidgetState.pressed, false);
                    _bounceController.handleTapUp(details);
                  }
                : null,
            onTapCancel: _enabled
                ? () {
                    _updateTriggerState(WidgetState.pressed, false);
                    _bounceController.handleTapCancel();
                  }
                : null,
            child: trigger,
          ),
        );
        trigger = _withKeyboardActivation(trigger);
        if (_enabled) {
          trigger = AxiTapBounce(
            controller: _bounceController,
            enabled: animationDuration != Duration.zero,
            scale: widget.buttonSize == AxiButtonSize.sm
                ? context.motion.buttonCompactBounceScale
                : context.motion.buttonBounceScale,
            pressDuration: pressDuration,
            releaseDuration: releaseDuration,
            child: trigger,
          );
        }
        trigger = Opacity(
          opacity: _enabled ? 1 : ShadTheme.of(context).disabledOpacity,
          child: trigger,
        );
        if (widget.tooltip != null) {
          trigger = AxiTooltip(
            builder: (context) =>
                Text(widget.tooltip!, style: context.textTheme.muted),
            child: trigger,
          );
        }
        return Semantics(
          button: true,
          enabled: _enabled,
          label: widget.semanticLabel ?? widget.tooltip,
          onTap: _enabled ? _popoverController.toggle : null,
          child: trigger,
        );
      },
    );
  }

  Widget _decoratedTrigger(BuildContext context, Widget selectedChild) {
    final Duration animationDuration = context.select<SettingsCubit, Duration>(
      (cubit) => cubit.animationDuration,
    );
    final Duration pressDuration = Duration(
      milliseconds:
          (animationDuration.inMilliseconds *
                  context.motion.buttonPressDurationFactor)
              .round(),
    );
    final Duration releaseDuration = Duration(
      milliseconds:
          (animationDuration.inMilliseconds *
                  context.motion.buttonReleaseDurationFactor)
              .round(),
    );
    return ValueListenableBuilder<Set<WidgetState>>(
      valueListenable: _triggerStates,
      builder: (context, states, _) {
        final focused = states.contains(WidgetState.focused);
        final colors = context.colorScheme;
        final foreground = _enabled
            ? colors.foreground
            : colors.mutedForeground;
        final gap = widget.buttonSize.gap(context.spacing);
        Widget trigger = ShadDecorator(
          focused: focused,
          decoration: widget.decoration,
          child: Padding(
            padding:
                widget.padding ?? widget.buttonSize.padding(context.spacing),
            child: Row(
              mainAxisSize: widget.widthBehavior == AxiButtonWidth.expand
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(child: selectedChild),
                SizedBox(width: gap),
                widget.trailing ??
                    Icon(
                      LucideIcons.chevronDown,
                      size: context.sizing.menuItemIconSize,
                    ),
              ],
            ),
          ),
        );
        trigger = IconTheme.merge(
          data: IconThemeData(color: foreground),
          child: DefaultTextStyle.merge(
            style: context.textTheme.small.copyWith(color: foreground),
            child: trigger,
          ),
        );
        if (widget.minWidth != null || widget.maxWidth != null) {
          trigger = ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: widget.minWidth ?? 0,
              maxWidth: widget.maxWidth ?? double.infinity,
            ),
            child: trigger,
          );
        }
        trigger = Material(
          color: Colors.transparent,
          child: ShadFocusable(
            canRequestFocus: _enabled,
            onFocusChange: _enabled
                ? (value) => _updateTriggerState(WidgetState.focused, value)
                : null,
            builder: (context, focused, child) =>
                child ?? const SizedBox.shrink(),
            child: ShadGestureDetector(
              cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
              behavior: HitTestBehavior.opaque,
              hoverStrategies: ShadTheme.of(context).hoverStrategies,
              onHoverChange: _enabled
                  ? (value) => _updateTriggerState(WidgetState.hovered, value)
                  : null,
              onTap: _enabled ? _popoverController.toggle : null,
              onTapDown: _enabled
                  ? (details) {
                      _updateTriggerState(WidgetState.pressed, true);
                      _bounceController.handleTapDown(details);
                    }
                  : null,
              onTapUp: _enabled
                  ? (details) {
                      _updateTriggerState(WidgetState.pressed, false);
                      _bounceController.handleTapUp(details);
                    }
                  : null,
              onTapCancel: _enabled
                  ? () {
                      _updateTriggerState(WidgetState.pressed, false);
                      _bounceController.handleTapCancel();
                    }
                  : null,
              child: trigger,
            ),
          ),
        );
        trigger = _withKeyboardActivation(trigger);
        if (_enabled) {
          trigger = AxiTapBounce(
            controller: _bounceController,
            enabled: animationDuration != Duration.zero,
            scale: widget.buttonSize == AxiButtonSize.sm
                ? context.motion.buttonCompactBounceScale
                : context.motion.buttonBounceScale,
            pressDuration: pressDuration,
            releaseDuration: releaseDuration,
            child: trigger,
          );
        }
        trigger = Opacity(
          opacity: _enabled ? 1 : ShadTheme.of(context).disabledOpacity,
          child: trigger,
        );
        if (widget.tooltip != null) {
          trigger = AxiTooltip(
            builder: (context) =>
                Text(widget.tooltip!, style: context.textTheme.muted),
            child: trigger,
          );
        }
        return Semantics(
          button: true,
          enabled: _enabled,
          label: widget.semanticLabel ?? widget.tooltip,
          onTap: _enabled ? _popoverController.toggle : null,
          child: trigger,
        );
      },
    );
  }
}
