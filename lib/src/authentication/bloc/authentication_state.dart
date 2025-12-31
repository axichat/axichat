part of 'authentication_cubit.dart';

sealed class AuthenticationState extends Equatable {
  const AuthenticationState({this.config = const EndpointConfig()});

  final EndpointConfig config;

  String get server => config.domain;

  AuthenticationState copyWithConfig(EndpointConfig config);

  @override
  List<Object?> get props => [config];
}

final class AuthenticationNone extends AuthenticationState {
  const AuthenticationNone({super.config});

  @override
  AuthenticationNone copyWithConfig(EndpointConfig config) =>
      AuthenticationNone(config: config);

  @override
  List<Object?> get props => [config];
}

abstract final class AuthenticationInProgress extends AuthenticationState {
  const AuthenticationInProgress({super.config});

  @override
  AuthenticationInProgress copyWithConfig(EndpointConfig config);
}

final class AuthenticationLogInInProgress extends AuthenticationInProgress {
  const AuthenticationLogInInProgress({
    this.fromSignup = false,
    super.config,
  });

  final bool fromSignup;

  @override
  AuthenticationLogInInProgress copyWithConfig(EndpointConfig config) =>
      AuthenticationLogInInProgress(fromSignup: fromSignup, config: config);

  @override
  List<Object?> get props => [config, fromSignup];
}

final class AuthenticationSignUpInProgress extends AuthenticationInProgress {
  const AuthenticationSignUpInProgress({
    this.fromSubmission = true,
    super.config,
  });

  final bool fromSubmission;

  @override
  AuthenticationSignUpInProgress copyWithConfig(EndpointConfig config) =>
      AuthenticationSignUpInProgress(
        fromSubmission: fromSubmission,
        config: config,
      );

  @override
  List<Object?> get props => [config, fromSubmission];
}

final class AuthenticationComplete extends AuthenticationState {
  const AuthenticationComplete({super.config});

  @override
  AuthenticationComplete copyWithConfig(EndpointConfig config) =>
      AuthenticationComplete(config: config);

  @override
  List<Object?> get props => [config];
}

final class AuthenticationCompleteFromSignup extends AuthenticationComplete {
  const AuthenticationCompleteFromSignup({super.config});

  @override
  AuthenticationCompleteFromSignup copyWithConfig(EndpointConfig config) =>
      AuthenticationCompleteFromSignup(config: config);

  @override
  List<Object?> get props => [config];
}

final class AuthenticationPasswordChangeSuccess extends AuthenticationComplete {
  const AuthenticationPasswordChangeSuccess(
    this.successText, {
    super.config,
  });

  final String successText;

  @override
  AuthenticationPasswordChangeSuccess copyWithConfig(EndpointConfig config) =>
      AuthenticationPasswordChangeSuccess(
        successText,
        config: config,
      );

  @override
  List<Object?> get props => [config, successText];
}

final class AuthenticationPasswordChangeInProgress
    extends AuthenticationComplete {
  const AuthenticationPasswordChangeInProgress({super.config});

  @override
  AuthenticationPasswordChangeInProgress copyWithConfig(
    EndpointConfig config,
  ) =>
      AuthenticationPasswordChangeInProgress(config: config);

  @override
  List<Object?> get props => [config];
}

final class AuthenticationPasswordChangeFailure extends AuthenticationComplete {
  const AuthenticationPasswordChangeFailure(
    this.errorText, {
    super.config,
  });

  final String errorText;

  @override
  AuthenticationPasswordChangeFailure copyWithConfig(EndpointConfig config) =>
      AuthenticationPasswordChangeFailure(
        errorText,
        config: config,
      );

  @override
  List<Object?> get props => [config, errorText];
}

final class AuthenticationUnregisterInProgress extends AuthenticationComplete {
  const AuthenticationUnregisterInProgress({super.config});

  @override
  AuthenticationUnregisterInProgress copyWithConfig(EndpointConfig config) =>
      AuthenticationUnregisterInProgress(config: config);

  @override
  List<Object?> get props => [config];
}

final class AuthenticationUnregisterFailure extends AuthenticationComplete {
  const AuthenticationUnregisterFailure(
    this.errorText, {
    super.config,
  });

  final String errorText;

  @override
  AuthenticationUnregisterFailure copyWithConfig(EndpointConfig config) =>
      AuthenticationUnregisterFailure(
        errorText,
        config: config,
      );

  @override
  List<Object?> get props => [config, errorText];
}

final class AuthenticationFailure extends AuthenticationState {
  const AuthenticationFailure(
    this.errorText, {
    super.config,
  });

  final String errorText;

  @override
  AuthenticationFailure copyWithConfig(EndpointConfig config) =>
      AuthenticationFailure(
        errorText,
        config: config,
      );

  @override
  List<Object?> get props => [config, errorText];
}

final class AuthenticationSignupFailure extends AuthenticationState {
  const AuthenticationSignupFailure(
    this.errorText, {
    this.isCleanupBlocked = false,
    super.config,
  });

  final String errorText;
  final bool isCleanupBlocked;

  @override
  AuthenticationSignupFailure copyWithConfig(EndpointConfig config) =>
      AuthenticationSignupFailure(
        errorText,
        isCleanupBlocked: isCleanupBlocked,
        config: config,
      );

  @override
  List<Object?> get props => [config, errorText, isCleanupBlocked];
}
