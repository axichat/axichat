// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class DeleteCredentialsButton extends AxiIconButton {
  DeleteCredentialsButton({super.key})
      : assert(kDebugMode),
        super.ghost(
          iconData: LucideIcons.delete,
          onPressed: () async {
            await const FlutterSecureStorage().deleteAll();
          },
        );
}
