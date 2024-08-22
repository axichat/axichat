part of 'authentication_cubit.dart';

sealed class AuthenticationState {
  const AuthenticationState();
}

final class AuthenticationNone extends AuthenticationState {}

final class AuthenticationInProgress extends AuthenticationState {}

final class AuthenticationComplete extends AuthenticationState {}

final class AuthenticationFailure extends AuthenticationState {
  const AuthenticationFailure(this.errorText);

  final String errorText;
}

final class AuthenticationSignupFailure extends AuthenticationState {
  const AuthenticationSignupFailure(this.errorText);

  final String errorText;
}
