import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:shadcn_ui/shadcn_ui.dart';

enum AvatarTemplateCategory { abstract, science, sports, music }

typedef AvatarTemplateBuilder = Future<GeneratedAvatar> Function(
  Color background,
  ShadColorScheme colors,
);

class AvatarTemplate {
  const AvatarTemplate({
    required this.id,
    required this.label,
    required this.category,
    required this.hasAlphaBackground,
    required this.generator,
  });

  final String id;
  final String label;
  final AvatarTemplateCategory category;
  final bool hasAlphaBackground;
  final AvatarTemplateBuilder generator;
}

class GeneratedAvatar {
  const GeneratedAvatar({
    required this.bytes,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.hasAlpha,
  });

  final Uint8List bytes;
  final String mimeType;
  final int width;
  final int height;
  final bool hasAlpha;
}

List<AvatarTemplate> buildDefaultAvatarTemplates() => const [
      AvatarTemplate(
        id: 'abstract-grid',
        label: 'Prismatic Grid',
        category: AvatarTemplateCategory.abstract,
        hasAlphaBackground: false,
        generator: _gridTemplate,
      ),
      AvatarTemplate(
        id: 'abstract-waves',
        label: 'Silk Waves',
        category: AvatarTemplateCategory.abstract,
        hasAlphaBackground: true,
        generator: _wavesTemplate,
      ),
      AvatarTemplate(
        id: 'abstract-spheres',
        label: 'Floating Spheres',
        category: AvatarTemplateCategory.abstract,
        hasAlphaBackground: false,
        generator: _spheresTemplate,
      ),
      AvatarTemplate(
        id: 'science-atom',
        label: 'Atom',
        category: AvatarTemplateCategory.science,
        hasAlphaBackground: true,
        generator: _atomTemplate,
      ),
      AvatarTemplate(
        id: 'science-blueprint',
        label: 'Blueprint',
        category: AvatarTemplateCategory.science,
        hasAlphaBackground: false,
        generator: _blueprintTemplate,
      ),
      AvatarTemplate(
        id: 'science-rocket',
        label: 'Rocket',
        category: AvatarTemplateCategory.science,
        hasAlphaBackground: false,
        generator: _rocketTemplate,
      ),
      AvatarTemplate(
        id: 'sports-pitch',
        label: 'Pitch',
        category: AvatarTemplateCategory.sports,
        hasAlphaBackground: false,
        generator: _pitchTemplate,
      ),
      AvatarTemplate(
        id: 'sports-lines',
        label: 'Court Lines',
        category: AvatarTemplateCategory.sports,
        hasAlphaBackground: true,
        generator: _courtLinesTemplate,
      ),
      AvatarTemplate(
        id: 'sports-cycling',
        label: 'Cycling',
        category: AvatarTemplateCategory.sports,
        hasAlphaBackground: false,
        generator: _cyclingTemplate,
      ),
      AvatarTemplate(
        id: 'music-note',
        label: 'Note',
        category: AvatarTemplateCategory.music,
        hasAlphaBackground: true,
        generator: _noteTemplate,
      ),
      AvatarTemplate(
        id: 'music-synth',
        label: 'Synth Pads',
        category: AvatarTemplateCategory.music,
        hasAlphaBackground: false,
        generator: _synthTemplate,
      ),
      AvatarTemplate(
        id: 'music-vibes',
        label: 'Vibes',
        category: AvatarTemplateCategory.music,
        hasAlphaBackground: false,
        generator: _vibesTemplate,
      ),
    ];

const _templateSize = 640;

Future<GeneratedAvatar> _gridTemplate(
  Color background,
  ShadColorScheme colors,
) async {
  final canvas = _canvas(
    size: _templateSize,
    background: colors.secondary,
  );
  final stroke = _color(colors.border);
  for (var i = 1; i < 8; i++) {
    final offset = (i * (_templateSize ~/ 8));
    img.drawLine(
      canvas,
      x1: 0,
      y1: offset,
      x2: _templateSize,
      y2: offset,
      color: stroke,
      thickness: 2,
      antialias: true,
    );
    img.drawLine(
      canvas,
      x1: offset,
      y1: 0,
      x2: offset,
      y2: _templateSize,
      color: stroke,
      thickness: 2,
      antialias: true,
    );
  }
  img.fillCircle(
    canvas,
    x: (_templateSize * 0.3).round(),
    y: (_templateSize * 0.35).round(),
    radius: 80,
    color: _color(colors.primary),
    antialias: true,
  );
  img.drawCircle(
    canvas,
    x: (_templateSize * 0.7).round(),
    y: (_templateSize * 0.7).round(),
    radius: 120,
    color: _color(colors.accent),
    antialias: true,
  );
  return _encodePng(canvas);
}

Future<GeneratedAvatar> _wavesTemplate(
  Color background,
  ShadColorScheme colors,
) async {
  final canvas = _canvas(
    size: _templateSize,
    background: Colors.transparent,
  );
  final waveColor = _color(colors.primary);
  for (var row = 0; row < 6; row++) {
    final baseline = (_templateSize * (0.15 + row * 0.12)).round();
    for (var x = 0; x < _templateSize; x += 8) {
      final y = baseline + (sin(x / 35 + row) * 18).round();
      img.fillCircle(
        canvas,
        x: x,
        y: y,
        radius: 2,
        color: waveColor,
        antialias: true,
      );
    }
  }
  img.drawCircle(
    canvas,
    x: (_templateSize * 0.18).round(),
    y: (_templateSize * 0.78).round(),
    radius: 52,
    color: _color(colors.accent),
    antialias: true,
  );
  img.drawCircle(
    canvas,
    x: (_templateSize * 0.82).round(),
    y: (_templateSize * 0.32).round(),
    radius: 48,
    color: _color(colors.accent),
    antialias: true,
  );
  return _encodePng(canvas);
}

Future<GeneratedAvatar> _spheresTemplate(
  Color background,
  ShadColorScheme colors,
) async {
  final canvas = _canvas(
    size: _templateSize,
    background: colors.primary,
  );
  const centers = [
    Offset(_templateSize * 0.28, _templateSize * 0.32),
    Offset(_templateSize * 0.62, _templateSize * 0.52),
    Offset(_templateSize * 0.46, _templateSize * 0.76),
  ];
  for (final center in centers) {
    img.fillCircle(
      canvas,
      x: center.dx.round(),
      y: center.dy.round(),
      radius: (_templateSize * 0.17).round(),
      color: _color(colors.card),
      antialias: true,
    );
    img.drawCircle(
      canvas,
      x: center.dx.round(),
      y: center.dy.round(),
      radius: (_templateSize * 0.17).round(),
      color: _color(colors.accent),
      antialias: true,
    );
  }
  return _encodePng(canvas);
}

Future<GeneratedAvatar> _atomTemplate(
  Color background,
  ShadColorScheme colors,
) async {
  final canvas = _canvas(size: _templateSize, background: Colors.transparent);
  const center = _templateSize ~/ 2;
  final orbitColor = _color(colors.accent);
  const radii = [180, 200, 160];
  for (final radius in radii) {
    img.drawCircle(
      canvas,
      x: center,
      y: center,
      radius: radius,
      color: orbitColor,
      antialias: true,
    );
  }
  img.fillCircle(
    canvas,
    x: center,
    y: center,
    radius: 30,
    color: _color(colors.primary),
    antialias: true,
  );
  return _encodePng(canvas);
}

Future<GeneratedAvatar> _blueprintTemplate(
  Color background,
  ShadColorScheme colors,
) async {
  final canvas = _canvas(
    size: _templateSize,
    background: colors.secondary,
  );
  final grid = _color(colors.border);
  for (var i = 0; i < _templateSize; i += 40) {
    img.drawLine(
      canvas,
      x1: i,
      y1: 0,
      x2: i,
      y2: _templateSize,
      color: grid,
    );
    img.drawLine(
      canvas,
      x1: 0,
      y1: i,
      x2: _templateSize,
      y2: i,
      color: grid,
    );
  }
  img.drawLine(
    canvas,
    x1: (_templateSize * 0.2).round(),
    y1: (_templateSize * 0.65).round(),
    x2: (_templateSize * 0.8).round(),
    y2: (_templateSize * 0.25).round(),
    color: _color(colors.primary),
    thickness: 12,
    antialias: true,
  );
  img.drawLine(
    canvas,
    x1: (_templateSize * 0.3).round(),
    y1: (_templateSize * 0.45).round(),
    x2: (_templateSize * 0.7).round(),
    y2: (_templateSize * 0.75).round(),
    color: _color(colors.accent),
    thickness: 10,
    antialias: true,
  );
  return _encodePng(canvas);
}

Future<GeneratedAvatar> _rocketTemplate(
  Color background,
  ShadColorScheme colors,
) async {
  final canvas = _canvas(
    size: _templateSize,
    background: colors.card,
  );
  final baseX = (_templateSize * 0.5).round();
  final baseY = (_templateSize * 0.18).round();
  img.drawPolygon(
    canvas,
    vertices: [
      img.Point(baseX, baseY),
      img.Point(baseX + 50, baseY + 240),
      img.Point(baseX, baseY + 320),
      img.Point(baseX - 50, baseY + 240),
    ],
    color: _color(colors.primary),
    antialias: true,
  );
  img.fillCircle(
    canvas,
    x: baseX,
    y: baseY + 170,
    radius: 40,
    color: _color(colors.accent),
    antialias: true,
  );
  img.drawLine(
    canvas,
    x1: baseX,
    y1: baseY + 320,
    x2: baseX,
    y2: baseY + 380,
    color: _color(colors.secondaryForeground),
    thickness: 14,
    antialias: true,
  );
  return _encodePng(canvas);
}

Future<GeneratedAvatar> _pitchTemplate(
  Color background,
  ShadColorScheme colors,
) async {
  final canvas = _canvas(
    size: _templateSize,
    background: colors.primary,
  );
  final borderColor = _color(colors.card);
  const padding = 60;
  img.drawRect(
    canvas,
    x1: padding,
    y1: padding,
    x2: _templateSize - padding,
    y2: _templateSize - padding,
    color: borderColor,
    thickness: 12,
  );
  img.drawLine(
    canvas,
    x1: _templateSize ~/ 2,
    y1: padding,
    x2: _templateSize ~/ 2,
    y2: _templateSize - padding,
    color: borderColor,
    thickness: 10,
  );
  img.drawCircle(
    canvas,
    x: _templateSize ~/ 2,
    y: _templateSize ~/ 2,
    radius: 92,
    color: borderColor,
    antialias: true,
  );
  return _encodePng(canvas);
}

Future<GeneratedAvatar> _courtLinesTemplate(
  Color background,
  ShadColorScheme colors,
) async {
  final canvas = _canvas(size: _templateSize, background: Colors.transparent);
  final outline = _color(colors.primary);
  const padding = 40;
  img.drawRect(
    canvas,
    x1: padding,
    y1: padding,
    x2: _templateSize - padding,
    y2: _templateSize - padding,
    color: outline,
    thickness: 10,
  );
  img.drawLine(
    canvas,
    x1: _templateSize ~/ 2,
    y1: padding,
    x2: _templateSize ~/ 2,
    y2: _templateSize - padding,
    color: outline,
    thickness: 8,
  );
  img.drawLine(
    canvas,
    x1: padding,
    y1: _templateSize ~/ 2,
    x2: _templateSize - padding,
    y2: _templateSize ~/ 2,
    color: outline,
    thickness: 8,
  );
  return _encodePng(canvas);
}

Future<GeneratedAvatar> _cyclingTemplate(
  Color background,
  ShadColorScheme colors,
) async {
  final canvas = _canvas(
    size: _templateSize,
    background: colors.secondary,
  );
  final wheel = _color(colors.primary);
  final accent = _color(colors.accent);
  final centerY = (_templateSize * 0.65).round();
  img.drawCircle(
    canvas,
    x: (_templateSize * 0.32).round(),
    y: centerY,
    radius: 110,
    color: wheel,
    antialias: true,
  );
  img.drawCircle(
    canvas,
    x: (_templateSize * 0.72).round(),
    y: centerY,
    radius: 110,
    color: wheel,
    antialias: true,
  );
  img.drawLine(
    canvas,
    x1: (_templateSize * 0.32).round(),
    y1: centerY,
    x2: (_templateSize * 0.52).round(),
    y2: (_templateSize * 0.32).round(),
    color: accent,
    thickness: 14,
    antialias: true,
  );
  img.drawLine(
    canvas,
    x1: (_templateSize * 0.52).round(),
    y1: (_templateSize * 0.32).round(),
    x2: (_templateSize * 0.72).round(),
    y2: centerY,
    color: accent,
    thickness: 14,
    antialias: true,
  );
  img.drawLine(
    canvas,
    x1: (_templateSize * 0.52).round(),
    y1: (_templateSize * 0.32).round(),
    x2: (_templateSize * 0.44).round(),
    y2: (_templateSize * 0.12).round(),
    color: _color(colors.foreground),
    thickness: 10,
    antialias: true,
  );
  return _encodePng(canvas);
}

Future<GeneratedAvatar> _noteTemplate(
  Color background,
  ShadColorScheme colors,
) async {
  final canvas = _canvas(size: _templateSize, background: Colors.transparent);
  final stem = _color(colors.primary);
  img.drawLine(
    canvas,
    x1: (_templateSize * 0.45).round(),
    y1: (_templateSize * 0.25).round(),
    x2: (_templateSize * 0.45).round(),
    y2: (_templateSize * 0.75).round(),
    color: stem,
    thickness: 14,
    antialias: true,
  );
  img.drawLine(
    canvas,
    x1: (_templateSize * 0.45).round(),
    y1: (_templateSize * 0.25).round(),
    x2: (_templateSize * 0.68).round(),
    y2: (_templateSize * 0.34).round(),
    color: stem,
    thickness: 14,
    antialias: true,
  );
  img.fillCircle(
    canvas,
    x: (_templateSize * 0.32).round(),
    y: (_templateSize * 0.74).round(),
    radius: 60,
    color: stem,
    antialias: true,
  );
  img.fillCircle(
    canvas,
    x: (_templateSize * 0.62).round(),
    y: (_templateSize * 0.65).round(),
    radius: 52,
    color: stem,
    antialias: true,
  );
  return _encodePng(canvas);
}

Future<GeneratedAvatar> _synthTemplate(
  Color background,
  ShadColorScheme colors,
) async {
  final canvas = _canvas(
    size: _templateSize,
    background: colors.card,
  );
  final barColor = _color(colors.primary);
  for (var i = 0; i < 9; i++) {
    final height = (_templateSize * (0.18 + (i % 4) * 0.1)).round();
    final x = (_templateSize * 0.08 + i * 60).round();
    img.fillRect(
      canvas,
      x1: x,
      y1: _templateSize - height - 50,
      x2: x + 36,
      y2: _templateSize - 70,
      color: barColor,
    );
  }
  img.drawLine(
    canvas,
    x1: (_templateSize * 0.12).round(),
    y1: (_templateSize * 0.28).round(),
    x2: (_templateSize * 0.9).round(),
    y2: (_templateSize * 0.18).round(),
    color: _color(colors.accent),
    thickness: 12,
    antialias: true,
  );
  return _encodePng(canvas);
}

Future<GeneratedAvatar> _vibesTemplate(
  Color background,
  ShadColorScheme colors,
) async {
  final canvas = _canvas(
    size: _templateSize,
    background: colors.accent,
  );
  final pulse = _color(colors.card);
  for (var i = 0; i < 5; i++) {
    final radius = (_templateSize * (0.18 + i * 0.1)).round();
    img.drawCircle(
      canvas,
      x: _templateSize ~/ 2,
      y: _templateSize ~/ 2,
      radius: radius,
      color: pulse,
      antialias: true,
    );
  }
  img.fillCircle(
    canvas,
    x: _templateSize ~/ 2,
    y: _templateSize ~/ 2,
    radius: 70,
    color: _color(colors.primary),
    antialias: true,
  );
  return _encodePng(canvas);
}

img.Image _canvas({
  required int size,
  required Color background,
}) {
  final canvas = img.Image(
    width: size,
    height: size,
    numChannels: 4,
  );
  img.fill(canvas, color: _color(background));
  return canvas;
}

GeneratedAvatar _encodePng(img.Image image) => GeneratedAvatar(
      bytes: Uint8List.fromList(
        img.encodePng(
          image,
          level: 4,
        ),
      ),
      mimeType: 'image/png',
      width: image.width,
      height: image.height,
      hasAlpha: image.numChannels == 4,
    );

img.Color _color(Color color) => img.ColorInt32.rgba(
      _channelToByte(color.r),
      _channelToByte(color.g),
      _channelToByte(color.b),
      _channelToByte(color.a),
    );

int _channelToByte(double channel) => (channel * 255.0).round().clamp(0, 255);
