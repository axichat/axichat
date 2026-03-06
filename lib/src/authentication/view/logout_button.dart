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
            var loading = false;
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
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AxiCheckboxFormField(
                          key: ValueKey('logout-normal-${severity.name}'),
                          enabled: !loading,
                          initialValue: severity.isNormal,
                          inputLabel: Text(context.l10n.authLogoutNormal),
                          inputSublabel: Text(
                            context.l10n.authLogoutNormalDescription,
                          ),
                          onChanged: (_) =>
                              updateSeverity(LogoutSeverity.normal),
                        ),
                        SizedBox(height: spacing.s),
                        AxiCheckboxFormField(
                          key: ValueKey('logout-burn-${severity.name}'),
                          enabled: !loading,
                          initialValue: severity.isBurn,
                          inputLabel: Text(context.l10n.authLogoutBurn),
                          inputSublabel: Text(
                            context.l10n.authLogoutBurnDescription,
                          ),
                          onChanged: (_) => updateSeverity(LogoutSeverity.burn),
                        ),
                      ],
                    ),
                    loading: loading,
                    callback: loading
                        ? null
                        : () async {
                            setState(() {
                              loading = true;
                            });
                            try {
                              await context.read<AuthenticationCubit>().logout(
                                severity: severity,
                              );
                            } finally {
                              if (!context.mounted) {
                                return;
                              }
                              setState(() {
                                loading = false;
                              });
                            }
                          },
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
