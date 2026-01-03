// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

enum RequestStatus { none, loading, success, failure }

extension RequestStatusFlags on RequestStatus {
  bool get isNone => this == RequestStatus.none;

  bool get isLoading => this == RequestStatus.loading;

  bool get isSuccess => this == RequestStatus.success;

  bool get isFailure => this == RequestStatus.failure;
}
