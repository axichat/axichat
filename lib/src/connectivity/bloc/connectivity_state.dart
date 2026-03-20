// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'connectivity_cubit.dart';

sealed class ConnectivityState {
  const ConnectivityState({
    required this.emailState,
    required this.emailEnabled,
    required this.demoOffline,
  });

  final EmailSyncState emailState;
  final bool emailEnabled;
  final bool demoOffline;
}

final class ConnectivityConnected extends ConnectivityState {
  const ConnectivityConnected({
    required super.emailState,
    required super.emailEnabled,
    required super.demoOffline,
  });
}

final class ConnectivityConnecting extends ConnectivityState {
  const ConnectivityConnecting({
    required super.emailState,
    required super.emailEnabled,
    required super.demoOffline,
  });
}

final class ConnectivityNotConnected extends ConnectivityState {
  const ConnectivityNotConnected({
    required super.emailState,
    required super.emailEnabled,
    required super.demoOffline,
  });
}

final class ConnectivityError extends ConnectivityState {
  const ConnectivityError({
    required super.emailState,
    required super.emailEnabled,
    required super.demoOffline,
  });
}
