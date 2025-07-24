import 'package:axichat/src/app.dart';
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
      child: const Text('Delete'),
    );
  }
}
