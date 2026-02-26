// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;
import 'dart:ui';

import 'package:axichat/src/common/ui/fade_scale_effect.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiContextMenu extends StatelessWidget {
  const AxiContextMenu({
    super.key,
    required this.child,
    required this.items,
    this.anchor,
    this.visible,
    this.constraints,
    this.onHoverArea,
    this.padding,
    this.groupId,
    this.shadows,
    this.decoration,
    this.filter,
    this.controller,
    this.onTapOutside,
    this.onTapInside,
    this.onTapUpInside,
    this.onTapUpOutside,
    this.popoverReverseDuration,
  });

  final Widget child;
  final List<Widget> items;
  final ShadAnchorBase? anchor;
  final bool? visible;
  final BoxConstraints? constraints;
  final ValueChanged<bool>? onHoverArea;
  final EdgeInsetsGeometry? padding;
  final Object? groupId;
  final List<BoxShadow>? shadows;
  final ShadDecoration? decoration;
  final ImageFilter? filter;
  final ShadContextMenuController? controller;
  final TapRegionCallback? onTapOutside;
  final TapRegionCallback? onTapInside;
  final TapRegionUpCallback? onTapUpInside;
  final TapRegionUpCallback? onTapUpOutside;
  final Duration? popoverReverseDuration;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return child;
    final effects = fadeScaleEffectsFor(context);
    final Widget menuBody = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    );
    return ShadContextMenu(
      items: [menuBody],
      anchor: anchor,
      visible: visible,
      constraints: constraints,
      onHoverArea: onHoverArea,
      padding: padding,
      groupId: groupId,
      effects: effects,
      shadows: shadows,
      decoration: decoration,
      filter: filter,
      controller: controller,
      onTapOutside: onTapOutside,
      onTapInside: onTapInside,
      onTapUpInside: onTapUpInside,
      onTapUpOutside: onTapUpOutside,
      popoverReverseDuration: popoverReverseDuration,
      child: child,
    );
  }
}

class AxiContextMenuRegion extends StatefulWidget {
  const AxiContextMenuRegion({
    super.key,
    required this.child,
    required this.items,
    this.groupId,
    this.visible,
    this.controller,
    this.longPressEnabled,
    this.onMenuVisibilityChanged,
  });

  final Widget child;
  final List<Widget> items;
  final Object? groupId;
  final bool? visible;
  final ShadContextMenuController? controller;
  final bool? longPressEnabled;
  final ValueChanged<bool>? onMenuVisibilityChanged;

  @override
  State<AxiContextMenuRegion> createState() => _AxiContextMenuRegionState();
}

class _AxiContextMenuRegionState extends State<AxiContextMenuRegion> {
  static final Object _defaultMenuGroupId = Object();
  static final Map<Object, _AxiContextMenuRegionState> _openMenuByGroup =
      <Object, _AxiContextMenuRegionState>{};

  ShadContextMenuController? _controller;
  ShadContextMenuController? _attachedController;
  ShadContextMenuController get controller =>
      widget.controller ??
      (_controller ??= ShadContextMenuController(
        isOpen: widget.visible ?? false,
      ));

  ShadAnchorBase? _anchor;
  Offset? _pendingLongPress;
  final bool _isContextMenuAlreadyDisabled =
      kIsWeb && !BrowserContextMenu.enabled;
  var _controllerOpen = false;
  Object get _menuGroupId => widget.groupId ?? _defaultMenuGroupId;

  @override
  void initState() {
    super.initState();
    _attachControllerListener();
  }

  @override
  void didUpdateWidget(covariant AxiContextMenuRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != null) {
      controller.setOpen(widget.visible!);
    }
    if (oldWidget.groupId != widget.groupId) {
      _unregisterMenuGroup(oldWidget.groupId ?? _defaultMenuGroupId);
      if (_controllerOpen) {
        _closeOpenMenuForCurrentGroup();
        _openMenuByGroup[_menuGroupId] = this;
      }
    }
    if (oldWidget.controller != widget.controller) {
      _attachControllerListener(force: true);
    } else {
      _attachControllerListener();
    }
  }

  @override
  void dispose() {
    _unregisterMenuGroup(_menuGroupId);
    _attachedController?.removeListener(_handleControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _showAtOffset(Offset offset) {
    if (!mounted || widget.items.isEmpty) return;
    _closeOpenMenuForCurrentGroup();
    setState(() {
      _anchor = _edgeAwareAnchor(offset);
    });
    controller.show();
    _updateOpenState(true);
  }

  void _hide() {
    controller.hide();
    _updateOpenState(false);
  }

  void _attachControllerListener({bool force = false}) {
    final current = controller;
    if (!force && identical(current, _attachedController)) return;
    _attachedController?.removeListener(_handleControllerChanged);
    _attachedController = current;
    _attachedController?.addListener(_handleControllerChanged);
  }

  void _handleControllerChanged() {
    _updateOpenState(controller.isOpen);
  }

  void _updateOpenState(bool open) {
    if (_controllerOpen == open) return;
    _controllerOpen = open;
    if (open) {
      _openMenuByGroup[_menuGroupId] = this;
    } else {
      _unregisterMenuGroup(_menuGroupId);
    }
    widget.onMenuVisibilityChanged?.call(open);
  }

  void _closeOpenMenuForCurrentGroup() {
    final existing = _openMenuByGroup[_menuGroupId];
    if (existing == null) {
      return;
    }
    if (!existing.mounted) {
      _openMenuByGroup.remove(_menuGroupId);
      return;
    }
    if (!identical(existing, this)) {
      existing.controller.hide();
    }
  }

  void _unregisterMenuGroup(Object groupId) {
    if (identical(_openMenuByGroup[groupId], this)) {
      _openMenuByGroup.remove(groupId);
    }
  }

  ShadAnchorBase _edgeAwareAnchor(Offset globalPosition) {
    final size = MediaQuery.sizeOf(context);
    if (size.isEmpty) {
      return const ShadAnchorAuto(offset: Offset(0, 4));
    }
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final safeLeft = math.max(viewPadding.left, viewInsets.left);
    final safeRight = math.max(viewPadding.right, viewInsets.right);
    final safeTop = math.max(viewPadding.top, viewInsets.top);
    final safeBottom = math.max(viewPadding.bottom, viewInsets.bottom);
    final usableLeft = safeLeft + 16;
    final usableRight = size.width - safeRight - 16;
    final usableTop = safeTop + 16;
    final usableBottom = size.height - safeBottom - 16;

    final clampedPosition = Offset(
      globalPosition.dx.clamp(usableLeft, usableRight).toDouble(),
      globalPosition.dy.clamp(usableTop, usableBottom).toDouble(),
    );

    final RenderObject? renderObject = context.findRenderObject();
    final Rect targetRect = switch (renderObject) {
      RenderBox box when box.hasSize => Rect.fromLTWH(
        box.localToGlobal(Offset.zero).dx,
        box.localToGlobal(Offset.zero).dy,
        box.size.width,
        box.size.height,
      ),
      _ => Rect.fromCenter(center: clampedPosition, width: 0, height: 0),
    };

    final leftSpace = targetRect.left - usableLeft;
    final rightSpace = usableRight - targetRect.right;
    const sideClearance = 220.0;
    if (math.max(leftSpace, rightSpace) >= sideClearance) {
      final openToRight = rightSpace >= leftSpace;
      final vertical = _verticalAnchor(
        topSpace: targetRect.top - usableTop,
        bottomSpace: usableBottom - targetRect.bottom,
      );
      final alignmentY = switch (vertical) {
        _MenuVertical.top => -1.0,
        _MenuVertical.center => 0.0,
        _MenuVertical.bottom => 1.0,
      };
      final targetX = openToRight ? 1.0 : -1.0;
      final followerX = targetX;
      return ShadAnchorAuto(
        offset: Offset(openToRight ? 8 : -8, 0),
        followerAnchor: Alignment(followerX, alignmentY),
        targetAnchor: Alignment(targetX, alignmentY),
      );
    }

    return ShadGlobalAnchor(clampedPosition);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return widget.child;
    }

    final platform = defaultTargetPlatform;
    final effectiveLongPressEnabled =
        widget.longPressEnabled ??
        (platform == TargetPlatform.android || platform == TargetPlatform.iOS);

    final isWindows = platform == TargetPlatform.windows;

    return AxiContextMenu(
      anchor: _anchor ?? const ShadAnchorAuto(offset: Offset(0, 4)),
      controller: controller,
      items: widget.items,
      groupId: widget.groupId,
      popoverReverseDuration: Duration.zero,
      onTapOutside: (_) => _hide(),
      onTapUpOutside: (_) => _hide(),
      child: ShadGestureDetector(
        onTapDown: (_) => _hide(),
        onSecondaryTapDown: (details) async {
          if (kIsWeb && !_isContextMenuAlreadyDisabled) {
            await BrowserContextMenu.disableContextMenu();
          }
          if (!isWindows) {
            _showAtOffset(details.globalPosition);
          }
        },
        onSecondaryTapUp: (details) async {
          if (isWindows) {
            _showAtOffset(details.globalPosition);
            await Future<void>.delayed(Duration.zero);
          }
          if (kIsWeb && !_isContextMenuAlreadyDisabled) {
            await BrowserContextMenu.enableContextMenu();
          }
        },
        onLongPressStart: effectiveLongPressEnabled
            ? (details) => _pendingLongPress = details.globalPosition
            : null,
        onLongPress: effectiveLongPressEnabled
            ? () {
                final pending = _pendingLongPress;
                if (pending != null) {
                  _showAtOffset(pending);
                }
              }
            : null,
        child: widget.child,
      ),
    );
  }

  _MenuVertical _verticalAnchor({
    required double topSpace,
    required double bottomSpace,
  }) {
    const edgeThreshold = 96.0;
    final constrainedTop = topSpace < edgeThreshold;
    final constrainedBottom = bottomSpace < edgeThreshold;
    if (constrainedTop && !constrainedBottom) {
      return _MenuVertical.top;
    }
    if (constrainedBottom && !constrainedTop) {
      return _MenuVertical.bottom;
    }
    return _MenuVertical.center;
  }
}

enum _MenuVertical { top, center, bottom }
