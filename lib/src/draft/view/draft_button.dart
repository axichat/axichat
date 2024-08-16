import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/draft/view/draft_form.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class DraftButton extends StatelessWidget {
  const DraftButton({super.key});

  @override
  Widget build(BuildContext context) {
    return AxiTooltip(
      builder: (_) => const Text('Compose a message'),
      child: FloatingActionButton(
        child: const Icon(LucideIcons.pencilLine),
        onPressed: () => showDraft(context, id: null),
      ),
    );
  }
}
