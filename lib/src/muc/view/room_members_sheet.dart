// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/avatar/avatar_editor_state_extensions.dart';
import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/avatar/bloc/avatar_editor_cubit.dart';
import 'package:axichat/src/avatar/view/avatar_error_l10n.dart';
import 'package:axichat/src/avatar/view/widgets/signup_avatar_editor_panel.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/view/recipient_chips_bar.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/widgets/transport_aware_avatar.dart';
import 'package:axichat/src/common/ui/keyboard_pop_scope.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_sheet_header.dart';
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
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RoomMembersSheet extends StatelessWidget {
  const RoomMembersSheet({
    required this.roomState,
    required this.memberSections,
    required this.canInvite,
    required this.avatarUpdateInFlight,
    required this.onInvite,
    required this.onAction,
    required this.onOpenDirectChat,
    this.roomAvatarPath,
    this.onChangeNickname,
    this.onLeaveRoom,
    this.onDestroyRoom,
    this.currentNickname,
    this.onClose,
    this.useSurface = true,
    super.key,
  });

  final RoomState roomState;
  final List<RoomMemberSection> memberSections;
  final bool canInvite;
  final bool avatarUpdateInFlight;
  final ValueChanged<String> onInvite;
  final Future<void> Function(
    String occupantId,
    MucModerationAction action,
    String actionLabel,
  )
  onAction;
  final Future<void> Function(String jid) onOpenDirectChat;
  final String? roomAvatarPath;
  final ValueChanged<String>? onChangeNickname;
  final Future<void> Function()? onLeaveRoom;
  final Future<void> Function()? onDestroyRoom;
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
    final showMembersLoading =
        memberSections.isEmpty && roomState.isBootstrapPending;
    final roomJoinFailed =
        memberSections.isEmpty && !showMembersLoading && roomState.hasJoinError;
    final roomJoinFailureDetail = roomState.joinErrorText?.trim();
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(border: Border(bottom: context.borderSide)),
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
              loading: avatarUpdateInFlight,
              onEdit: canEditAvatar && !avatarUpdateInFlight
                  ? () => _handleAvatarEdit(context, avatarPath)
                  : null,
            ),
          ),
        if (onChangeNickname != null ||
            onLeaveRoom != null ||
            onDestroyRoom != null)
          Padding(
            padding: EdgeInsets.fromLTRB(spacing.m, 0, spacing.m, spacing.s),
            child: _RoomManagementActions(
              onPromptNickname: onChangeNickname == null
                  ? null
                  : () async {
                      final next = await _promptNickname(context);
                      if (next?.isNotEmpty == true) {
                        onChangeNickname!(next!);
                      }
                    },
              onLeaveRoom: onLeaveRoom,
              onDestroyRoom: roomState.myAffiliation.isOwner
                  ? onDestroyRoom
                  : null,
              currentNickname: currentNickname,
            ),
          ),
        SizedBox(height: spacing.s),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(spacing.m, 0, spacing.m, spacing.m),
            child: showMembersLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AxiProgressIndicator(
                          color: colors.foreground,
                          semanticsLabel: l10n.chatMembersLoading,
                        ),
                        SizedBox(height: spacing.s),
                        Text(
                          l10n.chatMembersLoadingEllipsis,
                          style: theme.muted.copyWith(
                            color: colors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  )
                : roomJoinFailed
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.triangleAlert,
                          size: context.sizing.iconButtonIconSize,
                          color: colors.destructive,
                        ),
                        SizedBox(height: spacing.s),
                        Text(
                          l10n.chatInviteJoinFailed,
                          style: theme.muted.copyWith(
                            color: colors.destructive,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (roomJoinFailureDetail?.isNotEmpty == true) ...[
                          SizedBox(height: spacing.xs),
                          Text(
                            roomJoinFailureDetail!,
                            style: theme.muted.copyWith(
                              color: colors.mutedForeground,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  )
                : memberSections.isEmpty
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
                        onOpenDirectChat: onOpenDirectChat,
                        myOccupantId: roomState.myOccupantId,
                        l10n: l10n,
                        animationDuration: animationDuration,
                      );
                    },
                    separatorBuilder: (_, _) => SizedBox(height: spacing.s),
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
    return showAdaptiveBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      preferDialogOnMobile: true,
      useRootNavigator: false,
      surfacePadding: EdgeInsets.zero,
      builder: (sheetContext) => _InviteChipsSheet(
        initialRecipients: const [],
        onClose: () => Navigator.of(sheetContext).maybePop(),
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
      preferDialogOnMobile: true,
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
    final chatState = locate<ChatBloc>().state;
    final chat = chatState.chat;
    final roomState = chatState.roomState;
    if (chat == null || roomState == null) {
      return;
    }
    locate<ChatBloc>().add(
      ChatRoomAvatarChangeRequested(
        avatar: avatar,
        chat: chat,
        roomState: roomState,
      ),
    );
  }
}

class _RoomAvatarSection extends StatelessWidget {
  const _RoomAvatarSection({
    required this.roomJid,
    required this.avatarPath,
    required this.canEdit,
    required this.loading,
    this.onEdit,
  });

  final String roomJid;
  final String? avatarPath;
  final bool canEdit;
  final bool loading;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final motion = context.motion;
    final radii = context.radii;
    final sizing = context.sizing;
    final spacing = context.spacing;
    final avatarSize = sizing.iconButtonTapTarget;
    final avatarSpacing = spacing.s;
    final l10n = context.l10n;
    final sizeSpan = sizing.iconButtonSize - sizing.iconButtonIconSize;
    final clampedProgress = sizeSpan <= 0
        ? 1.0
        : ((avatarSize - sizing.iconButtonIconSize) / sizeSpan)
              .clamp(0.0, 1.0)
              .toDouble();
    final squircleCornerRadius =
        radii.squircleSm +
        ((radii.squircle - radii.squircleSm) * clampedProgress);
    final avatarShape = SquircleBorder(cornerRadius: squircleCornerRadius);
    final overlayAlpha = motion.tapFocusAlpha + motion.tapHoverAlpha;
    final avatar = SizedBox.square(
      dimension: avatarSize,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AxiAvatar(jid: roomJid, size: avatarSize, avatarPath: avatarPath),
          if (loading)
            IgnorePointer(
              child: ClipPath(
                clipper: ShapeBorderClipper(shape: avatarShape),
                child: ColoredBox(
                  color: colors.foreground.withValues(alpha: overlayAlpha),
                  child: Center(
                    child: AxiProgressIndicator(
                      color: colors.background,
                      semanticsLabel: l10n.mucEditAvatar,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    final editButton = canEdit
        ? AxiButton.outline(
            onPressed: onEdit,
            loading: loading,
            child: Text(l10n.mucEditAvatar),
          )
        : null;
    return Row(
      children: [
        avatar,
        SizedBox(width: avatarSpacing),
        ?editButton,
      ],
    );
  }
}

class _RoomManagementActions extends StatefulWidget {
  const _RoomManagementActions({
    required this.currentNickname,
    this.onPromptNickname,
    this.onLeaveRoom,
    this.onDestroyRoom,
  });

  final String? currentNickname;
  final Future<void> Function()? onPromptNickname;
  final Future<void> Function()? onLeaveRoom;
  final Future<void> Function()? onDestroyRoom;

  @override
  State<_RoomManagementActions> createState() => _RoomManagementActionsState();
}

class _RoomManagementActionsState extends State<_RoomManagementActions> {
  _RoomManagementAction? _loadingAction;

  bool get _busy => _loadingAction != null;

  Future<void> _handleConfirmedAction({
    required _RoomManagementAction action,
    required Future<void> Function() onConfirmed,
    required String title,
    required String message,
    required String confirmLabel,
    required String timeoutMessage,
  }) async {
    final confirmed = await confirm(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructiveConfirm: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _loadingAction = action);
    try {
      await onConfirmed();
    } on XmppMessageException {
      // The bloc surfaces failure feedback; keep the UI from crashing.
    } on TimeoutException {
      if (mounted) {
        FeedbackSystem.showError(context, timeoutMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingAction = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sizing = context.sizing;
    final spacing = context.spacing;
    return Wrap(
      spacing: spacing.s,
      runSpacing: spacing.s,
      children: [
        if (widget.onPromptNickname != null)
          AxiButton.outline(
            onPressed: _busy
                ? null
                : () async {
                    await widget.onPromptNickname!();
                  },
            leading: Icon(LucideIcons.pencil, size: sizing.menuItemIconSize),
            child: Text(
              widget.currentNickname == null
                  ? l10n.mucChangeNickname
                  : l10n.mucChangeNicknameWithCurrent(widget.currentNickname!),
            ),
          ),
        if (widget.onLeaveRoom != null)
          AxiButton.destructive(
            onPressed: _busy
                ? null
                : () => _handleConfirmedAction(
                    action: _RoomManagementAction.leave,
                    onConfirmed: widget.onLeaveRoom!,
                    title: l10n.mucLeaveRoomConfirmTitle,
                    message: l10n.mucLeaveRoomConfirmBody,
                    confirmLabel: l10n.mucLeaveRoom,
                    timeoutMessage: l10n.chatLeaveRoomFailed,
                  ),
            loading: _loadingAction == _RoomManagementAction.leave,
            leading: Icon(LucideIcons.logOut, size: sizing.menuItemIconSize),
            child: Text(l10n.mucLeaveRoom),
          ),
        if (widget.onDestroyRoom != null)
          AxiButton.destructive(
            onPressed: _busy
                ? null
                : () => _handleConfirmedAction(
                    action: _RoomManagementAction.destroy,
                    onConfirmed: widget.onDestroyRoom!,
                    title: l10n.mucDestroyRoomConfirmTitle,
                    message: l10n.mucDestroyRoomConfirmBody,
                    confirmLabel: l10n.mucDestroyRoom,
                    timeoutMessage: l10n.chatDestroyRoomFailed,
                  ),
            loading: _loadingAction == _RoomManagementAction.destroy,
            leading: Icon(LucideIcons.trash2, size: sizing.menuItemIconSize),
            child: Text(l10n.mucDestroyRoom),
          ),
      ],
    );
  }
}

enum _RoomManagementAction { leave, destroy }

class _MemberSection extends StatelessWidget {
  const _MemberSection({
    required this.kind,
    required this.members,
    required this.onAction,
    required this.onOpenDirectChat,
    required this.myOccupantId,
    required this.l10n,
    required this.animationDuration,
  });

  final RoomMemberSectionKind kind;
  final List<RoomMemberEntry> members;
  final Future<void> Function(
    String occupantId,
    MucModerationAction action,
    String actionLabel,
  )
  onAction;
  final Future<void> Function(String jid) onOpenDirectChat;
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
              directChatJid: member.directChatJid,
              avatarPath: member.avatarPath,
              onAction: onAction,
              onOpenDirectChat: onOpenDirectChat,
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
      RoomMemberSectionKind.participants => l10n.mucSectionParticipants,
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
    } else if (occupant.role.isParticipant) {
      labels.add(l10n.mucRoleParticipant);
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
    required this.directChatJid,
    required this.avatarPath,
    required this.onAction,
    required this.onOpenDirectChat,
    required this.isSelf,
    required this.l10n,
    required this.animationDuration,
    super.key,
  });

  final Occupant occupant;
  final String subtitle;
  final List<MucModerationAction> actions;
  final String? directChatJid;
  final String? avatarPath;
  final Future<void> Function(
    String occupantId,
    MucModerationAction action,
    String actionLabel,
  )
  onAction;
  final Future<void> Function(String jid) onOpenDirectChat;
  final bool isSelf;
  final AppLocalizations l10n;
  final Duration animationDuration;

  @override
  State<_MemberTile> createState() => _MemberTileState();
}

class _MemberTileState extends State<_MemberTile> {
  static const Duration _actionTimeout = Duration(seconds: 10);

  bool _showActions = false;
  String? _loadingActionId;

  bool get _hasActionPanel =>
      widget.directChatJid != null || widget.actions.isNotEmpty;

  bool get _actionBusy => _loadingActionId != null;

  void _toggleActions() {
    if (!_hasActionPanel || _actionBusy) {
      return;
    }
    setState(() => _showActions = !_showActions);
  }

  Future<void> _handleMemberAction(_MemberActionSpec action) async {
    if (_actionBusy) {
      return;
    }
    setState(() => _loadingActionId = action.id);
    try {
      await action.onPressed().timeout(
        _actionTimeout,
        onTimeout: () {
          if (!mounted || action.timeoutMessage == null) {
            return;
          }
          FeedbackSystem.showError(context, action.timeoutMessage!);
        },
      );
    } finally {
      if (mounted) {
        setState(() => _loadingActionId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final brightness = context.brightness;
    final radii = context.radii;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final avatarKey = _avatarKey(widget.occupant);
    final overlayAlpha = brightness == Brightness.dark ? 0.12 : 0.06;
    final tileBackgroundColor = widget.isSelf
        ? Color.alphaBlend(
            colors.primary.withValues(alpha: overlayAlpha),
            colors.card,
          )
        : colors.card;
    final surfaceBorderColor = context.borderSide.color;
    final shape = SquircleBorder(
      cornerRadius: radii.squircle,
      side: BorderSide(
        color: surfaceBorderColor,
        width: context.borderSide.width,
      ),
    );
    final avatar = AxiAvatar(
      jid: avatarKey,
      size: sizing.iconButtonSize,
      avatarPath: widget.avatarPath,
    );
    final actionSpecs = <_MemberActionSpec>[
      if (widget.directChatJid != null)
        _MemberActionSpec(
          id: 'chat:${widget.directChatJid}',
          label: widget.l10n.mucActionOpenChat,
          icon: LucideIcons.messagesSquare,
          onPressed: () => widget.onOpenDirectChat(widget.directChatJid!),
        ),
      ...widget.actions.map((action) {
        final descriptor = _MemberActionDescriptor.forAction(
          action,
          widget.l10n,
        );
        return _MemberActionSpec(
          id: 'moderation:${widget.occupant.occupantId}:${action.name}',
          label: descriptor.label,
          icon: descriptor.icon,
          destructive: descriptor.destructive,
          timeoutMessage: widget.l10n.chatModerationFailed,
          onPressed: () => widget.onAction(
            widget.occupant.occupantId,
            action,
            descriptor.label,
          ),
        );
      }),
    ];
    final cutoutGap = spacing.xxs;
    final iconButtonSize = sizing.iconButtonSize;
    final iconCutoutThickness = iconButtonSize + (cutoutGap * 2);
    final iconCutoutDepth = (iconButtonSize / 2) + cutoutGap;

    final tile = AxiListTile(
      onTap: _hasActionPanel && !_actionBusy ? _toggleActions : null,
      leading: avatar,
      title: widget.occupant.nick,
      subtitle: widget.subtitle,
      selected: widget.isSelf,
      paintSurface: false,
      tapBounce: false,
      contentPadding: EdgeInsetsDirectional.fromSTEB(
        spacing.m,
        spacing.xs,
        spacing.m,
        spacing.xs,
      ),
    );

    final Widget expandedActionsPanel = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        spacing.m,
        0,
        spacing.m,
        spacing.m,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.m),
        child: _MemberActionPanel(
          actions: actionSpecs,
          activeActionId: _loadingActionId,
          onActionPressed: _handleMemberAction,
        ),
      ),
    );
    final Widget actionsPanel = !_hasActionPanel
        ? const SizedBox.shrink()
        : widget.animationDuration == Duration.zero
        ? (_showActions ? expandedActionsPanel : const SizedBox.shrink())
        : AnimatedCrossFade(
            duration: widget.animationDuration,
            sizeCurve: Curves.easeInOutCubic,
            crossFadeState: _showActions
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: expandedActionsPanel,
          );

    final cutouts = !_hasActionPanel
        ? const <CutoutSpec>[]
        : <CutoutSpec>[
            CutoutSpec(
              edge: CutoutEdge.right,
              alignment: const Alignment(1, 0),
              depth: iconCutoutDepth,
              thickness: iconCutoutThickness,
              cornerRadius: context.radii.squircle,
              child: _MemberActionsToggle(
                backgroundColor: tileBackgroundColor,
                expanded: _showActions,
                onPressed: _actionBusy ? null : _toggleActions,
                l10n: widget.l10n,
              ),
            ),
          ];

    final tileSurface = CutoutSurface(
      backgroundColor: tileBackgroundColor,
      borderColor: surfaceBorderColor,
      cutouts: cutouts,
      shape: shape,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          return SizedBox(
            width: maxWidth,
            child: Column(children: [tile, actionsPanel]),
          );
        },
      ),
    );
    return tileSurface.withTapBounce(enabled: _hasActionPanel && !_actionBusy);
  }
}

class _MemberActionPanel extends StatelessWidget {
  const _MemberActionPanel({
    required this.actions,
    required this.activeActionId,
    required this.onActionPressed,
  });

  final List<_MemberActionSpec> actions;
  final String? activeActionId;
  final Future<void> Function(_MemberActionSpec action) onActionPressed;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final spacing = context.spacing;
    return Wrap(
      spacing: spacing.s,
      runSpacing: spacing.s,
      alignment: WrapAlignment.start,
      children: actions.map((action) {
        final loading = activeActionId == action.id;
        final builder = action.destructive
            ? AxiButton.destructive
            : AxiButton.outline;
        return builder(
          onPressed: activeActionId == null
              ? () => onActionPressed(action)
              : null,
          loading: loading,
          leading: Icon(action.icon, size: sizing.menuItemIconSize),
          child: Text(action.label),
        );
      }).toList(),
    );
  }
}

class _MemberActionSpec {
  const _MemberActionSpec({
    required this.id,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
    this.timeoutMessage,
  });

  final String id;
  final String label;
  final IconData icon;
  final bool destructive;
  final String? timeoutMessage;
  final Future<void> Function() onPressed;
}

class _MemberActionsToggle extends StatelessWidget {
  const _MemberActionsToggle({
    required this.backgroundColor,
    required this.expanded,
    required this.onPressed,
    required this.l10n,
  });

  final Color backgroundColor;
  final bool expanded;
  final VoidCallback? onPressed;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final sizing = context.sizing;
    final tooltip = expanded ? l10n.commonClose : l10n.commonMoreOptions;
    return Semantics(
      container: true,
      button: true,
      toggled: expanded,
      label: tooltip,
      onTap: onPressed,
      child: AxiIconButton(
        iconData: expanded ? LucideIcons.x : LucideIcons.ellipsisVertical,
        tooltip: tooltip,
        semanticLabel: tooltip,
        onPressed: onPressed,
        iconSize: sizing.iconButtonIconSize,
        buttonSize: sizing.iconButtonSize,
        tapTargetSize: sizing.iconButtonSize,
        color: colors.mutedForeground,
        backgroundColor: backgroundColor,
        borderColor: colors.border,
        borderWidth: context.borderSide.width,
        cornerRadius: context.radii.squircle,
      ),
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
          create: (_) =>
              AvatarEditorCubit(
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
    final payload = await context
        .read<AvatarEditorCubit>()
        .buildSelectedAvatarPayload();
    if (payload == null) return;
    widget.onSave(payload);
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = context.modalHeaderTextStyle;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final animationDuration = context.watch<SettingsCubit>().animationDuration;
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
        final saveEnabled =
            !avatarState.isBusy && avatarState.draftAvatar != null;
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
                              imageHeight: avatarState.draftAvatar?.sourceHeight
                                  ?.toDouble(),
                              onCropChanged: (rect) => context
                                  .read<AvatarEditorCubit>()
                                  .updateCropRect(rect),
                              onCropReset: () =>
                                  context.read<AvatarEditorCubit>().resetCrop(),
                              onCropCommitted: (rect) => context
                                  .read<AvatarEditorCubit>()
                                  .commitCrop(rect),
                              onShuffle: () => context
                                  .read<AvatarEditorCubit>()
                                  .pauseOnPreviewAvatar(context.colorScheme),
                              onUpload: () =>
                                  context.read<AvatarEditorCubit>().pickImage(),
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
                                  ? () => context
                                        .read<AvatarEditorCubit>()
                                        .shuffleBackground(context.colorScheme)
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
                child: Padding(padding: actionsPadding, child: actions),
              ),
            ],
          ),
        );
      },
    );
  }
}

String? _mucInviteAccountDomain(String? selfJid) {
  final domain = addressDomainPart(selfJid)?.toLowerCase();
  if (domain == null || domain.isEmpty) {
    return null;
  }
  return domain;
}

bool _isMucInviteEligibleAddress(String? address, {required String? domain}) {
  final bare = bareAddressOrNull(address);
  if (bare == null || isAxichatWelcomeThreadJid(bare)) {
    return false;
  }
  final addressDomain = addressDomainPart(bare)?.toLowerCase();
  if (addressDomain == null || addressDomain.isEmpty) {
    return false;
  }
  if (domain != null && addressDomain == domain) {
    return true;
  }
  return isAxiJid(bare);
}

bool _isMucInviteEligibleChat(
  chat_models.Chat chat, {
  required String? domain,
}) {
  if (chat.type != chat_models.ChatType.chat) {
    return false;
  }
  if (chat.isEmailBacked || chat.isAxichatWelcomeThread) {
    return false;
  }
  return _isMucInviteEligibleAddress(
    _mucInviteChatAddress(chat),
    domain: domain,
  );
}

bool _isMucInviteEligibleTarget(
  FanOutTarget target, {
  required String? domain,
}) {
  final chat = target.chat;
  if (chat != null) {
    return _isMucInviteEligibleChat(chat, domain: domain);
  }
  return _isMucInviteEligibleAddress(target.address, domain: domain);
}

String? _mucInviteAddressForTarget(FanOutTarget target) {
  final chat = target.chat;
  if (chat != null) {
    return _mucInviteChatAddress(chat);
  }
  return bareAddressOrNull(target.address);
}

String? _mucInviteChatAddress(chat_models.Chat chat) {
  return bareAddressOrNull(chat.remoteJid) ?? bareAddressOrNull(chat.jid);
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
  late List<ComposerRecipient> _recipients;

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
    final locate = context.read;
    final chatsState = locate<ChatsCubit>().state;
    final selfJid = locate<ChatsCubit>().selfJid;
    final accountDomain = _mucInviteAccountDomain(selfJid);
    final availableChats = (chatsState.items ?? const <chat_models.Chat>[])
        .where((chat) => _isMucInviteEligibleChat(chat, domain: accountDomain))
        .toList(growable: false);
    final profileJid = context.watch<ProfileCubit>().state.jid;
    final resolvedProfileJid = profileJid.trim();
    final String? selfIdentityJid = resolvedProfileJid.isNotEmpty
        ? resolvedProfileJid
        : null;
    final selfIdentity = SelfIdentitySnapshot(
      selfJid: selfIdentityJid,
      avatarPath: context.watch<ProfileCubit>().state.avatarPath,
      avatarLoading: context.watch<ProfileCubit>().state.avatarHydrating,
    );
    final includedRecipients = _recipients
        .where((recipient) => recipient.included)
        .toList(growable: false);
    final actionsPadding = EdgeInsets.fromLTRB(
      spacing.m,
      0,
      spacing.m,
      spacing.m,
    );
    final Widget actions = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AxiButton.outline(
          onPressed: () =>
              closeSheetWithKeyboardDismiss(context, widget.onClose),
          child: Text(l10n.commonCancel),
        ),
        SizedBox(width: spacing.s),
        AxiButton.primary(
          onPressed: includedRecipients.isEmpty
              ? null
              : () {
                  final invitees = <String>[];
                  for (final recipient in includedRecipients) {
                    final target = recipient.target;
                    if (!_isMucInviteEligibleTarget(
                      target,
                      domain: accountDomain,
                    )) {
                      FeedbackSystem.showInfo(
                        context,
                        context.l10n.mucInviteEligibleRecipientsOnly,
                      );
                      return;
                    }
                    final invitee = _mucInviteAddressForTarget(target);
                    if (invitee == null) {
                      FeedbackSystem.showInfo(
                        context,
                        context.l10n.mucInviteEligibleRecipientsOnly,
                      );
                      return;
                    }
                    invitees.add(invitee);
                  }
                  Navigator.of(context).pop(invitees);
                },
          leading: Icon(
            LucideIcons.send,
            size: context.sizing.iconButtonIconSize,
          ),
          child: Text(l10n.commonSend),
        ),
      ],
    );
    return AxiSheetScaffold.scroll(
      header: AxiSheetHeader(
        title: Text(l10n.mucInviteUsers),
        onClose: widget.onClose,
      ),
      bodyPadding: EdgeInsets.zero,
      children: [
        BlocSelector<ChatsCubit, ChatsState, List<String>>(
          bloc: locate<ChatsCubit>(),
          selector: (state) => state.recipientAddressSuggestions,
          builder: (context, suggestions) {
            final filteredSuggestions = suggestions
                .where(
                  (address) => _isMucInviteEligibleAddress(
                    address,
                    domain: accountDomain,
                  ),
                )
                .toList(growable: false);
            return RecipientChipsBar(
              recipients: _recipients,
              availableChats: availableChats,
              rosterItems: rosterItems,
              databaseSuggestionAddresses: filteredSuggestions,
              selfJid: selfJid,
              selfIdentity: selfIdentity,
              latestStatuses: const {},
              onRecipientAdded: (target) {
                if (!_isMucInviteEligibleTarget(
                  target,
                  domain: accountDomain,
                )) {
                  FeedbackSystem.showInfo(
                    context,
                    context.l10n.mucInviteEligibleRecipientsOnly,
                  );
                  return;
                }
                _addRecipient(target);
              },
              onRecipientRemoved: _removeRecipient,
              onRecipientToggled: _toggleRecipient,
              collapsedByDefault: false,
              horizontalPadding: 0,
            );
          },
        ),
        SizedBox(height: spacing.m),
        Padding(padding: actionsPadding, child: actions),
        SizedBox(height: spacing.m),
      ],
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
    final Widget actions = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AxiButton.outline(
          onPressed: () => closeSheetWithKeyboardDismiss(context, onCancel),
          child: Text(l10n.commonCancel),
        ),
        SizedBox(width: spacing.s),
        AxiButton.primary(
          onPressed: () => onSubmit(controller.text.trim()),
          child: Text(l10n.mucUpdateNickname),
        ),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CalendarSheetHeader(
          title: l10n.mucChangeNicknameTitle,
          onClose: onCancel,
        ),
        SizedBox(height: spacing.s),
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(
            child: AxiTextFormField(
              controller: controller,
              autofocus: true,
              placeholder: Text(l10n.mucEnterNicknamePlaceholder),
              onSubmitted: onSubmit,
            ),
          ),
        ),
        SizedBox(height: spacing.m),
        actions,
      ],
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
