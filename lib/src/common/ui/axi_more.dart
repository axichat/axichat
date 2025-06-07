import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiMore extends StatefulWidget {
  const AxiMore({
    super.key,
    required this.options,
    this.enabled = true,
  });

  final List<Widget Function(void Function() toggle)> options;
  final bool enabled;

  @override
  State<AxiMore> createState() => _AxiMoreState();
}

class _AxiMoreState extends State<AxiMore> {
  late final ShadPopoverController popoverController;

  @override
  void initState() {
    super.initState();
    popoverController = ShadPopoverController();
  }

  @override
  void dispose() {
    popoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShadPopover(
      controller: popoverController,
      popover: (context) {
        return IntrinsicWidth(
          child: Material(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in widget.options)
                  option(popoverController.toggle),
              ],
            ),
          ),
        );
      },
      child: ShadIconButton.ghost(
        enabled: widget.enabled,
        onPressed: popoverController.toggle,
        icon: const Icon(LucideIcons.ellipsisVertical),
      ),
    );
  }
}
