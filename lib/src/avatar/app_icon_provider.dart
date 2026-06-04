// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:flutter/widgets.dart';

const String _axichatAppIconAssetPath = 'assets/icons/app_icon_source.png';

ImageProvider<Object> axichatAppIconProvider(
  BuildContext context, {
  required double size,
}) {
  return const AssetImage(_axichatAppIconAssetPath);
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
