import 'dart:async';
import 'dart:typed_data';

import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/avatar/bloc/avatar_editor_cubit.dart';
import 'package:axichat/src/avatar/models/avatar_models.dart';
import 'package:axichat/src/avatar/util/avatar_pipeline.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class _MockXmppService extends Mock implements XmppService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockXmppService xmppService;

  setUp(() {
    xmppService = _MockXmppService();
    when(() => xmppService.cachedSelfAvatar).thenReturn(null);
    when(() => xmppService.getOwnAvatar()).thenAnswer((_) async => null);
  });

  test('close invalidates a delayed carousel tick before it can emit', () {
    fakeAsync((async) {
      final templates = <AvatarTemplate>[];
      final buildCompleter = Completer<Avatar>();
      final cubit = AvatarEditorCubit(
        xmppService: xmppService,
        templates: templates,
        pipeline: _TestAvatarPipeline(buildCompleter: buildCompleter),
      );
      final colors = ShadColorScheme.fromName(
        'zinc',
        brightness: Brightness.light,
      );

      unawaited(cubit.setCarouselEnabled(true, colors));
      async.flushMicrotasks();

      templates.add(_fakeTemplate(id: 'delayed-template'));

      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();

      expect(cubit.state.carouselAvatar, isNull);

      unawaited(cubit.close());
      async.flushMicrotasks();

      buildCompleter.complete(
        _avatarFromTemplate(
          template: templates.single,
          background: colors.accent,
        ),
      );
      async.flushMicrotasks();

      expect(cubit.state.carouselAvatar, isNull);
    });
  });
}

class _TestAvatarPipeline extends AvatarPipeline {
  _TestAvatarPipeline({required this.buildCompleter})
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

  final Completer<Avatar> buildCompleter;

  @override
  Future<Avatar> buildFromTemplate({
    required AvatarTemplate template,
    required Color background,
    required ShadColorScheme colors,
    required double insetFraction,
    double cropSide = 100000.0,
  }) {
    return buildCompleter.future;
  }
}

AvatarTemplate _fakeTemplate({required String id}) {
  return AvatarTemplate(
    id: id,
    category: AvatarTemplateCategory.misc,
    hasAlphaBackground: false,
    generator: (background, colors) async => GeneratedAvatar(
      bytes: Uint8List.fromList(const [0, 1, 2, 3]),
      mimeType: 'image/png',
      width: 1,
      height: 1,
      hasAlpha: false,
    ),
  );
}

Avatar _avatarFromTemplate({
  required AvatarTemplate template,
  required Color background,
}) {
  return Avatar(
    source: AvatarSource.template,
    payload: AvatarUploadPayload(
      bytes: Uint8List.fromList(const [1, 2, 3, 4]),
      mimeType: 'image/png',
      width: 1,
      height: 1,
      hash: 'hash',
    ),
    template: template,
    backgroundColor: background,
  );
}
