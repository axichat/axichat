// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiMenuAction {
  const AxiMenuAction({
    required this.label,
    this.icon,
    this.trailing,
    this.onPressed,
    this.destructive = false,
    this.enabled = true,
  });

  final String label;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onPressed;
  final bool destructive;
  final bool enabled;
}

class AxiMenu extends StatefulWidget {
  const AxiMenu({
    super.key,
    required this.actions,
    this.minWidth,
    this.maxWidth,
    this.maxHeight,
  });

  final List<AxiMenuAction> actions;
  final double? minWidth;
  final double? maxWidth;
  final double? maxHeight;

  @override
  State<AxiMenu> createState() => _AxiMenuState();
}

class _AxiMenuState extends State<AxiMenu> {
  late List<FocusNode> _focusNodes;
  late final FocusNode _menuScopeNode;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _menuScopeNode = FocusNode(debugLabel: 'AxiMenuScope');
    _focusNodes = _buildFocusNodes(widget.actions.length);
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(covariant AxiMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actions.length != widget.actions.length) {
      for (final node in _focusNodes) {
        node.dispose();
      }
      _focusNodes = _buildFocusNodes(widget.actions.length);
    }
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    _menuScopeNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<FocusNode> _buildFocusNodes(int count) =>
      List<FocusNode>.generate(count, (_) => FocusNode());

  void _activateFocused() {
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null) return;
    final index = _focusNodes.indexOf(focused);
    if (index == -1) return;
    final action = widget.actions[index];
    if (!action.enabled) return;
    action.onPressed?.call();
  }

  void _focusFirstIfNone() {
    if (_focusNodes.isEmpty) return;
    final FocusNode? primary = FocusManager.instance.primaryFocus;
    if (primary == null || !_focusNodes.contains(primary)) {
      _focusNodes.first.requestFocus();
    }
  }

  void _focusLastIfNone() {
    if (_focusNodes.isEmpty) return;
    final FocusNode? primary = FocusManager.instance.primaryFocus;
    if (primary == null || !_focusNodes.contains(primary)) {
      _focusNodes.last.requestFocus();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final FocusNode? primary = FocusManager.instance.primaryFocus;
    final bool hasMenuFocus = primary != null && _focusNodes.contains(primary);
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (!hasMenuFocus) {
        _focusFirstIfNone();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (!hasMenuFocus) {
        _focusLastIfNone();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final double maxHeight = widget.maxHeight ?? context.sizing.menuMaxHeight;
    final double minWidth = widget.minWidth ?? context.sizing.menuMinWidth;
    final double maxWidth = widget.maxWidth ?? context.sizing.menuMaxWidth;
    final double menuHeight =
        widget.actions.length * context.sizing.menuItemHeight;
    final bool scrollable = menuHeight > maxHeight;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minWidth,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
      child: IntrinsicWidth(
        child: AxiModalSurface(
          padding: EdgeInsets.all(context.spacing.xs),
          backgroundColor: context.colorScheme.popover,
          borderColor: context.colorScheme.border,
          child: Focus(
            focusNode: _menuScopeNode,
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: Shortcuts(
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.arrowDown):
                    DirectionalFocusIntent(TraversalDirection.down),
                SingleActivator(LogicalKeyboardKey.arrowUp):
                    DirectionalFocusIntent(TraversalDirection.up),
                SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
              },
              child: Actions(
                actions: {
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (_) {
                      _activateFocused();
                      return null;
                    },
                  ),
                },
                child: FocusTraversalGroup(
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: scrollable,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: scrollable
                          ? const ClampingScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int index = 0;
                              index < widget.actions.length;
                              index++)
                            _AxiMenuItem(
                              action: widget.actions[index],
                              focusNode: _focusNodes[index],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AxiMenuItem extends StatefulWidget {
  const _AxiMenuItem({
    required this.action,
    required this.focusNode,
  });

  final AxiMenuAction action;
  final FocusNode focusNode;

  @override
  State<_AxiMenuItem> createState() => _AxiMenuItemState();
}

class _AxiMenuItemState extends State<_AxiMenuItem> {
  final AxiTapBounceController _bounceController = AxiTapBounceController();
  final ValueNotifier<Set<WidgetState>> _states =
      ValueNotifier<Set<WidgetState>>(<WidgetState>{});

  void _updateState(WidgetState state, bool enabled) {
    final next = Set<WidgetState>.from(_states.value);
    if (enabled) {
      next.add(state);
    } else {
      next.remove(state);
    }
    _states.value = next;
  }

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Duration animationDuration = context.select<SettingsCubit, Duration>(
      (cubit) => cubit.animationDuration,
    );
    final Duration pressDuration = Duration(
      milliseconds: (animationDuration.inMilliseconds *
              context.motion.buttonPressDurationFactor)
          .round(),
    );
    final Duration releaseDuration = Duration(
      milliseconds: (animationDuration.inMilliseconds *
              context.motion.buttonReleaseDurationFactor)
          .round(),
    );
    return ValueListenableBuilder<Set<WidgetState>>(
      valueListenable: _states,
      builder: (context, states, _) {
        final bool enabled =
            widget.action.enabled && widget.action.onPressed != null;
        final bool hovered = states.contains(WidgetState.hovered);
        final bool pressed = states.contains(WidgetState.pressed);
        final bool focused = states.contains(WidgetState.focused);
        final bool selected = hovered || pressed || focused;
        final Color baseForeground = widget.action.destructive
            ? context.colorScheme.destructive
            : context.colorScheme.foreground;
        final Color foreground =
            selected ? context.colorScheme.accentForeground : baseForeground;
        final Color background = selected
            ? context.colorScheme.accent
            : context.colorScheme.background.withValues(alpha: 0);
        final textStyle = context.textTheme.small.copyWith(color: foreground);
        final Widget leadingIcon = widget.action.icon == null
            ? const SizedBox.shrink()
            : Padding(
                padding: EdgeInsets.only(right: context.spacing.s),
                child: Icon(
                  widget.action.icon,
                  size: context.sizing.menuItemIconSize,
                  color: foreground,
                ),
              );
        final Widget trailing = widget.action.trailing == null
            ? const SizedBox.shrink()
            : Padding(
                padding: EdgeInsets.only(left: context.spacing.s),
                child: DefaultTextStyle(
                  style: context.textTheme.muted.copyWith(color: foreground),
                  child: widget.action.trailing!,
                ),
              );

        Widget content = SizedBox(
          height: context.sizing.menuItemHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacing.s),
            child: Row(
              children: [
                if (widget.action.icon != null) leadingIcon,
                Expanded(
                  child: DefaultTextStyle(
                    style: textStyle,
                    child: Text(widget.action.label),
                  ),
                ),
                if (widget.action.trailing != null) trailing,
              ],
            ),
          ),
        );

        content = Material(
          color: background,
          shape: RoundedSuperellipseBorder(borderRadius: context.radius),
          clipBehavior: Clip.antiAlias,
          child: ShadFocusable(
            focusNode: widget.focusNode,
            canRequestFocus: enabled,
            onFocusChange: enabled
                ? (value) => _updateState(WidgetState.focused, value)
                : null,
            builder: (context, focused, child) =>
                child ?? const SizedBox.shrink(),
            child: ShadGestureDetector(
              cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
              hoverStrategies: ShadTheme.of(context).hoverStrategies,
              onHoverChange: enabled
                  ? (value) => _updateState(WidgetState.hovered, value)
                  : null,
              onTap: enabled ? widget.action.onPressed : null,
              onTapDown: enabled
                  ? (details) {
                      _updateState(WidgetState.pressed, true);
                      _bounceController.handleTapDown(details);
                    }
                  : null,
              onTapUp: enabled
                  ? (details) {
                      _updateState(WidgetState.pressed, false);
                      _bounceController.handleTapUp(details);
                    }
                  : null,
              onTapCancel: enabled
                  ? () {
                      _updateState(WidgetState.pressed, false);
                      _bounceController.handleTapCancel();
                    }
                  : null,
              child: content,
            ),
          ),
        );

        if (enabled) {
          content = AxiTapBounce(
            controller: _bounceController,
            enabled: animationDuration != Duration.zero,
            scale: context.motion.buttonBounceScale,
            pressDuration: pressDuration,
            releaseDuration: releaseDuration,
            child: content,
          );
        }

        content = Opacity(
          opacity: enabled ? 1 : ShadTheme.of(context).disabledOpacity,
          child: content,
        );

        return Semantics(
          button: true,
          enabled: enabled,
          label: widget.action.label,
          onTap: widget.action.onPressed,
          child: content,
        );
      },
    );
  }
}
