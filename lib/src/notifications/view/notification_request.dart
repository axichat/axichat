// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/foreground_runtime_controller.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:axichat/src/notifications/bloc/notification_request_cubit.dart';
import 'package:axichat/src/notifications/view/notification_dialog.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum NotificationRequestDisplayMode {
  platformOnly,
  always;

  bool shouldShowFor(Capability capability) {
    switch (this) {
      case NotificationRequestDisplayMode.platformOnly:
        return capability.canForegroundService;
      case NotificationRequestDisplayMode.always:
        return true;
    }
  }
}

class NotificationRequest extends StatelessWidget {
  const NotificationRequest({
    super.key,
    this.displayMode = NotificationRequestDisplayMode.platformOnly,
    this.allowCurrentSessionMigration = false,
    this.onForegroundActivationStarted,
    this.onForegroundActivationFinished,
    this.onForegroundActivated,
  });

  final NotificationRequestDisplayMode displayMode;
  final bool allowCurrentSessionMigration;
  final void Function()? onForegroundActivationStarted;
  final void Function()? onForegroundActivationFinished;
  final Future<void> Function()? onForegroundActivated;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NotificationRequestCubit(
        foregroundRuntimeController: context
            .read<ForegroundRuntimeController>(),
        notificationService: context.read<NotificationService>(),
      )..refreshPermissions(),
      child: _NotificationRequestBody(
        capability: context.watch<Capability>(),
        displayMode: displayMode,
        allowCurrentSessionMigration: allowCurrentSessionMigration,
        onForegroundActivationStarted: onForegroundActivationStarted,
        onForegroundActivationFinished: onForegroundActivationFinished,
        onForegroundActivated: onForegroundActivated,
      ),
    );
  }
}

class _NotificationRequestBody extends StatefulWidget {
  const _NotificationRequestBody({
    required this.capability,
    required this.displayMode,
    required this.allowCurrentSessionMigration,
    required this.onForegroundActivationStarted,
    required this.onForegroundActivationFinished,
    required this.onForegroundActivated,
  });

  final Capability capability;
  final NotificationRequestDisplayMode displayMode;
  final bool allowCurrentSessionMigration;
  final void Function()? onForegroundActivationStarted;
  final void Function()? onForegroundActivationFinished;
  final Future<void> Function()? onForegroundActivated;

  @override
  State<_NotificationRequestBody> createState() =>
      _NotificationRequestBodyState();
}

class _NotificationRequestBodyState extends State<_NotificationRequestBody> {
  bool _backgroundMessagingToggleInFlight = false;
  bool? _pendingBackgroundMessagingEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final backgroundMessagingEnabled = context.select<SettingsCubit, bool>(
      (cubit) => cubit.state.backgroundMessagingEnabled,
    );
    return BlocBuilder<NotificationRequestCubit, NotificationRequestState>(
      builder: (context, state) {
        if (state.hasPermissions == null ||
            !widget.displayMode.shouldShowFor(widget.capability)) {
          return const SizedBox.shrink();
        }
        final switchValue =
            _pendingBackgroundMessagingEnabled ?? backgroundMessagingEnabled;
        final switchBusy = state.isBusy || _backgroundMessagingToggleInFlight;
        final String? sublabel = switch ((
          switchValue,
          state.foregroundServiceActive,
          state.hasPermissions,
        )) {
          (true, true, true) => null,
          (_, _, _) => l10n.notificationsRequiresRestart,
        };

        return ShadSwitch(
          label: Text(l10n.notificationsMessageToggle),
          sublabel: sublabel == null ? null : Text(sublabel),
          value: switchValue,
          onChanged: switchBusy
              ? null
              : (enabled) =>
                    _handleBackgroundMessagingChanged(context, enabled),
        );
      },
    );
  }

  Future<void> _handleBackgroundMessagingChanged(
    BuildContext context,
    bool enabled,
  ) async {
    final locate = context.read;
    final notificationCubit = locate<NotificationRequestCubit>();
    final settingsCubit = locate<SettingsCubit>();
    final xmppService = locate<XmppService>();
    final hasPermissions = notificationCubit.state.hasPermissions == true;
    var foregroundActivationStarted = false;
    setState(() {
      _backgroundMessagingToggleInFlight = true;
      if (!enabled) {
        _pendingBackgroundMessagingEnabled = false;
      } else if (hasPermissions) {
        _pendingBackgroundMessagingEnabled = true;
      }
    });
    try {
      if (!enabled) {
        final foregroundDisabled = await notificationCubit
            .disableForegroundService();
        if (!context.mounted || !foregroundDisabled) {
          return;
        }
        await settingsCubit.toggleBackgroundMessaging(
          false,
          accountJid: xmppService.myJid,
        );
        return;
      }
      if (!hasPermissions) {
        final confirmed = await showNotificationDialog(context, locate);
        if (!context.mounted || confirmed != true) {
          return;
        }
        if (!widget.displayMode.shouldShowFor(widget.capability)) {
          return;
        }
        if (!widget.capability.canForegroundService) {
          return;
        }
        setState(() {
          _pendingBackgroundMessagingEnabled = true;
        });
      }
      if (widget.allowCurrentSessionMigration) {
        widget.onForegroundActivationStarted?.call();
        foregroundActivationStarted = true;
      }
      final foregroundResult = await notificationCubit.enableForegroundService(
        emailKeepaliveEnabled: settingsCubit.state.endpointConfig.smtpEnabled,
        allowCurrentSessionMigration: widget.allowCurrentSessionMigration,
      );
      if (!context.mounted || !foregroundResult.shouldPersistPreference) {
        return;
      }
      await settingsCubit.toggleBackgroundMessaging(
        true,
        accountJid: xmppService.myJid,
      );
      if (!context.mounted) {
        return;
      }
      switch (foregroundResult) {
        case ForegroundActivationResult.active:
          await widget.onForegroundActivated?.call();
        case ForegroundActivationResult.deferredUntilRestart:
          await showNotificationRestartDialog(context);
        case ForegroundActivationResult.unavailable:
        case ForegroundActivationResult.failed:
          break;
      }
    } finally {
      if (foregroundActivationStarted) {
        widget.onForegroundActivationFinished?.call();
      }
      if (mounted) {
        setState(() {
          _backgroundMessagingToggleInFlight = false;
          _pendingBackgroundMessagingEnabled = null;
        });
      }
    }
  }
}
