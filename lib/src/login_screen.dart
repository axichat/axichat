import 'package:chat/src/app.dart';
import 'package:chat/src/authentication/view/debug_delete_credentials.dart';
import 'package:chat/src/authentication/view/login_form.dart';
import 'package:chat/src/chat/view/chat.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        shape: Border(
          bottom: BorderSide(color: context.colorScheme.border),
        ),
        title: const Text('Axichat'),
        actions: kDebugMode
            ? [DeleteCredentialsButton(), const SizedBox(width: 50)]
            : null,
      ),
      body: const SafeArea(
        child: AxiAdaptiveLayout(
          primaryChild: Padding(
            padding: EdgeInsets.all(16.0),
            child: LoginForm(),
          ),
          secondaryChild: GuestChat(),
        ),
      ),
    );
  }
}
