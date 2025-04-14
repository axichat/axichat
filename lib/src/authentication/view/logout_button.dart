import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
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
                  title: const Text('Log Out'),
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
                            title: const Text('Normal'),
                            subtitle: const Text('Clear JID and password.'),
                            selected: severity.isNormal,
                            onTap: () => setState(() {
                              severity = LogoutSeverity.normal;
                            }),
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            title: const Text('Burn'),
                            subtitle: const Text(
                                'Permanently delete all data and messages '
                                'for account on this device.'),
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
