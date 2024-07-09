import 'package:chat/src/common/ui/ui.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class DeleteCredentialsButton extends AxiIconButton {
  DeleteCredentialsButton({super.key})
      : super(
          iconData: LucideIcons.delete,
          onPressed: () async {
            await const FlutterSecureStorage().deleteAll();
          },
        );
}
