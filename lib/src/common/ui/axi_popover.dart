// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:ui';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/fade_scale_effect.dart';
import 'package:axichat/src/common/ui/axi_surface_scope.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiPopover extends StatefulWidget {
  const AxiPopover({
    super.key,
    required this.child,
    required this.popover,
    this.controller,
    this.visible,
    this.closeOnTapOutside = true,
    this.focusNode,
    this.anchor,
    this.shadows,
    this.padding,
    this.decoration,
    this.filter,
    this.groupId,
    this.areaGroupId,
    this.useSameGroupIdForChild = true,
  });

  final WidgetBuilder popover;
  final Widget child;
  final ShadPopoverController? controller;
  final bool? visible;
  final bool closeOnTapOutside;
  final FocusNode? focusNode;
  final ShadAnchorBase? anchor;
  final List<BoxShadow>? shadows;
  final EdgeInsetsGeometry? padding;
  final ShadDecoration? decoration;
  final ImageFilter? filter;
  final Object? groupId;
  final Object? areaGroupId;
  final bool useSameGroupIdForChild;

  @override
  State<AxiPopover> createState() => _AxiPopoverState();
}

final class _AxiPopoverState extends State<AxiPopover> {
  final Object _surfaceOwner = Object();
  AxiSurfaceController? _registeredSurfaceController;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_handleControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSurfaceRegistration();
  }

  @override
  void didUpdateWidget(covariant AxiPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      widget.controller?.addListener(_handleControllerChanged);
    }
    _syncSurfaceRegistration();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerChanged);
    _registeredSurfaceController?.unregisterSurface(_surfaceOwner);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }
    _syncSurfaceRegistration();
    setState(() {});
  }

  void _syncSurfaceRegistration() {
    final controller = widget.controller;
    final surfaceController = AxiSurfaceScope.maybeControllerOf(context);
    if (_registeredSurfaceController != null &&
        _registeredSurfaceController != surfaceController) {
      _registeredSurfaceController!.unregisterSurface(_surfaceOwner);
      _registeredSurfaceController = null;
    }
    final shouldRegister =
        controller != null && controller.isOpen && surfaceController != null;
    if (!shouldRegister) {
      _registeredSurfaceController?.unregisterSurface(_surfaceOwner);
      _registeredSurfaceController = null;
      return;
    }
    surfaceController.registerSurface(
      owner: _surfaceOwner,
      onDismiss: controller.hide,
    );
    _registeredSurfaceController = surfaceController;
  }

  @override
  Widget build(BuildContext context) {
    final effects = fadeScaleEffectsFor(context);
    final bool shouldWrapSurface =
        widget.padding == null &&
        widget.decoration == null &&
        widget.shadows == null;
    Widget resolvedPopoverBuilder(BuildContext popoverContext) {
      final Widget built = widget.popover(popoverContext);
      if (!shouldWrapSurface) {
        return built;
      }
      return AxiModalSurface(
        backgroundColor: context.colorScheme.popover,
        borderColor: context.colorScheme.border,
        padding: EdgeInsets.all(context.spacing.m),
        child: built,
      );
    }

    final popoverWidget = ShadPopover(
      popover: resolvedPopoverBuilder,
      controller: widget.controller,
      visible: widget.visible,
      closeOnTapOutside: widget.closeOnTapOutside,
      focusNode: widget.focusNode,
      anchor: widget.anchor,
      effects: effects,
      shadows: shouldWrapSurface ? const <BoxShadow>[] : widget.shadows,
      padding: shouldWrapSurface ? EdgeInsets.zero : widget.padding,
      decoration: shouldWrapSurface
          ? const ShadDecoration()
          : widget.decoration,
      filter: widget.filter,
      groupId: widget.groupId,
      areaGroupId: widget.areaGroupId,
      useSameGroupIdForChild: widget.useSameGroupIdForChild,
      child: widget.child,
    );
    final popoverController = widget.controller;
    if (popoverController == null) {
      return popoverWidget;
    }
    if (AxiSurfaceScope.maybeControllerOf(context) != null) {
      return popoverWidget;
    }
    return ListenableBuilder(
      listenable: popoverController,
      builder: (context, _) {
        final canPop = !popoverController.isOpen;
        return PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || canPop) {
              return;
            }
            popoverController.hide();
          },
          child: popoverWidget,
        );
      },
    );
  }
}
