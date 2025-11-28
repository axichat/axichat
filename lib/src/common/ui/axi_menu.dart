import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _kMenuItemHeight = 52;
const double _kMenuMinWidth = 220;
const double _kMenuMaxWidth = 360;
const double _kMenuMaxHeight = 320;

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
    this.minWidth = _kMenuMinWidth,
    this.maxWidth = _kMenuMaxWidth,
    this.maxHeight = _kMenuMaxHeight,
  });

  final List<AxiMenuAction> actions;
  final double minWidth;
  final double maxWidth;
  final double maxHeight;

  @override
  State<AxiMenu> createState() => _AxiMenuState();
}

class _AxiMenuState extends State<AxiMenu> {
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _focusNodes = _buildFocusNodes(widget.actions.length);
    _autofocusFirst();
  }

  @override
  void didUpdateWidget(covariant AxiMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actions.length != widget.actions.length) {
      for (final node in _focusNodes) {
        node.dispose();
      }
      _focusNodes = _buildFocusNodes(widget.actions.length);
      _autofocusFirst();
    }
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _autofocusFirst() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focusNodes.isEmpty) return;
      final FocusNode node = _focusNodes.first;
      if (node.canRequestFocus) {
        node.requestFocus();
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final borderRadius = BorderRadius.circular(20);
    final dividerColor = colors.border.withValues(alpha: 0.55);
    final hoverColor = colors.muted.withValues(alpha: 0.08);
    final focusColor = colors.primary.withValues(alpha: 0.12);

    final height = math.min(
      widget.actions.length * _kMenuItemHeight,
      widget.maxHeight,
    );
    final scrollable = widget.actions.length * _kMenuItemHeight > height;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: widget.minWidth,
        maxWidth: widget.maxWidth,
        maxHeight: widget.maxHeight,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: borderRadius,
          border: Border.all(color: colors.border.withValues(alpha: 0.9)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 28,
              offset: Offset(0, 18),
            ),
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 8,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Material(
            color: Colors.transparent,
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
                  child: SizedBox(
                    height: height,
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      physics: scrollable
                          ? const ClampingScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      itemCount: widget.actions.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 0,
                        thickness: 0.7,
                        color: dividerColor,
                      ),
                      itemBuilder: (context, index) {
                        final action = widget.actions[index];
                        return SizedBox(
                          height: _kMenuItemHeight,
                          child: _AxiMenuItem(
                            action: action,
                            focusNode: _focusNodes[index],
                            textTheme: textTheme,
                            colors: colors,
                            hoverColor: hoverColor,
                            focusColor: focusColor,
                            onPressed: action.enabled
                                ? () {
                                    action.onPressed?.call();
                                  }
                                : null,
                          ),
                        );
                      },
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

class _AxiMenuItem extends StatelessWidget {
  const _AxiMenuItem({
    required this.action,
    required this.focusNode,
    required this.textTheme,
    required this.colors,
    required this.hoverColor,
    required this.focusColor,
    required this.onPressed,
  });

  final AxiMenuAction action;
  final FocusNode focusNode;
  final ShadTextTheme textTheme;
  final ShadColorScheme colors;
  final Color hoverColor;
  final Color focusColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = action.enabled && onPressed != null;
    final Color foreground = action.destructive
        ? colors.destructive
        : (enabled
            ? colors.foreground
            : colors.mutedForeground.withValues(alpha: 0.65));

    return InkWell(
      focusNode: focusNode,
      autofocus: false,
      onTap: enabled ? onPressed : null,
      hoverColor: hoverColor,
      focusColor: focusColor,
      highlightColor: focusColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            if (action.icon != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  action.icon,
                  size: 16,
                  color: foreground,
                ),
              ),
            Expanded(
              child: Text(
                action.label,
                style: textTheme.small.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
