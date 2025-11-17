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

abstract final class AuthenticationInProgress extends AuthenticationState {
  const AuthenticationInProgress();

  @override
  List<Object?> get props => [];
}

final class AuthenticationLogInInProgress extends AuthenticationInProgress {
  const AuthenticationLogInInProgress();
}

final class AuthenticationSignUpInProgress extends AuthenticationInProgress {
  const AuthenticationSignUpInProgress();
}

final class AuthenticationComplete extends AuthenticationState {
  const AuthenticationComplete();

  @override
  List<Object?> get props => [];
}

final class AuthenticationPasswordChangeSuccess extends AuthenticationComplete {
  const AuthenticationPasswordChangeSuccess(this.successText);

  final String successText;

  @override
  List<Object?> get props => [successText];
}

final class AuthenticationPasswordChangeInProgress
    extends AuthenticationComplete {
  const AuthenticationPasswordChangeInProgress();

  @override
  List<Object?> get props => [];
}

final class AuthenticationPasswordChangeFailure extends AuthenticationComplete {
  const AuthenticationPasswordChangeFailure(this.errorText);

  final String errorText;

  @override
  List<Object?> get props => [errorText];
}

final class AuthenticationUnregisterInProgress extends AuthenticationComplete {
  const AuthenticationUnregisterInProgress();

  @override
  List<Object?> get props => [];
}

final class AuthenticationUnregisterFailure extends AuthenticationComplete {
  const AuthenticationUnregisterFailure(this.errorText);

  final String errorText;

  @override
  List<Object?> get props => [errorText];
}

final class AuthenticationFailure extends AuthenticationState {
  const AuthenticationFailure(this.errorText);

  final String errorText;

  @override
  List<String> get props => [errorText];
}

final class AuthenticationSignupFailure extends AuthenticationState {
  const AuthenticationSignupFailure(
    this.errorText, {
    this.isCleanupBlocked = false,
  });

  final String errorText;
  final bool isCleanupBlocked;

  @override
  List<Object?> get props => [errorText, isCleanupBlocked];
}
