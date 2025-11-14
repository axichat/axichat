import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/view/block_button_inline.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/bloc/chat_transport_cubit.dart';
import 'package:axichat/src/chat/view/filter_toggle.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/routes.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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
    final transport = context.watch<ChatTransportCubit>().state;
    final canUseEmail = (chat?.deltaChatId != null) ||
        (chat?.emailAddress?.isNotEmpty ?? false);
    final isEmailTransport = canUseEmail && transport.isEmail;
    final encryptionAvailable =
        context.read<ChatBloc>().encryptionAvailable && !isEmailTransport;
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
            if (chat != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send via',
                      style: context.textTheme.small.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ChatTransportSelector(
                      transport: transport,
                      emailEnabled: canUseEmail,
                      onChanged: (candidate) => context
                          .read<ChatBloc>()
                          .add(ChatTransportChanged(candidate)),
                    ),
                    if (isEmailTransport)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: FilterToggle(
                          padding: EdgeInsets.zero,
                          selected: state.viewFilter,
                          contactName: chat.title,
                          onChanged: (filter) => context
                              .read<ChatBloc>()
                              .add(ChatViewFilterChanged(filter: filter)),
                        ),
                      ),
                  ],
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
              onPressed: () => context.push(
                const ComposeRoute().location,
                extra: {
                  'locate': context.read,
                  'jids': ['spam@axichat.com'],
                  'body': 'I want to report \'$jid\' for spam.',
                  'attachments': const <String>[],
                },
              ),
              child: const Text('Report spam'),
            ).withTapBounce(),
            BlockButtonInline(
              jid: jid!,
              showIcon: true,
              mainAxisAlignment: MainAxisAlignment.start,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTransportSelector extends StatelessWidget {
  const _ChatTransportSelector({
    required this.transport,
    required this.emailEnabled,
    required this.onChanged,
  });

  final MessageTransport transport;
  final bool emailEnabled;
  final ValueChanged<MessageTransport> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final muted = context.textTheme.muted.color ??
        colors.foreground.withValues(alpha: 0.7);

    Widget buildChip(MessageTransport candidate) {
      final selected = candidate == transport;
      final unavailable = candidate.isEmail && !emailEnabled;
      final foreground =
          candidate.isEmail ? colors.destructive : colors.accentForeground;
      final selectedColor = candidate.isEmail
          ? colors.destructive.withValues(alpha: 0.16)
          : colors.accent.withValues(alpha: 0.22);
      final unselectedColor = candidate.isEmail
          ? colors.destructive.withValues(alpha: 0.06)
          : colors.accent.withValues(alpha: 0.1);
      final labelColor = selected ? foreground : muted;

      final chip = ChoiceChip(
        showCheckmark: false,
        label: Text(
          candidate.label,
          style: context.textTheme.small.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: labelColor,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        selected: selected,
        onSelected: unavailable
            ? null
            : (value) {
                if (value) onChanged(candidate);
              },
        side: BorderSide(
          color: selected
              ? Colors.transparent
              : colors.border.withValues(alpha: 0.7),
        ),
        backgroundColor: unselectedColor,
        selectedColor: selectedColor,
        disabledColor: colors.border.withValues(alpha: 0.4),
      );

      if (!unavailable) {
        return chip;
      }

      return Tooltip(
        message: 'Email transport unavailable for this chat',
        preferBelow: false,
        child: chip,
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children:
            MessageTransport.values.map(buildChip).toList(growable: false),
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
