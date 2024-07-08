part of 'authentication_bloc.dart';

enum LogoutSeverity {
  normal,
  burn;

  bool get isNormal => this == normal;
  bool get isBurn => this == burn;

  String get asString => switch (this) {
        LogoutSeverity.normal => 'Normal',
        LogoutSeverity.burn => 'Burn',
      };
}

sealed class AuthenticationEvent extends Equatable {
  const AuthenticationEvent();
}

final class AuthenticationLoginRequested extends AuthenticationEvent {
  const AuthenticationLoginRequested({
    required this.username,
    required this.password,
    required this.rememberMe,
  });

  final String username;
  final String password;
  final bool rememberMe;

  @override
  List<Object?> get props => [username, password, rememberMe];
}

final class AuthenticationSignupRequested extends AuthenticationEvent {
  const AuthenticationSignupRequested({
    required this.username,
    required this.password,
    required this.rememberMe,
    required this.agreeToTerms,
  });

  final String username;
  final String password;
  final bool rememberMe;
  final bool agreeToTerms;

  @override
  List<Object?> get props => [username, password, rememberMe, agreeToTerms];
}

final class AuthenticationLogoutRequested extends AuthenticationEvent {
  const AuthenticationLogoutRequested({required this.severity});

  final LogoutSeverity severity;

  @override
  List<Object?> get props => [severity];
}
