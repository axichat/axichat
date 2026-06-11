// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/password_safety.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AuthPasswordStrengthMeter extends StatelessWidget {
  const AuthPasswordStrengthMeter({
    super.key,
    required this.assessment,
    required this.animationDuration,
    this.showBreachWarning = false,
    this.showSafetyUnavailableWarning = false,
  });

  final AuthPasswordAssessment assessment;
  final Duration animationDuration;
  final bool showBreachWarning;
  final bool showSafetyUnavailableWarning;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final motion = context.motion;
    final spacing = context.spacing;
    final sizing = context.sizing;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: assessment.strengthFraction),
      duration: animationDuration,
      curve: Curves.easeInOut,
      builder: (context, animatedFraction, child) {
        final fillColor = _colorForLevel(assessment.strengthLevel, colors);
        final barHeight = sizing.progressIndicatorBarHeight;
        final barRadius = context.radius;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.authPasswordStrength,
                  style: context.textTheme.muted,
                ),
                Text(
                  assessment.strengthLevel.resolve(context.l10n),
                  style: context.textTheme.muted.copyWith(color: fillColor),
                ),
              ],
            ),
            SizedBox(height: spacing.s),
            Stack(
              children: [
                Container(
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: colors.muted.withValues(alpha: motion.tapHoverAlpha),
                    borderRadius: barRadius,
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: animatedFraction,
                  child: Container(
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: barRadius,
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: animationDuration,
              child: _AuthPasswordSafetyMessage(
                showBreachWarning: showBreachWarning,
                showSafetyUnavailableWarning: showSafetyUnavailableWarning,
              ),
            ),
          ],
        );
      },
    );
  }

  Color _colorForLevel(
    AuthPasswordStrengthLevel level,
    ShadColorScheme colors,
  ) {
    return switch (level) {
      AuthPasswordStrengthLevel.empty ||
      AuthPasswordStrengthLevel.weak => colors.destructive,
      AuthPasswordStrengthLevel.medium => axiWarning,
      AuthPasswordStrengthLevel.stronger => axiGreen,
    };
  }
}

class AuthPasswordRiskNotice extends StatelessWidget {
  const AuthPasswordRiskNotice({
    super.key,
    required this.risk,
    required this.allowed,
    required this.enabled,
    required this.showError,
    required this.animationDuration,
    required this.resetTick,
    required this.onChanged,
  });

  final AuthPasswordRisk? risk;
  final bool allowed;
  final bool enabled;
  final bool showError;
  final Duration animationDuration;
  final int resetTick;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final destructiveTextStyle = context.textTheme.small.copyWith(
      color: context.colorScheme.destructive,
    );
    return AnimatedSwitcher(
      duration: animationDuration,
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      child: risk == null
          ? const SizedBox.shrink()
          : Column(
              key: ValueKey(risk),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AxiCheckboxFormField(
                  key: ValueKey('${risk!.name}-$resetTick'),
                  enabled: enabled,
                  initialValue: allowed,
                  inputLabel: Text(
                    context.l10n.authPasswordRiskAcknowledgement,
                  ),
                  inputSublabel: Text(risk!.resolve(context.l10n)),
                  onChanged: onChanged,
                ),
                AnimatedOpacity(
                  opacity: showError && !allowed ? 1 : 0,
                  duration: animationDuration,
                  child: Padding(
                    padding: EdgeInsets.only(left: spacing.xs, top: spacing.xs),
                    child: Text(
                      context.l10n.authPasswordRiskError,
                      style: destructiveTextStyle,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AuthPasswordSafetyMessage extends StatelessWidget {
  const _AuthPasswordSafetyMessage({
    required this.showBreachWarning,
    required this.showSafetyUnavailableWarning,
  });

  final bool showBreachWarning;
  final bool showSafetyUnavailableWarning;

  @override
  Widget build(BuildContext context) {
    if (!showBreachWarning && !showSafetyUnavailableWarning) {
      return const SizedBox.shrink();
    }
    final spacing = context.spacing;
    return Padding(
      key: ValueKey('$showBreachWarning-$showSafetyUnavailableWarning'),
      padding: EdgeInsets.only(top: spacing.s),
      child: Text(
        showBreachWarning
            ? context.l10n.authPasswordBreached
            : context.l10n.authPasswordSafetyUnavailable,
        style: context.textTheme.muted.copyWith(
          color: context.colorScheme.destructive,
        ),
      ),
    );
  }
}
