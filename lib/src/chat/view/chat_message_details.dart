import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/common/bool_tool.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ChatMessageDetails extends StatelessWidget {
  const ChatMessageDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final message = state.focused;
        if (message == null) return const SizedBox.shrink();
        return SingleChildScrollView(
          child: Container(
            width: double.maxFinite,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              spacing: 24,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SelectableText(
                  message.body ?? '',
                  style: context.textTheme.lead,
                ),
                Wrap(
                  spacing: 12.0,
                  children: [
                    ShadBadge.secondary(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        spacing: 6.0,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Sent'),
                          Icon(
                            message.acked.toIcon,
                            color: message.acked.toColor,
                          ),
                        ],
                      ),
                    ),
                    ShadBadge.secondary(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        spacing: 6.0,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Received'),
                          Icon(
                            message.received.toIcon,
                            color: message.received.toColor,
                          ),
                        ],
                      ),
                    ),
                    ShadBadge.secondary(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        spacing: 6.0,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Displayed'),
                          Icon(
                            message.displayed.toIcon,
                            color: message.displayed.toColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  'Encryption is disabled. Messages are sent in plaintext.',
                  style: context.textTheme.muted,
                  textAlign: TextAlign.center,
                ),
                if (message.error.isNotNone)
                  Column(
                    spacing: 8,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Error',
                        style: context.textTheme.muted,
                      ),
                      Text(message.error.asString),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
