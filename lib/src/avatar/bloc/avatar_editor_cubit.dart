import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:axichat/src/avatar/avatar_image_utils.dart';
import 'package:axichat/src/avatar/avatar_templates.dart';
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
  // All non-abstract templates ship with transparent backgrounds, so keep a single inset.
  static const avatarInsetFraction = 0.10;
  static const transparentAvatarInsetFraction = 0.10;
  static const _targetSize = 256;
  static const _maxBytes = 64 * 1024;
  static const _minQuality = 55;
  static const _qualityStep = 5;

  final XmppService _xmppService;
  final ProfileCubit? _profileCubit;
  final List<AvatarTemplate> _templates;
  final List<String> _recentShuffleIds = <String>[];
  final List<AvatarTemplate> _abstractShuffleBag = <AvatarTemplate>[];
  final List<AvatarTemplate> _nonAbstractShuffleBag = <AvatarTemplate>[];
  static const _shuffleHistoryLimit = 12;
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
    unawaited(_loadInitialAvatar());
  }

  Future<void> _loadInitialAvatar() async {
    final avatarPath = _profileCubit?.state.avatarPath?.trim();
    if (avatarPath == null || avatarPath.isEmpty) {
      return;
    }
    try {
      final bytes = await _xmppService.loadAvatarBytes(avatarPath);
      if (bytes == null || bytes.isEmpty) {
        return;
      }
      await _loadFromBytes(bytes);
    } catch (_) {}
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
      final decoded = await decodeImageBytes(generated.bytes);
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
    if (state.template != null) {
      await selectTemplate(
        state.template!,
        colors,
        background: color,
      );
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
    final decoded = await decodeImageBytes(bytes);
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
    final sourceBytes = state.sourceBytes;
    if (source == null || sourceBytes == null || sourceBytes.isEmpty) return;
    final safeCrop = _constrainRect(
      state.cropRect ?? _initialCropRect(source),
      source.width.toDouble(),
      source.height.toDouble(),
    );
    final template = state.template;
    final useTemplateInset = template != null &&
        template.category != AvatarTemplateCategory.abstract;
    final padAlphaTemplate =
        template?.hasAlphaBackground == true && useTemplateInset;
    final insetFraction = useTemplateInset
        ? (padAlphaTemplate
            ? transparentAvatarInsetFraction
            : avatarInsetFraction)
        : 0.0;
    final shouldInset = insetFraction > 0;
    final paddingColor = _paddingColorForTemplate(
      image: source,
      template: template,
      fallback: state.backgroundColor,
    );
    final shouldFlatten =
        shouldInset || (paddingColor.a > 0 && source.numChannels == 4);
    emit(state.copyWith(processing: true, clearError: true));
    await Future<void>.delayed(Duration.zero);
    try {
      final processed = await processAvatar(
        AvatarProcessRequest(
          bytes: sourceBytes,
          cropLeft: safeCrop.left,
          cropTop: safeCrop.top,
          cropSide: safeCrop.width,
          targetSize: _targetSize,
          maxBytes: _maxBytes,
          insetFraction: insetFraction,
          shouldInset: shouldInset,
          backgroundColor: paddingColor.toARGB32(),
          flattenBackground: shouldFlatten,
          minJpegQuality: _minQuality,
          qualityStep: _qualityStep,
        ),
      );
      final hash = sha1.convert(processed.bytes).toString();
      final draft = AvatarUploadPayload(
        bytes: processed.bytes,
        mimeType: processed.mimeType,
        width: processed.width,
        height: processed.height,
        hash: hash,
      );
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

  Rect _initialCropRect(img.Image image) {
    final minSide = min(image.width, image.height).toDouble();
    final targetSide = max(minCropSide, minSide * 0.8);
    final side = min(targetSide, minSide);
    final left = (image.width - side) / 2;
    final top = (image.height - side) / 2;
    return _constrainRect(
      Rect.fromLTWH(left, top, side, side),
      image.width.toDouble(),
      image.height.toDouble(),
    );
  }

  Rect _constrainRect(Rect rect, double width, double height) {
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      return Rect.zero;
    }
    final maxSide = min(width, height);
    final minSide = min(minCropSide, maxSide);
    final baseSide = rect.isFinite && rect.width > 0 && rect.height > 0
        ? min(rect.width, rect.height)
        : maxSide;
    final desiredSide = baseSide.clamp(minSide, maxSide);
    final maxLeft = width - desiredSide;
    final maxTop = height - desiredSide;
    final left = rect.left.isFinite
        ? rect.left.clamp(0.0, maxLeft)
        : (width - desiredSide) / 2;
    final top = rect.top.isFinite
        ? rect.top.clamp(0.0, maxTop)
        : (height - desiredSide) / 2;
    return Rect.fromLTWH(left, top, desiredSide, desiredSide);
  }

  Color _paddingColorForTemplate({
    required img.Image image,
    AvatarTemplate? template,
    required Color fallback,
  }) {
    if (template == null ||
        template.category == AvatarTemplateCategory.abstract ||
        image.width <= 0 ||
        image.height <= 0) {
      return fallback;
    }
    if (template.hasAlphaBackground || fallback.a > 0) {
      return fallback;
    }
    final samples = [
      image.getPixel(0, 0),
      image.getPixel(image.width - 1, 0),
      image.getPixel(0, image.height - 1),
      image.getPixel(image.width - 1, image.height - 1),
    ];
    final count = samples.length;
    final r = samples.fold<int>(0, (sum, pixel) => sum + (pixel.r as int));
    final g = samples.fold<int>(0, (sum, pixel) => sum + (pixel.g as int));
    final b = samples.fold<int>(0, (sum, pixel) => sum + (pixel.b as int));
    final a = samples.fold<int>(0, (sum, pixel) => sum + (pixel.a as int));
    return Color.fromARGB(
      a ~/ count,
      r ~/ count,
      g ~/ count,
      b ~/ count,
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
    final selection = _pickFromBag(
      pool: pool,
      bag: useAbstract ? _abstractShuffleBag : _nonAbstractShuffleBag,
    );
    _recentShuffleIds.add(selection.id);
    if (_recentShuffleIds.length > _shuffleHistoryLimit) {
      _recentShuffleIds.removeAt(0);
    }
    return selection;
  }

  AvatarTemplate _pickFromBag({
    required List<AvatarTemplate> pool,
    required List<AvatarTemplate> bag,
  }) {
    if (bag.isEmpty) {
      bag.addAll(pool);
      bag.shuffle(_random);
    }
    AvatarTemplate? selection;
    final recycled = <AvatarTemplate>[];
    while (bag.isNotEmpty) {
      final candidate = bag.removeAt(0);
      if (_recentShuffleIds.contains(candidate.id)) {
        recycled.add(candidate);
        continue;
      }
      selection = candidate;
      break;
    }
    bag.addAll(recycled);
    selection ??=
        bag.isNotEmpty ? bag.removeAt(0) : pool[_random.nextInt(pool.length)];
    return selection;
  }

  Color _randomAvatarBackgroundColor(ShadColorScheme colors) {
    final hue = _random.nextDouble() * 360.0;
    final saturation = 0.75 + _random.nextDouble() * 0.25;
    final lightness = 0.38 + _random.nextDouble() * 0.17;
    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }
}
