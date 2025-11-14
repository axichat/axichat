import 'dart:math' as math;

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

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeInOut,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: loginSelected
            ? _YinYangCard(
                key: const ValueKey(_AuthMode.login),
                mode: _AuthMode.login,
                duration: duration,
                onPrimaryPressed: () => onChanged(true),
                onCutoutPressed: () => onChanged(false),
              )
            : _YinYangCard(
                key: const ValueKey(_AuthMode.signup),
                mode: _AuthMode.signup,
                duration: duration,
                onPrimaryPressed: () => onChanged(false),
                onCutoutPressed: () => onChanged(true),
              ),
      ),
    );
  }
}

enum _AuthMode { login, signup }

class _YinYangCard extends StatelessWidget {
  const _YinYangCard({
    super.key,
    required this.mode,
    required this.duration,
    required this.onPrimaryPressed,
    required this.onCutoutPressed,
  });

  final _AuthMode mode;
  final Duration duration;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onCutoutPressed;

  static const _cutoutDepth = 48.0;
  static const _cornerRadius = 26.0;

  bool get _isLogin => mode == _AuthMode.login;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final accent = _isLogin ? colors.primary : colors.accent;
    final primaryLabel = _isLogin ? 'Log in' : 'Sign up';
    final primarySubtitle = _isLogin
        ? 'Welcome back to your encrypted chats'
        : 'Create your secure Axichat ID';
    final primaryIcon = _isLogin ? Icons.lock_outline : Icons.person_add_alt_1;
    final alternateLabel = _isLogin ? 'Sign up' : 'Log in';
    final alternateSubtitle =
        _isLogin ? 'Need an account? Create one.' : 'Already onboard? Log in.';
    final alternateIcon =
        _isLogin ? Icons.person_add_alt : Icons.lock_open_outlined;
    final cutoutEdge = _isLogin ? CutoutEdge.bottom : CutoutEdge.top;
    final topPadding = cutoutEdge == CutoutEdge.top ? _cutoutDepth : 0.0;
    final bottomPadding = cutoutEdge == CutoutEdge.bottom ? _cutoutDepth : 0.0;

    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final resolvedThickness = math.max(180.0, maxWidth - 64);
          final shape = SquircleBorder(
            cornerRadius: _cornerRadius,
            side: BorderSide(color: colors.border),
          );
          return CutoutSurface(
            backgroundColor: colors.card,
            borderColor: colors.border,
            shadowOpacity: 0.22,
            shadows: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 36,
                offset: const Offset(0, 20),
              ),
            ],
            shape: shape,
            cutouts: [
              CutoutSpec(
                edge: cutoutEdge,
                alignment: Alignment.center,
                depth: _cutoutDepth,
                thickness: resolvedThickness,
                cornerRadius: 22,
                child: _YinYangCutoutButton(
                  label: alternateLabel,
                  subtitle: alternateSubtitle,
                  icon: alternateIcon,
                  accent: accent,
                  onPressed: onCutoutPressed,
                ),
              ),
            ],
            child: _YinYangPrimaryBody(
              label: primaryLabel,
              subtitle: primarySubtitle,
              icon: primaryIcon,
              accent: accent,
              onPressed: onPrimaryPressed,
              alignStart: _isLogin,
            ),
          );
        },
      ),
    );
  }
}

class _YinYangPrimaryBody extends StatelessWidget {
  const _YinYangPrimaryBody({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onPressed,
    required this.alignStart,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onPressed;
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final alignment =
        alignStart ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    final textAlign = alignStart ? TextAlign.left : TextAlign.right;
    final gradient = LinearGradient(
      begin: alignStart ? Alignment.topLeft : Alignment.topRight,
      end: alignStart ? Alignment.bottomRight : Alignment.bottomLeft,
      colors: [
        accent.withValues(alpha: 0.18),
        accent.withValues(alpha: 0.08),
      ],
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(_YinYangCard._cornerRadius - 4),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 48),
          child: Column(
            crossAxisAlignment: alignment,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: accent),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: textAlign,
                style: context.textTheme.h3.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: textAlign,
                style: context.textTheme.p.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    ).withTapBounce();
  }
}

class _YinYangCutoutButton extends StatelessWidget {
  const _YinYangCutoutButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onPressed,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 26,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: onPressed,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    Icon(icon, size: 22, color: accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: context.textTheme.p.copyWith(
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: context.textTheme.small.copyWith(
                              color: colors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: colors.mutedForeground,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
