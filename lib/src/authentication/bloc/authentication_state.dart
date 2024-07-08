part of 'authentication_bloc.dart';

sealed class AuthenticationState extends Equatable {
  const AuthenticationState();
}

final class AuthenticationNone extends AuthenticationState {
  @override
  List<Object> get props => [];
}

final class AuthenticationInProgress extends AuthenticationState {
  @override
  List<Object> get props => [];
}

final class AuthenticationComplete extends AuthenticationState {
  @override
  List<Object> get props => [];
}

final class AuthenticationFailure extends AuthenticationState {
  const AuthenticationFailure(this.errorText);

  final String errorText;

  @override
  List<Object> get props => [errorText];
}
