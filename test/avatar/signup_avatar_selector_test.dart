import 'package:animations/animations.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/avatar/view/signup_avatar_preview.dart';
import 'package:axichat/src/avatar/view/signup_avatar_selector.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('wrapper radius matches the avatar squircle radius', (
    tester,
  ) async {
    await tester.pumpWidget(
      _SelectorTestApp(
        child: SignupAvatarSelector(
          bytes: null,
          username: 'room',
          processing: false,
          showRotationTimer: false,
          animationDuration: Duration.zero,
          rotationDuration: const Duration(seconds: 2),
          onTap: () {},
        ),
      ),
    );

    final context = tester.element(find.byType(SignupAvatarSelector));
    final avatarSize = context.sizing.iconButtonTapTarget;
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(SignupAvatarSelector),
        matching: find.byType(Material),
      ),
    );
    final shape = material.shape! as RoundedSuperellipseBorder;
    final borderRadius = shape.borderRadius.resolve(TextDirection.ltr);

    expect(
      borderRadius.topLeft.x,
      axiAvatarSquircleRadius(context, avatarSize),
    );
  });

  testWidgets('timed carousel avatar changes do not cross-fade', (
    tester,
  ) async {
    await tester.pumpWidget(
      _SelectorTestApp(
        child: SignupAvatarPreview(
          bytes: null,
          displayLabel: 'avatar@axichat',
          size: 48,
          animationDuration: const Duration(milliseconds: 300),
          rotationDuration: const Duration(seconds: 2),
          rotationStartedAt: DateTime.timestamp(),
          showRotationTimer: true,
          transitionKey: 1,
        ),
      ),
    );

    final switcher = tester.widget<PageTransitionSwitcher>(
      find.byType(PageTransitionSwitcher),
    );

    expect(switcher.duration, Duration.zero);
  });

  testWidgets(
    'manual avatar preview keeps the configured transition duration',
    (tester) async {
      const animationDuration = Duration(milliseconds: 300);
      await tester.pumpWidget(
        _SelectorTestApp(
          child: SignupAvatarPreview(
            bytes: null,
            displayLabel: 'avatar@axichat',
            size: 48,
            animationDuration: animationDuration,
            rotationDuration: const Duration(seconds: 2),
            rotationStartedAt: null,
            showRotationTimer: false,
            transitionKey: 1,
          ),
        ),
      );

      final switcher = tester.widget<PageTransitionSwitcher>(
        find.byType(PageTransitionSwitcher),
      );

      expect(switcher.duration, animationDuration);
    },
  );
}

class _SelectorTestApp extends StatelessWidget {
  const _SelectorTestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        extensions: const [
          axiBorders,
          axiRadii,
          axiSpacing,
          axiSizing,
          axiMotion,
        ],
      ),
      home: ShadTheme(
        data: ShadThemeData(
          colorScheme: const ShadSlateColorScheme.light(),
          brightness: Brightness.light,
        ),
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }
}
