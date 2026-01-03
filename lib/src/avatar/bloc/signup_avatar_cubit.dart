// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:axichat/src/avatar/avatar_image_utils.dart';
import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart' show AvatarUploadPayload;
import 'package:bloc/bloc.dart';
import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:shadcn_ui/shadcn_ui.dart';

enum SignupAvatarEditorMode { none, colorOnly, cropOnly }

enum SignupAvatarErrorType {
  openFailed,
  readFailed,
  invalidImage,
  sizeExceeded,
  processingFailed,
}

class SignupAvatarError extends Equatable {
  const SignupAvatarError(this.type, {this.maxKilobytes});

  final SignupAvatarErrorType type;
  final int? maxKilobytes;

  @override
  List<Object?> get props => [type, maxKilobytes];
}

class SignupAvatarState extends Equatable {
  const SignupAvatarState({
    required this.backgroundColor,
    this.avatar,
    this.avatarPreviewBytes,
    this.carouselPreviewBytes,
    this.processing = false,
    this.error,
    this.backgroundLocked = false,
    this.lockedBackgroundColor,
    this.activeTemplate,
    this.activeCategory,
    this.sourceBytes,
    this.imageWidth,
    this.imageHeight,
    this.cropRect,
  });

  final AvatarUploadPayload? avatar;
  final Uint8List? avatarPreviewBytes;
  final Uint8List? carouselPreviewBytes;
  final bool processing;
  final SignupAvatarError? error;
  final Color backgroundColor;
  final bool backgroundLocked;
  final Color? lockedBackgroundColor;
  final AvatarTemplate? activeTemplate;
  final AvatarTemplateCategory? activeCategory;
  final Uint8List? sourceBytes;
  final double? imageWidth;
  final double? imageHeight;
  final Rect? cropRect;

  Uint8List? get displayedBytes => avatarPreviewBytes ?? carouselPreviewBytes;

  bool get hasUserSelectedAvatar => avatar != null;

  bool get canShuffleBackground {
    final template = activeTemplate;
    if (template == null) return false;
    if (template.category == AvatarTemplateCategory.abstract) return false;
    return template.hasAlphaBackground;
  }

  SignupAvatarEditorMode get editorMode {
    final category = activeCategory;
    if (category == null) {
      return activeTemplate == null && sourceBytes != null
          ? SignupAvatarEditorMode.cropOnly
          : SignupAvatarEditorMode.none;
    }
    if (category == AvatarTemplateCategory.abstract) {
      return SignupAvatarEditorMode.none;
    }
    return SignupAvatarEditorMode.colorOnly;
  }

  SignupAvatarState copyWith({
    AvatarUploadPayload? avatar,
    Uint8List? avatarPreviewBytes,
    Uint8List? carouselPreviewBytes,
    bool? processing,
    SignupAvatarError? error,
    Color? backgroundColor,
    bool? backgroundLocked,
    Color? lockedBackgroundColor,
    AvatarTemplate? activeTemplate,
    AvatarTemplateCategory? activeCategory,
    Uint8List? sourceBytes,
    double? imageWidth,
    double? imageHeight,
    Rect? cropRect,
    bool clearError = false,
    bool clearCrop = false,
  }) {
    return SignupAvatarState(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      avatar: avatar ?? this.avatar,
      avatarPreviewBytes: avatarPreviewBytes ?? this.avatarPreviewBytes,
      carouselPreviewBytes: carouselPreviewBytes ?? this.carouselPreviewBytes,
      processing: processing ?? this.processing,
      error: clearError ? null : error ?? this.error,
      backgroundLocked: backgroundLocked ?? this.backgroundLocked,
      lockedBackgroundColor:
          lockedBackgroundColor ?? this.lockedBackgroundColor,
      activeTemplate: activeTemplate ?? this.activeTemplate,
      activeCategory: activeCategory ?? this.activeCategory,
      sourceBytes: clearCrop ? null : sourceBytes ?? this.sourceBytes,
      imageWidth: clearCrop ? null : imageWidth ?? this.imageWidth,
      imageHeight: clearCrop ? null : imageHeight ?? this.imageHeight,
      cropRect: clearCrop ? null : cropRect ?? this.cropRect,
    );
  }

  @override
  List<Object?> get props => [
        avatar?.hash,
        avatarPreviewBytes,
        carouselPreviewBytes,
        processing,
        error,
        backgroundColor,
        backgroundLocked,
        lockedBackgroundColor,
        activeTemplate,
        activeCategory,
        sourceBytes,
        imageWidth,
        imageHeight,
        cropRect,
      ];
}

class SignupAvatarCubit extends Cubit<SignupAvatarState> {
  SignupAvatarCubit({List<AvatarTemplate>? templates})
      : _templates = templates ?? buildDefaultAvatarTemplates(),
        super(const SignupAvatarState(backgroundColor: Colors.transparent)) {
    _abstractTemplates = _templates
        .where(
            (template) => template.category == AvatarTemplateCategory.abstract)
        .toList();
    _nonAbstractTemplates = _templates
        .where(
            (template) => template.category != AvatarTemplateCategory.abstract)
        .toList();
  }

  static const int avatarTargetSize = 256;
  static const int avatarMaxBytes = 64 * 1024;
  static const int avatarMaxKilobytes = avatarMaxBytes ~/ 1024;
  static const int avatarMinJpegQuality = 35;
  static const int avatarQualityStep = 5;
  static const int _sourceMaxDimension = 768;
  static const int _sourceJpegQuality = 86;
  static const double avatarInsetFraction = 0.10;
  static const double avatarTransparentInsetFraction = 0.10;
  static const double minCropSide = 48.0;
  static const _avatarCarouselInterval = Duration(seconds: 1);
  static const _avatarCarouselInitialBuffer = 4;
  static const _avatarCarouselSustainBuffer = 3;
  static const _avatarCarouselHistoryLimit = 12;
  static const _rebuildDelay = Duration(milliseconds: 140);
  static const _abstractWarmupDuration = Duration(seconds: 3);

  static const _randomBackgroundSaturationMin = 0.75;
  static const _randomBackgroundSaturationRange = 0.25;
  static const _randomBackgroundLightnessMin = 0.38;
  static const _randomBackgroundLightnessRange = 0.17;

  final List<AvatarTemplate> _templates;
  late final List<AvatarTemplate> _abstractTemplates;
  late final List<AvatarTemplate> _nonAbstractTemplates;
  final math.Random _random = math.Random();

  final List<_CarouselAvatar> _carouselBuffer = <_CarouselAvatar>[];
  final List<String> _recentCarouselAvatarIds = <String>[];
  final List<AvatarTemplate> _abstractCarouselBag = <AvatarTemplate>[];
  final List<AvatarTemplate> _nonAbstractCarouselBag = <AvatarTemplate>[];
  Timer? _avatarCarouselTimer;
  Future<bool>? _prefillCarouselFuture;
  bool _nonAbstractAvatarsReady = false;
  bool _warmingNonAbstractAvatars = false;
  bool _initialized = false;
  bool _carouselEnabled = true;
  ShadColorScheme? _colors;
  DateTime? _abstractOnlyUntil;

  Timer? _rebuildTimer;
  img.Image? _sourceImage;
  _CarouselAvatar? _currentCarouselAvatar;

  @override
  Future<void> close() async {
    _avatarCarouselTimer?.cancel();
    _rebuildTimer?.cancel();
    return super.close();
  }

  void initialize(ShadColorScheme colors) {
    _colors = colors;
    if (_initialized) return;
    _initialized = true;
    _abstractOnlyUntil = DateTime.now().add(_abstractWarmupDuration);
    emit(
      state.copyWith(
        backgroundColor: colors.accent,
        clearError: true,
      ),
    );
    if (_carouselEnabled) {
      unawaited(_startAvatarCarousel());
    }
  }

  bool get _abstractWarmupActive {
    final until = _abstractOnlyUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void setVisible(bool visible, ShadColorScheme colors) {
    _colors = colors;
    _carouselEnabled = visible;
    if (!visible) {
      _stopAvatarCarousel();
      return;
    }
    initialize(colors);
    _resumeAvatarCarouselIfNeeded();
  }

  void materializeCurrentCarouselAvatar() {
    if (state.avatar != null || state.processing) {
      return;
    }
    final current = _currentCarouselAvatar;
    if (current == null) {
      return;
    }
    _stopAvatarCarousel();
    emit(
      state.copyWith(
        avatar: current.payload,
        avatarPreviewBytes: current.payload.bytes,
        carouselPreviewBytes: null,
        activeTemplate: current.template,
        activeCategory: current.category,
        backgroundColor: current.template?.hasAlphaBackground == true
            ? current.background
            : state.backgroundColor,
        clearError: true,
      ),
    );
  }

  Future<void> shuffleTemplate(ShadColorScheme colors) async {
    _colors = colors;
    final selection = _pickAvatarSelection(colors);
    if (selection == null) return;
    await selectTemplate(
      selection.template,
      background: selection.background,
      colors: colors,
    );
  }

  Future<void> shuffleBackground(ShadColorScheme colors) async {
    _colors = colors;
    if (state.processing || !state.canShuffleBackground) {
      return;
    }
    final template = state.activeTemplate;
    if (template == null) {
      return;
    }
    final background = _randomAvatarBackgroundColor(colors);
    emit(
      state.copyWith(
        backgroundLocked: true,
        lockedBackgroundColor: background,
      ),
    );
    await selectTemplate(
      template,
      background: background,
      colors: colors,
    );
  }

  Future<void> selectTemplate(
    AvatarTemplate template, {
    required ShadColorScheme colors,
    Color? background,
  }) async {
    _colors = colors;
    if (state.processing) return;

    _stopAvatarCarousel();
    _carouselBuffer.clear();
    _currentCarouselAvatar = null;
    _sourceImage = null;

    emit(
      state.copyWith(
        processing: true,
        error: null,
        clearError: true,
        carouselPreviewBytes: null,
        activeTemplate: template,
        activeCategory: template.category,
        clearCrop: true,
      ),
    );

    final resolvedBackground = _resolveTemplateBackground(
      template,
      colors,
      requested: background,
    );

    try {
      final payload = await _buildAvatarPayloadFromTemplate(
        template: template,
        background: resolvedBackground,
        colors: colors,
      );
      if (isClosed) return;
      _pushRecentCarouselAvatar(template.id);
      if (!_nonAbstractAvatarsReady &&
          template.category != AvatarTemplateCategory.abstract) {
        _nonAbstractAvatarsReady = true;
      }
      emit(
        state.copyWith(
          avatar: payload,
          avatarPreviewBytes: payload.bytes,
          processing: false,
          clearError: true,
          backgroundColor: template.hasAlphaBackground
              ? resolvedBackground
              : state.backgroundColor,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          processing: false,
          error:
              const SignupAvatarError(SignupAvatarErrorType.processingFailed),
        ),
      );
      _resumeAvatarCarouselIfNeeded();
    }
  }

  Future<void> pickAvatarFromFiles() async {
    if (state.processing) return;
    _stopAvatarCarousel();

    emit(
      state.copyWith(
        processing: true,
        carouselPreviewBytes: null,
        clearError: true,
      ),
    );

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
        withReadStream: true,
      );
      if (result == null || result.files.isEmpty) {
        if (isClosed) return;
        emit(state.copyWith(processing: false, clearError: true));
        _resumeAvatarCarouselIfNeeded();
        return;
      }
      final file = result.files.first;
      final bytes = await _loadPickedFileBytes(file);
      if (bytes == null || bytes.isEmpty) {
        if (isClosed) return;
        emit(
          state.copyWith(
            processing: false,
            error: const SignupAvatarError(SignupAvatarErrorType.readFailed),
          ),
        );
        _resumeAvatarCarouselIfNeeded();
        return;
      }
      await _applyAvatarFromBytes(bytes);
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          processing: false,
          error: const SignupAvatarError(SignupAvatarErrorType.openFailed),
        ),
      );
      _resumeAvatarCarouselIfNeeded();
    }
  }

  void updateCropRect(Rect rect) {
    final image = _sourceImage;
    if (image == null) return;
    final constrained = _constrainCropRect(rect, image);
    if (state.cropRect == constrained) return;
    emit(
      state.copyWith(
        cropRect: constrained,
        processing: true,
        clearError: true,
      ),
    );
    _scheduleRebuild();
  }

  void resetCrop() {
    final image = _sourceImage;
    if (image == null) return;
    final reset = _fallbackCropRect(
      imageWidth: image.width.toDouble(),
      imageHeight: image.height.toDouble(),
    );
    emit(
      state.copyWith(
        cropRect: reset,
        processing: true,
        clearError: true,
      ),
    );
    _scheduleRebuild();
  }

  void _scheduleRebuild() {
    _rebuildTimer?.cancel();
    _rebuildTimer = Timer(_rebuildDelay, () => unawaited(_rebuildAvatar()));
  }

  Future<void> _applyAvatarFromBytes(Uint8List bytes) async {
    try {
      final prepared = await prepareAvatarSource(
        AvatarSourcePrepareRequest(
          bytes: bytes,
          maxDimension: _sourceMaxDimension,
          jpegQuality: _sourceJpegQuality,
        ),
      );
      if (isClosed) return;
      final preparedBytes = prepared.bytes;
      final decoded = await decodeImageBytes(preparedBytes);
      if (decoded == null) {
        if (isClosed) return;
        emit(
          state.copyWith(
            processing: false,
            error: const SignupAvatarError(SignupAvatarErrorType.invalidImage),
          ),
        );
        _resumeAvatarCarouselIfNeeded();
        return;
      }
      _sourceImage = decoded;
      final width = prepared.width.toDouble();
      final height = prepared.height.toDouble();
      emit(
        state.copyWith(
          sourceBytes: preparedBytes,
          imageWidth: width,
          imageHeight: height,
          cropRect: _fallbackCropRect(
            imageWidth: width,
            imageHeight: height,
          ),
          activeTemplate: null,
          activeCategory: null,
          backgroundColor: Colors.transparent,
          clearError: true,
        ),
      );
      await _rebuildAvatar();
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          processing: false,
          error: const SignupAvatarError(SignupAvatarErrorType.invalidImage),
        ),
      );
      _resumeAvatarCarouselIfNeeded();
    }
  }

  Future<Uint8List?> _loadPickedFileBytes(PlatformFile file) async {
    if (file.bytes?.isNotEmpty == true) {
      return file.bytes!;
    }
    final stream = file.readStream;
    if (stream == null) {
      return null;
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    final data = builder.takeBytes();
    return data.isEmpty ? null : data;
  }

  Future<void> _rebuildAvatar() async {
    _rebuildTimer?.cancel();
    final image = _sourceImage;
    final sourceBytes = state.sourceBytes;
    if (image == null || sourceBytes == null || sourceBytes.isEmpty) {
      if (isClosed) return;
      emit(state.copyWith(processing: false));
      _resumeAvatarCarouselIfNeeded();
      return;
    }
    await Future<void>.delayed(Duration.zero);
    try {
      final payload = await _processSignupImage(
        image: image,
        bytes: sourceBytes,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          avatar: payload,
          avatarPreviewBytes: payload.bytes,
          processing: false,
          clearError: true,
        ),
      );
      _stopAvatarCarousel();
    } on _AvatarSizeException {
      if (isClosed) return;
      emit(
        state.copyWith(
          processing: false,
          error: const SignupAvatarError(
            SignupAvatarErrorType.sizeExceeded,
            maxKilobytes: avatarMaxKilobytes,
          ),
        ),
      );
      _resumeAvatarCarouselIfNeeded();
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          processing: false,
          error:
              const SignupAvatarError(SignupAvatarErrorType.processingFailed),
        ),
      );
      _resumeAvatarCarouselIfNeeded();
    }
  }

  Future<AvatarUploadPayload> _processSignupImage({
    required img.Image image,
    required Uint8List bytes,
  }) async {
    final baseCrop = state.cropRect ??
        _fallbackCropRect(
          imageWidth: image.width.toDouble(),
          imageHeight: image.height.toDouble(),
        );
    final safeCrop = _constrainCropRect(baseCrop, image);
    final hasAlpha = image.hasAlpha || image.numChannels == 4;
    final background = state.backgroundColor;
    final shouldFlatten = background.a > 0 && hasAlpha;
    final processed = await processAvatar(
      AvatarProcessRequest(
        bytes: bytes,
        cropLeft: safeCrop.left,
        cropTop: safeCrop.top,
        cropSide: safeCrop.width,
        targetSize: avatarTargetSize,
        maxBytes: avatarMaxBytes,
        insetFraction: 0,
        shouldInset: false,
        backgroundColor: background.toARGB32(),
        flattenBackground: shouldFlatten,
        minJpegQuality: avatarMinJpegQuality,
        qualityStep: avatarQualityStep,
      ),
    );
    if (processed.bytes.length > avatarMaxBytes) {
      throw const _AvatarSizeException();
    }
    final hash = sha1.convert(processed.bytes).toString();
    return AvatarUploadPayload(
      bytes: processed.bytes,
      mimeType: processed.mimeType,
      width: processed.width,
      height: processed.height,
      hash: hash,
    );
  }

  Future<AvatarUploadPayload> _buildAvatarPayloadFromTemplate({
    required AvatarTemplate template,
    required Color background,
    required ShadColorScheme colors,
  }) async {
    final rawBytes = await template.loadRawBytes();
    final bytes = (rawBytes != null && rawBytes.isNotEmpty)
        ? rawBytes
        : (await template.generator(background, colors)).bytes;
    return _processTemplateBytes(
      bytes: bytes,
      template: template,
      background: template.hasAlphaBackground
          ? background
          : state.backgroundColor == Colors.transparent
              ? colors.accent
              : state.backgroundColor,
    );
  }

  Future<AvatarUploadPayload> _processTemplateBytes({
    required Uint8List bytes,
    required AvatarTemplate template,
    required Color background,
  }) async {
    const cropSide = 100000.0;
    final useTemplateInset =
        template.category != AvatarTemplateCategory.abstract;
    final padAlphaTemplate = template.hasAlphaBackground && useTemplateInset;
    final insetFraction = useTemplateInset
        ? (padAlphaTemplate
            ? avatarTransparentInsetFraction
            : avatarInsetFraction)
        : 0.0;
    final shouldInset = insetFraction > 0;
    final shouldFlatten =
        shouldInset || template.hasAlphaBackground || background.a > 0;
    final processed = await processAvatar(
      AvatarProcessRequest(
        bytes: bytes,
        cropLeft: 0,
        cropTop: 0,
        cropSide: cropSide,
        targetSize: avatarTargetSize,
        maxBytes: avatarMaxBytes,
        insetFraction: insetFraction,
        shouldInset: shouldInset,
        backgroundColor: background.toARGB32(),
        flattenBackground: shouldFlatten,
        minJpegQuality: avatarMinJpegQuality,
        qualityStep: avatarQualityStep,
      ),
    );
    final hash = sha1.convert(processed.bytes).toString();
    return AvatarUploadPayload(
      bytes: processed.bytes,
      mimeType: processed.mimeType,
      width: processed.width,
      height: processed.height,
      hash: hash,
    );
  }

  Future<void> _startAvatarCarousel() async {
    if (!_carouselEnabled ||
        state.hasUserSelectedAvatar ||
        state.processing ||
        _avatarCarouselTimer != null) {
      return;
    }
    final colors = _colors;
    if (colors == null) return;

    if (state.carouselPreviewBytes == null && _currentCarouselAvatar == null) {
      await _prefillCarousel(
        targetSize: 1,
        preferAbstract: true,
      );
      if (isClosed ||
          !_carouselEnabled ||
          state.hasUserSelectedAvatar ||
          state.processing ||
          _avatarCarouselTimer != null) {
        return;
      }
      if (!_showNextCarouselAvatar(colors, allowFallback: false)) {
        _showNextCarouselAvatar(colors, allowFallback: true);
      }
    }

    unawaited(
      _prefillCarousel(
        targetSize: _avatarCarouselInitialBuffer,
        preferAbstract: !_nonAbstractAvatarsReady,
      ),
    );

    if (!_carouselEnabled ||
        state.hasUserSelectedAvatar ||
        state.processing ||
        _avatarCarouselTimer != null) {
      return;
    }

    _avatarCarouselTimer = Timer.periodic(
      _avatarCarouselInterval,
      (_) {
        if (!_carouselEnabled ||
            state.hasUserSelectedAvatar ||
            state.processing) {
          return;
        }
        _showNextCarouselAvatar(colors, allowFallback: false);
        unawaited(
          _prefillCarousel(
            targetSize: _avatarCarouselSustainBuffer,
            preferAbstract: !_nonAbstractAvatarsReady,
          ),
        );
      },
    );
  }

  void _stopAvatarCarousel() {
    _avatarCarouselTimer?.cancel();
    _avatarCarouselTimer = null;
  }

  void _resumeAvatarCarouselIfNeeded() {
    if (!_carouselEnabled ||
        state.hasUserSelectedAvatar ||
        state.processing ||
        !_initialized ||
        _avatarCarouselTimer != null) {
      return;
    }
    unawaited(_startAvatarCarousel());
  }

  bool _showNextCarouselAvatar(
    ShadColorScheme colors, {
    bool allowFallback = true,
  }) {
    if (isClosed ||
        !_carouselEnabled ||
        state.processing ||
        state.hasUserSelectedAvatar) {
      return false;
    }
    if (_carouselBuffer.isEmpty) {
      if (!allowFallback) {
        return false;
      }
      final fallbackBackground = state.backgroundColor == Colors.transparent
          ? colors.accent
          : state.backgroundColor;
      final fallback = _fallbackAvatarPayload(
        background: fallbackBackground,
        accent: colors.primary,
      );
      final entry = _CarouselAvatar(
        payload: fallback,
        template: null,
        category: AvatarTemplateCategory.abstract,
        background: fallbackBackground,
      );
      _currentCarouselAvatar = entry;
      emit(
        state.copyWith(
          carouselPreviewBytes: fallback.bytes,
          activeTemplate: null,
          activeCategory: AvatarTemplateCategory.abstract,
          clearError: true,
        ),
      );
      return true;
    }

    final entry = _carouselBuffer.removeAt(0);
    _currentCarouselAvatar = entry;
    if (!_nonAbstractAvatarsReady &&
        entry.category != AvatarTemplateCategory.abstract) {
      _nonAbstractAvatarsReady = true;
    }
    emit(
      state.copyWith(
        carouselPreviewBytes: entry.payload.bytes,
        activeTemplate: entry.template,
        activeCategory: entry.category,
        backgroundColor: entry.template?.hasAlphaBackground == true
            ? entry.background
            : state.backgroundColor,
        clearError: true,
      ),
    );
    return true;
  }

  Future<bool> _prefillCarousel({
    int targetSize = 2,
    bool preferAbstract = false,
  }) async {
    if (_prefillCarouselFuture != null) {
      return _prefillCarouselFuture!;
    }
    if (isClosed ||
        !_carouselEnabled ||
        state.hasUserSelectedAvatar ||
        state.processing) {
      return _carouselBuffer.isNotEmpty;
    }
    final future = _performCarouselPrefill(
      targetSize: targetSize,
      preferAbstract: preferAbstract,
    );
    _prefillCarouselFuture = future;
    try {
      return await future;
    } finally {
      _prefillCarouselFuture = null;
    }
  }

  Future<bool> _performCarouselPrefill({
    int targetSize = 2,
    bool preferAbstract = false,
  }) async {
    final colors = _colors;
    if (colors == null) return false;
    final warmupActive = _abstractWarmupActive;

    if (!warmupActive &&
        preferAbstract &&
        !_nonAbstractAvatarsReady &&
        !_warmingNonAbstractAvatars &&
        _nonAbstractTemplates.isNotEmpty) {
      _warmingNonAbstractAvatars = true;
      unawaited(_warmFirstNonAbstractAvatar(colors));
    }

    var added = 0;
    var attempts = 0;
    const maxAttempts = 6;
    try {
      while (!isClosed &&
          _carouselEnabled &&
          !state.hasUserSelectedAvatar &&
          !state.processing &&
          _carouselBuffer.length < targetSize &&
          attempts < maxAttempts) {
        final useAbstractOnly =
            (warmupActive || (preferAbstract && !_nonAbstractAvatarsReady)) &&
                _abstractTemplates.isNotEmpty;
        AvatarTemplate? template = useAbstractOnly
            ? _pickFromPool(
                _abstractTemplates,
                bag: _abstractCarouselBag,
              )
            : null;
        template ??= _pickCarouselTemplate();
        if (template == null) break;
        attempts++;
        _pushRecentCarouselAvatar(template.id);
        final background = template.hasAlphaBackground
            ? _randomAvatarBackgroundColor(colors)
            : state.backgroundColor;
        final payload = await _buildAvatarPayloadFromTemplate(
          template: template,
          background: background,
          colors: colors,
        );
        _carouselBuffer.add(
          _CarouselAvatar(
            payload: payload,
            template: template,
            category: template.category,
            background: background,
          ),
        );
        if (!_nonAbstractAvatarsReady &&
            template.category != AvatarTemplateCategory.abstract) {
          _nonAbstractAvatarsReady = true;
        }
        added++;
      }
      if (added == 0 &&
          _carouselBuffer.isEmpty &&
          !isClosed &&
          _carouselEnabled &&
          !state.hasUserSelectedAvatar) {
        final fallbackBackground = state.backgroundColor == Colors.transparent
            ? colors.accent
            : state.backgroundColor;
        final fallback = _fallbackAvatarPayload(
          background: fallbackBackground,
          accent: colors.primary,
        );
        _carouselBuffer.add(
          _CarouselAvatar(
            payload: fallback,
            template: null,
            category: AvatarTemplateCategory.abstract,
            background: fallbackBackground,
          ),
        );
        return true;
      }
    } catch (_) {
      // Ignore prefill failures; fallback handled by buffer logic.
    }
    return added > 0;
  }

  Future<void> _warmFirstNonAbstractAvatar(ShadColorScheme colors) async {
    try {
      final template = _pickFromPool(
        _nonAbstractTemplates,
        bag: _nonAbstractCarouselBag,
      );
      if (template == null) return;
      _pushRecentCarouselAvatar(template.id);
      final background = template.hasAlphaBackground
          ? _randomAvatarBackgroundColor(colors)
          : state.backgroundColor;
      final payload = await _buildAvatarPayloadFromTemplate(
        template: template,
        background: background,
        colors: colors,
      );
      if (isClosed || !_carouselEnabled) return;
      _nonAbstractAvatarsReady = true;
      _carouselBuffer.add(
        _CarouselAvatar(
          payload: payload,
          template: template,
          category: template.category,
          background: background,
        ),
      );
    } catch (_) {
      // Ignore warmup failures; fallback handled by buffer.
    } finally {
      _warmingNonAbstractAvatars = false;
    }
  }

  AvatarTemplate? _pickCarouselTemplate() {
    final hasAbstract = _abstractTemplates.isNotEmpty;
    final hasOther = _nonAbstractTemplates.isNotEmpty;
    if (!hasAbstract && !hasOther) {
      return null;
    }
    if (!hasOther) {
      return _pickFromPool(
        _abstractTemplates,
        bag: _abstractCarouselBag,
      );
    }
    if (!hasAbstract) {
      return _pickFromPool(
        _nonAbstractTemplates,
        bag: _nonAbstractCarouselBag,
      );
    }
    final useAbstract = _random.nextBool();
    return _pickFromPool(
      useAbstract ? _abstractTemplates : _nonAbstractTemplates,
      bag: useAbstract ? _abstractCarouselBag : _nonAbstractCarouselBag,
    );
  }

  AvatarTemplate? _pickFromPool(
    List<AvatarTemplate> pool, {
    required List<AvatarTemplate> bag,
  }) {
    if (pool.isEmpty) return null;
    if (bag.isEmpty) {
      bag.addAll(pool);
      bag.shuffle(_random);
    }
    AvatarTemplate? selection;
    final recycled = <AvatarTemplate>[];
    while (bag.isNotEmpty) {
      final candidate = bag.removeAt(0);
      if (_recentCarouselAvatarIds.contains(candidate.id)) {
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

  void _pushRecentCarouselAvatar(String id) {
    _recentCarouselAvatarIds.add(id);
    if (_recentCarouselAvatarIds.length > _avatarCarouselHistoryLimit) {
      _recentCarouselAvatarIds.removeAt(0);
    }
  }

  _AvatarSelection? _pickAvatarSelection(ShadColorScheme colors) {
    final template = _pickCarouselTemplate();
    if (template == null) return null;
    final background = state.backgroundLocked
        ? (state.lockedBackgroundColor ?? state.backgroundColor)
        : _randomAvatarBackgroundColor(colors);
    return _AvatarSelection(template: template, background: background);
  }

  Color _resolveTemplateBackground(
    AvatarTemplate template,
    ShadColorScheme colors, {
    Color? requested,
  }) {
    if (requested != null) return requested;
    if (!template.hasAlphaBackground) return state.backgroundColor;
    if (state.backgroundLocked) {
      return state.lockedBackgroundColor ?? state.backgroundColor;
    }
    return _randomAvatarBackgroundColor(colors);
  }

  Color _randomAvatarBackgroundColor(ShadColorScheme colors) {
    final hue = _random.nextDouble() * 360.0;
    final saturation = _randomBackgroundSaturationMin +
        _random.nextDouble() * _randomBackgroundSaturationRange;
    final lightness = _randomBackgroundLightnessMin +
        _random.nextDouble() * _randomBackgroundLightnessRange;
    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }

  AvatarUploadPayload _fallbackAvatarPayload({
    required Color background,
    required Color accent,
  }) {
    final generated = _fallbackGeneratedAvatar(
      background: background,
      accent: accent,
    );
    final hash = sha1.convert(generated.bytes).toString();
    return AvatarUploadPayload(
      bytes: generated.bytes,
      mimeType: generated.mimeType,
      width: generated.width,
      height: generated.height,
      hash: hash,
    );
  }

  GeneratedAvatar _fallbackGeneratedAvatar({
    required Color background,
    required Color accent,
  }) {
    const size = avatarTargetSize;
    final base = background == Colors.transparent ? accent : background;
    final image = img.Image(width: size, height: size, numChannels: 4);
    img.fill(image, color: _imgColor(base));
    final bytes = Uint8List.fromList(img.encodePng(image, level: 1));
    return GeneratedAvatar(
      bytes: bytes,
      mimeType: 'image/png',
      width: size,
      height: size,
      hasAlpha: false,
    );
  }

  img.Color _imgColor(Color color) {
    final argb = color.toARGB32();
    final a = (argb >> 24) & 0xFF;
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    return img.ColorRgba8(r, g, b, a);
  }

  Rect _fallbackCropRect({
    required double imageWidth,
    required double imageHeight,
  }) {
    if (!imageWidth.isFinite ||
        !imageHeight.isFinite ||
        imageWidth <= 0 ||
        imageHeight <= 0) {
      return Rect.zero;
    }
    final minSide = math.min(imageWidth, imageHeight);
    final effectiveMinSide = math.min(minCropSide, minSide);
    final targetSide = minSide * 0.72;
    final safeSide = targetSide.clamp(effectiveMinSide, minSide);
    final left = (imageWidth - safeSide) / 2;
    final top = (imageHeight - safeSide) / 2;
    return Rect.fromLTWH(left, top, safeSide, safeSide);
  }

  Rect _constrainCropRect(Rect rect, img.Image image) {
    final width = image.width.toDouble();
    final height = image.height.toDouble();
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      return Rect.zero;
    }
    final maxSide = math.min(width, height);
    final safeMinSide = math.min(minCropSide, maxSide);
    final fallback = _fallbackCropRect(
      imageWidth: width,
      imageHeight: height,
    );
    if (!rect.isFinite || rect.width <= 0 || rect.height <= 0) {
      return fallback;
    }
    final desiredSide =
        math.min(rect.width, rect.height).clamp(safeMinSide, maxSide);
    final maxLeft = width - desiredSide;
    final maxTop = height - desiredSide;
    final left =
        rect.left.isFinite ? rect.left.clamp(0.0, maxLeft) : fallback.left;
    final top = rect.top.isFinite ? rect.top.clamp(0.0, maxTop) : fallback.top;
    return Rect.fromLTWH(left, top, desiredSide, desiredSide);
  }
}

class _AvatarSizeException implements Exception {
  const _AvatarSizeException();
}

class _AvatarSelection {
  const _AvatarSelection({
    required this.template,
    required this.background,
  });

  final AvatarTemplate template;
  final Color background;
}

class _CarouselAvatar {
  const _CarouselAvatar({
    required this.payload,
    required this.background,
    this.template,
    this.category,
  });

  final AvatarUploadPayload payload;
  final AvatarTemplate? template;
  final AvatarTemplateCategory? category;
  final Color background;
}
