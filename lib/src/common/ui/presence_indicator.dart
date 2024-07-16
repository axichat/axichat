import 'package:chat/src/app.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/profile/bloc/profile_cubit.dart';
import 'package:chat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PresenceIndicator extends StatefulWidget {
  const PresenceIndicator({
    super.key,
    required this.presence,
    this.status,
    this.active = false,
  });

  final Presence presence;
  final String? status;
  final bool active;

  @override
  State<PresenceIndicator> createState() => _PresenceIndicatorState();
}

class _PresenceIndicatorState extends State<PresenceIndicator> {
  final popoverController = ShadPopoverController();

  @override
  void dispose() {
    popoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = _PresenceCircle(presence: widget.presence);

    if (widget.active) {
      final options =
          Presence.values.getRange(1, Presence.values.length).toList();
      final locate = context.read;
      child = ShadPopover(
        controller: popoverController,
        popover: (context) {
          var newStatus = widget.status;
          return BlocProvider.value(
            value: locate<ProfileCubit>(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 250.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final value = options[index];
                      return Material(
                        child: ListTile(
                          title: Text(value.tooltip),
                          leading: _PresenceCircle(presence: value),
                          selected: widget.presence.name == value.name,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          selectedColor: context.colorScheme.accentForeground,
                          selectedTileColor: context.colorScheme.accent,
                          onTap: () {
                            context
                                .read<ProfileCubit>()
                                .updatePresence(presence: value);
                            popoverController.toggle();
                          },
                        ),
                      );
                    },
                  ),
                  StatefulBuilder(
                    builder: (context, setState) => Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: AxiTextFormField(
                              placeholder: const Text('Status message'),
                              initialValue: widget.status,
                              onChanged: (value) => setState(() {
                                newStatus = value;
                              }),
                            ),
                          ),
                          const SizedBox(width: 5.0),
                          AxiIconButton(
                            iconData: LucideIcons.check,
                            onPressed: () => context
                                .read<ProfileCubit>()
                                .updatePresence(status: newStatus),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: ShadGestureDetector(
          cursor: SystemMouseCursors.click,
          onTap: popoverController.toggle,
          child: child,
        ),
      );
    }
    return ShadTooltip(
      builder: (_) => Text(widget.status == null
          ? '(${widget.presence.tooltip})'
          : '${widget.status} (${widget.presence.tooltip})'),
      child: child,
    );
  }
}

class _PresenceCircle extends StatelessWidget {
  const _PresenceCircle({required this.presence});

  final Presence presence;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16.0,
      width: 16.0,
      decoration: ShapeDecoration(
        shape: CircleBorder(
          side: BorderSide(
            color: Color.lerp(presence.toColor, Colors.white, 0.6)!,
            width: 2.0,
          ),
        ),
        color: presence.toColor,
      ),
      child: presence.isDnd
          ? const Icon(
              LucideIcons.minus,
              color: Colors.white,
              size: 12.0,
            )
          : null,
    );
  }
}
