import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/avatar/editing/avatar_carousel_engine.dart';
import 'package:axichat/src/avatar/editing/avatar_carousel_session.dart';
import 'package:axichat/src/avatar/editing/avatar_pipeline.dart';
import 'package:axichat/src/avatar/editing/editable_avatar.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('seeded start emits the seed first and advances on the timer', () {
    fakeAsync((async) {
      final frames = <AvatarCarouselFrame>[];
      var running = false;
      final session = _buildSession(
        templates: <AvatarTemplate>[
          _fakeTemplate(id: 'template-1'),
          _fakeTemplate(id: 'template-2'),
        ],
        onRunningChanged: (value) => running = value,
        onPreviewChanged: frames.add,
      );
      final seed = _avatar(hash: 'seed');

      unawaited(session.start(_colors(), seed: seed));
      async.flushMicrotasks();

      expect(running, isTrue);
      expect(frames, hasLength(1));
      expect(frames.single.avatar.payload.hash, 'seed');

      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();

      expect(frames, hasLength(2));
      expect(frames.last.avatar.payload.hash, isNot('seed'));
    });
  });

  test('resume restarts the current avatar timer before advancing', () {
    fakeAsync((async) {
      final frames = <AvatarCarouselFrame>[];
      final session = _buildSession(
        templates: <AvatarTemplate>[
          _fakeTemplate(id: 'template-1'),
          _fakeTemplate(id: 'template-2'),
        ],
        onPreviewChanged: frames.add,
      );
      final seed = _avatar(hash: 'seed');

      unawaited(session.start(_colors(), seed: seed));
      async.flushMicrotasks();
      session.stop();

      unawaited(session.resume());
      async.flushMicrotasks();

      expect(frames, hasLength(2));
      expect(frames.last.avatar.payload.hash, 'seed');

      async.elapse(
        const Duration(seconds: 2) - const Duration(microseconds: 1),
      );
      async.flushMicrotasks();

      expect(frames, hasLength(2));

      async.elapse(const Duration(microseconds: 1));
      async.flushMicrotasks();

      expect(frames, hasLength(3));
      expect(frames.last.avatar.payload.hash, isNot('seed'));
    });
  });

  test('manual preview consumes a buffered avatar before building', () {
    fakeAsync((async) {
      final pipeline = _ImmediatePipeline();
      final frames = <AvatarCarouselFrame>[];
      final session = _buildSession(
        templates: <AvatarTemplate>[
          _fakeTemplate(id: 'template-1'),
          _fakeTemplate(id: 'template-2'),
          _fakeTemplate(id: 'template-3'),
        ],
        pipeline: pipeline,
        onPreviewChanged: frames.add,
      );

      unawaited(session.start(_colors()));
      async.flushMicrotasks();
      final buildCountAfterStart = pipeline.buildCount;

      EditableAvatar? manualPreview;
      unawaited(
        session
            .manualPreview(_colors())
            .then((avatar) => manualPreview = avatar),
      );
      async.flushMicrotasks();

      expect(manualPreview, isNotNull);
      expect(pipeline.buildCount, buildCountAfterStart);
    });
  });

  test('fallback is emitted when templates cannot build', () {
    fakeAsync((async) {
      final frames = <AvatarCarouselFrame>[];
      var running = false;
      final session = _buildSession(
        templates: <AvatarTemplate>[],
        onRunningChanged: (value) => running = value,
        onPreviewChanged: frames.add,
      );

      unawaited(session.start(_colors()));
      async.flushMicrotasks();

      expect(frames, hasLength(1));
      expect(frames.single.avatar.payload.bytes, isNotEmpty);
      expect(running, isFalse);

      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();

      expect(frames, hasLength(1));
    });
  });

  test(
    'timer holds the current avatar until a delayed next avatar is ready',
    () {
      fakeAsync((async) {
        final frames = <AvatarCarouselFrame>[];
        final buildCompleter = Completer<EditableAvatar>();
        final session = _buildSession(
          templates: <AvatarTemplate>[_fakeTemplate(id: 'delayed')],
          pipeline: _DelayedPipeline(buildCompleter),
          onPreviewChanged: frames.add,
        );
        final seed = _avatar(hash: 'seed');

        unawaited(session.start(_colors(), seed: seed));
        async.flushMicrotasks();

        expect(frames, hasLength(1));
        expect(frames.single.avatar.payload.hash, 'seed');

        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(frames, hasLength(1));

        buildCompleter.complete(_avatar(hash: 'next'));
        async.flushMicrotasks();

        expect(frames, hasLength(2));
        expect(frames.last.avatar.payload.hash, 'next');

        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(frames, hasLength(3));
      });
    },
  );

  test('reset prevents a delayed build from emitting', () {
    fakeAsync((async) {
      final frames = <AvatarCarouselFrame>[];
      final buildCompleter = Completer<EditableAvatar>();
      final session = _buildSession(
        templates: <AvatarTemplate>[_fakeTemplate(id: 'delayed')],
        pipeline: _DelayedPipeline(buildCompleter),
        onPreviewChanged: frames.add,
      );

      unawaited(session.start(_colors()));
      async.flushMicrotasks();

      session.reset();
      buildCompleter.complete(_avatar(hash: 'late'));
      async.flushMicrotasks();

      expect(frames, isEmpty);
    });
  });
}

AvatarCarouselSession _buildSession({
  required List<AvatarTemplate> templates,
  AvatarPipeline? pipeline,
  void Function(bool running)? onRunningChanged,
  void Function(AvatarCarouselFrame frame)? onPreviewChanged,
}) {
  final resolvedPipeline = pipeline ?? _ImmediatePipeline();
  final engine = AvatarCarouselEngine(
    pipeline: resolvedPipeline,
    templates: templates,
    random: Random(1),
  );
  return AvatarCarouselSession(
    engine: engine,
    interval: const Duration(seconds: 2),
    initialBufferSize: 2,
    sustainBufferSize: 1,
    canRun: () => true,
    currentBackground: () => Colors.blue,
    renderSpec: (template, context) => AvatarRenderSpec(
      background: context.currentBackground,
      insetFraction: 0,
      cropSide: 1000,
    ),
    preferAbstract: () => false,
    fallbackAvatar: (_) => buildAvatarCarouselFallback(
      pipeline: resolvedPipeline,
      background: Colors.blue,
      accent: Colors.green,
    ),
    onRunningChanged: onRunningChanged ?? (_) {},
    onPreviewChanged: onPreviewChanged ?? (_) {},
  );
}

ShadColorScheme _colors() {
  return ShadColorScheme.fromName('zinc', brightness: Brightness.light);
}

AvatarTemplate _fakeTemplate({required String id}) {
  return AvatarTemplate(
    id: id,
    category: AvatarTemplateCategory.misc,
    hasAlphaBackground: false,
    generator: (background, colors) async => GeneratedAvatar(
      bytes: Uint8List.fromList(id.codeUnits),
      mimeType: 'image/png',
      width: 1,
      height: 1,
      hasAlpha: false,
    ),
  );
}

EditableAvatar _avatar({required String hash}) {
  final bytes = Uint8List.fromList(hash.codeUnits);
  return EditableAvatar(
    source: AvatarSource.template,
    payload: AvatarUploadPayload(
      bytes: bytes,
      mimeType: 'image/png',
      width: 1,
      height: 1,
      hash: hash,
    ),
  );
}

class _ImmediatePipeline extends AvatarPipeline {
  _ImmediatePipeline()
    : super(
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

  int buildCount = 0;

  @override
  Future<EditableAvatar> buildFromTemplate({
    required AvatarTemplate template,
    required Color background,
    required ShadColorScheme colors,
    required double insetFraction,
    double cropSide = 100000.0,
  }) async {
    buildCount += 1;
    return EditableAvatar(
      source: AvatarSource.template,
      payload: AvatarUploadPayload(
        bytes: Uint8List.fromList(template.id.codeUnits),
        mimeType: 'image/png',
        width: 1,
        height: 1,
        hash: template.id,
      ),
      template: template,
      backgroundColor: background,
    );
  }
}

class _DelayedPipeline extends _ImmediatePipeline {
  _DelayedPipeline(this.buildCompleter);

  final Completer<EditableAvatar> buildCompleter;

  @override
  Future<EditableAvatar> buildFromTemplate({
    required AvatarTemplate template,
    required Color background,
    required ShadColorScheme colors,
    required double insetFraction,
    double cropSide = 100000.0,
  }) {
    return buildCompleter.future;
  }
}
