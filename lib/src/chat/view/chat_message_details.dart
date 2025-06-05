import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/common/bool_tool.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/verification/bloc/verification_cubit.dart';
import 'package:axichat/src/verification/view/verification_selector.dart';
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
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            spacing: 24,
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
              if (message.deviceID != null &&
                  context.read<VerificationCubit?>() != null)
                BlocBuilder<VerificationCubit, VerificationState>(
                  builder: (context, verificationState) {
                    final list = message.senderJid ==
                            context.read<ProfileCubit>().state.jid
                        ? verificationState.myFingerprints
                        : verificationState.fingerprints;
                    final fingerprint =
                        list.singleWhere((e) => e.deviceID == message.deviceID);
                    return VerificationSelector(fingerprint: fingerprint);
                  },
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
          ),
        );
      },
    );
  }
}
