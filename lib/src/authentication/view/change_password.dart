import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:shadcn_ui/shadcn_ui.dart';

class ChangePasswordButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AxiInputDialog(
        title: Text(ChangePassword.title), content: ChangePassword());
  }
}

class ChangePassword extends StatefulWidget {
  const ChangePassword({super.key});

  static const title = 'Change Password';

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  late TextEditingController _passwordTextController;
  late TextEditingController _newPasswordTextController;
  late TextEditingController _newPassword2TextController;

  var _loading = false;

  String? _successText;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _passwordTextController = TextEditingController();
    _newPasswordTextController = TextEditingController();
    _newPassword2TextController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordTextController.dispose();
    _newPasswordTextController.dispose();
    _newPassword2TextController.dispose();
    super.dispose();
  }

  void _onPressed(BuildContext context) async {
    if (!Form.of(context).mounted || !Form.of(context).validate()) return;
    setState(() {
      _loading = true;
    });
    try {
      final response = await http.post(
        AuthenticationCubit.changePasswordUrl,
        body: {
          'username': context.read<ProfileCubit>().state.username,
          'host': AuthenticationCubit.domain,
          'passwordold': _passwordTextController.value.text,
          'password': _newPasswordTextController.value.text,
          'password2': _newPassword2TextController.value.text,
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          _successText = response.body;
          _errorText = null;
        });
      } else {
        setState(() {
          _successText = null;
          _errorText = response.body;
        });
      }
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _successText != null
              ? Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Text(
                    _successText!,
                    textAlign: TextAlign.center,
                  ),
                )
              : _errorText != null
                  ? Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        _errorText!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colorScheme.destructive,
                        ),
                      ),
                    )
                  : const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: PasswordInput(
              placeholder: 'Old password',
              enabled: !_loading,
              controller: _passwordTextController,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: PasswordInput(
              placeholder: 'New password',
              enabled: !_loading,
              controller: _newPasswordTextController,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: PasswordInput(
              placeholder: 'Confirm new password',
              enabled: !_loading,
              controller: _newPassword2TextController,
            ),
          ),
          const SizedBox.square(dimension: 16.0),
          Builder(
            builder: (context) {
              return ShadButton(
                enabled: !_loading,
                onPressed: () => _onPressed(context),
                leading: AnimatedCrossFade(
                  crossFadeState: _loading
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: context.read<SettingsCubit>().animationDuration,
                  firstChild: const SizedBox(),
                  secondChild: AxiProgressIndicator(
                    color: context.colorScheme.primaryForeground,
                    semanticsLabel: 'Waiting for password change',
                  ),
                ),
                trailing: const SizedBox.shrink(),
                child: const Text('Continue'),
              );
            },
          ),
        ],
      ),
    );
  }
}
