part of 'authentication_cubit.dart';

sealed class AuthenticationState extends Equatable {
  const AuthenticationState({this.server = 'axi.im'});

  final String server;
}

final class AuthenticationNone extends AuthenticationState {
  const AuthenticationNone();

  @override
  List<Object?> get props => [];
}

final class AuthenticationInProgress extends AuthenticationState {
  const AuthenticationInProgress();

  @override
  List<Object?> get props => [];
}

final class AuthenticationComplete extends AuthenticationState {
  const AuthenticationComplete();

  @override
  List<Object?> get props => [];
}

final class AuthenticationFailure extends AuthenticationState {
  const AuthenticationFailure(this.errorText);

  final String errorText;

  @override
  List<String> get props => [errorText];
}

final class AuthenticationSignupFailure extends AuthenticationState {
  const AuthenticationSignupFailure(this.errorText);

  final String errorText;

  @override
  List<String> get props => [errorText];
}
