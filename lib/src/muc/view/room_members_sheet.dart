// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/avatar/avatar_editor_state_extensions.dart';
import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/avatar/bloc/avatar_editor_cubit.dart';
import 'package:axichat/src/avatar/view/widgets/signup_avatar_editor_panel.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/view/recipient_chips_bar.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/widgets/transport_aware_avatar.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/muc/muc_models.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/models/chat_models.dart' as chat_models;
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RoomMembersSheet extends StatelessWidget {
  const RoomMembersSheet({
    required this.roomState,
    required this.memberSections,
    required this.canInvite,
    required this.onInvite,
    required this.onAction,
    this.roomAvatarPath,
    this.onChangeNickname,
    this.onLeaveRoom,
    this.currentNickname,
    this.onClose,
    this.useSurface = true,
    super.key,
  });

  final RoomState roomState;
  final List<RoomMemberSection> memberSections;
  final bool canInvite;
  final ValueChanged<String> onInvite;
  final void Function(String occupantId, MucModerationAction action) onAction;
  final String? roomAvatarPath;
  final ValueChanged<String>? onChangeNickname;
  final VoidCallback? onLeaveRoom;
  final String? currentNickname;
  final VoidCallback? onClose;
  final bool useSurface;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.textTheme;
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final animationDuration = context.watch<SettingsCubit>().animationDuration;
    final avatarSectionPadding = EdgeInsets.fromLTRB(
      spacing.m,
      0,
      spacing.m,
      spacing.s,
    );
    final avatarPath = roomAvatarPath?.trim();
    final canEditAvatar = roomState.canEditAvatar;
    final showAvatarSection = avatarPath?.isNotEmpty == true || canEditAvatar;
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: context.borderSide),
          ),
          padding: EdgeInsets.fromLTRB(
            spacing.m,
            spacing.m,
            spacing.m,
            spacing.s,
          ),
          child: _HeaderRow(
            canInvite: canInvite,
            onInviteTap: () => _handleInvite(context),
            onClose: onClose,
            l10n: l10n,
          ),
        ),
        SizedBox(height: spacing.s),
        if (showAvatarSection)
          Padding(
            padding: avatarSectionPadding,
            child: _RoomAvatarSection(
              roomJid: roomState.roomJid,
              avatarPath: avatarPath,
              canEdit: canEditAvatar,
              onEdit: canEditAvatar
                  ? () => _handleAvatarEdit(context, avatarPath)
                  : null,
            ),
          ),
        if (onChangeNickname != null || onLeaveRoom != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.m,
              0,
              spacing.m,
              spacing.s,
            ),
            child: Wrap(
              spacing: spacing.s,
              runSpacing: spacing.s,
              children: [
                if (onChangeNickname != null)
                  AxiButton.outline(
                    onPressed: () async {
                      final next = await _promptNickname(context);
                      if (next?.isNotEmpty == true) {
                        onChangeNickname!(next!);
                      }
                    },
                    child: Text(
                      currentNickname == null
                          ? l10n.mucChangeNickname
                          : l10n.mucChangeNicknameWithCurrent(currentNickname!),
                    ),
                  ),
                if (onLeaveRoom != null)
                  AxiButton.destructive(
                    onPressed: onLeaveRoom,
                    child: Text(l10n.mucLeaveRoom),
                  ),
              ],
            ),
          ),
        SizedBox(height: spacing.s),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.m,
              0,
              spacing.m,
              spacing.m,
            ),
            child: memberSections.isEmpty
                ? Center(
                    child: Text(
                      l10n.mucNoMembers,
                      style: theme.muted.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final group = memberSections[index];
                      return _MemberSection(
                        kind: group.kind,
                        members: group.members,
                        onAction: onAction,
                        myOccupantId: roomState.myOccupantId,
                        l10n: l10n,
                        animationDuration: animationDuration,
                      );
                    },
                    separatorBuilder: (_, __) => SizedBox(height: spacing.s),
                    itemCount: memberSections.length,
                  ),
          ),
        ),
      ],
    );

    final Widget wrappedContent = useSurface
        ? AxiModalSurface(
            padding: EdgeInsets.zero,
            borderColor: Colors.transparent,
            shadows: const <BoxShadow>[],
            child: content,
          )
        : content;

    return wrappedContent;
  }

  Future<List<String>?> _promptInvite(BuildContext context) async {
    final dialogMaxWidth = context.sizing.dialogMaxWidth;
    return showAdaptiveBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      surfacePadding: EdgeInsets.zero,
      dialogMaxWidth: dialogMaxWidth,
      showCloseButton: false,
      builder: (context) => _InviteChipsSheet(
        initialRecipients: const [],
        onClose: () => Navigator.of(context).maybePop(),
      ),
    );
  }

  Future<void> _handleInvite(BuildContext context) async {
    final jids = await _promptInvite(context);
    if (jids != null && jids.isNotEmpty) {
      for (final jid in jids) {
        onInvite(jid.trim());
      }
    }
  }

  Future<String?> _promptNickname(BuildContext context) async {
    final controller = TextEditingController(text: currentNickname ?? '');
    final dialogMaxWidth = context.sizing.dialogMaxWidth;
    final result = await showAdaptiveBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      showCloseButton: false,
      dialogMaxWidth: dialogMaxWidth,
      builder: (sheetContext) {
        final pop = Navigator.of(sheetContext).pop;
        return _NicknameSheet(
          controller: controller,
          onCancel: () => pop(),
          onSubmit: (value) => pop(value.trim()),
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _handleAvatarEdit(
    BuildContext context,
    String? avatarPath,
  ) async {
    final avatar = await RoomAvatarEditorSheet.show(
      context,
      avatarPath: avatarPath,
    );
    if (!context.mounted || avatar == null) return;
    final locate = context.read;
    locate<ChatBloc>().add(ChatRoomAvatarChangeRequested(avatar));
  }
}

class _RoomAvatarSection extends StatelessWidget {
  const _RoomAvatarSection({
    required this.roomJid,
    required this.avatarPath,
    required this.canEdit,
    this.onEdit,
  });

  final String roomJid;
  final String? avatarPath;
  final bool canEdit;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final spacing = context.spacing;
    final avatarSize = sizing.iconButtonTapTarget;
    final avatarSpacing = spacing.s;
    final l10n = context.l10n;
    final avatar = AxiAvatar(
      jid: roomJid,
      size: avatarSize,
      avatarPath: avatarPath,
    );
    final editButton = canEdit
        ? AxiButton.outline(
            onPressed: onEdit,
            child: Text(l10n.mucEditAvatar),
          )
        : null;
    return Row(
      children: [
        avatar,
        SizedBox(width: avatarSpacing),
        if (editButton != null) editButton,
      ],
    );
  }
}

class _MemberSection extends StatelessWidget {
  const _MemberSection({
    required this.kind,
    required this.members,
    required this.onAction,
    required this.myOccupantId,
    required this.l10n,
    required this.animationDuration,
  });

  final RoomMemberSectionKind kind;
  final List<RoomMemberEntry> members;
  final void Function(String occupantId, MucModerationAction action) onAction;
  final String? myOccupantId;
  final AppLocalizations l10n;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final spacing = context.spacing;
    final title = _titleForKind(kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.xs),
          child: Text(title, style: textTheme.sectionLabelM),
        ),
        ...members.map((member) {
          final occupant = member.occupant;
          final subtitle = _roleSubtitle(occupant);
          final isSelf = occupant.occupantId == myOccupantId;
          return Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.xs),
            child: _MemberTile(
              key: ValueKey(occupant.occupantId),
              occupant: occupant,
              subtitle: subtitle,
              actions: member.actions,
              avatarPath: member.avatarPath,
              onAction: onAction,
              isSelf: isSelf,
              l10n: l10n,
              animationDuration: animationDuration,
            ),
          );
        }),
      ],
    );
  }

  String _titleForKind(RoomMemberSectionKind kind) {
    return switch (kind) {
      RoomMemberSectionKind.owners => l10n.mucSectionOwners,
      RoomMemberSectionKind.admins => l10n.mucSectionAdmins,
      RoomMemberSectionKind.moderators => l10n.mucSectionModerators,
      RoomMemberSectionKind.members => l10n.mucSectionMembers,
      RoomMemberSectionKind.visitors => l10n.mucSectionVisitors,
    };
  }

  String _roleSubtitle(Occupant occupant) {
    final labels = <String>[];
    if (occupant.affiliation.isOwner) {
      labels.add(l10n.mucRoleOwner);
    } else if (occupant.affiliation.isAdmin) {
      labels.add(l10n.mucRoleAdmin);
    } else if (occupant.affiliation.isMember) {
      labels.add(l10n.mucRoleMember);
    } else {
      labels.add(l10n.mucRoleVisitor);
    }
    if (occupant.role.isModerator) labels.add(l10n.mucRoleModerator);
    return labels.join(' • ');
  }
}

class _MemberTile extends StatefulWidget {
  const _MemberTile({
    required this.occupant,
    required this.subtitle,
    required this.actions,
    required this.avatarPath,
    required this.onAction,
    required this.isSelf,
    required this.l10n,
    required this.animationDuration,
    super.key,
  });

  final Occupant occupant;
  final String subtitle;
  final List<MucModerationAction> actions;
  final String? avatarPath;
  final void Function(String occupantId, MucModerationAction action) onAction;
  final bool isSelf;
  final AppLocalizations l10n;
  final Duration animationDuration;

  @override
  State<_MemberTile> createState() => _MemberTileState();
}

class _MemberTileState extends State<_MemberTile> {
  bool _showActions = false;

  void _toggleActions() => setState(() => _showActions = !_showActions);

  void _closeActions() => setState(() => _showActions = false);

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final sizing = context.sizing;
    final avatarKey = _avatarKey(widget.occupant);
    final avatar = AxiAvatar(
      jid: avatarKey,
      size: sizing.iconButtonSize,
      avatarPath: widget.avatarPath,
    );

    final tile = AxiListTile(
      onTap: widget.actions.isEmpty ? null : _toggleActions,
      leading: avatar,
      title: widget.occupant.nick,
      subtitle: widget.subtitle,
      selected: widget.isSelf,
      paintSurface: true,
      tapBounce: true,
    );

    final actionsPanel = widget.actions.isEmpty
        ? const SizedBox.shrink()
        : AnimatedCrossFade(
            duration: widget.animationDuration,
            sizeCurve: Curves.easeInOutCubic,
            crossFadeState: _showActions
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                spacing.s,
                spacing.xs,
                spacing.s,
                spacing.xs,
              ),
              child: _MemberActionPanel(
                occupantId: widget.occupant.occupantId,
                actions: widget.actions,
                onAction: widget.onAction,
                onClose: _closeActions,
                l10n: widget.l10n,
              ),
            ),
          );

    return Column(children: [tile, actionsPanel]);
  }
}

class _MemberActionPanel extends StatelessWidget {
  const _MemberActionPanel({
    required this.occupantId,
    required this.actions,
    required this.onAction,
    required this.onClose,
    required this.l10n,
  });

  final String occupantId;
  final List<MucModerationAction> actions;
  final void Function(String occupantId, MucModerationAction action) onAction;
  final VoidCallback onClose;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final spacing = context.spacing;
    return Wrap(
      spacing: spacing.s,
      runSpacing: spacing.s,
      alignment: WrapAlignment.start,
      children: actions.map((action) {
        final descriptor = _MemberActionDescriptor.forAction(action, l10n);
        final builder =
            descriptor.destructive ? AxiButton.destructive : AxiButton.outline;
        return builder(
          onPressed: () {
            onClose();
            onAction(occupantId, action);
          },
          leading: Icon(descriptor.icon, size: sizing.menuItemIconSize),
          child: Text(descriptor.label),
        );
      }).toList(),
    );
  }
}

class _MemberActionDescriptor {
  const _MemberActionDescriptor({
    required this.label,
    required this.icon,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final bool destructive;

  static _MemberActionDescriptor forAction(
    MucModerationAction action,
    AppLocalizations l10n,
  ) {
    switch (action) {
      case MucModerationAction.kick:
        return _MemberActionDescriptor(
          label: l10n.mucActionKick,
          icon: LucideIcons.logOut,
          destructive: true,
        );
      case MucModerationAction.ban:
        return _MemberActionDescriptor(
          label: l10n.mucActionBan,
          icon: LucideIcons.shieldOff,
          destructive: true,
        );
      case MucModerationAction.member:
        return _MemberActionDescriptor(
          label: l10n.mucActionMakeMember,
          icon: LucideIcons.userRound,
        );
      case MucModerationAction.admin:
        return _MemberActionDescriptor(
          label: l10n.mucActionMakeAdmin,
          icon: LucideIcons.shield,
        );
      case MucModerationAction.owner:
        return _MemberActionDescriptor(
          label: l10n.mucActionMakeOwner,
          icon: LucideIcons.crown,
        );
      case MucModerationAction.moderator:
        return _MemberActionDescriptor(
          label: l10n.mucActionGrantModerator,
          icon: LucideIcons.gavel,
        );
      case MucModerationAction.participant:
        return _MemberActionDescriptor(
          label: l10n.mucActionRevokeModerator,
          icon: LucideIcons.userMinus,
        );
    }
  }
}

String _avatarKey(Occupant occupant) {
  final realJid = occupant.realJid;
  if (realJid == null || realJid.isEmpty) {
    return occupant.nick;
  }
  return bareAddress(realJid) ?? realJid;
}

class RoomAvatarEditorSheet extends StatefulWidget {
  const RoomAvatarEditorSheet({
    required this.avatarPath,
    required this.onCancel,
    required this.onSave,
    super.key,
  });

  final String? avatarPath;
  final VoidCallback onCancel;
  final ValueChanged<AvatarUploadPayload> onSave;

  @override
  State<RoomAvatarEditorSheet> createState() => _RoomAvatarEditorSheetState();

  static Future<AvatarUploadPayload?> show(
    BuildContext context, {
    String? avatarPath,
  }) {
    final dialogMaxWidth = context.sizing.dialogMaxWidth;
    return showAdaptiveBottomSheet<AvatarUploadPayload>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      showCloseButton: false,
      dialogMaxWidth: dialogMaxWidth,
      builder: (sheetContext) {
        final pop = Navigator.of(sheetContext).pop;
        final colors = sheetContext.colorScheme;
        return BlocProvider(
          create: (_) => AvatarEditorCubit(
            xmppService: sheetContext.read<XmppService>(),
            templates: buildDefaultAvatarTemplates(),
          )
            ..initialize(colors)
            ..setCarouselEnabled(true, colors)
            ..seedFromAvatarPath(avatarPath),
          child: RoomAvatarEditorSheet(
            avatarPath: avatarPath,
            onCancel: () => pop(),
            onSave: (payload) => pop(payload),
          ),
        );
      },
    );
  }
}

class _RoomAvatarEditorSheetState extends State<RoomAvatarEditorSheet> {
  Future<void> _handleSave() async {
    if (context.read<AvatarEditorCubit>().state.isBusy) return;
    context.read<AvatarEditorCubit>().pauseCarousel();
    final payload =
        await context.read<AvatarEditorCubit>().buildSelectedAvatarPayload();
    if (payload == null) return;
    widget.onSave(payload);
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = context.modalHeaderTextStyle;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final animationDuration = context.watch<SettingsCubit>().animationDuration;
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final headerPadding = EdgeInsets.fromLTRB(
      spacing.m,
      spacing.m,
      spacing.m,
      spacing.s,
    );
    final contentPadding = EdgeInsets.symmetric(horizontal: spacing.m);
    final actionsPadding = EdgeInsets.fromLTRB(
      spacing.m,
      0,
      spacing.m,
      spacing.m,
    );
    return BlocBuilder<AvatarEditorCubit, AvatarEditorState>(
      builder: (context, avatarState) {
        final errorText = avatarState.errorType?.resolve(l10n);
        final hasAvatar = avatarState.draftAvatar != null ||
            avatarState.carouselAvatar != null;
        final saveEnabled = !avatarState.isBusy && hasAvatar;
        final useActionEnabled = avatarState.canUseCarouselAvatar;
        final Widget actions = Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AxiButton.outline(
              onPressed: widget.onCancel,
              child: Text(l10n.commonCancel),
            ),
            SizedBox(width: spacing.s),
            AxiButton.primary(
              onPressed: saveEnabled ? _handleSave : null,
              child: Text(l10n.avatarSaveAvatar),
            ),
          ],
        );
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: headerPadding,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.mucEditAvatar,
                                  style: titleStyle,
                                ),
                              ),
                              AxiIconButton(
                                iconData: LucideIcons.x,
                                tooltip: l10n.commonClose,
                                onPressed: widget.onCancel,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: contentPadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SignupAvatarEditorPanel(
                                mode: avatarState.editorMode,
                                avatarBytes: avatarState.displayedBytes,
                                animationDuration: animationDuration,
                                cropBytes: avatarState.draftAvatar?.sourceBytes,
                                cropRect: avatarState.draftAvatar?.cropRect,
                                imageWidth: avatarState.draftAvatar?.sourceWidth
                                    ?.toDouble(),
                                imageHeight: avatarState
                                    .draftAvatar?.sourceHeight
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
                                    .shuffleCarousel(context.colorScheme),
                                onUpload: () => context
                                    .read<AvatarEditorCubit>()
                                    .pickImage(),
                                onUseCurrent: () => context
                                    .read<AvatarEditorCubit>()
                                    .pauseCarousel(),
                                useActionEnabled: useActionEnabled,
                                canShuffleBackground:
                                    avatarState.hasCarouselPreview &&
                                        avatarState.canShuffleBackground,
                                onShuffleBackground:
                                    avatarState.hasCarouselPreview &&
                                            avatarState.canShuffleBackground
                                        ? () => context
                                            .read<AvatarEditorCubit>()
                                            .shuffleCarouselBackground(
                                              context.colorScheme,
                                            )
                                        : null,
                                descriptionText: l10n.mucAvatarMenuDescription,
                              ),
                              if (errorText != null) ...[
                                SizedBox(height: spacing.s),
                                Text(
                                  errorText,
                                  style: context.textTheme.small.copyWith(
                                    color: context.colorScheme.destructive,
                                  ),
                                ),
                              ],
                              SizedBox(height: spacing.s),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  bottom: true,
                  child: Padding(
                    padding: actionsPadding,
                    child: actions,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InviteChipsSheet extends StatefulWidget {
  const _InviteChipsSheet({
    required this.initialRecipients,
    required this.onClose,
  });

  final List<ComposerRecipient> initialRecipients;
  final VoidCallback onClose;

  @override
  State<_InviteChipsSheet> createState() => _InviteChipsSheetState();
}

class _InviteChipsSheetState extends State<_InviteChipsSheet> {
  final ScrollController _scrollController = ScrollController();
  late List<ComposerRecipient> _recipients;

  @override
  void initState() {
    super.initState();
    _recipients = List<ComposerRecipient>.from(widget.initialRecipients);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final rosterItems =
        context.watch<RosterCubit>().state.items ?? const <RosterItem>[];
    final locate = context.read;
    final profileJid = context.watch<ProfileCubit>().state.jid;
    final resolvedProfileJid = profileJid.trim();
    final String? selfJid =
        resolvedProfileJid.isNotEmpty ? resolvedProfileJid : null;
    final selfIdentity = SelfIdentitySnapshot(
      selfJid: selfJid,
      avatarPath: context.watch<ProfileCubit>().state.avatarPath,
    );
    final contentPadding = EdgeInsets.fromLTRB(
      spacing.m,
      0,
      spacing.m,
      spacing.m,
    );
    final Widget actions = Row(
      children: [
        AxiButton.outline(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        SizedBox(width: spacing.s),
        AxiButton.primary(
          onPressed: _recipients.isEmpty
              ? null
              : () {
                  final invitees = _recipients
                      .where((recipient) => recipient.included)
                      .map(
                        (recipient) =>
                            recipient.target.address ??
                            recipient.target.chat?.jid,
                      )
                      .whereType<String>()
                      .toList();
                  Navigator.of(context).pop(invitees);
                },
          child: Text(l10n.mucSendInvites),
        ),
      ],
    );
    return AxiSheetScaffold(
      header: AxiSheetHeader(
        title: Text(l10n.mucInviteUsers),
        onClose: widget.onClose,
      ),
      body: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: ListView(
          controller: _scrollController,
          padding: contentPadding,
          children: [
            RecipientChipsBar(
              recipients: _recipients,
              availableChats: const <chat_models.Chat>[],
              rosterItems: rosterItems,
              recipientSuggestionsStream:
                  locate<ChatsCubit>().recipientAddressSuggestionsStream(),
              selfJid: locate<ChatsCubit>().selfJid,
              selfIdentity: selfIdentity,
              latestStatuses: const {},
              onRecipientAdded: _addRecipient,
              onRecipientRemoved: _removeRecipient,
              onRecipientToggled: _toggleRecipient,
              collapsedByDefault: false,
            ),
            SizedBox(height: spacing.s),
          ],
        ),
      ),
      footer: Padding(padding: contentPadding, child: actions),
    );
  }

  void _addRecipient(FanOutTarget target) {
    setState(() {
      final existingIndex = _recipients.indexWhere(
        (recipient) => recipient.key == target.key,
      );
      if (existingIndex >= 0) {
        _recipients[existingIndex] = _recipients[existingIndex].copyWith(
          target: target,
          included: true,
        );
      } else {
        _recipients.add(ComposerRecipient(target: target));
      }
    });
  }

  void _removeRecipient(String key) {
    setState(() {
      _recipients.removeWhere((recipient) => recipient.key == key);
    });
  }

  void _toggleRecipient(String key) {
    setState(() {
      final index = _recipients.indexWhere((recipient) => recipient.key == key);
      if (index == -1) return;
      final recipient = _recipients[index];
      _recipients[index] = recipient.copyWith(included: !recipient.included);
    });
  }
}

class _NicknameSheet extends StatelessWidget {
  const _NicknameSheet({
    required this.controller,
    required this.onSubmit,
    required this.onCancel,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final contentPadding = EdgeInsets.fromLTRB(
      spacing.m,
      0,
      spacing.m,
      spacing.m,
    );
    final Widget actions = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AxiButton.outline(
          onPressed: onCancel,
          child: Text(l10n.commonCancel),
        ),
        SizedBox(width: spacing.s),
        AxiButton.primary(
          onPressed: () => onSubmit(controller.text.trim()),
          child: Text(l10n.mucUpdateNickname),
        ),
      ],
    );
    return AxiSheetScaffold(
      header: AxiSheetHeader(
        title: Text(l10n.mucChangeNicknameTitle),
        onClose: onCancel,
      ),
      body: Padding(
        padding: contentPadding,
        child: AxiTextFormField(
          controller: controller,
          autofocus: true,
          placeholder: Text(l10n.mucEnterNicknamePlaceholder),
          onSubmitted: onSubmit,
        ),
      ),
      footer: Padding(
        padding: contentPadding,
        child: actions,
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.canInvite,
    required this.onInviteTap,
    required this.onClose,
    required this.l10n,
  });

  final bool canInvite;
  final Future<void> Function()? onInviteTap;
  final VoidCallback? onClose;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final headerStyle = context.modalHeaderTextStyle;
    final spacing = context.spacing;
    final sizing = context.sizing;
    return Row(
      children: [
        Text(l10n.mucMembersTitle, style: headerStyle),
        const Spacer(),
        if (canInvite)
          AxiButton.outline(
            onPressed: onInviteTap,
            leading: Icon(LucideIcons.userPlus, size: sizing.menuItemIconSize),
            child: Text(l10n.mucInviteUser),
          ),
        if (onClose != null) ...[
          SizedBox(width: spacing.s),
          AxiIconButton(
            iconData: LucideIcons.x,
            tooltip: l10n.commonClose,
            onPressed: onClose,
          ),
        ],
      ],
    );
  }
}
