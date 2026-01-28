// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:typed_data';

import 'package:animations/animations.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const String _fallbackSignupAvatarAssetPath =
    'assets/images/avatars/abstract/abstract1.png';

class SignupAvatarSelector extends StatefulWidget {
  const SignupAvatarSelector({
    super.key,
    required this.bytes,
    required this.username,
    required this.processing,
    required this.onTap,
  });

  final Uint8List? bytes;
  final String username;
  final bool processing;
  final VoidCallback onTap;

  @override
  State<SignupAvatarSelector> createState() => _SignupAvatarSelectorState();
}

class _SignupAvatarSelectorState extends State<SignupAvatarSelector> {
  _HoverState _hoverState = _HoverState.idle;
  int _previewVersion = 0;
  Uint8List? _lastBytes;
  bool _fallbackAvatarPrecached = false;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fallbackAvatarPrecached) return;
    _fallbackAvatarPrecached = true;
    precacheImage(const AssetImage(_fallbackSignupAvatarAssetPath), context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final motion = context.motion;
    final sizing = context.sizing;
    final animationDuration = context.watch<SettingsCubit>().animationDuration;
    final avatarSize = sizing.iconButtonTapTarget;
    final overlayShape = RoundedSuperellipseBorder(
      borderRadius: context.radius,
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
    final hasBytes = resolvedBytes != null;
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
              () => _hoverState =
                  focused ? _HoverState.hovered : _HoverState.idle,
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
                SizedBox.square(
                  dimension: avatarSize,
                  child: PageTransitionSwitcher(
                    duration: animationDuration,
                    transitionBuilder:
                        (child, primaryAnimation, secondaryAnimation) =>
                            FadeTransition(
                      opacity: primaryAnimation,
                      child: FadeTransition(
                        opacity: ReverseAnimation(secondaryAnimation),
                        child: child,
                      ),
                    ),
                    child: hasBytes
                        ? AxiAvatar(
                            key: ValueKey(_previewVersion),
                            jid: displayJid,
                            size: avatarSize,
                            shape: AxiAvatarShape.squircle,
                            subscription: Subscription.none,
                            presence: null,
                            avatarBytes: resolvedBytes,
                          )
                        : SizedBox.square(
                            key: ValueKey(_previewVersion),
                            dimension: avatarSize,
                            child: DecoratedBox(
                              decoration: ShapeDecoration(
                                color: colors.card,
                                shape: overlayShape,
                              ),
                              child: ClipPath(
                                clipper: ShapeBorderClipper(
                                  shape: overlayShape,
                                ),
                                child: Image.asset(
                                  _fallbackSignupAvatarAssetPath,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                  ),
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
                                    color: colors.foreground),
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
