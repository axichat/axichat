import 'package:chat/src/authentication/bloc/authentication_cubit.dart';
import 'package:chat/src/common/request_status.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/chats/bloc/chats_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ChatsAddButton extends StatelessWidget {
  const ChatsAddButton({super.key});

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    return AxiTooltip(
      builder: (_) => const Text('Create chat room'),
      child: AxiFab(
        iconData: LucideIcons.userPlus,
        text: 'Room',
        onPressed: () => showShadDialog(
          context: context,
          builder: (context) {
            String title = '';
            String? nickname;
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
                    title: const Text('Create chat room'),
                    content: BlocConsumer<ChatsCubit, ChatsState>(
                      listener: (context, state) {
                        if (state.creationStatus == RequestStatus.success) {
                          context.pop();
                        }
                      },
                      builder: (context, state) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AxiTextFormField(
                              placeholder: const Text('Title'),
                              enabled:
                                  state.creationStatus == RequestStatus.loading,
                              onChanged: (value) {
                                setState(() => title = value);
                              },
                            ),
                            AxiTextFormField(
                              placeholder: const Text('Nickname'),
                              enabled: state.creationStatus == RequestStatus.loading,
                              onChanged: (value) {
                                setState(() => nickname = value);
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    // const SizedBox(height: 12),
                    // AxiTextFormField(
                    //   placeholder: const Text('Nickname (optional)'),
                    //   onChanged: (value) {
                    //     setState(() => title = value);
                    //   },
                    // ),

                    callback: title.isEmpty
                        ? null
                        : () => context
                            .read<ChatsCubit>()
                            .createChatRoom(title: title, nickname: nickname),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
