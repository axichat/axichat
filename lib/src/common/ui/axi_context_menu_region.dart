// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;
import 'dart:ui';

import 'package:axichat/src/common/ui/in_bounds_fade_scale.dart';
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

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return child;
    final Widget menuBody = InBoundsFadeScale(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items,
      ),
    );
    return ShadContextMenu(
      items: [menuBody],
      anchor: anchor,
      visible: visible,
      constraints: constraints,
      onHoverArea: onHoverArea,
      padding: padding,
      groupId: groupId,
      effects: const [],
      shadows: shadows,
      decoration: decoration,
      filter: filter,
      controller: controller,
      onTapOutside: onTapOutside,
      onTapInside: onTapInside,
      onTapUpInside: onTapUpInside,
      onTapUpOutside: onTapUpOutside,
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
  ShadContextMenuController? _controller;
  ShadContextMenuController? _attachedController;
  ShadContextMenuController get controller =>
      widget.controller ??
      (_controller ??=
          ShadContextMenuController(isOpen: widget.visible ?? false));

  ShadAnchorBase? _anchor;
  Offset? _pendingLongPress;
  final bool _isContextMenuAlreadyDisabled =
      kIsWeb && !BrowserContextMenu.enabled;
  var _controllerOpen = false;

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
    if (oldWidget.controller != widget.controller) {
      _attachControllerListener(force: true);
    } else {
      _attachControllerListener();
    }
  }

  @override
  void dispose() {
    _attachedController?.removeListener(_handleControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _showAtOffset(Offset offset) {
    if (!mounted || widget.items.isEmpty) return;
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
    widget.onMenuVisibilityChanged?.call(open);
  }

  ShadAnchorAuto _edgeAwareAnchor(Offset globalPosition) {
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

    final clampedDx = globalPosition.dx.clamp(usableLeft, usableRight);
    final clampedDy = globalPosition.dy.clamp(usableTop, usableBottom);

    final aboveSpace = clampedDy - safeTop;
    final belowSpace = (size.height - safeBottom) - clampedDy;
    const edgeThreshold = 128.0;
    const menuClearance = 240.0;
    final nearTopEdge = aboveSpace < edgeThreshold;
    final nearBottomEdge = belowSpace < edgeThreshold;
    final fitsBelow = belowSpace >= menuClearance;
    final fitsAbove = aboveSpace >= menuClearance;
    final preferBelow = switch ((nearTopEdge, nearBottomEdge)) {
      (true, false) => true,
      (false, true) => false,
      _ when fitsBelow != fitsAbove => fitsBelow,
      _ => belowSpace >= aboveSpace,
    };

    const snapThreshold = 96.0;
    final leftSpace = clampedDx - safeLeft;
    final rightSpace = (size.width - safeRight) - clampedDx;
    final horizontal = leftSpace < snapThreshold
        ? _MenuHorizontal.left
        : rightSpace < snapThreshold
            ? _MenuHorizontal.right
            : _MenuHorizontal.center;

    return ShadAnchorAuto(
      offset: _anchorOffset(preferBelow, horizontal),
      followerAnchor: _followerAlignment(preferBelow, horizontal),
      targetAnchor: _targetAlignment(preferBelow, horizontal),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return widget.child;
    }

    final platform = Theme.of(context).platform;
    final effectiveLongPressEnabled = widget.longPressEnabled ??
        (platform == TargetPlatform.android || platform == TargetPlatform.iOS);

    final isWindows = platform == TargetPlatform.windows;

    return AxiContextMenu(
      anchor: _anchor ?? const ShadAnchorAuto(offset: Offset(0, 4)),
      controller: controller,
      items: widget.items,
      groupId: widget.groupId,
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

  Alignment _targetAlignment(
    bool preferBelow,
    _MenuHorizontal horizontal,
  ) {
    final y = preferBelow ? 1.0 : -1.0;
    final x = _alignmentX(horizontal);
    return Alignment(x, y);
  }

  Alignment _followerAlignment(
    bool preferBelow,
    _MenuHorizontal horizontal,
  ) {
    final y = preferBelow ? -1.0 : 1.0;
    final x = _alignmentX(horizontal);
    return Alignment(x, y);
  }

  double _alignmentX(_MenuHorizontal horizontal) {
    switch (horizontal) {
      case _MenuHorizontal.left:
        return -1.0;
      case _MenuHorizontal.center:
        return 0.0;
      case _MenuHorizontal.right:
        return 1.0;
    }
  }

  Offset _anchorOffset(bool preferBelow, _MenuHorizontal horizontal) {
    final dy = preferBelow ? 8.0 : -8.0;
    final dx = switch (horizontal) {
      _MenuHorizontal.left => 12.0,
      _MenuHorizontal.center => 0.0,
      _MenuHorizontal.right => -12.0,
    };
    return Offset(dx, dy);
  }
}

enum _MenuHorizontal { left, center, right }
