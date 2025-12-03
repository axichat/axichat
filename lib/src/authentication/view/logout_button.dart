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
      onPressed: () => showDialog(
        context: context,
        builder: (context) {
          var severity = LogoutSeverity.normal;
          return BlocProvider.value(
            value: locate<AuthenticationCubit>(),
            child: StatefulBuilder(
              builder: (context, setState) {
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
                          ListTile(
                            title: Text(l10n.authLogoutNormal),
                            subtitle: Text(l10n.authLogoutNormalDescription),
                            selected: severity.isNormal,
                            onTap: () => setState(() {
                              severity = LogoutSeverity.normal;
                            }),
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            title: Text(l10n.authLogoutBurn),
                            subtitle: Text(l10n.authLogoutBurnDescription),
                            isThreeLine: true,
                            selected: severity.isBurn,
                            onTap: () => setState(() {
                              severity = LogoutSeverity.burn;
                            }),
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
