// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

class NotificationStrings {
  const NotificationStrings({
    required this.channelMessages,
    required this.newMessageTitle,
    required this.openAction,
    required this.appTitle,
    required this.backgroundConnectionDisabledTitle,
    required this.backgroundConnectionDisabledBody,
  });

  const NotificationStrings.empty()
      : channelMessages = '',
        newMessageTitle = '',
        openAction = '',
        appTitle = '',
        backgroundConnectionDisabledTitle = '',
        backgroundConnectionDisabledBody = '';

  final String channelMessages;
  final String newMessageTitle;
  final String openAction;
  final String appTitle;
  final String backgroundConnectionDisabledTitle;
  final String backgroundConnectionDisabledBody;
}
