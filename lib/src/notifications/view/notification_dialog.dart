// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/notifications/bloc/notification_request_cubit.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<bool?> showNotificationDialog(
  BuildContext context,
  T Function<T>() locate,
) =>
    showFadeScaleDialog<bool>(
      context: context,
      builder: (context) =>
          BlocBuilder<NotificationRequestCubit, NotificationRequestState>(
        bloc: locate<NotificationRequestCubit>(),
        builder: (context, state) {
          return ShadDialog(
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
                        final granted = await locate<NotificationRequestCubit>()
                            .requestPermissions();
                        if (granted && context.mounted) {
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
