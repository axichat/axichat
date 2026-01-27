// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:axichat/src/avatar/avatar_editor_mode.dart';
import 'package:axichat/src/avatar/avatar_image_utils.dart';
import 'package:axichat/src/avatar/avatar_templates.dart';
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

extension SignupAvatarErrorTypeX on SignupAvatarErrorType {
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
      SignupAvatarErrorType.sizeExceeded =>
        l10n.signupAvatarSizeError(maxKilobytes ?? fallbackMaxKilobytes),
      SignupAvatarErrorType.processingFailed => hasSourceBytes
          ? l10n.signupAvatarProcessError
          : l10n.signupAvatarRenderError,
    };
  }
}

class SignupAvatarCubit extends Cubit<SignupAvatarState> {
  SignupAvatarCubit({List<AvatarTemplate>? templates})
      : _templates = templates ?? buildDefaultAvatarTemplates(),
        super(const SignupAvatarState(backgroundColor: Colors.transparent)) {
    _abstractTemplates = _templates
        .where(
          (template) => template.category == AvatarTemplateCategory.abstract,
        )
        .toList();
    _nonAbstractTemplates = _templates
        .where(
          (template) => template.category != AvatarTemplateCategory.abstract,
        )
        .toList();
  }

  static const int avatarTargetSize = 256;
  static const int avatarMaxBytes = 64 * 1024;
  static const int avatarMaxKilobytes = avatarMaxBytes ~/ 1024;
  static const int avatarMinJpegQuality = 35;
  static const int avatarQualityStep = 5;
  static const int _sourceMaxDimension = 768;
  static const int _sourceMaxBytes = 8 * 1024 * 1024;
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
  _NonAbstractWarmupState _nonAbstractWarmupState =
      _NonAbstractWarmupState.pending;
  _CarouselVisibility _carouselVisibility = _CarouselVisibility.visible;
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

  Future<void> initialize(ShadColorScheme colors) async {
    _colors = colors;
    if (_abstractOnlyUntil != null) return;
    _abstractOnlyUntil = DateTime.now().add(_abstractWarmupDuration);
    emit(state.copyWith(backgroundColor: colors.accent, clearError: true));
    if (_isCarouselVisible) {
      await _startAvatarCarousel();
    }
  }

  bool get _abstractWarmupActive {
    final until = _abstractOnlyUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  Future<void> setVisible(bool visible, ShadColorScheme colors) async {
    _colors = colors;
    _carouselVisibility =
        visible ? _CarouselVisibility.visible : _CarouselVisibility.hidden;
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

  AvatarUploadPayload? selectedAvatarPayload() =>
      state.avatar ?? _currentCarouselAvatar?.payload;

  Future<void> shuffleCarousel(ShadColorScheme colors) async {
    _colors = colors;
    _carouselVisibility = _CarouselVisibility.visible;
    if (state.processing) return;
    if (state.hasUserSelectedAvatar ||
        state.sourceBytes != null ||
        state.activeTemplate != null ||
        state.activeCategory != null) {
      _carouselBuffer.clear();
      _currentCarouselAvatar = null;
      _stopAvatarCarousel();
      emit(
        state.copyWith(
          avatar: null,
          avatarPreviewBytes: null,
          carouselPreviewBytes: null,
          activeTemplate: null,
          activeCategory: null,
          backgroundLocked: false,
          lockedBackgroundColor: null,
          clearCrop: true,
          clearError: true,
        ),
      );
    }
    if (_carouselBuffer.isEmpty) {
      await _prefillCarousel(targetSize: 1, preferAbstract: !_nonAbstractReady);
    }
    if (state.processing ||
        state.hasUserSelectedAvatar ||
        !_isCarouselVisible) {
      return;
    }
    if (!_showNextCarouselAvatar(colors, allowFallback: false)) {
      _showNextCarouselAvatar(colors, allowFallback: true);
    }
    await _prefillCarousel(
      targetSize: _avatarCarouselSustainBuffer,
      preferAbstract: !_nonAbstractReady,
    );
  }

  Future<void> shuffleCarouselBackground(ShadColorScheme colors) async {
    _colors = colors;
    _carouselVisibility = _CarouselVisibility.visible;
    if (state.processing || state.hasUserSelectedAvatar) return;
    final current = _currentCarouselAvatar;
    final template = current?.template;
    if (current == null || template == null) return;
    if (template.category == AvatarTemplateCategory.abstract) return;
    if (!template.hasAlphaBackground) return;
    final background = _randomAvatarBackgroundColor(colors);
    emit(state.copyWith(processing: true, clearError: true));
    try {
      final payload = await _buildAvatarPayloadFromTemplate(
        template: template,
        background: background,
        colors: colors,
      );
      if (state.hasUserSelectedAvatar || !_isCarouselVisible) {
        return;
      }
      final updated = _CarouselAvatar(
        payload: payload,
        template: template,
        category: template.category,
        background: background,
      );
      _currentCarouselAvatar = updated;
      emit(
        state.copyWith(
          processing: false,
          carouselPreviewBytes: payload.bytes,
          activeTemplate: template,
          activeCategory: template.category,
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
      _resumeAvatarCarouselIfNeeded();
    }
  }

  Future<void> seedAvatarFromBytes(Uint8List bytes) async {
    if (bytes.isEmpty) return;
    _stopAvatarCarousel();
    _currentCarouselAvatar = null;
    emit(
      state.copyWith(
        avatar: null,
        avatarPreviewBytes: null,
        carouselPreviewBytes: null,
        processing: true,
        clearError: true,
      ),
    );
    await _applyAvatarFromBytes(bytes);
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
      state.copyWith(backgroundLocked: true, lockedBackgroundColor: background),
    );
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
    _sourceImage = null;

    emit(
      state.copyWith(
        processing: true,
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
      _pushRecentCarouselAvatar(template.id);
      if (!_nonAbstractReady &&
          template.category != AvatarTemplateCategory.abstract) {
        _nonAbstractWarmupState = _NonAbstractWarmupState.ready;
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
    final image = _sourceImage;
    if (image == null) return;
    final constrained = _constrainCropRect(rect, image);
    if (state.cropRect == constrained) return;
    emit(
      state.copyWith(cropRect: constrained, processing: true, clearError: true),
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
    emit(state.copyWith(cropRect: reset, processing: true, clearError: true));
    _scheduleRebuild();
  }

  void _scheduleRebuild() {
    _rebuildTimer?.cancel();
    _rebuildTimer = Timer(
      _rebuildDelay,
      () async {
        await _rebuildAvatar();
      },
    );
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
      final preparedBytes = prepared.bytes;
      final decoded = await decodeImageBytes(preparedBytes);
      if (decoded == null) {
        emit(
          state.copyWith(
            processing: false,
            errorType: SignupAvatarErrorType.invalidImage,
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
          cropRect: _fallbackCropRect(imageWidth: width, imageHeight: height),
          activeTemplate: null,
          activeCategory: null,
          backgroundColor: Colors.transparent,
          clearError: true,
        ),
      );
      await _rebuildAvatar();
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

  Future<void> _rebuildAvatar() async {
    _rebuildTimer?.cancel();
    final image = _sourceImage;
    final sourceBytes = state.sourceBytes;
    if (image == null || sourceBytes == null || sourceBytes.isEmpty) {
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
      emit(
        state.copyWith(
          processing: false,
          errorType: SignupAvatarErrorType.sizeExceeded,
          errorMaxKilobytes: avatarMaxKilobytes,
        ),
      );
      _resumeAvatarCarouselIfNeeded();
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
    if (!_shouldRunCarousel || _avatarCarouselTimer != null) {
      return;
    }
    final colors = _colors;
    if (colors == null) return;

    if (state.carouselPreviewBytes == null && _currentCarouselAvatar == null) {
      await _prefillCarousel(targetSize: 1, preferAbstract: true);
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

    if (!_shouldRunCarousel || _avatarCarouselTimer != null) {
      return;
    }
    _scheduleCarouselTick();
  }

  void _stopAvatarCarousel() {
    _avatarCarouselTimer?.cancel();
    _avatarCarouselTimer = null;
  }

  Future<void> _resumeAvatarCarouselIfNeeded() async {
    if (!_shouldRunCarousel ||
        _abstractOnlyUntil == null ||
        _avatarCarouselTimer != null) {
      return;
    }
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
    if (!_nonAbstractReady &&
        entry.category != AvatarTemplateCategory.abstract) {
      _nonAbstractWarmupState = _NonAbstractWarmupState.ready;
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
    final warmupActive = _abstractWarmupActive;

    if (!warmupActive &&
        preferAbstract &&
        !_nonAbstractReady &&
        _nonAbstractWarmupState != _NonAbstractWarmupState.warming &&
        _nonAbstractTemplates.isNotEmpty) {
      _nonAbstractWarmupState = _NonAbstractWarmupState.warming;
      await _warmFirstNonAbstractAvatar(colors);
    }

    var added = 0;
    var attempts = 0;
    const maxAttempts = 6;
    try {
      while (_isCarouselVisible &&
          !state.hasUserSelectedAvatar &&
          !state.processing &&
          _carouselBuffer.length < targetSize &&
          attempts < maxAttempts) {
        final useAbstractOnly =
            (warmupActive || (preferAbstract && !_nonAbstractReady)) &&
                _abstractTemplates.isNotEmpty;
        AvatarTemplate? template = useAbstractOnly
            ? _pickFromPool(_abstractTemplates, bag: _abstractCarouselBag)
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
        if (!_nonAbstractReady &&
            template.category != AvatarTemplateCategory.abstract) {
          _nonAbstractWarmupState = _NonAbstractWarmupState.ready;
        }
        added++;
      }
      if (added == 0 &&
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
          _CarouselAvatar(
            payload: fallback,
            template: null,
            category: AvatarTemplateCategory.abstract,
            background: fallbackBackground,
          ),
        );
        return true;
      }
    } on FormatException {
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
      if (!_isCarouselVisible) return;
      _nonAbstractWarmupState = _NonAbstractWarmupState.ready;
      _carouselBuffer.add(
        _CarouselAvatar(
          payload: payload,
          template: template,
          category: template.category,
          background: background,
        ),
      );
    } on FormatException {
      // Ignore warmup failures; fallback handled by buffer.
    } finally {
      if (_nonAbstractWarmupState != _NonAbstractWarmupState.ready) {
        _nonAbstractWarmupState = _NonAbstractWarmupState.pending;
      }
    }
  }

  AvatarTemplate? _pickCarouselTemplate() {
    final hasAbstract = _abstractTemplates.isNotEmpty;
    final hasOther = _nonAbstractTemplates.isNotEmpty;
    if (!hasAbstract && !hasOther) {
      return null;
    }
    if (!hasOther) {
      return _pickFromPool(_abstractTemplates, bag: _abstractCarouselBag);
    }
    if (!hasAbstract) {
      return _pickFromPool(_nonAbstractTemplates, bag: _nonAbstractCarouselBag);
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
    final fallback = _fallbackCropRect(imageWidth: width, imageHeight: height);
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

  void _scheduleCarouselTick() {
    _avatarCarouselTimer?.cancel();
    if (!_shouldRunCarousel) return;
    _avatarCarouselTimer = Timer(
      _avatarCarouselInterval,
      () async {
        await _handleCarouselTick();
      },
    );
  }

  Future<void> _handleCarouselTick() async {
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
    if (!_shouldRunCarousel) {
      _stopAvatarCarousel();
      return;
    }
    _scheduleCarouselTick();
  }

  bool get _isCarouselVisible =>
      _carouselVisibility == _CarouselVisibility.visible;

  bool get _nonAbstractReady =>
      _nonAbstractWarmupState == _NonAbstractWarmupState.ready;

  bool get _shouldRunCarousel =>
      _isCarouselVisible && !state.hasUserSelectedAvatar && !state.processing;
}

class _AvatarSizeException implements Exception {
  const _AvatarSizeException();
}

class _AvatarSelection {
  const _AvatarSelection({required this.template, required this.background});

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

enum _CarouselVisibility { visible, hidden }

enum _NonAbstractWarmupState { pending, warming, ready }
