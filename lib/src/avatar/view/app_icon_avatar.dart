// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/avatar/app_icon_provider.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

class AxichatAppIconAvatar extends StatelessWidget {
  const AxichatAppIconAvatar({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final shape = SquircleBorder(cornerRadius: context.radii.squircle);
    final imageProvider = axichatAppIconProvider(context, size: size);
    return SizedBox.square(
      dimension: size,
      child: ClipPath(
        clipBehavior: Clip.antiAlias,
        clipper: ShapeBorderClipper(shape: shape),
        child: Image(
          image: imageProvider,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.none,
          isAntiAlias: false,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}
