import 'package:axichat/src/accessibility/bloc/accessibility_action_bloc.dart';
import 'package:axichat/src/accessibility/view/shortcut_hint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:axichat/src/common/ui/ui.dart';

class AccessibilityFindActionButton extends StatelessWidget {
  const AccessibilityFindActionButton({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AccessibilityActionBloc?>();
    if (bloc == null) {
      return const SizedBox.shrink();
    }
    final shortcut = findActionShortcut(Theme.of(context).platform);
    final shortcutText = shortcutLabel(context, shortcut);
    final tooltip = 'Accessibility actions ($shortcutText)';
    if (compact) {
      return AxiTooltip(
        builder: (_) => Text(tooltip),
        child: ShadButton.ghost(
          onPressed: () => bloc.add(const AccessibilityMenuOpened()),
          padding: const EdgeInsets.all(12),
          child: const Icon(LucideIcons.accessibility, size: 18),
        ),
      );
    }
    return ShadButton.outline(
      onPressed: () => bloc.add(const AccessibilityMenuOpened()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.accessibility, size: 18),
          const SizedBox(width: 10),
          ShortcutHint(
            shortcut: shortcut,
            dense: true,
          ),
        ],
      ),
    );
  }
}
