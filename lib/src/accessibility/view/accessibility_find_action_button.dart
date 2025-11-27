import 'package:axichat/src/accessibility/bloc/accessibility_action_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
    const label = 'Find action';
    if (compact) {
      return Tooltip(
        message: label,
        child: ShadButton.ghost(
          onPressed: () => bloc.add(const AccessibilityMenuOpened()),
          padding: const EdgeInsets.all(12),
          child: const Icon(LucideIcons.command, size: 18),
        ),
      );
    }
    final textTheme = Theme.of(context).textTheme;
    return ShadButton.outline(
      onPressed: () => bloc.add(const AccessibilityMenuOpened()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.command, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: (textTheme.bodyMedium ?? const TextStyle())
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
