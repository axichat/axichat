class SignupDraft {
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
}
