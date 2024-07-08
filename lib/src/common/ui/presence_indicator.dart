import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/profile/bloc/profile_cubit.dart';
import 'package:chat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:popover/popover.dart';

class PresenceIndicator extends StatelessWidget {
  const PresenceIndicator(
      {super.key, required this.presence, this.status, this.active = false});

  final Presence presence;
  final String? status;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final options =
        Presence.values.getRange(1, Presence.values.length).toList();
    final locate = context.read;
    return Tooltip(
      message: status == null
          ? '(${presence.tooltip})'
          : '$status (${presence.tooltip})',
      verticalOffset: 12.0,
      child: InkWell(
        onTap: active
            ? () async {
                await showPopover(
                  context: context,
                  bodyBuilder: (context) {
                    var newStatus = status;
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
                                return ListTile(
                                  title: Text(value.tooltip),
                                  leading: _PresenceCircle(presence: value),
                                  onTap: () {
                                    context
                                        .read<ProfileCubit>()
                                        .updatePresence(presence: value);
                                    context.pop();
                                  },
                                );
                              },
                            ),
                            StatefulBuilder(builder: (context, setState) {
                              return Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: AxiTextFormField(
                                        labelText: 'Status message',
                                        hintText: status,
                                        onChanged: (value) => setState(() {
                                          newStatus = value;
                                        }),
                                      ),
                                    ),
                                    const SizedBox(width: 5.0),
                                    AxiIconButton(
                                      iconData: Icons.check,
                                      onPressed: () {
                                        context
                                            .read<ProfileCubit>()
                                            .updatePresence(status: newStatus);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }
            : null,
        child: _PresenceCircle(presence: presence),
      ),
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
        shape: const CircleBorder(
          side: BorderSide(
            color: Colors.white,
            width: 2.0,
          ),
        ),
        color: presence.toColor,
      ),
      child: presence.isDnd
          ? const Icon(
              Icons.remove,
              color: Colors.white,
              size: 12.0,
            )
          : null,
    );
  }
}
