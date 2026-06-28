// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

class AxichatAppIconAvatar extends StatelessWidget {
  const AxichatAppIconAvatar({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final shape = SquircleBorder(
      cornerRadius: axiAvatarSquircleRadius(context, size),
    );
    return SizedBox.square(
      dimension: size,
      child: ClipPath(
        clipBehavior: Clip.antiAlias,
        clipper: ShapeBorderClipper(shape: shape),
        child: CustomPaint(
          painter: const _AxichatAppIconPainter(),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _AxichatAppIconPainter extends CustomPainter {
  const _AxichatAppIconPainter();

  static const double _sourceExtent = 1024.0;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black;
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final markPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = Colors.white;

    canvas.drawPath(
      _path(size, const <Offset>[
        Offset(186, 324),
        Offset(512, 526),
        Offset(512, 616),
      ]),
      markPaint,
    );
    canvas.drawPath(
      _path(size, const <Offset>[
        Offset(838, 324),
        Offset(512, 526),
        Offset(512, 616),
      ]),
      markPaint,
    );
    canvas.drawPath(
      _path(size, const <Offset>[
        Offset(174, 702),
        Offset(354, 505),
        Offset(398, 545),
      ]),
      markPaint,
    );
    canvas.drawPath(
      _path(size, const <Offset>[
        Offset(850, 702),
        Offset(670, 505),
        Offset(626, 545),
      ]),
      markPaint,
    );
  }

  Path _path(Size size, List<Offset> points) {
    final path = Path();
    for (var index = 0; index < points.length; index += 1) {
      final point = points[index];
      final scaled = Offset(
        point.dx / _sourceExtent * size.width,
        point.dy / _sourceExtent * size.height,
      );
      if (index == 0) {
        path.moveTo(scaled.dx, scaled.dy);
      } else {
        path.lineTo(scaled.dx, scaled.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _AxichatAppIconPainter oldDelegate) => false;
}
