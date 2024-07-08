import 'package:chat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeleteCredentialsButton extends AxiIconButton {
  DeleteCredentialsButton({super.key})
      : super(
          iconData: Icons.delete,
          onPressed: () async {
            await const FlutterSecureStorage().deleteAll();
          },
        );
}
