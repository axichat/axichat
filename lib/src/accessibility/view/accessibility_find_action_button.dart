// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/accessibility/bloc/accessibility_action_bloc.dart';
import 'package:axichat/src/accessibility/view/shortcut_hint.dart';
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
    if (context.read<AccessibilityActionBloc?>() == null) {
      return const SizedBox.shrink();
    }
    const double iconSize = 18.0;
    const double compactPadding = 12.0;
    const double labelGap = 10.0;
    final shortcut = findActionShortcut(Theme.of(context).platform);
    final shortcutText = shortcutLabel(context, shortcut);
    final tooltip = context.l10n.accessibilityActionsShortcutTooltip(
      shortcutText,
    );
    if (compact) {
      return AxiTooltip(
        builder: (_) => Text(tooltip),
        child: ShadButton.ghost(
          onPressed: () => context.read<AccessibilityActionBloc?>()?.add(
                const AccessibilityMenuOpened(),
              ),
          padding: const EdgeInsets.all(compactPadding),
          child: const Icon(LucideIcons.lifeBuoy, size: iconSize),
        ),
      );
    }
    return ShadButton.outline(
      onPressed: () => context.read<AccessibilityActionBloc?>()?.add(
            const AccessibilityMenuOpened(),
          ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.lifeBuoy, size: iconSize),
          const SizedBox(width: labelGap),
          ShortcutHint(shortcut: shortcut, dense: true),
        ],
      ),
    );
  }
}
