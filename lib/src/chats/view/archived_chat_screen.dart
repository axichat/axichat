import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/bloc/chat_search_cubit.dart';
import 'package:axichat/src/chat/bloc/chat_transport_cubit.dart';
import 'package:axichat/src/chat/view/chat.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ArchivedChatScreen extends StatelessWidget {
  const ArchivedChatScreen({
    super.key,
    required this.locate,
    required this.jid,
  });

  final T Function<T>() locate;
  final String jid;

  @override
  Widget build(BuildContext context) {
    final xmppService = locate<XmppService>();
    final notificationService = locate<NotificationService>();
    final emailService = locate<EmailService>();
    final chatsCubit = locate<ChatsCubit>();
    final OmemoService? omemoService =
        xmppService is OmemoService ? xmppService as OmemoService : null;

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: chatsCubit),
        BlocProvider(
          create: (_) => ChatBloc(
            jid: jid,
            messageService: xmppService,
            chatsService: xmppService,
            notificationService: notificationService,
            emailService: emailService,
            omemoService: omemoService,
          ),
        ),
        BlocProvider(
          create: (_) => ChatTransportCubit(
            chatsService: xmppService,
            jid: jid,
          ),
        ),
        BlocProvider(
          create: (_) => ChatSearchCubit(
            jid: jid,
            messageService: xmppService,
          ),
        ),
      ],
      child: const _ArchivedChatBody(),
    );
  }
}

class _ArchivedChatBody extends StatelessWidget {
  const _ArchivedChatBody();

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archive'),
        leadingWidth: AxiIconButton.kDefaultSize + 24,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: AxiIconButton.kDefaultSize,
              height: AxiIconButton.kDefaultSize,
              child: AxiIconButton(
                iconData: LucideIcons.arrowLeft,
                tooltip: 'Back',
                color: colors.foreground,
                borderColor: colors.border,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: colors.border,
          ),
        ),
      ),
      body: const SafeArea(
        child: Chat(readOnly: true),
      ),
    );
  }
}
