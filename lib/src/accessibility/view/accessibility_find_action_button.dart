// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/accessibility/bloc/accessibility_action_bloc.dart';
import 'package:axichat/src/accessibility/view/shortcut_hint.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:axichat/src/common/ui/ui.dart';

class AccessibilityFindActionButton extends StatelessWidget {
  const AccessibilityFindActionButton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final shortcut = findActionShortcut(EnvScope.of(context).platform);
    final shortcutText = shortcutLabel(context, shortcut);
    final tooltip = context.l10n.accessibilityActionsShortcutTooltip(
      shortcutText,
    );
    if (compact) {
      return AxiTooltip(
        builder: (_) => Text(tooltip),
        child: AxiIconButton.ghost(
          iconData: LucideIcons.lifeBuoy,
          tooltip: tooltip,
          onPressed: () => context.read<AccessibilityActionBloc>().add(
            const AccessibilityMenuOpened(),
          ),
        ),
      );
    }
    return AxiButton.outline(
      onPressed: () => context.read<AccessibilityActionBloc>().add(
        const AccessibilityMenuOpened(),
      ),
      leading: Icon(
        LucideIcons.lifeBuoy,
        size: context.sizing.iconButtonIconSize,
      ),
      child: ShortcutHint(shortcut: shortcut, dense: true),
    );
  }
}
