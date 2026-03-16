// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:axichat/src/avatar/avatar_editor_mode.dart';
import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/avatar/editing/editable_avatar.dart';
import 'package:axichat/src/avatar/editing/avatar_carousel_engine.dart';
import 'package:axichat/src/avatar/editing/avatar_pipeline.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart' show AvatarUploadPayload;
import 'package:bloc/bloc.dart';
import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:shadcn_ui/shadcn_ui.dart';

part 'signup_avatar_state.dart';

enum SignupAvatarErrorType {
  openFailed,
  readFailed,
  invalidImage,
  sizeExceeded,
  processingFailed,
}

extension SignupAvatarErrorLocalization on SignupAvatarErrorType {
  String resolve(
    AppLocalizations l10n, {
    required bool hasSourceBytes,
    int? maxKilobytes,
    required int fallbackMaxKilobytes,
  }) {
    return switch (this) {
      SignupAvatarErrorType.openFailed => l10n.signupAvatarOpenError,
      SignupAvatarErrorType.readFailed => l10n.signupAvatarReadError,
      SignupAvatarErrorType.invalidImage => l10n.signupAvatarInvalidImage,
      SignupAvatarErrorType.sizeExceeded => l10n.signupAvatarSizeError(
        maxKilobytes ?? fallbackMaxKilobytes,
      ),
      SignupAvatarErrorType.processingFailed =>
        hasSourceBytes
            ? l10n.signupAvatarProcessError
            : l10n.signupAvatarRenderError,
    };
  }
}

class SignupAvatarCubit extends Cubit<SignupAvatarState> {
  SignupAvatarCubit({List<AvatarTemplate>? templates, AvatarPipeline? pipeline})
    : _templates = templates ?? buildDefaultAvatarTemplates(),
      _random = math.Random(),
      _pipeline = pipeline ?? AvatarPipeline(config: _defaultPipelineConfig),
      super(const SignupAvatarState(backgroundColor: Colors.transparent)) {
    _carouselEngine = AvatarCarouselEngine(
      pipeline: _pipeline,
      templates: _templates,
      random: _random,
      config: const AvatarCarouselEngineConfig(
        historyLimit: _avatarCarouselHistoryLimit,
        abstractWarmupDuration: _abstractWarmupDuration,
      ),
    );
  }

  static const AvatarPipelineConfig _defaultPipelineConfig =
      AvatarPipelineConfig(
        minJpegQuality: 35,
        minCropSide: minCropSide,
        uploadMaxDimension: 0,
      );
  static final int avatarMaxKilobytes = _defaultPipelineConfig.maxBytes ~/ 1024;
  static const int _sourceMaxBytes = 8 * 1024 * 1024;
  static const double avatarInsetFraction = 0.10;
  static const double avatarTransparentInsetFraction = 0.10;
  static const double minCropSide = 48.0;
  static const _avatarCarouselInterval = Duration(seconds: 1);
  static const _avatarCarouselInitialBuffer = 4;
  static const _avatarCarouselSustainBuffer = 3;
  static const _avatarCarouselHistoryLimit = 12;
  static const _avatarCarouselCropSide = 100000.0;
  static const _abstractWarmupDuration = Duration(seconds: 3);

  final List<AvatarTemplate> _templates;
  final math.Random _random;
  final AvatarPipeline _pipeline;
  Rect? _pendingCropRect;
  late final AvatarCarouselEngine _carouselEngine;
  final List<EditableAvatar> _carouselBuffer = <EditableAvatar>[];
  Timer? _avatarCarouselTimer;
  int _carouselGeneration = 0;
  Future<bool>? _prefillCarouselFuture;
  _CarouselVisibility _carouselVisibility = _CarouselVisibility.visible;
  ShadColorScheme? _colors;
  EditableAvatar? _currentCarouselAvatar;

  @override
  Future<void> close() async {
    _stopAvatarCarousel();
    return super.close();
  }

  Future<void> initialize(ShadColorScheme colors) async {
    _colors = colors;
    _carouselEngine.startWarmupIfNeeded();
    emit(state.copyWith(backgroundColor: colors.accent, clearError: true));
    if (_isCarouselVisible) {
      await _startAvatarCarousel();
    }
  }

  Future<void> setVisible(bool visible, ShadColorScheme colors) async {
    _colors = colors;
    _carouselVisibility = visible
        ? _CarouselVisibility.visible
        : _CarouselVisibility.hidden;
    if (!visible) {
      _stopAvatarCarousel();
      return;
    }
    await initialize(colors);
    await _resumeAvatarCarouselIfNeeded();
  }

  void pauseCarousel() {
    _carouselVisibility = _CarouselVisibility.hidden;
    _stopAvatarCarousel();
  }

  void selectCarouselAvatar() {
    if (state.processing) return;
    final selected = state.carouselAvatar ?? _currentCarouselAvatar;
    if (selected == null) return;
    _stopAvatarCarousel();
    _carouselBuffer.clear();
    _currentCarouselAvatar = null;
    _pendingCropRect = null;
    emit(
      state.copyWith(
        avatar: selected,
        carouselAvatar: null,
        backgroundColor: selected.backgroundColor ?? state.backgroundColor,
        clearError: true,
      ),
    );
  }

  AvatarUploadPayload? selectedAvatarPayload() => state.avatar?.payload;

  Future<AvatarUploadPayload?> buildSelectedAvatarPayload() async {
    final draftAvatar = state.avatar;
    if (draftAvatar == null) return null;
    final refreshed = await _refreshAvatarPayload(draftAvatar);
    return refreshed?.payload;
  }

  Future<void> pauseOnPreviewAvatar(ShadColorScheme colors) async {
    _colors = colors;
    if (state.processing) return;

    _carouselVisibility = _CarouselVisibility.visible;
    if (state.hasUserSelectedAvatar) {
      _carouselBuffer.clear();
      _currentCarouselAvatar = null;
      _pendingCropRect = null;
      emit(
        state.copyWith(
          avatar: null,
          carouselAvatar: null,
          backgroundLocked: false,
          lockedBackgroundColor: null,
          clearError: true,
        ),
      );
    }

    if (_carouselBuffer.isEmpty) {
      await _prefillCarousel(targetSize: 1, preferAbstract: !_nonAbstractReady);
    }
    if (state.processing || state.hasUserSelectedAvatar) {
      return;
    }
    if (!_showNextCarouselAvatar(colors, allowFallback: false)) {
      _showNextCarouselAvatar(colors, allowFallback: true);
    }
    pauseCarousel();
  }

  Future<void> seedAvatarFromBytes(Uint8List bytes) async {
    if (bytes.isEmpty) return;
    _stopAvatarCarousel();
    _currentCarouselAvatar = null;
    _pendingCropRect = null;
    emit(
      state.copyWith(
        avatar: null,
        carouselAvatar: null,
        processing: true,
        clearError: true,
      ),
    );
    await _applyAvatarFromBytes(bytes);
  }

  Future<void> shuffleBackground(ShadColorScheme colors) async {
    _colors = colors;
    if (state.processing || !state.canShuffleBackground) {
      return;
    }
    final activeAvatar =
        state.avatar ?? state.carouselAvatar ?? _currentCarouselAvatar;
    final template = activeAvatar?.template;
    if (template == null) {
      return;
    }
    final background = _randomAvatarBackgroundColor();
    emit(
      state.copyWith(backgroundLocked: true, lockedBackgroundColor: background),
    );
    if (state.avatar == null) {
      pauseCarousel();
      emit(state.copyWith(processing: true, clearError: true));
      try {
        final updated = await _buildAvatarFromTemplate(
          template: template,
          background: background,
          colors: colors,
        );
        _currentCarouselAvatar = updated;
        emit(
          state.copyWith(
            processing: false,
            carouselAvatar: updated,
            backgroundColor: background,
            clearError: true,
          ),
        );
      } on FormatException {
        emit(
          state.copyWith(
            processing: false,
            errorType: SignupAvatarErrorType.processingFailed,
          ),
        );
      }
      return;
    }
    await selectTemplate(template, background: background, colors: colors);
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
    _pendingCropRect = null;

    emit(
      state.copyWith(processing: true, clearError: true, carouselAvatar: null),
    );

    final resolvedBackground = _resolveTemplateBackground(
      template,
      colors,
      requested: background,
    );

    try {
      final avatar = await _buildAvatarFromTemplate(
        template: template,
        background: resolvedBackground,
        colors: colors,
      );
      _carouselEngine.markTemplateUsed(template);
      _carouselEngine.markNonAbstractReady(template);
      emit(
        state.copyWith(
          avatar: avatar,
          processing: false,
          clearError: true,
          backgroundColor: template.hasAlphaBackground
              ? resolvedBackground
              : state.backgroundColor,
        ),
      );
    } on FormatException {
      emit(
        state.copyWith(
          processing: false,
          errorType: SignupAvatarErrorType.processingFailed,
        ),
      );
      _resumeAvatarCarouselIfNeeded();
    }
  }

  Future<void> pickAvatarFromFiles() async {
    if (state.processing) return;
    _stopAvatarCarousel();

    emit(
      state.copyWith(processing: true, carouselAvatar: null, clearError: true),
    );

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
        withReadStream: true,
      );
      if (result == null || result.files.isEmpty) {
        emit(state.copyWith(processing: false, clearError: true));
        _resumeAvatarCarouselIfNeeded();
        return;
      }
      final file = result.files.first;
      if (file.size > _sourceMaxBytes) {
        emit(
          state.copyWith(
            processing: false,
            errorType: SignupAvatarErrorType.sizeExceeded,
            errorMaxKilobytes: _sourceMaxBytes ~/ 1024,
          ),
        );
        _resumeAvatarCarouselIfNeeded();
        return;
      }
      final bytes = await _loadPickedFileBytes(file);
      if (bytes == null || bytes.isEmpty) {
        emit(
          state.copyWith(
            processing: false,
            errorType: SignupAvatarErrorType.readFailed,
          ),
        );
        _resumeAvatarCarouselIfNeeded();
        return;
      }
      await _applyAvatarFromBytes(bytes);
    } on PlatformException {
      emit(
        state.copyWith(
          processing: false,
          errorType: SignupAvatarErrorType.openFailed,
        ),
      );
      _resumeAvatarCarouselIfNeeded();
    } on FileSystemException {
      emit(
        state.copyWith(
          processing: false,
          errorType: SignupAvatarErrorType.readFailed,
        ),
      );
      _resumeAvatarCarouselIfNeeded();
    }
  }

  void updateCropRect(Rect rect) {
    final avatar = state.avatar;
    if (state.processing) {
      _pendingCropRect = rect;
      return;
    }
    if (avatar == null || avatar.source != AvatarSource.upload) return;
    final constrained = _pipeline.constrainCropRect(avatar: avatar, rect: rect);
    if (avatar.cropRect == constrained) return;
    emit(
      state.copyWith(
        avatar: avatar.copyWith(cropRect: constrained),
        clearError: true,
      ),
    );
  }

  void resetCrop() {
    final avatar = state.avatar;
    if (avatar == null || avatar.source != AvatarSource.upload) return;
    final reset = _pipeline.initialCropRect(avatar);
    if (reset == null) return;
    if (state.processing) {
      _pendingCropRect = reset;
      return;
    }
    emit(
      state.copyWith(
        avatar: avatar.copyWith(cropRect: reset),
        clearError: true,
      ),
    );
  }

  Future<void> commitCrop([Rect? rect]) async {
    final avatar = state.avatar;
    if (avatar == null || avatar.source != AvatarSource.upload) return;
    if (state.processing) {
      _pendingCropRect =
          rect ?? avatar.cropRect ?? _pipeline.resolveCropRect(avatar);
      return;
    }
    final resolvedRect =
        rect ?? avatar.cropRect ?? _pipeline.resolveCropRect(avatar);
    if (resolvedRect == null) return;
    final nextAvatar = avatar.cropRect == resolvedRect
        ? avatar
        : avatar.copyWith(cropRect: resolvedRect);
    emit(state.copyWith(avatar: nextAvatar, clearError: true));
    await _refreshAvatarPayload(nextAvatar);
  }

  Future<void> _applyAvatarFromBytes(Uint8List bytes) async {
    _pendingCropRect = null;
    try {
      final avatar = await _pipeline.buildFromUpload(bytes);
      emit(
        state.copyWith(
          avatar: avatar,
          processing: false,
          backgroundColor: Colors.transparent,
          clearError: true,
        ),
      );
    } on FormatException {
      emit(
        state.copyWith(
          processing: false,
          errorType: SignupAvatarErrorType.invalidImage,
        ),
      );
      _resumeAvatarCarouselIfNeeded();
    }
  }

  Future<Uint8List?> _loadPickedFileBytes(PlatformFile file) async {
    if (file.bytes?.isNotEmpty == true) {
      final data = file.bytes!;
      return data.length > _sourceMaxBytes ? null : data;
    }
    final stream = file.readStream;
    if (stream != null) {
      final builder = BytesBuilder(copy: false);
      var total = 0;
      await for (final chunk in stream) {
        total += chunk.length;
        if (total > _sourceMaxBytes) {
          return null;
        }
        builder.add(chunk);
      }
      final data = builder.takeBytes();
      return data.isEmpty ? null : data;
    }
    final path = file.path;
    if (path == null || path.isEmpty) {
      return null;
    }
    final data = await File(path).readAsBytes();
    if (data.length > _sourceMaxBytes) {
      return null;
    }
    return data.isEmpty ? null : data;
  }

  Future<EditableAvatar?> _refreshAvatarPayload(EditableAvatar avatar) async {
    if (avatar.source != AvatarSource.upload) {
      return avatar;
    }
    final cropRect = _pipeline.resolveCropRect(avatar) ?? avatar.cropRect;
    if (cropRect == null || cropRect.width <= 0 || cropRect.height <= 0) {
      return avatar;
    }
    emit(state.copyWith(processing: true, clearError: true));
    try {
      final updated = await _pipeline.rebuildUploadPayload(
        avatar: avatar,
        cropRect: cropRect,
        insetFraction: 0,
        backgroundColor: Colors.transparent,
      );
      emit(
        state.copyWith(avatar: updated, processing: false, clearError: true),
      );
      _stopAvatarCarousel();
      return updated;
    } on FormatException {
      emit(
        state.copyWith(
          processing: false,
          errorType: SignupAvatarErrorType.processingFailed,
        ),
      );
      _resumeAvatarCarouselIfNeeded();
      return null;
    } finally {
      await _flushPendingCropIfNeeded();
    }
  }

  Future<void> _flushPendingCropIfNeeded() async {
    final pending = _pendingCropRect;
    if (pending == null) return;
    _pendingCropRect = null;
    if (state.processing) return;
    final avatar = state.avatar;
    if (avatar == null || avatar.source != AvatarSource.upload) return;
    final resolved = _pipeline.constrainCropRect(avatar: avatar, rect: pending);
    if (avatar.cropRect == resolved) return;
    final nextAvatar = avatar.copyWith(cropRect: resolved);
    emit(state.copyWith(avatar: nextAvatar, clearError: true));
    await _refreshAvatarPayload(nextAvatar);
  }

  Future<EditableAvatar> _buildAvatarFromTemplate({
    required AvatarTemplate template,
    required Color background,
    required ShadColorScheme colors,
  }) async {
    final resolvedBackground = template.hasAlphaBackground
        ? background
        : state.backgroundColor == Colors.transparent
        ? colors.accent
        : state.backgroundColor;
    final useTemplateInset =
        template.category != AvatarTemplateCategory.abstract;
    final padAlphaTemplate = template.hasAlphaBackground && useTemplateInset;
    final insetFraction = useTemplateInset
        ? (padAlphaTemplate
              ? avatarTransparentInsetFraction
              : avatarInsetFraction)
        : 0.0;
    return _pipeline.buildFromTemplate(
      template: template,
      background: resolvedBackground,
      colors: colors,
      insetFraction: insetFraction,
      cropSide: _avatarCarouselCropSide,
    );
  }

  Future<void> _startAvatarCarousel() async {
    if (!_shouldRunCarousel || _avatarCarouselTimer != null) {
      return;
    }
    final colors = _colors;
    if (colors == null) return;
    final generation = _carouselGeneration;

    if (state.carouselAvatar == null && _currentCarouselAvatar == null) {
      await _prefillCarousel(targetSize: 1, preferAbstract: true);
      if (generation != _carouselGeneration) {
        return;
      }
      if (state.hasUserSelectedAvatar ||
          state.processing ||
          _avatarCarouselTimer != null) {
        return;
      }
      if (!_showNextCarouselAvatar(colors, allowFallback: false)) {
        _showNextCarouselAvatar(colors, allowFallback: true);
      }
    }

    await _prefillCarousel(
      targetSize: _avatarCarouselInitialBuffer,
      preferAbstract: !_nonAbstractReady,
    );
    if (generation != _carouselGeneration) {
      return;
    }

    if (!_shouldRunCarousel || _avatarCarouselTimer != null) {
      return;
    }
    _scheduleCarouselTick();
  }

  void _stopAvatarCarousel() {
    _avatarCarouselTimer?.cancel();
    _avatarCarouselTimer = null;
    _carouselGeneration++;
  }

  Future<void> _resumeAvatarCarouselIfNeeded() async {
    if (!_shouldRunCarousel || _avatarCarouselTimer != null) {
      return;
    }
    _carouselEngine.startWarmupIfNeeded();
    await _startAvatarCarousel();
  }

  bool _showNextCarouselAvatar(
    ShadColorScheme colors, {
    bool allowFallback = true,
  }) {
    if (!_isCarouselVisible ||
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
      final entry = EditableAvatar(
        source: AvatarSource.template,
        payload: fallback,
        backgroundColor: fallbackBackground,
      );
      _currentCarouselAvatar = entry;
      emit(state.copyWith(carouselAvatar: entry, clearError: true));
      return true;
    }

    final entry = _carouselBuffer.removeAt(0);
    _currentCarouselAvatar = entry;
    emit(
      state.copyWith(
        carouselAvatar: entry,
        backgroundColor: entry.template?.hasAlphaBackground == true
            ? entry.backgroundColor ?? state.backgroundColor
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
    if (!_isCarouselVisible ||
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
    _carouselEngine.startWarmupIfNeeded();
    final remaining = targetSize - _carouselBuffer.length;
    if (remaining <= 0) return true;
    final context = AvatarCarouselBuildContext(
      colors: colors,
      currentBackground: state.backgroundColor,
    );
    final avatars = await _carouselEngine.prefill(
      targetSize: remaining,
      preferAbstract: preferAbstract,
      context: context,
      renderSpec: _resolveCarouselRenderSpec,
    );
    if (avatars.isNotEmpty) {
      _carouselBuffer.addAll(avatars);
    }
    if (avatars.isEmpty &&
        _carouselBuffer.isEmpty &&
        _isCarouselVisible &&
        !state.hasUserSelectedAvatar) {
      final fallbackBackground = state.backgroundColor == Colors.transparent
          ? colors.accent
          : state.backgroundColor;
      final fallback = _fallbackAvatarPayload(
        background: fallbackBackground,
        accent: colors.primary,
      );
      _carouselBuffer.add(
        EditableAvatar(
          source: AvatarSource.template,
          payload: fallback,
          backgroundColor: fallbackBackground,
        ),
      );
      return true;
    }
    return avatars.isNotEmpty;
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
    return _randomAvatarBackgroundColor();
  }

  Color _randomAvatarBackgroundColor() => _pipeline.randomBackground(_random);

  AvatarRenderSpec _resolveCarouselRenderSpec(
    AvatarTemplate template,
    AvatarCarouselBuildContext context,
  ) {
    final resolvedBackground = template.hasAlphaBackground
        ? _randomAvatarBackgroundColor()
        : context.currentBackground == Colors.transparent
        ? context.colors.accent
        : context.currentBackground;
    final useTemplateInset =
        template.category != AvatarTemplateCategory.abstract;
    final padAlphaTemplate = template.hasAlphaBackground && useTemplateInset;
    final insetFraction = useTemplateInset
        ? (padAlphaTemplate
              ? avatarTransparentInsetFraction
              : avatarInsetFraction)
        : 0.0;
    return AvatarRenderSpec(
      background: resolvedBackground,
      insetFraction: insetFraction,
      cropSide: _avatarCarouselCropSide,
    );
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
    final size = _pipeline.config.targetSize;
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

  void _scheduleCarouselTick() {
    _avatarCarouselTimer?.cancel();
    if (!_shouldRunCarousel) return;
    final generation = _carouselGeneration;
    _avatarCarouselTimer = Timer(_avatarCarouselInterval, () async {
      await _handleCarouselTick(generation);
    });
  }

  Future<void> _handleCarouselTick(int generation) async {
    if (generation != _carouselGeneration) {
      return;
    }
    if (!_shouldRunCarousel) {
      _stopAvatarCarousel();
      return;
    }
    final colors = _colors;
    if (colors == null) {
      _stopAvatarCarousel();
      return;
    }
    if (!_showNextCarouselAvatar(colors, allowFallback: false)) {
      _showNextCarouselAvatar(colors, allowFallback: true);
    }
    if (_carouselBuffer.length < _avatarCarouselSustainBuffer) {
      await _prefillCarousel(
        targetSize: _avatarCarouselSustainBuffer,
        preferAbstract: !_nonAbstractReady,
      );
    }
    if (generation != _carouselGeneration) {
      return;
    }
    if (!_shouldRunCarousel) {
      _stopAvatarCarousel();
      return;
    }
    _scheduleCarouselTick();
  }

  bool get _isCarouselVisible =>
      _carouselVisibility == _CarouselVisibility.visible;

  bool get _nonAbstractReady => _carouselEngine.nonAbstractReady;

  bool get _shouldRunCarousel =>
      _isCarouselVisible && !state.hasUserSelectedAvatar && !state.processing;
}

enum _CarouselVisibility { visible, hidden }
