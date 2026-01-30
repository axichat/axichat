// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/view/compose_launcher.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';

class DraftButton extends StatelessWidget {
  const DraftButton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    void handleCompose() {
      openComposeDraft(context, attachmentMetadataIds: const <String>[]);
    }

    if (compact) {
      return AxiIconButton.secondary(
        iconData: LucideIcons.pencilLine,
        tooltip: l10n.draftComposeMessage,
        semanticLabel: l10n.draftComposeMessage,
        onPressed: handleCompose,
      );
    }
    return AxiFab(
      tooltip: l10n.draftComposeMessage,
      onPressed: handleCompose,
      iconData: LucideIcons.pencilLine,
      text: l10n.draftCompose,
    );
  }
}
