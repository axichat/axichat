// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/attachment_drop.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:desktop_drop/desktop_drop.dart' as desktop_drop;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show LucideIcons;

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
    final animationDuration = context.select<SettingsCubit, Duration>(
      (cubit) => cubit.animationDuration,
    );
    final radius = context.radius;
    final child = Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: animationDuration,
              curve: Curves.easeOutCubic,
              opacity: _dragging ? 1.0 : 0.0,
              child: DecoratedBox(
                key: const ValueKey<String>('axi-attachment-drop-overlay'),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  color: colors.primary.withValues(alpha: 0.16),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.upload,
                        color: colors.primary,
                        size: context.sizing.iconButtonTapTarget,
                      ),
                      SizedBox(height: context.spacing.s),
                      Text(
                        context.l10n.chatComposerDropFiles,
                        style: context.textTheme.large.copyWith(
                          color: colors.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
