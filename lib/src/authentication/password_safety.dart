// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/localization/app_localizations.dart';

enum AuthPasswordStrengthLevel {
  empty,
  weak,
  medium,
  stronger;

  bool get requiresAcknowledgement => this == weak;

  String resolve(AppLocalizations l10n) {
    return switch (this) {
      AuthPasswordStrengthLevel.empty => l10n.authPasswordStrengthNone,
      AuthPasswordStrengthLevel.weak => l10n.authPasswordStrengthWeak,
      AuthPasswordStrengthLevel.medium => l10n.authPasswordStrengthMedium,
      AuthPasswordStrengthLevel.stronger => l10n.authPasswordStrengthStronger,
    };
  }
}

enum PasswordBreachCheckResult { safe, breached, unavailable }

enum AuthPasswordRisk {
  weak,
  breached,
  unavailable;

  String resolve(AppLocalizations l10n) {
    return switch (this) {
      AuthPasswordRisk.weak => l10n.authPasswordRiskAllowWeak,
      AuthPasswordRisk.breached => l10n.authPasswordRiskAllowBreach,
      AuthPasswordRisk.unavailable => l10n.authPasswordRiskAllowUnavailable,
    };
  }
}

final class AuthPasswordAssessment {
  const AuthPasswordAssessment({
    required this.entropyBits,
    required this.strengthLevel,
  });

  final double entropyBits;
  final AuthPasswordStrengthLevel strengthLevel;

  double get strengthFraction {
    const maxEntropyBits = 120.0;
    return (entropyBits.clamp(0.0, maxEntropyBits) / maxEntropyBits).clamp(
      0.0,
      1.0,
    );
  }

  bool get requiresAcknowledgement => strengthLevel.requiresAcknowledgement;
}

AuthPasswordAssessment assessAuthPassword(String password) {
  if (password.isEmpty) {
    return const AuthPasswordAssessment(
      entropyBits: 0,
      strengthLevel: AuthPasswordStrengthLevel.empty,
    );
  }
  final entropyBits =
      password.length * (_log2(_estimateCharacterPool(password)));
  const weakEntropyThreshold = 50;
  const strongEntropyThreshold = 80;
  if (entropyBits < weakEntropyThreshold) {
    return AuthPasswordAssessment(
      entropyBits: entropyBits,
      strengthLevel: AuthPasswordStrengthLevel.weak,
    );
  }
  if (entropyBits < strongEntropyThreshold) {
    return AuthPasswordAssessment(
      entropyBits: entropyBits,
      strengthLevel: AuthPasswordStrengthLevel.medium,
    );
  }
  return AuthPasswordAssessment(
    entropyBits: entropyBits,
    strengthLevel: AuthPasswordStrengthLevel.stronger,
  );
}

AuthPasswordRisk? authPasswordRiskForHostedPolicy({
  required AuthPasswordAssessment assessment,
  required PasswordBreachCheckResult? breachCheckResult,
}) {
  if (breachCheckResult == PasswordBreachCheckResult.breached) {
    return AuthPasswordRisk.breached;
  }
  if (breachCheckResult == PasswordBreachCheckResult.unavailable) {
    return AuthPasswordRisk.unavailable;
  }
  if (assessment.requiresAcknowledgement) {
    return AuthPasswordRisk.weak;
  }
  return null;
}

int _estimateCharacterPool(String password) {
  var pool = 0;
  if (RegExp(r'[0-9]').hasMatch(password)) {
    pool += 10;
  }
  if (RegExp(r'[a-z]').hasMatch(password)) {
    pool += 26;
  }
  if (RegExp(r'[A-Z]').hasMatch(password)) {
    pool += 26;
  }
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
    pool += 33;
  }
  return pool == 0 ? 1 : pool;
}

double _log2(num value) => math.log(value) / math.ln2;
