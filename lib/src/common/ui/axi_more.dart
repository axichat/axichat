import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiMore extends StatefulWidget {
  const AxiMore({
    super.key,
    required this.actions,
    this.tooltip = 'More options',
    this.enabled = true,
  });

  final List<AxiMenuAction> actions;
  final String tooltip;
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
    final actions = widget.actions
        .map(
          (action) => AxiMenuAction(
            label: action.label,
            icon: action.icon,
            destructive: action.destructive,
            enabled: action.enabled,
            onPressed: action.onPressed == null
                ? null
                : () {
                    popoverController.hide();
                    action.onPressed?.call();
                  },
          ),
        )
        .toList(growable: false);
    return ShadPopover(
      controller: popoverController,
      closeOnTapOutside: true,
      padding: EdgeInsets.zero,
      popover: (context) {
        return AxiMenu(actions: actions);
      },
      child: AxiIconButton(
        iconData: LucideIcons.ellipsisVertical,
        tooltip: widget.tooltip,
        onPressed: widget.enabled ? popoverController.toggle : null,
      ),
    );
  }
}
