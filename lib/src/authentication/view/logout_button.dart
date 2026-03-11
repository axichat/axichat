// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  static String title(AppLocalizations l10n) => l10n.authLogoutTitle;

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    return AxiIconButton(
      iconData: LucideIcons.logOut,
      onPressed: () {
        showFadeScaleDialog<void>(
          context: context,
          builder: (dialogContext) => _LogoutDialog(
            onLogout: () => locate<AuthenticationCubit>().logout(
              severity: LogoutSeverity.normal,
            ),
          ),
        );
      },
    );
  }
}

class _LogoutDialog extends StatefulWidget {
  const _LogoutDialog({required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<_LogoutDialog> createState() => _LogoutDialogState();
}

class _LogoutDialogState extends State<_LogoutDialog> {
  var _loading = false;

  Future<void> _handleLogout() async {
    if (_loading) {
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      await widget.onLogout();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AxiInputDialog(
      title: Text(LogoutButton.title(context.l10n)),
      content: Text(
        context.l10n.authLogoutNormalDescription,
        style: context.textTheme.small,
      ),
      callbackText: context.l10n.authLogoutTitle,
      callback: _handleLogout,
      loading: _loading,
      canPop: !_loading,
      showCloseButton: !_loading,
    );
  }
}
