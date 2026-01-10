// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

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
    final l10n = context.l10n;
    return AxiDialogFab(
      tooltip: l10n.chatsCreateGroupChatTooltip,
      iconData: LucideIcons.userPlus,
      label: l10n.chatsRoomLabel,
      dialogBuilder: (context) => const _ChatRoomCreateDialog(),
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
  static const _dialogMaxHeightRatio = 0.8;

  String _title = '';
  String? _validationError;

  void _handleTitleChanged(String value) {
    setState(() {
      _title = value;
      _validationError = null;
    });
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
    if (context.read<ChatsCubit>().state.creationStatus.isLoading) return;
    setState(() {
      _validationError = null;
    });
    context.read<ChatsCubit>().createChatRoom(
          title: trimmed,
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
        final canSubmit = _title.trim().isNotEmpty && !loading;
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
                      child: AxiTextFormField(
                        placeholder: Text(l10n.chatsRoomNamePlaceholder),
                        enabled: !loading,
                        onChanged: _handleTitleChanged,
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
  }
}
