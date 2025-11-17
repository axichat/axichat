import 'package:equatable/equatable.dart';

class SignupDraft extends Equatable {
  const SignupDraft({
    this.username = '',
    this.password = '',
    this.confirmPassword = '',
    this.captcha = '',
    this.rememberMe = true,
    this.allowInsecurePassword = false,
    this.currentStep = 0,
  });

  final String username;
  final String password;
  final String confirmPassword;
  final String captcha;
  final bool rememberMe;
  final bool allowInsecurePassword;
  final int currentStep;

  bool get isEmpty =>
      username.isEmpty &&
      password.isEmpty &&
      confirmPassword.isEmpty &&
      captcha.isEmpty;

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'confirmPassword': confirmPassword,
      'captcha': captcha,
      'rememberMe': rememberMe,
      'allowInsecurePassword': allowInsecurePassword,
      'currentStep': currentStep,
    };
  }

  factory SignupDraft.fromJson(Map<String, dynamic> json) {
    return SignupDraft(
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      confirmPassword: json['confirmPassword'] as String? ?? '',
      captcha: json['captcha'] as String? ?? '',
      rememberMe: json['rememberMe'] as bool? ?? true,
      allowInsecurePassword: json['allowInsecurePassword'] as bool? ?? false,
      currentStep: json['currentStep'] as int? ?? 0,
    );
  }

  SignupDraft copyWith({
    String? username,
    String? password,
    String? confirmPassword,
    String? captcha,
    bool? rememberMe,
    bool? allowInsecurePassword,
    int? currentStep,
  }) {
    return SignupDraft(
      username: username ?? this.username,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      captcha: captcha ?? this.captcha,
      rememberMe: rememberMe ?? this.rememberMe,
      allowInsecurePassword:
          allowInsecurePassword ?? this.allowInsecurePassword,
      currentStep: currentStep ?? this.currentStep,
    );
  }

  @override
  List<Object?> get props => [
        username,
        password,
        confirmPassword,
        captcha,
        rememberMe,
        allowInsecurePassword,
        currentStep,
      ];
}
