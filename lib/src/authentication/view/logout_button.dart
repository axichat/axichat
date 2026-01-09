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
    final l10n = context.l10n;
    return AxiIconButton(
      iconData: LucideIcons.logOut,
      onPressed: () => showFadeScaleDialog(
        context: context,
        builder: (context) {
          var severity = LogoutSeverity.normal;
          return BlocProvider.value(
            value: locate<AuthenticationCubit>(),
            child: StatefulBuilder(
              builder: (context, setState) {
                void updateSeverity(LogoutSeverity value) {
                  setState(() {
                    severity = value;
                  });
                }

                return AxiInputDialog(
                  title: Text(title(l10n)),
                  content: Material(
                    child: ListTileTheme.merge(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      selectedColor: context.colorScheme.accentForeground,
                      selectedTileColor: context.colorScheme.accent,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CheckboxListTile(
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(l10n.authLogoutNormal),
                            subtitle: Text(l10n.authLogoutNormalDescription),
                            value: severity.isNormal,
                            selected: severity.isNormal,
                            onChanged: (_) =>
                                updateSeverity(LogoutSeverity.normal),
                          ),
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(l10n.authLogoutBurn),
                            subtitle: Text(l10n.authLogoutBurnDescription),
                            isThreeLine: true,
                            value: severity.isBurn,
                            selected: severity.isBurn,
                            onChanged: (_) =>
                                updateSeverity(LogoutSeverity.burn),
                          ),
                        ],
                      ),
                    ),
                  ),
                  callback: () => context
                      .read<AuthenticationCubit>()
                      .logout(severity: severity),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
