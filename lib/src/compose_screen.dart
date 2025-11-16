import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/view/draft_form.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ComposeScreen extends StatelessWidget {
  const ComposeScreen({
    super.key,
    this.id,
    this.jids = const [''],
    this.body = '',
    this.subject = '',
    this.attachmentMetadataIds = const [],
    required this.locate,
  });

  final int? id;
  final List<String> jids;
  final String body;
  final String subject;
  final List<String> attachmentMetadataIds;
  final T Function<T>() locate;

  @override
  Widget build(BuildContext context) {
    final xmppService = locate<XmppService>();
    final MessageService messageService = xmppService;
    final emailService = _maybeLocate<EmailService>();
    return Scaffold(
      backgroundColor: context.colorScheme.background,
      appBar: AppBar(
        backgroundColor: context.colorScheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        forceMaterialTransparency: true,
        shape: Border(
          bottom: BorderSide(color: context.colorScheme.border),
        ),
        leadingWidth: AxiIconButton.kDefaultSize + 24,
        leading: Navigator.canPop(context)
            ? Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: AxiIconButton.kDefaultSize,
                    height: AxiIconButton.kDefaultSize,
                    child: AxiIconButton(
                      iconData: LucideIcons.arrowLeft,
                      tooltip: 'Back',
                      color: context.colorScheme.foreground,
                      borderColor: context.colorScheme.border,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              )
            : null,
        title: const Text('Compose'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400.0),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: context.colorScheme.card,
                shape: ContinuousRectangleBorder(
                  borderRadius: context.radius,
                  side: BorderSide(color: context.colorScheme.border),
                ),
              ),
              child: MultiRepositoryProvider(
                providers: [
                  RepositoryProvider<MessageService>.value(
                    value: messageService,
                  ),
                ],
                child: Builder(
                  builder: (context) {
                    final chatsCubit = _maybeLocate<ChatsCubit>();
                    final draftCubit = _maybeLocate<DraftCubit>();
                    final providers = <BlocProvider<dynamic>>[
                      if (draftCubit != null)
                        BlocProvider<DraftCubit>.value(value: draftCubit)
                      else
                        BlocProvider<DraftCubit>(
                          create: (context) => DraftCubit(
                            messageService: messageService,
                            emailService: emailService,
                          ),
                        ),
                    ];
                    if (chatsCubit != null) {
                      providers.add(
                        BlocProvider.value(value: chatsCubit),
                      );
                    }
                    return MultiBlocProvider(
                      providers: providers,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16.0),
                        child: DraftForm(
                          id: id,
                          jids: jids,
                          body: body,
                          subject: subject,
                          attachmentMetadataIds: attachmentMetadataIds,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  T? _maybeLocate<T>() {
    try {
      return locate<T>();
    } catch (_) {
      return null;
    }
  }
}
