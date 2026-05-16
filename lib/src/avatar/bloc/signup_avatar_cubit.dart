// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:axichat/src/avatar/avatar_editor_mode.dart';
import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/avatar/editing/avatar_carousel_engine.dart';
import 'package:axichat/src/avatar/editing/avatar_carousel_session.dart';
import 'package:axichat/src/avatar/editing/editable_avatar.dart';
import 'package:axichat/src/avatar/editing/avatar_pipeline.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart' show AvatarUploadPayload;
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    _carousel = AvatarCarouselSession(
      engine: _carouselEngine,
      interval: avatarCarouselInterval,
      initialBufferSize: _avatarCarouselInitialBuffer,
      sustainBufferSize: _avatarCarouselSustainBuffer,
      canRun: () => _shouldRunCarousel,
      currentBackground: () => state.backgroundColor,
      renderSpec: _resolveCarouselRenderSpec,
      preferAbstract: () => !_nonAbstractReady,
      fallbackAvatar: _buildCarouselFallback,
      onRunningChanged: _setCarouselRunning,
      onPreviewChanged: _emitCarouselFrame,
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
  static const avatarCarouselInterval = Duration(seconds: 4);
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
  late final AvatarCarouselSession _carousel;
  _CarouselVisibility _carouselVisibility = _CarouselVisibility.visible;

  @override
  Future<void> close() async {
    _carousel.reset();
    return super.close();
  }

  Future<void> initialize(ShadColorScheme colors) async {
    emit(state.copyWith(backgroundColor: colors.accent, clearError: true));
    if (_isCarouselVisible) {
      await _carousel.start(colors);
    }
  }

  Future<void> setVisible(bool visible, ShadColorScheme colors) async {
    _carouselVisibility = visible
        ? _CarouselVisibility.visible
        : _CarouselVisibility.hidden;
    if (!visible) {
      _carousel.stop();
      return;
    }
    await initialize(colors);
    await _resumeAvatarCarouselIfNeeded();
  }

  void pauseCarousel() {
    _carouselVisibility = _CarouselVisibility.hidden;
    _carousel.stop();
  }

  void selectCarouselAvatar() {
    if (state.processing) return;
    final selected = state.carouselAvatar ?? _carousel.currentAvatar;
    if (selected == null) return;
    _carousel.reset();
    _pendingCropRect = null;
    emit(
      state.copyWith(
        avatar: selected,
        carouselAvatar: null,
        carouselRunning: false,
        carouselStartedAt: null,
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
    if (state.processing) return;

    _carouselVisibility = _CarouselVisibility.hidden;

    final previewAvatar = await _carousel.manualPreview(colors);
    if (previewAvatar == null) {
      return;
    }
    _pendingCropRect = null;
    emit(
      state.copyWith(
        avatar: null,
        carouselAvatar: previewAvatar,
        carouselRunning: false,
        carouselStartedAt: null,
        clearError: true,
      ),
    );
  }

  Future<void> seedAvatarFromBytes(Uint8List bytes) async {
    if (bytes.isEmpty) return;
    _carousel.reset();
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
    if (state.processing || !state.canShuffleBackground) {
      return;
    }
    final activeAvatar =
        state.carouselAvatar ?? state.avatar ?? _carousel.currentAvatar;
    final template = activeAvatar?.template;
    if (template == null) {
      return;
    }
    final background = _randomAvatarBackgroundColor();
    emit(
      state.copyWith(backgroundLocked: true, lockedBackgroundColor: background),
    );
    final previewingCandidate =
        state.carouselAvatar != null || state.avatar == null;
    if (previewingCandidate) {
      _carousel.reset();
      emit(state.copyWith(processing: true, clearError: true));
      try {
        final updated = await _buildAvatarFromTemplate(
          template: template,
          background: background,
          colors: colors,
        );
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
    if (state.processing) return;

    _carousel.reset();
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
    _carousel.reset();

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
          carouselRunning: false,
          carouselStartedAt: null,
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
      _carousel.reset();
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

  Future<void> _resumeAvatarCarouselIfNeeded() async {
    await _carousel.resume();
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

  bool get _isCarouselVisible =>
      _carouselVisibility == _CarouselVisibility.visible;

  bool get _nonAbstractReady => _carouselEngine.nonAbstractReady;

  bool get _shouldRunCarousel =>
      _isCarouselVisible && !state.hasUserSelectedAvatar && !state.processing;

  EditableAvatar _buildCarouselFallback(ShadColorScheme colors) {
    final fallbackBackground = state.backgroundColor == Colors.transparent
        ? colors.accent
        : state.backgroundColor;
    return buildAvatarCarouselFallback(
      pipeline: _pipeline,
      background: fallbackBackground,
      accent: colors.primary,
    );
  }

  void _emitCarouselFrame(AvatarCarouselFrame frame) {
    final avatar = frame.avatar;
    emit(
      state.copyWith(
        carouselAvatar: avatar,
        carouselRunning: true,
        carouselStartedAt: frame.startedAt,
        backgroundColor: avatar.template?.hasAlphaBackground == true
            ? avatar.backgroundColor ?? state.backgroundColor
            : state.backgroundColor,
        clearError: true,
      ),
    );
  }

  void _setCarouselRunning(bool running) {
    if (state.carouselRunning == running &&
        (running || state.carouselStartedAt == null)) {
      return;
    }
    emit(
      state.copyWith(
        carouselRunning: running,
        carouselStartedAt: running ? state.carouselStartedAt : null,
      ),
    );
  }
}

enum _CarouselVisibility { visible, hidden }
