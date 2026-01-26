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
    final spacing = context.spacing;
    return AxiIconButton(
      iconData: LucideIcons.logOut,
      onPressed: () {
        showFadeScaleDialog(
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
                    title: Text(title(context.l10n)),
                    content: Material(
                      child: ListTileTheme.merge(
                        shape: RoundedRectangleBorder(
                          borderRadius: context.radius,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CheckboxListTile(
                              title: Text(
                                context.l10n.authLogoutNormal,
                                style: context.textTheme.p,
                              ),
                              subtitle: Text(
                                context.l10n.authLogoutNormalDescription,
                                style: context.textTheme.small,
                              ),
                              value: severity.isNormal,
                              selected: severity.isNormal,
                              tileColor: context.colorScheme.card,
                              onChanged: (_) =>
                                  updateSeverity(LogoutSeverity.normal),
                            ),
                            SizedBox(height: spacing.s),
                            CheckboxListTile(
                              title: Text(
                                context.l10n.authLogoutBurn,
                                style: context.textTheme.p,
                              ),
                              subtitle: Text(
                                context.l10n.authLogoutBurnDescription,
                                style: context.textTheme.small,
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
        );
      },
    );
  }
}
