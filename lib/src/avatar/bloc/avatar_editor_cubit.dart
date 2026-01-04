// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

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
import 'package:moxxmpp/moxxmpp.dart' as mox;
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
    this.shuffling = false,
    this.processing = false,
    this.publishing = false,
    this.error,
    this.lastSavedPath,
    this.lastSavedHash,
    this.estimatedBytes,
  });

  final AvatarSource source;
  final Uint8List? sourceBytes;
  final Uint8List? previewBytes;
  final AvatarTemplate? template;
  final AvatarUploadPayload? draft;
  final bool shuffling;
  final bool processing;
  final bool publishing;
  final String? error;
  final Rect? cropRect;
  final int? imageWidth;
  final int? imageHeight;
  final Color backgroundColor;
  final String? lastSavedPath;
  final String? lastSavedHash;
  final int? estimatedBytes;

  AvatarEditorState copyWith({
    AvatarSource? source,
    Uint8List? sourceBytes,
    Uint8List? previewBytes,
    AvatarTemplate? template,
    AvatarUploadPayload? draft,
    bool? shuffling,
    bool? processing,
    bool? publishing,
    String? error,
    Rect? cropRect,
    int? imageWidth,
    int? imageHeight,
    Color? backgroundColor,
    String? lastSavedPath,
    String? lastSavedHash,
    int? estimatedBytes,
    bool clearError = false,
    bool clearSourceBytes = false,
    bool clearPreviewBytes = false,
    bool clearTemplate = false,
    bool clearDraft = false,
    bool clearEstimatedBytes = false,
    bool clearLastSavedPath = false,
    bool clearLastSavedHash = false,
  }) {
    return AvatarEditorState(
      source: source ?? this.source,
      sourceBytes: clearSourceBytes ? null : sourceBytes ?? this.sourceBytes,
      previewBytes:
          clearPreviewBytes ? null : previewBytes ?? this.previewBytes,
      template: clearTemplate ? null : template ?? this.template,
      draft: clearDraft ? null : draft ?? this.draft,
      shuffling: shuffling ?? this.shuffling,
      processing: processing ?? this.processing,
      publishing: publishing ?? this.publishing,
      error: clearError ? null : error ?? this.error,
      cropRect: cropRect ?? this.cropRect,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      lastSavedPath:
          clearLastSavedPath ? null : lastSavedPath ?? this.lastSavedPath,
      lastSavedHash:
          clearLastSavedHash ? null : lastSavedHash ?? this.lastSavedHash,
      estimatedBytes:
          clearEstimatedBytes ? null : estimatedBytes ?? this.estimatedBytes,
    );
  }

  @override
  List<Object?> get props => [
        source,
        sourceBytes,
        previewBytes,
        template,
        draft?.hash,
        shuffling,
        processing,
        publishing,
        error,
        cropRect,
        imageWidth,
        imageHeight,
        backgroundColor,
        lastSavedPath,
        lastSavedHash,
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

  void _emitIfOpen(AvatarEditorState next) {
    if (isClosed) return;
    try {
      emit(next);
    } on StateError {
      if (isClosed) return;
      rethrow;
    }
  }

  static const minCropSide = 48.0;
  static const avatarInsetFraction = 0.10;
  static const _targetSize = 256;
  static const _maxBytes = 64 * 1024;
  static const _minQuality = 55;
  static const _qualityStep = 5;
  static const _sourceMaxDimension = 768;
  static const _sourceJpegQuality = 86;
  static const _rebuildDelay = Duration(milliseconds: 220);
  static const _missingDraftMessage = 'Pick or build an avatar first.';
  static const _xmppDisconnectedMessage =
      'Connect to XMPP before saving your avatar.';
  static const _avatarPublishRejectedMessage =
      'Your server rejected avatar publishing.';
  static const _avatarPublishTimeoutMessage =
      'Avatar upload timed out. Please try again.';
  static const _avatarPublishGenericMessage =
      'Could not publish avatar. Check your connection and try again.';
  static const _avatarPublishUnexpectedMessage =
      'Unexpected error while uploading avatar.';

  final XmppService _xmppService;
  final ProfileCubit? _profileCubit;
  final List<AvatarTemplate> _templates;
  final List<String> _recentShuffleIds = <String>[];
  final List<AvatarTemplate> _abstractShuffleBag = <AvatarTemplate>[];
  final List<AvatarTemplate> _nonAbstractShuffleBag = <AvatarTemplate>[];
  static const _shuffleHistoryLimit = 12;
  final _random = Random();

  Timer? _rebuildTimer;
  bool _draftBuildInProgress = false;
  bool _draftBuildRequested = false;

  @override
  Future<void> close() async {
    _rebuildTimer?.cancel();
    return super.close();
  }

  void initialize(ShadColorScheme colors) {
    final initialBackground = state.backgroundColor == Colors.transparent
        ? colors.accent
        : state.backgroundColor;
    _emitIfOpen(state.copyWith(backgroundColor: initialBackground));
    unawaited(_loadInitialAvatar());
  }

  Future<void> seedFromBytes(Uint8List bytes) async {
    if (bytes.isEmpty) return;
    await _loadFromBytes(bytes, buildDraft: true);
  }

  Future<void> seedRandomTemplate(ShadColorScheme colors) async {
    if (state.sourceBytes != null ||
        state.previewBytes != null ||
        state.draft != null ||
        state.processing) {
      return;
    }
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
      if (isClosed) return;
      await _loadFromBytes(bytes, buildDraft: false);
    } catch (_) {}
  }

  Future<void> pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
        withReadStream: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null || bytes.isEmpty) {
        _emitIfOpen(state.copyWith(error: 'Could not read that file.'));
        return;
      }
      await _loadFromBytes(bytes, buildDraft: true);
    } catch (_) {
      _emitIfOpen(
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
    _emitIfOpen(
      state.copyWith(
        processing: true,
        source: AvatarSource.template,
        template: template,
        clearDraft: true,
        clearPreviewBytes: true,
        clearEstimatedBytes: true,
        clearLastSavedPath: true,
        clearError: true,
      ),
    );
    try {
      final selectedBackground = background ?? state.backgroundColor;
      final generatorBackground =
          template.hasAlphaBackground ? Colors.transparent : selectedBackground;
      final generated = await template.generator(
        generatorBackground,
        colors,
      );
      if (isClosed) return;
      _emitIfOpen(
        state.copyWith(
          sourceBytes: generated.bytes,
          imageWidth: generated.width,
          imageHeight: generated.height,
          cropRect: _initialCropRect(
            imageWidth: generated.width.toDouble(),
            imageHeight: generated.height.toDouble(),
          ),
          backgroundColor: selectedBackground,
          clearError: true,
        ),
      );
      await _rebuildDraft();
    } catch (_) {
      if (isClosed) return;
      _emitIfOpen(
        state.copyWith(
          processing: false,
          clearDraft: true,
          error: 'Failed to load that avatar option.',
        ),
      );
    }
  }

  Future<void> setBackgroundColor(
    Color color,
    ShadColorScheme colors,
  ) async {
    _emitIfOpen(state.copyWith(backgroundColor: color));
    final template = state.template;
    final shouldRebuild = template != null &&
        template.category != AvatarTemplateCategory.abstract &&
        template.hasAlphaBackground;
    if (!shouldRebuild) return;
    _scheduleRebuild();
  }

  Future<void> shuffleTemplate(ShadColorScheme colors) async {
    if (state.processing || state.publishing || state.shuffling) {
      return;
    }
    _emitIfOpen(state.copyWith(shuffling: true, clearError: true));
    final template = _pickTemplate();
    if (template == null) {
      _emitIfOpen(state.copyWith(shuffling: false));
      return;
    }
    final background = template.hasAlphaBackground
        ? _randomAvatarBackgroundColor(colors)
        : state.backgroundColor == Colors.transparent
            ? colors.accent
            : state.backgroundColor;
    try {
      await selectTemplate(
        template,
        colors,
        background: background,
      );
    } finally {
      _emitIfOpen(state.copyWith(shuffling: false));
    }
  }

  Future<void> shuffleBackground(ShadColorScheme colors) async {
    if (state.processing || state.publishing || state.shuffling) {
      return;
    }
    final template = state.template;
    if (template == null) return;
    if (template.category == AvatarTemplateCategory.abstract) return;
    if (!template.hasAlphaBackground) return;
    final background = _randomAvatarBackgroundColor(colors);
    await setBackgroundColor(background, colors);
  }

  void updateCropRect(Rect rect) {
    final imageWidth = state.imageWidth?.toDouble();
    final imageHeight = state.imageHeight?.toDouble();
    if (imageWidth == null || imageHeight == null) return;
    final clamped = _constrainRect(rect, imageWidth, imageHeight);
    if (state.cropRect == clamped) return;
    _emitIfOpen(state.copyWith(cropRect: clamped));
    _scheduleRebuild();
  }

  void resizeCropRect(double factor) {
    final imageWidth = state.imageWidth?.toDouble();
    final imageHeight = state.imageHeight?.toDouble();
    if (imageWidth == null || imageHeight == null) return;
    final clampedFactor = factor.clamp(0.0, 1.0);
    final maxSide = min(imageWidth, imageHeight);
    final side = minCropSide + (maxSide - minCropSide) * clampedFactor;
    final current = state.cropRect ??
        _initialCropRect(
          imageWidth: imageWidth,
          imageHeight: imageHeight,
        );
    final next = Rect.fromCenter(
      center: current.center,
      width: side,
      height: side,
    );
    final constrained = _constrainRect(next, imageWidth, imageHeight);
    _emitIfOpen(state.copyWith(cropRect: constrained));
    _scheduleRebuild();
  }

  void resetCrop() {
    final imageWidth = state.imageWidth?.toDouble();
    final imageHeight = state.imageHeight?.toDouble();
    if (imageWidth == null || imageHeight == null) return;
    final reset = _initialCropRect(
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
    _emitIfOpen(state.copyWith(cropRect: reset));
    _scheduleRebuild();
  }

  Future<void> publish() async {
    final draft = state.draft;
    if (draft == null) {
      _emitIfOpen(state.copyWith(error: _missingDraftMessage));
      return;
    }
    if (!_xmppService.connected) {
      _emitIfOpen(
        state.copyWith(
          error: _xmppDisconnectedMessage,
        ),
      );
      return;
    }
    _emitIfOpen(state.copyWith(publishing: true, clearError: true));
    await Future<void>.delayed(Duration.zero);
    if (isClosed) return;
    try {
      final result = await _xmppService.publishAvatar(draft);
      _profileCubit?.updateAvatar(
        path: result.path,
        hash: result.hash,
      );
      _emitIfOpen(
        state.copyWith(
          publishing: false,
          lastSavedPath: result.path,
          lastSavedHash: result.hash,
          clearError: true,
        ),
      );
    } on XmppAvatarException catch (error) {
      final cause = error.wrapped;
      final message = switch (cause) {
        TimeoutException() => _avatarPublishTimeoutMessage,
        mox.PubSubError() => _pubSubErrorMessage(cause),
        mox.AvatarError() => _avatarPublishRejectedMessage,
        _ => _avatarPublishGenericMessage,
      };
      _emitIfOpen(
        state.copyWith(
          publishing: false,
          error: message,
        ),
      );
    } catch (_) {
      _emitIfOpen(
        state.copyWith(
          publishing: false,
          error: _avatarPublishUnexpectedMessage,
        ),
      );
    }
  }

  String _pubSubErrorMessage(mox.PubSubError error) {
    final message = error.message.trim();
    final suggestion = error.recoverySuggestion?.trim();
    if (suggestion == null || suggestion.isEmpty) {
      return message.isEmpty ? _avatarPublishGenericMessage : message;
    }
    if (message.isEmpty) return suggestion;
    return '$message $suggestion';
  }

  void _scheduleRebuild() {
    _rebuildTimer?.cancel();
    _rebuildTimer = Timer(
      _rebuildDelay,
      _rebuildDraft,
    );
  }

  Future<void> _rebuildDraft() async {
    if (isClosed) return;
    if (_draftBuildInProgress) {
      _draftBuildRequested = true;
      return;
    }
    _draftBuildInProgress = true;
    try {
      while (true) {
        if (isClosed) return;
        _draftBuildRequested = false;
        final sourceBytes = state.sourceBytes;
        final imageWidth = state.imageWidth?.toDouble();
        final imageHeight = state.imageHeight?.toDouble();
        if (sourceBytes == null ||
            sourceBytes.isEmpty ||
            imageWidth == null ||
            imageHeight == null ||
            imageWidth <= 0 ||
            imageHeight <= 0) {
          if (state.processing) {
            _emitIfOpen(state.copyWith(processing: false));
          }
          return;
        }
        final safeCrop = _constrainRect(
          state.cropRect ??
              _initialCropRect(
                imageWidth: imageWidth,
                imageHeight: imageHeight,
              ),
          imageWidth,
          imageHeight,
        );
        final template = state.template;
        final applyTint = template != null &&
            template.category != AvatarTemplateCategory.abstract &&
            template.hasAlphaBackground;
        final insetFraction = applyTint ? avatarInsetFraction : 0.0;
        final shouldInset = applyTint;
        final paddingColor =
            applyTint ? state.backgroundColor : Colors.transparent;
        final shouldFlatten = applyTint && paddingColor.a > 0;

        _emitIfOpen(state.copyWith(processing: true, clearError: true));
        await Future<void>.delayed(Duration.zero);
        if (isClosed) return;

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
          if (isClosed) return;
          final hash = sha1.convert(processed.bytes).toString();
          final draft = AvatarUploadPayload(
            bytes: processed.bytes,
            mimeType: processed.mimeType,
            width: processed.width,
            height: processed.height,
            hash: hash,
          );
          _emitIfOpen(
            state.copyWith(
              processing: false,
              draft: draft,
              previewBytes: draft.bytes,
              estimatedBytes: draft.bytes.length,
              clearError: true,
            ),
          );
        } catch (_) {
          if (isClosed) return;
          _emitIfOpen(
            state.copyWith(
              processing: false,
              clearDraft: true,
              clearPreviewBytes: true,
              error: 'Unable to process that image.',
            ),
          );
        }

        if (!_draftBuildRequested) {
          return;
        }
      }
    } finally {
      _draftBuildInProgress = false;
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

  Future<void> _loadFromBytes(
    Uint8List bytes, {
    required bool buildDraft,
  }) async {
    _emitIfOpen(
      state.copyWith(
        processing: true,
        clearError: true,
      ),
    );
    try {
      final prepared = await prepareAvatarSource(
        AvatarSourcePrepareRequest(
          bytes: bytes,
          maxDimension: _sourceMaxDimension,
          jpegQuality: _sourceJpegQuality,
        ),
      );
      if (isClosed) return;
      final imageWidth = prepared.width.toDouble();
      final imageHeight = prepared.height.toDouble();
      _emitIfOpen(
        state.copyWith(
          source: AvatarSource.upload,
          sourceBytes: prepared.bytes,
          imageWidth: prepared.width,
          imageHeight: prepared.height,
          cropRect: _initialCropRect(
            imageWidth: imageWidth,
            imageHeight: imageHeight,
          ),
          previewBytes: buildDraft ? null : prepared.bytes,
          clearTemplate: true,
          clearDraft: true,
          clearPreviewBytes: buildDraft,
          estimatedBytes: buildDraft ? null : prepared.bytes.length,
          clearEstimatedBytes: buildDraft,
          clearLastSavedPath: true,
          clearError: true,
        ),
      );
      if (!buildDraft) {
        _emitIfOpen(state.copyWith(processing: false, clearError: true));
        return;
      }
      await _rebuildDraft();
    } catch (_) {
      if (isClosed) return;
      _emitIfOpen(
        state.copyWith(
          processing: false,
          error: 'That file is not a valid image.',
        ),
      );
    }
  }
}
