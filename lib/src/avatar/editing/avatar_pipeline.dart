// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math';
import 'dart:typed_data';

import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/avatar/editing/editable_avatar.dart';
import 'package:axichat/src/common/avatar_background.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AvatarPipelineConfig {
  const AvatarPipelineConfig({
    this.targetSize = 256,
    this.maxBytes = 64 * 1024,
    this.minJpegQuality = 55,
    this.qualityStep = 5,
    this.uploadMaxDimension = 256,
    this.uploadJpegQuality = 90,
    this.minCropSide = 48.0,
  });

  final int targetSize;
  final int maxBytes;
  final int minJpegQuality;
  final int qualityStep;
  final int uploadMaxDimension;
  final int uploadJpegQuality;
  final double minCropSide;
}

class AvatarPipeline {
  AvatarPipeline({required AvatarPipelineConfig config}) : _config = config;

  final AvatarPipelineConfig _config;

  AvatarPipelineConfig get config => _config;

  Color randomBackground(Random random) => generateAvatarBackground(random);

  String templateKey(AvatarTemplate template) {
    final path = template.assetPath;
    if (path == null || path.isEmpty) return template.id;
    final segments = path.split('/');
    return segments.isNotEmpty ? segments.last : template.id;
  }

  Rect? resolveCropRect(EditableAvatar avatar) =>
      avatar.resolveCropRect(minCropSide: _config.minCropSide);

  Rect? initialCropRect(EditableAvatar avatar) =>
      avatar.initialCropRect(minCropSide: _config.minCropSide);

  Rect constrainCropRect({required EditableAvatar avatar, required Rect rect}) {
    return avatar.constrainCropRect(
      rect: rect,
      minCropSide: _config.minCropSide,
    );
  }

  Future<EditableAvatar> buildFromUpload(Uint8List bytes) {
    return EditableAvatar.fromUploadBytes(
      bytes: bytes,
      maxDimension: _config.uploadMaxDimension,
      jpegQuality: _config.uploadJpegQuality,
      targetSize: _config.targetSize,
      maxBytes: _config.maxBytes,
      minJpegQuality: _config.minJpegQuality,
      qualityStep: _config.qualityStep,
    );
  }

  Future<EditableAvatar> buildFromTemplate({
    required AvatarTemplate template,
    required Color background,
    required ShadColorScheme colors,
    required double insetFraction,
    double cropSide = 100000.0,
  }) async {
    final rawBytes = await template.loadRawBytes();
    final bytes = rawBytes != null && rawBytes.isNotEmpty
        ? rawBytes
        : (await template.generator(background, colors)).bytes;
    return EditableAvatar.fromTemplateBytes(
      bytes: bytes,
      template: template,
      background: background,
      targetSize: _config.targetSize,
      maxBytes: _config.maxBytes,
      insetFraction: insetFraction,
      minJpegQuality: _config.minJpegQuality,
      qualityStep: _config.qualityStep,
      cropSide: cropSide,
    );
  }

  Future<EditableAvatar> rebuildUploadPayload({
    required EditableAvatar avatar,
    required Rect cropRect,
    required double insetFraction,
    required Color backgroundColor,
  }) {
    return avatar.rebuildUploadPayload(
      cropRect: cropRect,
      targetSize: _config.targetSize,
      maxBytes: _config.maxBytes,
      insetFraction: insetFraction,
      minJpegQuality: _config.minJpegQuality,
      qualityStep: _config.qualityStep,
      backgroundColor: backgroundColor,
    );
  }
}
