// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math';

import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/avatar/models/avatar_models.dart';
import 'package:axichat/src/avatar/util/avatar_pipeline.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AvatarCarouselEngineConfig {
  const AvatarCarouselEngineConfig({
    this.historyLimit = 12,
    this.maxAttempts = 6,
    this.abstractWarmupDuration = Duration.zero,
  });

  final int historyLimit;
  final int maxAttempts;
  final Duration abstractWarmupDuration;
}

class AvatarCarouselBuildContext {
  const AvatarCarouselBuildContext({
    required this.colors,
    required this.currentBackground,
  });

  final ShadColorScheme colors;
  final Color currentBackground;
}

class AvatarRenderSpec {
  const AvatarRenderSpec({
    required this.background,
    required this.insetFraction,
    required this.cropSide,
  });

  final Color background;
  final double insetFraction;
  final double cropSide;
}

typedef AvatarRenderSpecResolver =
    AvatarRenderSpec Function(
      AvatarTemplate template,
      AvatarCarouselBuildContext context,
    );

class AvatarCarouselEngine {
  AvatarCarouselEngine({
    required AvatarPipeline pipeline,
    required List<AvatarTemplate> templates,
    required Random random,
    AvatarCarouselEngineConfig config = const AvatarCarouselEngineConfig(),
  }) : _pipeline = pipeline,
       _random = random,
       _config = config,
       _abstractTemplates = templates
           .where(
             (template) => template.category == AvatarTemplateCategory.abstract,
           )
           .toList(growable: false),
       _nonAbstractTemplates = templates
           .where(
             (template) => template.category != AvatarTemplateCategory.abstract,
           )
           .toList(growable: false);

  final AvatarPipeline _pipeline;
  final Random _random;
  final AvatarCarouselEngineConfig _config;
  final List<AvatarTemplate> _abstractTemplates;
  final List<AvatarTemplate> _nonAbstractTemplates;

  final List<String> _recentTemplateKeys = <String>[];
  final List<AvatarTemplate> _abstractBag = <AvatarTemplate>[];
  final List<AvatarTemplate> _nonAbstractBag = <AvatarTemplate>[];
  DateTime? _abstractOnlyUntil;
  _NonAbstractWarmupState _nonAbstractWarmupState =
      _NonAbstractWarmupState.pending;

  void startWarmupIfNeeded() {
    if (_config.abstractWarmupDuration == Duration.zero) return;
    if (_abstractOnlyUntil != null) return;
    _abstractOnlyUntil = DateTime.now().add(_config.abstractWarmupDuration);
  }

  bool get abstractWarmupActive {
    final until = _abstractOnlyUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  bool get nonAbstractReady =>
      _nonAbstractWarmupState == _NonAbstractWarmupState.ready;

  AvatarTemplate? pickTemplate({required bool preferAbstract}) {
    final hasAbstract = _abstractTemplates.isNotEmpty;
    final hasOther = _nonAbstractTemplates.isNotEmpty;
    if (!hasAbstract && !hasOther) {
      return null;
    }
    if (!hasOther) {
      return _pickFromPool(_abstractTemplates, bag: _abstractBag);
    }
    if (!hasAbstract) {
      return _pickFromPool(_nonAbstractTemplates, bag: _nonAbstractBag);
    }
    if (preferAbstract) {
      return _pickFromPool(_abstractTemplates, bag: _abstractBag);
    }
    final useAbstract = _random.nextBool();
    return _pickFromPool(
      useAbstract ? _abstractTemplates : _nonAbstractTemplates,
      bag: useAbstract ? _abstractBag : _nonAbstractBag,
    );
  }

  void markTemplateUsed(AvatarTemplate template) {
    _recentTemplateKeys.add(_pipeline.templateKey(template));
    if (_recentTemplateKeys.length > _config.historyLimit) {
      _recentTemplateKeys.removeAt(0);
    }
  }

  void markNonAbstractReady(AvatarTemplate template) {
    if (template.category == AvatarTemplateCategory.abstract) {
      return;
    }
    _nonAbstractWarmupState = _NonAbstractWarmupState.ready;
  }

  Future<EditableAvatar?> buildNext({
    required AvatarCarouselBuildContext context,
    required AvatarRenderSpecResolver renderSpec,
    bool preferAbstract = false,
  }) async {
    final template = pickTemplate(preferAbstract: preferAbstract);
    if (template == null) return null;
    markTemplateUsed(template);
    final avatar = await _buildAvatarForTemplate(
      template: template,
      context: context,
      renderSpec: renderSpec,
    );
    if (avatar == null) return null;
    markNonAbstractReady(template);
    return avatar;
  }

  Future<List<EditableAvatar>> prefill({
    required int targetSize,
    required AvatarCarouselBuildContext context,
    required AvatarRenderSpecResolver renderSpec,
    required bool preferAbstract,
  }) async {
    final results = <EditableAvatar>[];
    if (targetSize <= 0) return results;
    final warmupActive = abstractWarmupActive;

    if (!warmupActive &&
        preferAbstract &&
        !nonAbstractReady &&
        _nonAbstractWarmupState != _NonAbstractWarmupState.warming &&
        _nonAbstractTemplates.isNotEmpty) {
      _nonAbstractWarmupState = _NonAbstractWarmupState.warming;
      final warmTemplate = _pickFromPool(
        _nonAbstractTemplates,
        bag: _nonAbstractBag,
      );
      if (warmTemplate != null) {
        markTemplateUsed(warmTemplate);
        final warmed = await _buildAvatarForTemplate(
          template: warmTemplate,
          context: context,
          renderSpec: renderSpec,
        );
        if (warmed != null) {
          results.add(warmed);
          markNonAbstractReady(warmTemplate);
        }
      }
      if (_nonAbstractWarmupState != _NonAbstractWarmupState.ready) {
        _nonAbstractWarmupState = _NonAbstractWarmupState.pending;
      }
    }

    var attempts = 0;
    while (results.length < targetSize && attempts < _config.maxAttempts) {
      final useAbstractOnly =
          (warmupActive || (preferAbstract && !nonAbstractReady)) &&
          _abstractTemplates.isNotEmpty;
      AvatarTemplate? template = useAbstractOnly
          ? _pickFromPool(_abstractTemplates, bag: _abstractBag)
          : null;
      template ??= pickTemplate(preferAbstract: false);
      if (template == null) break;
      attempts++;
      markTemplateUsed(template);
      final avatar = await _buildAvatarForTemplate(
        template: template,
        context: context,
        renderSpec: renderSpec,
      );
      if (avatar == null) continue;
      results.add(avatar);
      markNonAbstractReady(template);
    }

    return results;
  }

  AvatarTemplate? _pickFromPool(
    List<AvatarTemplate> pool, {
    required List<AvatarTemplate> bag,
  }) {
    if (pool.isEmpty) return null;
    if (bag.isEmpty) {
      bag
        ..clear()
        ..addAll(pool)
        ..shuffle(_random);
    }
    AvatarTemplate? selection;
    final recycled = <AvatarTemplate>[];
    while (bag.isNotEmpty) {
      final candidate = bag.removeAt(0);
      final key = _pipeline.templateKey(candidate);
      if (_recentTemplateKeys.contains(key)) {
        recycled.add(candidate);
        continue;
      }
      selection = candidate;
      break;
    }
    bag.addAll(recycled);
    selection ??= bag.isNotEmpty
        ? bag.removeAt(0)
        : pool[_random.nextInt(pool.length)];
    return selection;
  }

  Future<EditableAvatar?> _buildAvatarForTemplate({
    required AvatarTemplate template,
    required AvatarCarouselBuildContext context,
    required AvatarRenderSpecResolver renderSpec,
  }) async {
    final spec = renderSpec(template, context);
    try {
      return await _pipeline.buildFromTemplate(
        template: template,
        background: spec.background,
        colors: context.colors,
        insetFraction: spec.insetFraction,
        cropSide: spec.cropSide,
      );
    } on FormatException {
      return null;
    }
  }
}

enum _NonAbstractWarmupState { pending, warming, ready }
