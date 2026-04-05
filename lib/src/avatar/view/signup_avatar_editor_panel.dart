// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:typed_data';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/avatar/bloc/avatar_editor_cubit.dart';
import 'package:axichat/src/avatar/avatar_editor_mode.dart';
import 'package:axichat/src/avatar/view/signup_avatar_preview.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SignupAvatarEditorPanel extends StatefulWidget {
  const SignupAvatarEditorPanel({
    super.key,
    required this.mode,
    required this.avatarBytes,
    required this.onShuffle,
    required this.onUpload,
    required this.canShuffleBackground,
    required this.animationDuration,
    required this.showRotationTimer,
    this.rotationStartedAt,
    required this.rotationDuration,
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
  });

  final AvatarEditorMode mode;
  final Uint8List? avatarBytes;
  final Future<void> Function() onShuffle;
  final Future<void> Function() onUpload;
  final bool canShuffleBackground;
  final Duration animationDuration;
  final bool showRotationTimer;
  final DateTime? rotationStartedAt;
  final Duration rotationDuration;
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
        ],
      );
    }

    final allowBackgroundShuffle =
        widget.canShuffleBackground && widget.onShuffleBackground != null;
    final allowUseAction =
        widget.useActionEnabled && !busy && widget.onUseCurrent != null;
    final resolvedPreviewBytes = widget.avatarBytes?.isNotEmpty == true
        ? widget.avatarBytes
        : (_lastPreviewBytes?.isNotEmpty == true ? _lastPreviewBytes : null);
    final previewSize = sizing.iconButtonTapTarget * 1.5;
    final buttonWidthBehavior = AxiButtonWidth.expand;
    Widget preview = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.s,
      children: [
        Align(
          alignment: Alignment.center,
          child: SignupAvatarPreview(
            bytes: resolvedPreviewBytes,
            displayLabel: 'avatar@axichat',
            size: previewSize,
            animationDuration: animationDuration,
            rotationDuration: widget.rotationDuration,
            rotationStartedAt: widget.rotationStartedAt,
            showRotationTimer: widget.showRotationTimer,
            transitionKey: _previewVersion,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: avatarActionSpacing,
          children: [
            AxiButton.primary(
              size: AxiButtonSize.sm,
              widthBehavior: buttonWidthBehavior,
              onPressed: allowUseAction ? widget.onUseCurrent : null,
              leading: Icon(LucideIcons.check, size: avatarActionIconSize),
              child: Text(
                l10n.commonSelect,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            AxiButton.secondary(
              size: AxiButtonSize.sm,
              widthBehavior: buttonWidthBehavior,
              loading: _shuffling,
              onPressed: busy ? null : _handleShuffle,
              leading: Icon(LucideIcons.refreshCw, size: avatarActionIconSize),
              child: Text(
                l10n.signupAvatarShuffle,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            AxiButton.secondary(
              size: AxiButtonSize.sm,
              widthBehavior: buttonWidthBehavior,
              loading: _shufflingBackground,
              onPressed: busy || !allowBackgroundShuffle
                  ? null
                  : () async {
                      await _handleShuffleBackground();
                    },
              leading: Icon(LucideIcons.palette, size: avatarActionIconSize),
              child: Text(
                l10n.signupAvatarBackgroundColor,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            AxiButton.outline(
              size: AxiButtonSize.sm,
              widthBehavior: buttonWidthBehavior,
              onPressed: busy
                  ? null
                  : () async {
                      await widget.onUpload();
                    },
              leading: Icon(LucideIcons.upload, size: avatarActionIconSize),
              child: Text(
                l10n.signupAvatarUploadImage,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
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
