import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/view/debug_delete_credentials.dart';
import 'package:axichat/src/authentication/view/login_form.dart';
import 'package:axichat/src/authentication/view/signup_form.dart';
import 'package:axichat/src/chat/view/chat.dart';
import 'package:axichat/src/common/shorebird_push.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  var _login = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AxiAppBar(
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AxiVersion(),
                  if (kDebugMode) ...[
                    const SizedBox(width: 8),
                    DeleteCredentialsButton(),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colors.background,
                  border: Border(
                    top: BorderSide(color: colors.border),
                  ),
                ),
                child: AxiAdaptiveLayout(
                  primaryChild: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: ShorebirdChecker(),
                              ),
                              DecoratedBox(
                                decoration: ShapeDecoration(
                                  color: colors.card,
                                  shape: SquircleBorder(
                                    cornerRadius: 20,
                                    side: BorderSide(color: colors.border),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: AnimatedCrossFade(
                                    crossFadeState: _login
                                        ? CrossFadeState.showFirst
                                        : CrossFadeState.showSecond,
                                    duration: context
                                        .read<SettingsCubit>()
                                        .animationDuration,
                                    firstChild: const LoginForm(),
                                    secondChild: const SignupForm(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _AuthModeToggle(
                                loginSelected: _login,
                                duration: context
                                    .read<SettingsCubit>()
                                    .animationDuration,
                                onChanged: (isLogin) {
                                  if (_login == isLogin) return;
                                  setState(() {
                                    _login = isLogin;
                                  });
                                },
                              ),
                              const SizedBox(height: 18),
                              ShadButton.outline(
                                onPressed: () => context.go('/guest-calendar'),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_today),
                                    SizedBox(width: 8),
                                    Text('Try Calendar (Guest Mode)'),
                                  ],
                                ),
                              ).withTapBounce(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  secondaryChild: const GuestChat(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthModeToggle extends StatelessWidget {
  const _AuthModeToggle({
    required this.loginSelected,
    required this.onChanged,
    required this.duration,
  });

  final bool loginSelected;
  final ValueChanged<bool> onChanged;
  final Duration duration;

  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(320.0, math.max(220.0, constraints.maxWidth));
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MorphingAuthButton(
              label: 'Log in',
              alternateLabel: 'Sign up',
              selected: loginSelected,
              cutoutEdge: CutoutEdge.bottom,
              width: width,
              duration: duration,
              onTap: () => onChanged(true),
              onAlternateTap: () => onChanged(false),
            ),
            const SizedBox(height: _gap),
            _MorphingAuthButton(
              label: 'Sign up',
              alternateLabel: 'Log in',
              selected: !loginSelected,
              cutoutEdge: CutoutEdge.top,
              width: width,
              duration: duration,
              onTap: () => onChanged(false),
              onAlternateTap: () => onChanged(true),
            ),
          ],
        );
      },
    );
  }
}

class _MorphingAuthButton extends StatefulWidget {
  const _MorphingAuthButton({
    required this.label,
    required this.alternateLabel,
    required this.selected,
    required this.cutoutEdge,
    required this.width,
    required this.duration,
    required this.onTap,
    required this.onAlternateTap,
  });

  final String label;
  final String alternateLabel;
  final bool selected;
  final CutoutEdge cutoutEdge;
  final double width;
  final Duration duration;
  final VoidCallback onTap;
  final VoidCallback onAlternateTap;

  static const double _primaryHeight = 60;
  static const double _compactHeight = 38;
  static const double _cutoutDepth = 22;

  @override
  State<_MorphingAuthButton> createState() => _MorphingAuthButtonState();
}

class _MorphingAuthButtonState extends State<_MorphingAuthButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.selected ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant _MorphingAuthButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.selected != widget.selected) {
      if (widget.selected) {
        _controller.animateTo(1, curve: Curves.easeInOut);
      } else {
        _controller.animateTo(0, curve: Curves.easeInOut);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        final expandedWidth = widget.width;
        final compactWidth = widget.width * 0.6;
        final currentWidth =
            lerpDouble(compactWidth, expandedWidth, t) ?? expandedWidth;
        final height = lerpDouble(
              _MorphingAuthButton._compactHeight,
              _MorphingAuthButton._primaryHeight,
              t,
            ) ??
            _MorphingAuthButton._primaryHeight;
        final borderRadius = lerpDouble(18, 26, t) ?? 26;
        final borderColor = Color.lerp(
              colors.border.withValues(alpha: 0.9),
              colors.primary,
              t,
            ) ??
            colors.border;
        final borderWidth = lerpDouble(1, 1.4, t) ?? 1.2;
        final cutoutThickness = lerpDouble(0, currentWidth * 0.6, t) ?? 0;
        final cutoutDepth = _MorphingAuthButton._cutoutDepth * t;
        final cutouts = <CutoutSpec>[];
        if (cutoutDepth > 0.1 && cutoutThickness > 18) {
          cutouts.add(
            CutoutSpec(
              edge: widget.cutoutEdge,
              alignment: Alignment.center,
              depth: cutoutDepth,
              thickness: cutoutThickness,
              cornerRadius: 18,
              child: const SizedBox.shrink(),
            ),
          );
        }
        return SizedBox(
          width: currentWidth,
          height: height,
          child: GestureDetector(
            onTap: widget.onTap,
            child: CutoutSurface(
              backgroundColor: colors.card,
              borderColor: borderColor,
              shadowOpacity: 0.15 * t,
              shadows: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.2 * t),
                  blurRadius: 18,
                  offset: Offset(0, 12 * t),
                ),
              ],
              shape: SquircleBorder(
                cornerRadius: borderRadius,
                side: BorderSide(color: borderColor, width: borderWidth),
              ),
              cutouts: cutouts,
              child: Center(
                child: Text(
                  widget.label,
                  style: context.textTheme.p.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ).withTapBounce(),
          ),
        );
      },
    );
  }
}
