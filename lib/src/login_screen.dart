import 'package:chat/src/authentication/view/debug_delete_credentials.dart';
import 'package:chat/src/authentication/view/login_form.dart';
import 'package:chat/src/chat/view/chat.dart';
import 'package:chat/src/common/ui/narrow_layout.dart';
import 'package:chat/src/common/ui/wide_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Axichat'),
        actions: kDebugMode
            ? [DeleteCredentialsButton(), const SizedBox(width: 50)]
            : null,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 600) {
              return const WideLayout(
                smallChild: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: LoginForm(),
                ),
                largeChild: Chat(),
              );
            }

            return const NarrowLayout(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: LoginForm(),
              ),
            );
          },
        ),
      ),
    );
  }
}
