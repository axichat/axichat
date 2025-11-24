import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/view/recipient_chips_bar.dart';
import 'package:axichat/src/common/ui/axi_avatar.dart';
import 'package:axichat/src/common/ui/axi_list_tile.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/muc/muc_models.dart';
import 'package:axichat/src/storage/models/chat_models.dart' as chat_models;
import 'package:flutter/material.dart';
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
    final groups = _sections();
    final theme = context.textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Members', style: theme.h4),
                const Spacer(),
                if (canInvite)
                  ShadButton.outline(
                    size: ShadButtonSize.sm,
                    onPressed: () async {
                      final jids = await _promptInvite(context);
                      if (jids != null && jids.isNotEmpty) {
                        for (final jid in jids) {
                          onInvite(jid.trim());
                        }
                      }
                    },
                    child: const Text('Invite user'),
                  ),
                if (onClose != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    tooltip: 'Close',
                    onPressed: onClose,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (onChangeNickname != null || onLeaveRoom != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
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
                          'Change nick${currentNickname == null ? '' : ' (${currentNickname!})'}',
                        ),
                      ),
                    if (onLeaveRoom != null)
                      ShadButton.destructive(
                        size: ShadButtonSize.sm,
                        onPressed: onLeaveRoom,
                        child: const Text('Leave room'),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: groups.isEmpty
                  ? Center(
                      child: Text(
                        'No members yet',
                        style: theme.muted,
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
                          myAffiliation: roomState.myAffiliation,
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemCount: groups.length,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<String>?> _promptInvite(BuildContext context) async {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _InviteChipsSheet(
        initialRecipients: [],
      ),
    );
  }

  Future<String?> _promptNickname(BuildContext context) async {
    final controller = TextEditingController(text: currentNickname ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change nickname'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter a nickname',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  List<_MemberGroup> _sections() {
    final seen = <String>{};
    final groups = <_MemberGroup>[
      _MemberGroup('Owners', roomState.owners),
      _MemberGroup('Admins', roomState.admins),
      _MemberGroup(
        'Moderators',
        roomState.moderators
            .where((o) => !o.affiliation.isOwner && !o.affiliation.isAdmin)
            .toList(),
      ),
      _MemberGroup('Members', roomState.members),
      _MemberGroup(
        'Visitors',
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
    final isOwnerOrAdmin = myAffiliation.isOwner || myAffiliation.isAdmin;
    final canModerateRoles = isOwnerOrAdmin || myRole.isModerator;
    final actions = <MucModerationAction>[];
    final hasRealJid = occupant.realJid?.isNotEmpty == true;
    if (canModerateRoles) {
      actions.add(MucModerationAction.kick);
    }
    if (isOwnerOrAdmin && hasRealJid) {
      actions.add(MucModerationAction.ban);
      actions.addAll([
        MucModerationAction.member,
        MucModerationAction.admin,
        MucModerationAction.owner,
      ]);
    }
    if (isOwnerOrAdmin) {
      actions.add(MucModerationAction.moderator);
    }
    if (canModerateRoles) {
      actions.add(MucModerationAction.participant);
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
    required this.myAffiliation,
  });

  final String title;
  final List<Occupant> occupants;
  final List<MucModerationAction> Function(Occupant occupant) buildActions;
  final void Function(String occupantId, MucModerationAction action) onAction;
  final String? myOccupantId;
  final OccupantAffiliation myAffiliation;

  @override
  Widget build(BuildContext context) {
    final theme = context.textTheme;
    const memberTileHeight = 64.0;
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
              child: AxiListTile(
                leading: AxiAvatar(
                  jid: _avatarKey(occupant),
                  size: 44,
                ),
                title: occupant.nick,
                subtitle: subtitle,
                selected: isSelf,
                minTileHeight: memberTileHeight,
                actions: actions.isEmpty
                    ? null
                    : [
                        PopupMenuButton<MucModerationAction>(
                          icon: const Icon(LucideIcons.ellipsisVertical),
                          onSelected: (action) =>
                              onAction(occupant.occupantId, action),
                          itemBuilder: (context) => actions
                              .map(
                                (action) => PopupMenuItem(
                                  value: action,
                                  child: Text(_actionLabel(action)),
                                ),
                              )
                              .toList(),
                        ),
                      ],
              ),
            );
          },
        ),
      ],
    );
  }

  String _actionLabel(MucModerationAction action) => switch (action) {
        MucModerationAction.kick => 'Kick',
        MucModerationAction.ban => 'Ban',
        MucModerationAction.member => 'Make member',
        MucModerationAction.admin => 'Make admin',
        MucModerationAction.owner => 'Make owner',
        MucModerationAction.moderator => 'Grant moderator',
        MucModerationAction.participant => 'Revoke moderator',
      };

  String _roleSubtitle(Occupant occupant) {
    final labels = <String>[];
    if (occupant.affiliation.isOwner) {
      labels.add('Owner');
    } else if (occupant.affiliation.isAdmin) {
      labels.add('Admin');
    } else if (occupant.affiliation.isMember) {
      labels.add('Member');
    } else {
      labels.add('Visitor');
    }
    if (occupant.role.isModerator) labels.add('Moderator');
    return labels.join(' • ');
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
  late List<ComposerRecipient> _recipients;

  @override
  void initState() {
    super.initState();
    _recipients = List<ComposerRecipient>.from(widget.initialRecipients);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + viewInsets,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invite users', style: context.textTheme.h4),
            const SizedBox(height: 12),
            RecipientChipsBar(
              recipients: _recipients,
              availableChats: const <chat_models.Chat>[],
              latestStatuses: const {},
              onRecipientAdded: _addRecipient,
              onRecipientRemoved: _removeRecipient,
              onRecipientToggled: _toggleRecipient,
              collapsedByDefault: false,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ShadButton.outline(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
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
                  child: const Text('Send invites'),
                ),
              ],
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
