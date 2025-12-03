import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ChatsAddButton extends StatelessWidget {
  const ChatsAddButton({super.key});

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    final l10n = context.l10n;
    return AxiDialogFab(
      tooltip: l10n.chatsCreateGroupChatTooltip,
      iconData: LucideIcons.userPlus,
      label: l10n.chatsRoomLabel,
      dialogBuilder: (context) {
        String title = '';
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(
              value: locate<ChatsCubit>(),
            ),
            BlocProvider.value(
              value: locate<AuthenticationCubit>(),
            ),
          ],
          child: StatefulBuilder(
            builder: (context, setState) {
              return AxiInputDialog(
                title: Text(l10n.chatsCreateChatRoomTitle),
                content: BlocConsumer<ChatsCubit, ChatsState>(
                  listener: (context, state) {
                    if (state.creationStatus.isSuccess) {
                      context.pop();
                    }
                  },
                  builder: (context, state) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: AxiTextFormField(
                            placeholder: Text(l10n.chatsRoomNamePlaceholder),
                            enabled: !state.creationStatus.isLoading,
                            onChanged: (value) {
                              setState(() => title = value);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                callback: title.isEmpty
                    ? null
                    : () =>
                        context.read<ChatsCubit>().createChatRoom(title: title),
              );
            },
          ),
        );
      },
    );
  }
}
