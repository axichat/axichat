// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/app.dart';
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
    final l10n = context.l10n;
    return AxiDialogFab(
      tooltip: l10n.chatsCreateGroupChatTooltip,
      iconData: LucideIcons.userPlus,
      label: l10n.chatsRoomLabel,
      dialogBuilder: (context) {
        final colors = context.colorScheme;
        return BlocProvider(
          create: (_) => AvatarEditorCubit(
            xmppService: context.read<XmppService>(),
            templates: buildDefaultAvatarTemplates(),
          )
            ..initialize(colors)
            ..setCarouselEnabled(true, colors),
          child: const _ChatRoomCreateDialog(),
        );
      },
    );
  }
}

class _ChatRoomCreateDialog extends StatefulWidget {
  const _ChatRoomCreateDialog();

  @override
  State<_ChatRoomCreateDialog> createState() => _ChatRoomCreateDialogState();
}

class _ChatRoomCreateDialogState extends State<_ChatRoomCreateDialog> {
  static const _restrictedRoomNameCharacter = '+';
  static const _fieldPadding = EdgeInsets.all(8.0);
  static const _errorPadding = EdgeInsets.fromLTRB(8, 0, 8, 8);
  static const _avatarRowSpacing = 12.0;
  static const _avatarEditorTopPadding = 12.0;
  static const _avatarEditorMaxWidth = 960.0;
  static const _avatarEditorCloseInset = 6.0;
  static const _dialogMaxHeightRatio = 0.8;

  String _title = '';
  String? _validationError;
  bool _showAvatarEditor = false;

  void _handleTitleChanged(String value) {
    setState(() {
      _title = value;
      _validationError = null;
    });
  }

  void _openAvatarEditor() {
    final colors = context.colorScheme;
    context.read<AvatarEditorCubit>().setCarouselEnabled(false, colors);
    setState(() {
      _showAvatarEditor = true;
    });
  }

  void _closeAvatarEditor() {
    setState(() {
      _showAvatarEditor = false;
    });
    final colors = context.colorScheme;
    final hasSelection =
        context.read<AvatarEditorCubit>().state.hasUserSelectedAvatar;
    context.read<AvatarEditorCubit>().setCarouselEnabled(
          !hasSelection,
          colors,
        );
  }

  void _submit() {
    final l10n = context.l10n;
    final trimmed = _title.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _validationError = l10n.chatsRoomNameRequiredError;
      });
      return;
    }
    if (trimmed.contains(_restrictedRoomNameCharacter)) {
      setState(() {
        _validationError = l10n.chatsRoomNameInvalidCharacterError(
          _restrictedRoomNameCharacter,
        );
      });
      return;
    }
    if (context.read<AvatarEditorCubit>().state.isBusy) {
      return;
    }
    setState(() {
      _validationError = null;
    });
    context.read<ChatsCubit>().createChatRoom(
          title: trimmed,
          avatar: context.read<AvatarEditorCubit>().state.draft,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<ChatsCubit, ChatsState>(
      listener: (context, state) {
        if (state.creationStatus.isSuccess) {
          context.pop();
          context.read<ChatsCubit>().clearCreationStatus();
        }
      },
      builder: (context, state) {
        final loading = state.creationStatus.isLoading;
        return BlocBuilder<AvatarEditorCubit, AvatarEditorState>(
          builder: (context, avatarState) {
            final avatarErrorText = avatarState.localizedErrorText(l10n);
            final canSubmit =
                _title.trim().isNotEmpty && !avatarState.isBusy && !loading;
            final previewWidth = math.min(
              MediaQuery.sizeOf(context).width,
              _avatarEditorMaxWidth,
            );
            final dialogMaxHeight =
                MediaQuery.sizeOf(context).height * _dialogMaxHeightRatio;
            final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
            return AxiInputDialog(
              title: Text(l10n.chatsCreateChatRoomTitle),
              content: Padding(
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
                          padding: _fieldPadding,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              AbsorbPointer(
                                absorbing: loading,
                                child: SignupAvatarSelector(
                                  bytes: avatarState.displayedBytes,
                                  username: _title,
                                  processing: avatarState.isBusy,
                                  onTap: _openAvatarEditor,
                                ),
                              ),
                              const SizedBox(width: _avatarRowSpacing),
                              Expanded(
                                child: AxiTextFormField(
                                  placeholder:
                                      Text(l10n.chatsRoomNamePlaceholder),
                                  enabled: !loading,
                                  onChanged: _handleTitleChanged,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (avatarErrorText != null)
                          Padding(
                            padding: _errorPadding,
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
                        if (_validationError != null)
                          Padding(
                            padding: _errorPadding,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _validationError!,
                                style: context.textTheme.small.copyWith(
                                  color: context.colorScheme.destructive,
                                ),
                              ),
                            ),
                          ),
                        if (_showAvatarEditor)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: _avatarEditorTopPadding,
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
                                        avatarBytes: avatarState.displayedBytes,
                                        cropBytes: avatarState.sourceBytes,
                                        cropRect: avatarState.cropRect,
                                        imageWidth:
                                            avatarState.imageWidth?.toDouble(),
                                        imageHeight:
                                            avatarState.imageHeight?.toDouble(),
                                        onCropChanged: (rect) => context
                                            .read<AvatarEditorCubit>()
                                            .updateCropRect(rect),
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
                                            avatarState.canShuffleBackground,
                                        onShuffleBackground:
                                            avatarState.canShuffleBackground
                                                ? () => context
                                                    .read<AvatarEditorCubit>()
                                                    .shuffleBackground(
                                                      context.colorScheme,
                                                    )
                                                : null,
                                        descriptionText:
                                            l10n.mucAvatarMenuDescription,
                                      ),
                                    ),
                                    Positioned(
                                      top: _avatarEditorCloseInset,
                                      right: _avatarEditorCloseInset,
                                      child: AxiIconButton(
                                        iconData: LucideIcons.x,
                                        tooltip: l10n.commonClose,
                                        onPressed: _closeAvatarEditor,
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
              ),
              callbackText: l10n.chatsCreateChatRoomAction,
              loading: loading,
              callback: canSubmit ? _submit : null,
            );
          },
        );
      },
    );
  }
}
