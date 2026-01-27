// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/avatar/models/avatar_models.dart';
import 'package:axichat/src/common/avatar_background.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/services.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';

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

extension AvatarEditorErrorTypeX on AvatarEditorErrorType {
  String resolve(AppLocalizations l10n) => switch (this) {
        AvatarEditorErrorType.openFailed => l10n.avatarOpenError,
        AvatarEditorErrorType.readFailed => l10n.avatarReadError,
        AvatarEditorErrorType.invalidImage => l10n.avatarInvalidImageError,
        AvatarEditorErrorType.processingFailed => l10n.avatarProcessError,
        AvatarEditorErrorType.templateLoadFailed =>
          l10n.avatarTemplateLoadError,
        AvatarEditorErrorType.missingDraft => l10n.avatarMissingDraftError,
        AvatarEditorErrorType.xmppDisconnected =>
          l10n.avatarXmppDisconnectedError,
        AvatarEditorErrorType.publishRejected =>
          l10n.avatarPublishRejectedError,
        AvatarEditorErrorType.publishTimeout => l10n.avatarPublishTimeoutError,
        AvatarEditorErrorType.publishGeneric => l10n.avatarPublishGenericError,
      };
}

class AvatarEditorCubit extends Cubit<AvatarEditorState> {
  AvatarEditorCubit({
    required XmppService xmppService,
    required List<AvatarTemplate> templates,
  })  : _xmppService = xmppService,
        _templates = templates,
        super(const AvatarEditorState());

  static const minCropSide = 48.0;
  static const avatarInsetFraction = 0.10;
  static const _targetSize = 256;
  static const _maxBytes = 64 * 1024;
  static const _minQuality = 55;
  static const _qualityStep = 5;
  static const _maxUploadBytes = 20 * 1024 * 1024;
  static const _avatarCarouselInterval = Duration(seconds: 1);
  static const _avatarCarouselHistoryLimit = 12;
  static const _avatarCarouselCropSide = 100000.0;

  final XmppService _xmppService;
  final List<AvatarTemplate> _templates;
  late final List<AvatarTemplate> _abstractTemplates = _templates
      .where((template) => template.category == AvatarTemplateCategory.abstract)
      .toList(growable: false);
  late final List<AvatarTemplate> _nonAbstractTemplates = _templates
      .where((template) => template.category != AvatarTemplateCategory.abstract)
      .toList(growable: false);
  late final Map<String, AvatarTemplate> _templateByKey = {
    for (final template in _templates) _templateKey(template): template,
  };
  late final List<String> _abstractTemplateKeys =
      _abstractTemplates.map(_templateKey).toList(growable: false);
  late final List<String> _nonAbstractTemplateKeys =
      _nonAbstractTemplates.map(_templateKey).toList(growable: false);
  final List<String> _recentTemplateKeys = <String>[];
  final _random = Random();

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

  AvatarUploadPayload? selectedAvatarPayload() =>
      state.draftAvatar?.payload ?? state.carouselAvatar?.payload;

  Future<AvatarUploadPayload?> buildSelectedAvatarPayload() async {
    final draftAvatar = state.draftAvatar;
    if (draftAvatar == null) {
      return state.carouselAvatar?.payload;
    }
    final updated = await _refreshDraftPayload(draftAvatar);
    return updated?.payload;
  }

  Future<void> shuffleCarousel(ShadColorScheme colors) async {
    _carouselColors = colors;
    _carouselEnabled = true;
    if (_isCarouselBlocked()) return;
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
    await _loadFromBytes(bytes, buildDraft: true);
  }

  Future<void> seedRandomTemplate(ShadColorScheme colors) async {
    if (state.draftAvatar != null || state.processing) {
      return;
    }
    final template = _pickTemplate();
    if (template == null) return;
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
    _avatarCarouselTimer = Timer.periodic(_avatarCarouselInterval, (_) async {
      await _advanceCarousel();
    });
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
    final template = _pickTemplate();
    if (template == null) return;
    final background = template.hasAlphaBackground
        ? _randomAvatarBackgroundColor()
        : state.backgroundColor == Colors.transparent
            ? colors.accent
            : state.backgroundColor;
    _nextCarouselAvatar = await _buildAvatarFromTemplate(
      template: template,
      background: background,
      colors: colors,
    );
  }

  void updateCropRect(Rect rect) {
    final draftAvatar = state.draftAvatar;
    final imageWidth = draftAvatar?.sourceWidth?.toDouble();
    final imageHeight = draftAvatar?.sourceHeight?.toDouble();
    if (imageWidth == null || imageHeight == null) return;
    final clamped = _constrainRect(rect, imageWidth, imageHeight);
    if (draftAvatar?.cropRect == clamped) return;
    emit(state.copyWith(draftAvatar: draftAvatar?.copyWith(cropRect: clamped)));
  }

  void resizeCropRect(double factor) {
    final draftAvatar = state.draftAvatar;
    final imageWidth = draftAvatar?.sourceWidth?.toDouble();
    final imageHeight = draftAvatar?.sourceHeight?.toDouble();
    if (imageWidth == null || imageHeight == null) return;
    final clampedFactor = factor.clamp(0.0, 1.0);
    final maxSide = min(imageWidth, imageHeight);
    final side = minCropSide + (maxSide - minCropSide) * clampedFactor;
    final current = draftAvatar?.cropRect ??
        _initialCropRect(imageWidth: imageWidth, imageHeight: imageHeight);
    final next = Rect.fromCenter(
      center: current.center,
      width: side,
      height: side,
    );
    final constrained = _constrainRect(next, imageWidth, imageHeight);
    emit(
      state.copyWith(
        draftAvatar: draftAvatar?.copyWith(cropRect: constrained),
      ),
    );
  }

  void resetCrop() {
    final draftAvatar = state.draftAvatar;
    final imageWidth = draftAvatar?.sourceWidth?.toDouble();
    final imageHeight = draftAvatar?.sourceHeight?.toDouble();
    if (imageWidth == null || imageHeight == null) return;
    final reset = _initialCropRect(
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
    emit(state.copyWith(draftAvatar: draftAvatar?.copyWith(cropRect: reset)));
  }

  Future<void> publish() async {
    final draftAvatar = state.draftAvatar;
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
      final refreshed = await _refreshDraftPayload(draftAvatar);
      final payload = refreshed?.payload ?? draftAvatar.payload;
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

  Future<Avatar?> _refreshDraftPayload(Avatar draftAvatar) async {
    if (draftAvatar.source != AvatarSource.upload) {
      return draftAvatar;
    }
    final cropRect = draftAvatar.resolveCropRect(minCropSide: minCropSide) ??
        draftAvatar.cropRect;
    if (cropRect == null || cropRect.width <= 0 || cropRect.height <= 0) {
      return draftAvatar;
    }
    emit(state.copyWith(processing: true, errorType: null));
    try {
      final updated = await draftAvatar.rebuildUploadPayload(
        cropRect: cropRect,
        targetSize: _targetSize,
        maxBytes: _maxBytes,
        insetFraction: avatarInsetFraction,
        minJpegQuality: _minQuality,
        qualityStep: _qualityStep,
        backgroundColor: state.backgroundColor,
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
    }
  }

  Rect _initialCropRect({
    required double imageWidth,
    required double imageHeight,
  }) {
    final side = min(imageWidth, imageHeight);
    final left = (imageWidth - side) / 2;
    final top = (imageHeight - side) / 2;
    return _constrainRect(
      Rect.fromLTWH(left, top, side, side),
      imageWidth,
      imageHeight,
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
    return Rect.fromLTWH(
      left.roundToDouble(),
      top.roundToDouble(),
      desiredSide.roundToDouble(),
      desiredSide.roundToDouble(),
    );
  }

  AvatarTemplate? _pickTemplate() {
    final hasAbstract = _abstractTemplates.isNotEmpty;
    final hasNonAbstract = _nonAbstractTemplates.isNotEmpty;
    if (!hasAbstract && !hasNonAbstract) return null;
    final useAbstract = !hasNonAbstract ||
        (hasAbstract && hasNonAbstract && _random.nextBool());
    final pool = useAbstract ? _abstractTemplates : _nonAbstractTemplates;
    final keys = useAbstract ? _abstractTemplateKeys : _nonAbstractTemplateKeys;
    if (keys.isEmpty || pool.isEmpty) return null;
    final recentKeys = _recentTemplateKeys.toSet();
    final availableKeys =
        keys.where((key) => !recentKeys.contains(key)).toList();
    final pickKeys = availableKeys.isEmpty ? keys : availableKeys;
    final selectionKey = pickKeys[_random.nextInt(pickKeys.length)];
    final selection =
        _templateByKey[selectionKey] ?? pool[_random.nextInt(pool.length)];
    _pushRecentTemplateKey(selectionKey);
    return selection;
  }

  Color _randomAvatarBackgroundColor() => generateAvatarBackground(_random);

  String _templateKey(AvatarTemplate template) {
    final path = template.assetPath;
    if (path == null || path.isEmpty) return template.id;
    final segments = path.split('/');
    return segments.isNotEmpty ? segments.last : template.id;
  }

  void _pushRecentTemplateKey(String key) {
    _recentTemplateKeys.add(key);
    if (_recentTemplateKeys.length > _avatarCarouselHistoryLimit) {
      _recentTemplateKeys.removeAt(0);
    }
  }

  Future<Avatar> _buildAvatarFromTemplate({
    required AvatarTemplate template,
    required Color background,
    required ShadColorScheme colors,
  }) async {
    final rawBytes = await template.loadRawBytes();
    final bytes = rawBytes != null && rawBytes.isNotEmpty
        ? rawBytes
        : (await template.generator(background, colors)).bytes;
    final resolvedBackground = template.hasAlphaBackground
        ? background
        : state.backgroundColor == Colors.transparent
            ? colors.accent
            : state.backgroundColor;
    final useTemplateInset =
        template.category != AvatarTemplateCategory.abstract;
    final insetFraction = useTemplateInset ? avatarInsetFraction : 0.0;
    return Avatar.fromTemplateBytes(
      bytes: bytes,
      template: template,
      background: resolvedBackground,
      targetSize: _targetSize,
      maxBytes: _maxBytes,
      insetFraction: insetFraction,
      minJpegQuality: _minQuality,
      qualityStep: _qualityStep,
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
    try {
      final avatar = await Avatar.fromUploadBytes(
        bytes: bytes,
        maxDimension: _targetSize,
        jpegQuality: 90,
        targetSize: _targetSize,
        maxBytes: _maxBytes,
        minJpegQuality: _minQuality,
        qualityStep: _qualityStep,
      );
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
