import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class DraftButton extends StatelessWidget {
  const DraftButton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    void handleCompose() {
      context.push(
        const ComposeRoute().location,
        extra: {
          'locate': context.read,
          'attachments': const <String>[],
        },
      );
    }

    if (compact) {
      final button = ShadButton.secondary(
        size: ShadButtonSize.sm,
        onPressed: handleCompose,
        child: const Icon(LucideIcons.pencilLine, size: 16),
      ).withTapBounce();
      return AxiTooltip(
        builder: (_) => const Text('Compose a message'),
        child: button,
      );
    }
    return AxiFab(
      tooltip: 'Compose a message',
      onPressed: handleCompose,
      iconData: LucideIcons.pencilLine,
      text: 'Compose',
    );
  }
}
