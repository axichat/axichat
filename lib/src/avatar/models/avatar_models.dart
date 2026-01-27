// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:typed_data';

import 'package:axichat/src/avatar/avatar_image_utils.dart';
import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart' show AvatarUploadPayload;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

enum AvatarSource { upload, template }

class Avatar {
  const Avatar({
    required this.source,
    required this.payload,
    this.template,
    this.backgroundColor,
    this.cropRect,
    this.sourceBytes,
    this.sourceWidth,
    this.sourceHeight,
  });

  final AvatarSource source;
  final AvatarUploadPayload payload;
  final AvatarTemplate? template;
  final Color? backgroundColor;
  final Rect? cropRect;
  final Uint8List? sourceBytes;
  final int? sourceWidth;
  final int? sourceHeight;

  Uint8List get bytes => payload.bytes;

  static Future<Avatar> fromUploadBytes({
    required Uint8List bytes,
    required int maxDimension,
    required int jpegQuality,
    required int targetSize,
    required int maxBytes,
    required int minJpegQuality,
    required int qualityStep,
  }) async {
    final prepared = await prepareAvatarSource(
      AvatarSourcePrepareRequest(
        bytes: bytes,
        maxDimension: maxDimension,
        jpegQuality: jpegQuality,
      ),
    );
    final width = prepared.width.toDouble();
    final height = prepared.height.toDouble();
    final side = width < height ? width : height;
    final left = (width - side) / 2;
    final top = (height - side) / 2;
    final cropRect = Rect.fromLTWH(left, top, side, side);
    final processed = await processAvatar(
      AvatarProcessRequest(
        bytes: prepared.bytes,
        cropLeft: cropRect.left,
        cropTop: cropRect.top,
        cropSide: cropRect.width,
        targetSize: targetSize,
        maxBytes: maxBytes,
        insetFraction: 0,
        shouldInset: false,
        backgroundColor: Colors.transparent.toARGB32(),
        flattenBackground: false,
        minJpegQuality: minJpegQuality,
        qualityStep: qualityStep,
      ),
    );
    final hash = sha1.convert(processed.bytes).toString();
    final payload = AvatarUploadPayload(
      bytes: processed.bytes,
      mimeType: processed.mimeType,
      width: processed.width,
      height: processed.height,
      hash: hash,
    );
    return Avatar(
      source: AvatarSource.upload,
      payload: payload,
      sourceBytes: prepared.bytes,
      sourceWidth: prepared.width,
      sourceHeight: prepared.height,
      cropRect: cropRect,
    );
  }

  static Future<Avatar> fromTemplateBytes({
    required Uint8List bytes,
    required AvatarTemplate template,
    required Color background,
    required int targetSize,
    required int maxBytes,
    required double insetFraction,
    required int minJpegQuality,
    required int qualityStep,
    double cropSide = 100000.0,
  }) async {
    final shouldInset = insetFraction > 0;
    final shouldFlatten =
        shouldInset || template.hasAlphaBackground || background.a > 0;
    final processed = await processAvatar(
      AvatarProcessRequest(
        bytes: bytes,
        cropLeft: 0,
        cropTop: 0,
        cropSide: cropSide,
        targetSize: targetSize,
        maxBytes: maxBytes,
        insetFraction: insetFraction,
        shouldInset: shouldInset,
        backgroundColor: background.toARGB32(),
        flattenBackground: shouldFlatten,
        minJpegQuality: minJpegQuality,
        qualityStep: qualityStep,
      ),
    );
    final hash = sha1.convert(processed.bytes).toString();
    final payload = AvatarUploadPayload(
      bytes: processed.bytes,
      mimeType: processed.mimeType,
      width: processed.width,
      height: processed.height,
      hash: hash,
    );
    return Avatar(
      source: AvatarSource.template,
      payload: payload,
      template: template,
      backgroundColor: background,
    );
  }

  bool get usesTemplateBackground {
    final templateValue = template;
    if (templateValue == null) return false;
    if (templateValue.category == AvatarTemplateCategory.abstract) return false;
    return templateValue.hasAlphaBackground;
  }

  Rect? resolveCropRect({required double minCropSide}) {
    final width = sourceWidth?.toDouble();
    final height = sourceHeight?.toDouble();
    if (width == null || height == null || width <= 0 || height <= 0) {
      return cropRect;
    }
    if (cropRect != null) return cropRect;
    final side = width < height ? width : height;
    final minSide = minCropSide < side ? minCropSide : side;
    final left = (width - minSide) / 2;
    final top = (height - minSide) / 2;
    return Rect.fromLTWH(left, top, minSide, minSide);
  }

  Rect constrainCropRect({
    required Rect rect,
    required double minCropSide,
  }) {
    final width = sourceWidth?.toDouble();
    final height = sourceHeight?.toDouble();
    if (width == null ||
        height == null ||
        width <= 0 ||
        height <= 0 ||
        !rect.isFinite) {
      return Rect.zero;
    }
    final maxSide = width < height ? width : height;
    final minSide = minCropSide < maxSide ? minCropSide : maxSide;
    final baseSide = rect.width > 0 && rect.height > 0
        ? (rect.width < rect.height ? rect.width : rect.height)
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

  Future<Avatar> rebuildUploadPayload({
    required Rect cropRect,
    required int targetSize,
    required int maxBytes,
    required double insetFraction,
    required int minJpegQuality,
    required int qualityStep,
    required Color backgroundColor,
  }) async {
    final source = sourceBytes;
    if (source == null || source.isEmpty) {
      throw const FormatException('Missing avatar source bytes.');
    }
    final applyTint = usesTemplateBackground;
    final paddingColor = applyTint ? backgroundColor : Colors.transparent;
    final shouldFlatten = applyTint && paddingColor.a > 0;
    final processed = await processAvatar(
      AvatarProcessRequest(
        bytes: source,
        cropLeft: cropRect.left,
        cropTop: cropRect.top,
        cropSide: cropRect.width,
        targetSize: targetSize,
        maxBytes: maxBytes,
        insetFraction: applyTint ? insetFraction : 0,
        shouldInset: applyTint,
        backgroundColor: paddingColor.toARGB32(),
        flattenBackground: shouldFlatten,
        minJpegQuality: minJpegQuality,
        qualityStep: qualityStep,
      ),
    );
    final hash = sha1.convert(processed.bytes).toString();
    final nextPayload = AvatarUploadPayload(
      bytes: processed.bytes,
      mimeType: processed.mimeType,
      width: processed.width,
      height: processed.height,
      hash: hash,
    );
    return copyWith(payload: nextPayload, cropRect: cropRect);
  }

  Avatar copyWith({
    AvatarSource? source,
    AvatarUploadPayload? payload,
    AvatarTemplate? template,
    Color? backgroundColor,
    Rect? cropRect,
    Uint8List? sourceBytes,
    int? sourceWidth,
    int? sourceHeight,
  }) {
    return Avatar(
      source: source ?? this.source,
      payload: payload ?? this.payload,
      template: template ?? this.template,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      cropRect: cropRect ?? this.cropRect,
      sourceBytes: sourceBytes ?? this.sourceBytes,
      sourceWidth: sourceWidth ?? this.sourceWidth,
      sourceHeight: sourceHeight ?? this.sourceHeight,
    );
  }
}
