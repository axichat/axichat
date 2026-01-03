// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'connectivity_cubit.dart';

sealed class ConnectivityState {
  const ConnectivityState();
}

final class ConnectivityConnected extends ConnectivityState {
  const ConnectivityConnected();
}

final class ConnectivityConnecting extends ConnectivityState {
  const ConnectivityConnecting();
}

final class ConnectivityNotConnected extends ConnectivityState {
  const ConnectivityNotConnected();
}

final class ConnectivityError extends ConnectivityState {
  const ConnectivityError();
}
