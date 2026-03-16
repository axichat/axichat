// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math';
import 'dart:typed_data';

import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/avatar/editing/avatar_carousel_engine.dart';
import 'package:axichat/src/avatar/editing/avatar_pipeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('prefill prefers abstract templates when requested', () async {
    final templates = [
      _fakeTemplate(id: 'abs-1', category: AvatarTemplateCategory.abstract),
      _fakeTemplate(id: 'abs-2', category: AvatarTemplateCategory.abstract),
      _fakeTemplate(id: 'misc-1', category: AvatarTemplateCategory.misc),
    ];
    final pipeline = AvatarPipeline(
      config: const AvatarPipelineConfig(
        targetSize: 16,
        maxBytes: 1024,
        minJpegQuality: 60,
        qualityStep: 5,
        uploadMaxDimension: 16,
        uploadJpegQuality: 90,
        minCropSide: 8,
      ),
    );
    final engine = AvatarCarouselEngine(
      pipeline: pipeline,
      templates: templates,
      random: Random(4),
      config: const AvatarCarouselEngineConfig(historyLimit: 8),
    );
    final context = AvatarCarouselBuildContext(
      colors: _buildColors(),
      currentBackground: Colors.blue,
    );
    final avatars = await engine.prefill(
      targetSize: 3,
      preferAbstract: true,
      context: context,
      renderSpec: _defaultRenderSpec,
    );

    expect(avatars, isNotEmpty);
    for (final avatar in avatars) {
      expect(avatar.template?.category, AvatarTemplateCategory.abstract);
    }
  });

  test('history avoids immediate repeats when alternates exist', () {
    final templates = [
      _fakeTemplate(id: 'abs-1', category: AvatarTemplateCategory.abstract),
      _fakeTemplate(id: 'abs-2', category: AvatarTemplateCategory.abstract),
    ];
    final engine = AvatarCarouselEngine(
      pipeline: _buildPipeline(),
      templates: templates,
      random: Random(1),
      config: const AvatarCarouselEngineConfig(historyLimit: 1),
    );

    final first = engine.pickTemplate(preferAbstract: true);
    expect(first, isNotNull);
    engine.markTemplateUsed(first!);
    final second = engine.pickTemplate(preferAbstract: true);
    expect(second, isNotNull);
    expect(second!.id, isNot(equals(first.id)));
  });

  test('buildNext uses render spec background', () async {
    final templates = [
      _fakeTemplate(
        id: 'abs-1',
        category: AvatarTemplateCategory.abstract,
        hasAlphaBackground: true,
      ),
    ];
    final engine = AvatarCarouselEngine(
      pipeline: _buildPipeline(),
      templates: templates,
      random: Random(2),
      config: const AvatarCarouselEngineConfig(historyLimit: 2),
    );
    final context = AvatarCarouselBuildContext(
      colors: _buildColors(),
      currentBackground: Colors.orange,
    );
    final avatar = await engine.buildNext(
      context: context,
      renderSpec: (template, _) => const AvatarRenderSpec(
        background: Colors.green,
        insetFraction: 0,
        cropSide: 1000,
      ),
    );

    expect(avatar, isNotNull);
    expect(avatar!.backgroundColor, Colors.green);
  });
}

AvatarPipeline _buildPipeline() {
  return AvatarPipeline(
    config: const AvatarPipelineConfig(
      targetSize: 16,
      maxBytes: 1024,
      minJpegQuality: 60,
      qualityStep: 5,
      uploadMaxDimension: 16,
      uploadJpegQuality: 90,
      minCropSide: 8,
    ),
  );
}

AvatarRenderSpec _defaultRenderSpec(
  AvatarTemplate template,
  AvatarCarouselBuildContext context,
) {
  return AvatarRenderSpec(
    background: context.currentBackground,
    insetFraction: 0,
    cropSide: 1000,
  );
}

AvatarTemplate _fakeTemplate({
  required String id,
  required AvatarTemplateCategory category,
  bool hasAlphaBackground = false,
}) {
  return AvatarTemplate(
    id: id,
    category: category,
    hasAlphaBackground: hasAlphaBackground,
    generator: (background, _) async => _solidAvatar(background),
  );
}

GeneratedAvatar _solidAvatar(Color color) {
  final image = img.Image(width: 32, height: 32, numChannels: 4);
  img.fill(image, color: _imgColor(color));
  final bytes = Uint8List.fromList(img.encodePng(image, level: 1));
  return GeneratedAvatar(
    bytes: bytes,
    mimeType: 'image/png',
    width: image.width,
    height: image.height,
    hasAlpha: true,
  );
}

img.Color _imgColor(Color color) {
  final argb = color.toARGB32();
  final a = (argb >> 24) & 0xFF;
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  return img.ColorRgba8(r, g, b, a);
}

ShadColorScheme _buildColors() {
  return ShadColorScheme.fromName('zinc', brightness: Brightness.light);
}
