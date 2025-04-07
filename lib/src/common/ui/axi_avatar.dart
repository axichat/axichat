import 'package:chat/src/app.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/profile/bloc/profile_cubit.dart';
import 'package:chat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiAvatar extends StatefulWidget {
  const AxiAvatar({
    super.key,
    required this.jid,
    this.subscription = Subscription.none,
    this.presence,
    this.status,
    this.active = false,
  });

  final String jid;
  final Subscription subscription;
  final Presence? presence;
  final String? status;
  final bool active;

  @override
  State<AxiAvatar> createState() => _AxiAvatarState();
}

class _AxiAvatarState extends State<AxiAvatar> {
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
    Widget child = Stack(
      fit: StackFit.expand,
      children: [
        CircleAvatar(
          backgroundColor: stringToColor(widget.jid),
          child: Text(widget.jid.substring(0, 1).toUpperCase()),
        ),
        widget.presence == null ||
                widget.subscription.isNone ||
                widget.subscription.isFrom
            ? const SizedBox()
            : Align(
                alignment: Alignment.bottomRight,
                child: PresenceIndicator(
                  presence: widget.presence!,
                  status: widget.status,
                ),
              ),
      ],
    );
    if (widget.active && widget.presence != null) {
      final locate = context.read;
      child = ShadPopover(
        controller: popoverController,
        popover: (context) {
          return BlocProvider.value(
            value: locate<ProfileCubit>(),
            child: IntrinsicWidth(
              child: Material(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final value
                        in Presence.values..remove(Presence.unknown))
                      ListTile(
                        title: Text(value.tooltip),
                        leading: PresenceCircle(presence: value),
                        selected: widget.presence?.name == value.name,
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
                  ],
                ),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: 50.0,
        maxWidth: 50.0,
      ),
      child: widget.presence == null
          ? child
          : AxiTooltip(
              builder: (_) => Text(widget.status == null
                  ? '(${widget.presence!.tooltip})'
                  : '${widget.status} (${widget.presence!.tooltip})'),
              child: child,
            ),
    );
  }
}
