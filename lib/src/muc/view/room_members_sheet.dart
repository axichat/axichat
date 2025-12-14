import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/view/recipient_chips_bar.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/muc/muc_models.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/models/chat_models.dart' as chat_models;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RoomMembersSheet extends StatelessWidget {
  const RoomMembersSheet({
    required this.roomState,
    required this.canInvite,
    required this.onInvite,
    required this.onAction,
    this.onChangeNickname,
    this.onLeaveRoom,
    this.currentNickname,
    this.onClose,
    super.key,
  });

  final RoomState roomState;
  final bool canInvite;
  final ValueChanged<String> onInvite;
  final void Function(String occupantId, MucModerationAction action) onAction;
  final ValueChanged<String>? onChangeNickname;
  final VoidCallback? onLeaveRoom;
  final String? currentNickname;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groups = _sections(l10n);
    final theme = context.textTheme;
    final colors = context.colorScheme;
    return SafeArea(
      child: AxiModalSurface(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.border)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: _HeaderRow(
                canInvite: canInvite,
                onInviteTap: () => _handleInvite(context),
                onClose: onClose,
                l10n: l10n,
              ),
            ),
            const SizedBox(height: 12),
            if (onChangeNickname != null || onLeaveRoom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (onChangeNickname != null)
                      ShadButton.outline(
                        size: ShadButtonSize.sm,
                        onPressed: () async {
                          final next = await _promptNickname(context);
                          if (next?.isNotEmpty == true) {
                            onChangeNickname!(next!);
                          }
                        },
                        child: Text(
                          currentNickname == null
                              ? l10n.mucChangeNickname
                              : l10n.mucChangeNicknameWithCurrent(
                                  currentNickname!,
                                ),
                        ),
                      ),
                    if (onLeaveRoom != null)
                      ShadButton.destructive(
                        size: ShadButtonSize.sm,
                        onPressed: onLeaveRoom,
                        child: Text(l10n.mucLeaveRoom),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: groups.isEmpty
                    ? Center(
                        child: Text(
                          l10n.mucNoMembers,
                          style: theme.muted
                              .copyWith(color: colors.mutedForeground),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return _MemberSection(
                            title: group.title,
                            occupants: group.members,
                            buildActions: _actionsFor,
                            onAction: onAction,
                            myOccupantId: roomState.myOccupantId,
                            l10n: l10n,
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemCount: groups.length,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<String>?> _promptInvite(BuildContext context) async {
    return showAdaptiveBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      surfacePadding: EdgeInsets.zero,
      dialogMaxWidth: 520,
      builder: (context) => const _InviteChipsSheet(
        initialRecipients: [],
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
    final focusNode = FocusNode();
    final result = await showAdaptiveBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      builder: (sheetContext) {
        final pop = Navigator.of(sheetContext).pop;
        return _NicknameSheet(
          controller: controller,
          focusNode: focusNode,
          onCancel: () => pop(),
          onSubmit: (value) => pop(value.trim()),
        );
      },
    );
    controller.dispose();
    focusNode.dispose();
    return result;
  }

  List<_MemberGroup> _sections(AppLocalizations l10n) {
    final seen = <String>{};
    final groups = <_MemberGroup>[
      _MemberGroup(l10n.mucSectionOwners, roomState.owners),
      _MemberGroup(l10n.mucSectionAdmins, roomState.admins),
      _MemberGroup(
        l10n.mucSectionModerators,
        roomState.moderators
            .where((o) => !o.affiliation.isOwner && !o.affiliation.isAdmin)
            .toList(),
      ),
      _MemberGroup(l10n.mucSectionMembers, roomState.members),
      _MemberGroup(
        l10n.mucSectionVisitors,
        roomState.visitors.where((o) => !o.affiliation.isMember).toList(),
      ),
    ];
    return groups
        .map(
          (group) => _MemberGroup(
            group.title,
            group.members
                .where((occupant) => seen.add(occupant.occupantId))
                .toList(),
          ),
        )
        .where((group) => group.members.isNotEmpty)
        .toList();
  }

  List<MucModerationAction> _actionsFor(Occupant occupant) {
    if (occupant.occupantId == roomState.myOccupantId) return const [];
    final myAffiliation = roomState.myAffiliation;
    final myRole = roomState.myRole;
    final isOwner = myAffiliation.isOwner;
    final isAdmin = myAffiliation.isAdmin;
    final isModerator = myRole.isModerator;
    final canSetRoles = isOwner || isAdmin || isModerator;
    final actions = <MucModerationAction>[];
    final hasRealJid = occupant.realJid?.isNotEmpty == true;
    if (canSetRoles) {
      actions.add(MucModerationAction.kick);
    }
    if ((isOwner || isAdmin) && hasRealJid) {
      actions.add(MucModerationAction.ban);
    }
    if (isOwner || isAdmin) {
      if (!occupant.affiliation.isMember) {
        actions.add(MucModerationAction.member);
      }
      if (isOwner) {
        if (!occupant.affiliation.isAdmin) {
          actions.add(MucModerationAction.admin);
        }
        if (!occupant.affiliation.isOwner) {
          actions.add(MucModerationAction.owner);
        }
      }
      if (occupant.role.isModerator) {
        actions.add(MucModerationAction.participant);
      } else {
        actions.add(MucModerationAction.moderator);
      }
    }
    if (canSetRoles && !actions.contains(MucModerationAction.participant)) {
      if (occupant.role.isModerator) {
        actions.add(MucModerationAction.participant);
      }
    }
    return actions;
  }
}

class _MemberGroup {
  const _MemberGroup(this.title, this.members);

  final String title;
  final List<Occupant> members;
}

class _MemberSection extends StatelessWidget {
  const _MemberSection({
    required this.title,
    required this.occupants,
    required this.buildActions,
    required this.onAction,
    required this.myOccupantId,
    required this.l10n,
  });

  final String title;
  final List<Occupant> occupants;
  final List<MucModerationAction> Function(Occupant occupant) buildActions;
  final void Function(String occupantId, MucModerationAction action) onAction;
  final String? myOccupantId;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = context.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(title, style: theme.muted),
        ),
        ...occupants.map(
          (occupant) {
            final actions = buildActions(occupant);
            final subtitle = _roleSubtitle(occupant);
            final isSelf = occupant.occupantId == myOccupantId;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _MemberTile(
                key: ValueKey(occupant.occupantId),
                occupant: occupant,
                subtitle: subtitle,
                actions: actions,
                onAction: onAction,
                isSelf: isSelf,
                l10n: l10n,
              ),
            );
          },
        ),
      ],
    );
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
    required this.onAction,
    required this.isSelf,
    required this.l10n,
    super.key,
  });

  final Occupant occupant;
  final String subtitle;
  final List<MucModerationAction> actions;
  final void Function(String occupantId, MucModerationAction action) onAction;
  final bool isSelf;
  final AppLocalizations l10n;

  @override
  State<_MemberTile> createState() => _MemberTileState();
}

class _MemberTileState extends State<_MemberTile> {
  bool _showActions = false;

  static const double _avatarSize = 40.0;

  void _toggleActions() => setState(() => _showActions = !_showActions);

  void _closeActions() => setState(() => _showActions = false);

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final borderColor =
        widget.isSelf ? colors.primary.withValues(alpha: 0.3) : colors.border;
    final avatarKey = _avatarKey(widget.occupant);
    final rosterCubit = context.read<RosterCubit?>();

    String? resolveAvatarPath({
      required List<RosterItem>? rosterItems,
      required List<Chat>? chats,
      required ProfileState profile,
    }) {
      if (widget.isSelf) {
        final selfPath = profile.avatarPath?.trim();
        if (selfPath?.isNotEmpty == true) {
          return selfPath;
        }
      }

      final realJid = widget.occupant.realJid?.trim();
      if (realJid == null || realJid.isEmpty) {
        return null;
      }

      final bareJid =
          realJid.contains('/') ? realJid.split('/').first : realJid;
      final normalizedBareJid = bareJid.trim().toLowerCase();
      if (normalizedBareJid.isEmpty) return null;

      if (rosterItems != null) {
        for (final item in rosterItems) {
          if (item.jid.trim().toLowerCase() != normalizedBareJid) continue;
          final path = item.avatarPath?.trim();
          if (path?.isNotEmpty == true) {
            return path;
          }
          break;
        }
      }

      if (chats != null) {
        for (final chat in chats) {
          final candidateBare = chat.remoteJid.trim().toLowerCase();
          if (candidateBare != normalizedBareJid) continue;
          final path = (chat.avatarPath ?? chat.contactAvatarPath)?.trim();
          if (path?.isNotEmpty == true) {
            return path;
          }
          break;
        }
      }

      return null;
    }

    final avatar = BlocBuilder<ChatsCubit, ChatsState>(
      buildWhen: (previous, current) => previous.items != current.items,
      builder: (context, chatsState) {
        return BlocBuilder<ProfileCubit, ProfileState>(
          buildWhen: (previous, current) =>
              previous.avatarPath != current.avatarPath,
          builder: (context, profileState) {
            final chats = chatsState.items;
            if (rosterCubit == null) {
              final avatarPath = resolveAvatarPath(
                rosterItems: null,
                chats: chats,
                profile: profileState,
              );
              return AxiAvatar(
                jid: avatarKey,
                size: _avatarSize,
                avatarPath: avatarPath,
              );
            }
            return BlocBuilder<RosterCubit, RosterState>(
              buildWhen: (_, current) => current is RosterAvailable,
              builder: (context, rosterState) {
                final cachedItems = rosterState is RosterAvailable
                    ? rosterState.items
                    : context.read<RosterCubit>()['items'] as List<RosterItem>?;
                final avatarPath = resolveAvatarPath(
                  rosterItems: cachedItems,
                  chats: chats,
                  profile: profileState,
                );
                return AxiAvatar(
                  jid: avatarKey,
                  size: _avatarSize,
                  avatarPath: avatarPath,
                );
              },
            );
          },
        );
      },
    );

    final tile = AxiListTile(
      onTap: widget.actions.isEmpty ? null : _toggleActions,
      leading: avatar,
      title: widget.occupant.nick,
      subtitle: widget.subtitle,
      selected: widget.isSelf,
      paintSurface: true,
      tapBounce: true,
      minTileHeight: 56,
      surfaceColor: colors.card,
      surfaceShape: SquircleBorder(
        cornerRadius: 14,
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      contentPadding: const EdgeInsetsDirectional.fromSTEB(14, 8, 14, 8),
    );

    final actionsPanel = widget.actions.isEmpty
        ? const SizedBox.shrink()
        : AnimatedCrossFade(
            duration: baseAnimationDuration,
            sizeCurve: Curves.easeInOutCubic,
            crossFadeState: _showActions
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
              child: _MemberActionPanel(
                occupantId: widget.occupant.occupantId,
                actions: widget.actions,
                onAction: widget.onAction,
                onClose: _closeActions,
                l10n: widget.l10n,
              ),
            ),
          );

    return Column(
      children: [
        tile,
        actionsPanel,
      ],
    );
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
    final textScaler = MediaQuery.of(context).textScaler;
    double scaled(double value) => textScaler.scale(value);
    final iconSize = scaled(16);
    final spacing = scaled(8);
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: WrapAlignment.start,
      children: actions.map((action) {
        final descriptor = _MemberActionDescriptor.forAction(action, l10n);
        final builder = descriptor.destructive
            ? ShadButton.destructive
            : ShadButton.outline;
        return builder(
            size: ShadButtonSize.sm,
            onPressed: () {
              onClose();
              onAction(occupantId, action);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(descriptor.icon, size: iconSize),
                SizedBox(width: scaled(6)),
                Text(descriptor.label),
              ],
            ));
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
  final separatorIndex = realJid.indexOf('/');
  if (separatorIndex <= 0) {
    return realJid;
  }
  return realJid.substring(0, separatorIndex);
}

class _InviteChipsSheet extends StatefulWidget {
  const _InviteChipsSheet({
    required this.initialRecipients,
  });

  final List<ComposerRecipient> initialRecipients;

  @override
  State<_InviteChipsSheet> createState() => _InviteChipsSheetState();
}

class _InviteChipsSheetState extends State<_InviteChipsSheet> {
  static const double _inviteSheetHorizontalPadding = 16.0;
  static const double _inviteSheetSectionSpacing = 12.0;
  static const EdgeInsets _inviteSheetHeaderPadding = EdgeInsets.fromLTRB(
    _inviteSheetHorizontalPadding,
    _inviteSheetHorizontalPadding,
    _inviteSheetHorizontalPadding,
    _inviteSheetSectionSpacing,
  );
  static const EdgeInsets _inviteSheetActionsPadding = EdgeInsets.symmetric(
    horizontal: _inviteSheetHorizontalPadding,
  );

  late List<ComposerRecipient> _recipients;

  @override
  void initState() {
    super.initState();
    _recipients = List<ComposerRecipient>.from(widget.initialRecipients);
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = context.modalHeaderTextStyle;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: _inviteSheetHorizontalPadding + viewInsets,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: _inviteSheetHeaderPadding,
              child: Text(l10n.mucInviteUsers, style: titleStyle),
            ),
            RecipientChipsBar(
              recipients: _recipients,
              availableChats: const <chat_models.Chat>[],
              latestStatuses: const {},
              onRecipientAdded: _addRecipient,
              onRecipientRemoved: _removeRecipient,
              onRecipientToggled: _toggleRecipient,
              collapsedByDefault: false,
              horizontalPadding: _inviteSheetHorizontalPadding,
            ),
            const SizedBox(height: _inviteSheetSectionSpacing),
            Padding(
              padding: _inviteSheetActionsPadding,
              child: Row(
                children: [
                  ShadButton.outline(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.commonCancel),
                  ).withTapBounce(),
                  const SizedBox(width: 8),
                  ShadButton(
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
                  ).withTapBounce(),
                ],
              ),
            ),
          ],
        ),
      ),
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

class _NicknameSheet extends StatefulWidget {
  const _NicknameSheet({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;

  @override
  State<_NicknameSheet> createState() => _NicknameSheetState();
}

class _NicknameSheetState extends State<_NicknameSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.focusNode.requestFocus(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = context.modalHeaderTextStyle;
    final l10n = context.l10n;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.mucChangeNicknameTitle,
            style: titleStyle,
          ),
          const SizedBox(height: 12),
          AxiTextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            placeholder: Text(l10n.mucEnterNicknamePlaceholder),
            onSubmitted: widget.onSubmit,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ShadButton.outline(
                onPressed: widget.onCancel,
                child: Text(l10n.commonCancel),
              ).withTapBounce(),
              const SizedBox(width: 8),
              ShadButton(
                onPressed: () => widget.onSubmit(widget.controller.text.trim()),
                child: Text(l10n.mucUpdateNickname),
              ).withTapBounce(),
            ],
          ),
        ],
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
    return Row(
      children: [
        Text(
          l10n.mucMembersTitle,
          style: headerStyle,
        ),
        const Spacer(),
        if (canInvite)
          ShadButton.outline(
            size: ShadButtonSize.sm,
            onPressed: onInviteTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.userPlus, size: 16),
                const SizedBox(width: 6),
                Text(l10n.mucInviteUser),
              ],
            ),
          ),
        if (onClose != null) ...[
          const SizedBox(width: 8),
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
