import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _unregisterErrorPaddingValue = 10.0;
const double _unregisterFieldPaddingValue = 8.0;
const double _unregisterSpacerHeight = 40.0;
const double _unregisterButtonGap = 16.0;
const EdgeInsets _unregisterErrorPadding =
    EdgeInsets.all(_unregisterErrorPaddingValue);
const EdgeInsets _unregisterFieldPadding =
    EdgeInsets.all(_unregisterFieldPaddingValue);

class UnregisterForm extends StatefulWidget {
  const UnregisterForm({super.key});

  static String title(AppLocalizations l10n) => l10n.authUnregisterTitle;

  @override
  State<UnregisterForm> createState() => _UnregisterFormState();
}

class _UnregisterFormState extends State<UnregisterForm> {
  late TextEditingController _passwordTextController;

  @override
  void initState() {
    super.initState();
    _passwordTextController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordTextController.dispose();
    super.dispose();
  }

  void _onPressed(BuildContext context) async {
    final form = Form.of(context);
    if (!form.validate()) return;
    final l10n = context.l10n;
    final approved = await confirm(
      context,
      title: l10n.authUnregisterConfirmTitle,
      message: l10n.authUnregisterConfirmMessage,
      confirmLabel: l10n.authUnregisterConfirmAction,
      cancelLabel: l10n.commonCancel,
      destructiveConfirm: true,
    );
    if (!context.mounted || approved != true) return;
    await context.read<AuthenticationCubit>().unregister(
          username: context.read<ProfileCubit>().state.username,
          host: context.read<AuthenticationCubit>().endpointConfig.domain,
          password: _passwordTextController.value.text,
        );
    _passwordTextController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationCubit, AuthenticationState>(
      builder: (context, state) {
        final l10n = context.l10n;
        final loading = state is AuthenticationUnregisterInProgress;
        return Form(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                UnregisterForm.title(l10n),
                style: context.textTheme.h3,
              ),
              state is AuthenticationUnregisterFailure
                  ? Padding(
                      padding: _unregisterErrorPadding,
                      child: Text(
                        state.errorText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colorScheme.destructive,
                        ),
                      ),
                    )
                  : const SizedBox(height: _unregisterSpacerHeight),
              Padding(
                padding: _unregisterFieldPadding,
                child: PasswordInput(
                  placeholder: l10n.authPasswordPlaceholder,
                  enabled: !loading,
                  controller: _passwordTextController,
                ),
              ),
              const SizedBox.square(dimension: _unregisterButtonGap),
              Builder(
                builder: (context) {
                  return ShadButton.destructive(
                    enabled: !loading,
                    onPressed: () => _onPressed(context),
                    leading: AnimatedCrossFade(
                      crossFadeState: loading
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration:
                          context.watch<SettingsCubit>().animationDuration,
                      firstChild: const SizedBox(),
                      secondChild: AxiProgressIndicator(
                        color: context.colorScheme.primaryForeground,
                        semanticsLabel: l10n.authUnregisterProgressLabel,
                      ),
                    ),
                    trailing: const SizedBox.shrink(),
                    child: Text(l10n.commonContinue),
                  ).withTapBounce(enabled: !loading);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
