// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/common/ui/axi_sizing.dart';
import 'package:flutter/material.dart';

const String _axichatAppIconAssetPath = 'assets/icons/app_icon_source.png';

ImageProvider<Object> axichatAppIconProvider(
  BuildContext context, {
  required double size,
}) {
  final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
  final physicalSize = !size.isFinite || size <= 0 ? 1.0 : size;
  final physicalPixelRatio = !pixelRatio.isFinite || pixelRatio <= 0
      ? 1.0
      : pixelRatio;
  final cacheExtent = math.max(1, (physicalSize * physicalPixelRatio).ceil());
  return ResizeImage(
    const AssetImage(_axichatAppIconAssetPath),
    width: cacheExtent,
    height: cacheExtent,
  );
}

Future<void> precacheAxichatAppIcon(
  BuildContext context, {
  double? size,
}) async {
  final sizing = Theme.of(context).extension<AxiSizing>() ?? axiSizing;
  final resolvedSize = size ?? sizing.iconButtonTapTarget;
  await precacheImage(
    axichatAppIconProvider(context, size: resolvedSize),
    context,
  );
}
