// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/avatar/avatar_editor_state_extensions.dart';
import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/avatar/bloc/avatar_editor_cubit.dart';
import 'package:axichat/src/avatar/view/widgets/signup_avatar_editor_panel.dart';
import 'package:axichat/src/avatar/view/widgets/signup_avatar_selector.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
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
    const restrictedRoomNameCharacter = '+';
    final createLabel = l10n.chatsCreateChatRoomAction;
    final emptyTitleValidationMessage = l10n.chatsRoomNameRequiredError;
    final invalidCharacterValidationMessage =
        l10n.chatsRoomNameInvalidCharacterError(
      restrictedRoomNameCharacter,
    );
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
              create: (context) {
                final colors = ShadTheme.of(context, listen: false).colorScheme;
                return AvatarEditorCubit(
                  xmppService: locate<XmppService>(),
                  templates: buildDefaultAvatarTemplates(),
                )
                  ..initialize(colors)
                  ..seedRandomTemplate(colors);
              },
            ),
          ],
          child: BlocBuilder<AvatarEditorCubit, AvatarEditorState>(
            builder: (context, avatarState) {
              return StatefulBuilder(
                builder: (context, setState) {
                  const fieldPadding = EdgeInsets.all(8.0);
                  const errorPadding = EdgeInsets.fromLTRB(8, 0, 8, 8);
                  const avatarRowSpacing = 12.0;
                  const avatarEditorTopPadding = 12.0;
                  const avatarEditorMaxWidth = 960.0;
                  const avatarEditorCloseInset = 6.0;
                  const dialogMaxHeightRatio = 0.8;
                  final avatarErrorText = avatarState.error;
                  final canSubmit = title.isNotEmpty &&
                      !avatarState.isBusy &&
                      avatarState.draft != null;
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
                        final dialogMaxHeight =
                            MediaQuery.sizeOf(context).height *
                                dialogMaxHeightRatio;
                        final keyboardInset =
                            MediaQuery.viewInsetsOf(context).bottom;
                        return Padding(
                          padding: EdgeInsets.only(bottom: keyboardInset),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: dialogMaxHeight,
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: fieldPadding,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        AbsorbPointer(
                                          absorbing: loading,
                                          child: SignupAvatarSelector(
                                            bytes: avatarState.displayedBytes,
                                            username: title,
                                            processing: avatarState.isBusy,
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
                                            placeholder: Text(
                                              l10n.chatsRoomNamePlaceholder,
                                            ),
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
                                          style:
                                              context.textTheme.small.copyWith(
                                            color:
                                                context.colorScheme.destructive,
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
                                          style:
                                              context.textTheme.small.copyWith(
                                            color:
                                                context.colorScheme.destructive,
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
                                                  avatarBytes: avatarState
                                                      .displayedBytes,
                                                  cropBytes:
                                                      avatarState.sourceBytes,
                                                  cropRect:
                                                      avatarState.cropRect,
                                                  imageWidth: avatarState
                                                      .imageWidth
                                                      ?.toDouble(),
                                                  imageHeight: avatarState
                                                      .imageHeight
                                                      ?.toDouble(),
                                                  onCropChanged: (rect) => context
                                                      .read<AvatarEditorCubit>()
                                                      .updateCropRect(
                                                        rect,
                                                      ),
                                                  onCropReset: () => context
                                                      .read<AvatarEditorCubit>()
                                                      .resetCrop(),
                                                  onShuffle: () => context
                                                      .read<AvatarEditorCubit>()
                                                      .shuffleTemplate(
                                                        context.colorScheme,
                                                      ),
                                                  onUpload: () => context
                                                      .read<AvatarEditorCubit>()
                                                      .pickImage(),
                                                  canShuffleBackground:
                                                      avatarState
                                                          .canShuffleBackground,
                                                  onShuffleBackground: avatarState
                                                          .canShuffleBackground
                                                      ? () => context
                                                          .read<
                                                              AvatarEditorCubit>()
                                                          .shuffleBackground(
                                                            context.colorScheme,
                                                          )
                                                      : null,
                                                  descriptionText: l10n
                                                      .mucAvatarMenuDescription,
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
                              ),
                            ),
                          ),
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
                            if (trimmed.contains(restrictedRoomNameCharacter)) {
                              setState(() => validationError =
                                  invalidCharacterValidationMessage);
                              return;
                            }
                            if (context
                                .read<AvatarEditorCubit>()
                                .state
                                .isBusy) {
                              return;
                            }
                            setState(() => validationError = null);
                            context.read<ChatsCubit>().createChatRoom(
                                  title: trimmed,
                                  avatar: context
                                      .read<AvatarEditorCubit>()
                                      .state
                                      .draft,
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
