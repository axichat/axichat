// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

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
  const AuthenticationLogInInProgress({this.fromSignup = false, super.config});

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
  const AuthenticationPasswordChangeSuccess(this.message, {super.config});

  final AuthMessage message;

  @override
  AuthenticationPasswordChangeSuccess copyWithConfig(EndpointConfig config) =>
      AuthenticationPasswordChangeSuccess(message, config: config);

  @override
  List<Object?> get props => [config, message];
}

final class AuthenticationPasswordChangeInProgress
    extends AuthenticationComplete {
  const AuthenticationPasswordChangeInProgress({super.config});

  @override
  AuthenticationPasswordChangeInProgress copyWithConfig(
    EndpointConfig config,
  ) => AuthenticationPasswordChangeInProgress(config: config);

  @override
  List<Object?> get props => [config];
}

final class AuthenticationPasswordChangeFailure extends AuthenticationComplete {
  const AuthenticationPasswordChangeFailure(this.message, {super.config});

  final AuthMessage message;

  @override
  AuthenticationPasswordChangeFailure copyWithConfig(EndpointConfig config) =>
      AuthenticationPasswordChangeFailure(message, config: config);

  @override
  List<Object?> get props => [config, message];
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
  const AuthenticationUnregisterFailure(this.message, {super.config});

  final AuthMessage message;

  @override
  AuthenticationUnregisterFailure copyWithConfig(EndpointConfig config) =>
      AuthenticationUnregisterFailure(message, config: config);

  @override
  List<Object?> get props => [config, message];
}

final class AuthenticationFailure extends AuthenticationState {
  const AuthenticationFailure(this.message, {super.config});

  final AuthMessage message;

  @override
  AuthenticationFailure copyWithConfig(EndpointConfig config) =>
      AuthenticationFailure(message, config: config);

  @override
  List<Object?> get props => [config, message];
}

final class AuthenticationSignupFailure extends AuthenticationState {
  const AuthenticationSignupFailure(
    this.message, {
    this.isCleanupBlocked = false,
    super.config,
  });

  final AuthMessage message;
  final bool isCleanupBlocked;

  @override
  AuthenticationSignupFailure copyWithConfig(EndpointConfig config) =>
      AuthenticationSignupFailure(
        message,
        isCleanupBlocked: isCleanupBlocked,
        config: config,
      );

  @override
  List<Object?> get props => [config, message, isCleanupBlocked];
}
