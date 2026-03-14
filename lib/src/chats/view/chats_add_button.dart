// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/avatar/avatar_editor_state_extensions.dart';
import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/avatar/bloc/avatar_editor_cubit.dart';
import 'package:axichat/src/avatar/view/avatar_error_l10n.dart';
import 'package:axichat/src/avatar/view/widgets/signup_avatar_editor_panel.dart';
import 'package:axichat/src/avatar/view/widgets/signup_avatar_selector.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum _RoomCreateType {
  chat,
  calendar;

  ChatPrimaryView get primaryView => switch (this) {
    _RoomCreateType.chat => ChatPrimaryView.chat,
    _RoomCreateType.calendar => ChatPrimaryView.calendar,
  };

  IconData get iconData => switch (this) {
    _RoomCreateType.chat => LucideIcons.messagesSquare,
    _RoomCreateType.calendar => LucideIcons.calendarClock,
  };
}

class ChatsAddButton extends StatelessWidget {
  const ChatsAddButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AxiDialogFab(
      tooltip: l10n.chatsCreateGroupChatTooltip,
      iconData: LucideIcons.userPlus,
      label: l10n.chatsRoomLabel,
      barrierDismissible: false,
      dialogBuilder: (context) {
        final colors = context.colorScheme;
        return BlocProvider(
          create: (_) =>
              AvatarEditorCubit(
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

  String _title = '';
  String? _validationError;
  bool _showAvatarEditor = false;
  _RoomCreateType _roomType = _RoomCreateType.chat;

  void _handleTitleChanged(String value) {
    setState(() {
      _title = value;
      _validationError = null;
    });
  }

  void _openAvatarEditor() {
    setState(() {
      _showAvatarEditor = true;
    });
  }

  void _closeAvatarEditor() {
    setState(() {
      _showAvatarEditor = false;
    });
    final colors = context.colorScheme;
    final hasSelection = context
        .read<AvatarEditorCubit>()
        .state
        .hasUserSelectedAvatar;
    context.read<AvatarEditorCubit>().setCarouselEnabled(!hasSelection, colors);
  }

  Future<void> _submit() async {
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
    context.read<AvatarEditorCubit>().pauseCarousel();
    final avatarPayload = await context
        .read<AvatarEditorCubit>()
        .buildSelectedAvatarPayload();
    if (!mounted) return;
    context.read<ChatsCubit>().createChatRoom(
      title: trimmed,
      avatar: avatarPayload,
      primaryView: _roomType.primaryView,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final locate = context.read;
    final fieldPadding = EdgeInsets.all(spacing.s);
    final errorPadding = EdgeInsets.only(
      left: spacing.s,
      right: spacing.s,
      bottom: spacing.s,
    );
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
            final animationDuration = context
                .watch<SettingsCubit>()
                .animationDuration;
            final avatarErrorText = avatarState.errorType?.resolve(l10n);
            final canSubmit =
                _title.trim().isNotEmpty && !avatarState.isBusy && !loading;
            final useActionEnabled = avatarState.canUseCarouselAvatar;
            final selectorBytes = _showAvatarEditor
                ? avatarState.displayedBytes
                : avatarState.draftAvatar?.bytes;
            final previewWidth = math.min(
              MediaQuery.sizeOf(context).width,
              sizing.dialogMaxWidth,
            );
            final dialogMaxHeight =
                MediaQuery.sizeOf(context).height *
                sizing.dialogMaxHeightFraction;
            return AxiInputDialog(
              title: Text(l10n.chatsCreateChatRoomTitle),
              canPop: !loading,
              showCloseButton: !loading,
              maxWidth: sizing.dialogMaxWidth,
              content: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: dialogMaxHeight),
                child: SingleChildScrollView(
                  child: Column(
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
                                bytes: selectorBytes,
                                username: _title,
                                processing: avatarState.isBusy,
                                animationDuration: animationDuration,
                                onTap: _openAvatarEditor,
                              ),
                            ),
                            SizedBox(width: spacing.s),
                            Expanded(
                              child: AxiTextFormField(
                                placeholder: Text(
                                  l10n.chatsRoomNamePlaceholder,
                                ),
                                enabled: !loading,
                                onChanged: _handleTitleChanged,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          spacing.s,
                          0,
                          spacing.s,
                          spacing.s,
                        ),
                        child: _RoomCreateTypeSelector(
                          value: _roomType,
                          enabled: !loading,
                          onChanged: (value) {
                            setState(() {
                              _roomType = value;
                            });
                          },
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
                      if (_validationError != null)
                        Padding(
                          padding: errorPadding,
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
                          padding: EdgeInsets.only(top: spacing.s),
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
                                      animationDuration: animationDuration,
                                      cropBytes:
                                          avatarState.draftAvatar?.sourceBytes,
                                      cropRect:
                                          avatarState.draftAvatar?.cropRect,
                                      imageWidth: avatarState
                                          .draftAvatar
                                          ?.sourceWidth
                                          ?.toDouble(),
                                      imageHeight: avatarState
                                          .draftAvatar
                                          ?.sourceHeight
                                          ?.toDouble(),
                                      onCropChanged: (rect) => context
                                          .read<AvatarEditorCubit>()
                                          .updateCropRect(rect),
                                      onCropReset: () => context
                                          .read<AvatarEditorCubit>()
                                          .resetCrop(),
                                      onCropCommitted: (rect) => context
                                          .read<AvatarEditorCubit>()
                                          .commitCrop(rect),
                                      onShuffle: () => context
                                          .read<AvatarEditorCubit>()
                                          .pauseOnPreviewAvatar(
                                            context.colorScheme,
                                          ),
                                      onUpload: () => context
                                          .read<AvatarEditorCubit>()
                                          .pickImage(),
                                      onUseCurrent: () => context
                                          .read<AvatarEditorCubit>()
                                          .selectCarouselAvatar(),
                                      useActionEnabled: useActionEnabled,
                                      hasUserSelectedAvatar:
                                          avatarState.hasUserSelectedAvatar,
                                      canShuffleBackground:
                                          avatarState.canShuffleBackground,
                                      onShuffleBackground:
                                          avatarState.canShuffleBackground
                                          ? () => locate<AvatarEditorCubit>()
                                                .shuffleBackground(
                                                  context.colorScheme,
                                                )
                                          : null,
                                      descriptionText:
                                          l10n.mucAvatarMenuDescription,
                                    ),
                                  ),
                                  Positioned(
                                    top: spacing.xs,
                                    right: spacing.xs,
                                    child: AxiIconButton(
                                      iconData: LucideIcons.x,
                                      tooltip: l10n.commonClose,
                                      onPressed: loading
                                          ? null
                                          : _closeAvatarEditor,
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

class _RoomCreateTypeSelector extends StatelessWidget {
  const _RoomCreateTypeSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final _RoomCreateType value;
  final bool enabled;
  final ValueChanged<_RoomCreateType> onChanged;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RoomCreateTypeOption(
          value: _RoomCreateType.chat,
          selected: value == _RoomCreateType.chat,
          onPressed: enabled ? () => onChanged(_RoomCreateType.chat) : null,
        ),
        SizedBox(height: spacing.s),
        _RoomCreateTypeOption(
          value: _RoomCreateType.calendar,
          selected: value == _RoomCreateType.calendar,
          onPressed: enabled ? () => onChanged(_RoomCreateType.calendar) : null,
        ),
      ],
    );
  }
}

class _RoomCreateTypeOption extends StatelessWidget {
  const _RoomCreateTypeOption({
    required this.value,
    required this.selected,
    this.onPressed,
  });

  final _RoomCreateType value;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final title = switch (value) {
      _RoomCreateType.chat => l10n.chatsCreateRoomTypeChatTitle,
      _RoomCreateType.calendar => l10n.chatsCreateRoomTypeCalendarTitle,
    };
    final description = switch (value) {
      _RoomCreateType.chat => l10n.chatsCreateRoomTypeChatDescription,
      _RoomCreateType.calendar => l10n.chatsCreateRoomTypeCalendarDescription,
    };

    return AxiListButton(
      variant: AxiButtonVariant.outline,
      selected: selected,
      onPressed: onPressed,
      leading: DecoratedBox(
        decoration: ShapeDecoration(
          color: selected
              ? colors.primary.withValues(alpha: context.motion.tapSplashAlpha)
              : colors.secondary.withValues(
                  alpha: context.motion.tapHoverAlpha,
                ),
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(context.radii.squircle),
            side: BorderSide(
              color: selected ? colors.primary : context.borderSide.color,
              width: context.borderSide.width,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(spacing.s),
          child: Icon(
            value.iconData,
            size: sizing.menuItemIconSize,
            color: selected ? colors.primary : colors.secondaryForeground,
          ),
        ),
      ),
      trailing: Padding(
        padding: EdgeInsets.only(top: spacing.xxs),
        child: Icon(
          selected
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_off_rounded,
          size: sizing.menuItemIconSize,
          color: selected ? colors.primary : colors.mutedForeground,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: context.textTheme.small),
          SizedBox(height: spacing.xxs),
          Text(
            description,
            style: context.textTheme.muted.copyWith(
              color: colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
