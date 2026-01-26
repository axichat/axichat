// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AxiMenuAction {
  const AxiMenuAction({
    required this.label,
    this.icon,
    this.onPressed,
    this.destructive = false,
    this.enabled = true,
  });

  final String label;
  final IconData? icon;
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
                            SizedBox(
                              height: context.sizing.menuItemHeight,
                              child: AxiListButton(
                                focusNode: _focusNodes[index],
                                variant: AxiButtonVariant.ghost,
                                leading: widget.actions[index].icon == null
                                    ? null
                                    : Icon(
                                        widget.actions[index].icon,
                                        size: context.sizing.menuItemIconSize,
                                      ),
                                foregroundColor:
                                    widget.actions[index].destructive
                                        ? context.colorScheme.destructive
                                        : null,
                                semanticLabel: widget.actions[index].label,
                                onPressed: widget.actions[index].enabled
                                    ? () {
                                        widget.actions[index].onPressed?.call();
                                      }
                                    : null,
                                child: Text(widget.actions[index].label),
                              ),
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
