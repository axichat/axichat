import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/avatar/bloc/signup_avatar_cubit.dart';
import 'package:axichat/src/avatar/editing/avatar_pipeline.dart';
import 'package:axichat/src/avatar/editing/editable_avatar.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'pauseOnPreviewAvatar halts the carousel without selecting the avatar',
    () {
      fakeAsync((async) {
        final colors = ShadColorScheme.fromName(
          'zinc',
          brightness: Brightness.light,
        );
        final cubit = SignupAvatarCubit(
          templates: <AvatarTemplate>[
            _fakeTemplate(id: 'preview-template-1'),
            _fakeTemplate(id: 'preview-template-2'),
          ],
          pipeline: _ImmediateSignupAvatarPipeline(),
        );

        unawaited(cubit.initialize(colors));
        async.flushMicrotasks();

        final initialPreview = cubit.state.carouselAvatar;
        expect(initialPreview, isNotNull);
        expect(cubit.state.avatar, isNull);

        unawaited(cubit.pauseOnPreviewAvatar(colors));
        async.flushMicrotasks();

        final pausedPreview = cubit.state.carouselAvatar;
        expect(pausedPreview, isNotNull);
        expect(cubit.state.avatar, isNull);
        expect(
          pausedPreview?.payload.hash,
          isNot(equals(initialPreview?.payload.hash)),
        );

        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(identical(cubit.state.carouselAvatar, pausedPreview), isTrue);
        expect(
          cubit.state.carouselAvatar?.payload.hash,
          isNot(equals(initialPreview?.payload.hash)),
        );
        expect(cubit.state.canUseCarouselAvatar, isTrue);
        expect(cubit.state.hasUserSelectedAvatar, isFalse);
        expect(cubit.selectedAvatarPayload(), isNull);
      });
    },
  );

  test(
    'pauseOnPreviewAvatar clears a selected signup avatar before previewing',
    () {
      fakeAsync((async) {
        final colors = ShadColorScheme.fromName(
          'zinc',
          brightness: Brightness.light,
        );
        final cubit = SignupAvatarCubit(
          templates: <AvatarTemplate>[
            _fakeTemplate(id: 'preview-template-1'),
            _fakeTemplate(id: 'preview-template-2'),
          ],
          pipeline: _ImmediateSignupAvatarPipeline(),
        );

        unawaited(cubit.initialize(colors));
        async.flushMicrotasks();

        cubit.selectCarouselAvatar();
        expect(cubit.state.hasUserSelectedAvatar, isTrue);

        unawaited(cubit.pauseOnPreviewAvatar(colors));
        async.flushMicrotasks();

        expect(cubit.state.hasUserSelectedAvatar, isFalse);
        expect(cubit.state.canUseCarouselAvatar, isTrue);
        expect(cubit.selectedAvatarPayload(), isNull);
      });
    },
  );

  test(
    'pauseOnPreviewAvatar preserves a shuffled background between rotations',
    () {
      fakeAsync((async) {
        final colors = ShadColorScheme.fromName(
          'zinc',
          brightness: Brightness.light,
        );
        final cubit = SignupAvatarCubit(
          templates: <AvatarTemplate>[
            _fakeTemplate(id: 'preview-template-1', hasAlphaBackground: true),
            _fakeTemplate(id: 'preview-template-2', hasAlphaBackground: true),
          ],
          pipeline: _ImmediateSignupAvatarPipeline(
            backgrounds: const <Color>[Colors.red, Colors.green],
          ),
        );

        unawaited(cubit.initialize(colors));
        async.flushMicrotasks();

        expect(cubit.state.canShuffleBackground, isTrue);

        unawaited(cubit.shuffleBackground(colors));
        async.flushMicrotasks();

        final lockedBackground = cubit.state.lockedBackgroundColor;
        expect(cubit.state.backgroundLocked, isTrue);
        expect(lockedBackground, isNotNull);
        expect(cubit.state.backgroundColor, lockedBackground);
        expect(cubit.state.carouselAvatar?.backgroundColor, lockedBackground);

        unawaited(cubit.pauseOnPreviewAvatar(colors));
        async.flushMicrotasks();

        expect(cubit.state.avatar, isNull);
        expect(cubit.state.backgroundLocked, isTrue);
        expect(cubit.state.lockedBackgroundColor, lockedBackground);
        expect(cubit.state.backgroundColor, lockedBackground);
        expect(cubit.state.carouselAvatar?.backgroundColor, lockedBackground);
      });
    },
  );
}

class _ImmediateSignupAvatarPipeline extends AvatarPipeline {
  _ImmediateSignupAvatarPipeline({List<Color> backgrounds = const <Color>[]})
    : _backgrounds = backgrounds,
      super(
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

  final List<Color> _backgrounds;
  int _backgroundIndex = 0;

  @override
  Color randomBackground(math.Random random) {
    if (_backgrounds.isEmpty) {
      return super.randomBackground(random);
    }
    final background = _backgrounds[_backgroundIndex % _backgrounds.length];
    _backgroundIndex++;
    return background;
  }

  @override
  Future<EditableAvatar> buildFromTemplate({
    required AvatarTemplate template,
    required Color background,
    required ShadColorScheme colors,
    required double insetFraction,
    double cropSide = 100000.0,
  }) async {
    final payloadBytes = Uint8List.fromList(template.id.codeUnits);
    return EditableAvatar(
      source: AvatarSource.template,
      payload: AvatarUploadPayload(
        bytes: payloadBytes,
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

AvatarTemplate _fakeTemplate({
  required String id,
  bool hasAlphaBackground = false,
}) {
  return AvatarTemplate(
    id: id,
    category: AvatarTemplateCategory.misc,
    hasAlphaBackground: hasAlphaBackground,
    generator: (background, colors) async => GeneratedAvatar(
      bytes: Uint8List.fromList(const <int>[0, 1, 2, 3]),
      mimeType: 'image/png',
      width: 1,
      height: 1,
      hasAlpha: false,
    ),
  );
}
