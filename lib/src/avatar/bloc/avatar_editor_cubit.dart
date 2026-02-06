// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/avatar/models/avatar_models.dart';
import 'package:axichat/src/avatar/util/avatar_carousel_engine.dart';
import 'package:axichat/src/avatar/util/avatar_pipeline.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/services.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:shadcn_ui/shadcn_ui.dart';

part 'avatar_editor_cubit.freezed.dart';
part 'avatar_editor_state.dart';

enum AvatarEditorErrorType {
  openFailed,
  readFailed,
  invalidImage,
  processingFailed,
  templateLoadFailed,
  missingDraft,
  xmppDisconnected,
  publishRejected,
  publishTimeout,
  publishGeneric,
}

class AvatarEditorCubit extends Cubit<AvatarEditorState> {
  AvatarEditorCubit({
    required XmppService xmppService,
    required List<AvatarTemplate> templates,
    AvatarPipeline? pipeline,
  })  : _xmppService = xmppService,
        _templates = templates,
        _random = Random(),
        _pipeline = pipeline ??
            AvatarPipeline(
              config: const AvatarPipelineConfig(
                minCropSide: minCropSide,
                uploadMaxDimension: 0,
              ),
            ),
        super(const AvatarEditorState()) {
    _carouselEngine = AvatarCarouselEngine(
      pipeline: _pipeline,
      templates: _templates,
      random: _random,
      config: const AvatarCarouselEngineConfig(
        historyLimit: _avatarCarouselHistoryLimit,
      ),
    );
  }

  static const minCropSide = 48.0;
  static const avatarInsetFraction = 0.10;
  static const _maxUploadBytes = 20 * 1024 * 1024;
  static const _avatarCarouselInterval = Duration(seconds: 1);
  static const _avatarCarouselHistoryLimit = 12;
  static const _avatarCarouselCropSide = 100000.0;

  final XmppService _xmppService;
  final AvatarPipeline _pipeline;
  late final AvatarCarouselEngine _carouselEngine;
  final List<AvatarTemplate> _templates;
  final Random _random;
  Rect? _pendingCropRect;

  Timer? _avatarCarouselTimer;
  Avatar? _nextCarouselAvatar;
  ShadColorScheme? _carouselColors;
  bool _carouselEnabled = false;

  @override
  Future<void> close() async {
    _avatarCarouselTimer?.cancel();
    return super.close();
  }

  Future<void> initialize(ShadColorScheme colors) async {
    final initialBackground = state.backgroundColor == Colors.transparent
        ? colors.accent
        : state.backgroundColor;
    emit(state.copyWith(backgroundColor: initialBackground));
    await _loadInitialAvatar();
  }

  Future<void> setCarouselEnabled(bool enabled, ShadColorScheme colors) async {
    _carouselColors = colors;
    _carouselEnabled = enabled;
    if (!enabled) {
      _stopAvatarCarousel();
      return;
    }
    await _resumeAvatarCarouselIfNeeded();
  }

  void pauseCarousel() {
    _carouselEnabled = false;
    _stopAvatarCarousel();
  }

  void selectCarouselAvatar() {
    final selected = state.carouselAvatar;
    if (selected == null) return;
    pauseCarousel();
    _pendingCropRect = null;
    emit(
      state.copyWith(
        draftAvatar: selected,
        carouselAvatar: null,
        backgroundColor: selected.backgroundColor ?? state.backgroundColor,
        errorType: null,
      ),
    );
  }

  AvatarUploadPayload? selectedAvatarPayload() =>
      state.draftAvatar?.payload ?? state.carouselAvatar?.payload;

  Future<AvatarUploadPayload?> buildSelectedAvatarPayload() async {
    final draftAvatar = state.draftAvatar;
    if (draftAvatar == null) {
      return state.carouselAvatar?.payload;
    }
    final updated = await _refreshDraftPayload(
      draftAvatar,
      backgroundColor: state.backgroundColor,
    );
    return updated?.payload;
  }

  Future<void> shuffleCarousel(ShadColorScheme colors) async {
    _carouselColors = colors;
    _carouselEnabled = true;
    if (state.processing || state.shuffling || state.publishing) {
      return;
    }
    if (state.draftAvatar != null) {
      _stopAvatarCarousel();
      _pendingCropRect = null;
      emit(
        state.copyWith(
          draftAvatar: null,
          carouselAvatar: null,
          errorType: null,
        ),
      );
    }
    if (_nextCarouselAvatar == null) {
      await _warmNextCarouselAvatar();
    }
    if (_isCarouselBlocked()) return;
    await _advanceCarousel();
  }

  Future<void> shuffleCarouselBackground(ShadColorScheme colors) async {
    _carouselColors = colors;
    if (_isCarouselBlocked()) return;
    final current = state.carouselAvatar;
    if (current == null) return;
    final template = current.template;
    if (template == null) return;
    if (template.category == AvatarTemplateCategory.abstract) return;
    if (!template.hasAlphaBackground) return;
    final background = _randomAvatarBackgroundColor();
    final updated = await _buildAvatarFromTemplate(
      template: template,
      background: background,
      colors: colors,
    );
    if (_isCarouselBlocked()) return;
    emit(
      state.copyWith(
        carouselAvatar: updated,
        backgroundColor: background,
        errorType: null,
      ),
    );
  }

  Future<void> seedFromBytes(Uint8List bytes) async {
    if (bytes.isEmpty) return;
    _stopAvatarCarousel();
    _pendingCropRect = null;
    await _loadFromBytes(bytes, buildDraft: true);
  }

  Future<void> seedFromAvatarPath(String? avatarPath) async {
    final resolvedPath = avatarPath?.trim();
    if (resolvedPath == null || resolvedPath.isEmpty) {
      return;
    }
    try {
      final bytes = await _xmppService.loadAvatarBytes(resolvedPath);
      if (bytes == null || bytes.isEmpty) {
        return;
      }
      await seedFromBytes(bytes);
    } on FileSystemException {
      return;
    }
  }

  Future<void> seedRandomTemplate(ShadColorScheme colors) async {
    if (state.draftAvatar != null || state.processing) {
      return;
    }
    final template = _pickTemplate();
    if (template == null) return;
    _carouselEngine.markTemplateUsed(template);
    final background = template.hasAlphaBackground
        ? _randomAvatarBackgroundColor()
        : state.backgroundColor == Colors.transparent
            ? colors.accent
            : state.backgroundColor;
    await selectTemplate(template, colors, background: background);
  }

  Future<void> _loadInitialAvatar() async {
    final cached = _xmppService.cachedSelfAvatar;
    final stored = cached ?? await _xmppService.getOwnAvatar();
    final avatarPath = stored?.path?.trim();
    if (avatarPath == null || avatarPath.isEmpty) {
      return;
    }
    try {
      final bytes = await _xmppService.loadAvatarBytes(avatarPath);
      if (bytes == null || bytes.isEmpty) {
        return;
      }
      await _loadFromBytes(bytes, buildDraft: false);
    } on FileSystemException {
      return;
    }
  }

  Future<void> pickImage() async {
    _stopAvatarCarousel();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
        withReadStream: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.size > _maxUploadBytes) {
        emit(
          state.copyWith(
            errorType: AvatarEditorErrorType.readFailed,
          ),
        );
        return;
      }
      final bytes = await _loadPickedFileBytes(file);
      if (bytes == null || bytes.isEmpty) {
        emit(
          state.copyWith(
            errorType: AvatarEditorErrorType.readFailed,
          ),
        );
        return;
      }
      await _loadFromBytes(bytes, buildDraft: true);
    } on PlatformException {
      emit(
        state.copyWith(
          errorType: AvatarEditorErrorType.openFailed,
        ),
      );
    }
  }

  Future<void> selectTemplate(
    AvatarTemplate template,
    ShadColorScheme colors, {
    Color? background,
  }) async {
    _stopAvatarCarousel();
    _pendingCropRect = null;
    emit(
      state.copyWith(
        processing: true,
        draftAvatar: null,
        carouselAvatar: null,
        lastSavedPath: null,
        lastSavedHash: null,
        errorType: null,
      ),
    );
    try {
      final selectedBackground = background ?? state.backgroundColor;
      final avatar = await _buildAvatarFromTemplate(
        template: template,
        background: selectedBackground,
        colors: colors,
      );
      emit(
        state.copyWith(
          draftAvatar: avatar,
          backgroundColor: selectedBackground,
          errorType: null,
          processing: false,
        ),
      );
    } on FormatException {
      emit(
        state.copyWith(
          processing: false,
          draftAvatar: null,
          errorType: AvatarEditorErrorType.templateLoadFailed,
        ),
      );
    }
  }

  Future<void> setBackgroundColor(Color color, ShadColorScheme colors) async {
    emit(state.copyWith(backgroundColor: color));
    final template = state.draftAvatar?.template;
    final shouldRebuild = template != null &&
        template.category != AvatarTemplateCategory.abstract &&
        template.hasAlphaBackground;
    if (!shouldRebuild) return;
    emit(state.copyWith(processing: true, errorType: null));
    try {
      final updated = await _buildAvatarFromTemplate(
        template: template,
        background: color,
        colors: colors,
      );
      emit(
        state.copyWith(
          processing: false,
          draftAvatar: updated,
          errorType: null,
        ),
      );
    } on FormatException {
      emit(
        state.copyWith(
          processing: false,
          errorType: AvatarEditorErrorType.processingFailed,
        ),
      );
    }
  }

  Future<void> shuffleTemplate(ShadColorScheme colors) async {
    if (state.processing || state.publishing || state.shuffling) {
      return;
    }
    emit(state.copyWith(shuffling: true, errorType: null));
    final template = _pickTemplate();
    if (template == null) {
      emit(state.copyWith(shuffling: false));
      return;
    }
    _carouselEngine.markTemplateUsed(template);
    final background = template.hasAlphaBackground
        ? _randomAvatarBackgroundColor()
        : state.backgroundColor == Colors.transparent
            ? colors.accent
            : state.backgroundColor;
    try {
      await selectTemplate(template, colors, background: background);
    } finally {
      emit(state.copyWith(shuffling: false));
    }
  }

  Future<void> shuffleBackground(ShadColorScheme colors) async {
    if (state.processing || state.publishing || state.shuffling) {
      return;
    }
    final template = state.draftAvatar?.template;
    if (template == null) return;
    if (template.category == AvatarTemplateCategory.abstract) return;
    if (!template.hasAlphaBackground) return;
    final background = _randomAvatarBackgroundColor();
    await setBackgroundColor(background, colors);
  }

  void _stopAvatarCarousel() {
    _avatarCarouselTimer?.cancel();
    _avatarCarouselTimer = null;
  }

  Future<void> _resumeAvatarCarouselIfNeeded() async {
    if (_avatarCarouselTimer != null || _isCarouselBlocked()) return;
    await _startAvatarCarousel();
  }

  bool _isCarouselBlocked() {
    return !_carouselEnabled ||
        state.processing ||
        state.shuffling ||
        state.publishing ||
        state.draftAvatar != null;
  }

  Future<void> _startAvatarCarousel() async {
    if (_isCarouselBlocked() || _avatarCarouselTimer != null) {
      return;
    }
    await _warmNextCarouselAvatar();
    await _advanceCarousel();
    if (_isCarouselBlocked() || _avatarCarouselTimer != null) {
      return;
    }
    _scheduleCarouselTick();
  }

  void _scheduleCarouselTick() {
    if (_avatarCarouselTimer != null || _isCarouselBlocked()) return;
    _avatarCarouselTimer = Timer(_avatarCarouselInterval, () async {
      await _handleCarouselTick();
    });
  }

  Future<void> _handleCarouselTick() async {
    if (_isCarouselBlocked()) {
      _stopAvatarCarousel();
      return;
    }
    try {
      await _advanceCarousel();
    } finally {
      _avatarCarouselTimer = null;
    }
    if (_isCarouselBlocked()) {
      _stopAvatarCarousel();
      return;
    }
    _scheduleCarouselTick();
  }

  Future<void> _advanceCarousel() async {
    if (_isCarouselBlocked()) return;
    if (_nextCarouselAvatar == null) {
      await _warmNextCarouselAvatar();
    }
    final next = _nextCarouselAvatar;
    if (next == null || _isCarouselBlocked()) return;
    emit(
      state.copyWith(
        carouselAvatar: next,
        backgroundColor: next.backgroundColor ?? state.backgroundColor,
        errorType: null,
      ),
    );
    _nextCarouselAvatar = null;
    await _warmNextCarouselAvatar();
  }

  Future<void> _warmNextCarouselAvatar() async {
    if (_nextCarouselAvatar != null || _isCarouselBlocked()) {
      return;
    }
    final colors = _carouselColors;
    if (colors == null) return;
    final context = AvatarCarouselBuildContext(
      colors: colors,
      currentBackground: state.backgroundColor,
    );
    _nextCarouselAvatar = await _carouselEngine.buildNext(
      context: context,
      renderSpec: _resolveCarouselRenderSpec,
    );
  }

  void updateCropRect(Rect rect) {
    final draftAvatar = state.draftAvatar;
    if (state.processing) {
      _pendingCropRect = rect;
      return;
    }
    if (draftAvatar == null) return;
    final clamped = _pipeline.constrainCropRect(
      avatar: draftAvatar,
      rect: rect,
    );
    if (draftAvatar.cropRect == clamped) return;
    emit(state.copyWith(draftAvatar: draftAvatar.copyWith(cropRect: clamped)));
  }

  void resizeCropRect(double factor) {
    final draftAvatar = state.draftAvatar;
    final imageWidth = draftAvatar?.sourceWidth?.toDouble();
    final imageHeight = draftAvatar?.sourceHeight?.toDouble();
    if (draftAvatar == null || imageWidth == null || imageHeight == null) {
      return;
    }
    final clampedFactor = factor.clamp(0.0, 1.0);
    final maxSide = min(imageWidth, imageHeight);
    final side = minCropSide + (maxSide - minCropSide) * clampedFactor;
    final current = draftAvatar.cropRect ??
        _pipeline.initialCropRect(draftAvatar) ??
        Rect.fromLTWH(0, 0, maxSide, maxSide);
    final next = Rect.fromCenter(
      center: current.center,
      width: side,
      height: side,
    );
    final constrained =
        _pipeline.constrainCropRect(avatar: draftAvatar, rect: next);
    emit(
      state.copyWith(
        draftAvatar: draftAvatar.copyWith(cropRect: constrained),
      ),
    );
  }

  void resetCrop() {
    final draftAvatar = state.draftAvatar;
    if (draftAvatar == null) return;
    final reset = _pipeline.initialCropRect(draftAvatar);
    if (reset == null) return;
    if (state.processing) {
      _pendingCropRect = reset;
      return;
    }
    emit(state.copyWith(draftAvatar: draftAvatar.copyWith(cropRect: reset)));
  }

  Future<void> commitCrop([Rect? rect]) async {
    final draftAvatar = state.draftAvatar;
    if (draftAvatar == null || draftAvatar.source != AvatarSource.upload) {
      return;
    }
    if (state.processing) {
      _pendingCropRect = rect ??
          draftAvatar.cropRect ??
          _pipeline.resolveCropRect(draftAvatar);
      return;
    }
    final resolvedRect =
        rect ?? draftAvatar.cropRect ?? _pipeline.resolveCropRect(draftAvatar);
    if (resolvedRect == null) return;
    final nextAvatar = draftAvatar.cropRect == resolvedRect
        ? draftAvatar
        : draftAvatar.copyWith(cropRect: resolvedRect);
    emit(state.copyWith(draftAvatar: nextAvatar));
    await _refreshDraftPayload(
      nextAvatar,
      backgroundColor: state.backgroundColor,
    );
  }

  Future<void> publish({
    required Avatar? draftAvatar,
    required Color backgroundColor,
  }) async {
    if (draftAvatar == null) {
      emit(
        state.copyWith(
          errorType: AvatarEditorErrorType.missingDraft,
        ),
      );
      return;
    }
    if (!_xmppService.connected) {
      emit(
        state.copyWith(
          errorType: AvatarEditorErrorType.xmppDisconnected,
        ),
      );
      return;
    }
    emit(state.copyWith(publishing: true, errorType: null));
    try {
      final refreshed = await _refreshDraftPayload(
        draftAvatar,
        backgroundColor: backgroundColor,
      );
      if (refreshed == null) {
        emit(state.copyWith(publishing: false));
        return;
      }
      final payload = refreshed.payload;
      final result = await _xmppService.publishAvatar(payload);
      emit(
        state.copyWith(
          publishing: false,
          lastSavedPath: result.path,
          lastSavedHash: result.hash,
          errorType: null,
        ),
      );
    } on XmppAvatarException catch (error) {
      final cause = error.wrapped;
      final errorType = switch (cause) {
        TimeoutException() => AvatarEditorErrorType.publishTimeout,
        mox.PubSubError() => AvatarEditorErrorType.publishGeneric,
        mox.AvatarError() => AvatarEditorErrorType.publishRejected,
        _ => AvatarEditorErrorType.publishGeneric,
      };
      emit(
        state.copyWith(
          publishing: false,
          errorType: errorType,
        ),
      );
    }
  }

  Future<Avatar?> _refreshDraftPayload(
    Avatar draftAvatar, {
    required Color backgroundColor,
  }) async {
    if (draftAvatar.source != AvatarSource.upload) {
      return draftAvatar;
    }
    final cropRect =
        _pipeline.resolveCropRect(draftAvatar) ?? draftAvatar.cropRect;
    if (cropRect == null || cropRect.width <= 0 || cropRect.height <= 0) {
      return draftAvatar;
    }
    emit(state.copyWith(processing: true, errorType: null));
    try {
      final updated = await _pipeline.rebuildUploadPayload(
        avatar: draftAvatar,
        cropRect: cropRect,
        insetFraction: avatarInsetFraction,
        backgroundColor: backgroundColor,
      );
      emit(
        state.copyWith(
          processing: false,
          draftAvatar: updated,
          carouselAvatar: null,
          errorType: null,
        ),
      );
      return updated;
    } on FormatException {
      emit(
        state.copyWith(
          processing: false,
          draftAvatar: null,
          errorType: AvatarEditorErrorType.processingFailed,
        ),
      );
      return null;
    } finally {
      await _flushPendingCropIfNeeded();
    }
  }

  AvatarTemplate? _pickTemplate() =>
      _carouselEngine.pickTemplate(preferAbstract: false);

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
    final insetFraction = useTemplateInset ? avatarInsetFraction : 0.0;
    return AvatarRenderSpec(
      background: resolvedBackground,
      insetFraction: insetFraction,
      cropSide: _avatarCarouselCropSide,
    );
  }

  Future<Avatar> _buildAvatarFromTemplate({
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
    final insetFraction = useTemplateInset ? avatarInsetFraction : 0.0;
    return _pipeline.buildFromTemplate(
      template: template,
      background: resolvedBackground,
      colors: colors,
      insetFraction: insetFraction,
      cropSide: _avatarCarouselCropSide,
    );
  }

  Future<void> _loadFromBytes(
    Uint8List bytes, {
    required bool buildDraft,
  }) async {
    emit(
      state.copyWith(
        processing: true,
        errorType: null,
        carouselAvatar: null,
      ),
    );
    _pendingCropRect = null;
    try {
      final avatar = await _pipeline.buildFromUpload(bytes);
      emit(
        state.copyWith(
          draftAvatar: buildDraft ? avatar : null,
          carouselAvatar: null,
          lastSavedPath: null,
          lastSavedHash: null,
          errorType: null,
          processing: false,
        ),
      );
      if (!buildDraft) {
        return;
      }
    } on FormatException {
      emit(
        state.copyWith(
          processing: false,
          errorType: AvatarEditorErrorType.invalidImage,
        ),
      );
    }
  }

  Future<void> _flushPendingCropIfNeeded() async {
    final pending = _pendingCropRect;
    if (pending == null) return;
    _pendingCropRect = null;
    if (state.processing) return;
    final draftAvatar = state.draftAvatar;
    if (draftAvatar == null || draftAvatar.source != AvatarSource.upload) {
      return;
    }
    final resolved = _pipeline.constrainCropRect(
      avatar: draftAvatar,
      rect: pending,
    );
    if (draftAvatar.cropRect == resolved) return;
    final nextAvatar = draftAvatar.copyWith(cropRect: resolved);
    emit(state.copyWith(draftAvatar: nextAvatar));
    await _refreshDraftPayload(
      nextAvatar,
      backgroundColor: state.backgroundColor,
    );
  }

  Future<Uint8List?> _loadPickedFileBytes(PlatformFile file) async {
    final data = file.bytes;
    if (data != null && data.isNotEmpty) {
      return data.length > _maxUploadBytes ? null : data;
    }
    final stream = file.readStream;
    if (stream == null) {
      return null;
    }
    final builder = BytesBuilder(copy: false);
    var total = 0;
    await for (final chunk in stream) {
      total += chunk.length;
      if (total > _maxUploadBytes) {
        return null;
      }
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    return bytes.isEmpty ? null : bytes;
  }
}
