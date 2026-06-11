import 'package:axichat/src/authentication/password_safety.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('assessAuthPassword', () {
    test('classifies empty passwords separately from weak passwords', () {
      final assessment = assessAuthPassword('');

      expect(assessment.strengthLevel, AuthPasswordStrengthLevel.empty);
      expect(assessment.requiresAcknowledgement, isFalse);
    });

    test('classifies low-entropy passwords as weak', () {
      final assessment = assessAuthPassword('abc');

      expect(assessment.strengthLevel, AuthPasswordStrengthLevel.weak);
      expect(assessment.requiresAcknowledgement, isTrue);
    });

    test('classifies high-entropy passwords as stronger', () {
      final assessment = assessAuthPassword('CorrectHorseBatteryStaple2026!');

      expect(assessment.strengthLevel, AuthPasswordStrengthLevel.stronger);
      expect(assessment.requiresAcknowledgement, isFalse);
    });
  });

  group('authPasswordRiskForHostedPolicy', () {
    test('prefers breached risk over weak risk', () {
      final risk = authPasswordRiskForHostedPolicy(
        assessment: assessAuthPassword('abc'),
        breachCheckResult: PasswordBreachCheckResult.breached,
      );

      expect(risk, AuthPasswordRisk.breached);
    });

    test('treats unavailable breach checks as acknowledgement risk', () {
      final risk = authPasswordRiskForHostedPolicy(
        assessment: assessAuthPassword('CorrectHorseBatteryStaple2026!'),
        breachCheckResult: PasswordBreachCheckResult.unavailable,
      );

      expect(risk, AuthPasswordRisk.unavailable);
    });

    test('returns no risk for strong safe passwords', () {
      final risk = authPasswordRiskForHostedPolicy(
        assessment: assessAuthPassword('CorrectHorseBatteryStaple2026!'),
        breachCheckResult: PasswordBreachCheckResult.safe,
      );

      expect(risk, isNull);
    });
  });
}
