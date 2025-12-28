import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/app.dart';
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
    const createLabel = 'Create';
    const emptyTitleValidationMessage = 'Room name cannot be empty.';
    const invalidCharacterValidationMessage =
        'Room names cannot contain a + character.';
    return AxiDialogFab(
      tooltip: l10n.chatsCreateGroupChatTooltip,
      iconData: LucideIcons.userPlus,
      label: l10n.chatsRoomLabel,
      dialogBuilder: (context) {
        String title = '';
        String? validationError;
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
                      context.read<ChatsCubit>().clearCreationStatus();
                    }
                  },
                  builder: (context, state) {
                    final loading = state.creationStatus.isLoading;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: AxiTextFormField(
                            placeholder: Text(l10n.chatsRoomNamePlaceholder),
                            enabled: !loading,
                            onChanged: (value) {
                              setState(() {
                                title = value;
                                validationError = null;
                              });
                            },
                          ),
                        ),
                        if (validationError != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                validationError!,
                                style: context.textTheme.small.copyWith(
                                  color: context.colorScheme.destructive,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                callbackText: createLabel,
                loading:
                    context.watch<ChatsCubit>().state.creationStatus.isLoading,
                callback: title.isEmpty
                    ? null
                    : () {
                        final trimmed = title.trim();
                        if (trimmed.isEmpty) {
                          setState(() =>
                              validationError = emptyTitleValidationMessage);
                          return;
                        }
                        if (trimmed.contains('+')) {
                          setState(() => validationError =
                              invalidCharacterValidationMessage);
                          return;
                        }
                        setState(() => validationError = null);
                        context
                            .read<ChatsCubit>()
                            .createChatRoom(title: trimmed);
                      },
              );
            },
          ),
        );
      },
    );
  }
}
