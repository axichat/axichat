// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'notification_request_cubit.dart';

class NotificationRequestState {
  const NotificationRequestState({
    this.hasPermissions,
    this.isCheckingPermissions = false,
    this.isRequestingPermissions = false,
    this.isEnablingForeground = false,
    this.isDisablingForeground = false,
    required this.foregroundServiceActive,
  });

  final bool? hasPermissions;
  final bool isCheckingPermissions;
  final bool isRequestingPermissions;
  final bool isEnablingForeground;
  final bool isDisablingForeground;
  final bool foregroundServiceActive;

  bool get isBusy =>
      isCheckingPermissions ||
      isRequestingPermissions ||
      isEnablingForeground ||
      isDisablingForeground;

  NotificationRequestState copyWith({
    bool? hasPermissions,
    bool? isCheckingPermissions,
    bool? isRequestingPermissions,
    bool? isEnablingForeground,
    bool? isDisablingForeground,
    bool? foregroundServiceActive,
  }) {
    return NotificationRequestState(
      hasPermissions: hasPermissions ?? this.hasPermissions,
      isCheckingPermissions:
          isCheckingPermissions ?? this.isCheckingPermissions,
      isRequestingPermissions:
          isRequestingPermissions ?? this.isRequestingPermissions,
      isEnablingForeground: isEnablingForeground ?? this.isEnablingForeground,
      isDisablingForeground:
          isDisablingForeground ?? this.isDisablingForeground,
      foregroundServiceActive:
          foregroundServiceActive ?? this.foregroundServiceActive,
    );
  }
}
