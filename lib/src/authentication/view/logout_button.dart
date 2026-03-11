// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

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
    return AxiIconButton(
      iconData: LucideIcons.logOut,
      onPressed: () async {
        final shouldLogout = await confirm(
          context,
          title: title(context.l10n),
          message: context.l10n.authLogoutNormalDescription,
          confirmLabel: context.l10n.authLogoutTitle,
          destructiveConfirm: false,
        );
        if (shouldLogout != true || !context.mounted) {
          return;
        }
        await context.read<AuthenticationCubit>().logout(
          severity: LogoutSeverity.normal,
        );
      },
    );
  }
}
