// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum EndpointConfigSheetMode {
  login,
  signup;

  bool get isSignup => this == signup;
}

class EndpointConfigSheet extends StatefulWidget {
  const EndpointConfigSheet({
    super.key,
    required this.compact,
    required this.mode,
    this.initialConfig,
  });

  final bool compact;
  final EndpointConfigSheetMode mode;
  final EndpointConfig? initialConfig;

  static Future<EndpointConfig?> show(
    BuildContext context, {
    EndpointConfigSheetMode mode = EndpointConfigSheetMode.login,
    EndpointConfig? initialConfig,
  }) {
    final commandSurface = resolveCommandSurface(context);
    final bool compact = commandSurface == CommandSurface.sheet;
    final sizing = context.sizing;
    return showAdaptiveBottomSheet<EndpointConfig>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      preferDialogOnMobile: true,
      showDragHandle: compact,
      dialogMaxWidth: sizing.dialogMaxWidth,
      surfacePadding: EdgeInsets.zero,
      builder: (_) => EndpointConfigSheet(
        compact: compact,
        mode: mode,
        initialConfig: initialConfig,
      ),
    );
  }

  @override
  State<EndpointConfigSheet> createState() => _EndpointConfigSheetState();
}

class _EndpointConfigSheetState extends State<EndpointConfigSheet> {
  late TextEditingController _domainController;
  late TextEditingController _emailProvisioningPublicTokenController;

  EndpointConfig? _draftConfig;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _domainController = TextEditingController();
    _emailProvisioningPublicTokenController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draftConfig != null) return;
    final config =
        widget.initialConfig ??
        context.read<SettingsCubit>().state.endpointConfig;
    _draftConfig = config;
    _domainController.text = config.isDefaultDomain ? '' : config.domain;
    _emailProvisioningPublicTokenController.text =
        config.emailProvisioningPublicToken ?? '';
  }

  @override
  void dispose() {
    _domainController.dispose();
    _emailProvisioningPublicTokenController.dispose();
    super.dispose();
  }

  EndpointConfig _resolveConfig(EndpointConfig current) {
    final candidate = _domainController.text.trim();
    final resolvedDomain = widget.mode.isSignup && candidate.isEmpty
        ? ''
        : candidate.isEmpty
        ? current.domain
        : candidate;
    final parsed = InternetAddress.tryParse(resolvedDomain);
    final fallbackDomain = InternetAddress.tryParse(current.domain) == null
        ? current.domain
        : EndpointConfig.defaultDomain;
    final domain = parsed == null ? resolvedDomain : fallbackDomain;
    final emailProvisioningPublicToken = _emailProvisioningPublicTokenController
        .text
        .trim();

    return current.copyWith(
      domain: domain,
      imapHost: null,
      smtpHost: null,
      imapPort: EndpointConfig.defaultImapPort,
      smtpPort: EndpointConfig.defaultSmtpPort,
      apiPort: EndpointConfig.defaultApiPort,
      emailProvisioningPublicToken: emailProvisioningPublicToken.isEmpty
          ? null
          : emailProvisioningPublicToken,
    );
  }

  Future<void> _save() async {
    final baseConfig =
        _draftConfig ?? context.read<SettingsCubit>().state.endpointConfig;
    final updated = _resolveConfig(baseConfig);
    if (widget.mode.isSignup &&
        (updated.domain.trim().isEmpty ||
            updated.requiresCustomSignupEndpoint)) {
      setState(() {
        _errorText = context.l10n.signupCustomEndpointRequired;
      });
      return;
    }
    if (!widget.mode.isSignup) {
      context.read<SettingsCubit>().updateEndpointConfig(updated);
    }
    if (!mounted) return;
    Navigator.of(context).pop(updated);
  }

  Future<void> _reset() async {
    if (widget.mode.isSignup) {
      Navigator.of(context).pop();
      return;
    }
    await context.read<SettingsCubit>().resetEndpointConfig();
    if (!mounted) return;
    Navigator.of(context).pop(const EndpointConfig());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final spacing = context.spacing;
    final config =
        _draftConfig ?? context.watch<SettingsCubit>().state.endpointConfig;
    final placeholderStyle = textTheme.muted;
    return AxiSheetScaffold.scroll(
      header: AxiSheetHeader(
        title: Text(context.l10n.authCustomServerTitle),
        onClose: () => Navigator.of(context).maybePop(),
      ),
      children: [
        Text(
          widget.mode.isSignup
              ? context.l10n.authCustomServerSignupDescription
              : context.l10n.authCustomServerDescription,
          style: textTheme.muted,
        ),
        if (widget.mode.isSignup) ...[
          SizedBox(height: spacing.s),
          Text(
            context.l10n.signupAxiImUnavailableDescription,
            style: textTheme.muted,
          ),
        ],
        if (_errorText != null) ...[
          SizedBox(height: spacing.s),
          Text(
            _errorText!,
            style: textTheme.small.copyWith(
              color: context.colorScheme.destructive,
            ),
          ),
        ],
        SizedBox(height: spacing.m),
        AxiTextFormField(
          autocorrect: false,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          maxLines: 1,
          placeholderAlignment: Alignment.centerLeft,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9.-]')),
          ],
          controller: _domainController,
          placeholder: Text(
            context.l10n.authEndpointDomainPlaceholder,
            style: placeholderStyle,
          ),
          placeholderStyle: placeholderStyle,
        ),
        SizedBox(height: spacing.s),
        _ToggleTile(
          label: context.l10n.authCustomServerSmtpLabel,
          value: config.smtpEnabled,
          onChanged: (value) => setState(
            () => _draftConfig = config.copyWith(smtpEnabled: value),
          ),
        ),
        SizedBox(height: spacing.s),
        AxiTextFormField(
          autocorrect: false,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          maxLines: 1,
          enabled: config.smtpEnabled,
          placeholder: Text(
            context.l10n.authCustomServerEmailPublicTokenPlaceholder,
            style: placeholderStyle,
          ),
          placeholderStyle: placeholderStyle,
          controller: _emailProvisioningPublicTokenController,
        ),
        SizedBox(height: spacing.m),
        Row(
          children: [
            Expanded(
              child: AxiButton.secondary(
                onPressed: _reset,
                child: Text(
                  widget.mode.isSignup
                      ? context.l10n.commonCancel
                      : context.l10n.authCustomServerReset,
                ),
              ),
            ),
            SizedBox(width: spacing.s),
            Expanded(
              child: AxiButton.primary(
                onPressed: _save,
                child: Text(context.l10n.commonSave),
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.s),
      ],
    );
  }
}

class EndpointSuffix extends StatelessWidget {
  const EndpointSuffix({super.key, required this.server});

  final String server;

  @override
  Widget build(BuildContext context) {
    return _EndpointSuffixShine(
      child: AxiButton.ghost(
        size: AxiButtonSize.sm,
        semanticLabel: context.l10n.authCustomServerOpenSettings,
        onPressed: () async => await EndpointConfigSheet.show(context),
        child: Text(
          '@$server',
          style: context.textTheme.small.copyWith(
            color: context.colorScheme.foreground,
          ),
        ),
      ),
    );
  }
}

class SignupEndpointSuffix extends StatelessWidget {
  const SignupEndpointSuffix({
    super.key,
    required this.config,
    required this.onChanged,
  });

  final EndpointConfig? config;
  final ValueChanged<EndpointConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    final resolvedConfig = config;
    final label =
        resolvedConfig == null ||
            resolvedConfig.domain.trim().isEmpty ||
            resolvedConfig.requiresCustomSignupEndpoint
        ? context.l10n.signupChooseServer
        : '@${resolvedConfig.domain}';
    return _EndpointSuffixShine(
      child: AxiButton.ghost(
        size: AxiButtonSize.sm,
        semanticLabel: context.l10n.authCustomServerOpenSettings,
        onPressed: () async {
          final updated = await EndpointConfigSheet.show(
            context,
            mode: EndpointConfigSheetMode.signup,
            initialConfig: resolvedConfig ?? const EndpointConfig(domain: ''),
          );
          if (updated == null || !context.mounted) {
            return;
          }
          onChanged(updated);
        },
        child: Text(
          label,
          style: context.textTheme.small.copyWith(
            color: context.colorScheme.foreground,
          ),
        ),
      ),
    );
  }
}

class _EndpointSuffixShine extends StatefulWidget {
  const _EndpointSuffixShine({required this.child});

  final Widget child;

  @override
  State<_EndpointSuffixShine> createState() => _EndpointSuffixShineState();
}

class _EndpointSuffixShineState extends State<_EndpointSuffixShine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  Duration _shineDuration = Duration.zero;
  Duration _cycleDuration = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animationDuration = context.watch<SettingsCubit>().animationDuration;
    if (animationDuration == Duration.zero) {
      _controller.stop();
      _controller.value = 0;
      _shineDuration = Duration.zero;
      _cycleDuration = Duration.zero;
      return;
    }
    final motion = context.motion;
    _shineDuration = motion.endpointBorderShineDuration;
    _cycleDuration =
        motion.endpointBorderShineDuration +
        motion.endpointBorderShinePauseDuration;
    _controller.duration = _cycleDuration;
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderSide = context.borderSide;
    final motion = context.motion;
    final alpha = (motion.tapFocusAlpha + motion.tapSplashAlpha).clamp(
      0.0,
      1.0,
    );
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final activeFraction = _cycleDuration == Duration.zero
            ? 0.0
            : _shineDuration.inMicroseconds / _cycleDuration.inMicroseconds;
        final phase =
            activeFraction == 0.0 || _controller.value > activeFraction
            ? null
            : _controller.value / activeFraction;
        final progress = phase == null
            ? null
            : Curves.easeInOutCubic.transform(phase);
        final opacity = phase == null ? 0.0 : _endpointShineOpacity(phase);
        final colors = _endpointRainbowColors(
          brightness: context.brightness,
          alpha: alpha * opacity,
        );
        return Stack(
          fit: StackFit.passthrough,
          children: [
            child ?? const SizedBox.shrink(),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _EndpointSuffixShinePainter(
                    progress: progress,
                    borderRadius: context.radius,
                    borderSide: borderSide,
                    colors: colors,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

double _endpointShineOpacity(double progress) {
  const fadeInEnd = 0.18;
  const fadeOutStart = 0.72;
  if (progress < fadeInEnd) {
    return Curves.easeInCubic.transform(progress / fadeInEnd);
  }
  if (progress > fadeOutStart) {
    final fadeProgress = ((progress - fadeOutStart) / (1 - fadeOutStart)).clamp(
      0.0,
      1.0,
    );
    return 1 - Curves.easeOutCubic.transform(fadeProgress);
  }
  return 1;
}

List<Color> _endpointRainbowColors({
  required Brightness brightness,
  required double alpha,
}) {
  final value = brightness == Brightness.dark ? 1.0 : 0.86;
  return [
    Colors.transparent,
    Colors.transparent,
    HSVColor.fromAHSV(alpha, 0, 0.86, value).toColor(),
    HSVColor.fromAHSV(alpha, 55, 0.86, value).toColor(),
    HSVColor.fromAHSV(alpha, 130, 0.86, value).toColor(),
    HSVColor.fromAHSV(alpha, 205, 0.86, value).toColor(),
    HSVColor.fromAHSV(alpha, 275, 0.86, value).toColor(),
    Colors.transparent,
  ];
}

class _EndpointSuffixShinePainter extends CustomPainter {
  const _EndpointSuffixShinePainter({
    required this.progress,
    required this.borderRadius,
    required this.borderSide,
    required this.colors,
  });

  final double? progress;
  final BorderRadius borderRadius;
  final BorderSide borderSide;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final shineProgress = progress;
    if (shineProgress == null || size.isEmpty) {
      return;
    }

    final rect = Offset.zero & size;
    final shape = RoundedSuperellipseBorder(borderRadius: borderRadius);
    final path = shape.getOuterPath(rect.deflate(borderSide.width / 2));
    final shader = SweepGradient(
      transform: GradientRotation(shineProgress * math.pi * 2),
      colors: colors,
      stops: const [0.0, 0.76, 0.8, 0.84, 0.88, 0.92, 0.96, 1.0],
    ).createShader(rect);

    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderSide.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _EndpointSuffixShinePainter oldDelegate) {
    return progress != oldDelegate.progress ||
        borderRadius != oldDelegate.borderRadius ||
        borderSide != oldDelegate.borderSide ||
        colors != oldDelegate.colors;
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AxiCheckboxFormField(
      key: ValueKey('$label-$value'),
      initialValue: value,
      inputLabel: Text(label),
      onChanged: onChanged,
    );
  }
}
