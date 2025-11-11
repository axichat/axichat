import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ChatAlert extends StatelessWidget {
  const ChatAlert({
    super.key,
    this.color = Colors.orange,
    this.iconData = LucideIcons.info,
  });

  final Color color;
  final IconData iconData;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        return AnimatedContainer(
          duration: context.watch<SettingsCubit>().animationDuration,
          color: color,
          alignment: Alignment.center,
          child: !state.showAlert || state.chat?.alert == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        iconData,
                        color: Colors.white,
                        size: 20.0,
                      ),
                      const SizedBox.square(dimension: 8.0),
                      Expanded(
                        child: Text(
                          state.chat!.alert!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox.square(dimension: 4.0),
                      ShadButton.secondary(
                        child: const Text('Hide'),
                        onPressed: () => context
                            .read<ChatBloc>()
                            .add(const ChatAlertHidden()),
                      ).withTapBounce(),
                      const SizedBox.square(dimension: 4.0),
                      ShadButton.ghost(
                        child: const Text(
                          'Ignore',
                          style: TextStyle(color: Colors.white),
                        ),
                        onPressed: () => context
                            .read<ChatBloc>()
                            .add(const ChatAlertHidden(forever: true)),
                      ).withTapBounce(),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
