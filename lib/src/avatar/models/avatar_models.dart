// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:typed_data';

import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart' show AvatarUploadPayload;
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
