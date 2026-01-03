// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/avatar/bloc/signup_avatar_cubit.dart';
import 'package:axichat/src/avatar/view/signup_avatar_error_text.dart';
import 'package:axichat/src/avatar/view/widgets/signup_avatar_editor_panel.dart';
import 'package:axichat/src/avatar/view/widgets/signup_avatar_selector.dart';
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
        var showAvatarEditor = false;
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(
              value: locate<ChatsCubit>(),
            ),
            BlocProvider.value(
              value: locate<AuthenticationCubit>(),
            ),
            BlocProvider(
              create: (context) =>
                  SignupAvatarCubit()..setVisible(true, context.colorScheme),
            ),
          ],
          child: BlocBuilder<SignupAvatarCubit, SignupAvatarState>(
            builder: (context, avatarState) {
              return StatefulBuilder(
                builder: (context, setState) {
                  const fieldPadding = EdgeInsets.all(8.0);
                  const errorPadding = EdgeInsets.fromLTRB(8, 0, 8, 8);
                  const avatarRowSpacing = 12.0;
                  const avatarEditorTopPadding = 12.0;
                  const avatarEditorMaxWidth = 960.0;
                  const avatarEditorCloseInset = 6.0;
                  final avatarErrorText = signupAvatarErrorText(
                    avatarState: avatarState,
                    l10n: l10n,
                  );
                  final canSubmit = title.isNotEmpty && !avatarState.processing;
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
                        final previewWidth = math.min(
                          MediaQuery.sizeOf(context).width,
                          avatarEditorMaxWidth,
                        );
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: fieldPadding,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  AbsorbPointer(
                                    absorbing: loading,
                                    child: SignupAvatarSelector(
                                      bytes: avatarState.displayedBytes,
                                      username: title,
                                      processing: avatarState.processing,
                                      onTap: () {
                                        setState(() {
                                          showAvatarEditor = true;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: avatarRowSpacing),
                                  Expanded(
                                    child: AxiTextFormField(
                                      placeholder:
                                          Text(l10n.chatsRoomNamePlaceholder),
                                      enabled: !loading,
                                      onChanged: (value) {
                                        setState(() {
                                          title = value;
                                          validationError = null;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (avatarErrorText != null)
                              Padding(
                                padding: errorPadding,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    avatarErrorText,
                                    style: context.textTheme.small.copyWith(
                                      color: context.colorScheme.destructive,
                                    ),
                                  ),
                                ),
                              ),
                            if (validationError != null)
                              Padding(
                                padding: errorPadding,
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
                            if (showAvatarEditor)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: avatarEditorTopPadding,
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: previewWidth,
                                    ),
                                    child: Stack(
                                      children: [
                                        AbsorbPointer(
                                          absorbing: loading,
                                          child: SignupAvatarEditorPanel(
                                            mode: avatarState.editorMode,
                                            avatarBytes:
                                                avatarState.displayedBytes,
                                            cropBytes: avatarState.sourceBytes,
                                            cropRect: avatarState.cropRect,
                                            imageWidth: avatarState.imageWidth,
                                            imageHeight:
                                                avatarState.imageHeight,
                                            onCropChanged: (rect) => context
                                                .read<SignupAvatarCubit>()
                                                .updateCropRect(rect),
                                            onCropReset: context
                                                .read<SignupAvatarCubit>()
                                                .resetCrop,
                                            onShuffle: () => context
                                                .read<SignupAvatarCubit>()
                                                .shuffleTemplate(
                                                  context.colorScheme,
                                                ),
                                            onUpload: context
                                                .read<SignupAvatarCubit>()
                                                .pickAvatarFromFiles,
                                            canShuffleBackground: avatarState
                                                .canShuffleBackground,
                                            onShuffleBackground: avatarState
                                                    .canShuffleBackground
                                                ? () => context
                                                    .read<SignupAvatarCubit>()
                                                    .shuffleBackground(
                                                      context.colorScheme,
                                                    )
                                                : null,
                                          ),
                                        ),
                                        Positioned(
                                          top: avatarEditorCloseInset,
                                          right: avatarEditorCloseInset,
                                          child: AxiIconButton(
                                            iconData: LucideIcons.x,
                                            tooltip: l10n.commonClose,
                                            onPressed: () {
                                              setState(() {
                                                showAvatarEditor = false;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    callbackText: createLabel,
                    loading: context
                        .watch<ChatsCubit>()
                        .state
                        .creationStatus
                        .isLoading,
                    callback: !canSubmit
                        ? null
                        : () {
                            final trimmed = title.trim();
                            if (trimmed.isEmpty) {
                              setState(() => validationError =
                                  emptyTitleValidationMessage);
                              return;
                            }
                            if (trimmed.contains('+')) {
                              setState(() => validationError =
                                  invalidCharacterValidationMessage);
                              return;
                            }
                            final avatarCubit =
                                context.read<SignupAvatarCubit>();
                            if (avatarCubit.state.processing) return;
                            if (avatarCubit.state.avatar == null) {
                              avatarCubit.materializeCurrentCarouselAvatar();
                            }
                            setState(() => validationError = null);
                            context.read<ChatsCubit>().createChatRoom(
                                  title: trimmed,
                                  avatar: avatarCubit.state.avatar,
                                );
                          },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
