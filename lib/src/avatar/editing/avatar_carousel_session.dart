// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:typed_data';

import 'package:axichat/src/avatar/editing/avatar_carousel_engine.dart';
import 'package:axichat/src/avatar/editing/avatar_pipeline.dart';
import 'package:axichat/src/avatar/editing/editable_avatar.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart' show AvatarUploadPayload;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:shadcn_ui/shadcn_ui.dart';

class AvatarCarouselFrame {
  const AvatarCarouselFrame({required this.avatar, required this.startedAt});

  final EditableAvatar avatar;
  final DateTime startedAt;
}

class AvatarCarouselSession {
  AvatarCarouselSession({
    required AvatarCarouselEngine engine,
    required Duration interval,
    required int initialBufferSize,
    required int sustainBufferSize,
    required bool Function() canRun,
    required Color Function() currentBackground,
    required AvatarRenderSpecResolver renderSpec,
    required bool Function() preferAbstract,
    required EditableAvatar Function(ShadColorScheme colors) fallbackAvatar,
    required void Function(bool running) onRunningChanged,
    required void Function(AvatarCarouselFrame frame) onPreviewChanged,
  }) : _engine = engine,
       _interval = interval,
       _initialBufferSize = initialBufferSize,
       _sustainBufferSize = sustainBufferSize,
       _canRun = canRun,
       _currentBackground = currentBackground,
       _renderSpec = renderSpec,
       _preferAbstract = preferAbstract,
       _fallbackAvatar = fallbackAvatar,
       _onRunningChanged = onRunningChanged,
       _onPreviewChanged = onPreviewChanged;

  final AvatarCarouselEngine _engine;
  final Duration _interval;
  final int _initialBufferSize;
  final int _sustainBufferSize;
  final bool Function() _canRun;
  final Color Function() _currentBackground;
  final AvatarRenderSpecResolver _renderSpec;
  final bool Function() _preferAbstract;
  final EditableAvatar Function(ShadColorScheme colors) _fallbackAvatar;
  final void Function(bool running) _onRunningChanged;
  final void Function(AvatarCarouselFrame frame) _onPreviewChanged;

  final List<EditableAvatar> _buffer = <EditableAvatar>[];
  Timer? _timer;
  Future<void>? _startFuture;
  Future<bool>? _buildFuture;
  int? _buildGeneration;
  int _generation = 0;
  ShadColorScheme? _colors;
  EditableAvatar? _currentAvatar;

  EditableAvatar? get currentAvatar => _currentAvatar;

  Future<void> start(ShadColorScheme colors, {EditableAvatar? seed}) async {
    _colors = colors;
    final existing = _startFuture;
    if (existing != null) {
      await existing;
      return;
    }
    final future = _performStart(colors, seed: seed);
    _startFuture = future;
    try {
      await future;
    } finally {
      if (identical(_startFuture, future)) {
        _startFuture = null;
      }
    }
  }

  Future<void> _performStart(
    ShadColorScheme colors, {
    EditableAvatar? seed,
  }) async {
    if (_timer != null || !_canRun()) return;
    _engine.startWarmupIfNeeded();
    final generation = _generation;
    var hasVisibleFrame = false;

    if (seed != null) {
      _emitPreview(seed);
      hasVisibleFrame = true;
    } else if (_currentAvatar != null) {
      _emitPreview(_currentAvatar!);
      hasVisibleFrame = true;
    } else if (_currentAvatar == null) {
      await _buildOne(generation: generation, preferAbstract: true);
      if (!_isActive(generation)) return;
      if (_showNext()) {
        hasVisibleFrame = true;
      } else {
        _emitPreview(_fallbackAvatar(colors));
        _onRunningChanged(false);
      }
    }

    if (!_isActive(generation) || !hasVisibleFrame) return;
    _scheduleTick();
    _startPrefill(
      generation: generation,
      targetSize: _initialBufferSize,
      preferAbstract: _preferAbstract(),
    );
  }

  Future<void> resume() async {
    final colors = _colors;
    if (colors == null || _timer != null || !_canRun()) return;
    await start(colors);
  }

  Future<EditableAvatar?> manualPreview(ShadColorScheme colors) async {
    _colors = colors;
    stop();
    final generation = _generation;
    if (_buffer.isNotEmpty) {
      final avatar = _buffer.removeAt(0);
      _currentAvatar = avatar;
      return avatar;
    }
    final avatar = await _buildNext(colors);
    if (generation != _generation) return null;
    final preview = avatar ?? _fallbackAvatar(colors);
    _currentAvatar = preview;
    return preview;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _startFuture = null;
    _generation++;
    _buildFuture = null;
    _buildGeneration = null;
    _onRunningChanged(false);
  }

  void reset() {
    stop();
    _buffer.clear();
    _currentAvatar = null;
  }

  void _startPrefill({
    required int generation,
    required int targetSize,
    required bool preferAbstract,
  }) {
    if (!_isActive(generation)) return;
    unawaited(
      _fillBuffer(
        generation: generation,
        targetSize: targetSize,
        preferAbstract: preferAbstract,
      ),
    );
  }

  Future<void> _fillBuffer({
    required int generation,
    required int targetSize,
    required bool preferAbstract,
  }) async {
    while (_isActive(generation) && _buffer.length < targetSize) {
      final added = await _buildOne(
        generation: generation,
        preferAbstract: preferAbstract,
      );
      if (!added) return;
    }
  }

  Future<bool> _buildOne({
    required int generation,
    required bool preferAbstract,
  }) async {
    final existing = _buildFuture;
    Future<bool> future;
    if (existing != null && _buildGeneration == generation) {
      future = existing;
    } else {
      future = _performBuildOne(
        generation: generation,
        preferAbstract: preferAbstract,
      );
    }
    _buildFuture = future;
    _buildGeneration = generation;
    try {
      return await future;
    } finally {
      if (identical(_buildFuture, future)) {
        _buildFuture = null;
        _buildGeneration = null;
      }
    }
  }

  Future<bool> _performBuildOne({
    required int generation,
    required bool preferAbstract,
  }) async {
    final colors = _colors;
    if (colors == null) return false;
    if (!_isActive(generation)) return _buffer.isNotEmpty;
    _engine.startWarmupIfNeeded();
    final avatars = await _engine.prefill(
      targetSize: 1,
      preferAbstract: preferAbstract,
      context: _buildContext(colors),
      renderSpec: _renderSpec,
    );
    if (!_isActive(generation)) return _buffer.isNotEmpty;
    _buffer.addAll(avatars);
    return avatars.isNotEmpty || _buffer.isNotEmpty;
  }

  void _scheduleTick() {
    if (_timer != null || !_canRun()) return;
    final generation = _generation;
    _timer = Timer(_interval, () async {
      await _handleTick(generation);
    });
  }

  Future<void> _handleTick(int generation) async {
    if (generation == _generation) {
      _timer = null;
    }
    if (!_isActive(generation)) return;
    if (_colors == null) {
      stop();
      return;
    }
    if (!_showNext()) {
      await _buildOne(
        generation: generation,
        preferAbstract: _preferAbstract(),
      );
      if (!_isActive(generation)) return;
      if (!_showNext()) {
        stop();
        return;
      }
    }
    if (!_isActive(generation)) return;
    _scheduleTick();
    if (_buffer.length < _sustainBufferSize) {
      _startPrefill(
        generation: generation,
        targetSize: _sustainBufferSize,
        preferAbstract: _preferAbstract(),
      );
    }
  }

  bool _showNext() {
    if (!_canRun() || _buffer.isEmpty) return false;
    _emitPreview(_buffer.removeAt(0));
    return true;
  }

  void _emitPreview(EditableAvatar avatar) {
    _currentAvatar = avatar;
    _onPreviewChanged(
      AvatarCarouselFrame(avatar: avatar, startedAt: DateTime.timestamp()),
    );
    _onRunningChanged(true);
  }

  Future<EditableAvatar?> _buildNext(ShadColorScheme colors) {
    _engine.startWarmupIfNeeded();
    return _engine.buildNext(
      context: _buildContext(colors),
      renderSpec: _renderSpec,
      preferAbstract: _preferAbstract(),
    );
  }

  AvatarCarouselBuildContext _buildContext(ShadColorScheme colors) {
    return AvatarCarouselBuildContext(
      colors: colors,
      currentBackground: _currentBackground(),
    );
  }

  bool _isActive(int generation) => generation == _generation && _canRun();
}

EditableAvatar buildAvatarCarouselFallback({
  required AvatarPipeline pipeline,
  required Color background,
  required Color accent,
}) {
  final base = background == Colors.transparent ? accent : background;
  final image = img.Image(
    width: pipeline.config.targetSize,
    height: pipeline.config.targetSize,
    numChannels: 4,
  );
  img.fill(image, color: _imgColor(base));
  final bytes = Uint8List.fromList(img.encodePng(image, level: 1));
  return EditableAvatar(
    source: AvatarSource.template,
    payload: AvatarUploadPayload(
      bytes: bytes,
      mimeType: 'image/png',
      width: pipeline.config.targetSize,
      height: pipeline.config.targetSize,
      hash: sha1.convert(bytes).toString(),
    ),
    backgroundColor: background,
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
