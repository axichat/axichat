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
                              const ShorebirdChecker(),
                              DecoratedBox(
                                decoration: ShapeDecoration(
                                  color: colors.card,
                                  shape: SquircleBorder(
                                    cornerRadius: 20,
                                    side: BorderSide(color: colors.border),
                                  ),
                                ),
                                child: AnimatedCrossFade(
                                  crossFadeState: _login
                                      ? CrossFadeState.showFirst
                                      : CrossFadeState.showSecond,
                                  duration: context
                                      .read<SettingsCubit>()
                                      .animationDuration,
                                  firstChild: const Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: LoginForm(),
                                  ),
                                  secondChild: const Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: SignupForm(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // NOTE: Keep the morphing auth toggle below for later polish.
                              /*
                              _AuthModeToggle(
                                loginSelected: _login,
                                duration:
                                    context.read<SettingsCubit>().animationDuration,
                                onChanged: (isLogin) {
                                  if (_login == isLogin) return;
                                  setState(() {
                                    _login = isLogin;
                                  });
                                },
                              ),
                              */
                              ShadButton.ghost(
                                onPressed: () {
                                  setState(() {
                                    _login = !_login;
                                  });
                                },
                                child: Text(
                                  _login
                                      ? 'New? Sign up'
                                      : 'Already registered? Log in',
                                ),
                              ).withTapBounce(),
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
                              const SizedBox(height: 18),
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

// ignore: unused_element
class _AuthModeToggle extends StatelessWidget {
  const _AuthModeToggle({
    required this.loginSelected,
    required this.onChanged,
    required this.duration,
  });

  final bool loginSelected;
  final ValueChanged<bool> onChanged;
  final Duration duration;

  static const double _overlap =
      _MorphingAuthButton._cutoutDepth - 4; // Pulls buttons together

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 240.0;
        final width = math.min(240.0, math.max(190.0, maxWidth));
        return Center(
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MorphingAuthButton(
                  label: 'Log in',
                  selected: loginSelected,
                  cutoutEdge: CutoutEdge.bottom,
                  width: width,
                  duration: duration,
                  onTap: () => onChanged(true),
                ),
                Transform.translate(
                  offset: const Offset(0, -_AuthModeToggle._overlap),
                  child: _MorphingAuthButton(
                    label: 'Sign up',
                    selected: !loginSelected,
                    cutoutEdge: CutoutEdge.top,
                    width: width,
                    duration: duration,
                    onTap: () => onChanged(false),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MorphingAuthButton extends StatefulWidget {
  const _MorphingAuthButton({
    required this.label,
    required this.selected,
    required this.cutoutEdge,
    required this.width,
    required this.duration,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final CutoutEdge cutoutEdge;
  final double width;
  final Duration duration;
  final VoidCallback onTap;

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
        final compactWidth = widget.width * 0.55;
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
        final borderWidth = lerpDouble(1, 1.8, t) ?? 1.3;
        final cutoutThickness = lerpDouble(0, widget.width - 28, t) ?? 0;
        final cutoutDepth = _MorphingAuthButton._cutoutDepth * t;
        final fillColor =
            Color.lerp(colors.card, colors.primary, t) ?? colors.card;
        final textColor = Color.lerp(
              colors.foreground,
              colors.primaryForeground,
              t,
            ) ??
            colors.foreground;
        final edgePadding = EdgeInsets.only(
          top: widget.cutoutEdge == CutoutEdge.top ? cutoutDepth * 0.6 : 0,
          bottom:
              widget.cutoutEdge == CutoutEdge.bottom ? cutoutDepth * 0.6 : 0,
        );
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
              backgroundColor: fillColor,
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
              child: Padding(
                padding: edgePadding,
                child: Center(
                  child: Text(
                    widget.label,
                    style: context.textTheme.p.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
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
