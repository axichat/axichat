// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:typed_data';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/avatar/view/signup_avatar_preview.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SignupAvatarSelector extends StatefulWidget {
  const SignupAvatarSelector({
    super.key,
    required this.bytes,
    required this.username,
    required this.processing,
    required this.showRotationTimer,
    this.rotationStartedAt,
    required this.animationDuration,
    required this.rotationDuration,
    required this.onTap,
  });

  final Uint8List? bytes;
  final String username;
  final bool processing;
  final bool showRotationTimer;
  final DateTime? rotationStartedAt;
  final Duration animationDuration;
  final Duration rotationDuration;
  final VoidCallback onTap;

  @override
  State<SignupAvatarSelector> createState() => _SignupAvatarSelectorState();
}

class _SignupAvatarSelectorState extends State<SignupAvatarSelector> {
  _HoverState _hoverState = _HoverState.idle;
  int _previewVersion = 0;
  Uint8List? _lastBytes;

  @override
  void didUpdateWidget(covariant SignupAvatarSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextBytes = widget.bytes;
    if (nextBytes != null &&
        nextBytes.isNotEmpty &&
        !identical(nextBytes, _lastBytes)) {
      _previewVersion++;
      _lastBytes = nextBytes;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final motion = context.motion;
    final sizing = context.sizing;
    final animationDuration = widget.animationDuration;
    final avatarSize = sizing.iconButtonTapTarget;
    final overlayShape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(context.radii.squircle),
      side: context.borderSide,
    );
    final displayJid = widget.username.isEmpty
        ? 'avatar@axichat'
        : '${widget.username}@preview';
    final overlayVisible =
        _hoverState == _HoverState.hovered || widget.processing;
    final resolvedBytes = widget.bytes?.isNotEmpty == true
        ? widget.bytes
        : (_lastBytes?.isNotEmpty == true ? _lastBytes : null);
    return AxiTapBounce(
      enabled: true,
      child: Material(
        color: colors.background.withValues(alpha: 0),
        shape: overlayShape,
        clipBehavior: Clip.antiAlias,
        child: ShadFocusable(
          canRequestFocus: true,
          onFocusChange: (focused) {
            if (!mounted) return;
            setState(
              () => _hoverState = focused
                  ? _HoverState.hovered
                  : _HoverState.idle,
            );
          },
          builder: (context, focused, child) =>
              child ?? const SizedBox.shrink(),
          child: ShadGestureDetector(
            cursor: SystemMouseCursors.click,
            hoverStrategies: ShadTheme.of(context).hoverStrategies,
            onHoverChange: (value) => setState(
              () =>
                  _hoverState = value ? _HoverState.hovered : _HoverState.idle,
            ),
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _hoverState = _HoverState.hovered),
            onTapUp: (_) => setState(() => _hoverState = _HoverState.idle),
            onTapCancel: () => setState(() => _hoverState = _HoverState.idle),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SignupAvatarPreview(
                  bytes: resolvedBytes,
                  displayLabel: displayJid,
                  size: avatarSize,
                  animationDuration: animationDuration,
                  rotationDuration: widget.rotationDuration,
                  rotationStartedAt: widget.rotationStartedAt,
                  showRotationTimer:
                      widget.showRotationTimer && !widget.processing,
                  transitionKey: _previewVersion,
                ),
                AnimatedOpacity(
                  opacity: overlayVisible ? motion.tapFocusAlpha : 0.0,
                  duration: animationDuration,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: colors.background.withValues(
                        alpha: motion.tapFocusAlpha,
                      ),
                      shape: overlayShape,
                    ),
                    child: SizedBox(
                      width: avatarSize,
                      height: avatarSize,
                      child: widget.processing
                          ? Center(
                              child: SizedBox(
                                width: sizing.progressIndicatorSize,
                                height: sizing.progressIndicatorSize,
                                child: AxiProgressIndicator(
                                  color: colors.foreground,
                                ),
                              ),
                            )
                          : Icon(
                              LucideIcons.pencil,
                              color: colors.foreground,
                              size: sizing.iconButtonIconSize,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _HoverState { idle, hovered }
