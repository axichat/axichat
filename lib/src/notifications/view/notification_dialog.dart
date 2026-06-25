// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/notifications/bloc/notification_request_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

Future<bool?> showNotificationDialog(
  BuildContext context,
  T Function<T>() locate,
) {
  final notificationCubit = locate<NotificationRequestCubit>();
  return showFadeScaleDialog<bool>(
    context: context,
    builder: (context) =>
        BlocBuilder<NotificationRequestCubit, NotificationRequestState>(
          bloc: notificationCubit,
          builder: (context, state) {
            return AxiDialog(
              constraints: BoxConstraints(
                maxWidth: context.sizing.dialogMaxWidth,
              ),
              title: Text(
                context.l10n.notificationsDialogTitle,
                style: context.modalHeaderTextStyle,
              ),
              actions: [
                AxiButton.destructive(
                  onPressed: state.isRequestingPermissions
                      ? null
                      : () => context.pop(false),
                  child: Text(context.l10n.notificationsDialogIgnore),
                ),
                AxiButton.primary(
                  onPressed: state.isRequestingPermissions
                      ? null
                      : () async {
                          final permissionResult = await notificationCubit
                              .requestPermissions();
                          if (permissionResult.isGranted && context.mounted) {
                            context.pop(true);
                          }
                        },
                  child: Text(context.l10n.notificationsDialogContinue),
                ),
              ],
              child: Text(context.l10n.notificationsDialogDescription),
            );
          },
        ),
  );
}

Future<void>? _notificationRestartDialogFuture;

Future<void> showNotificationRestartDialog(BuildContext context) {
  final activeDialog = _notificationRestartDialogFuture;
  if (activeDialog != null) {
    return activeDialog;
  }

  late final Future<void> dialogFuture;
  dialogFuture =
      showFadeScaleDialog<void>(
        context: context,
        builder: (context) => AxiDialog(
          constraints: BoxConstraints(maxWidth: context.sizing.dialogMaxWidth),
          title: Text(
            context.l10n.notificationsRestartTitle,
            style: context.modalHeaderTextStyle,
          ),
          actions: [
            AxiButton.primary(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.commonDone),
            ),
          ],
          child: Text(context.l10n.notificationsRestartSubtitle),
        ),
      ).whenComplete(() {
        if (identical(_notificationRestartDialogFuture, dialogFuture)) {
          _notificationRestartDialogFuture = null;
        }
      });
  _notificationRestartDialogFuture = dialogFuture;
  return dialogFuture;
}
