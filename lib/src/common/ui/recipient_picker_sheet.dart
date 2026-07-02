// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/avatar/avatar_presentation.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/compose_recipient.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

typedef RecipientPickerChatFilter = bool Function(Chat chat, String? selfJid);
typedef RecipientPickerAddressFilter =
    bool Function(String address, String? selfJid);
typedef RecipientPickerResolver =
    FutureOr<Contact?> Function(
      BuildContext context,
      Contact target,
      String? selfJid,
    );
typedef RecipientPickerSubmit =
    FutureOr<void> Function(
      BuildContext context,
      List<ComposerRecipient> recipients,
    );

class RecipientPickerSheet extends StatefulWidget {
  const RecipientPickerSheet({
    super.key,
    required this.title,
    required this.primaryLabel,
    required this.onClose,
    required this.onSubmit,
    this.primaryIconData,
    this.initialRecipients = const <ComposerRecipient>[],
    this.maxRecipients,
    this.loading = false,
    this.errorText,
    this.chatFilter,
    this.databaseSuggestionFilter,
    this.resolveRecipient,
    this.recipientKeyBuilder,
    this.recipientAddError,
    this.canSubmit,
  });

  final Widget title;
  final String primaryLabel;
  final IconData? primaryIconData;
  final VoidCallback onClose;
  final RecipientPickerSubmit onSubmit;
  final List<ComposerRecipient> initialRecipients;
  final int? maxRecipients;
  final bool loading;
  final String? errorText;
  final RecipientPickerChatFilter? chatFilter;
  final RecipientPickerAddressFilter? databaseSuggestionFilter;
  final RecipientPickerResolver? resolveRecipient;
  final ComposerRecipientKey Function(Contact target)? recipientKeyBuilder;
  final String? Function(Contact target)? recipientAddError;
  final bool Function(List<ComposerRecipient> recipients)? canSubmit;

  @override
  State<RecipientPickerSheet> createState() => _RecipientPickerSheetState();
}

class _RecipientPickerSheetState extends State<RecipientPickerSheet> {
  late List<ComposerRecipient> _recipients;
  final Object _recipientTextInputTapRegionGroup = Object();

  @override
  void initState() {
    super.initState();
    _recipients = List<ComposerRecipient>.from(widget.initialRecipients);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final rosterItems =
        context.watch<RosterCubit>().state.items ??
        (context.watch<RosterCubit>()[RosterCubit.itemsCacheKey]
            as List<RosterItem>?) ??
        const <RosterItem>[];
    final chatsState = context.watch<ChatsCubit>().state;
    final selfJid = context.watch<ChatsCubit>().selfJid;
    final availableChats = widget.chatFilter == null
        ? chatsState.items ?? const <Chat>[]
        : (chatsState.items ?? const <Chat>[])
              .where((chat) => widget.chatFilter!(chat, selfJid))
              .toList(growable: false);
    final suggestions = widget.databaseSuggestionFilter == null
        ? chatsState.recipientAddressSuggestions
        : chatsState.recipientAddressSuggestions
              .where((address) {
                return widget.databaseSuggestionFilter!(address, selfJid);
              })
              .toList(growable: false);
    final profile = context.watch<ProfileCubit>().state;
    final profileJid = profile.jid.trim();
    final selfIdentity = SelfAvatar(
      jid: profileJid.isEmpty ? null : profileJid,
      avatar: Avatar.tryParseOrNull(path: profile.avatarPath, hash: null),
      hydrating: profile.avatarHydrating,
    );
    final submitEnabled =
        !widget.loading &&
        _recipients.isNotEmpty &&
        (widget.canSubmit?.call(_recipients) ?? true);
    final primaryIconData = widget.primaryIconData;

    return AxiSheetScaffold.sections(
      header: AxiSheetHeader(title: widget.title, onClose: widget.onClose),
      footer: AxiSheetActions(
        children: [
          AxiButton.outline(
            onPressed: widget.loading
                ? null
                : () => closeSheetWithKeyboardDismiss(context, widget.onClose),
            child: Text(l10n.commonCancel),
          ),
          SizedBox(width: spacing.s),
          AxiButton.primary(
            loading: widget.loading,
            onPressed: submitEnabled
                ? () => widget.onSubmit(
                    context,
                    List<ComposerRecipient>.unmodifiable(_recipients),
                  )
                : null,
            leading: primaryIconData == null
                ? null
                : Icon(
                    primaryIconData,
                    size: context.sizing.iconButtonIconSize,
                  ),
            child: Text(widget.primaryLabel),
          ),
        ],
      ),
      sections: [
        AxiSheetSection.edge(
          child: AbsorbPointer(
            absorbing: widget.loading,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RecipientChipsBar(
                  recipients: _recipients,
                  availableChats: availableChats,
                  rosterItems: rosterItems,
                  databaseSuggestionAddresses: suggestions,
                  selfJid: selfJid,
                  selfIdentity: selfIdentity,
                  latestStatuses: const {},
                  onRecipientAdded: _handleRecipientAdded,
                  onRecipientRemoved: _removeRecipient,
                  collapsedByDefault: false,
                  horizontalPadding: EdgeInsets.zero.horizontal,
                  tapRegionGroup: _recipientTextInputTapRegionGroup,
                  recipientAddError: widget.recipientAddError,
                ),
                if (widget.errorText != null) ...[
                  SizedBox(height: spacing.s),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: spacing.m),
                    child: AxiErrorText(widget.errorText!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> _handleRecipientAdded(Contact target) async {
    Contact? resolved = target;
    final resolveRecipient = widget.resolveRecipient;
    if (resolveRecipient != null) {
      resolved = await resolveRecipient(
        context,
        target,
        context.read<ChatsCubit>().selfJid,
      );
    }
    if (!mounted || resolved == null) {
      return false;
    }
    final recipientTarget = resolved;
    final candidate = ComposerRecipient(
      target: recipientTarget,
      recipientKey: widget.recipientKeyBuilder?.call(recipientTarget),
    );
    setState(() {
      final maxRecipients = widget.maxRecipients;
      if (maxRecipients == 1) {
        _recipients = <ComposerRecipient>[candidate];
        return;
      }
      final existingIndex = _recipients.indexWhere(
        (recipient) => recipient.key == candidate.key,
      );
      if (existingIndex >= 0) {
        _recipients[existingIndex] = _recipients[existingIndex].copyWith(
          target: recipientTarget,
          included: true,
        );
        return;
      }
      if (maxRecipients != null && _recipients.length >= maxRecipients) {
        _recipients = <ComposerRecipient>[
          ..._recipients.skip(_recipients.length - maxRecipients + 1),
          candidate,
        ];
        return;
      }
      _recipients = <ComposerRecipient>[..._recipients, candidate];
    });
    return true;
  }

  void _removeRecipient(String key) {
    setState(() {
      _recipients = _recipients
          .where((recipient) => recipient.key != key)
          .toList(growable: false);
    });
  }
}
