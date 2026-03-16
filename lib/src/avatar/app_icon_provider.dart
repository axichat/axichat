// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:flutter/widgets.dart';

const String _axichatAppIconAssetPath = 'assets/icons/app_icon_source.png';

ImageProvider<Object> axichatAppIconProvider(
  BuildContext context, {
  required double size,
}) {
  final baseSize = size < context.sizing.iconButtonTapTarget
      ? context.sizing.iconButtonTapTarget
      : size;
  final devicePixelRatio = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1;
  final scaledSize = (baseSize * devicePixelRatio).ceil();
  final cacheExtent = scaledSize > 0 ? scaledSize : 1;
  return ResizeImage.resizeIfNeeded(
    cacheExtent,
    cacheExtent,
    const AssetImage(_axichatAppIconAssetPath),
  );
}

Future<void> precacheAxichatAppIcon(
  BuildContext context, {
  double? size,
}) async {
  final resolvedSize = size ?? context.sizing.iconButtonTapTarget;
  await precacheImage(
    axichatAppIconProvider(context, size: resolvedSize),
    context,
  );
}
