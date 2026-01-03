// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:typed_data';

import 'package:axichat/src/common/media_decode_safety.dart';

const int avatarMaxBytes = 512 * 1024;
const int avatarMaxPixels = 2 * 1024 * 1024;
const int avatarMaxFrames = 10;
const int avatarMinBytes = 1;
const int avatarMinFrames = 1;
const int avatarMinDimension = 1;
const Duration avatarDecodeTimeout = Duration(milliseconds: 1500);

const ImageDecodeLimits avatarDecodeLimits = ImageDecodeLimits(
  maxBytes: avatarMaxBytes,
  maxPixels: avatarMaxPixels,
  maxFrames: avatarMaxFrames,
  minDimension: avatarMinDimension,
  decodeTimeout: avatarDecodeTimeout,
  minBytes: avatarMinBytes,
  minFrames: avatarMinFrames,
);

Future<Uint8List?> sanitizeAvatarBytes(Uint8List? bytes) async {
  if (bytes == null || bytes.isEmpty) {
    return null;
  }
  final safe = await isSafeImageBytes(bytes, avatarDecodeLimits);
  return safe ? bytes : null;
}
