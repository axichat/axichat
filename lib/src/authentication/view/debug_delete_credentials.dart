// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DeleteCredentialsButton extends StatelessWidget {
  const DeleteCredentialsButton({super.key}) : assert(kDebugMode);

  @override
  Widget build(BuildContext context) {
    return AxiIconButton.ghost(
      iconData: LucideIcons.delete,
      onPressed: () async {
        await context.read<CredentialStore>().deleteAll(burn: true);
      },
    );
  }
}
