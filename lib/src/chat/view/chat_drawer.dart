import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/view/block_button_inline.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/view/filter_toggle.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ChatDrawer extends StatelessWidget {
  const ChatDrawer({
    super.key,
    required this.state,
  });

  final ChatState state;

  @override
  Widget build(BuildContext context) {
    final jid = state.chat?.jid;
    final muted = state.chat?.muted;
    final chat = state.chat;
    final supportsEmail = chat?.supportsEmail ?? false;
    final encryptionAvailable = context.read<ChatBloc>().encryptionAvailable &&
        (chat?.defaultTransport.isEmail != true);
    final isSpamChat = chat?.spam ?? false;
    final colors = context.colorScheme;
    return Drawer(
      backgroundColor: colors.background,
      width: 360.0,
      shape: const ContinuousRectangleBorder(),
      child: Material(
        color: colors.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.maxFinite,
              child: DrawerHeader(
                padding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 8.0),
                decoration: const BoxDecoration(color: Colors.transparent),
                child: Text(
                  '${state.chat?.title}',
                  style: context.textTheme.h4,
                ),
              ),
            ),
            if (chat != null && supportsEmail) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: FilterToggle(
                  padding: EdgeInsets.zero,
                  selected: state.viewFilter,
                  contactName: chat.title,
                  onChanged: (filter) => context
                      .read<ChatBloc>()
                      .add(ChatViewFilterChanged(filter: filter)),
                ),
              ),
              const _DrawerDivider(),
            ],
            encryptionAvailable
                ? Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: ShadSwitch(
                      label: const Text('Encryption'),
                      sublabel:
                          const Text('Send messages end-to-end encrypted'),
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
                sublabel:
                    const Text('Receive background message notifications'),
                value: !muted!,
                onChanged: (muted) =>
                    context.read<ChatBloc>().add(ChatMuted(!muted)),
              ),
            ),
            const _DrawerDivider(),
            const Spacer(),
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
                  ).withTapBounce()
                : const SizedBox.shrink(),
            ShadButton.ghost(
              width: double.infinity,
              mainAxisAlignment: MainAxisAlignment.start,
              leading: Icon(
                LucideIcons.flag,
                size: context.iconTheme.size,
              ),
              foregroundColor: context.colorScheme.destructive,
              onPressed: () async {
                final targetChat = chat;
                final currentJid = jid;
                if (targetChat == null || currentJid == null) {
                  return;
                }
                final xmppService = context.read<XmppService?>();
                final emailService =
                    RepositoryProvider.of<EmailService?>(context);
                final sendToSpam = !targetChat.spam;
                await xmppService?.toggleChatSpam(
                  jid: currentJid,
                  spam: sendToSpam,
                );
                final address = targetChat.emailAddress?.trim();
                if (targetChat.transport.isEmail &&
                    address?.isNotEmpty == true) {
                  if (sendToSpam) {
                    await emailService?.spam.mark(address!);
                  } else {
                    await emailService?.spam.unmark(address!);
                  }
                }
                if (!context.mounted) return;
                final toastMessage = sendToSpam
                    ? 'Sent ${targetChat.title} to spam.'
                    : 'Returned ${targetChat.title} to inbox.';
                ShadToaster.maybeOf(context)?.show(
                  ShadToast(
                    title: Text(sendToSpam ? 'Reported' : 'Restored'),
                    description: Text(toastMessage),
                    alignment: Alignment.topRight,
                    showCloseIconOnlyWhenHovered: false,
                  ),
                );
              },
              child: Text(isSpamChat ? 'Move to inbox' : 'Report spam'),
            ).withTapBounce(),
            BlockButtonInline(
              jid: jid!,
              emailAddress: chat?.emailAddress,
              useEmailBlocking: chat?.defaultTransport.isEmail ?? false,
              showIcon: true,
              mainAxisAlignment: MainAxisAlignment.start,
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerDivider extends StatelessWidget {
  const _DrawerDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Divider(
        height: 1,
        thickness: 1,
        color: context.colorScheme.border,
      ),
    );
  }
}
