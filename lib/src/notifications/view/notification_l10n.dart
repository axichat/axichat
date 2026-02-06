// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/notifications/notification_strings.dart';

extension NotificationStringsFromL10n on AppLocalizations {
  NotificationStrings toNotificationStrings() {
    return NotificationStrings(
      channelMessages: notificationChannelMessages,
      newMessageTitle: notificationNewMessageTitle,
      openAction: notificationOpenAction,
      appTitle: appTitle,
      backgroundConnectionDisabledTitle:
          notificationBackgroundConnectionDisabledTitle,
      backgroundConnectionDisabledBody:
          notificationBackgroundConnectionDisabledBody,
    );
  }
}
