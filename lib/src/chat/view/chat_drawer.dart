import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/view/block_button_inline.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/routes.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/verification/bloc/verification_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ChatDrawer extends StatelessWidget {
  const ChatDrawer({
    super.key,
    required this.state,
    this.showVerification,
  });

  final ChatState state;
  final void Function()? showVerification;

  @override
  Widget build(BuildContext context) {
    final jid = state.chat?.jid;
    final muted = state.chat?.muted;
    final chat = state.chat;
    final isEmailChat = chat?.transport.isEmail ?? false;
    final encryptionAvailable =
        context.read<ChatBloc>().encryptionAvailable && !isEmailChat;
    return Drawer(
      width: 360.0,
      shape: const ContinuousRectangleBorder(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.maxFinite,
            child: DrawerHeader(
              padding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 8.0),
              child: Text(
                '${state.chat?.title}',
                style: context.textTheme.h4,
              ),
            ),
          ),
          encryptionAvailable
              ? Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: ShadSwitch(
                    label: const Text('Encryption'),
                    sublabel: const Text('Send messages end-to-end encrypted'),
                    value: chat!.encryptionProtocol.isNotNone,
                    onChanged: (encrypted) => context.read<ChatBloc>().add(
                          ChatEncryptionChanged(
                            protocol: encrypted
                                ? EncryptionProtocol.omemo
                                : EncryptionProtocol.none,
                          ),
                        ),
                  ),
                )
              : const SizedBox.shrink(),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ShadSwitch(
              label: const Text('Notifications'),
              sublabel: const Text('Receive background message notifications'),
              value: !muted!,
              onChanged: (muted) =>
                  context.read<ChatBloc>().add(ChatMuted(!muted)),
            ),
          ),
          const Spacer(),
          encryptionAvailable
              ? ShadButton.ghost(
                  width: double.infinity,
                  mainAxisAlignment: MainAxisAlignment.start,
                  leading: Icon(
                    LucideIcons.shieldUser,
                    size: context.iconTheme.size,
                  ),
                  child: const Text('Verification'),
                  onPressed: () {
                    context.read<VerificationCubit>().loadFingerprints();
                    showVerification?.call();
                    Scaffold.of(context).closeEndDrawer();
                  },
                )
              : const SizedBox.shrink(),
          encryptionAvailable
              ? ShadButton.ghost(
                  width: double.infinity,
                  mainAxisAlignment: MainAxisAlignment.start,
                  leading: Icon(
                    LucideIcons.userCog,
                    size: context.iconTheme.size,
                  ),
                  foregroundColor: context.colorScheme.destructive,
                  onPressed: () async {
                    if (await confirm(
                          context,
                          text: 'Only do this is you are an expert.',
                        ) !=
                        true) {
                      return;
                    }
                    if (context.mounted) {
                      context
                          .read<ChatBloc>()
                          .add(const ChatEncryptionRepaired());
                    }
                  },
                  child: const Text('Repair encryption'),
                )
              : const SizedBox.shrink(),
          ShadButton.ghost(
            width: double.infinity,
            mainAxisAlignment: MainAxisAlignment.start,
            leading: Icon(
              LucideIcons.flag,
              size: context.iconTheme.size,
            ),
            foregroundColor: context.colorScheme.destructive,
            onPressed: () => context.push(
              const ComposeRoute().location,
              extra: {
                'locate': context.read,
                'jids': ['spam@axichat.com'],
                'body': 'I want to report \'$jid\' for spam.',
              },
            ),
            child: const Text('Report spam'),
          ),
          BlockButtonInline(
            jid: jid!,
            showIcon: true,
            mainAxisAlignment: MainAxisAlignment.start,
          ),
        ],
      ),
    );
  }
}
