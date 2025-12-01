import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _kMenuItemHeight = 52;
const double _kMenuMinWidth = 0;
const double _kMenuMaxWidth = 360;
const double _kMenuMaxHeight = 320;
const double _kMenuCornerRadius = 20;
const double _kMenuItemCornerRadius = 12;

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
  late final FocusNode _menuScopeNode;

  @override
  void initState() {
    super.initState();
    _menuScopeNode = FocusNode(debugLabel: 'AxiMenuScope');
    _focusNodes = _buildFocusNodes(widget.actions.length);
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
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final BorderRadius borderRadius = BorderRadius.circular(_kMenuCornerRadius);
    final dividerColor = colors.border.withValues(alpha: 0.55);
    final hoverColor = colors.muted.withValues(alpha: 0.1);
    final focusColor = colors.primary.withValues(alpha: 0.16);

    final height = math.min(
      widget.actions.length * _kMenuItemHeight,
      widget.maxHeight,
    );
    final scrollable = widget.actions.length * _kMenuItemHeight > height;

    final TextDirection textDirection =
        Directionality.maybeOf(context) ?? TextDirection.ltr;
    final double computedWidth =
        widget.actions.fold<double>(widget.minWidth, (current, action) {
      final double textWidth = _measureLabelWidth(
        action.label,
        textTheme.small.copyWith(
          fontWeight: FontWeight.w700,
        ),
        textDirection,
      );
      final double iconWidth = action.icon != null ? 28 : 0; // 16 icon + 12 gap
      final double paddedWidth = 14 * 2 + iconWidth + textWidth;
      return math.max(current, paddedWidth);
    });

    final double menuWidth = computedWidth.clamp(
      widget.minWidth,
      widget.maxWidth,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
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
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: menuWidth,
            maxWidth: widget.maxWidth,
            maxHeight: widget.maxHeight,
          ),
          child: Material(
            color: colors.card,
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius,
              side: BorderSide(color: colors.border.withValues(alpha: 0.9)),
            ),
            clipBehavior: Clip.antiAlias,
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
                    child: SizedBox(
                      width: menuWidth,
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
      ),
    );
  }

  double _measureLabelWidth(
    String label,
    TextStyle style,
    TextDirection textDirection,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: textDirection,
      maxLines: 1,
      ellipsis: null,
    )..layout();
    return painter.width;
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
    final BorderRadius radius = BorderRadius.circular(_kMenuItemCornerRadius);
    final WidgetStateProperty<Color?> overlay =
        WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.focused)) {
        return focusColor;
      }
      if (states.contains(WidgetState.hovered)) {
        return hoverColor;
      }
      return Colors.transparent;
    });

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: InkWell(
        focusNode: focusNode,
        autofocus: false,
        onTap: enabled ? onPressed : null,
        overlayColor: overlay,
        customBorder: RoundedRectangleBorder(borderRadius: radius),
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
      ),
    );
  }
}
