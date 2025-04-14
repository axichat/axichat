import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class DraftButton extends StatelessWidget {
  const DraftButton({super.key});

  @override
  Widget build(BuildContext context) {
    return AxiTooltip(
      builder: (_) => const Text('Compose a message'),
      child: AxiFab(
        onPressed: () => context.push(
          const ComposeRoute().location,
          extra: {'locate': context.read},
        ),
        iconData: LucideIcons.pencilLine,
        text: 'Compose',
      ),
    );
  }
}
