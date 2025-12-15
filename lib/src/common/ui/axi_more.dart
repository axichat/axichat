import 'package:axichat/src/common/env.dart';
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

  Future<void> _showSheetActions(List<AxiMenuAction> actions) async {
    if (!mounted) return;
    const double sheetItemSpacing = 4;
    const double sheetPadding = 8;
    await showAdaptiveBottomSheet<void>(
      context: context,
      showDragHandle: true,
      dialogMaxWidth: 420,
      builder: (sheetContext) {
        final colors = ShadTheme.of(sheetContext).colorScheme;
        final textTheme = ShadTheme.of(sheetContext).textTheme;
        return AxiSheetScaffold.scroll(
          header: AxiSheetHeader(
            title: Text(widget.tooltip),
            onClose: () => Navigator.of(sheetContext).maybePop(),
            padding: const EdgeInsets.fromLTRB(
              sheetPadding,
              sheetPadding,
              sheetPadding,
              sheetPadding,
            ),
          ),
          bodyPadding: const EdgeInsets.fromLTRB(
            sheetPadding,
            0,
            sheetPadding,
            sheetPadding,
          ),
          children: [
            for (final action in actions) ...[
              ListTile(
                enabled: action.enabled,
                leading: action.icon == null
                    ? null
                    : Icon(
                        action.icon,
                        color: action.destructive
                            ? colors.destructive
                            : colors.primary,
                      ),
                title: Text(
                  action.label,
                  style: action.destructive
                      ? textTheme.small.copyWith(
                          color: colors.destructive,
                          fontWeight: FontWeight.w700,
                        )
                      : null,
                ),
                onTap: action.enabled
                    ? () {
                        Navigator.of(sheetContext).pop();
                        action.onPressed?.call();
                      }
                    : null,
              ),
              const SizedBox(height: sheetItemSpacing),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final commandSurface = resolveCommandSurface(context);
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
    if (commandSurface == CommandSurface.sheet) {
      return AxiIconButton(
        iconData: LucideIcons.ellipsisVertical,
        tooltip: widget.tooltip,
        onPressed: widget.enabled ? () => _showSheetActions(actions) : null,
      );
    }
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
