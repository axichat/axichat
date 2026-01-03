// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiDeleteMenuItem extends StatelessWidget {
  const AxiDeleteMenuItem({super.key, this.onPressed});

  final void Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return ShadContextMenuItem(
      leading: Icon(
        LucideIcons.trash,
        color: context.colorScheme.destructive,
      ),
      onPressed: onPressed,
      child: Text(context.l10n.commonDelete),
    );
  }
}
