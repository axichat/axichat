import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/common/ui/ui.dart';
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
        return Column(
          children: [
            Row(
              textBaseline: TextBaseline.alphabetic,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              children: [
                Text(
                  'Body: ',
                  style: context.textTheme.muted,
                ),
                Expanded(
                  child: SelectableText(
                    message.body ?? '',
                    style: context.textTheme.small,
                  ),
                ),
              ],
            ),
            Divider(
              thickness: 1,
              color: context.colorScheme.border,
            ),
            Row(
              children: [
                Text(
                  'Sent: ${message.acked || message.received ? 'true' : 'unknown'}',
                ),
                AxiTooltip(
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      LucideIcons.info,
                    ),
                  ),
                  builder: (context) {
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300.0),
                      child: const Text(
                        'If false, the message may still have '
                        'been received but server acknowledgement '
                        'was disabled. Logging out and back in may '
                        'solve the problem.',
                        textAlign: TextAlign.left,
                      ),
                    );
                  },
                ),
              ],
            ),
            Divider(
              thickness: 1,
              color: context.colorScheme.border,
            ),
            Row(
              children: [
                Text(
                  'Encrypted: ${message.encryptionProtocol.isNotNone}',
                ),
              ],
            ),
            Divider(
              thickness: 1,
              color: context.colorScheme.border,
            ),
            Row(
              children: [
                Text('Error: ${message.error.name}'),
                if (message.error.tooltip != null)
                  AxiTooltip(
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(
                        LucideIcons.info,
                      ),
                    ),
                    builder: (context) {
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300.0),
                        child: Text(
                          message.error.tooltip!,
                          textAlign: TextAlign.left,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
