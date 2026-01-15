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
    final l10n = context.l10n;
    return AxiIconButton(
      iconData: LucideIcons.logOut,
      onPressed: () => showFadeScaleDialog(
        context: context,
        builder: (context) {
          var severity = LogoutSeverity.normal;
          return BlocProvider.value(
            value: context.read<AuthenticationCubit>(),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CheckboxListTile(
                            title: Text(
                              l10n.authLogoutNormal,
                              style: TextStyle(
                                  color: context.colorScheme.cardForeground),
                            ),
                            subtitle: Text(
                              l10n.authLogoutNormalDescription,
                              style: TextStyle(
                                  color: context.colorScheme.cardForeground),
                            ),
                            value: severity.isNormal,
                            selected: severity.isNormal,
                            tileColor: context.colorScheme.card,
                            onChanged: (_) =>
                                updateSeverity(LogoutSeverity.normal),
                          ),
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            title: Text(
                              l10n.authLogoutBurn,
                              style: TextStyle(
                                  color: context.colorScheme.cardForeground),
                            ),
                            subtitle: Text(
                              l10n.authLogoutBurnDescription,
                              style: TextStyle(
                                  color: context.colorScheme.cardForeground),
                            ),
                            isThreeLine: true,
                            value: severity.isBurn,
                            selected: severity.isBurn,
                            tileColor: context.colorScheme.card,
                            onChanged: (_) =>
                                updateSeverity(LogoutSeverity.burn),
                          ),
                        ],
                      ),
                    ),
                  ),
                  callback: () => context.read<AuthenticationCubit>().logout(
                        severity: severity,
                      ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
