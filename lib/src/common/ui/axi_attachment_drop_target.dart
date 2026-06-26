// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/attachment_drop.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:desktop_drop/desktop_drop.dart' as desktop_drop;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

typedef AxiDroppedAttachmentsCallback =
    Future<void> Function(DroppedAttachmentSourceResult result);

class AxiAttachmentDropTarget extends StatefulWidget {
  const AxiAttachmentDropTarget({
    super.key,
    required this.child,
    required this.onDropped,
    this.enabled = true,
  });

  final Widget child;
  final AxiDroppedAttachmentsCallback? onDropped;
  final bool enabled;

  @override
  State<AxiAttachmentDropTarget> createState() =>
      _AxiAttachmentDropTargetState();
}

class _AxiAttachmentDropTargetState extends State<AxiAttachmentDropTarget> {
  var _dragging = false;
  ModalRoute<dynamic>? _route;

  bool get _dropEnabled =>
      widget.enabled &&
      widget.onDropped != null &&
      axiAttachmentDropTargetPlatformEnabled;

  bool get _dropEnabledForRoute => _dropEnabled && (_route?.isCurrent ?? true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    if (!_dropEnabledForRoute && _dragging) {
      _dragging = false;
    }
  }

  @override
  void didUpdateWidget(covariant AxiAttachmentDropTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dropEnabledForRoute && _dragging) {
      _dragging = false;
    }
  }

  void _setDragging(bool dragging) {
    if (_dragging == dragging || !_dropEnabledForRoute) {
      return;
    }
    setState(() => _dragging = dragging);
  }

  Future<void> _handleDragDone(desktop_drop.DropDoneDetails details) async {
    if (!_dropEnabledForRoute) {
      return;
    }
    _setDragging(false);
    final result = droppedAttachmentSourcesFromItems(details.files);
    if (!mounted) {
      return;
    }
    await widget.onDropped?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _dropEnabledForRoute;
    if (!enabled) {
      return widget.child;
    }
    final colors = context.colorScheme;
    final borderSide = context.borderSide;
    final animationDuration = context.select<SettingsCubit, Duration>(
      (cubit) => cubit.animationDuration,
    );
    final child = AnimatedContainer(
      duration: animationDuration,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        border: Border.all(
          color: _dragging ? colors.primary : Colors.transparent,
          width: borderSide.width,
        ),
        borderRadius: context.radius,
        color: _dragging
            ? colors.primary.withValues(alpha: context.motion.tapHoverAlpha)
            : Colors.transparent,
      ),
      child: widget.child,
    );
    return desktop_drop.DropTarget(
      enable: enabled,
      onDragEntered: (_) => _setDragging(true),
      onDragUpdated: (_) => _setDragging(true),
      onDragExited: (_) => _setDragging(false),
      onDragDone: (details) => unawaited(_handleDragDone(details)),
      child: child,
    );
  }
}

bool get axiAttachmentDropTargetPlatformEnabled {
  if (kIsWeb) {
    return false;
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.linux ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => true,
    TargetPlatform.android ||
    TargetPlatform.fuchsia ||
    TargetPlatform.iOS => false,
  };
}
