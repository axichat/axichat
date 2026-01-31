// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'connectivity_cubit.dart';

sealed class ConnectivityState {
  const ConnectivityState({
    required this.emailState,
    required this.emailEnabled,
  });

  final EmailSyncState emailState;
  final bool emailEnabled;
}

final class ConnectivityConnected extends ConnectivityState {
  const ConnectivityConnected({
    required super.emailState,
    required super.emailEnabled,
  });
}

final class ConnectivityConnecting extends ConnectivityState {
  const ConnectivityConnecting({
    required super.emailState,
    required super.emailEnabled,
  });
}

final class ConnectivityNotConnected extends ConnectivityState {
  const ConnectivityNotConnected({
    required super.emailState,
    required super.emailEnabled,
  });
}

final class ConnectivityError extends ConnectivityState {
  const ConnectivityError({
    required super.emailState,
    required super.emailEnabled,
  });
}
