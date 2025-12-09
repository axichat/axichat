import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:axichat/src/profile/avatar/avatar_templates.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:shadcn_ui/shadcn_ui.dart';

enum AvatarSource {
  upload,
  template,
}

class AvatarEditorState extends Equatable {
  const AvatarEditorState({
    required this.backgroundColor,
    this.cropRect,
    this.imageWidth,
    this.imageHeight,
    this.source = AvatarSource.template,
    this.sourceBytes,
    this.previewBytes,
    this.template,
    this.draft,
    this.processing = false,
    this.publishing = false,
    this.error,
    this.lastSavedPath,
    this.estimatedBytes,
  });

  final AvatarSource source;
  final Uint8List? sourceBytes;
  final Uint8List? previewBytes;
  final AvatarTemplate? template;
  final AvatarUploadPayload? draft;
  final bool processing;
  final bool publishing;
  final String? error;
  final Rect? cropRect;
  final int? imageWidth;
  final int? imageHeight;
  final Color backgroundColor;
  final String? lastSavedPath;
  final int? estimatedBytes;

  AvatarEditorState copyWith({
    AvatarSource? source,
    Uint8List? sourceBytes,
    Uint8List? previewBytes,
    AvatarTemplate? template,
    AvatarUploadPayload? draft,
    bool? processing,
    bool? publishing,
    String? error,
    Rect? cropRect,
    int? imageWidth,
    int? imageHeight,
    Color? backgroundColor,
    String? lastSavedPath,
    int? estimatedBytes,
    bool clearError = false,
  }) {
    return AvatarEditorState(
      source: source ?? this.source,
      sourceBytes: sourceBytes ?? this.sourceBytes,
      previewBytes: previewBytes ?? this.previewBytes,
      template: template ?? this.template,
      draft: draft ?? this.draft,
      processing: processing ?? this.processing,
      publishing: publishing ?? this.publishing,
      error: clearError ? null : error ?? this.error,
      cropRect: cropRect ?? this.cropRect,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      lastSavedPath: lastSavedPath ?? this.lastSavedPath,
      estimatedBytes: estimatedBytes ?? this.estimatedBytes,
    );
  }

  @override
  List<Object?> get props => [
        source,
        sourceBytes,
        previewBytes,
        template,
        draft?.hash,
        processing,
        publishing,
        error,
        cropRect,
        imageWidth,
        imageHeight,
        backgroundColor,
        lastSavedPath,
        estimatedBytes,
      ];
}

class AvatarEditorCubit extends Cubit<AvatarEditorState> {
  AvatarEditorCubit({
    required XmppService xmppService,
    required List<AvatarTemplate> templates,
    ProfileCubit? profileCubit,
  })  : _xmppService = xmppService,
        _templates = templates,
        _profileCubit = profileCubit,
        super(
          const AvatarEditorState(
            backgroundColor: Colors.transparent,
          ),
        );

  static const minCropSide = 48.0;
  static const _targetSize = 256;
  static const _maxBytes = 64 * 1024;
  static const _minQuality = 55;

  final XmppService _xmppService;
  final ProfileCubit? _profileCubit;
  final List<AvatarTemplate> _templates;
  final List<String> _recentShuffleIds = <String>[];
  final _random = Random();

  img.Image? _decodedImage;
  Timer? _rebuildTimer;

  @override
  Future<void> close() async {
    _rebuildTimer?.cancel();
    return super.close();
  }

  void initialize(ShadColorScheme colors) {
    final initialBackground = state.backgroundColor == Colors.transparent
        ? colors.accent
        : state.backgroundColor;
    emit(state.copyWith(backgroundColor: initialBackground));
    if (state.template == null && _templates.isNotEmpty) {
      unawaited(selectTemplate(_templates.first, colors));
    }
  }

  Future<void> pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null || bytes.isEmpty) {
        emit(state.copyWith(error: 'Could not read that file.'));
        return;
      }
      await _loadFromBytes(bytes);
    } catch (_) {
      emit(
        state.copyWith(
          error: 'Unable to open that image. Please try a different file.',
        ),
      );
    }
  }

  Future<void> selectTemplate(
    AvatarTemplate template,
    ShadColorScheme colors, {
    Color? background,
  }) async {
    emit(
      state.copyWith(
        processing: true,
        source: AvatarSource.template,
        template: template,
        clearError: true,
      ),
    );
    try {
      final selectedBackground = background ?? state.backgroundColor;
      final generated = await template.generator(
        selectedBackground == Colors.transparent
            ? colors.background
            : selectedBackground,
        colors,
      );
      final decoded = img.decodeImage(generated.bytes);
      if (decoded == null) {
        emit(
          state.copyWith(
            processing: false,
            error: 'Unable to build that avatar.',
          ),
        );
        return;
      }
      _decodedImage = decoded;
      emit(
        state.copyWith(
          sourceBytes: generated.bytes,
          imageWidth: decoded.width,
          imageHeight: decoded.height,
          cropRect: _initialCropRect(decoded),
          backgroundColor: selectedBackground,
          clearError: true,
        ),
      );
      await _rebuildDraft();
    } catch (_) {
      emit(
        state.copyWith(
          processing: false,
          error: 'Failed to load that avatar option.',
        ),
      );
    }
  }

  Future<void> setBackgroundColor(
    Color color,
    ShadColorScheme colors,
  ) async {
    emit(state.copyWith(backgroundColor: color));
    if (state.template != null && state.template!.hasAlphaBackground) {
      await selectTemplate(state.template!, colors);
      return;
    }
    if (_decodedImage != null && _decodedImage!.numChannels == 4) {
      await _rebuildDraft();
    }
  }

  Future<void> shuffleTemplate(ShadColorScheme colors) async {
    final template = _pickTemplate();
    if (template == null) return;
    final background = template.hasAlphaBackground
        ? _randomAvatarBackgroundColor(colors)
        : state.backgroundColor == Colors.transparent
            ? colors.accent
            : state.backgroundColor;
    await selectTemplate(
      template,
      colors,
      background: background,
    );
  }

  void updateCropRect(Rect rect) {
    final image = _decodedImage;
    if (image == null) return;
    final clamped =
        _constrainRect(rect, image.width.toDouble(), image.height.toDouble());
    if (state.cropRect == clamped) return;
    emit(state.copyWith(cropRect: clamped));
    _scheduleRebuild();
  }

  void resizeCropRect(double factor) {
    final image = _decodedImage;
    if (image == null) return;
    final clampedFactor = factor.clamp(0.0, 1.0);
    final maxSide = min(image.width.toDouble(), image.height.toDouble());
    final side = minCropSide + (maxSide - minCropSide) * clampedFactor;
    final current = state.cropRect ?? _initialCropRect(image);
    final next = Rect.fromCenter(
      center: current.center,
      width: side,
      height: side,
    );
    final constrained =
        _constrainRect(next, image.width.toDouble(), image.height.toDouble());
    emit(state.copyWith(cropRect: constrained));
    _scheduleRebuild();
  }

  void resetCrop() {
    final image = _decodedImage;
    if (image == null) return;
    final reset = _initialCropRect(image);
    emit(state.copyWith(cropRect: reset));
    _scheduleRebuild();
  }

  Future<void> publish() async {
    final draft = state.draft;
    if (draft == null) {
      emit(state.copyWith(error: 'Pick or build an avatar first.'));
      return;
    }
    emit(state.copyWith(publishing: true, clearError: true));
    try {
      final result = await _xmppService.publishAvatar(draft);
      _profileCubit?.updateAvatar(
        path: result.path,
        hash: result.hash,
      );
      emit(
        state.copyWith(
          publishing: false,
          lastSavedPath: result.path,
          clearError: true,
        ),
      );
    } on XmppAvatarException {
      emit(
        state.copyWith(
          publishing: false,
          error: 'Could not publish avatar. Please try again.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          publishing: false,
          error: 'Unexpected error while uploading avatar.',
        ),
      );
    }
  }

  Future<void> _loadFromBytes(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      emit(state.copyWith(error: 'That file is not a valid image.'));
      return;
    }
    _decodedImage = decoded;
    emit(
      state.copyWith(
        source: AvatarSource.upload,
        sourceBytes: bytes,
        template: null,
        imageWidth: decoded.width,
        imageHeight: decoded.height,
        cropRect: _initialCropRect(decoded),
        clearError: true,
      ),
    );
    await _rebuildDraft();
  }

  void _scheduleRebuild() {
    _rebuildTimer?.cancel();
    _rebuildTimer = Timer(
      const Duration(milliseconds: 140),
      _rebuildDraft,
    );
  }

  Future<void> _rebuildDraft() async {
    final source = _decodedImage;
    if (source == null) return;
    emit(state.copyWith(processing: true, clearError: true));
    await Future<void>.delayed(Duration.zero);
    try {
      final draft = _processImage(source);
      emit(
        state.copyWith(
          processing: false,
          draft: draft,
          previewBytes: draft.bytes,
          estimatedBytes: draft.bytes.length,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          processing: false,
          error: 'Unable to process that image.',
        ),
      );
    }
  }

  AvatarUploadPayload _processImage(img.Image image) {
    final safeCrop = _constrainRect(
      state.cropRect ?? _initialCropRect(image),
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final left = safeCrop.left.round();
    final top = safeCrop.top.round();
    final width = min(safeCrop.width.round(), image.width - left);
    final height = min(safeCrop.height.round(), image.height - top);
    final cropped = img.copyCrop(
      image,
      x: left,
      y: top,
      width: width,
      height: height,
    );
    final flattened = _flattenIfNeeded(cropped);
    final resized = img.copyResize(
      flattened,
      width: _targetSize,
      height: _targetSize,
      interpolation: img.Interpolation.cubic,
    );
    final encoded = _encode(resized);
    final hash = sha1.convert(encoded.bytes).toString();
    return AvatarUploadPayload(
      bytes: encoded.bytes,
      mimeType: encoded.mimeType,
      width: resized.width,
      height: resized.height,
      hash: hash,
    );
  }

  Rect _initialCropRect(img.Image image) {
    final minSide = min(image.width, image.height).toDouble();
    final side = max(minCropSide, minSide * 0.8);
    final left = (image.width - side) / 2;
    final top = (image.height - side) / 2;
    return _constrainRect(
      Rect.fromLTWH(left, top, side, side),
      image.width.toDouble(),
      image.height.toDouble(),
    );
  }

  Rect _constrainRect(Rect rect, double width, double height) {
    final availableSide = min(width, height);
    final desiredSide =
        min(rect.width, rect.height).clamp(minCropSide, availableSide);
    final maxLeft = width - desiredSide;
    final maxTop = height - desiredSide;
    final left = rect.left.clamp(0.0, maxLeft);
    final top = rect.top.clamp(0.0, maxTop);
    return Rect.fromLTWH(left, top, desiredSide, desiredSide);
  }

  img.Image _flattenIfNeeded(img.Image image) {
    final backgroundAlpha = _channelToByte(state.backgroundColor.a);
    final shouldFlatten = (state.template?.hasAlphaBackground ?? false) ||
        (backgroundAlpha > 0 && image.numChannels == 4);
    if (!shouldFlatten) return image;
    final background = img.Image(
      width: image.width,
      height: image.height,
      numChannels: 4,
    );
    img.fill(background, color: _color(state.backgroundColor));
    img.compositeImage(background, image);
    return background;
  }

  _EncodedAvatar _encode(img.Image image) {
    if (image.numChannels == 4) {
      final pngBytes = Uint8List.fromList(
        img.encodePng(image, level: 4),
      );
      if (pngBytes.length <= _maxBytes) {
        return _EncodedAvatar(
          bytes: pngBytes,
          mimeType: 'image/png',
        );
      }
    }
    var quality = 90;
    Uint8List jpgBytes = Uint8List.fromList(
      img.encodeJpg(image, quality: quality),
    );
    while (jpgBytes.length > _maxBytes && quality > _minQuality) {
      quality -= 5;
      jpgBytes = Uint8List.fromList(
        img.encodeJpg(image, quality: quality),
      );
    }
    return _EncodedAvatar(
      bytes: jpgBytes,
      mimeType: 'image/jpeg',
    );
  }

  AvatarTemplate? _pickTemplate() {
    final abstract = _templates
        .where(
            (template) => template.category == AvatarTemplateCategory.abstract)
        .toList();
    final nonAbstract = _templates
        .where(
            (template) => template.category != AvatarTemplateCategory.abstract)
        .toList();
    final hasAbstract = abstract.isNotEmpty;
    final hasNonAbstract = nonAbstract.isNotEmpty;
    if (!hasAbstract && !hasNonAbstract) return null;
    final useAbstract = !hasNonAbstract ||
        (hasAbstract && hasNonAbstract && _random.nextBool());
    final pool = useAbstract ? abstract : nonAbstract;
    final available = pool
        .where((template) => !_recentShuffleIds.contains(template.id))
        .toList();
    final candidates = available.isEmpty ? pool : available;
    final selection = candidates[_random.nextInt(candidates.length)];
    _recentShuffleIds.add(selection.id);
    if (_recentShuffleIds.length > 12) {
      _recentShuffleIds.removeAt(0);
    }
    return selection;
  }

  Color _randomAvatarBackgroundColor(ShadColorScheme colors) {
    final hue = _random.nextDouble() * 360.0;
    final saturation = 0.65 + _random.nextDouble() * 0.35;
    final lightness = 0.45 + _random.nextDouble() * 0.15;
    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }
}

class _EncodedAvatar {
  _EncodedAvatar({
    required this.bytes,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String mimeType;
}

img.Color _color(Color color) => img.ColorInt32.rgba(
      _channelToByte(color.r),
      _channelToByte(color.g),
      _channelToByte(color.b),
      _channelToByte(color.a),
    );

int _channelToByte(double channel) => (channel * 255.0).round().clamp(0, 255);
