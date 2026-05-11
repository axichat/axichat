// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/contacts/bloc/contacts_cubit.dart';
import 'package:axichat/src/folders/bloc/folders_cubit.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<void> showAddToFolderSheet(
  BuildContext context, {
  required Message message,
  required Chat chat,
}) {
  final locate = context.read;
  final shadTheme = ShadTheme.of(context);
  return showAdaptiveBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    showCloseButton: false,
    builder: (_) => ShadTheme(
      data: shadTheme,
      child: BlocProvider.value(
        value: locate<FoldersCubit>(),
        child: BlocProvider.value(
          value: locate<ChatBloc>(),
          child: _AddToFolderSheet(message: message, chat: chat),
        ),
      ),
    ),
  );
}

Future<void> showContactFolderRuleSheet(
  BuildContext context, {
  required ContactDirectoryEntry contact,
}) {
  final locate = context.read;
  final shadTheme = ShadTheme.of(context);
  return showAdaptiveBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    showCloseButton: false,
    builder: (_) => ShadTheme(
      data: shadTheme,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: locate<FoldersCubit>()),
          BlocProvider.value(value: locate<ContactsCubit>()),
        ],
        child: _ContactFolderRuleSheet(contact: contact),
      ),
    ),
  );
}

Future<MessageCollectionEntry?> showFolderCreateDialog(BuildContext context) {
  final locate = context.read;
  return showFadeScaleDialog<MessageCollectionEntry>(
    context: context,
    useRootNavigator: true,
    builder: (_) => BlocProvider.value(
      value: locate<FoldersCubit>(),
      child: const _FolderCreateDialog(),
    ),
  );
}

class _AddToFolderSheet extends StatefulWidget {
  const _AddToFolderSheet({required this.message, required this.chat});

  final Message message;
  final Chat chat;

  @override
  State<_AddToFolderSheet> createState() => _AddToFolderSheetState();
}

class _AddToFolderSheetState extends State<_AddToFolderSheet> {
  void _setMembership(MessageCollectionEntry collection, bool active) {
    context.read<ChatBloc>().add(
      ChatMessageCollectionMembershipChanged(
        message: widget.message,
        collectionId: collection.id,
        chat: widget.chat,
        active: active,
      ),
    );
  }

  Future<void> _createFolder() async {
    final collection = await showFolderCreateDialog(context);
    if (!mounted || collection == null) {
      return;
    }
    _setMembership(collection, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reference = widget.message.collectionReference(
      isGroupChat: widget.chat.type == ChatType.groupChat,
    );
    return BlocListener<ChatBloc, ChatState>(
      listenWhen: (previous, current) =>
          previous.collectionActionState != current.collectionActionState,
      listener: (context, state) {
        final actionState = state.collectionActionState;
        if (actionState is! ChatCollectionActionFailure ||
            actionState.messageReferenceId != reference?.value) {
          return;
        }
        ShadToaster.maybeOf(
          context,
        )?.show(FeedbackToast.error(message: l10n.folderPickerUpdateFailed));
      },
      child: AxiSheetScaffold.scroll(
        header: AxiSheetHeader(
          title: Text(l10n.folderPickerTitle),
          onClose: () => Navigator.of(context).maybePop(),
        ),
        footer: BlocBuilder<ChatBloc, ChatState>(
          buildWhen: (previous, current) =>
              previous.collectionActionState != current.collectionActionState,
          builder: (context, chatState) {
            return AxiButton.outline(
              onPressed:
                  chatState.collectionActionState is ChatCollectionActionLoading
                  ? null
                  : () => unawaited(_createFolder()),
              width: context.sizing.dialogMaxWidth,
              widthBehavior: AxiButtonWidth.expand,
              child: Text(l10n.folderCreateTitle),
            );
          },
        ),
        children: [
          BlocBuilder<FoldersCubit, FoldersState>(
            builder: (context, foldersState) {
              final collections = foldersState.activeCollections;
              if (foldersState.collections == null ||
                  foldersState.memberships == null) {
                return Center(
                  child: AxiProgressIndicator(
                    color: context.colorScheme.foreground,
                  ),
                );
              }
              if (collections.isEmpty) {
                return Text(
                  l10n.folderPickerEmpty,
                  style: context.textTheme.muted,
                );
              }
              final activeCollectionIds = foldersState
                  .activeCollectionIdsForMessage(
                    chat: widget.chat,
                    message: widget.message,
                  );
              return BlocBuilder<ChatBloc, ChatState>(
                buildWhen: (previous, current) =>
                    previous.collectionActionState !=
                    current.collectionActionState,
                builder: (context, chatState) {
                  final actionState = chatState.collectionActionState;
                  return _FolderCollectionList(
                    collections: collections,
                    activeCollectionIds: activeCollectionIds,
                    loadingCollectionId:
                        actionState is ChatCollectionActionLoading &&
                            actionState.messageReferenceId == reference?.value
                        ? actionState.collectionId
                        : null,
                    onToggleFolder: _setMembership,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ContactFolderRuleSheet extends StatefulWidget {
  const _ContactFolderRuleSheet({required this.contact});

  final ContactDirectoryEntry contact;

  @override
  State<_ContactFolderRuleSheet> createState() =>
      _ContactFolderRuleSheetState();
}

class _ContactFolderRuleSheetState extends State<_ContactFolderRuleSheet> {
  int _handledFailureId = 0;

  void _setRule(MessageCollectionEntry collection, bool active) {
    final cubit = context.read<ContactsCubit>();
    if (active) {
      unawaited(
        cubit.setContactFolderRule(
          contact: widget.contact,
          collectionId: collection.id,
        ),
      );
      return;
    }
    unawaited(cubit.clearContactFolderRule(contact: widget.contact));
  }

  Future<void> _createFolder() async {
    final collection = await showFolderCreateDialog(context);
    if (!mounted || collection == null) {
      return;
    }
    _setRule(collection, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocListener<ContactsCubit, ContactsState>(
      listenWhen: (previous, current) =>
          previous.actionState != current.actionState,
      listener: (context, state) {
        final actionState = state.actionState;
        if (actionState is! ContactActionFailure ||
            actionState.address != widget.contact.address ||
            (actionState.action != ContactActionType.setFolderRule &&
                actionState.action != ContactActionType.clearFolderRule) ||
            _handledFailureId == state.actionId) {
          return;
        }
        _handledFailureId = state.actionId;
        ShadToaster.maybeOf(
          context,
        )?.show(FeedbackToast.error(message: l10n.contactFolderRuleFailed));
      },
      child: AxiSheetScaffold.scroll(
        header: AxiSheetHeader(
          title: Text(_contactFolderRuleTitle(l10n, widget.contact)),
          subtitle: Text(widget.contact.displayName),
          onClose: () => Navigator.of(context).maybePop(),
        ),
        footer: BlocBuilder<ContactsCubit, ContactsState>(
          buildWhen: (previous, current) =>
              previous.actionState != current.actionState,
          builder: (context, contactsState) {
            final actionState = contactsState.actionState;
            final loading =
                actionState is ContactActionLoading &&
                actionState.address == widget.contact.address &&
                (actionState.action == ContactActionType.setFolderRule ||
                    actionState.action == ContactActionType.clearFolderRule);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AxiButton.outline(
                  onPressed: loading ? null : () => unawaited(_createFolder()),
                  width: context.sizing.dialogMaxWidth,
                  widthBehavior: AxiButtonWidth.expand,
                  child: Text(l10n.folderCreateTitle),
                ),
                SizedBox(height: context.spacing.s),
                AxiButton.ghost(
                  onPressed: loading
                      ? null
                      : () => unawaited(
                          context.read<ContactsCubit>().clearContactFolderRule(
                            contact: widget.contact,
                          ),
                        ),
                  width: context.sizing.dialogMaxWidth,
                  widthBehavior: AxiButtonWidth.expand,
                  child: Text(l10n.contactFolderRuleClear),
                ),
              ],
            );
          },
        ),
        children: [
          BlocBuilder<FoldersCubit, FoldersState>(
            builder: (context, foldersState) {
              final collections = foldersState.activeCollections;
              if (foldersState.collections == null) {
                return Center(
                  child: AxiProgressIndicator(
                    color: context.colorScheme.foreground,
                  ),
                );
              }
              if (collections.isEmpty) {
                return Text(
                  l10n.folderPickerEmpty,
                  style: context.textTheme.muted,
                );
              }
              return BlocBuilder<ContactsCubit, ContactsState>(
                buildWhen: (previous, current) =>
                    previous.actionState != current.actionState ||
                    previous.items != current.items,
                builder: (context, contactsState) {
                  final actionState = contactsState.actionState;
                  final currentContact = contactsState.items?.firstWhere(
                    (item) => item.address == widget.contact.address,
                    orElse: () => widget.contact,
                  );
                  final activeCollectionId = currentContact?.folderCollectionId
                      ?.trim();
                  return _FolderCollectionList(
                    collections: collections,
                    activeCollectionIds: <String>{
                      if (activeCollectionId != null &&
                          activeCollectionId.isNotEmpty)
                        activeCollectionId,
                    },
                    loadingCollectionId:
                        actionState is ContactActionLoading &&
                            actionState.address == widget.contact.address &&
                            actionState.action ==
                                ContactActionType.setFolderRule
                        ? actionState.collectionId
                        : null,
                    singleSelect: true,
                    onToggleFolder: _setRule,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FolderCollectionList extends StatelessWidget {
  const _FolderCollectionList({
    required this.collections,
    required this.activeCollectionIds,
    required this.onToggleFolder,
    this.loadingCollectionId,
    this.singleSelect = false,
  });

  final List<MessageCollectionEntry> collections;
  final Set<String> activeCollectionIds;
  final String? loadingCollectionId;
  final bool singleSelect;
  final void Function(MessageCollectionEntry collection, bool active)
  onToggleFolder;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final collection in collections) ...[
          _FolderCollectionButton(
            collection: collection,
            active: activeCollectionIds.contains(collection.id),
            loading: loadingCollectionId == collection.id,
            disabled: loadingCollectionId != null,
            singleSelect: singleSelect,
            onPressed: onToggleFolder,
          ),
          if (collection != collections.last)
            SizedBox(height: context.spacing.xs),
        ],
      ],
    );
  }
}

class _FolderCollectionButton extends StatelessWidget {
  const _FolderCollectionButton({
    required this.collection,
    required this.active,
    required this.loading,
    required this.disabled,
    required this.singleSelect,
    required this.onPressed,
  });

  final MessageCollectionEntry collection;
  final bool active;
  final bool loading;
  final bool disabled;
  final bool singleSelect;
  final void Function(MessageCollectionEntry collection, bool active) onPressed;

  @override
  Widget build(BuildContext context) {
    return AxiListButton(
      leading: Icon(_folderCollectionIconData(collection)),
      trailing: active ? const Icon(LucideIcons.check) : null,
      loading: loading,
      onPressed: disabled
          ? null
          : () => onPressed(collection, singleSelect ? true : !active),
      child: Text(
        _folderCollectionLabel(context, collection),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

String _folderCollectionLabel(
  BuildContext context,
  MessageCollectionEntry collection,
) {
  final systemCollection = collection.systemCollection;
  if (systemCollection != null) {
    return systemCollection.label(context.l10n);
  }
  return collection.id;
}

IconData _folderCollectionIconData(MessageCollectionEntry collection) {
  return switch (collection.systemCollection) {
    SystemMessageCollection.important => LucideIcons.star,
    SystemMessageCollection.receipts => LucideIcons.receiptText,
    SystemMessageCollection.marketing => LucideIcons.megaphone,
    SystemMessageCollection.newsletters => LucideIcons.newspaper,
    null => LucideIcons.folder,
  };
}

String _contactFolderRuleTitle(
  AppLocalizations l10n,
  ContactDirectoryEntry contact,
) {
  if (contact.hasXmppRoster && contact.hasEmailContact) {
    return l10n.contactFolderRuleMessagesAndEmailsTitle;
  }
  if (contact.hasEmailContact) {
    return l10n.contactFolderRuleEmailsTitle;
  }
  return l10n.contactFolderRuleMessagesTitle;
}

class _FolderCreateDialog extends StatefulWidget {
  const _FolderCreateDialog();

  @override
  State<_FolderCreateDialog> createState() => _FolderCreateDialogState();
}

class _FolderCreateDialogState extends State<_FolderCreateDialog> {
  final GlobalKey<ShadFormState> _formKey = GlobalKey<ShadFormState>();
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  var _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_handleChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleChanged() {
    final canSubmit = _controller.text.trim().isNotEmpty;
    final actionState = context.read<FoldersCubit>().state.actionState;
    if (canSubmit == _canSubmit && actionState is FoldersActionIdle) {
      return;
    }
    context.read<FoldersCubit>().clearActionState();
    setState(() {
      _canSubmit = canSubmit;
    });
  }

  String? _validateFolderName(
    String value,
    FoldersState state,
    AppLocalizations l10n,
  ) {
    final title = normalizeCustomMessageCollectionTitle(value);
    if (title == null) {
      return MessageCollectionNameFailure.empty.label(l10n);
    }
    final collectionId = normalizeCustomMessageCollectionId(title);
    if (collectionId == null) {
      return MessageCollectionNameFailure.empty.label(l10n);
    }
    if (SystemMessageCollection.isSystemId(collectionId)) {
      return MessageCollectionNameFailure.reserved.label(l10n);
    }
    final titleKey = title.toLowerCase();
    final collectionIdKey = collectionId.toLowerCase();
    for (final collection in state.customCollections) {
      if (collection.id.trim().toLowerCase() == collectionIdKey ||
          collection.displayTitle.trim().toLowerCase() == titleKey) {
        return MessageCollectionNameFailure.duplicate.label(l10n);
      }
    }
    final actionState = context.read<FoldersCubit>().state.actionState;
    if (actionState is FoldersActionFailure &&
        actionState.action == FoldersActionType.createFolder &&
        actionState.reason == FoldersFailureReason.invalidName) {
      return actionState.nameFailure?.label(l10n);
    }
    return null;
  }

  Future<void> _submit(FoldersState state) async {
    if (state.actionState is FoldersActionLoading) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      _focusNode.requestFocus();
      return;
    }
    final collection = await context.read<FoldersCubit>().createFolder(
      _controller.text,
    );
    if (mounted && collection != null) {
      Navigator.of(context).pop(collection);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FoldersCubit, FoldersState>(
      listenWhen: (previous, current) =>
          previous.actionState != current.actionState,
      listener: (context, state) {
        final actionState = state.actionState;
        if (actionState is! FoldersActionFailure ||
            actionState.action != FoldersActionType.createFolder) {
          return;
        }
        _formKey.currentState?.validate();
        _focusNode.requestFocus();
      },
      builder: (context, state) {
        final l10n = context.l10n;
        final actionState = state.actionState;
        final submitting =
            actionState is FoldersActionLoading &&
            actionState.action == FoldersActionType.createFolder;
        final submitFailed =
            actionState is FoldersActionFailure &&
            actionState.action == FoldersActionType.createFolder &&
            actionState.reason == FoldersFailureReason.createFailed;
        return AxiInputDialog(
          title: Text(l10n.folderCreateTitle),
          callbackText: l10n.folderCreateAction,
          loading: submitting,
          canPop: !submitting,
          showCloseButton: !submitting,
          callback: _canSubmit && !submitting
              ? () => unawaited(_submit(state))
              : null,
          content: ShadForm(
            key: _formKey,
            autovalidateMode: ShadAutovalidateMode.disabled,
            fieldIdSeparator: null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AxiTextFormField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !submitting,
                  autofocus: true,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  placeholder: Text(l10n.folderNameLabel),
                  validator: (value) => _validateFolderName(value, state, l10n),
                  onSubmitted: (_) => unawaited(_submit(state)),
                ),
                if (submitFailed) ...[
                  SizedBox(height: context.spacing.s),
                  Text(
                    l10n.folderCreateFailed,
                    style: context.textTheme.muted.copyWith(
                      color: context.colorScheme.destructive,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
