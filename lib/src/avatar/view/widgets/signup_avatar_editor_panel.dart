import 'dart:async';
import 'dart:typed_data';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/avatar/bloc/signup_avatar_cubit.dart';
import 'package:axichat/src/avatar/view/widgets/avatar_cropper.dart';
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
    this.onShuffleBackground,
    this.cropBytes,
    this.cropRect,
    this.imageWidth,
    this.imageHeight,
    this.onCropChanged,
    this.onCropReset,
  });

  final SignupAvatarEditorMode mode;
  final Uint8List? avatarBytes;
  final Future<void> Function() onShuffle;
  final Future<void> Function() onUpload;
  final bool canShuffleBackground;
  final Future<void> Function()? onShuffleBackground;
  final Uint8List? cropBytes;
  final Rect? cropRect;
  final double? imageWidth;
  final double? imageHeight;
  final ValueChanged<Rect>? onCropChanged;
  final VoidCallback? onCropReset;

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
  Rect? _pendingCropRect;
  bool _cropChangeScheduled = false;
  bool _fallbackAvatarPrecached = false;

  @override
  void didUpdateWidget(covariant SignupAvatarEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.avatarBytes, widget.avatarBytes)) {
      _previewVersion++;
      _lastPreviewBytes = widget.avatarBytes;
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
    _pendingCropRect = rect;
    if (_cropChangeScheduled) return;
    _cropChangeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cropChangeScheduled = false;
      final next = _pendingCropRect;
      _pendingCropRect = null;
      if (!mounted || next == null) return;
      widget.onCropChanged?.call(next);
      setState(() => _localCropRect = next);
    });
  }

  void _handleCropReset() {
    final rect = widget.cropRect;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onCropReset?.call();
      setState(() => _localCropRect = rect);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    const avatarActionSpacing = 8.0;
    final showCrop = widget.mode == SignupAvatarEditorMode.cropOnly;
    final busy = _shuffling || _shufflingBackground;
    final cropBytes = showCrop ? widget.cropBytes ?? _lastPreviewBytes : null;
    final imageWidth = showCrop ? widget.imageWidth : null;
    final imageHeight = showCrop ? widget.imageHeight : null;
    final canEditCrop = showCrop &&
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
      cropper = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12.0,
        children: [
          Text(
            'Crop & focus',
            style: context.textTheme.small.copyWith(color: colors.foreground),
          ),
          Text(
            'Drag or resize the square to frame your avatar. Reset to center the selection.',
            style: context.textTheme.small.copyWith(
              color: colors.mutedForeground,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: AvatarCropper(
                bytes: safeBytes,
                imageWidth: safeImageWidth,
                imageHeight: safeImageHeight,
                cropRect: _localCropRect ??
                    widget.cropRect ??
                    AvatarCropper.fallbackCropRect(
                      imageWidth: safeImageWidth,
                      imageHeight: safeImageHeight,
                      minCropSide: SignupAvatarCubit.minCropSide,
                    ),
                onCropChanged: _scheduleCropChange,
                onCropReset: _handleCropReset,
                colors: colors,
                borderRadius: context.radius,
                minCropSide: SignupAvatarCubit.minCropSide,
              ),
            ),
          ),
          Text(
            'Only the area inside the circle will appear in the final avatar.',
            style: context.textTheme.small.copyWith(
              color: colors.mutedForeground,
            ),
          ),
        ],
      );
    }

    final allowBackgroundShuffle =
        widget.canShuffleBackground && widget.onShuffleBackground != null;

    final previewKey = ValueKey(_previewVersion);
    final previewBytes = widget.avatarBytes;
    final hasPreviewBytes = previewBytes != null && previewBytes.isNotEmpty;
    Widget preview = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 12.0,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: hasPreviewBytes
              ? AxiAvatar(
                  key: previewKey,
                  jid: 'avatar@axichat',
                  size: 96,
                  subscription: Subscription.none,
                  presence: null,
                  avatarBytes: previewBytes,
                )
              : SizedBox.square(
                  key: previewKey,
                  dimension: 96,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.border),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        _fallbackSignupAvatarAssetPath,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
        ),
        Text(
          l10n.signupAvatarMenuDescription,
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
            ShadButton(
              onPressed: busy ? null : _handleShuffle,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8.0,
                children: [
                  if (_shuffling)
                    SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.primaryForeground,
                        ),
                        backgroundColor:
                            colors.primaryForeground.withValues(alpha: 0.2),
                      ),
                    )
                  else
                    const Icon(LucideIcons.refreshCw, size: 20),
                  Text(l10n.signupAvatarShuffle),
                ],
              ),
            ).withTapBounce(),
            ShadButton.secondary(
              onPressed: busy || !allowBackgroundShuffle
                  ? null
                  : () => unawaited(_handleShuffleBackground()),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8.0,
                children: [
                  if (_shufflingBackground)
                    SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.secondaryForeground,
                        ),
                        backgroundColor:
                            colors.secondaryForeground.withValues(alpha: 0.2),
                      ),
                    )
                  else
                    const Icon(LucideIcons.palette, size: 20),
                  Text(l10n.signupAvatarBackgroundColor),
                ],
              ),
            ).withTapBounce(),
            ShadButton.outline(
              onPressed: busy ? null : () => unawaited(widget.onUpload()),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8.0,
                children: [
                  const Icon(LucideIcons.upload),
                  Text(l10n.signupAvatarUploadImage),
                ],
              ),
            ).withTapBounce(),
          ],
        ),
      ],
    );

    final previewAndCrop = showCrop && cropper != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12.0,
            children: [
              preview,
              cropper,
            ],
          )
        : preview;

    return ShadCard(
      padding: const EdgeInsets.all(12.0),
      child: previewAndCrop,
    );
  }
}
