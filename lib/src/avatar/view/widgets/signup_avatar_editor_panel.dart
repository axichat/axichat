// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:typed_data';

import 'package:animations/animations.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/avatar/avatar_editor_mode.dart';
import 'package:axichat/src/avatar/bloc/avatar_editor_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const String _fallbackSignupAvatarAssetPath =
    'assets/images/avatars/abstract/abstract1.png';

class SignupAvatarEditorPanel extends StatefulWidget {
  const SignupAvatarEditorPanel({
    super.key,
    required this.mode,
    required this.avatarBytes,
    required this.onShuffle,
    required this.onUpload,
    required this.canShuffleBackground,
    required this.animationDuration,
    required this.hasUserSelectedAvatar,
    this.onUseCurrent,
    this.useActionEnabled = false,
    this.onShuffleBackground,
    this.cropBytes,
    this.cropRect,
    this.imageWidth,
    this.imageHeight,
    this.onCropChanged,
    this.onCropReset,
    this.onCropCommitted,
    this.descriptionText,
  });

  final AvatarEditorMode mode;
  final Uint8List? avatarBytes;
  final Future<void> Function() onShuffle;
  final Future<void> Function() onUpload;
  final bool canShuffleBackground;
  final Duration animationDuration;
  final bool hasUserSelectedAvatar;
  final Future<void> Function()? onShuffleBackground;
  final VoidCallback? onUseCurrent;
  final bool useActionEnabled;
  final Uint8List? cropBytes;
  final Rect? cropRect;
  final double? imageWidth;
  final double? imageHeight;
  final ValueChanged<Rect>? onCropChanged;
  final VoidCallback? onCropReset;
  final ValueChanged<Rect>? onCropCommitted;
  final String? descriptionText;

  @override
  State<SignupAvatarEditorPanel> createState() =>
      _SignupAvatarEditorPanelState();
}

class _SignupAvatarEditorPanelState extends State<SignupAvatarEditorPanel> {
  bool _shuffling = false;
  bool _shufflingBackground = false;
  int _previewVersion = 0;
  Uint8List? _lastPreviewBytes;
  Rect? _localCropRect;
  bool _fallbackAvatarPrecached = false;

  @override
  void didUpdateWidget(covariant SignupAvatarEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextBytes = widget.avatarBytes;
    if (nextBytes != null &&
        nextBytes.isNotEmpty &&
        !identical(nextBytes, _lastPreviewBytes)) {
      _previewVersion++;
      _lastPreviewBytes = nextBytes;
    }
    if (oldWidget.imageWidth != widget.imageWidth ||
        oldWidget.imageHeight != widget.imageHeight) {
      _localCropRect = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fallbackAvatarPrecached) return;
    _fallbackAvatarPrecached = true;
    precacheImage(const AssetImage(_fallbackSignupAvatarAssetPath), context);
  }

  Future<void> _handleShuffle() async {
    if (_shuffling) return;
    setState(() => _shuffling = true);
    try {
      await widget.onShuffle();
    } finally {
      if (mounted) {
        setState(() => _shuffling = false);
      }
    }
  }

  Future<void> _handleShuffleBackground() async {
    final shuffleBackground = widget.onShuffleBackground;
    if (_shufflingBackground || shuffleBackground == null) {
      return;
    }
    setState(() => _shufflingBackground = true);
    try {
      await shuffleBackground();
    } finally {
      if (mounted) {
        setState(() => _shufflingBackground = false);
      }
    }
  }

  void _scheduleCropChange(Rect rect) {
    if (!mounted) return;
    widget.onCropChanged?.call(rect);
    setState(() => _localCropRect = rect);
  }

  void _handleCropReset() {
    final rect = widget.cropRect;
    if (!mounted) return;
    widget.onCropReset?.call();
    setState(() => _localCropRect = rect);
  }

  void _handleCropCommit(Rect rect) {
    widget.onCropCommitted?.call(rect);
    if (!mounted) return;
    setState(() => _localCropRect = rect);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final animationDuration = widget.animationDuration;
    final avatarActionSpacing = spacing.s;
    final avatarActionIconSize = sizing.iconButtonIconSize;
    final showCrop = widget.mode == AvatarEditorMode.cropOnly;
    final busy = _shuffling || _shufflingBackground;
    final cropBytes = showCrop ? widget.cropBytes ?? _lastPreviewBytes : null;
    final imageWidth = showCrop ? widget.imageWidth : null;
    final imageHeight = showCrop ? widget.imageHeight : null;
    final canEditCrop =
        showCrop &&
        cropBytes != null &&
        imageWidth != null &&
        imageHeight != null &&
        imageWidth > 0 &&
        imageHeight > 0 &&
        widget.onCropChanged != null &&
        widget.onCropReset != null;

    Widget? cropper;
    if (canEditCrop) {
      final Uint8List safeBytes = cropBytes;
      final double safeImageWidth = imageWidth;
      final double safeImageHeight = imageHeight;
      final onCropCommitted = widget.onCropCommitted;
      final cropFallback = AxiImageCropper.fallbackCropRect(
        imageWidth: safeImageWidth,
        imageHeight: safeImageHeight,
        minCropSide: AvatarEditorCubit.minCropSide,
      );
      cropper = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.s,
        children: [
          Text(
            l10n.signupAvatarCropTitle,
            style: context.textTheme.small.copyWith(color: colors.foreground),
          ),
          Text(
            l10n.avatarCropDescription,
            style: context.textTheme.small.copyWith(
              color: colors.mutedForeground,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(spacing.s),
            child: Center(
              child: AxiImageCropper(
                bytes: safeBytes,
                imageWidth: safeImageWidth,
                imageHeight: safeImageHeight,
                cropRect: _localCropRect ?? widget.cropRect ?? cropFallback,
                onCropChanged: _scheduleCropChange,
                onCropReset: _handleCropReset,
                onCropCommitted: onCropCommitted == null
                    ? null
                    : _handleCropCommit,
                minCropSide: AvatarEditorCubit.minCropSide,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: AxiButton.secondary(
              onPressed: onCropCommitted == null
                  ? null
                  : () => _handleCropCommit(
                      _localCropRect ?? widget.cropRect ?? cropFallback,
                    ),
              child: Text(l10n.commonDone),
            ),
          ),
          Text(
            l10n.signupAvatarCropHint,
            style: context.textTheme.small.copyWith(
              color: colors.mutedForeground,
            ),
          ),
        ],
      );
    }

    final allowBackgroundShuffle =
        widget.canShuffleBackground && widget.onShuffleBackground != null;
    final showBackgroundShuffle = allowBackgroundShuffle;
    final allowUseAction =
        widget.useActionEnabled && !busy && widget.onUseCurrent != null;
    final useLabel = l10n.avatarUseThis;
    const IconData useIcon = LucideIcons.check;

    final previewKey = ValueKey(_previewVersion);
    final resolvedPreviewBytes = widget.avatarBytes?.isNotEmpty == true
        ? widget.avatarBytes
        : (_lastPreviewBytes?.isNotEmpty == true ? _lastPreviewBytes : null);
    final hasPreviewBytes = resolvedPreviewBytes != null;
    Widget preview = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: spacing.s,
      children: [
        PageTransitionSwitcher(
          duration: animationDuration,
          transitionBuilder: (child, primaryAnimation, secondaryAnimation) =>
              FadeTransition(
                opacity: primaryAnimation,
                child: FadeTransition(
                  opacity: ReverseAnimation(secondaryAnimation),
                  child: child,
                ),
              ),
          child: hasPreviewBytes
              ? AxiAvatar(
                  key: previewKey,
                  jid: 'avatar@axichat',
                  size: 96,
                  subscription: Subscription.none,
                  presence: null,
                  avatarBytes: resolvedPreviewBytes,
                )
              : SizedBox.square(
                  key: previewKey,
                  dimension: 96,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: colors.card,
                      shape: SquircleBorder(
                        cornerRadius: context.radii.squircle,
                        side: context.borderSide,
                      ),
                    ),
                    child: ClipPath(
                      clipper: ShapeBorderClipper(
                        shape: SquircleBorder(
                          cornerRadius: context.radii.squircle,
                        ),
                      ),
                      child: Image.asset(
                        _fallbackSignupAvatarAssetPath,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
        ),
        Text(
          widget.descriptionText ?? l10n.signupAvatarMenuDescription,
          style: context.textTheme.small.copyWith(
            color: colors.mutedForeground,
          ),
          textAlign: TextAlign.center,
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: avatarActionSpacing,
          runSpacing: avatarActionSpacing,
          children: [
            AxiButton.secondary(
              onPressed: allowUseAction ? widget.onUseCurrent : null,
              leading: Icon(useIcon, size: avatarActionIconSize),
              child: Text(useLabel),
            ),
            AxiButton.primary(
              loading: _shuffling,
              onPressed: busy ? null : _handleShuffle,
              leading: Icon(LucideIcons.refreshCw, size: avatarActionIconSize),
              child: Text(l10n.signupAvatarShuffle),
            ),
            if (showBackgroundShuffle)
              AxiButton.secondary(
                loading: _shufflingBackground,
                onPressed: busy
                    ? null
                    : () async {
                        await _handleShuffleBackground();
                      },
                leading: Icon(LucideIcons.palette, size: avatarActionIconSize),
                child: Text(l10n.signupAvatarBackgroundColor),
              ),
            AxiButton.outline(
              onPressed: busy
                  ? null
                  : () async {
                      await widget.onUpload();
                    },
              leading: Icon(LucideIcons.upload, size: avatarActionIconSize),
              child: Text(l10n.signupAvatarUploadImage),
            ),
          ],
        ),
      ],
    );

    final previewAndCrop = showCrop && cropper != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: spacing.s,
            children: [preview, cropper],
          )
        : preview;

    return ShadCard(padding: EdgeInsets.all(spacing.m), child: previewAndCrop);
  }
}
